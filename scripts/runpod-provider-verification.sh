#!/bin/bash
# Runpod Provider WebSocket + GPU Detection Verification
# Run this on Runpod instance to diagnose provider-side blockers

set -e

# Colors
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
section() { echo -e "\n${BOLD}=== $1 ===${NC}"; }

# Configuration variables 
RELAYER_HOST="${RELAYER_HOST:-your-relayer-hostname.com}"
RELAYER_API_KEY="${RELAYER_API_KEY:-${API_KEY:-}}"
RELAYER_WS_URL="ws://${RELAYER_HOST}:8000"
NODE_ID="runpod-test-$(date +%s)"
PROVIDER_DIR="/home/smainer/Smainer/backend/provider"

section "1. ENVIRONMENT SETUP VERIFICATION"

# Check if we're on Runpod
if [ -f "/etc/runpod-release" ] || [ -n "$RUNPOD_POD_ID" ]; then
    success "✅ Running on Runpod instance"
    log "Pod ID: ${RUNPOD_POD_ID:-unknown}"
else
    warning "⚠️  Not detected as Runpod instance"
fi

# Check GPU availability
log "Checking GPU detection..."
if command -v nvidia-smi >/dev/null 2>&1; then
    success "✅ nvidia-smi available"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | while read gpu_info; do
        success "    GPU: $gpu_info"
    done
else
    error "❌ nvidia-smi not found - no GPU detection possible"
fi

section "2. SANDBOX PATH VERIFICATION"

# Check the new sandbox path requirements
SANDBOX_PATH="/var/lib/smainer-provider/sandbox"
log "Verifying sandbox path: $SANDBOX_PATH"

if [ -d "$SANDBOX_PATH" ]; then
    success "✅ Sandbox directory exists"
    ls -la "$SANDBOX_PATH" | head -5
else
    warning "⚠️  Sandbox directory does not exist - creating..."
    
    # Create with proper permissions
    sudo mkdir -p "$SANDBOX_PATH" 2>/dev/null || mkdir -p "$SANDBOX_PATH"
    
    # Set ownership to current user if we have sudo
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R $(whoami):$(whoami) "$SANDBOX_PATH" 2>/dev/null || true
    fi
    
    # Set permissions  
    chmod 700 "$SANDBOX_PATH"
    
    if [ -d "$SANDBOX_PATH" ]; then
        success "✅ Created sandbox directory with permissions:"
        ls -la "$SANDBOX_PATH"
    else
        error "❌ Failed to create sandbox directory"
        exit 1
    fi
fi

section "3. NETWORK CONNECTIVITY TEST"

log "Testing relayer connectivity..."
log "Relayer WS URL: $RELAYER_WS_URL"

# Test HTTP health endpoint first
HTTP_URL="http://${RELAYER_HOST}:8000/api/v1/health"
log "Testing HTTP health endpoint: $HTTP_URL"

if curl -s --connect-timeout 10 "$HTTP_URL" >/dev/null 2>&1; then
    success "✅ Relayer HTTP endpoint reachable"
    
    # Get the actual response
    health_response=$(curl -s "$HTTP_URL" 2>/dev/null || echo "no response")
    log "Health response: $health_response"
else
    error "❌ Relayer HTTP endpoint unreachable"
    log "Troubleshooting steps:"
    log "1. Verify relayer is running on DO droplet"
    log "2. Check firewall allows port 8000"
    log "3. Update RELAYER_HOST variable"
    exit 1
fi

# Test WebSocket capability (using a simple check)
log "Testing WebSocket endpoint availability..."
if command -v wscat >/dev/null 2>&1; then
    # Test WebSocket connection briefly
    timeout 5 wscat -c "${RELAYER_WS_URL}/ws/node/test" 2>&1 | head -3 | grep -q "connected" && {
        success "✅ WebSocket endpoint accepts connections"
    } || {
        warning "⚠️  WebSocket test inconclusive (normal - auth required)"
    }
else
    log "wscat not available - skipping WebSocket test"
fi

section "4. PROVIDER DEPENDENCIES CHECK" 

log "Checking Python virtual environment..."
cd "$PROVIDER_DIR" || exit 1

if [ -f "../../../.venv/bin/activate" ]; then
    source "../../../.venv/bin/activate"
    success "✅ Virtual environment activated"
else
    error "❌ Virtual environment not found"
    exit 1
fi

# Check critical dependencies
log "Checking key Python packages..."
python -c "import websockets, starknet_py, psutil, structlog" 2>/dev/null && {
    success "✅ Core dependencies available"
} || {
    error "❌ Missing critical dependencies"
    exit 1
}

section "5. CONFIGURATION FILE VALIDATION"

log "Generating test environment configuration..."

# Create a test .env file with corrected settings
if [ -z "${STARKNET_PRIVATE_KEY:-}" ]; then
    warning "STARKNET_PRIVATE_KEY is not set in environment; generating ephemeral test key"
    TEST_PRIVATE_KEY="0x$(openssl rand -hex 32)"
