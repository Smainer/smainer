#!/bin/bash
# Smainer Provider Setup Verification Script
# Host: 10.100.102.208 Bootstrap Package
# Purpose: Comprehensive verification of provider daemon setup and connectivity

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/smainer-provider"
CONFIG_FILE="$INSTALL_DIR/config/.env"
USER="smainer"
LOG_FILE="/tmp/provider-verification-$(date +%Y%m%d_%H%M%S).log"

echo "🔍 SMAINER PROVIDER VERIFICATION REPORT"
echo "======================================="
echo "Date: $(date)"
echo "Host: $(hostname) ($(hostname -I | awk '{print $1}'))"
echo "User: $(whoami)"
echo "Log: $LOG_FILE"
echo ""

# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
success() {
    echo -e "   ${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "   ${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "   ${RED}❌ $1${NC}"
}

info() {
    echo -e "   ${BLUE}ℹ️  $1${NC}"
}

test_result() {
    if [[ $1 -eq 0 ]]; then
        success "$2"
        return 0
    else
        error "$2"
        return 1
    fi
}

echo "📦 1. SYSTEM DEPENDENCIES CHECK"
echo "==============================="

# Check if user exists
if id "$USER" &>/dev/null; then
    success "User $USER exists"
    USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
    info "User home directory: $USER_HOME"
else
    error "User $USER does not exist"
    exit 1
fi

# Check Python version
if python3.11 --version &>/dev/null; then
    PYTHON_VERSION=$(python3.11 --version)
    success "Python 3.11 installed: $PYTHON_VERSION"
else
    error "Python 3.11 not found"
fi

# Check virtual environment
if [[ -f "$INSTALL_DIR/venv/bin/python" ]]; then
    success "Virtual environment exists"
    VENV_PYTHON_VERSION=$("$INSTALL_DIR/venv/bin/python" --version)
    info "Virtual environment Python: $VENV_PYTHON_VERSION"
else
    error "Virtual environment not found at $INSTALL_DIR/venv"
fi

# Check required Python packages
echo ""
echo "📦 2. PYTHON DEPENDENCIES CHECK"
echo "==============================="

REQUIRED_PACKAGES=("starknet-py" "websockets" "psutil" "pydantic" "structlog" "httpx")
for package in "${REQUIRED_PACKAGES[@]}"; do
    if sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" show "$package" &>/dev/null; then
        VERSION=$(sudo -u "$USER" "$INSTALL_DIR/venv/bin/pip" show "$package" | grep Version | cut -d: -f2 | tr -d ' ')
        success "$package installed (version: $VERSION)"
    else
        error "$package not installed"
    fi
done

echo ""
echo "📁 3. DIRECTORY STRUCTURE CHECK"
echo "==============================="

REQUIRED_DIRS=(
    "$INSTALL_DIR"
    "$INSTALL_DIR/config"
    "$INSTALL_DIR/provider"
    "$INSTALL_DIR/venv"
    "/var/lib/smainer-provider/sandbox"
    "/var/log/smainer-provider"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        success "Directory exists: $dir"
        PERMS=$(stat -c "%a" "$dir")
        OWNER=$(stat -c "%U:%G" "$dir")
        info "Permissions: $PERMS, Owner: $OWNER"
    else
        error "Directory missing: $dir"
    fi
done

echo ""
echo "🔧 4. CONFIGURATION CHECK"
echo "=========================="

if [[ -f "$CONFIG_FILE" ]]; then
    success "Configuration file exists: $CONFIG_FILE"
    PERMS=$(stat -c "%a" "$CONFIG_FILE")
    OWNER=$(stat -c "%U:%G" "$CONFIG_FILE")
    info "Permissions: $PERMS, Owner: $OWNER"
    
    # Check critical environment variables (without exposing values)
    ENV_VARS=("RELAYER_WS_URL" "NODE_ID" "STARKNET_PRIVATE_KEY")
    for var in "${ENV_VARS[@]}"; do
        if grep -q "^$var=" "$CONFIG_FILE"; then
            success "Environment variable set: $var"
        else
            error "Environment variable missing: $var"
        fi
    done
else
    error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo ""
echo "⚙️  5. SYSTEMD SERVICE CHECK"
echo "============================"

# Check if service file exists
if [[ -f "/etc/systemd/system/smainer-provider.service" ]]; then
    success "Systemd service file exists"
else
    error "Systemd service file not found"
fi

# Check service status
if systemctl is-enabled smainer-provider &>/dev/null; then
    success "Service is enabled for auto-start"
else
    warning "Service is not enabled for auto-start"
fi

# Check if service can start (without actually starting it for long)
echo ""
echo "🧪 6. SERVICE START TEST"
echo "========================"

echo "   Testing daemon startup (5-second test)..."

# Start the service
if systemctl start smainer-provider; then
    success "Service started successfully"
    
    # Wait a moment for initialization
    sleep 3
    
    # Check if still running
    if systemctl is-active smainer-provider &>/dev/null; then
        success "Service is running and stable"
        
        # Get process information
        PID=$(systemctl show smainer-provider --property=MainPID --value)
        if [[ "$PID" != "0" ]]; then
            success "Process PID: $PID"
            
            # Check resource usage
            if ps -p "$PID" -o pid,user,cpu,mem,cmd --no-headers; then
                success "Process details retrieved"
            fi
        fi
    else
        error "Service failed after startup"
    fi
    
    # Stop the service
    echo "   Stopping test service..."
    systemctl stop smainer-provider
    sleep 1
    
    if ! systemctl is-active smainer-provider &>/dev/null; then
        success "Service stopped cleanly"
    else
        warning "Service did not stop cleanly"
    fi
else
    error "Service failed to start"
    
    # Show recent logs for debugging
    echo "   Recent service logs:"
    journalctl -u smainer-provider --no-pager -n 10 || true
fi

echo ""
echo "🌐 7. NETWORK CONNECTIVITY CHECK"
echo "================================"

# Load configuration to get relayer URL
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # Extract host and port from WebSocket URL
    if [[ "$RELAYER_WS_URL" =~ ws://([^:/]+):([0-9]+) ]]; then
        RELAYER_HOST="${BASH_REMATCH[1]}"
        RELAYER_PORT="${BASH_REMATCH[2]}"
        
        info "Relayer host: $RELAYER_HOST"
        info "Relayer port: $RELAYER_PORT"
        
        # Test basic connectivity
        if timeout 5 bash -c "</dev/tcp/$RELAYER_HOST/$RELAYER_PORT" 2>/dev/null; then
            success "TCP connectivity to relayer"
        else
            error "Cannot connect to relayer at $RELAYER_HOST:$RELAYER_PORT"
        fi
        
        # Test HTTP health endpoint
        HTTP_URL="http://$RELAYER_HOST:$RELAYER_PORT/health"
        if curl -s --max-time 5 "$HTTP_URL" >/dev/null; then
            success "HTTP health endpoint accessible"
        else
            warning "HTTP health endpoint not accessible: $HTTP_URL"
        fi
        
    else
        warning "Cannot parse relayer URL: $RELAYER_WS_URL"
    fi
else
    error "Cannot load configuration for network test"
fi

echo ""
echo "🔍 8. MODULE IMPORT TEST"
echo "======================="

# Test Python module imports
IMPORT_TEST_SCRIPT="/tmp/provider_import_test.py"
cat > "$IMPORT_TEST_SCRIPT" << 'EOF'
import sys
import os

# Add provider source to path
sys.path.insert(0, '/opt/smainer-provider/provider/src')

try:
    # Test basic imports
    import provider.main
    import provider.config
    import provider.signer
    print("✅ Core modules import successfully")
    
    # Test configuration loading
    from provider.config import get_config
    config = get_config()
    print(f"✅ Configuration loaded (node_id: {config.node_id})")
    
    # Test external dependencies
    import starknet_py
    import websockets
    import psutil
    print("✅ External dependencies import successfully")
    
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
EOF

if sudo -u "$USER" "$INSTALL_DIR/venv/bin/python" "$IMPORT_TEST_SCRIPT"; then
    success "All modules import successfully"
else
    error "Module import test failed"
fi

# Cleanup
rm -f "$IMPORT_TEST_SCRIPT"

echo ""
echo "📊 9. SYSTEM RESOURCE CHECK"
echo "==========================="

# Check available resources
TOTAL_MEM=$(free -h | awk 'NR==2{print $2}')
AVAILABLE_MEM=$(free -h | awk 'NR==2{print $7}')
DISK_USAGE=$(df -h "$INSTALL_DIR" | awk 'NR==2{print $5}')
CPU_CORES=$(nproc)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')

info "Total memory: $TOTAL_MEM"
info "Available memory: $AVAILABLE_MEM"
info "CPU cores: $CPU_CORES"
info "Load average: $LOAD_AVG"
info "Disk usage ($INSTALL_DIR): $DISK_USAGE"

# Check if minimum requirements are met
MEM_GB=$(free -g | awk 'NR==2{print $2}')
if [[ $MEM_GB -ge 4 ]]; then
    success "Memory requirement met (${MEM_GB}GB >= 4GB)"
else
    warning "Low memory: ${MEM_GB}GB (recommended: 4GB+)"
fi

if [[ $CPU_CORES -ge 2 ]]; then
    success "CPU requirement met ($CPU_CORES cores >= 2)"
else
    warning "Low CPU cores: $CPU_CORES (recommended: 2+)"
fi

echo ""
echo "🎯 10. SECURITY CHECK"
echo "===================="

# Check firewall status
if ufw status | grep -q "Status: active"; then
    success "UFW firewall is active"
    
    # Check if required port is allowed
    if ufw status | grep -q "8000"; then
        success "Port 8000 is allowed through firewall"
    else
        warning "Port 8000 not explicitly allowed in firewall"
    fi
else
    warning "UFW firewall is not active"
fi

# Check service file security settings
if grep -q "NoNewPrivileges=true" /etc/systemd/system/smainer-provider.service; then
    success "Security hardening enabled in systemd service"
else
    warning "Security hardening not found in systemd service"
fi

# Check sandbox permissions
SANDBOX_PERMS=$(stat -c "%a" "/var/lib/smainer-provider/sandbox" 2>/dev/null || echo "000")
if [[ "$SANDBOX_PERMS" == "700" ]]; then
    success "Sandbox directory has secure permissions (700)"
else
    warning "Sandbox directory permissions: $SANDBOX_PERMS (recommended: 700)"
fi

echo ""
echo "📋 VERIFICATION SUMMARY"
echo "======================="

echo "Report generated: $(date)"
echo "Log file: $LOG_FILE"
echo ""
echo "📁 Installation Paths:"
echo "   • Provider: $INSTALL_DIR"
echo "   • Config: $CONFIG_FILE"
echo "   • Logs: /var/log/smainer-provider"
echo "   • Sandbox: /var/lib/smainer-provider/sandbox"
echo ""
echo "🔧 Management Commands:"
echo "   • Start daemon: provider-daemon start"
echo "   • Stop daemon: provider-daemon stop"
echo "   • Check status: provider-daemon status"
echo "   • View logs: provider-daemon logs"
echo "   • Emergency kill: provider-daemon kill"
echo ""
echo "📊 Next Steps:"
echo "1. Review any errors or warnings above"
echo "2. Start the daemon: sudo provider-daemon start"
echo "3. Monitor logs: sudo provider-daemon logs"
echo "4. Check connectivity with relayer"
echo ""
echo "✅ Verification completed!"

# Make log file readable by user
chown "$USER:$USER" "$LOG_FILE" 2>/dev/null || true

echo ""
echo "Share this log file for support: $LOG_FILE"