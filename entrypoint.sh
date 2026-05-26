#!/bin/sh
# Runs as root. Sets up /data, writes iii-config.yaml, resolves AGENTMEMORY_SECRET,
# then drops to node user and execs supervisord.
set -eu

DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
HMAC_FILE="${DATA_DIR}/.hmac"
RUN_AS="node:node"
III_CONFIG="/opt/agentmemory/node_modules/@agentmemory/agentmemory/dist/iii-config.yaml"

mkdir -p "$DATA_DIR"
chown -R "$RUN_AS" "$DATA_DIR"

# Write iii-config.yaml with 0.0.0.0 bindings and /data absolute paths.
# This overwrites the npm-bundled config which binds 127.0.0.1 and uses
# relative ./data paths.
cat > "$III_CONFIG" <<'EOF'
workers:
  - name: iii-http
    config:
      port: 3111
      host: 0.0.0.0
      default_timeout: 180000
      cors:
        allowed_origins:
          - "http://localhost:3111"
          - "http://localhost:3113"
          - "http://127.0.0.1:3111"
          - "http://127.0.0.1:3113"
        allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]
  - name: iii-state
    config:
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/state_store.db
  - name: iii-queue
    config:
      adapter:
        name: builtin
  - name: iii-pubsub
    config:
      adapter:
        name: local
  - name: iii-cron
    config:
      adapter:
        name: kv
  - name: iii-stream
    config:
      port: 3112
      host: 0.0.0.0
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/stream_store
  - name: iii-observability
    config:
      enabled: true
      service_name: agentmemory
      exporter: memory
      sampling_ratio: 1.0
      metrics_enabled: true
      logs_enabled: true
      logs_console_output: true
EOF
chown "$RUN_AS" "$III_CONFIG"

# Resolve AGENTMEMORY_SECRET.
# Priority: (1) env var provided at runtime, (2) persisted /data/.hmac from prior run.
# Error if neither exists — this service must not run unauthenticated when public.
if [ -n "${AGENTMEMORY_SECRET:-}" ]; then
  printf '%s\n' "$AGENTMEMORY_SECRET" > "$HMAC_FILE"
  chmod 600 "$HMAC_FILE"
  chown "$RUN_AS" "$HMAC_FILE"
  echo "[entrypoint] Using provided AGENTMEMORY_SECRET."
elif [ -s "$HMAC_FILE" ]; then
  AGENTMEMORY_SECRET="$(cat "$HMAC_FILE")"
  export AGENTMEMORY_SECRET
  echo "[entrypoint] Loaded existing AGENTMEMORY_SECRET from $HMAC_FILE."
else
  echo "================================================================"
  echo "ERROR: AGENTMEMORY_SECRET is not set."
  echo ""
  echo "Generate one with:  openssl rand -hex 32"
  echo "Then pass it as:    -e AGENTMEMORY_SECRET=<value>"
  echo ""
  echo "This secret authenticates all REST API and MCP requests."
  echo "================================================================"
  exit 1
fi

export AGENTMEMORY_SECRET

echo "[entrypoint] Setup complete. Starting supervisord as node user..."
exec gosu "$RUN_AS" supervisord -c /etc/supervisor/supervisord.conf
