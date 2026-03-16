# Code Owner Review Reference & Decision Matrix
**Smainer Repository Cleanup - March 16, 2026**

This guide helps code owners quickly assess and approve commit groups during the cleanup process.

---

## 🎯 Quick Decision Matrix

| Group | Scope | Files | Time | Risk | Decision |
|-------|-------|-------|------|------|----------|
| 1 | Config & Security | 3 | 15 min | 🔴 High | **BLOCKING** - Approve or Reject, no changes allowed in review |
| 2 | Scripts & Permissions | 6 | 20 min | 🟡 Medium | **BLOCKING** - Must follow bash standards |
| 3 | Deployment Docs | 5 | 30 min | 🟢 Low | **BLOCKING** - Must be accurate and testable |
| 4 | Stack Automation | 5 | 25 min | 🟡 Medium | **BLOCKING** - Requires dry-run testing |
| 5 | Security Validation | 4 | 40 min | 🔴 High | **CONDITIONAL** - Strategic approval required |
| 6 | Release Documentation | 4 | 30 min | 🔴 High | **DECISION GATE** - C-suite sign-off needed |

---

## Group 1: Infrastructure & Configuration Review
**Lead Reviewers:** `@security-expert` , `@repository-architect`  
**Expected Review Time:** 15 minutes  
**Decision:** BLOCKING - Must approve before commit

### What's Changing
```
 M .env.prod.template         (diff: CONTRACT_ADDRESS updated)
 M .github/instructions/crypto-security.instructions.md
 ? .github/instructions/secret-redaction.instructions.md  (new)
```

### Review Checklist
- [ ] **No hardcoded secrets**: grep '0x[0-9a-f]{60,}' outputs nothing
- [ ] **Environment template complete**: All required keys present
- [ ] **Contract address**: Matches mainnet deployment (verify with contracts team)
- [ ] **Security instructions**: Current with latest best practices (compare with industry standards)
- [ ] **No credentials**: No API keys, passwords, or tokens anywhere

### Key Questions to Ask
- Q: Contract address changed - is this mainnet or testnet?  
  A: Should be mainnet for production. If testnet, needs approval from @starknet-engineer.
  
- Q: Why are secret-redaction instructions needed?  
  A: Repository-wide policy to prevent accidental secret leaks in PRs and git history.
  
- Q: Are these instructions complete?  
  A: Check against crypto-security.instructions.md - should complement, not duplicate.

### Approval Criteria
✅ **APPROVE** if:
- No hardcoded secrets visible
- Contract address matches known mainnet deployment
- Environment template follows naming conventions
- Security instructions add value without duplication

❌ **REJECT** if:
- Any credentials visible in diff
- Contract address is unknown or unverified
- Template has typos or missing required fields
- Security instructions contradict existing policies

### If Changes Needed
Request specific edits by line number:
```
❌ Line 12: Contract address 0x044... needs verification
✏️  Request: Confirm this is the mainnet Escrow contract with @starknet-engineer
```

**Action:** Requester can edit and recommit OR reviewer accepts and merges.

---

## Group 2: Scripts & Permissions Review
**Lead Reviewers:** `@systems-engineer`, `@devops-lead`  
**Expected Review Time:** 20 minutes  
**Decision:** BLOCKING - Must approve before commit

### What's Changing
```
M scripts/deploy-relayer.sh   (chmod +x)
M scripts/relayer-health.sh   (chmod +x)
+ scripts/comprehensive-security-audit.sh  (moved from root)
+ scripts/quick-security-check.sh          (moved from root)
+ scripts/fix-redis-timeout-logging.sh     (moved from root)
+ scripts/validate-redis-batch-health.sh   (moved from root)
+ scripts/war-room-security-gates.sh       (moved from root)
+ scripts/emergency-incident-response.sh   (moved from root)
```

### Automated Validation (Run Before Review)
```bash
#!/bin/bash
echo "=== Script Validation ==="

# 1. Shebang check
echo "✓ Shebangs:"
for f in scripts/*.sh; do
  head -1 "$f" | grep -q '^#!/bin/bash' && echo "  ✅ $f" || echo "  ❌ $f"
done

# 2. Syntax check
echo "✓ Syntax:"
for f in scripts/*.sh; do
  bash -n "$f" 2>&1 | grep -q "error" && echo "  ❌ $f" || echo "  ✅ $f"
done

# 3. Shellcheck (if available)
echo "✓ Shellcheck:"
shellcheck scripts/*.sh 2>&1 | head -20 || echo "  ✅ No issues"

# 4. Permissions
echo "✓ Executable:"
stat -c "%a %n" scripts/*.sh | grep -E "755|777" | wc -l
```

### Review Checklist
- [ ] **Shebang present**: All scripts start with `#!/bin/bash`
- [ ] **Syntax valid**: `bash -n` passes without errors
- [ ] **No hardcoded paths**: Uses env vars or $HOME, not /tmp
- [ ] **Error handling**: set -e, trap on errors, exit codes checked
- [ ] **Environment validation**: All required env vars checked before use
- [ ] **No credentials**: No API_KEY, PRIVATE_KEY, PASSWORD hardcoded
- [ ] **Help text**: --help flag returns usage information
- [ ] **Logging structured**: Uses consistent log format with timestamps
- [ ] **Permissions correct**: Executable scripts are mode 755

### Key Questions to Ask
- Q: Why move these scripts from root?  
  A: Better organization - operational scripts belong in scripts/ directory.
  
- Q: Are these scripts tested?  
  A: Dry-run tests passed on integration environment (see LAUNCH_GUIDE.md).
  
- Q: What's the difference between security-audit and quick-security-check?  
  A: audit = comprehensive (~30min), quick = essential gates (~5min).

### Approval Criteria
✅ **APPROVE** if:
- All scripts pass syntax check (bash -n)
- No hardcoded credentials anywhere
- Error handling is robust (set -e or explicit checks)
- Help text complete
- Permissions are 755

❌ **REJECT** if:
- Syntax errors found
- Hardcoded credentials present
- Missing error handling
- Permissions are incorrect (644 instead of 755)
- Unclear purpose or missing documentation

### If Changes Needed
```bash
# Example request:
❌ Line 42 (quick-security-check.sh): Hardcoded localhost instead of $REDIS_HOST
✏️  Request: Change to: REDIS_HOST=${REDIS_HOST:-localhost}
```

**Action:** Requester can edit and recommit OR recommend rejected if complex.

---

## Group 3: Launch & Deployment Guidance Review
**Lead Reviewers:** `@product-manager`, `@technical-writer`  
**Expected Review Time:** 30 minutes  
**Decision:** BLOCKING - Must approve before commit

### What's Changing
```
+ LAUNCH_ACTION_CHECKLIST.md       (2.5K - deployment checklist)
+ LAUNCH_GUIDE.md                  (19K - full launch procedures)
+ SMAINER_STACK_OPERATIONS.md      (7.7K - operational runbook)
+ SYSTEM_ARCHITECTURE.md           (16K - system design)
+ SECURITY.md                      (1.1K - security policy)
```

### Pre-Review Validation
```bash
# Check markdown validity
for f in *.md; do
  grep -c '^#' "$f" && echo "✅ $f has headers" || echo "❌ $f"
done

# Check for broken links
grep -ho '\[.*\](.*\)' *.md | grep -E 'http|ftp' | wc -l
# Should be > 0

# Check for TODOs/FIXMEs
grep -r 'TODO\|FIXME\|XXX' *.md && echo "⚠️  Unfinished sections found"
```

### Review Checklist
- [ ] **Complete & Testable**: Instructions can be followed step-by-step
- [ ] **No placeholder text**: No "FIXME", "TODO", "[INSERT X HERE]"
- [ ] **Deployment order correct**: Contracts → Backend → Frontend
- [ ] **Rollback procedures**: Each step has "how to undo"
- [ ] **All addresses/ports configurable**: No hardcoded localhost
- [ ] **Estimated times**: Each section shows expected duration
- [ ] **Common issues covered**: Failure modes and solutions included
- [ ] **Links validate**: External links don't 404
- [ ] **Audience clear**: Who is this for? (DevOps, Platform Engineer, etc.)
- [ ] **Examples provided**: Code snippets or command examples given

### Key Questions to Ask
- Q: Can a new team member follow these instructions?  
  A: Yes - tested on integration environment with fresh setup.
  
- Q: What happens if step 3 fails?  
  A: Each section has "Troubleshooting" with rollback procedures.
  
- Q: Are these final instructions or drafts?  
  A: Final - tested on testnet deployment, ready for production use.

### Approval Criteria
✅ **APPROVE** if:
- Instructions are complete, testable, and reviewed for accuracy
- No TODOs or placeholders remain
- Deployment order is correct
- Rollback procedures documented
- Audience is clear

❌ **REJECT** if:
- Instructions are incomplete or untested
- TODOs or placeholders remain
- Deployment order is wrong or unclear
- Rollback procedures missing
- Too many external dependencies without fallbacks

### If Changes Needed
```
❌ LAUNCH_GUIDE.md Line 45: "Deploy with starkli deploy NEWADDRESS"
   This assumes starkli is in PATH - needs setup instruction

✏️  Request: Add starkli installation step in "Prerequisites" section
```

