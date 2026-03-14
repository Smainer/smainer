#!/bin/bash
# SMAINER MAINNET SECURITY GATE - MASTER TEST RUNNER
# This script must pass 100% before mainnet deployment
set -e

echo "🔒 SMAINER MAINNET SECURITY VERIFICATION"
echo "========================================"
echo "Running comprehensive security test suite"
echo "All tests must pass for mainnet deployment"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED_TESTS=()
WARNINGS=()
START_TIME=$(date +%s)

# Helper functions
log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    FAILED_TESTS+=("$1")
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1" 
    WARNINGS+=("$1")
}

log_info() {
    echo -e "ℹ️  INFO: $1"
}

run_test_section() {
    local section_name="$1"
    local test_command="$2"
    
    echo ""
    echo "🧪 Testing: $section_name"
    echo "Command: $test_command"
    
    if eval "$test_command"; then
        log_pass "$section_name"
        return 0
    else
        log_fail "$section_name"
        return 1
    fi
}

# Pre-flight checks
echo "🔍 Pre-flight Security Checks"
echo "-------------------------------"

# Check for common security misconfigurations
log_info "Checking environment configuration..."

if [ -f "/home/smainer/Smainer/.env" ]; then
    # Check for default insecure values
    if grep -q "dev-api-key\|test-secret\|localhost:.*password\|0x000000000000" /home/smainer/Smainer/.env; then
        log_fail "Insecure default values found in .env"
    else
        log_pass "No obvious insecure defaults in .env"
    fi
else
    log_warn ".env file not found - using environment variables"
fi

# Check for secrets in git history (recent commits)
recent_commits=$(git log --oneline -10 --pretty=format:"%H" 2>/dev/null || echo "")
if [ -n "$recent_commits" ]; then
    for commit in $recent_commits; do
        if git show --name-only "$commit" 2>/dev/null | grep -E '\.env$|\.key$|secret' >/dev/null 2>&1; then
            log_warn "Potential secrets committed to git history in commit $commit"
            break
        fi
    done
fi

# Main test execution
echo ""
echo "🔒 MAIN SECURITY TEST EXECUTION"
echo "================================"

# 1. Contracts Security Tests
run_test_section "CONTRACT_SECURITY" "cd /home/smainer/Smainer/contracts && bash run-security-tests.sh"

# 2. Backend Security Tests
run_test_section "BACKEND_SECURITY" "cd /home/smainer/Smainer/backend && bash run-security-tests.sh"

# 3. Frontend Security Tests  
run_test_section "FRONTEND_SECURITY" "cd /home/smainer/Smainer/frontend && bash run-security-tests.sh"

# 4. Critical mainnet gate tests
run_test_section "MAINNET_GATES" "cd /home/smainer/Smainer/backend && python -m pytest tests/test_mainnet_security_gates.py -v"

# 5. Secrets scanning across entire codebase
echo ""
echo "🔍 SECRETS SCANNING"
echo "-------------------"
SECRET_SCAN_RESULT=0

# Comprehensive secret patterns
SECRET_PATTERNS=(
    "sk-[a-zA-Z0-9]{20,}"                                     # API keys
    "0x[a-fA-F0-9]{64}"                                       # Private keys  
    "redis://[^@]*:[^@]+@"                                    # Redis with password
    "postgresql://[^@]*:[^@]+@"                               # PostgreSQL URLs
    "mongodb://[^@]*:[^@]+@"                                  # MongoDB URLs
    "eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"     # JWT tokens
    "['\"]BOT[_-]?TOKEN['\"][:=]['\"][^'\"]{10,}"            # Bot tokens
    "BEGIN [A-Z ]+ PRIVATE KEY"                               # PEM keys
)

