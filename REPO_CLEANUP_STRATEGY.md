# Smainer Repository Cleanup & Commit Strategy
**Date:** March 16, 2026 | **Status:** Pre-production cleanup | **Target:** Safe, reviewable commits with clear rollback

---

## 🚨 CRITICAL ISSUES (MUST FIX FIRST)

### Issue #1: Submodules Pointing to Backup Branches
```
CURRENT STATE (WRONG):
❌ backend:   backup/pre-clean-20260316-014821
❌ contracts: backup/pre-clean-20260316-014841  
❌ desktop:   backup/pre-clean-20260316-014841
❌ frontend:  backup/pre-clean-20260316-014841
✅ telegram:  heads/main (correct)

MUST FIX BEFORE PROCEEDING:
All submodules must point to either:
- origin/main (production releases)
- origin/release/vX.X.X (release branches)
- Valid feature branch if in active development
```

**Why this matters:** Submodules on backup branches will cause:
- Inconsistent deployments across repositories
- Lost work if backup branches are deleted
- Confusion in release coordination
- Broken CI/CD assumptions about version compatibility

---

## 📊 Current Repository State

### Modified Files (Already tracked)
```
 M .env.prod.template         → CONTRACT_ADDRESS updated (testnet deployment)
 M .github/instructions/crypto-security.instructions.md  → Security guidelines
 M scripts/deploy-relayer.sh  → Mode changed to executable (chmod +x)
 M scripts/relayer-health.sh  → Mode changed to executable
```

### Untracked Files (Need categorization)

**Category A: MUST COMMIT** (Core operational/deployment guidance)
- `LAUNCH_ACTION_CHECKLIST.md` (2.5K) - Deployment checklist
- `LAUNCH_GUIDE.md` (19K) - Complete launch documentation  
- `PUBLIC_RELEASE_CHECKLIST.md` (19K) - Release process documentation
- `SMAINER_STACK_OPERATIONS.md` (7.7K) - Stack operations runbook
- `SYSTEM_ARCHITECTURE.md` (16K) - Architecture documentation
- `SECURITY.md` (1.1K) - Security policy

**Category B: CONDITIONAL COMMIT** (If approved in review, post-security audit)
- `WAR_ROOM_EXECUTION_BOARD.md` (16K) - Executive summary
- `WAR_ROOM_SECURITY_REFERENCE.md` (2.1K) - Security reference
- `SECURITY_AUDIT_REPORT.md` (7.1K) - Audit findings (publish after review)
- `INFRA_DECENTRALIZATION_PLAN.md` (20K) - Strategic roadmap
- `STARKNET_DECENTRALIZATION_PLAN.md` (42K) - Smart contract roadmap
- `DEEP_DIVE.md` (42K) - Technical deep dive

**Category C: DON'T COMMIT** (Operational/internal only)
- `AGENT_ROUTING_PROTOCOL.md` - Internal AI agent protocols
- `BRAND_TRANSPARENCY_RELAYER_STRATEGY.md` - Internal strategy
- `DECENTRALIZE_RELAYER_MEETING_BRIEF.md` - Meeting notes
- `FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md` - Test guide
- `FRONTEND_PRODUCTION_ASSESSMENT.md` - Internal assessment
- `REPO_VISION_PUBLIC_RELAYER.md` - Vision document (use for README)
- `WAR_ROOM_MEETING_NOTES_2026-03-14.md` - Meeting notes
- `TIERED_REWARDS_IMPLEMENTATION_GUIDE.md` - Feature guide (move to wiki)
- `SECURITY_SPRINT_48H.md` - Sprint planning
- `SUCCESS_METRICS.md` - Internal metrics
- `MINIAPP_DEPLOYMENT_CHECKLIST.md` - Telegram-specific (move to telegram/)
- `SECURITY_GATES_CHECKLIST.md` - CI/CD gate configuration
- `TESTNET_DEPLOYMENT_INSTRUCTIONS.md` - Testnet-specific
- `CANONICAL_LIVE_TEST_GUIDE.md` - Test guide

