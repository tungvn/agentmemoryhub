#!/bin/sh
set -e

if [ -z "${CLOUDFLARE_TOKEN}" ]; then
  echo "[cloudflared] CLOUDFLARE_TOKEN is not set. Running without tunnel (localhost only)."
  # Exit 0 so supervisord marks this EXITED (not FATAL) and doesn't retry.
  exit 0
fi

echo "[cloudflared] Starting named tunnel..."
# --protocol http2: TCP-based, surfaces dead sockets after sleep/network loss far
#   more reliably than the default QUIC (UDP NAT mappings expire silently on sleep).
# --grace-period / --retries: tune reconnect backoff after WiFi drops.
exec cloudflared tunnel --no-autoupdate \
  --protocol http2 \
  --grace-period 30s \
  --retries 10 \
  run --token "${CLOUDFLARE_TOKEN}"
