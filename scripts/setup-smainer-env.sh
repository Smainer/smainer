#!/bin/bash
# Smainer Stack Environment Setup
# Generates .env templates and validates environment configuration

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
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

# Generate secure random values
generate_redis_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_api_key() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

generate_callback_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Generate .env file template
generate_env_template() {
    local env_file="${1:-$PROJECT_ROOT/.env.smainer-stack}"
    
    log_info "Generating environment template: $env_file"
    
    cat > "$env_file" <<EOF
# Smainer Stack Environment Configuration
# Generated on: $(date)
# 
# SECURITY NOTICE:
# - Replace ALL placeholder values before production use
# - Never commit this file with real secrets to version control
# - Use strong, unique values for all passwords and keys

# ============================================================================
# REDIS CONFIGURATION
# ============================================================================
# Redis password for authentication (minimum 12 characters)
REDIS_PASSWORD=$(generate_redis_password)

# ============================================================================
# STARKNET CONFIGURATION 
# ============================================================================
# Starknet RPC endpoint (Mainnet)
STARKNET_RPC_URL=https://free-rpc.nethermind.io/mainnet-juno

# Contract address (Smainer main contract on Mainnet)
CONTRACT_ADDRESS=0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe

# REQUIRED: Replace with your actual private keys
# Format: 0x followed by 64 hexadecimal characters
RELAYER_PRIVATE_KEY=\${RELAYER_PRIVATE_KEY:-REPLACE_WITH_YOUR_RELAYER_PRIVATE_KEY}
STARKNET_PRIVATE_KEY=\${STARKNET_PRIVATE_KEY:-REPLACE_WITH_YOUR_STARKNET_PRIVATE_KEY}

# ============================================================================
# API CONFIGURATION
# ============================================================================
# Strong random API key for Relayer authentication
API_KEY=$(generate_api_key)

# Callback signing secret for webhook validation
CALLBACK_SIGNING_SECRET=$(generate_callback_secret)

# Allowed hosts for callbacks (comma-separated)
CALLBACK_ALLOWED_HOSTS=api.smainer.io,bot.smainer.io

# CORS origins (comma-separated, use * for development only)
CORS_ORIGINS=https://smainer.io,https://app.smainer.io

# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================
# Unique node identifier
NODE_ID=smainer-provider-\$(hostname)-\$(date +%s)

# Resource limits (auto-detected by launch script, can override)  
MAX_CONCURRENT_TASKS=2

# Sandbox settings
SANDBOX_TEMP_DIR=/tmp/provider_sandbox_\$(whoami)
ENABLE_CUSTOM_TASKS=false

# Performance monitoring
RESOURCE_MONITORING_INTERVAL=1.0
DEFAULT_CPU_TIME_LIMIT=300
DEFAULT_MEMORY_LIMIT=512
DEFAULT_TIMEOUT=300

# Connection settings
HEARTBEAT_INTERVAL=30
RECONNECT_MAX_ATTEMPTS=10
RECONNECT_INITIAL_DELAY=1.0
RECONNECT_MAX_DELAY=60.0
RECONNECT_BACKOFF_MULTIPLIER=2.0

# ============================================================================
# RELAYER CONFIGURATION
# ============================================================================
# Task management
TASK_TIMEOUT_SECONDS=300
BATCH_INTERVAL_SECONDS=60
MAX_BATCH_SIZE=10

# Node management
NODE_HEARTBEAT_TIMEOUT=90

# Feature flags
ENABLE_BATCH_SUBMISSION=false

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================
# Log level (DEBUG, INFO, WARNING, ERROR)
LOG_LEVEL=INFO

# ============================================================================
# DEVELOPMENT/TEST OVERRIDES
# ============================================================================
# Uncomment and modify for local testing:
# STARKNET_RPC_URL=https://free-rpc.nethermind.io/goerli-juno
# CONTRACT_ADDRESS=0x_YOUR_TEST_CONTRACT_ADDRESS
# CORS_ORIGINS=*
# LOG_LEVEL=DEBUG
EOF

    log_success "Environment template generated"
    log_warning "IMPORTANT: Edit $env_file and replace placeholder private keys before use!"
}

