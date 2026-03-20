#!/bin/bash
# INCIDENT RESPONSE: Emergency Stop + Secret Scrub
# For immediate response to secret exposure or security incident
set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
INCIDENT_LOG="/tmp/security_incident_${TIMESTAMP}.log"

echo -e "${BOLD}🚨 EMERGENCY INCIDENT RESPONSE ACTIVE${NC}"
echo "Timestamp: $(date)"
echo "Log: $INCIDENT_LOG"
echo ""

# Capture current state for investigation
{
    echo "=== INCIDENT RESPONSE LOG ==="
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "PWD: $(pwd)"
    echo "Environment: $(env | grep -E '(PRIVATE|API|TOKEN|SECRET)' | sed 's/=.*/=<REDACTED>/' || echo 'None visible')"
    echo ""
} > "$INCIDENT_LOG"

# PHASE 1: IMMEDIATE SHUTDOWN
echo -e "${BOLD}PHASE 1: Emergency Service Shutdown${NC}"

echo "1.1 Stopping all Smainer services..."
sudo systemctl stop smainer-provider smainer-relayer smainer-bot 2>/dev/null || true
echo "    ✓ Services stopped via systemctl"

echo "1.2 Killing remaining processes..."
sudo pkill -f "python.*provider" 2>/dev/null || true
sudo pkill -f "python.*relayer" 2>/dev/null || true 
sudo pkill -f "node.*telegram" 2>/dev/null || true
echo "    ✓ Processes terminated"

echo "1.3 Closing network connections..."
sudo netstat -tlnp | grep -E ":8000|:3000|:5432" | awk '{print $7}' | grep -o '^[0-9]*' | xargs -r sudo kill 2>/dev/null || true
echo "    ✓ Network connections closed"

# PHASE 2: SECRET SCRUBBING
echo ""
echo -e "${BOLD}PHASE 2: Secret Scrubbing${NC}"

echo "2.1 Scrubbing system logs..."
# Remove hex patterns that could be private keys
sudo find /var/log -type f -name "*.log" -exec sed -i 's/0x[a-fA-F0-9]\{64\}/<REDACTED_HEX>/g' {} \; 2>/dev/null || true
sudo find /var/log -type f -name "*.log" -exec sed -i 's/api_key[^,}]*[,}]/api_key: "<REDACTED>",/g' {} \; 2>/dev/null || true
sudo systemctl restart rsyslog 2>/dev/null || true
echo "    ✓ System logs scrubbed"

echo "2.2 Scrubbing application logs..."
find /home/smainer/Smainer -name "*.log" -type f -exec sed -i 's/0x[a-fA-F0-9]\{64\}/<REDACTED_HEX>/g' {} \; 2>/dev/null || true
find /tmp -name "*smainer*.log" -type f -delete 2>/dev/null || true
echo "    ✓ Application logs scrubbed"

echo "2.3 Clearing shell history..."
history -c 2>/dev/null || true
unset HISTFILE 2>/dev/null || true
> ~/.bash_history 2>/dev/null || true
echo "    ✓ Shell history cleared"

echo "2.4 Clearing terminal scrollback..."
printf '\033c' 2>/dev/null || true
echo "    ✓ Terminal cleared"

# PHASE 3: SECURE STATE VERIFICATION
echo ""
echo -e "${BOLD}PHASE 3: Secure State Verification${NC}"

echo "3.1 Verifying service shutdown..."
RUNNING_SERVICES=$(pgrep -f "smainer|provider|relayer" | wc -l)
if [[ "$RUNNING_SERVICES" -eq 0 ]]; then
    echo "    ✓ All services confirmed stopped"
else
    echo "    ⚠ $RUNNING_SERVICES processes still running"
fi

echo "3.2 Checking for secret remnants in logs..."
SECRET_COUNT=$(sudo grep -r "0x[a-fA-F0-9]\{64\}" /var/log/ 2>/dev/null | wc -l)
if [[ "$SECRET_COUNT" -eq 0 ]]; then
    echo "    ✓ No hex patterns found in logs"
else
    echo "    ⚠ $SECRET_COUNT potential secrets still in logs" 
fi

echo "3.3 Verifying network isolation..."
OPEN_PORTS=$(netstat -tlnp | grep -E ":8000|:3000|:5432" | wc -l)
if [[ "$OPEN_PORTS" -eq 0 ]]; then
    echo "    ✓ Application ports closed"
else
    echo "    ⚠ $OPEN_PORTS application ports still open"
fi

# PHASE 4: NEXT STEPS GUIDANCE
echo ""
echo -e "${BOLD}PHASE 4: Post-Incident Actions Required${NC}"

cat << 'EOF'
IMMEDIATE ACTIONS (within 1 hour):
1. Rotate all compromised keys:
   export NEW_PRIVATE_KEY="<generate-new-key>"
   export NEW_API_KEY="<generate-new-api-key>"
   
2. Update environment files:
   sudo nano /etc/systemd/system/smainer-*.service
   sudo systemctl daemon-reload
   
3. Check git for secret commits:
   git log --oneline -n 20 | grep -E "(key|secret|token)"
   
4. If git contains secrets, run:
   git-filter-repo --path-glob '**/accounts.json' --invert-paths
   git push --force-with-lease origin main

INVESTIGATION ACTIONS (within 4 hours):
1. Review incident log: cat INCIDENT_LOG_PATH
2. Determine exposure scope
3. Check external monitoring/logs 
4. Notify stakeholders if needed

RECOVERY ACTIONS (when ready):
1. Verify new keys are secure
2. Run: ./scripts/war-room-security-gates.sh
3. If gates pass: restart services
4. If gates fail: repeat fix cycle
EOF

echo ""
echo -e "${YELLOW}Incident log saved to: $INCIDENT_LOG${NC}"
echo -e "${RED}${BOLD}⚠ SYSTEM REMAINS IN EMERGENCY MODE${NC}"
echo -e "Run security gates before restart: ./scripts/war-room-security-gates.sh"

exit 0