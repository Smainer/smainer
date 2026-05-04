#!/bin/bash
# Smainer Provider Environment Configuration Script
# Host: 10.100.102.208 Bootstrap Package
# Purpose: Securely configure environment variables without exposing secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/smainer-provider"
CONFIG_FILE="$INSTALL_DIR/config/.env"
USER="smainer"

echo "🔧 Smainer Provider Environment Configuration"
echo "============================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Check if user exists
if ! id "$USER" &>/dev/null; then
    echo "❌ User $USER does not exist. Run install-dependencies.sh first."
    exit 1
fi

# Check if install directory exists
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "❌ Install directory $INSTALL_DIR not found. Run install-dependencies.sh first."
    exit 1
fi

echo "📝 Creating environment configuration..."
echo ""

# Create secure config directory if it doesn't exist
mkdir -p "$INSTALL_DIR/config"

# Function to prompt for value without echo (for secrets)
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    
    echo -n "$prompt"
    if [[ -n "$default_value" ]]; then
        echo -n " [default: $default_value]"
    fi
    echo -n ": "
    
    read -r -s value
    echo ""  # Add newline since -s suppresses it
    
    if [[ -z "$value" ]] && [[ -n "$default_value" ]]; then
        value="$default_value"
    fi
    
    eval "$var_name=\"$value\""
}

# Function to prompt for regular value
prompt_value() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    
    echo -n "$prompt"
    if [[ -n "$default_value" ]]; then
        echo -n " [default: $default_value]"
    fi
    echo -n ": "
    
    read -r value
    
    if [[ -z "$value" ]] && [[ -n "$default_value" ]]; then
        value="$default_value"
    fi
    
    eval "$var_name=\"$value\""
}

# Collect configuration values
echo "🌐 Relayer Connection Settings:"
prompt_value "Relayer WebSocket URL" RELAYER_WS_URL "ws://relay.smainer.com:8000"
prompt_value "Node ID (unique identifier)" NODE_ID "provider-$(hostname -s)-$(date +%s)"

echo ""
echo "🔐 Starknet Configuration:"
echo "⚠️  Private key will not be echoed to screen"
prompt_secret "Starknet Private Key (64-char hex)" STARKNET_PRIVATE_KEY ""

# Validate private key format
if [[ ! "$STARKNET_PRIVATE_KEY" =~ ^0x[0-9a-fA-F]{64}$ ]] && [[ ! "$STARKNET_PRIVATE_KEY" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "❌ Invalid private key format. Must be 64-character hexadecimal."
    exit 1
fi

# Ensure 0x prefix
if [[ ! "$STARKNET_PRIVATE_KEY" =~ ^0x ]]; then
    STARKNET_PRIVATE_KEY="0x$STARKNET_PRIVATE_KEY"
fi

echo "✅ Private key format validated"

echo ""
echo "⚙️  Performance Settings:"
prompt_value "Maximum concurrent tasks" MAX_CONCURRENT_TASKS "2"
prompt_value "Heartbeat interval (seconds)" HEARTBEAT_INTERVAL "30"
prompt_value "Log level (DEBUG/INFO/WARNING/ERROR)" LOG_LEVEL "INFO"

echo ""
echo "🛡️  Security Settings:"
prompt_value "Enable custom tasks (true/false)" ENABLE_CUSTOM_TASKS "false"

echo ""
echo "📊 Resource Limits:"
prompt_value "Default CPU time limit (seconds)" DEFAULT_CPU_TIME_LIMIT "300"
prompt_value "Default memory limit (MB)" DEFAULT_MEMORY_LIMIT "512"
prompt_value "Default timeout (seconds)" DEFAULT_TIMEOUT "300"

echo ""
echo "🔄 Connection Settings:"
prompt_value "Max reconnect attempts" RECONNECT_MAX_ATTEMPTS "10"
prompt_value "Initial reconnect delay (seconds)" RECONNECT_INITIAL_DELAY "1.0"
prompt_value "Max reconnect delay (seconds)" RECONNECT_MAX_DELAY "60.0"

# Create environment file
echo "📝 Writing configuration file..."
cat > "$CONFIG_FILE" << EOF
# Smainer Provider Configuration
# Generated: $(date)
# Host: $(hostname)

# Relayer Connection Settings
RELAYER_WS_URL=$RELAYER_WS_URL
NODE_ID=$NODE_ID

# Starknet Settings
STARKNET_PRIVATE_KEY=$STARKNET_PRIVATE_KEY

# Performance Settings
MAX_CONCURRENT_TASKS=$MAX_CONCURRENT_TASKS
HEARTBEAT_INTERVAL=$HEARTBEAT_INTERVAL
LOG_LEVEL=$LOG_LEVEL

# Security Settings
SANDBOX_TEMP_DIR=/var/lib/smainer-provider/sandbox
ENABLE_CUSTOM_TASKS=$ENABLE_CUSTOM_TASKS

# Resource Monitoring
RESOURCE_MONITORING_INTERVAL=1.0
DEFAULT_CPU_TIME_LIMIT=$DEFAULT_CPU_TIME_LIMIT
DEFAULT_MEMORY_LIMIT=$DEFAULT_MEMORY_LIMIT
DEFAULT_TIMEOUT=$DEFAULT_TIMEOUT

# Connection Settings
RECONNECT_MAX_ATTEMPTS=$RECONNECT_MAX_ATTEMPTS
RECONNECT_INITIAL_DELAY=$RECONNECT_INITIAL_DELAY
RECONNECT_MAX_DELAY=$RECONNECT_MAX_DELAY
RECONNECT_BACKOFF_MULTIPLIER=2.0

# System Paths
INSTALL_DIR=$INSTALL_DIR
LOG_DIR=/var/log/smainer-provider
PID_FILE=/var/run/smainer-provider.pid
EOF

# Set secure permissions on config file
chown "$USER:$USER" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"  # Only user can read/write

echo "✅ Configuration file created: $CONFIG_FILE"
echo "🔒 Permissions set to 600 (user-only access)"

# Create systemd environment file (without secrets)
echo "📝 Creating systemd environment file..."
cat > "$INSTALL_DIR/config/systemd.env" << EOF
# Systemd Environment File (Public Settings Only)
# Generated: $(date)

INSTALL_DIR=$INSTALL_DIR
LOG_DIR=/var/log/smainer-provider
PID_FILE=/var/run/smainer-provider.pid
SANDBOX_TEMP_DIR=/var/lib/smainer-provider/sandbox
LOG_LEVEL=$LOG_LEVEL
RESOURCE_MONITORING_INTERVAL=1.0
EOF

chown "$USER:$USER" "$INSTALL_DIR/config/systemd.env"
chmod 644 "$INSTALL_DIR/config/systemd.env"

echo "✅ Systemd environment file created"
echo ""
echo "✅ Environment configuration completed successfully!"
echo ""
echo "📋 Summary:"
echo "   • Main config: $CONFIG_FILE (600 permissions)"
echo "   • Systemd config: $INSTALL_DIR/config/systemd.env (644 permissions)"
echo "   • Owner: $USER"
echo ""
echo "⚠️  Security Notes:"
echo "   • Private key is stored in $CONFIG_FILE with restricted permissions"
echo "   • Only the $USER user can read the configuration"
echo "   • Systemd environment file contains no secrets"
echo ""
echo "Next steps:"
echo "1. Run install-systemd.sh to install the systemd service"
echo "2. Run verify-setup.sh to test the configuration"