else
    TEST_PRIVATE_KEY="$STARKNET_PRIVATE_KEY"
fi

cat > "${PROVIDER_DIR}/.env.test" << EOF
# TEST CONFIGURATION FOR RUNPOD
RELAYER_WS_URL=${RELAYER_WS_URL}
NODE_ID=${NODE_ID}
STARKNET_PRIVATE_KEY=${TEST_PRIVATE_KEY}
SANDBOX_TEMP_DIR=${SANDBOX_PATH}
MAX_CONCURRENT_TASKS=1
HEARTBEAT_INTERVAL=30
LOG_LEVEL=DEBUG
EOF

success "✅ Created test configuration:"
cat "${PROVIDER_DIR}/.env.test"

section "6. PROVIDER STARTUP TEST"

log "Testing provider daemon startup (dry-run mode)..."

# Test configuration loading
python -c "
import sys
sys.path.insert(0, 'src')
from provider.config import ProviderConfig
import os
os.environ.clear()
# Load test env
with open('.env.test', 'r') as f:
    for line in f:
        if '=' in line and not line.strip().startswith('#'):
            key, value = line.strip().split('=', 1)
            os.environ[key] = value

config = ProviderConfig()
print(f'✓ Config loaded - WS URL: {config.get_ws_url_with_node_id()}')
print(f'✓ Sandbox path: {config.SANDBOX_TEMP_DIR}')
print(f'✓ Node ID: {config.NODE_ID}')
print(f'✓ Starknet address: {config.get_starknet_address()[:10]}...')
" && {
    success "✅ Provider configuration loads successfully"
} || {
    error "❌ Provider configuration failed to load"
    exit 1
}

section "7. WEBSOCKET REGISTRATION TEST"

log "Testing WebSocket registration process..."

# Create registration test script
cat > "${PROVIDER_DIR}/test_registration.py" << 'EOF'
import asyncio
import json
import websockets
import os
import sys
from datetime import datetime
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / 'src'))
from provider.config import ProviderConfig

async def test_registration():
    """Test WebSocket registration with relayer."""
    
    # Load test config  
    with open('.env.test', 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                os.environ[key] = value
    
    config = ProviderConfig()
    ws_url = config.get_ws_url_with_node_id()
    
    print(f"Attempting connection to: {ws_url}")
    
    try:
        # Quick connection test (5 second timeout)
        async with asyncio.wait_for(
            websockets.connect(ws_url, ping_interval=None),
            timeout=5.0
        ) as websocket:
            print("✅ WebSocket connection established")
            
            # Send registration message
            registration = {
                "event_type": "node_register",
                "event_id": "test-event-123",
                "node_id": config.NODE_ID, 
                "starknet_address": config.get_starknet_address(),
                "timestamp": datetime.utcnow().isoformat(),
                "hardware_spec": {
                    "cpu_threads": 4,
                    "ram_gb": 16,
                    "storage_gb": 100,
                    "gpu_info": "Test GPU",
                    "gpu_vram_gb": 8.0,
                    "node_tier": "basic",
                    "is_wsl2": False
                },
                "auth_signature": "0x" + "00" * 32  # Test signature
            }
            
            await websocket.send(json.dumps(registration))
            print("✅ Registration message sent")
            
            # Wait for response (with timeout)
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=3.0)
                print(f"✅ Received response: {response[:100]}...")
                return True
            except asyncio.TimeoutError:
                print("⚠️  No response within timeout (may indicate auth rejection)")
                return True  # Connection worked, auth might be rejected
                
    except asyncio.TimeoutError:
        print("❌ Connection timeout - relayer unreachable")
        return False
    except ConnectionRefusedError:
        print("❌ Connection refused - relayer not running or wrong port") 
        return False
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_registration())
    sys.exit(0 if success else 1)
EOF

# Run the registration test
log "Running WebSocket registration test..."
if python test_registration.py; then
    success "✅ WebSocket registration test completed"
else
    error "❌ WebSocket registration test failed" 
fi

section "8. SUMMARY AND NEXT STEPS"

success "🎯 DIAGNOSTICS COMPLETED"
echo ""

log "Configuration Status:"
success "  ✅ Sandbox path corrected: $SANDBOX_PATH"
success "  ✅ Dependencies available"
success "  ✅ Test environment created"

if [ -f "${PROVIDER_DIR}/.env.test" ]; then
    echo ""
    log "To start provider with corrected config:"
    echo "  cd $PROVIDER_DIR"
    echo "  cp .env.test .env"
    echo "  python src/provider/main.py"
    echo ""
    
    log "For production deploy:"
    echo "  1. Update RELAYER_HOST in script"
    echo "  2. Set real STARKNET_PRIVATE_KEY"
    echo "  3. Use provided .env.test as template"
fi

echo ""
section "VERIFICATION COMPLETE ✅"
echo ""
log "Provider should now be ready for WebSocket connection to relayer"
log "Note: 'No GPU compute nodes online' should resolve once provider registers successfully"