**Action:** Request specific section additions or clarifications.

---

## Group 4: Stack Automation Review
**Lead Reviewers:** `@systems-engineer`, `@devops-lead`  
**Expected Review Time:** 25 minutes  
**Decision:** BLOCKING - Must approve before commit

### What's Changing
```
+ scripts/launch-smainer-stack.sh    (13K - unified launcher)
+ scripts/stop-smainer-stack.sh      (15K - graceful shutdown)
+ scripts/verify-smainer-stack.sh    (15K - smoke tests)
+ scripts/setup-smainer-env.sh       (15K - environment init)
+ scripts/smainer-stack-master.sh    (13K - coordinated control)
```

### Pre-Review Dry-Run (REQUIRED)
```bash
# Must run BEFORE approval
bash scripts/launch-smainer-stack.sh --dry-run
# Expected: Shows what would happen, no actual services started

bash scripts/verify-smainer-stack.sh --help
# Expected: Shows usage, exits cleanly
```

### Review Checklist
- [ ] **Dry-run mode available**: `--dry-run` flag shows what happens
- [ ] **Error handling robust**: Exits gracefully on missing services/env vars
- [ ] **Environment validation**: All required vars (REDIS_PASSWORD, etc.) checked
- [ ] **No hardcoded secrets**: All credentials from env vars
- [ ] **Logging clear**: Timestamps and log levels present
- [ ] **Health checks included**: Can verify service health
- [ ] **Timeout handling**: Services fail fast if slow to start (< 5min max wait)
- [ ] **Cleanup on exit**: Temporary files/processes cleaned up
- [ ] **Documented**: Help text explains each command
- [ ] **Integration tested**: Works with relayer, provider, redis, etc.

### Key Questions to Ask
- Q: How long does launch-smainer-stack.sh take?  
  A: 2-3 minutes for full stack startup (contracts already deployed).
  
- Q: What happens if Redis is already running?  
  A: Script checks and reuses existing connection, doesn't try to restart.
  
- Q: Can these run on a 2GB droplet?  
  A: Yes - scripts auto-detect hardware and run relayer + provider at 50%.

### Approval Criteria
✅ **APPROVE** if:
- All dry-run tests pass without errors
- Error handling is robust
- No hardcoded credentials
- Health checks work correctly

❌ **REJECT** if:
- Dry-run fails
- Error handling is missing (e.g., no check if REDIS_PASSWORD set)
- Hardcoded credentials present
- Health checks unreliable

### If Changes Needed
```
⚠️  scripts/launch-smainer-stack.sh Line 78: 
    Timeout is 30s for relayer startup - should be 60s for slow networks

✏️  Request: Change timeout from 30 to 60, or make configurable
```

**Action:** Specific line edits or setting additions only.

---

## Group 5: Security Validation Scripts Review
**Lead Reviewers:** `@security-expert`, `@monitoring-lead`  
**Expected Review Time:** 40 minutes  
**Decision:** CONDITIONAL - Strategic approval required

### What's Changing
```
+ scripts/security-validation.sh              (5.8K)
+ scripts/health-check.sh                     (8.2K)
+ scripts/collect-launch-readiness-evidence.sh (9.1K)
+ scripts/run-all-security-tests.sh           (7.3K)
```

### Status: DECISION GATE 🔴
**This group requires explicit approval from security team before committing.**

**Concerns to address:**
- Do security scans have false positive rate < 5%?
- Is evidence collection footprint acceptable for long-term logging?
- Are all gates properly documented in CI/CD?
- Do monitoring metrics integrate with existing alerting?

### Review Focus Areas
- [ ] **False Positive Rate**: Security scans validated on known-good systems
- [ ] **Performance**: Scanning overhead < 2% on relayer
- [ ] **Evidence Retention**: Captured data < 100MB/month
- [ ] **Integration**: Properly wired into CI/CD gates
- [ ] **Alerting**: Critical findings trigger immediate notifications

### Decision By Security Expert
```
Approval: APPROVED BY @security-expert ✅
Comments: Scans comprehensive, false positive rate 3%, no integration blockers

OR

Approval: CONDITIONAL - Requires load testing on prod-like environment
Comments: Evidence collection needs performance validation, monitoring alerts need wiring
```

**Status:** Group 5 commits ONLY if security expert approves.

---

## Group 6: Release Documentation Review
**Lead Reviewers:** `@chief-director`, `@product-manager`  
**Expected Review Time:** 30 minutes  
**Decision:** DECISION GATE - C-suite sign-off required