# Validate environment
validate_environment() {
    local env_file="${1:-$PROJECT_ROOT/.env.smainer-stack}"
    
    if [ ! -f "$env_file" ]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    log_info "Validating environment configuration..."
    
    # Source the env file for validation
    set -a
    source "$env_file"
    set +a
    
    local validation_errors=0
    
    # Check required secrets
    if [ "${REDIS_PASSWORD:-}" = "" ] || [ ${#REDIS_PASSWORD} -lt 12 ]; then
        log_error "REDIS_PASSWORD missing or too short (minimum 12 characters)"
        validation_errors=$((validation_errors + 1))
    fi
    
    if [ "${API_KEY:-}" = "" ] || [ ${#API_KEY} -lt 16 ]; then
        log_error "API_KEY missing or too short (minimum 16 characters)"  
        validation_errors=$((validation_errors + 1))
    fi
    
    if [ "${CALLBACK_SIGNING_SECRET:-}" = "" ] || [ ${#CALLBACK_SIGNING_SECRET} -lt 16 ]; then
        log_error "CALLBACK_SIGNING_SECRET missing or too short (minimum 16 characters)"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check private key format
    if [[ ! "${RELAYER_PRIVATE_KEY:-}" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        if [[ "${RELAYER_PRIVATE_KEY:-}" =~ REPLACE_WITH_YOUR.*PRIVATE_KEY ]] || [ "${RELAYER_PRIVATE_KEY:-}" = "" ]; then
            log_error "RELAYER_PRIVATE_KEY is placeholder - replace with real private key"
        else
            log_error "RELAYER_PRIVATE_KEY invalid format (must be 0x + 64 hex chars)"
        fi
        validation_errors=$((validation_errors + 1))
    fi
    
    if [[ ! "${STARKNET_PRIVATE_KEY:-}" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        if [[ "${STARKNET_PRIVATE_KEY:-}" =~ REPLACE_WITH_YOUR.*PRIVATE_KEY ]] || [ "${STARKNET_PRIVATE_KEY:-}" = "" ]; then
            log_error "STARKNET_PRIVATE_KEY is placeholder - replace with real private key"
        else
            log_error "STARKNET_PRIVATE_KEY invalid format (must be 0x + 64 hex chars)"
        fi
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check contract address format
    if [[ ! "${CONTRACT_ADDRESS:-}" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        log_error "CONTRACT_ADDRESS invalid format (must be 0x + 64 hex chars)"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check URLs
    if [[ ! "${STARKNET_RPC_URL:-}" =~ ^https?:// ]]; then
        log_error "STARKNET_RPC_URL invalid format (must be http/https URL)"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check numeric values
    if ! [[ "${MAX_CONCURRENT_TASKS:-2}" =~ ^[0-9]+$ ]]; then
        log_error "MAX_CONCURRENT_TASKS must be a positive number"
        validation_errors=$((validation_errors + 1))
    fi
    
    if ! [[ "${HEARTBEAT_INTERVAL:-30}" =~ ^[0-9]+$ ]]; then
        log_error "HEARTBEAT_INTERVAL must be a positive number"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check boolean values
    local boolean_vars=("ENABLE_BATCH_SUBMISSION" "ENABLE_CUSTOM_TASKS")
    for var in "${boolean_vars[@]}"; do
        local value="${!var:-}"
        if [ -n "$value" ] && [[ ! "$value" =~ ^(true|false|True|False|TRUE|FALSE|1|0)$ ]]; then
            log_error "$var must be true/false (got: $value)"
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    # Summary
    if [ $validation_errors -eq 0 ]; then
        log_success "Environment validation passed"
        return 0
    else
        log_error "Environment validation failed with $validation_errors error(s)"
        return 1
    fi
}

# Export current environment for scripts
export_environment() {
    local env_file="${1:-$PROJECT_ROOT/.env.smainer-stack}"
    
    if [ ! -f "$env_file" ]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    log_info "Exporting environment variables for launch scripts..."
    
    # Export to current shell
    set -a
    source "$env_file"
    set +a
    
    log_success "Environment variables loaded from $env_file"
    
    # Show some non-sensitive configuration
    echo ""
    echo "Active Configuration (non-sensitive values):"
    echo "  STARKNET_RPC_URL: $STARKNET_RPC_URL"  
    echo "  CONTRACT_ADDRESS: $CONTRACT_ADDRESS"
    echo "  NODE_ID: ${NODE_ID:-auto-generated}"
    echo "  MAX_CONCURRENT_TASKS: $MAX_CONCURRENT_TASKS"
    echo "  LOG_LEVEL: $LOG_LEVEL"
    echo "  ENABLE_BATCH_SUBMISSION: $ENABLE_BATCH_SUBMISSION"
    echo ""
}

# Quick security check
security_check() {
    log_info "Running security checks..."
    
    local security_issues=0
    
    # Check if we're running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Running as root is not recommended for security"
        security_issues=$((security_issues + 1))
    fi
    
    # Check for world-readable .env files
    find "$PROJECT_ROOT" -name ".env*" -perm /o+r 2>/dev/null | while read -r file; do
        log_warning "Environment file is world-readable: $file"
        log_info "Fix with: chmod 600 $file"
        security_issues=$((security_issues + 1))
    done
    
    # Check for private keys in command history
    if history | grep -i "private.*key\|0x.*64" >/dev/null 2>&1; then
        log_warning "Possible private keys found in command history"
        log_info "Consider clearing history: history -c"
    fi
    
    # Check system ulimits
    local max_open_files=$(ulimit -n)
    if [ "$max_open_files" -lt 1024 ]; then
        log_warning "Low file descriptor limit: $max_open_files (recommended: >=1024)"
        log_info "Fix with: ulimit -n 4096 or increase systemd limits"
    fi
    
    if [ $security_issues -eq 0 ]; then
        log_success "Security checks passed"
    else
        log_warning "Security checks completed with warnings"
    fi
}

# Main command dispatcher
main() {
    echo ""
    log_info "🔧 Smainer Stack Environment Setup"
    echo "========================================="
    echo ""
    
    local command="${1:-help}"
    
    case "$command" in
        "generate"|"gen")
            local env_file="${2:-$PROJECT_ROOT/.env.smainer-stack}"
            generate_env_template "$env_file"
            echo ""
            echo "Next steps:"
            echo "1. Edit $env_file and replace placeholder private keys"
            echo "2. Run: $0 validate $env_file"
            echo "3. Run: source $env_file && scripts/launch-smainer-stack.sh"
            ;;
            
        "validate"|"check")
            local env_file="${2:-$PROJECT_ROOT/.env.smainer-stack}"
            if validate_environment "$env_file"; then
                log_success "Environment is ready for use"
                echo ""
                echo "Ready to launch:"
                echo "  source $env_file && scripts/launch-smainer-stack.sh"
            else
                log_error "Fix validation errors before launching"
                exit 1
            fi
            ;;
            
        "export"|"load")
            local env_file="${2:-$PROJECT_ROOT/.env.smainer-stack}"
            export_environment "$env_file"
            ;;
            
        "security")
            security_check
            ;;
            
        "setup"|"init")
            local env_file="${2:-$PROJECT_ROOT/.env.smainer-stack}"
            generate_env_template "$env_file"
            echo ""
            log_info "Opening $env_file for editing..."
            echo "Please replace ALL placeholder values with real secrets."
            echo ""
            echo "Required changes:"
            echo "1. Set RELAYER_PRIVATE_KEY to your Starknet private key"
            echo "2. Set STARKNET_PRIVATE_KEY to your provider private key"
            echo "3. Verify CONTRACT_ADDRESS and STARKNET_RPC_URL"
            echo "4. Adjust NODE_ID if needed"
            echo ""
            read -p "Press Enter when ready to edit the file..."
            
            # Try to open with editor
            if command -v nano >/dev/null 2>&1; then
                nano "$env_file"
            elif command -v vim >/dev/null 2>&1; then
                vim "$env_file"
            elif command -v vi >/dev/null 2>&1; then
                vi "$env_file"
            else
                log_warning "No editor found. Manually edit: $env_file"
            fi
            
            echo ""
            log_info "Validating your configuration..."
            if validate_environment "$env_file"; then
                log_success "Setup complete!"
                echo ""
                echo "🚀 Ready to launch Smainer stack:"
                echo "   source $env_file && scripts/launch-smainer-stack.sh"
                echo ""
                echo "📋 Other useful commands:"
                echo "   scripts/verify-smainer-stack.sh    # Verify running services"
                echo "   scripts/stop-smainer-stack.sh      # Stop all services"
            else
                log_error "Configuration invalid. Please run: $0 setup"
                exit 1
            fi
            ;;
            
        "help"|--help|-h)
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  generate [file]  Generate .env template with random secrets"
            echo "  validate [file]  Validate existing .env configuration"
            echo "  export [file]    Export .env to current shell environment"
            echo "  security         Run security checks on configuration"
            echo "  setup [file]     Interactive setup (generate + edit + validate)"
            echo "  help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 setup                              # Interactive setup"
            echo "  $0 generate .env.production           # Generate production env"
            echo "  $0 validate .env.test                 # Validate test env"
            echo "  source <(cmp export .env.smainer-stack)  # Load env vars"
            echo ""
            echo "Default env file: $PROJECT_ROOT/.env.smainer-stack"
            ;;
            
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"