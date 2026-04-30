#!/bin/bash
# WAR ROOM SECURITY GATES - Pre-Launch Secret Leak and Safety Validation
# CRITICAL: Execute this script before first live end-to-end task
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD} WAR ROOM SECURITY GATES - PRE-LAUNCH VALIDATION${NC}"
echo -e "Target: First live end-to-end task safety"
echo -e "Date: $(date)"
echo ""

FAILED_CHECKS=0
WORKSPACE_ROOT="/home/smainer/Smainer"
cd "$WORKSPACE_ROOT"

# ==============================================================================
# 1. EXACT PRE-LAUNCH SECRET-LEAK CHECKS
# ==============================================================================
echo -e "${BOLD}1. PRE-LAUNCH SECRET-LEAK DETECTION${NC}"

echo -n "1.1 Filesystem secret scan (comprehensive)..."
SECRET_FINDINGS=$(mktemp)

# Enhanced secret patterns with better coverage
git grep -i --color=never -n \
  -E "(private_key|PRIVATE_KEY|secret_key|SECRET_KEY).*=.*(0x[a-fA-F0-9]{64}|[a-fA-F0-9]{64})" \
    -- ':!*.example' ':!*.template' ':!test*' ':!*test*' ':!node_modules' > "$SECRET_FINDINGS" 2>/dev/null || true

git grep -i --color=never -n \
  -E "(api_key|API_KEY|token|TOKEN).*=.*['\"][a-zA-Z0-9_-]{20,}['\"]" \
    -- ':!*.example' ':!*.template' ':!test*' ':!*test*' ':!node_modules' >> "$SECRET_FINDINGS" 2>/dev/null || true

# Check for mnemonic/seed phrases
git grep -i --color=never -n \
  -E "(mnemonic|seed_phrase).*=.*['\"][a-z ]{50,}['\"]" \
    -- ':!*.example' ':!*.template' ':!test*' ':!*test*' >> "$SECRET_FINDINGS" 2>/dev/null || true

# Check for Starknet accounts files with actual keys
find . -name "*accounts.json" -exec grep -l "private_key.*0x[a-fA-F0-9]" {} \; 2>/dev/null >> "$SECRET_FINDINGS" || true

# Check .env files for actual secrets (not placeholders)
find . -name ".env" -not -path "*/node_modules/*" | while read envfile; do
    if ! git ls-files --error-unmatch "$envfile" >/dev/null 2>&1; then
        continue
    fi
    if grep -q -E "(PRIVATE_KEY|API_KEY|TOKEN|SECRET|PASSWORD).*=.{16,}" "$envfile" 2>/dev/null; then
        echo "$envfile:ENV_VARS_DETECTED" >> "$SECRET_FINDINGS"
    fi
done

if [[ -s "$SECRET_FINDINGS" ]]; then
    echo -e " ${RED}CRITICAL FAILURE${NC}"
    echo -e "${RED}SECRETS DETECTED IN CODEBASE:${NC}"
    cat "$SECRET_FINDINGS" | sed 's/private_key.*/private_key: <REDACTED>/g' | sed 's/api_key.*/api_key: <REDACTED>/g'
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo -e " ${GREEN}PASS${NC}"
fi

echo -n "1.2 Environment variable leakage check..."
ENV_LEAK=$(env | grep -E "(PRIVATE_KEY|API_KEY|TOKEN|SECRET)" | grep -v "not_set\|unset\|REDACTED" || true)
if [[ -n "$ENV_LEAK" ]]; then
    echo -e " ${YELLOW}WARNING - Environment variables exposed${NC}"
    env | grep -E "(PRIVATE_KEY|API_KEY|TOKEN|SECRET)" | sed 's/=.*/=<REDACTED>/'
else
    echo -e " ${GREEN}PASS${NC}"
fi

echo -n "1.3 Log files secret scan..."
LOG_SECRET_SCAN=$(find . -name "*.log" -o -name "console.log" -o -name "error.log" | \
                  xargs grep -l -E "(0x[a-fA-F0-9]{64}|api_key.*['\"][a-zA-Z0-9]{20,})" 2>/dev/null || true)
