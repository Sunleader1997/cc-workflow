#!/bin/bash
# Install cc-workflow as a systemd service

set -e

SERVICE_NAME="cc-workflow"
EXEC_SRC="./bin/cc-workflow"
EXEC_DST="/usr/local/bin/${SERVICE_NAME}"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}.service"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root: sudo $0"
    exit 1
fi

# Check executable exists
if [ ! -f "$EXEC_SRC" ]; then
    log_error "Executable not found: $EXEC_SRC"
    log_info "Run ./package.sh first to build the executable."
    exit 1
fi

log_info "Installing ${SERVICE_NAME}..."

# Copy executable
log_info "Copying executable to ${EXEC_DST}..."
cp "$EXEC_SRC" "$EXEC_DST"
chmod +x "$EXEC_DST"

# Create systemd service file
log_info "Creating systemd service file..."
cat > "$SERVICE_DST" << 'EOF'
[Unit]
Description=Claude Code Workflow Orchestrator
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cc-workflow
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cc-workflow

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
log_info "Reloading systemd..."
systemctl daemon-reload

# Enable service
log_info "Enabling ${SERVICE_NAME} service..."
systemctl enable "${SERVICE_NAME}.service"

# Start or restart service
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log_info "Restarting ${SERVICE_NAME} service..."
    systemctl restart "${SERVICE_NAME}.service"
else
    log_info "Starting ${SERVICE_NAME} service..."
    systemctl start "${SERVICE_NAME}.service"
fi

# Wait a moment and check status
sleep 1
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log_info "${SERVICE_NAME} service is running."
else
    log_warn "${SERVICE_NAME} service may not have started yet. Check status with: systemctl status ${SERVICE_NAME}"
fi

echo ""
log_info "Installation complete!"
echo ""
echo "Service:    ${SERVICE_NAME}"
echo "Executable: ${EXEC_DST}"
echo "Service:    ${SERVICE_DST}"
echo "URL:        http://localhost:9800"
echo ""
echo "Commands:"
echo "  systemctl status ${SERVICE_NAME}    # Check service status"
echo "  systemctl start ${SERVICE_NAME}     # Start service"
echo "  systemctl stop ${SERVICE_NAME}      # Stop service"
echo "  systemctl restart ${SERVICE_NAME}   # Restart service"
echo "  systemctl disable ${SERVICE_NAME}   # Disable autostart"
echo "  journalctl -u ${SERVICE_NAME} -f    # View logs"