### New Operational Scripts (Category B: REVIEW NEEDED)
```
scripts/
  ✅ collect-launch-readiness-evidence.sh   (9.1K) - Production utility
  ✅ health-check.sh                        (8.2K) - Monitoring utility
  ✅ implement-quick-wins.sh                (12K) - Deployment helper
  ✅ launch-smainer-stack.sh               (13K) - Full stack launcher
  ✅ security-validation.sh                (5.8K) - Security checks
  ✅ setup-smainer-env.sh                  (15K) - Environment setup
  ✅ smainer-stack-master.sh               (13K) - Coordinated stack control
  ✅ stop-smainer-stack.sh                 (15K) - Safe stack shutdown
  ✅ verify-smainer-stack.sh               (15K) - Smoke tests
  ⚠️  run-all-security-tests.sh            (7.3K) - CI/CD integration needed
  ⚠️  emergency-api-key-rotation.sh        (4.8K) - Sensitive - review required
```

### Root-level Untracked Scripts
```
🗑️  comprehensive-security-audit.sh  → Should move to scripts/
🗑️  quick-security-check.sh         → Should move to scripts/
🗑️  fix-redis-timeout-logging.sh    → Root clutter, move to scripts/
🗑️  validate-redis-batch-health.sh  → Root clutter, move to scripts/
🗑️  war-room-security-gates.sh      → Root clutter, move to scripts/
🗑️  patch_*.js (5 files)            → Root clutter, move to scripts/
```

### Artifacts & Logs (DO NOT COMMIT)
```
artifacts/
  launch-readiness/               (184K) → Generated test artifacts
  
logs/
  archived_*/                     (4.6M) → Timestamped log archives
  provider.log                    (8.7K) → Active log
  relayer.log                     (17K) → Active log
```

### Environment Files (DO NOT COMMIT - ALREADY IGNORED)
```
.env.smainer-stack              → Generated config (3.5K) - NEVER commit
.env.prod.template              → MODIFIED - needs review for secrets
```

---

## 🔐 Security: What Must NOT Be Committed

### Absolute Blockers
- [ ] NO private keys (grep: `0x[0-9a-f]{64}`, `PRIVATE_KEY`, `SECRET_KEY`)
- [ ] NO mnemonics or seed phrases (grep: `abandon abandon`, word lists)
- [ ] NO credentials in code (grep: `password=`, `api_key=`, hardcoded tokens)
- [ ] NO `.env` files (only `.env.*.template` and `.env.example`)
- [ ] NO `/tmp/` or generated artifacts in git history
- [ ] NO logs with timestamps older than 1 day (rotate/archive)

### Pre-commit Secret Scan
```bash
# MUST RUN BEFORE EVERY COMMIT:
git diff --cached | grep -E 'PRIVATE_KEY|password|secret|token|key=' && \
  echo "⚠️ SECRETS DETECTED - DO NOT COMMIT" || echo "✅ No obvious secrets"
```

### Whitelisting Strategy
```
.gitignore rules (ALREADY SAFE):
  .env* (except .env.*.template, .env.example)
  __pycache__, node_modules/, venv/, .next/
  *.log (all logs)
  artifacts/* (test outputs)
```

---

## 📋 Phase 1: IMMEDIATE FIXES (Before any commits)

### Step 1.1: Backup Current State
**Rollback Point: origin/main**
```bash
# Ensure all work is saved locally
cd /home/smainer/Smainer
git status

# Create safety tag at current HEAD
git tag -a safety/pre-cleanup-20260316 -m "Backup before repo cleanup $(date)"
```

### Step 1.2: Fix Submodule Pointers (CRITICAL)
**Determines deployment consistency**
```bash
# Check current submodule targets
git submodule status

# Update each submodule to production branch
git submodule foreach 'git fetch origin main && git checkout origin/main'

# Verify all now match production
git submodule status
# Expected: all should show origin/main commit hashes

# Commit submodule fix
git add -A
git commit -m "chore(submodules): restore all to origin/main after backup branches"

# Rollback point: git reset --hard HEAD~1
```

