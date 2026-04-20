#!/bin/bash
# IMMEDIATE PRE-LAUNCH SECRET VERIFICATION 
# Fast version for war room - under 60 seconds execution
set -e

echo "🔒 IMMEDIATE PRE-LAUNCH SECRET CHECK"
echo "Execution: $(date)"

CRITICAL_FAILURE=0
cd /home/smainer/Smainer

# 1. CRITICAL: Hardcoded private keys in codebase
echo -n "1. Scanning codebase for hardcoded secrets..."
if git grep -q -E "(private_key|PRIVATE_KEY|secret_key).*=.*(0x[a-fA-F0-9]{64}|[a-fA-F0-9]{64})" -- ':!test*' ':!*.example' ':!node_modules' 2>/dev/null; then
    echo " 🚨 CRITICAL FAILURE - PRIVATE KEYS DETECTED"
    CRITICAL_FAILURE=1
elif git grep -q -E "(api_key|API_KEY|token|TOKEN).*=.*['\"][a-zA-Z0-9_-]{20,}['\"]" -- ':!test*' ':!*.example' ':!node_modules' 2>/dev/null; then
    echo " 🚨 CRITICAL FAILURE - API KEYS DETECTED" 
    CRITICAL_FAILURE=1
else
    echo " ✅ CLEAN" 
fi

# 2. CRITICAL: File permissions on sensitive files
echo -n "2. Checking sensitive file permissions..."
PERM_ISSUES=$(find . \( -name "*.env" -o -name "*.key" -o -name "*accounts.json" -o -name "*.pem" \) \
              -not -path "*/node_modules/*" -not -path "*/target/*" \
              -perm /o+w 2>/dev/null | wc -l)
if [[ "$PERM_ISSUES" -gt 0 ]]; then
    echo " 🚨 CRITICAL FAILURE - $PERM_ISSUES WORLD-WRITABLE FILES"
    CRITICAL_FAILURE=1
else
    echo " ✅ SECURE"
fi

# 3. CRITICAL: Secrets in logs and temp files
echo -n "3. Checking logs and temp files for secrets..."
SECRET_LOG_COUNT=0
if find . -name "*.log" | xargs grep -l -E "((api_key|token|private_key|secret)[=:][^[:space:]]{16,}|(api_key|token|private_key|secret).*(0x[a-fA-F0-9]{64}))" 2>/dev/null | grep -q .; then
    SECRET_LOG_COUNT=$((SECRET_LOG_COUNT + 1))
fi
if find /tmp \( -name "*smainer*" -o -name "*provider*" -o -name "*relayer*" \) -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.out" \) 2>/dev/null | xargs grep -l -E "((api_key|token|private_key|secret)[=:][^[:space:]]{16,}|(api_key|token|private_key|secret).*(0x[a-fA-F0-9]{64}))" 2>/dev/null | grep -q .; then
    SECRET_LOG_COUNT=$((SECRET_LOG_COUNT + 1))
fi
if [[ "$SECRET_LOG_COUNT" -gt 0 ]]; then
    echo " 🚨 CRITICAL FAILURE - SECRETS IN LOGS/TEMP"
    CRITICAL_FAILURE=1
else
    echo " ✅ CLEAN"
fi

# 4. CRITICAL: Environment exposure
echo -n "4. Checking environment security..."
if env | grep -E "(PRIVATE_KEY|API_KEY|TOKEN)" | grep -v "not_set\|unset\|REDACTED" >/dev/null 2>&1; then
    echo " ⚠️  WARNING - Environment variables visible"
else
    echo " ✅ CLEAN"
fi

# 5. SERVICE READINESS: Basic config validation
echo -n "5. Validating service configurations..."
CONFIG_ISSUES=0

# Relayer
if ! cd backend/relayer && python -c "
import sys
sys.path.insert(0, 'src')
from relayer.config import settings
assert hasattr(settings, 'api_key') and settings.api_key and len(str(settings.api_key)) >= 16
" >/dev/null 2>&1; then
    CONFIG_ISSUES=1
fi

# Provider  
if ! cd ../provider && python -c "
import sys
sys.path.insert(0, 'src')  
from provider.config import ProviderConfig
config = ProviderConfig()
assert hasattr(config, 'STARKNET_PRIVATE_KEY') and config.STARKNET_PRIVATE_KEY
" >/dev/null 2>&1; then
    CONFIG_ISSUES=1
fi
cd ../..

if [[ $CONFIG_ISSUES -eq 0 ]]; then
    echo " ✅ CONFIGURED"
else
    echo " ❌ CONFIG FAILURES"
    CRITICAL_FAILURE=1
fi

# VERDICT
echo ""
if [[ $CRITICAL_FAILURE -eq 0 ]]; then
    echo "🟢 LAUNCH CLEARED - No critical security issues"
    echo "Run full gates: ./war-room-security-gates.sh"
    exit 0
else  
    echo "🔴 LAUNCH BLOCKED - Critical security failures detected"
    echo "Fix issues above, then run: ./war-room-security-gates.sh"
    exit 1
fi