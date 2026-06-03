#!/bin/sh
# agentmemoryhub macOS wake hook.
#
# Runs when the Mac wakes from sleep (triggered by sleepwatcher). Restarts the
# agentmemory container so the Cloudflare tunnel re-establishes cleanly after the
# Docker Desktop VM was frozen during sleep.
#
# Configuration is read from $AGENTMEMORYHUB_HOME/config (default ~/.agentmemoryhub),
# which the installer (install-wakeup.sh) writes with the detected values below.

AGENTMEMORYHUB_HOME="${AGENTMEMORYHUB_HOME:-$HOME/.agentmemoryhub}"
[ -f "$AGENTMEMORYHUB_HOME/config" ] && . "$AGENTMEMORYHUB_HOME/config"

# Fallbacks if config is missing or incomplete.
PROJECT_DIR="${PROJECT_DIR:-$HOME/.agentmemoryhub/repo}"
DOCKER="${DOCKER:-$(command -v docker 2>/dev/null || echo /usr/local/bin/docker)}"
LOG="${LOG:-$AGENTMEMORYHUB_HOME/wakeup.log}"

echo "[$(date)] wake event — waiting for Docker daemon..." >> "$LOG"

# Docker Desktop's VM resumes a few seconds after wake; wait up to ~60s for it.
i=0
while [ "$i" -lt 30 ]; do
  if "$DOCKER" info >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 2
done

if ! "$DOCKER" info >/dev/null 2>&1; then
  echo "[$(date)] Docker daemon not ready after wait — skipping restart." >> "$LOG"
  exit 0
fi

echo "[$(date)] restarting agentmemory tunnel..." >> "$LOG"
cd "$PROJECT_DIR" && "$DOCKER" compose restart agentmemory >> "$LOG" 2>&1
echo "[$(date)] done." >> "$LOG"