log_info "Scanning for secrets in codebase..."
for pattern in "${SECRET_PATTERNS[@]}"; do
    # Get list of files containing the pattern, excluding test/example files
    matches=$(git ls-files | xargs grep -l "$pattern" 2>/dev/null | grep -v -E "\.(test|spec|example)\.|test/|tests/|\.env\.example|\.md$|README" | head -10)
    if [ -n "$matches" ]; then
        log_fail "Potential secrets found matching pattern: $pattern"
        echo "Files: $matches"
        SECRET_SCAN_RESULT=1
    fi
done

if [ $SECRET_SCAN_RESULT -eq 0 ]; then
    log_pass "No secrets found in codebase"
fi

# 6. Network security verification
echo ""
echo "🌐 NETWORK SECURITY"
echo "-------------------"

if command -v nmap >/dev/null 2>&1; then
    # Check for open ports that shouldn't be exposed
    OPEN_PORTS=$(nmap -sT -O localhost 2>/dev/null | grep "^[0-9]" | grep "open" | wc -l)
    if [ "$OPEN_PORTS" -gt 5 ]; then
        log_warn "Many open ports detected ($OPEN_PORTS) - review exposure"
    else
        log_pass "Port exposure reasonable ($OPEN_PORTS ports)"
    fi
else
    log_warn "nmap not available - skipping port scan"
fi

# 7. File permission security
echo ""
echo "🔐 FILE PERMISSIONS"
echo "-------------------"

# Check for overly permissive files
PERMISSIVE_FILES=$(find /home/smainer/Smainer -name "*.key" -o -name "*.pem" -o -name ".env*" 2>/dev/null | xargs ls -la 2>/dev/null | grep -E "rw-.*rw-|rwx.*rwx" | wc -l)
if [ "$PERMISSIVE_FILES" -gt 0 ]; then
    log_fail "Files with overly permissive permissions found"
    find /home/smainer/Smainer -name "*.key" -o -name "*.pem" -o -name ".env*" 2>/dev/null | xargs ls -la 2>/dev/null | grep -E "rw-.*rw-|rwx.*rwx" || true
else
    log_pass "File permissions secure"
fi

# Generate Security Report
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "📊 SECURITY TEST SUMMARY"
echo "========================"
echo "Duration: ${DURATION} seconds"
echo "Test Categories: 7"
echo ""

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL SECURITY TESTS PASSED${NC}"
    echo "✅ Mainnet deployment security gate: CLEAR"
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  WARNINGS (non-blocking):${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
        echo ""
        echo "Address warnings before mainnet for optimal security."
    fi
    
    # Generate security attestation
    cat > "/tmp/smainer-security-attestation-$(date +%s).txt" << EOF
SMAINER SECURITY ATTESTATION
===========================
Date: $(date)
Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Branch: $(git branch --show-current 2>/dev/null || echo "N/A")

All critical security tests PASSED ✅

Test Results:
- Contract Security: PASS
- Backend Security: PASS  
- Frontend Security: PASS
- Mainnet Gates: PASS
- Secrets Scanning: PASS
- Network Security: PASS
- File Permissions: PASS

Warnings: ${#WARNINGS[@]}
$(for warning in "${WARNINGS[@]}"; do echo "- $warning"; done)

Attestation: Ready for mainnet deployment from security perspective.
Signed by: Security Test Suite v1.0
EOF
    
    echo "📋 Security attestation written to /tmp/smainer-security-attestation-*.txt"
    exit 0
    
else
    echo -e "${RED}❌ SECURITY TESTS FAILED${NC}"
    echo "🚫 Mainnet deployment security gate: BLOCKED"
    echo ""
    echo "Failed tests:"
    for failed_test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}❌${NC} $failed_test"
    done
    
    echo ""
    echo "🔧 REQUIRED ACTIONS:"
    echo "1. Fix all failed security tests"
    echo "2. Re-run this security verification"
    echo "3. Only proceed to mainnet when all tests pass"
    echo ""
    echo "⛔ DO NOT DEPLOY TO MAINNET WITH FAILING SECURITY TESTS"
    
    exit 1
fi