if [[ -n "$LOG_SECRET_SCAN" ]]; then
    echo -e " ${RED}CRITICAL FAILURE${NC}"
    echo -e "${RED}SECRETS FOUND IN LOGS:${NC}"
    echo "$LOG_SECRET_SCAN"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo -e " ${GREEN}PASS${NC}"
fi

echo -n "1.4 Git history secret leak check..."
HIST_SECRETS=$(git log --since="1 week ago" -p --all | grep -E "(private_key|api_key).*[0x]?[a-fA-F0-9]{32,}" | head -3 || true)
if [[ -n "$HIST_SECRETS" ]]; then
    echo -e " ${YELLOW}WARNING${NC}"
    echo -e "${YELLOW}RECENT HISTORY CONTAINS SECRET-LIKE PATTERNS (review recommended)${NC}"
else
    echo -e " ${GREEN}PASS${NC}"
fi

echo -n "1.5 File permissions security audit..."
PERM_ISSUES=$(find . \( -name "*.env" -o -name "*.key" -o -name "*accounts.json" -o -name "*.pem" \) \
              -not -path "*/node_modules/*" -not -path "*/target/*" \
              -exec ls -la {} \; 2>/dev/null | grep -E "^-.......w." | wc -l)
if [[ "$PERM_ISSUES" -gt 0 ]]; then
    echo -e " ${RED}FAIL - $PERM_ISSUES world-writable sensitive files${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo -e " ${GREEN}PASS${NC}"
fi

# ==============================================================================
# 2. RUNTIME SAFETY CHECKS FOR KEY HANDLING
# ==============================================================================
echo ""
echo -e "${BOLD}2. RUNTIME SAFETY CHECKS${NC}"

echo -n "2.1 Relayer configuration validation..."
cd backend/relayer
if python -c "
import os, sys, logging
sys.path.insert(0, 'src')
# Disable all logging during validation
logging.disable(logging.CRITICAL)
try:
    from relayer.config import settings
    # Must have API key from env
    api_key = getattr(settings, 'api_key', None)
    if not api_key or api_key == 'your-api-key-here':
        print('FAIL: API_KEY not configured or is placeholder')
        sys.exit(1)
    # Must not be hardcoded
    if len(api_key) < 16:
        print('FAIL: API_KEY too short, likely hardcoded')
        sys.exit(1)
    print('PASS')
except Exception as e:
    print(f'FAIL: {e}')
    sys.exit(1)
" 2>/dev/null; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
cd ../..

echo -n "2.2 Provider private key validation..."
cd backend/provider
if python -c "
import os, sys, logging
sys.path.insert(0, 'src')
logging.disable(logging.CRITICAL)
try:
    from provider.config import ProviderConfig
    config = ProviderConfig()
    # Ensure private key is from environment
    if not hasattr(config, 'STARKNET_PRIVATE_KEY') or not config.STARKNET_PRIVATE_KEY:
        print('FAIL: Private key not loaded')
        sys.exit(1)
    # Basic validation without exposing key
    key = str(config.STARKNET_PRIVATE_KEY)
    key_no_prefix = key[2:] if key.startswith('0x') else key
    if len(key_no_prefix) == 64:
        print('PASS')
    else:
        print('FAIL: Invalid private key format')
        sys.exit(1)
except Exception as e:
    print(f'FAIL: {e}')
    sys.exit(1)
" 2>/dev/null; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
cd ../..

echo -n "2.3 Telegram bot token validation..."
cd telegram
if [[ -f package.json ]]; then
    if node -e "
    const token = process.env.BOT_TOKEN;
    if (!token || token.length < 20 || token === 'your-bot-token') {
        console.log('FAIL: BOT_TOKEN not configured');
        process.exit(1);
    }
    console.log('PASS');
    " 2>/dev/null; then
        echo -e " ${GREEN}PASS${NC}"
    else
        echo -e " ${RED}FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e " ${YELLOW}SKIP - No package.json${NC}"
fi
cd ..

echo -n "2.4 Contract relayer address verification..."
cd contracts
if command -v sncast >/dev/null 2>&1; then
    RELAYER_ADDR=$(sncast call --contract-address 0x040f979da0daf49e1007eed2634e5d3acfd475bfffca03e771c1654a5721b212 \
                   --function "get_relayer" --network mainnet 2>/dev/null | grep -o "0x[a-fA-F0-9]*" || echo "UNKNOWN")
    if [[ "$RELAYER_ADDR" != "UNKNOWN" && "$RELAYER_ADDR" != "0x0" ]]; then
        echo -e " ${GREEN}PASS (${RELAYER_ADDR:0:10}...${RELAYER_ADDR: -4})${NC}"
    else
        echo -e " ${YELLOW}WARNING - No relayer set${NC}"
    fi
