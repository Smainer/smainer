#!/bin/bash
# Security Validation Script for Smainer Deployment
# Prevents deployment with dangerous defaults and exposed secrets
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() {
    echo -e "${RED}❌ SECURITY ERROR: $1${NC}"
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}⚠️  SECURITY WARNING: $1${NC}"
    ((WARNINGS++))
}

info() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check for dangerous default values
check_dangerous_defaults() {
    echo "🔍 Checking for dangerous default values..."
    
    # Check for test private keys
    if grep -r "0x00000000.*01$" . --include="*.env*" --exclude-dir=.git 2>/dev/null; then
        error "Test private key detected in environment files"
    fi
    
    # Check for placeholder tokens that weren't replaced
    if grep -r "YOUR_BOT_TOKEN" . --include="*.env*" 2>/dev/null; then
        error "Telegram bot token placeholder not replaced"
    fi
    
    # Check for weak passwords
    if grep -ir "password.*123" . --include="*.env*" --exclude-dir=.git 2>/dev/null; then
        error "Weak password detected"
    fi
    
    if grep -ir "admin.*admin" . --include="*.env*" --exclude-dir=.git 2>/dev/null; then
        error "Default admin credentials detected"
    fi
}

# Check for exposed secrets
check_exposed_secrets() {
    echo "🔍 Checking for exposed secrets..."
    
    # Check for bot tokens in non-env files
    if grep -r "[0-9]\{8,\}:AA[A-Za-z0-9_-]\{35\}" . --exclude-dir=.git --exclude="*.env*" 2>/dev/null; then
        error "Telegram bot token exposed in non-environment files"
    fi
    
    # Check for private keys in source code AND documentation
    if grep -r "0x[a-fA-F0-9]\{64\}" . --include="*.py" --include="*.js" --include="*.ts" --include="*.md" --include="*.rst" --exclude-dir=.git 2>/dev/null; then
        error "Private key found in source code or documentation - NEVER commit private keys!"
    fi
    
    # Check for API keys in source
    if grep -r "sk-[A-Za-z0-9]\{32,\}" . --exclude-dir=.git --exclude="*.env*" 2>/dev/null; then
        error "API key exposed in source files"
    fi
    
    # Check for hardcoded Starknet account addresses that might indicate exposed keys
    if grep -r "STARKNET_PRIVATE_KEY=0x[a-fA-F0-9]" . --include="*.md" --include="*.rst" --include="*.txt" --exclude-dir=.git 2>/dev/null; then
        error "Hardcoded Starknet private key found in documentation"
    fi
}

# Check network configuration consistency
check_network_consistency() {
    echo "🔍 Checking network configuration consistency..."
    
    local mainnet_count=$(grep -c "starknet-mainnet" . -R --include="*.env*" 2>/dev/null || echo 0)
    local sepolia_count=$(grep -c "starknet-sepolia" . -R --include="*.env*" 2>/dev/null || echo 0)
    
    if [[ $mainnet_count -gt 0 && $sepolia_count -gt 0 ]]; then
        error "Mixed mainnet/testnet configuration detected"
    fi
    
    if [[ $sepolia_count -gt $mainnet_count ]]; then
        warn "Using testnet configuration - ensure this is intentional"
    fi
}

# Check file permissions
check_file_permissions() {
    echo "🔍 Checking file permissions..."
    
    # Check for world-readable secret files
    find . -name ".env*" -perm +004 2>/dev/null | while read -r file; do
        warn "Environment file $file is world-readable"
    done
    
    # Check for executable environment files
    find . -name ".env*" -perm +111 2>/dev/null | while read -r file; do
        warn "Environment file $file is executable"
    done
}

# Check deployment script security
check_deployment_security() {
    echo "🔍 Checking deployment script security..."
    
    # Check for unsafe curl usage
    if grep -r "curl.*http://" scripts/ 2>/dev/null; then
        warn "Insecure HTTP requests in deployment scripts"
    fi
    
    # Check for hardcoded domains
    if grep -r "localhost" . --include="docker-compose*.yml" 2>/dev/null | grep -v "127.0.0.1"; then
        warn "Localhost references in production configs"
    fi
}

# Validate required environment variables are set
validate_required_vars() {
    local env_file="${1:-.env.prod}"
    
    if [[ ! -f "$env_file" ]]; then
        error "Environment file $env_file not found"
        return
    fi
    
    echo "🔍 Validating required variables in $env_file..."
    
    local required_vars=(
        "REDIS_PASSWORD"
        "API_KEY" 
        "RELAYER_PRIVATE_KEY"
        "STARKNET_RPC_URL"
        "CONTRACT_ADDRESS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_file"; then
            error "Required variable $var missing from $env_file"
        elif grep -q "^$var=.*REPLACE.*" "$env_file"; then
            error "Variable $var contains placeholder value in $env_file"
        fi
    done
}

# Security recommendations
security_recommendations() {
    echo ""
    echo "🛡️  Security Recommendations:"
    echo "1. Use hardware security modules for private key storage"
    echo "2. Implement key rotation every 90 days"
    echo "3. Enable audit logging for all deployments"
    echo "4. Use least-privilege access controls"
    echo "5. Implement network segmentation"
    echo "6. Regular security scanning and penetration testing"
}

# Main execution
main() {
    echo "🔒 Smainer Security Validation"
    echo "==============================="
    
    check_dangerous_defaults
    check_exposed_secrets  
    check_network_consistency
    check_file_permissions
    check_deployment_security
    
    if [[ -f ".env.prod" ]]; then
        validate_required_vars ".env.prod"
    fi
    
    echo ""
    echo "==============================="
    
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}🚨 $ERRORS critical security errors detected!${NC}"
        echo -e "${RED}Deployment blocked until errors are resolved.${NC}"
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $WARNINGS security warnings detected.${NC}"
        echo -e "${YELLOW}Review warnings before proceeding.${NC}"
        exit 2
    else
        echo -e "${GREEN}✅ No critical security issues detected.${NC}"
        security_recommendations
        exit 0
    fi
}

# Run only if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi