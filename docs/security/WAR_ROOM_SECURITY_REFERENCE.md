# WAR ROOM SECURITY REFERENCE CARD
*Quick reference for launch security gates - Keep this visible during war room*

## PRE-LAUNCH EXECUTION
```bash
# Primary security gates check
cd /home/smainer/Smainer && ./war-room-security-gates.sh

# Quick secret scan (if needed)
git grep -i "private_key.*0x" -- ':!test*' || echo "Clean"
git grep -i "api_key.*=" -- ':!*.example' || echo "Clean"
```

## CRITICAL SUCCESS CRITERIA
- **Zero secrets in codebase/logs** ❌🚫
- **All service keys loaded from environment** ✓
- **Contract relayer configured** ✓
- **Signature verification tests pass** ✓

## RED LINE VIOLATIONS (Immediate Stop)
1. Any private key visible in plaintext
2. API keys hardcoded in source files  
3. Secrets detected in log files
4. Historical secret commits discovered

## EMERGENCY INCIDENT RESPONSE

### 🚨 Secret Exposed in Logs
```bash
# Immediate log scrubbing
sudo find /var/log -name "*.log" -exec sed -i 's/0x[a-fA-F0-9]\{64\}/<REDACTED>/g' {} \;
sudo systemctl restart rsyslog
```

### 🚨 Key Compromise Detected
```bash
# Emergency shutdown
sudo systemctl stop smainer-provider smainer-relayer smainer-bot

# Update environment (new keys)
export PROVIDER_PRIVATE_KEY="<new-key>"
export BOT_TOKEN="<new-token>"

# Restart with new keys
sudo systemctl start smainer-provider smainer-relayer smainer-bot
```

### 🚨 Service Authentication Failure
```bash
# Verify current config
cd backend/relayer && python -c "from relayer.config import settings; print('API configured:', bool(settings.api_key))"
cd ../provider && python -c "from provider.config import ProviderConfig; print('Key configured:', bool(ProviderConfig().private_key))"
```

## GO/NO-GO CHECKLIST
- [ ] War room security gates script: `PASS`
- [ ] No secrets in filesystem scan  
- [ ] Service configuration validated
- [ ] Contract signature tests verified
- [ ] Emergency response commands tested

## KEY PERSONNEL CONTACTS
- Security: security@smainer.io
- War Room Lead: [Your contact]
- Infrastructure: [Your contact]

---
**Remember: If ANY red line is crossed → IMMEDIATE STOP + INCIDENT RESPONSE**