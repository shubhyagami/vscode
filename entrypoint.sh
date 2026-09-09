#!/bin/bash
# ==============================================================================
# Code-Server Container Entrypoint for Render
# ==============================================================================

set -e

PORT="${PORT:-8080}"
WORKSPACE="${WORKSPACE_DIR:-/home/coder/project}"

mkdir -p "$WORKSPACE"

# Print Java and Environment Info
echo "========================================================"
echo "⚡ Starting Code-Server with Java on Render!"
echo "📡 Listening Port: 0.0.0.0:$PORT"
echo "☕ Java Version: $(java -version 2>&1 | head -n 1)"
echo "📂 Workspace: $WORKSPACE"
echo "========================================================"

# Determine Authentication
if [ -n "$PASSWORD" ]; then
  echo "🔒 Password protection: ENABLED"
  AUTH_MODE="password"
  export PASSWORD="$PASSWORD"
else
  echo "🔓 Password protection: DISABLED (Direct access)"
  AUTH_MODE="none"
fi

# Start Database Sync Daemon in background
echo "🚀 Launching Database Sync Daemon..."
node /home/coder/sync-daemon.js &

# Start Code-Server
echo "🌐 Starting Code-Server on 0.0.0.0:$PORT..."
exec code-server \
  --bind-addr "0.0.0.0:${PORT}" \
  --auth "${AUTH_MODE}" \
  --disable-telemetry \
  --disable-update-check \
  "$WORKSPACE"
