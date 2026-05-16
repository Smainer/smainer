#!/bin/bash
# Fix Provider Configuration Mismatches
# Addresses sandbox path inconsistencies blocking provider startup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROVIDER_DIR="/home/smainer/Smainer/backend/provider"
SANDBOX_PATH="/var/lib/smainer-provider/sandbox"

echo -e "${BOLD} FIXING PROVIDER CONFIGURATION MISMATCHES${NC}"
echo "=============================================="

cd "$PROVIDER_DIR" || exit 1

# 1. Fix .env.example
log "Updating .env.example with corrected sandbox path..."
sed -i "s|SANDBOX_TEMP_DIR=.*|SANDBOX_TEMP_DIR=${SANDBOX_PATH}|" .env.example
success " Updated .env.example"

# 2. Fix launch_provider.sh
log "Updating launch_provider.sh with corrected sandbox path..."
sed -i "s|SANDBOX_TEMP_DIR=\${SANDBOX_TEMP_DIR:-.*}|SANDBOX_TEMP_DIR=\"\${SANDBOX_TEMP_DIR:-${SANDBOX_PATH}}\"|" launch_provider.sh
success " Updated launch_provider.sh"

# 3. Create production-ready .env template
log "Creating production .env template..."
cat > .env.production-template << EOF
# Production Provider Configuration Template
# Copy to .env and customize before use

# === REQUIRED: Update these for your deployment ===
RELAYER_WS_URL=ws://your-relayer-host.com:8000
NODE_ID=your-unique-node-id-here
STARKNET_PRIVATE_KEY=0xYOUR_64_CHAR_PRIVATE_KEY_HERE

# === SANDBOX CONFIGURATION (Updated Path) ===
SANDBOX_TEMP_DIR=${SANDBOX_PATH}
ENABLE_CUSTOM_TASKS=false

# === PERFORMANCE SETTINGS ===
MAX_CONCURRENT_TASKS=2
HEARTBEAT_INTERVAL=30
LOG_LEVEL=INFO

# === RESOURCE LIMITS ===
DEFAULT_CPU_TIME_LIMIT=300
DEFAULT_MEMORY_LIMIT=512
DEFAULT_TIMEOUT=300

# === CONNECTION SETTINGS ===
RECONNECT_MAX_ATTEMPTS=10
RECONNECT_INITIAL_DELAY=1.0
RECONNECT_MAX_DELAY=60.0
RECONNECT_BACKOFF_MULTIPLIER=2.0

# === MONITORING ===
RESOURCE_MONITORING_INTERVAL=1.0
EOF

success " Created .env.production-template"

# 4. Create sandbox directory setup script
log "Creating sandbox directory setup script..."
cat > setup-sandbox.sh << 'EOF'
#!/bin/bash
# Setup sandbox directory with proper permissions
set -e

SANDBOX_PATH="/var/lib/smainer-provider/sandbox"

echo "Setting up sandbox directory: $SANDBOX_PATH"

# Create directory
sudo mkdir -p "$SANDBOX_PATH" 2>/dev/null || mkdir -p "$SANDBOX_PATH"

# Set ownership to current user (if we have sudo)
if command -v sudo >/dev/null 2>&1; then
    sudo chown -R $(whoami):$(whoami) "$SANDBOX_PATH" 2>/dev/null || {
        echo "Warning: Could not set ownership with sudo"
    }
fi

# Set restrictive permissions
chmod 700 "$SANDBOX_PATH"

echo " Sandbox directory ready: $SANDBOX_PATH"
ls -la "$SANDBOX_PATH"
EOF

chmod +x setup-sandbox.sh
success " Created setup-sandbox.sh"

# 5. Validate configuration loading
log "Testing updated configuration loading..."
python3 -c "
import sys
sys.path.insert(0, 'src')
from provider.config import ProviderConfig

print('Testing default configuration...')
config = ProviderConfig()
print(f' Sandbox path: {config.SANDBOX_TEMP_DIR}')
print(f' Max tasks: {config.MAX_CONCURRENT_TASKS}')
print(' Configuration loads successfully')
" && success " Configuration validation passed" || error " Configuration validation failed"

echo ""
echo -e "${BOLD} CONFIGURATION FIXES COMPLETE${NC}"
echo "================================="
echo ""

success "Fixed files:"
success "   .env.example - corrected sandbox path"  
success "   launch_provider.sh - corrected default sandbox"
success "   .env.production-template - ready for deployment"
success "   setup-sandbox.sh - sandbox directory setup"

echo ""
log "Next steps for deployment:"
echo "  1. Run: ./setup-sandbox.sh"
echo "  2. Copy: cp .env.production-template .env"
echo "  3. Edit: nano .env (set RELAYER_WS_URL, NODE_ID, STARKNET_PRIVATE_KEY)"
echo "  4. Test: ./launch_provider.sh"

echo ""
warning "  Remember to update:"
warning "     - RELAYER_WS_URL with your DO droplet hostname"
warning "     - NODE_ID with unique identifier" 
warning "     - STARKNET_PRIVATE_KEY with real private key"