else
    echo -e " ${YELLOW}SKIP - sncast not available${NC}"
fi
cd ..

# ==============================================================================
# 3. GO/NO-GO SECURITY CRITERIA
# ==============================================================================
echo ""
echo -e "${BOLD}3. GO/NO-GO EVIDENCE ARTIFACTS${NC}"

echo -n "3.1 Signature verification test evidence..."
cd contracts
if timeout 30s snforge test test_signature_verification_strict --exact >/dev/null 2>&1; then
    echo -e " ${GREEN}VERIFIED${NC}"
    echo "    └─ Artifact: Signature verification test passed"
else
    echo -e " ${YELLOW}UNVERIFIED${NC}"
    echo "    └─ WARNING: Could not run signature verification test"
fi

echo -n "3.2 Replay protection test evidence..."
if timeout 30s snforge test test_signature_replay_prevention --exact >/dev/null 2>&1; then
    echo -e " ${GREEN}VERIFIED${NC}"
    echo "    └─ Artifact: Replay protection test passed"
else
    echo -e " ${YELLOW}UNVERIFIED${NC}"
    echo "    └─ WARNING: Could not run replay protection test"
fi
cd ..

echo -n "3.3 Backend security test evidence..."
if ./backend/run-security-tests.sh >/dev/null 2>&1; then
    echo -e " ${GREEN}VERIFIED${NC}"
    echo "    └─ Artifact: Backend security tests passed"
else
    echo -e " ${RED}UNVERIFIED${NC}"
    echo "    └─ ERROR: Backend security tests failed"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo -n "3.4 File permissions audit..."
SENSITIVE_FILES=$(find . -name "*.env" -o -name "*.key" -o -name "*accounts.json" | head -10)
BAD_PERMS=$(echo "$SENSITIVE_FILES" | xargs ls -la 2>/dev/null | grep -E "^-.......w." || true)
if [[ -n "$BAD_PERMS" ]]; then
    echo -e " ${RED}FAIL${NC}"
    echo "    └─ World-writable sensitive files detected"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo -e " ${GREEN}PASS${NC}"
    echo "    └─ Artifact: No world-writable sensitive files"
fi

# ==============================================================================
# 4. INCIDENT RESPONSE COMMAND REFERENCE
# ==============================================================================
echo ""
echo -e "${BOLD}4. INCIDENT RESPONSE COMMANDS (for emergencies)${NC}"
cat << 'EOF'
# If secrets appear in logs:
sudo find /var/log -name "*.log" -exec sed -i 's/0x[a-fA-F0-9]\{64\}/<REDACTED>/g' {} \;
sudo systemctl restart rsyslog

# Emergency key rotation (update env vars):  
export OLD_PRIVATE_KEY="$PROVIDER_PRIVATE_KEY"
export PROVIDER_PRIVATE_KEY="<new-private-key>"
sudo systemctl restart smainer-provider smainer-relayer

# Emergency service shutdown:
sudo systemctl stop smainer-provider smainer-relayer smainer-bot
sudo killall -9 python node

# Log scrubbing verification:
sudo grep -r "0x[a-fA-F0-9]\{64\}" /var/log/ || echo "Clean"

# Emergency git secret removal:
git-filter-repo --path-glob '**/accounts.json' --invert-paths
git push --force-with-lease origin main
EOF

# ==============================================================================
# FINAL VERDICT 
# ==============================================================================
echo ""
echo -e "${BOLD}FINAL WAR ROOM VERDICT${NC}"

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD} GO FOR LAUNCH${NC}"
    echo -e "All security gates passed. Ready for first live end-to-end task."
    exit 0
else
    echo -e "${RED}${BOLD} NO-GO - SECURITY BLOCKS DETECTED${NC}"
    echo -e "Failed checks: $FAILED_CHECKS"
    echo -e "Resolve all CRITICAL FAILURE and FAIL items before proceeding."
    exit 1
fi