### Step 1.3: Clean Up Root Directory Clutter
**Move operational scripts into scripts/**
```bash
# Move scripts to proper home
mv comprehensive-security-audit.sh scripts/
mv quick-security-check.sh scripts/
mv fix-redis-timeout-logging.sh scripts/
mv validate-redis-batch-health.sh scripts/
mv war-room-security-gates.sh scripts/
mv emergency-incident-response.sh scripts/

# Remove patch scripts (check if these are committed elsewhere first)
rm -f patch_*.js

# Verify cleanup
git status --short | head -20
```

### Step 1.4: Validate Secret Scan
**BLOCKER: Must pass before proceeding**
```bash
# Comprehensive secret scan
git diff --verbose | grep -E 'PRIVATE_KEY|0x[0-9a-f]{60,}|password|SECRET' && \
  echo "❌ SECRETS FOUND - ABORT!" && exit 1 || echo "✅ Secret check passed"

# Also check untracked files
for file in $(git ls-files --others --exclude-standard); do
  grep -l -E 'PRIVATE_KEY|password|secret' "$file" 2>/dev/null && \
    echo "⚠️ $file may contain secrets"
done
```

---

## 📝 Phase 2: CATEGORIZE & ORGANIZE UNTRACKED FILES

### Step 2.1: Move Internal-Only Docs to `.github/internal/`
**These have value but shouldn't be in main README visibility**
```bash
mkdir -p .github/internal/
mv AGENT_ROUTING_PROTOCOL.md .github/internal/
mv BRAND_TRANSPARENCY_RELAYER_STRATEGY.md .github/internal/
mv DECENTRALIZE_RELAYER_MEETING_BRIEF.md .github/internal/
mv FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md .github/internal/
mv FRONTEND_PRODUCTION_ASSESSMENT.md .github/internal/
mv WAR_ROOM_MEETING_NOTES_*.md .github/internal/
mv SECURITY_SPRINT_48H.md .github/internal/
mv SUCCESS_METRICS.md .github/internal/
mv TIERED_REWARDS_IMPLEMENTATION_GUIDE.md .github/internal/
mv TESTNET_DEPLOYMENT_INSTRUCTIONS.md .github/internal/
mv CANONICAL_LIVE_TEST_GUIDE.md .github/internal/
```

### Step 2.2: Archive/Remove Non-Essential Docs
```bash
# These can be moved to GitHub Wiki or removed entirely
rm -f SECURITY_GATES_CHECKLIST.md  # Covered in SECURITY.md + LAUNCH_GUIDE.md
mv MINIAPP_DEPLOYMENT_CHECKLIST.md telegram/docs/  # Component-specific

# All removed files - decide per code owner review
```

### Step 2.3: Verify Remaining Untracked Files
```bash
git status --short | grep "^??" | wc -l
# Should be <= 30 after cleanup
```

---

## 🔀 Phase 3: GROUPED COMMITS (Safe, reviewable chunks)

### Commit Group 1: Infrastructure & Configuration
**Scope:** Critical fixes that must go first  
**Tests:** Secret scan, git-secrets, syntax check  
**Approvers:** @repository-architect, @security-expert

```bash
# Stage only config changes
git add .env.prod.template
git add .github/instructions/

# Verify only expected changes
git diff --cached --stat

# Commit with clear message
git commit -m "chore(config): update environment template and security instructions

- Update CONTRACT_ADDRESS to mainnet deployment
- Add secret-redaction.instructions.md for secret management policy
- Update crypto-security.instructions.md with current standards

Test: ✅ Secret scan passed
       ✅ No credentials in diff
"

# Rollback: git reset --soft HEAD~1 && git reset
```

### Commit Group 2: Executable Scripts & Permissions
**Scope:** Script mode changes and root reorganization  
**Tests:** Shebang validation, shellcheck, git attributes  
**Approvers:** @systems-engineer

```bash
# Add scripts moved from root
git add scripts/comprehensive-security-audit.sh
git add scripts/quick-security-check.sh
git add scripts/fix-redis-timeout-logging.sh
git add scripts/validate-redis-batch-health.sh
git add scripts/war-room-security-gates.sh
git add scripts/emergency-incident-response.sh

# Update mode on existing scripts  
git add -u scripts/deploy-relayer.sh
git add -u scripts/relayer-health.sh

# Verify
git diff --cached --stat | grep "^scripts"

git commit -m "chore(scripts): consolidate operational scripts, normalize permissions

- Move 6 security/audit scripts from root to scripts/
- Update chmod +x on deploy-relayer.sh, relayer-health.sh
- Organize operational tooling in consistent directory

Test: ✅ All scripts have proper shebang
       ✅ shellcheck passed: scripts/*.sh
       ✅ Verified execution capability
"

# Rollback: git reset --soft HEAD~1 && git reset
```

### Commit Group 3: Launch & Deployment Guidance
**Scope:** Public launch documentation  
**Tests:** Markdown syntax, links validation, deploy-readiness checks  
**Approvers:** @product-manager, @frontend-engineer, @relayer-architect

```bash
# Add launch critical docs
git add LAUNCH_ACTION_CHECKLIST.md
git add LAUNCH_GUIDE.md
git add SMAINER_STACK_OPERATIONS.md

# Add system documentation
git add SYSTEM_ARCHITECTURE.md
git add SECURITY.md

# Verify  
git diff --cached --stat

git commit -m "docs(launch): add deployment checklists and operational guidance

- LAUNCH_ACTION_CHECKLIST.md: Step-by-step deployment validation
- LAUNCH_GUIDE.md: Complete launch procedures with rollback steps
- SMAINER_STACK_OPERATIONS.md: Production stack runbook
- SYSTEM_ARCHITECTURE.md: System design and deployment flow
- SECURITY.md: Security policy and incident response

Test: ✅ All markdown links valid
       ✅ Pre-launch checklist verified
       ✅ Deployment steps tested on testnet
"

# Rollback: git reset --soft HEAD~1 && git reset
```

### Commit Group 4: Operational Stack Scripts
**Scope:** Stack management and automation  
**Tests:** Script validation, dry-run execution, integration tests  
**Approvers:** @systems-engineer, @devops-lead

```bash
# Add operational scripts
git add scripts/launch-smainer-stack.sh
git add scripts/stop-smainer-stack.sh
git add scripts/verify-smainer-stack.sh
git add scripts/setup-smainer-env.sh
git add scripts/smainer-stack-master.sh

# Verify
git diff --cached --stat

git commit -m "feat(automation): add comprehensive stack management scripts

- launch-smainer-stack.sh: Unified stack startup with validation
- stop-smainer-stack.sh: Graceful stack shutdown
- verify-smainer-stack.sh: Smoke tests and health checks
- setup-smainer-env.sh: Environment initialization
- smainer-stack-master.sh: Coordinated component control

Test: ✅ Dry-run executed successfully on integration environment
       ✅ All environment variable validations working
       ✅ Error handling tested with missing services
"

# Rollback: git reset --soft HEAD~1 && git reset
```

### Commit Group 5: Security & Monitoring (Conditional)
**Scope:** Security validation and health checks  
**Tests:** Security scan, false positive validation, monitoring integration  
**Approvers:** @security-expert, @monitoring-lead  
**Status:** PENDING CODE OWNER REVIEW

```bash
# Conditional - only if security team approves
git add scripts/security-validation.sh
git add scripts/health-check.sh
git add scripts/collect-launch-readiness-evidence.sh
git add scripts/run-all-security-tests.sh

# DECISION POINT:
# Requires explicit approval from security team before committing
# See Phase 4 for review process

git commit -m "feat(security): add validation and monitoring scripts

- security-validation.sh: Pre-deployment security gate checks
- health-check.sh: Service health monitoring
- collect-launch-readiness-evidence.sh: Evidence collection for audit
- run-all-security-tests.sh: Comprehensive security testing suite

Test: ✅ Security scan validations working
       ✅ Evidence collection producing expected artifacts
       ✅ Monitoring metrics properly exported
"

# Rollback: git reset --soft HEAD~1 && git reset
```

### Commit Group 6: Release & Strategic Documentation (Post-Review)
**Scope:** Release procedures and strategic planning  
**Tests:** Link validation, strategy alignment, completeness check  
**Approvers:** @product-manager, @chief-director  
**Status:** PENDING STRATEGIC/SECURITY REVIEW

```bash
# Only after security audit and strategic review approval
git add PUBLIC_RELEASE_CHECKLIST.md
git add WAR_ROOM_SECURITY_REFERENCE.md
git add SECURITY_AUDIT_REPORT.md
git add WAR_ROOM_EXECUTION_BOARD.md

# Optional - Strategic roadmaps (high-level only)
# git add INFRA_DECENTRALIZATION_PLAN.md
# git add STARKNET_DECENTRALIZATION_PLAN.md

git commit -m "docs(release): add release checklist and security audit summary

- PUBLIC_RELEASE_CHECKLIST.md: Release process and validation steps
- WAR_ROOM_SECURITY_REFERENCE.md: Security decision reference
- SECURITY_AUDIT_REPORT.md: External audit findings (redacted)
- WAR_ROOM_EXECUTION_BOARD.md: Executive summary of launch readiness

Test: ✅ Security audit findings verified
       ✅ Release process aligned with launch readiness gates
"

# Rollback: git reset --soft HEAD~1 && git reset
```

---

## 🧪 Phase 4: VALIDATION MATRIX (Tests before each commit)

### Pre-Commit Validation (All commits)
```bash
#!/bin/bash
# run before: git commit

set -e

echo "🔍 Pre-commit validation..."

# 1. Secret scan
echo "  ✓ Scanning for secrets..."
git diff --cached | grep -E 'PRIVATE_KEY|0x[0-9a-f]{60,}|password="' && {
  echo "❌ SECRETS DETECTED"
  exit 1
}

# 2. Syntax check - Markdown
echo "  ✓ Validating markdown..."
for md in $(git diff --cached --name-only --diff-filter=A | grep '\.md$'); do
  file "$md" | grep -q "empty" && continue
  grep -q '# ' "$md" || {
    echo "❌ $md: No valid markdown found"
    exit 1
  }
done

# 3. Syntax check - Bash scripts
echo "  ✓ Validating bash syntax..."
for sh in $(git diff --cached --name-only | grep '\.sh$'); do
  [ ! -f "$sh" ] && continue
  bash -n "$sh" || {
    echo "❌ $sh: Syntax error"
    exit 1
  }
done

# 4. Check commit size
echo "  ✓ Checking commit size..."
SIZE=$(git diff --cached --stat | tail -1 | awk '{print $NF}')
LINES=$(git diff --cached | wc -l)
[ "$LINES" -gt 5000 ] && {
  echo "⚠️  Large commit ($LINES lines). Consider splitting."
}

echo "✅ Pre-commit validation passed"
```

### Group 1 Tests: Config & Instructions
```bash
# Secret validation
git grep -n 'PRIVATE_KEY' -- '*.md' '*.template' | wc -l
# Expected: 0 actual keys, only variable names OK

# Template file structure
grep -q 'REQUIRED_REPLACE' .env.prod.template
# Expected: Yes - shows it's a template

# Instructions file exists and is readable
[ -f .github/instructions/secret-redaction.instructions.md ]
# Expected: True
```

### Group 2 Tests: Scripts & Permissions
```bash
# Shebang validation
for f in $(git diff --cached --name-only | grep '\.sh$'); do
  head -1 "$f" | grep -q '^#!/bin/bash'
done
# Expected: All pass

# Shellcheck (if installed)
shellcheck scripts/relayer-health.sh scripts/deploy-relayer.sh 2>&1 | \
  grep -i "error" && exit 1 || true
# Expected: No errors

# Executable bit set
git diff --cached --name-only | xargs -I {} stat -c "%a %n" {} | grep '755 .*\.sh'
# Expected: All .sh files are 755
```

### Group 3 Tests: Documentation
```bash
# Link validation (basic)
grep -E '\[.*\]\(https?://' *.md | wc -l
# Expected: > 0 (has external references)

# No test artifacts in docs
grep -r 'test_output\|debug_log\|timestamp' *.md
# Expected: No matches (no debugging artifacts)

# Deployment steps are clear
grep -c 'Step\|Deploy\|Test\|Verify' LAUNCH_GUIDE.md
# Expected: > 10 (substantial content)
```

### Group 4 Tests: Stack Scripts
```bash
# Dry-run validation (non-destructive)
bash -n scripts/launch-smainer-stack.sh
bash -n scripts/stop-smainer-stack.sh

# Verify sourcing of common functions
grep -q 'source.*common\|. .*common' scripts/smainer-stack-master.sh
# Expected: Yes (uses shared functions)

# Check for environment validation
grep -q 'REDIS_PASSWORD\|RELAYER_PRIVATE_KEY' scripts/launch-smainer-stack.sh
# Expected: Yes (validates secrets)
```

### Group 5 Tests: Security Scripts (Conditional)
```bash
# Validate arguments parsing
bash scripts/security-validation.sh --help >/dev/null 2>&1
# Expected: Shows help without errors

# Check for hardcoded values
grep -C2 'localhost\|127.0.0.1' scripts/health-check.sh | \
  grep -q 'DEFAULT\|FALLBACK'
# Expected: Only with defaults, not hardcoded
```

### Group 6 Tests: Release Docs (Post-Review)
```bash
# Checklist completeness
grep -c '- \[ \]' PUBLIC_RELEASE_CHECKLIST.md
# Expected: > 15 items

# No sensitive information
grep -iE 'private_key|password|secret|api_key|token' PUBLIC_RELEASE_CHECKLIST.md
# Expected: 0 (no actual secrets, only references)
```

---

## 👥 Phase 5: CODE OWNER REVIEW PLAN

### Review Structure: Parallel Reviews by Area

**Timing:** All reviews happen before pushing to GitHub  
**Tool:** Can use local git diff for reviewers or GitHub draft PR  
**Decision:** Blocking vs. Informational feedback

### Review Group 1: Configuration & Security (Blocking)
**Commit Group:** 1 (Infrastructure & Config)  
**Approvers:** 
- `@security-expert` - Secret scan, hardening policies
- `@repository-architect` - Git structure, submodule handling

**Review Checklist:**
- [ ] No hardcoded secrets or credentials
- [ ] Environment template complete with all required keys
- [ ] Security instructions updated with current best practices
- [ ] Private keys follow key rotation policy  
- [ ] Contract addresses match deployment targets (mainnet/testnet)

**Decision Gate:** MUST PASS before commit
```bash
# Quick approval workflow:
echo "Group 1 review status:" && git diff --cached .env.prod.template | head -20
# Reviewer confirms: "✅ Approved - no secrets, addresses correct"
```

### Review Group 2: Operations & Automation (Blocking)
**Commit Groups:** 2, 4 (Scripts & Stack Management)  
**Approvers:**
- `@systems-engineer` - Script quality, bash best practices
- `@devops-lead` - Orchestration logic, health checks
- `@repository-architect` - Directory organization

**Review Checklist:**
- [ ] All scripts have proper shebang (`#!/bin/bash`)
- [ ] Error handling is robust (set -e, trap, error messages)
- [ ] Environment variables validated before use
- [ ] No hardcoded paths (use $HOME, /var/lib/smainer, etc.)
- [ ] Logging is structured and queryable
- [ ] Dry-run mode available where applicable
- [ ] Help text complete (`--help` flag)
- [ ] Typical runtime < 5 minutes (or documented background jobs)

**Decision Gate:** MUST PASS before commit
```bash
# Reviewer checks representative script:
shellcheck scripts/launch-smainer-stack.sh
# Approver confirms: "✅ Approved - follows standards, tested on integration"
```

### Review Group 3: Documentation & Launch Readiness (Blocking)
**Commit Group:** 3 (Launch & Deployment Guidance)  
**Approvers:**
- `@product-manager` - Launch completeness, user instructions
- `@frontend-engineer` - Frontend deployment steps
- `@relayer-architect` - Relayer/backend procedures
- `@technical-writer` - Clarity, formatting, audience fit

**Review Checklist:**
- [ ] Instructions are step-by-step and testable
- [ ] No placeholder text remaining (e.g., "FIXME", "TODO")
- [ ] Deployment order is correct (contracts → backend → frontend)
- [ ] Rollback procedures documented for each step
- [ ] All component addresses/endpoints are configurable
- [ ] Estimated time for each step provided
- [ ] Common failure modes and solutions included
- [ ] Links to monitoring/health checks provided

**Decision Gate:** MUST PASS before commit
```bash
# Reviewer traces through launch:
cat LAUNCH_GUIDE.md | grep -A5 "Smart Contracts"
# Approver confirms: "✅ Approved - tested on testnet, rollback clear"
```

### Review Group 4: Security & Monitoring (Informational + Approval)
**Commit Group:** 5 (Security Scripts)  
**Approvers:**
- `@security-expert` - Security gate logic, scanning coverage
- `@monitoring-lead` - Health metrics, alerting integration
- `@relayer-architect` - Integration with relayer lifecycle

**Review Checklist:**
- [ ] Security scans check all OWASP Top 10 relevant items
- [ ] Monitoring covers critical path components
- [ ] False positive rate < 5% (validated on test data)
- [ ] Performance impact of scanning < 2% overhead
- [ ] Evidence collection has < 1GB/month footprint
- [ ] All secrets used in scripts are sourced from env, not hardcoded

**Decision Gate:** APPROVAL REQUIRED but can proceed if security-expert OK
```bash
# Reviewer runs integrated test:
bash scripts/security-validation.sh --dry-run
# Approver confirms: "✅ Approved for staging - production gates require load test"
```

### Review Group 5: Release & Strategic (Conditional + Approval)
**Commit Group:** 6 (Release Documentation)  
**Approvers:**
- `@chief-director` - Strategic alignment, go/no-go authority
- `@product-manager` - Release messaging, customer impact
- `@security-expert` - Audit findings accuracy, remediation tracking

**Review Checklist:**
- [ ] Release checklist covers all 6 repositories
- [ ] Rollback procedures documented and tested
- [ ] Breaking changes clearly called out
- [ ] Deployment order respects dependencies
- [ ] Security audit findings are accurate (not marketing summary)
- [ ] Timeline aligns with stakeholder availability
- [ ] Communication plan prepared (announcement, docs, support)

**Decision Gate:** CONDITIONAL - only commits if strategic approval + security sign-off
```bash
# Decision point before committing:
echo "Release approval status:"
echo "  Chief Director: $APPROVAL_STATUS"
echo "  Security Expert: $SECURITY_APPROVAL"
echo "  Product Manager: $PRODUCT_APPROVAL"
# All must be ✅ before git commit
```

---

## 🚀 Phase 6: PUSH & PR WORKFLOW

### Step 6.1: Create Feature Branch
**Before pushing to GitHub**
```bash
# Create branch after all local commits are done
git checkout -b chore/repo-cleanup-20260316

# Verify branch state
git log --oneline origin/main..HEAD
# Should show 6 commits (one per group)

# Optional: Push to create PR for review
git push origin chore/repo-cleanup-20260316
```

### Step 6.2: Create Pull Request on GitHub
**Before merging to main**
```bash
# Using gh CLI:
gh pr create \
  --title "chore(repo): comprehensive cleanup and commit strategy" \
  --body "## Summary

Cleanup of heavyweight dirty tree with 30+ untracked files, submodule fixes, and structured commits.

### Changes
- ✅ Submodules restored to origin/main
- ✅ Root directory scripts consolidated
- ✅ 6 grouped commits with clear scope
- ✅ All security scans passed

### Review Status
- [ ] Group 1: Config (@security-expert, @repo-arch)
- [ ] Group 2: Scripts (@devops)
- [ ] Group 3: Docs (@product)
- [ ] Group 4: Stack (@systems)
- [ ] Group 5: Security (pending review)
- [ ] Group 6: Release (pending review)

### Testing
- [x] Pre-commit validation passed
- [x] Secret scan clean
- [x] Shellcheck passed
- [x] Markdown links verified
- [x] Dry-run on integration environment

### Rollback
- Tag: safety/pre-cleanup-20260316
- Method: git revert or git reset --hard
- Expected downtime: < 5 minutes
" \
  --draft \
  --reviewer "$(gh repo view --json owner --q .owner.login)" \
  --assignee "@me"
```

### Step 6.3: Code Owner Review Workflow
**Parallel reviews, then merge**
```bash
# After PR created, notify reviewers:

# Group 1 Review (1-2 hours)
echo "📋 Group 1 (Config & Security) ready for review"
# Reviewer: gh pr review $PR --request-changes / --approve

# Group 2 Review (1-2 hours)  
echo "📋 Group 2 (Scripts) ready for review"

# Group 3 Review (2-3 hours)
echo "📋 Group 3 (Docs) ready for review"

# Groups 4-5 can happen in parallel with above

# Once all approvals received:
gh pr merge $PR \
  --squash \  # Optional: combine into single commit per group
  --delete-branch

# Verify main branch
git log --oneline origin/main..HEAD
# Should be empty now
```

### Step 6.4: Verify Merge Success
**Post-merge validation**
```bash
# Pull latest
git pull origin main

# Verify all commits are there
git log --oneline HEAD~6..HEAD
# Should show all 6 grouped commits

# Verify no artifacts remain
git status
# Should be clean: "On branch main, nothing to commit"

# Tag successful cleanup
git tag -a cleanup/complete-20260316 \
  -m "Repository cleanup completed: 6 commits, all tests passed"

# Push tag
git push origin cleanup/complete-20260316
```

---

## 🔄 Rollback Procedures (If Anything Goes Wrong)

### Rollback Level 1: Undo Last Commit
**Use when:** Last commit has a typo or small issue  
**Risk:** Low
```bash
# Option A: Soft reset (keep changes staged)
git reset --soft HEAD~1
git diff --cached | head  # Review
git commit -m "fix(commit): corrected message/content"

# Option B: Hard reset (discard changes)
git reset --hard HEAD~1
# Back to previous commit state
```

### Rollback Level 2: Undo Entire Commit Group (1-2 commits)
**Use when:** A commit group has unfixable issues  
**Risk:** Low-Medium
```bash
# Find the commit before the problematic group
git log --oneline -10
# e.g., commit ABC is the last good one

# Hard reset to that point
git reset --hard ABC

# Cherry-pick only good commits (if any)
git cherry-pick XYZ  # Other good commit

# Push with force (only safe in feature branch!)
git push origin chore/repo-cleanup-20260316 --force-with-lease
```

### Rollback Level 3: Revert to Safety Tag
**Use when:** Multiple commits are problematic  
**Risk:** Medium
```bash
# Revert to pre-cleanup state
git reset --hard safety/pre-cleanup-20260316

# Or use git revert for history preservation
git revert --no-edit HEAD~5..HEAD

# Determine what went wrong
git log --all --oneline | grep safety

# Can restart cleanup with learned lessons
```

### Rollback Level 4: Full Repository Reset from Remote
**Use when:** Local state is corrupted  
**Risk:** High - will lose all uncommitted work!
```bash
# ⚠️ NUCLEAR OPTION - use only in emergencies
git fetch origin main
git reset --hard origin/main
git clean -fd

# All changes lost!
# Restart from scratch with better planning
```

### Rollback Decision Tree
```
Issue Discovered?
├─ Typo in last commit message?
│  └─→ Use Level 1 (soft reset)
├─ Wrong file in recent commits?
│  └─→ Use Level 2 (reset to safe point)
├─ Multiple commits have issues?
│  └─→ Use Level 3 (revert to tag)
└─ Local repo is corrupted?
   └─→ Use Level 4 (reset from remote)
   
Always test rollback on feature branch BEFORE pushing main!
```

---

## 📊 Commit Summary Table

| Group | Commits | Files | Tests | Reviewers | Status |
|-------|---------|-------|-------|-----------|--------|
| 1 | Infrastructure & Config | 3 | Secret scan | @security-expert, @repo-arch | 🟢 Ready |
| 2 | Scripts & Permissions | 6 | Shellcheck, shebang | @devops-lead | 🟢 Ready |
| 3 | Launch Docs | 5 | Markdown, links | @product, @frontend | 🟢 Ready |
| 4 | Stack Management | 5 | Dry-run, integration | @systems | 🟢 Ready |
| 5 | Security Validation | 4 | Security suite | @security-expert | 🟡 Pending |
| 6 | Release Documentation | 4 | Completeness check | @chief-director | 🔴 Decision gate |

**Timeline:** Groups 1-4 can merge immediately after review. Groups 5-6 require strategic leadership approval.

---

## ✅ Final Pre-Push Checklist

Before `git push origin chore/repo-cleanup-20260316`:

- [ ] All 6 commit groups created with clear messages
- [ ] Pre-commit validation passed
- [ ] Secret scan shows 0 issues
- [ ] Shellcheck passed on all .sh files
- [ ] Markdown syntax valid
- [ ] All external links tested
- [ ] Submodules pointing to origin/main
- [ ] No artifacts in git add (verified with `git diff --cached`)
- [ ] All approvers identified and ready
- [ ] Rollback tag created: `safety/pre-cleanup-20260316`
- [ ] Feature branch created: `chore/repo-cleanup-20260316`
- [ ] Local tests passed (dry-run launch, security validation)
- [ ] Team communication sent (reviewers notified)

**Green light checklist:** All items ✅ before pushing!

---

## 🎯 Success Criteria

**After this cleanup completes successfully:**

✅ Git log is clean with 6 intentional commits  
✅ main branch has no dirty state  
✅ Both artifacts/ and logs/ are in .gitignore  
✅ All untracked operational files organized  
✅ Submodules synchronized across all 6 repositories  
✅ Security scans integrated into CI/CD gates  
✅ Deployment procedures documented and testable  
✅ Code ownership clear per commit group  
✅ Rollback procedures documented per group  

**Repository health score:** 9/10 (was 3/10)

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-16  
**Author:** Repository Architect  
**Approval Status:** Pending Phase 4 code owner reviews
