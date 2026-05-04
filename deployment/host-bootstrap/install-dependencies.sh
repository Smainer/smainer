#!/bin/bash
# Smainer Provider Dependencies Installation Script
# Host: 10.100.102.208 Bootstrap Package
# Version: 1.0.0

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/smainer-provider"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log/smainer-provider"
SANDBOX_DIR="/var/lib/smainer-provider/sandbox"
USER="smainer"

echo "🚀 Smainer Provider Dependencies Installation"
echo "============================================"
echo "Target Host: 10.100.102.208"
echo "Install Directory: $INSTALL_DIR"
echo "User: $USER"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create system user if it doesn't exist
if ! id "$USER" &>/dev/null; then
    echo "👤 Creating system user: $USER"
    useradd --system --home-dir "$INSTALL_DIR" --shell /bin/bash --create-home "$USER"
    echo "✅ User $USER created"
else
    echo "✅ User $USER already exists"
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
apt-get update
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    build-essential \
    curl \
    wget \
    git \
    htop \
    supervisor \
    nginx \
    ufw \
    fail2ban

echo "✅ System dependencies installed"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$INSTALL_DIR"/{bin,logs,config,scripts}
mkdir -p "$LOG_DIR"
mkdir -p "$SANDBOX_DIR"

# Set ownership and permissions
chown -R "$USER:$USER" "$INSTALL_DIR"
chown -R "$USER:$USER" "$LOG_DIR"  
chown -R "$USER:$USER" "$SANDBOX_DIR"
chmod 700 "$SANDBOX_DIR"  # Secure sandbox directory
chmod 750 "$INSTALL_DIR"
chmod 750 "$LOG_DIR"

echo "✅ Directory structure created"

# Create Python virtual environment
echo "🐍 Setting up Python virtual environment..."
sudo -u "$USER" python3.11 -m venv "$INSTALL_DIR/venv"
echo "✅ Virtual environment created"

# Copy provider source code
if [[ -d "$SCRIPT_DIR/../backend/provider" ]]; then
    echo "📋 Copying provider source code..."
    cp -r "$SCRIPT_DIR/../backend/provider" "$INSTALL_DIR/provider"
    chown -R "$USER:$USER" "$INSTALL_DIR/provider"
    echo "✅ Source code copied"
else
    echo "⚠️  Warning: Provider source code not found at expected path"
    echo "   Manual copy required after installation"
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip

# Install from requirements if available, otherwise install from pyproject.toml
if [[ -f "$INSTALL_DIR/provider/requirements.txt" ]]; then
    sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/provider/requirements.txt"
else
    # Install from pyproject.toml dependencies
    sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" install \
        "websockets>=12.0" \
        "psutil>=5.9.0" \
        "nvidia-ml-py>=12.535.133" \
        "starknet-py>=0.21.0" \
        "pydantic>=2.5.0" \
        "pydantic-settings>=2.1.0" \
        "structlog>=23.2.0" \
        "httpx>=0.26.0"
fi

echo "✅ Python dependencies installed"

# Configure firewall (basic security)
echo "🔒 Configuring basic firewall rules..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8000/tcp  # Relayer connection
echo "✅ Firewall configured"

# Create logrotate configuration
echo "📋 Setting up log rotation..."
cat > /etc/logrotate.d/smainer-provider << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload smainer-provider || true
    endscript
}
EOF
echo "✅ Log rotation configured"

# Verify installation
echo "🔍 Verifying installation..."
sudo -u "$USER" "$INSTALL_DIR/venv/bin/python" --version
sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" list | grep -E "(starknet|websockets|psutil)" || true

echo ""
echo "✅ Installation completed successfully!"
echo ""
echo "📋 Summary:"
echo "   • System user: $USER"
echo "   • Install directory: $INSTALL_DIR"
echo "   • Python venv: $INSTALL_DIR/venv"
echo "   • Sandbox directory: $SANDBOX_DIR (700 permissions)"
echo "   • Logs: $LOG_DIR"
echo ""
echo "Next steps:"
echo "1. Run configure-env.sh to set up environment variables"
echo "2. Run install-systemd.sh to install systemd service"
echo "3. Run verify-setup.sh to test configuration"