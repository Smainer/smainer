#!/bin/bash
# Smainer Stack Launcher - Redis + Relayer + Provider
# One-shot operational script for local/live-test bring-up
# Enforces half-hardware resource limits and secret validation

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Project paths
PROJECT_ROOT="/home/smainer/Smainer"
LOGS_DIR="$PROJECT_ROOT/logs"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
PROVIDER_DIR="$PROJECT_ROOT/backend/provider"
RELAYER_DIR="$PROJECT_ROOT/backend/relayer"

# PID file tracking
REDIS_PID_FILE="/tmp/smainer-redis.pid"
RELAYER_PID_FILE="/tmp/smainer-relayer.pid"
PROVIDER_PID_FILE="/tmp/smainer-provider.pid"

# Runtime Redis connection URL used by relayer startup
REDIS_CONNECTION_URL=""

# Resource limits (auto-detect half hardware)
detect_hardware_limits() {
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_mb=$((total_memory_kb / 1024))
    local half_memory_mb=$((total_memory_mb / 2))
    
    local cpu_cores=$(nproc)
    local half_cores=$((cpu_cores / 2))
    if [ $half_cores -eq 0 ]; then half_cores=1; fi
    
    # Redis gets 25% of total memory
    REDIS_MAX_MEMORY=$((total_memory_mb / 4))M
    
    # Relayer gets remaining memory with some buffer
    RELAYER_MAX_MEMORY=$((half_memory_mb - 256))M
    
    # Provider gets half cores for task execution
    PROVIDER_MAX_TASKS=$half_cores
    
    log_info "Hardware detected: ${cpu_cores} cores, ${total_memory_mb}MB RAM"
    log_info "Resource allocation: Redis=${REDIS_MAX_MEMORY}, Relayer=${RELAYER_MAX_MEMORY}, Provider=${PROVIDER_MAX_TASKS} tasks"
}

