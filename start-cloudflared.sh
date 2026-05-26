#!/bin/sh
set -e

if [ -z "${CLOUDFLARE_TOKEN}" ]; then
  echo "[cloudflared] CLOUDFLARE_TOKEN is not set. Running without tunnel (localhost only)."
  # Exit 0 so supervisord marks this EXITED (not FATAL) and doesn't retry.
  exit 0
fi

echo "[cloudflared] Starting named tunnel..."
exec cloudflared tunnel --no-autoupdate run --token "${CLOUDFLARE_TOKEN}"
