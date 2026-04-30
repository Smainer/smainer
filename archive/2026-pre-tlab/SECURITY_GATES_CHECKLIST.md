# Pre-Mainnet Security Gate Checklist
# All items must PASS before mainnet deployment

## Contract Security Gates /

### Critical Contract Security  
- [ ] **Signature Replay Protection**: `used_signatures` mapping prevents duplicate r,s pairs
- [ ] **Access Control**: Only authorized relayer can call `complete_task`  
- [ ] **Arithmetic Safety**: Fee/tier calculations protected against overflow
- [ ] **Reentrancy Protection**: State changes before external calls in escrow functions
- [ ] **Task Locking**: Atomic lock acquisition prevents race conditions

### Contract Verification Tests
- [ ] Replay attack test with identical signature fails
- [ ] Unauthorized `complete_task` calls revert  
- [ ] Large tier multiplier calculations don't overflow
- [ ] Concurrent task operations are properly serialized
- [ ] Edge case fee calculations (minimum amounts) work correctly

## Relayer Security Gates /

### Authentication & Authorization
- [ ] **API Key Security**: Constant-time comparison prevents timing attacks
- [ ] **Rate Limiting**: Task submission protected against spam (≤10 tasks/minute/key)  
- [ ] **Input Validation**: All JSON payloads validated against schema
- [ ] **Signature Verification**: Provider result signatures cryptographically verified

### Relayer Verification Tests  
- [ ] API key brute force test shows constant timing
- [ ] Rate limiting kicks in after 10+ rapid requests
- [ ] Malformed JSON payloads rejected with 400 errors
- [ ] Invalid provider signatures rejected
- [ ] WebSocket connections authenticate before privileged operations

## Provider Security Gates /

### Cryptographic Security
- [ ] **Private Key Protection**: Keys never logged or exposed in responses
- [ ] **Signature Determinism**: Same input produces same signature  
- [ ] **Result Integrity**: Hash includes all critical fields (task_id, result, status)
- [ ] **Sandbox Isolation**: Task execution properly isolated

### Provider Verification Tests
- [ ] Private keys not present in any log output
- [ ] Signature verification works for valid results  
- [ ] Modified task results produce different signatures
- [ ] Sandbox escapes blocked (basic file system restrictions)

## Infrastructure Security Gates /

### Secrets Management
- [ ] **No Hardcoded Secrets**: All secrets from environment variables
- [ ] **Log Scrubbing**: Private keys/API keys filtered from logs  
- [ ] **Error Sanitization**: Stack traces don't expose secrets
- [ ] **File Permissions**: Config files not world-readable (644 max)

### Infrastructure Verification Tests
- [ ] Grep codebase for hardcoded secrets (API keys, private keys)
- [ ] Log output contains no sensitive data patterns
- [ ] Error responses don't leak environment details
- [ ] Redis connections use authentication

## Frontend Security Gates /  

### Web Security
- [ ] **Wallet Integration**: Secure wallet connection flows
- [ ] **Input Sanitization**: XSS prevention on task inputs
- [ ] **HTTPS Enforcement**: All API calls use HTTPS
- [ ] **Content Security Policy**: CSP headers configured

### Frontend Verification Tests
- [ ] Wallet connect/disconnect cycles don't leak keys
- [ ] Task submission form prevents script injection
- [ ] All external API calls use HTTPS
- [ ] CSP blocks unauthorized resource loading

---

## Security Incident Response /

### Monitoring & Response
- [ ] **Error Alerting**: Critical errors trigger notifications
- [ ] **Rate Limit Monitoring**: Unusual request patterns detected  
- [ ] **Key Rotation Process**: Emergency API key rotation documented
- [ ] **Incident Response Plan**: Security incident escalation path defined

### Response Verification Tests
- [ ] Test error alerting with simulated failures
- [ ] Verify key rotation process works end-to-end
- [ ] Document security contact information

---

# BLOCKING CRITERIA

**Zero tolerance for:**
1. Private keys in logs or error messages
2. API authentication bypass
3. Signature verification bypass  
4. Contract reentrancy vulnerabilities
5. Unauthorized task completion

**All tests must pass in CI/CD pipeline before deployment approval.**