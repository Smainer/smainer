# 🚀 Repository Cleanup: Quick Start Guide

**Status:** Ready to execute  
**Timeline:** 2-3 hours (includes reviews)  
**Risk Level:** 🟡 Medium (but fully reversible)  
**Rollback:** Single command: `git reset --hard safety/pre-cleanup-<timestamp>`

---

## What's Happening

Your repository has accumulated 30+ untracked files, 4 submodules on backup branches, and a mix of operational/documentation content that needs cleanup. This plan organizes everything into safe, reviewable commits.

## 📊 Current Issues

| Issue | Count | Severity | Fix |
|-------|-------|----------|-----|
| Submodules on backup branches | 4 | 🔴 Critical | Restore to origin/main |
| Root directory clutter | 6 scripts | 🟡 Medium | Move to scripts/ |
| Untracked documentation | 30+ files | 🟡 Medium | Categorize & organize |
| Operational artifacts | 4.9MB | 🟡 Medium | Keep in .gitignore |
| Mixed commit scope | — | 🟡 Medium | Split into 6 groups |

## ✅ Solution Overview

### 6 Grouped Commits

```
Group 1: Config & Secrets (3 files)
         ↓ Approval: @security-expert, @repo-architect
         
Group 2: Scripts & Permissions (6 scripts)
         ↓ Approval: @systems-engineer
         
Group 3: Launch & Deployment Docs (5 docs)
         ↓ Approval: @product-manager
         
Group 4: Stack Automation (5 scripts)
         ↓ Approval: @devops-lead
         
Group 5: Security Validation (4 scripts)
         ↓ Approval: CONDITIONAL - security review
         
Group 6: Release Documentation (4 docs)
         ↓ Approval: DECISION GATE - chief director
```

**Result:** Clean, reviewable commits with clear ownership and decision gates.

---

## 🎯 Execution Path

### Step 1: Review the Plans (5 min)
- Read **REPO_CLEANUP_STRATEGY.md** - Full detailed strategy
- Read **CODE_OWNER_REVIEW_MATRIX.md** - How code owners review
- Understand phases and what gets committed vs. excluded

### Step 2: Prepare Team (10 min)
Notify code owners about upcoming reviews:
```bash
# Send review requests
gh pr create --draft \
  --title "chore(repo): comprehensive cleanup (6 commits, 2-3 hour review)" \
  --body "See CODE_OWNER_REVIEW_MATRIX.md for review responsibilities"
```

### Step 3: Execute Cleanup (30-60 min)
```bash
# Test first (no changes)
bash /home/smainer/Smainer/repo-cleanup-execute.sh --dry-run

# Run for real (creates 6 commits)
bash /home/smainer/Smainer/repo-cleanup-execute.sh

# Or run phase by phase
bash /home/smainer/Smainer/repo-cleanup-execute.sh --phase 1
bash /home/smainer/Smainer/repo-cleanup-execute.sh --phase 2
bash /home/smainer/Smainer/repo-cleanup-execute.sh --phase 3
# etc.
```

### Step 4: Request Reviews (10 min)
Assign code owners to each commit group:
```bash
# Show what's being reviewed
git log --oneline origin/main..HEAD

# Notify reviewers with specific commits
for group in 1 2 3 4 5 6; do
  echo "Requesting Group $group review..."
  # Post review request comment on PR
done
```

### Step 5: Collect Approvals (60-120 min)
Code owners review in parallel using the matrix:
- Groups 1-4: Must approve before committing
- Group 5: Conditional approval from security
- Group 6: Decision gate (chief director only)

### Step 6: Push & Merge (10 min)
```bash
# Push feature branch (once all Phase 1-4 approved)
git push origin chore/repo-cleanup-<timestamp>

# Create PR and merge once reviews done
gh pr create --title "chore(repo): cleanup" --body "Ready for merge"
gh pr merge <PR_NUMBER>
```

---

## 💻 Quick Commands

### Start Dry Run (No actual changes)
```bash
cd /home/smainer/Smainer
bash repo-cleanup-execute.sh --dry-run
```

### Start Actual Cleanup
```bash
cd /home/smainer/Smainer
bash repo-cleanup-execute.sh
```

### Check What Will Be Committed
```bash
git log --oneline origin/main..HEAD
git diff origin/main --stat
```

### Review Submodule Changes
```bash
git submodule status
git diff origin/main -- backend contracts frontend telegram
```

### Rollback If Needed
```bash
# Show available rollback points
git tag | grep safety

# Reset to before cleanup
git reset --hard safety/pre-cleanup-<timestamp>
```

---

## 🔍 What Gets Committed vs. Excluded

### ✅ COMMITTED (6 groups of commits)
- Configuration updates (.env.prod.template)
- Security instructions (.github/instructions/)
- Launch checklists and guides
- Deployment procedures
- Stack automation scripts
- Health check and monitoring scripts

### 🗑️ NOT COMMITTED (Stay in .gitignore)
- artifacts/ directory (184K test outputs)
- logs/ directory (4.6M log archives)
- .env.smainer-stack (generated config)
- node_modules/, __pycache__, .venv/
- *.log files (active logs)

### 📁 ORGANIZED (Moved but not committed yet)
- Internal-only docs → .github/internal/
- Root scripts → scripts/
- Meeting notes → .github/internal/

---

## 🔐 Security Checklist

Before executing, ensure:
- [ ] `git status` shows clean history
- [ ] No uncommitted secrets in diffs
- [ ] RELAYER_PRIVATE_KEY not in any files
- [ ] DATABASE_PASSWORD not visible
- [ ] API_KEYS are environment variables only
- [ ] No test data with real credentials

The script runs automatic secret scans. If it fails:
```bash
# See what triggered the alarm
git diff | grep -i 'private\|password\|secret\|token'

# Fix the file and re-run
git reset
git add <safe-files-only>
bash /home/smainer/Smainer/repo-cleanup-execute.sh --phase 3
```

---

## 📈 Timeline Estimate

| Activity | Time | Notes |
|----------|------|-------|
| Review plans | 5 min | Read strategy & matrix docs |
| Team notification | 10 min | Notify code owners |
| Dry run | 5 min | Test without changes |
| Execute cleanup | 30 min | Runs all phases |
| Code owner reviews | 60-120 min | Parallel reviews Groups 1-4 |
| Security conditional | 30-60 min | If Group 5 needs testing |
| Chief director gate | 10 min | Final approval Group 6 |
| Push & merge | 10 min | Final push to main |
| **Total** | **2-3 hours** | Mostly parallel review time |

---

## ⚠️ Known Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Reviewer unavailable | 🟡 Medium | Delays approval | Use escalation matrix |
| Merge conflict with other work | 🟡 Medium | Requires rebase | Keep branch fresh, merge quickly |
| Submodule sync issues | 🟢 Low | Broken versions | Test submodule checkout locally |
| Secret accidentally committed | 🟢 Low | Security breach | Run automatic scans every phase |
| Script syntax errors | 🟢 Low | Shellcheck failure | Pre-test with bash -n |

## 🛟 If Something Goes Wrong

### Problem: Submodule stays on backup branch
```bash
cd backend  # or contracts, frontend, etc.
git fetch origin main
git checkout origin/main
cd ..
git add backend
git commit --amend --no-edit
```

### Problem: Script has syntax error
```bash
bash -n scripts/problematic-script.sh  # Shows error
# Fix the error, then:
git add scripts/problematic-script.sh
git commit --amend --no-edit
```

### Problem: Code owner can't review on time
```bash
# Escalate to backup reviewer (see CODE_OWNER_REVIEW_MATRIX.md)
# Or ask @chief-director to break tie
```

### Problem: Need to restart cleanup
```bash
# Reset to before you started
git reset --hard safety/pre-cleanup-<original-timestamp>

# Analyze what went wrong
git log --all --oneline | head -20

# Can try again with different approach
```

### Problem: Feature branch got corrupted
```bash
# Go back to main (discard feature branch)
git checkout main
git reset --hard origin/main

# Delete problematic branch
git branch -D chore/repo-cleanup-<timestamp>

# Start over:
bash repo-cleanup-execute.sh
```

---

## 📚 Reference Documents

After executing this cleanup, review these documents for complete context:

1. **REPO_CLEANUP_STRATEGY.md** - Full strategy (5000+ lines)
   - Detailed phase breakdowns
   - Complete commit messages
   - Validation matrices per group
   - Rollback procedures

2. **CODE_OWNER_REVIEW_MATRIX.md** - Review guide
   - Review checklists per group
   - Approval criteria
   - Escalation procedures
   - Quick review process

3. **repo-cleanup-execute.sh** - Automated execution script
   - Runs phases 1-5
   - Supports --dry-run
   - Generates validation report
   - Creates feature branch

4. **REPO_CLEANUP_VALIDATION_*.txt** - Generated report
   - Runs after execution
   - Lists commits created
   - Shows validation results
   - Provides next steps

---

## ✨ Success Indicators

After cleanup completes successfully:

✅ **Git History:**
- 6 intentional commits with clear scope
- No merge commits or mass changes
- Squashed unrelated modifications

✅ **Repository State:**
- main branch is clean
- No dirty working directory
- All changes are staged and committed

✅ **Code Quality:**
- All scripts pass syntax checks
- Documentation is complete and accurate
- Links are valid and not broken

✅ **Security:**
- Secret scan shows no issues
- No credentials in git history
- Environment templates are safe

✅ **Team Alignment:**
- All code owners reviewed their groups
- Decisions are documented
- Rollback plan is clear

---

## 🎯 Next Steps After Cleanup

Once cleanup merges to main:

1. **Verify main branch**
   ```bash
   git checkout main
   git pull origin main
   git log --oneline -10
   ```

2. **Update submodules**
   ```bash
   git submodule update --recursive
   ```

3. **Test deployment procedures**
   ```bash
   bash scripts/launch-smainer-stack.sh --dry-run
   ```

4. **Archive old backups**
   ```bash
   # Delete safety tags (once confident)
   git tag -d safety/pre-cleanup-*
   ```

5. **Communicate completion**
   - Close related GitHub issues
   - Update CONTRIBUTING.md
   - Post announcement to team

---

## 📞 Questions & Support

| Question | Reference |
|----------|-----------|
| How do I roll back? | REPO_CLEANUP_STRATEGY.md → Rollback Procedures |
| How do I review my group? | CODE_OWNER_REVIEW_MATRIX.md → Your group section |
| What if something breaks? | This doc → "If Something Goes Wrong" |
| How do I run phases separately? | `repo-cleanup-execute.sh --help` |
| Where are the detailed specs? | REPO_CLEANUP_STRATEGY.md |

---

**Ready to start?**
```bash
cd /home/smainer/Smainer
bash repo-cleanup-execute.sh --dry-run    # First: see what would happen
bash repo-cleanup-execute.sh              # Then: run for real
```

**Questions?** Review the detailed strategy documents or reach out to your code owners.

---

**Version:** 1.0  
**Last Updated:** 2026-03-16  
**Maintained by:** Repository Architect
