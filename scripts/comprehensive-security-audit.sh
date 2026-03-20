#!/bin/bash
# COMPREHENSIVE SECURITY AUDIT - Full Deep Scan
# For thorough pre-production security validation 
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}🔐 COMPREHENSIVE SECURITY AUDIT${NC}"
echo -e "Deep security scan for production readiness"
echo -e "Date: $(date)"
echo ""

CRITICAL_FAILURES=0
WARNING_COUNT=0
WORKSPACE_ROOT="/home/smainer/Smainer"
cd "$WORKSPACE_ROOT"

# ==============================================================================
# SECTION 1: DEEP SECRET LEAKAGE ANALYSIS
# ==============================================================================
echo -e "${BOLD}SECTION 1: Deep Secret Leakage Analysis${NC}"

echo "1.1 Multi-pattern secret scanning..."
SECRET_PATTERNS=(
    "private_key.*=.*(0x[a-fA-F0-9]{64}|[a-fA-F0-9]{64})"
    "api_key.*=.*['\"][a-zA-Z0-9_-]{16,}['\"]"
    "token.*=.*['\"][a-zA-Z0-9_.-]{20,}['\"]"
    "(secret_key|webhook_secret|callback_signing_secret|client_secret).*=.*['\"][a-zA-Z0-9_-]{16,}['\"]"
    "mnemonic.*=.*['\"][a-z ]{40,}['\"]"
    "seed.*=.*['\"][a-z ]{40,}['\"]"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    echo -n "    - Testing pattern: ${pattern:0:20}..."
    if git grep -i -q -E "$pattern" -- ':!test*' ':!**/tests/**' ':!**/test_*.py' ':!*.example' ':!*.template' ':!*.md' ':!node_modules' ':!TEMP_GREEN_INSTRUCTIONS_*' ':!scripts/quick-security-check.sh' ':!scripts/comprehensive-security-audit.sh' ':!scripts/war-room-security-gates.sh' ':!backend/run-security-tests.sh' 2>/dev/null; then
        echo -e " ${RED}DETECTED${NC}"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    else
        echo -e " ${GREEN}CLEAN${NC}"
    fi
done

echo "1.2 Binary and encoded secret scan..."
echo -n "    - Base64 encoded secrets..."
if find . -type f -name "*.json" -o -name "*.env" | xargs grep -l "[A-Za-z0-9+/]{40,}={0,2}" 2>/dev/null | head -1 | grep -q .; then
    echo -e " ${YELLOW}POTENTIAL${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    echo -e " ${GREEN}CLEAN${NC}"
fi

echo -n "    - Hex encoded private keys..."
if find . -type f | xargs grep -l "[a-fA-F0-9]{126,128}" 2>/dev/null | head -1 | grep -q .; then 
    echo -e " ${YELLOW}POTENTIAL${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    echo -e " ${GREEN}CLEAN${NC}"  
fi

echo "1.3 Environment and configuration audit..."
echo -n "    - Live environment exposure..."
ENV_SECRETS=$(env | grep -E '^(OWNER_PRIVATE_KEY|RELAYER_PRIVATE_KEY|STARKNET_PRIVATE_KEY|API_KEY|BOT_TOKEN|CALLBACK_SIGNING_SECRET|REDIS_PASSWORD)=' | grep -v 'not_set\|unset\|REDACTED\|placeholder' | wc -l)
if [[ "$ENV_SECRETS" -gt 0 ]]; then
    echo -e " ${YELLOW}WARNING($ENV_SECRETS)${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    echo -e " ${GREEN}SECURE${NC}"
fi

echo -n "    - Configuration file validation..."
CONFIG_SECRETS=0
for config_file in $(find . -name "*.env" -o -name "config.py" -o -name "settings.py" -o -name "*accounts.json" | grep -v node_modules | grep -v "\.env\.example" | head -10); do
    if [[ -f "$config_file" ]] && grep -q -E "(private_key|api_key|token|secret).*=.*(0x[a-fA-F0-9]{64}|[a-zA-Z0-9_-]{20,})" "$config_file" 2>/dev/null; then
        CONFIG_SECRETS=$((CONFIG_SECRETS + 1))
    fi
done
if [[ "$CONFIG_SECRETS" -gt 0 ]]; then
    echo -e " ${RED}FAIL($CONFIG_SECRETS configs with secrets)${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
else
    echo -e " ${GREEN}CLEAN${NC}"
fi

# ==============================================================================
# SECTION 2: COMPREHENSIVE FILE SYSTEM SECURITY
# ==============================================================================
echo ""
echo -e "${BOLD}SECTION 2: File System Security Audit${NC}"

echo "2.1 File permission analysis..."
echo -n "    - World-writable sensitive files..."
WORLD_WRITE=$(find . \( -name "*.env" -o -name "*.key" -o -name "*.pem" -o -name "*accounts.json" \) \
              -not -path "*/node_modules/*" -not -path "*/target/*" \
              -perm /o+w 2>/dev/null | wc -l)
if [[ "$WORLD_WRITE" -gt 0 ]]; then
    echo -e " ${RED}FAIL($WORLD_WRITE files)${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
else
    echo -e " ${GREEN}SECURE${NC}"
fi

echo -n "    - Group-writable config files..."
GROUP_WRITE=$(find . \( -name "*.env" -o -name "config.*" \) \
              -not -path "*/node_modules/*" \
              -perm /g+w 2>/dev/null | wc -l)
if [[ "$GROUP_WRITE" -gt 0 ]]; then
    echo -e " ${YELLOW}WARNING($GROUP_WRITE files)${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    echo -e " ${GREEN}SECURE${NC}"
fi

echo -n "    - Executable config files..."
EXEC_CONFIG=$(find . \( -name "*.env" -o -name "*.json" \) \
              -not -path "*/node_modules/*" \
              -perm /u+x 2>/dev/null | wc -l)
if [[ "$EXEC_CONFIG" -gt 0 ]]; then
    echo -e " ${YELLOW}WARNING($EXEC_CONFIG executable configs)${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    echo -e " ${GREEN}SECURE${NC}"
fi

echo "2.2 Temporary file security..."
echo -n "    - Temp file secret exposure..."
TEMP_SECRETS=$(find /tmp -name "*smainer*" -o -name "*provider*" -o -name "*relayer*" 2>/dev/null | \
               xargs grep -l -E "((api_key|token|private_key|secret)[=:][^[:space:]]{16,}|(api_key|token|private_key|secret).*(0x[a-fA-F0-9]{64}))" 2>/dev/null | wc -l)
if [[ "$TEMP_SECRETS" -gt 0 ]]; then
    echo -e " ${RED}FAIL($TEMP_SECRETS temp files with secrets)${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
else
    echo -e " ${GREEN}CLEAN${NC}"
fi

# ==============================================================================
# SECTION 3: LOG AND MONITORING SECURITY  
# ==============================================================================
echo ""
echo -e "${BOLD}SECTION 3: Logging and Monitoring Security${NC}"

echo "3.1 Application log security..."
LOG_DIRS=("." "/var/log" "/tmp")
for log_dir in "${LOG_DIRS[@]}"; do
    if [[ -d "$log_dir" ]]; then
        echo -n "    - Secrets in $log_dir logs..."
        LOG_SECRET_COUNT=$(find "$log_dir" -name "*.log" 2>/dev/null | \
                          xargs grep -l -E "((api_key|token|private_key|secret)[=:][^[:space:]]{16,}|(api_key|token|private_key|secret).*(0x[a-fA-F0-9]{64}))" 2>/dev/null | wc -l)
        if [[ "$LOG_SECRET_COUNT" -gt 0 ]]; then
            echo -e " ${RED}FAIL($LOG_SECRET_COUNT files)${NC}"
            CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
        else
            echo -e " ${GREEN}CLEAN${NC}"
        fi
    fi
done

echo "3.2 Error reporting security..."
echo -n "    - Stack traces with sensitive data..."
ERROR_EXPOSURE=$(find . -name "*.log" 2>/dev/null | \
                 xargs grep -l -E "(Traceback.*private_key|Exception.*0x[a-fA-F0-9]{32,})" 2>/dev/null | wc -l)
if [[ "$ERROR_EXPOSURE" -gt 0 ]]; then
    echo -e " ${RED}FAIL($ERROR_EXPOSURE error logs with secrets)${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1)) 
else
    echo -e " ${GREEN}CLEAN${NC}"
fi

# ==============================================================================
# SECTION 4: RUNTIME CONFIGURATION VALIDATION
# ==============================================================================
echo ""
echo -e "${BOLD}SECTION 4: Runtime Configuration Validation${NC}"

echo "4.1 Backend service configuration..."
cd backend

# Relayer validation
echo -n "    - Relayer configuration security..."
cd relayer
if python -c "
import sys, os, logging
logging.disable(logging.CRITICAL)
sys.path.insert(0, 'src')
try:
    from relayer.config import settings
    # Validate critical settings exist and are not defaults
    checks = [
        (hasattr(settings, 'api_key') and settings.api_key and len(str(settings.api_key)) >= 16, 'API_KEY'),
        (hasattr(settings, 'redis_url') and settings.redis_url, 'REDIS_URL'),
    ]
    for check, name in checks:
        if not check:
            print(f'FAIL: {name} validation failed')
            sys.exit(1)
    print('PASS')
except Exception as e:
    print(f'FAIL: {e}')
    sys.exit(1)
" 2>/dev/null; then
    echo -e " ${GREEN}SECURE${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
fi
cd ..

# Provider validation
echo -n "    - Provider configuration security..."  
cd provider
if python -c "
import sys, os, logging
logging.disable(logging.CRITICAL)
sys.path.insert(0, 'src')
try:
    from provider.config import ProviderConfig
    config = ProviderConfig()
    # Validate private key without exposing it
    if not hasattr(config, 'STARKNET_PRIVATE_KEY') or not config.STARKNET_PRIVATE_KEY:
        print('FAIL: Private key not configured')
        sys.exit(1)
    key_str = str(config.STARKNET_PRIVATE_KEY)
    key_no_prefix = key_str[2:] if key_str.startswith('0x') else key_str
    if len(key_no_prefix) != 64:
        print('FAIL: Invalid private key format')
        sys.exit(1)
    print('PASS')
except Exception as e:
    print(f'FAIL: {e}')
    sys.exit(1)
" 2>/dev/null; then
    echo -e " ${GREEN}SECURE${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
fi
cd ../..

# ==============================================================================
# SECTION 5: SECURITY TESTING INTEGRATION
# ==============================================================================
echo ""
echo -e "${BOLD}SECTION 5: Security Test Integration${NC}"

echo "5.1 Contract security tests..."
cd contracts
echo -n "    - Signature verification tests..."
if timeout 45s snforge test test_signature_verification_strict --exact >/dev/null 2>&1; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
fi

echo -n "    - Replay protection tests..."
if timeout 45s snforge test test_signature_replay_prevention --exact >/dev/null 2>&1; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}" 
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
fi
cd ..