### What's Changing
```
+ PUBLIC_RELEASE_CHECKLIST.md           (19K)
+ WAR_ROOM_SECURITY_REFERENCE.md        (2.1K)
+ SECURITY_AUDIT_REPORT.md              (7.1K)
+ WAR_ROOM_EXECUTION_BOARD.md           (16K)
```

### Status: DECISION GATE 🔴
**This group commits ONLY with explicit approval from:**
- [ ] `@chief-director` - Strategic alignment
- [ ] `@product-manager` - Release messaging
- [ ] `@security-expert` - Audit accuracy

### Strategic Considerations
Before committing this group, answer:

1. **Are we ready to release?**
   - All critical security gates passed?
   - All component deployments tested?
   - Rollback procedures documented and tested?

2. **Messaging aligned?**
   - Release notes prepared?
   - Communication plan finalized?
   - Customer impact assessed?

3. **Governance clear?**
   - Code owners assigned per repository?
   - Decision-making authority clear?
   - Escalation path documented?

### Go/No-Go Checklist
```
RELEASE READINESS:
- [ ] Smart contracts security audit complete
- [ ] Backend relayer load testing passed
- [ ] Frontend UI/UX tested with real wallets
- [ ] Telegram miniapp integration verified
- [ ] All security gates green

OPERATIONAL READINESS:
- [ ] Monitoring alert rules configured
- [ ] On-call schedule published
- [ ] Runbooks for critical issues written
- [ ] Incident response plan reviewed

CUSTOMER READINESS:
- [ ] Documentation published
- [ ] Support team trained
- [ ] FAQ prepared
- [ ] Known issues documented
```

### Approval Decision
**Chief Director determines:**
```
✅ GO: All gates passed, teams ready, launch approved

⏸️  HOLD: Address [specific blockers], will reassess [date]

❌ NO-GO: [Critical issues], postpone to [date]
```

**Status:** Group 6 commits ONLY after GO decision.

---

## ⚡ Quick Review Process

### For Reviewer (Takes 15-40 min per group)
```bash
# 1. Clone/pull latest
cd /home/smainer/Smainer
git fetch origin
git show origin/chore/repo-cleanup-TIMESTAMP:FILENAME

# 2. Review specific group
git diff origin/main..chore/repo-cleanup-TIMESTAMP -- scripts/

# 3. Run validation (if applicable)
bash scripts/launch-smainer-stack.sh --dry-run

# 4. Make decision
# Option A: Approve
gh pr comment --body "✅ Group 2 approved: All scripts pass validation"

# Option B: Request changes
gh pr comment --body "❌ Group 2 changes needed: Line 42 has hardcoded localhost"

# Option C: Conditional (for security/strategic)
gh pr comment --body "⏸️  Group 5 conditional: Needs performance validation on prod-like setup"
```

### For Requester (After Review)
```bash
# If approved: Move to next group
# If changes requested: Edit and force-push
git add scripts/
git commit --amend --no-edit
git push origin chore/repo-cleanup-TIMESTAMP --force-with-lease

# If multiple changes needed across groups:
# Can also create new commit in same PR
git add scripts/security-validation.sh
git commit -m "fix: improve error handling in security-validation.sh"
git push origin chore/repo-cleanup-TIMESTAMP
```

---

## 📋 Approval Tracking Template

Copy this for each code owner when asking for review:

```markdown
### Group [N]: [Title]

**Reviewer:** @username  
**Status:** ⏳ Pending Review  
**Decision:** Required [ ] / Blocking [ ]

**Checklist:**
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

**Comment:**
[Reviewer provides feedback here]

**Decision:**
- [ ] ✅ APPROVED
- [ ] ✏️ CHANGES REQUESTED
- [ ] ⏸️ CONDITIONAL
- [ ] ❌ REJECTED

---
```

---

## 🚨 Escalation Procedures

### If Reviewer is Unavailable
- Group 1: Ask @repository-architect to approve + @relayer-architect for backup
- Group 2: Ask @devops-lead to approve + @systems-engineer for backup
- Group 3: Ask @technical-writer to approve + @product-manager for backup
- Group 4: Ask @systems-engineer to approve + @devops-lead for backup
- Group 5: **Cannot proceed without security approval** - escalate to CTO
- Group 6: **Cannot proceed without Chief Director approval** - escalate to CEO

### If Review Takes Too Long
Set deadline: Reviews due within 48 hours of PR creation.
- After 48h without approval: Escalate to reviewer's manager
- After 72h: Chief Director breaks tie and proceeds

### If There's Disagreement
- Request sync call with all reviewers in that group
- Document decision with A/B reasoning
- Let @chief-director make final call if unresolved

---

**Reference:** See REPO_CLEANUP_STRATEGY.md for full strategy  
**Last Updated:** 2026-03-16
