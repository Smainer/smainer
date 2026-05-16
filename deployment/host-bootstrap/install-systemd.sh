#!/bin/bash
# Smainer Provider Systemd Service Installation Script
# Host: 10.100.102.208 Bootstrap Package
# Purpose: Install and configure systemd service for provider daemon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/smainer-provider"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/smainer-provider.service"
USER="smainer"

echo "⚙️  Smainer Provider Systemd Service Installation"
echo "==============================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Check dependencies
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "❌ Install directory $INSTALL_DIR not found. Run install-dependencies.sh first."
    exit 1
fi

if [[ ! -f "$INSTALL_DIR/config/.env" ]]; then
    echo "❌ Configuration file not found. Run configure-env.sh first."
    exit 1
fi

if ! id "$USER" &>/dev/null; then
    echo "❌ User $USER does not exist. Run install-dependencies.sh first."
    exit 1
fi

echo "📝 Creating systemd service file..."

# Create the systemd service file
cat > "$SYSTEMD_SERVICE_FILE" << 'EOF'
[Unit]
Description=Smainer Provider Daemon
Documentation=https://docs.smainer.com/provider
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=exec
User=smainer
Group=smainer
WorkingDirectory=/opt/smainer-provider/provider
Environment=PYTHONPATH=/opt/smainer-provider/provider/src

# Load environment from secure config file
EnvironmentFile=/opt/smainer-provider/config/.env
EnvironmentFile=-/opt/smainer-provider/config/systemd.env

# Execution
ExecStartPre=/bin/bash -c 'mkdir -p /var/lib/smainer-provider/sandbox /var/log/smainer-provider'
ExecStartPre=/bin/bash -c 'chown smainer:smainer /var/lib/smainer-provider/sandbox /var/log/smainer-provider'
ExecStart=/opt/smainer-provider/venv/bin/python -m provider.main
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID

# Process management
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStartSec=60
TimeoutStopSec=30

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateTmp=true
ProtectHostname=true

# Filesystem permissions
ReadWritePaths=/var/lib/smainer-provider /var/log/smainer-provider /tmp
ReadOnlyPaths=/opt/smainer-provider

# Network restrictions
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# System call filtering
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @privileged @reboot @swap @raw-io

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=smainer-provider

# PID file
PIDFile=/var/run/smainer-provider.pid

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd service file created: $SYSTEMD_SERVICE_FILE"

# Create PID file directory
echo "📁 Creating PID file directory..."
mkdir -p /var/run
chown root:root /var/run

# Set permissions on service file
chmod 644 "$SYSTEMD_SERVICE_FILE"

# Create wrapper script for better control
echo "📝 Creating daemon control script..."
cat > "$INSTALL_DIR/bin/provider-daemon" << 'EOF'
#!/bin/bash
# Smainer Provider Daemon Control Script

INSTALL_DIR="/opt/smainer-provider"
PID_FILE="/var/run/smainer-provider.pid"

case "$1" in
    start)
        echo "Starting Smainer Provider Daemon..."
        systemctl start smainer-provider
        ;;
    stop)
        echo "Stopping Smainer Provider Daemon..."
        systemctl stop smainer-provider
        ;;
    restart)
        echo "Restarting Smainer Provider Daemon..."
        systemctl restart smainer-provider
        ;;
    status)
        systemctl status smainer-provider
        ;;
    logs)
        journalctl -u smainer-provider -f
        ;;
    logs-tail)
        journalctl -u smainer-provider -n 100
        ;;
    enable)
        echo "Enabling Smainer Provider Daemon to start at boot..."
        systemctl enable smainer-provider
        ;;
    disable)
        echo "Disabling Smainer Provider Daemon from starting at boot..."
        systemctl disable smainer-provider
        ;;
    kill)
        echo "Force killing provider daemon..."
        if [[ -f "$PID_FILE" ]]; then
            kill $(cat "$PID_FILE") 2>/dev/null || echo "PID file exists but process not found"
            rm -f "$PID_FILE"
        else
            echo "No PID file found"
        fi
        pkill -f "python.*provider.main" || echo "No python provider processes found"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|logs-tail|enable|disable|kill}"
        echo ""
        echo "Commands:"
        echo "  start      - Start the daemon"
        echo "  stop       - Stop the daemon gracefully"
        echo "  restart    - Restart the daemon"
        echo "  status     - Show daemon status"
        echo "  logs       - Follow live logs"
        echo "  logs-tail  - Show last 100 log entries"
        echo "  enable     - Enable auto-start at boot"
        echo "  disable    - Disable auto-start at boot"
        echo "  kill       - Force kill daemon (emergency)"
        exit 1
        ;;
esac
EOF

# Make control script executable
chmod +x "$INSTALL_DIR/bin/provider-daemon"

# Create convenient symlink
ln -sf "$INSTALL_DIR/bin/provider-daemon" /usr/local/bin/provider-daemon

echo "✅ Control script created: $INSTALL_DIR/bin/provider-daemon"
echo "✅ Symlink created: /usr/local/bin/provider-daemon"

# Reload systemd and enable service
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

echo "⚙️  Enabling service to start at boot..."
systemctl enable smainer-provider

echo "🔍 Validating service configuration..."
systemctl status smainer-provider --no-pager || true

echo ""
echo "✅ Systemd service installation completed successfully!"
echo ""
echo "📋 Summary:"
echo "   • Service file: $SYSTEMD_SERVICE_FILE"
echo "   • Control script: /usr/local/bin/provider-daemon"
echo "   • Service name: smainer-provider"
echo "   • User: $USER"
echo "   • Auto-start: enabled"
echo ""
echo "🔧 Service Management Commands:"
echo "   provider-daemon start      # Start the service"
echo "   provider-daemon stop       # Stop the service"
echo "   provider-daemon status     # Check status"
echo "   provider-daemon logs       # Follow live logs"
echo ""
echo "Next steps:"
echo "1. Run verify-setup.sh to test the complete setup"
echo "2. Use 'provider-daemon start' to start the daemon"