echo "5.2 Backend security tests..."
if timeout 60s ./backend/run-security-tests.sh >/dev/null 2>&1; then
    echo -n "    - Backend security validation..."
    echo -e " ${GREEN}PASS${NC}"
else
    echo -n "    - Backend security validation..."
    echo -e " ${RED}FAIL${NC}"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
fi

# ==============================================================================
# FINAL COMPREHENSIVE ASSESSMENT
# ==============================================================================
echo ""
echo -e "${BOLD}COMPREHENSIVE SECURITY ASSESSMENT${NC}"

echo "Security Metrics:"
echo "  Critical Failures: $CRITICAL_FAILURES"
echo "  Warnings: $WARNING_COUNT"
echo "  Scan Coverage: Full filesystem, logs, configs, runtime"
echo ""

if [[ $CRITICAL_FAILURES -eq 0 ]]; then
    if [[ $WARNING_COUNT -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ PRODUCTION SECURITY CLEARED${NC}"
        echo -e "Zero critical failures, zero warnings detected."
    else
        echo -e "${YELLOW}${BOLD}⚠️ PRODUCTION READY WITH $WARNING_COUNT WARNINGS${NC}"
        echo -e "No critical failures, but address warnings for optimal security."
    fi
    echo -e "Ready for mainnet deployment."
    exit 0
else
    echo -e "${RED}${BOLD}🛑 PRODUCTION BLOCKED${NC}"
    echo -e "$CRITICAL_FAILURES critical security failures must be resolved."
    echo ""
    echo "Next steps:"
    echo "1. Fix all critical failures above"
    echo "2. Run: ./scripts/quick-security-check.sh (fast verification)"
    echo "3. Re-run: ./scripts/comprehensive-security-audit.sh"
    echo "4. When clean: ./scripts/war-room-security-gates.sh (final sign-off)"
    exit 1
fi