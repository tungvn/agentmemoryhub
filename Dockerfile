ARG III_VERSION=0.11.2
ARG AGENTMEMORY_VERSION=0.9.21
ARG III_SDK_VERSION=0.11.2

# ── Stage 1: extract iii binary ───────────────────────────────────────────────
FROM iiidev/iii:${III_VERSION} AS iii-image

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM node:22-slim

ARG AGENTMEMORY_VERSION
ARG III_SDK_VERSION
ARG III_VERSION

ENV TRANSFORMERS_CACHE=/opt/agentmemory/.cache \
    III_REST_PORT=3111 \
    III_STREAMS_PORT=3112 \
    III_ENGINE_URL=ws://localhost:49134 \
    NODE_ENV=production \
    TINI_SUBREAPER=1 \
    AGENTMEMORY_III_VERSION=${III_VERSION}

# Install system dependencies + cloudflared
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssl ca-certificates curl tini gosu supervisor \
    && ARCH=$(dpkg --print-architecture) \
    && curl -fsSL \
         "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" \
         -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy iii binary from stage 1
COPY --from=iii-image /app/iii /usr/local/bin/iii

# Install agentmemory with exact iii-sdk pin.
# Install @xenova/transformers + onnxruntime-node explicitly (they are optional
# deps of agentmemory — included here to enable local vector embeddings without
# any API key).
WORKDIR /opt/agentmemory
RUN printf '{"name":"agentmemory-deploy","version":"1.0.0","private":true,"overrides":{"iii-sdk":"%s"}}\n' \
      "${III_SDK_VERSION}" > package.json \
    && npm install \
         "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" \
         @xenova/transformers \
         onnxruntime-node \
         --no-fund --no-audit \
    && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory \
    && npm cache clean --force \
    && find node_modules/@agentmemory/agentmemory/dist -name "*.mjs" \
         -exec sed -i 's/server\.listen(currentPort, "127\.0\.0\.1")/server.listen(currentPort, "0.0.0.0")/g' {} \;

# Pre-bake all-MiniLM-L6-v2 ONNX embedding model into the image layer.
# At runtime, TRANSFORMERS_CACHE points here — no network download needed.
COPY warmup-embeddings.mjs /opt/agentmemory/warmup-embeddings.mjs
RUN node /opt/agentmemory/warmup-embeddings.mjs

# Copy process management scripts and supervisord config
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 start-cloudflared.sh /usr/local/bin/start-cloudflared.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf

VOLUME /data
EXPOSE 3111 3112 3113

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:3111/agentmemory/livez || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