# Secret validation without exposure
validate_secrets() {
    log_info "Validating required secrets..."
    
    local missing_secrets=()
    
    # Check Redis password
    if [ -z "${REDIS_PASSWORD:-}" ]; then
        missing_secrets+=("REDIS_PASSWORD")
    elif [ ${#REDIS_PASSWORD} -lt 12 ]; then
        log_warning "REDIS_PASSWORD appears weak (less than 12 characters)"
    fi
    
    # Check Relayer private key
    if [ -z "${RELAYER_PRIVATE_KEY:-}" ]; then
        missing_secrets+=("RELAYER_PRIVATE_KEY")
    elif [[ ! "$RELAYER_PRIVATE_KEY" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        log_error "RELAYER_PRIVATE_KEY format invalid (must be 0x + 64 hex chars)"
        exit 1
    fi
    
    # Check Provider private key  
    if [ -z "${STARKNET_PRIVATE_KEY:-}" ]; then
        missing_secrets+=("STARKNET_PRIVATE_KEY")
    elif [[ ! "$STARKNET_PRIVATE_KEY" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        log_error "STARKNET_PRIVATE_KEY format invalid (must be 0x + 64 hex chars)"
        exit 1
    fi
    
    # Check API key
    if [ -z "${API_KEY:-}" ]; then
        missing_secrets+=("API_KEY")
    elif [ ${#API_KEY} -lt 16 ]; then
        log_warning "API_KEY appears weak (less than 16 characters)"
    fi
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        log_error "Missing required secrets: ${missing_secrets[*]}"
        log_error "Set these environment variables before running:"
        for secret in "${missing_secrets[@]}"; do
            echo "export $secret='<set-in-env>'"
        done
        exit 1
    fi
    
    log_success "All required secrets present and valid format"
}

# Setup logging directory
setup_logging() {
    mkdir -p "$LOGS_DIR"
    log_info "Logs directory prepared: $LOGS_DIR"
}

# Start Redis with resource limits
start_redis() {
    log_info "Starting Redis with ${REDIS_MAX_MEMORY} memory limit..."

    # If Redis is already running on 6379 (e.g. system service), reuse it.
    if ss -tuln 2>/dev/null | grep -q ":6379"; then
        local existing_redis_pid
        existing_redis_pid=$(pgrep -f "redis-server.*127.0.0.1:6379" | head -n1 || true)

        if redis-cli ping >/dev/null 2>&1; then
            REDIS_CONNECTION_URL="redis://localhost:6379/0"
            if [ -n "$existing_redis_pid" ]; then
                echo "$existing_redis_pid" > "$REDIS_PID_FILE"
            fi
            log_warning "Detected existing Redis on 6379 without auth; reusing system Redis"
            return 0
        fi

        if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
            REDIS_CONNECTION_URL="redis://:${REDIS_PASSWORD}@localhost:6379/0"
            if [ -n "$existing_redis_pid" ]; then
                echo "$existing_redis_pid" > "$REDIS_PID_FILE"
            fi
            log_warning "Detected existing Redis on 6379 with auth; reusing system Redis"
            return 0
        fi

        log_error "Redis is already listening on 6379 but is not accessible with current configuration"
        return 1
    fi
    
    # Kill any existing Redis
    if [ -f "$REDIS_PID_FILE" ]; then
        local old_pid=$(cat "$REDIS_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warning "Stopping existing Redis (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$REDIS_PID_FILE"
    fi
    
    # Start Redis with memory limit and auth
    redis-server \
        --daemonize yes \
        --pidfile "$REDIS_PID_FILE" \
        --logfile "$LOGS_DIR/redis.log" \
        --maxmemory "$REDIS_MAX_MEMORY" \
        --maxmemory-policy allkeys-lru \
        --requirepass "$REDIS_PASSWORD" \
        --appendonly yes \
        --dir "$LOGS_DIR" \
        --port 6379 \
        --bind 127.0.0.1
    
    # Wait for startup
    sleep 2
    
    # Verify Redis is running
    if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        REDIS_CONNECTION_URL="redis://:${REDIS_PASSWORD}@localhost:6379/0"
        log_success "Redis started successfully"
        return 0
    else
        log_error "Redis failed to start properly"
        return 1
    fi
}

# Start Relayer with Python virtual environment
start_relayer() {
    log_info "Starting Relayer with ${RELAYER_MAX_MEMORY} memory limit..."
    
    # Kill any existing Relayer
    if [ -f "$RELAYER_PID_FILE" ]; then
        local old_pid=$(cat "$RELAYER_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warning "Stopping existing Relayer (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$RELAYER_PID_FILE"
    fi
    
    # Activate Python environment
    source "$PROJECT_ROOT/.venv/bin/activate"
    
    cd "$RELAYER_DIR"
    
    # Set environment variables
    if [ -n "$REDIS_CONNECTION_URL" ]; then
        export REDIS_URL="$REDIS_CONNECTION_URL"
    else
        export REDIS_URL="redis://:${REDIS_PASSWORD}@localhost:6379/0"
    fi
    export HOST="0.0.0.0"
    export PORT="8000"
    export WORKERS="1"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export STARKNET_RPC_URL="${STARKNET_RPC_URL:-https://free-rpc.nethermind.io/mainnet-juno}"
    export CONTRACT_ADDRESS="${CONTRACT_ADDRESS:-0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe}"
    export CORS_ORIGINS="${CORS_ORIGINS:-*}"
    export ENABLE_BATCH_SUBMISSION="${ENABLE_BATCH_SUBMISSION:-false}"
    
    # Start Relayer with resource limits using systemd-run if available
    if command -v systemd-run >/dev/null 2>&1; then
        systemd-run \
            --user \
            --scope \
            --property=MemoryMax="$RELAYER_MAX_MEMORY" \
            --property=TasksMax=50 \
            python -m uvicorn src.relayer.main:app --host 0.0.0.0 --port 8000 \
            > "$LOGS_DIR/relayer.log" 2>&1 &
        echo $! > "$RELAYER_PID_FILE"
    else
        # Fallback without systemd
        python -m uvicorn src.relayer.main:app --host 0.0.0.0 --port 8000 \
            > "$LOGS_DIR/relayer.log" 2>&1 &
        echo $! > "$RELAYER_PID_FILE"
    fi
    
    # Wait for startup and verify
    log_info "Waiting for Relayer to be ready..."
    for i in {1..30}; do
        if curl -s "http://localhost:8000/api/v1/health" >/dev/null 2>&1; then
            log_success "Relayer started successfully and health check passed"
            return 0
        fi
        sleep 1
    done
    
    log_error "Relayer failed to start or health check failed"
    return 1
}

# Start Provider daemon
start_provider() {
    log_info "Starting Provider daemon with ${PROVIDER_MAX_TASKS} max concurrent tasks..."
    
    # Kill any existing Provider
    if [ -f "$PROVIDER_PID_FILE" ]; then
        local old_pid=$(cat "$PROVIDER_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warning "Stopping existing Provider (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$PROVIDER_PID_FILE"
    fi
    
    # Activate Python environment
    source "$PROJECT_ROOT/.venv/bin/activate"
    
    cd "$PROVIDER_DIR"
    
    # Set environment variables
    export RELAYER_WS_URL="ws://localhost:8000"
    export NODE_ID="${NODE_ID:-smainer-provider-$(hostname)-$(date +%s)}"
    export MAX_CONCURRENT_TASKS="$PROVIDER_MAX_TASKS"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export SANDBOX_TEMP_DIR="${SANDBOX_TEMP_DIR:-/tmp/provider_sandbox_$(whoami)}"
    export RESOURCE_MONITORING_INTERVAL="${RESOURCE_MONITORING_INTERVAL:-1.0}"
    export DEFAULT_CPU_TIME_LIMIT="${DEFAULT_CPU_TIME_LIMIT:-300}"
    export DEFAULT_MEMORY_LIMIT="${DEFAULT_MEMORY_LIMIT:-512}"
    
    # Create sandbox directory
    mkdir -p "$SANDBOX_TEMP_DIR"
    chmod 755 "$SANDBOX_TEMP_DIR"
    
    # Start Provider
    python -m provider.main > "$LOGS_DIR/provider.log" 2>&1 &
    echo $! > "$PROVIDER_PID_FILE"
    
    # Wait briefly to check if it starts
    sleep 3
    
    if [ -f "$PROVIDER_PID_FILE" ] && kill -0 "$(cat "$PROVIDER_PID_FILE")" 2>/dev/null; then
        log_success "Provider daemon started successfully"
        log_info "Node ID: $NODE_ID"
        return 0
    else
        log_error "Provider daemon failed to start"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    log_info "🚀 Smainer Stack Launcher"
    echo "========================================="
    
    # Pre-flight checks
    detect_hardware_limits
    validate_secrets
    setup_logging
    
    # Check if Python venv exists
    if [ ! -f "$PROJECT_ROOT/.venv/bin/activate" ]; then
        log_error "Python virtual environment not found at $PROJECT_ROOT/.venv"
        log_error "Run: python -m venv $PROJECT_ROOT/.venv && source $PROJECT_ROOT/.venv/bin/activate && pip install -e ."
        exit 1
    fi
    
    echo ""
    log_info "Starting services in sequence..."
    
    # Start Redis first
    if ! start_redis; then
        log_error "Failed to start Redis - aborting"
        exit 1
    fi
    
    # Start Relayer (depends on Redis)
    if ! start_relayer; then
        log_error "Failed to start Relayer - stopping Redis and aborting"
        if [ -f "$REDIS_PID_FILE" ]; then
            kill "$(cat "$REDIS_PID_FILE")" 2>/dev/null || true
        fi
        exit 1
    fi
    
    # Start Provider (depends on Relayer)
    if ! start_provider; then
        log_error "Failed to start Provider - stopping all services and aborting"
        [ -f "$RELAYER_PID_FILE" ] && kill "$(cat "$RELAYER_PID_FILE")" 2>/dev/null || true
        [ -f "$REDIS_PID_FILE" ] && kill "$(cat "$REDIS_PID_FILE")" 2>/dev/null || true
        exit 1
    fi
    
    echo ""
    log_success "🎉 All Smainer stack components started successfully!"
    echo ""
    echo "📊 Service Status:"
    echo "   Redis:    Running (PID: $(cat "$REDIS_PID_FILE" 2>/dev/null || echo 'N/A'))"
    echo "   Relayer:  Running (PID: $(cat "$RELAYER_PID_FILE" 2>/dev/null || echo 'N/A')) - http://localhost:8000"
    echo "   Provider: Running (PID: $(cat "$PROVIDER_PID_FILE" 2>/dev/null || echo 'N/A'))"
    echo ""
    echo "📝 Logs location: $LOGS_DIR"
    echo ""
    echo "🔧 Management commands:"
    echo "   Verify:   $SCRIPTS_DIR/verify-smainer-stack.sh"
    echo "   Stop:     $SCRIPTS_DIR/stop-smainer-stack.sh"
    echo "   Monitor:  tail -f $LOGS_DIR/*.log"
    echo ""
}

# Cleanup function for interrupts
cleanup() {
    echo ""
    log_warning "Received interrupt signal - stopping services..."
    [ -f "$PROVIDER_PID_FILE" ] && kill "$(cat "$PROVIDER_PID_FILE")" 2>/dev/null || true
    [ -f "$RELAYER_PID_FILE" ] && kill "$(cat "$RELAYER_PID_FILE")" 2>/dev/null || true  
    [ -f "$REDIS_PID_FILE" ] && kill "$(cat "$REDIS_PID_FILE")" 2>/dev/null || true
    exit 1
}

trap cleanup INT TERM

# Execute main function
main "$@"