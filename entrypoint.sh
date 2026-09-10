#!/bin/bash
# ==============================================================================
# Code-Server Container Entrypoint for Render & Cloud Deployments
# Ensures proper UID/GID, workspace permissions, settings, and daemon launch
# ==============================================================================

set -e

# Run fixuid if available (from official coder image)
eval "$(fixuid -q)" 2>/dev/null || true

PORT="${PORT:-8080}"
WORKSPACE="${WORKSPACE_DIR:-/home/coder/project}"

# Ensure directories exist
mkdir -p "$WORKSPACE"
mkdir -p "$WORKSPACE/.vscode"
mkdir -p /home/coder/.local/share/code-server/User
mkdir -p /home/coder/.local/share/code-server/extensions
mkdir -p /home/coder/.config/code-server

# Enforce full read/write permissions for coder user on workspace and config
sudo chown -R coder:coder "$WORKSPACE" /home/coder/.local /home/coder/.config 2>/dev/null || true
chmod -R u+rwX "$WORKSPACE" /home/coder/.local /home/coder/.config 2>/dev/null || true

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

# Write code-server runtime config.yaml
cat <<EOF > /home/coder/.config/code-server/config.yaml
bind-addr: 0.0.0.0:${PORT}
auth: ${AUTH_MODE}
cert: false
EOF

# Ensure default User & Workspace settings are in place
if [ -f /home/coder/settings.json ]; then
  if [ ! -f /home/coder/.local/share/code-server/User/settings.json ]; then
    cp /home/coder/settings.json /home/coder/.local/share/code-server/User/settings.json
  fi
  if [ ! -f "$WORKSPACE/.vscode/settings.json" ]; then
    cp /home/coder/settings.json "$WORKSPACE/.vscode/settings.json"
  fi
fi

# Start Database Sync Daemon in background
echo "🚀 Launching Database Sync Daemon..."
node /home/coder/sync-daemon.js &

# Start Code-Server with proper init wrapper
echo "🌐 Starting Code-Server on 0.0.0.0:$PORT..."

INIT_BIN=""
if command -v dumb-init >/dev/null 2>&1; then
  INIT_BIN="dumb-init"
fi

exec $INIT_BIN code-server \
  --bind-addr "0.0.0.0:${PORT}" \
  --auth "${AUTH_MODE}" \
  --user-data-dir "/home/coder/.local/share/code-server" \
  --extensions-dir "/home/coder/.local/share/code-server/extensions" \
  --config "/home/coder/.config/code-server/config.yaml" \
  --disable-telemetry \
  --disable-update-check \
  "$WORKSPACE"
