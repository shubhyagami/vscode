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

# Ensure all default extensions are present
(
  sleep 4
  echo "🔍 Verifying default extensions are active..."
  DEFAULT_EXTS=(
    "vscjava.vscode-java-pack"
    "redhat.java"
    "vscjava.vscode-java-debug"
    "vscjava.vscode-java-test"
    "vscjava.vscode-maven"
    "vscjava.vscode-java-dependency"
    "vmware.vscode-spring-boot-extension-pack"
    "vscjava.vscode-spring-initializr"
    "vmware.vscode-spring-boot"
    "formulahendry.code-runner"
    "ritwickdey.liveserver"
  )
  for ext in "${DEFAULT_EXTS[@]}"; do
    if ! code-server --list-extensions 2>/dev/null | grep -qi "$ext"; then
      echo "📦 Installing missing extension: $ext..."
      code-server --install-extension "$ext" >/dev/null 2>&1 || true
    fi
  done
  echo "✓ All default extensions verified!"
) &

# Start Code-Server
echo "🌐 Starting Code-Server on 0.0.0.0:$PORT..."
exec code-server \
  --bind-addr "0.0.0.0:${PORT}" \
  --auth "${AUTH_MODE}" \
  --disable-telemetry \
  --disable-update-check \
  "$WORKSPACE"
