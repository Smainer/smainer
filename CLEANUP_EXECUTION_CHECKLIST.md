# Repository Cleanup: Execution Checklist & Decision Tree

Use this checklist **before** and **during** the cleanup execution.

---

## 🟢 PRE-EXECUTION CHECKLIST (Do these FIRST)

**Before running `repo-cleanup-execute.sh`:**

### Team & Notification
- [ ] Identified all 6 code owners (security, repo-arch, systems, devops, product, chief-director)
- [ ] Team notified: "Cleanup starting, reviews needed in next 24-48h"
- [ ] Code owner availability confirmed (at least 4 of 6)
- [ ] Escalation contacts identified (backups for unavailable reviewers)

### Preparation
- [ ] Read REPO_CLEANUP_STRATEGY.md (took ~15 min)
- [ ] Read CODE_OWNER_REVIEW_MATRIX.md (took ~15 min)
- [ ] Understood 6 commit groups and their scope
- [ ] Understood rollback procedures (via `git reset --hard safety/pre-cleanup-*`)

### Environment
- [ ] In clean git state: `git status` shows no uncommitted changes
- [ ] On main branch: `git branch` shows `* main`
- [ ] Synced with remote: `git fetch origin && git status` shows clean
- [ ] Remote exists: `git remote -v` shows origin pointing to GitHub

### Security
- [ ] No local secrets in any files: verified with grep
- [ ] No PRIVATE_KEY, API_KEY, PASSWORD visible anywhere
- [ ] .gitignore already excludes .env* files
- [ ] Read secret-redaction.instructions.md from .github/instructions/

### Script Validation
- [ ] repo-cleanup-execute.sh is executable: `ls -l repo-cleanup-execute.sh | grep ^-rwx`
- [ ] Bash version is 4+: `bash --version`
- [ ] Script has been reviewed for safety (not modifying git directly until Phase 3)

**Gate:** All boxes ☑️ before proceeding

---

## 🔵 DRY RUN CHECKLIST (Test without changes)

```bash
# STEP 1: Dry run the entire cleanup
bash /home/smainer/Smainer/repo-cleanup-execute.sh --dry-run 2>&1 | tee cleanup_dryrun.log

# While watching output, verify:
```

- [ ] **Phase 1: Critical Fixes**
  - [ ] Safety tag would be created
  - [ ] Submodule pointers show as being fixed (all to origin/main)
  - [ ] No actual commits happen (shows "[DRY RUN]" prefix)

- [ ] **Phase 2: File Organization**
  - [ ] Scripts moved from root to scripts/
  - [ ] Internal docs moved to .github/internal/
  - [ ] No data loss messages

- [ ] **Phase 3: Grouped Commits**
  - [ ] 6 separate commit commands shown
  - [ ] Each group has clear description
  - [ ] No "FAILED TO COMMIT" errors

- [ ] **Phase 4: Validation**
  - [ ] Report file would be generated
  - [ ] Secret scan results shown
  - [ ] Script validation performed

- [ ] **Phase 5: PR Creation**
  - [ ] Feature branch name shown
  - [ ] Push/PR instructions provided

**Gate:** Dry run completes with no errors

---

## 🟡 EXECUTION CHECKLIST (Actually run the cleanup)

```bash
# STEP 1: Run actual cleanup (creates real commits)
bash /home/smainer/Smainer/repo-cleanup-execute.sh 2>&1 | tee cleanup_execution.log

# Answer any interactive prompts (y/N for confirmations)
```

### Phase 1 Execution
- [ ] Safety tag created successfully
- [ ] Submodule status shows all on origin/main
- [ ] Commit "chore(submodules): restore all to origin/main" created
- [ ] No errors in output

### Phase 2 Execution
- [ ] 6 scripts moved from root: comprehensive-security-audit.sh, etc.
- [ ] Internal docs moved to .github/internal/
- [ ] No "No such file" errors

### Phase 3 Execution (Groups 1-4 committed)
- [ ] Commit 1: chore(config): created ✓
- [ ] Commit 2: chore(scripts): created ✓
- [ ] Commit 3: docs(launch): created ✓
- [ ] Commit 4: feat(automation): created ✓
- [ ] Each commit has clear message and scope

### Phase 4 Execution
- [ ] Validation report generated: REPO_CLEANUP_VALIDATION_*.txt
- [ ] Secret scan output shows: "✅ PASS: No hardcoded secrets"
- [ ] Script validation shows all ✓
- [ ] Submodule status correct

### Phase 5 Execution
- [ ] Feature branch created: chore/repo-cleanup-TIMESTAMP
- [ ] Instructions shown for next steps

**Gate:** All phases complete with no errors

---

## 📋 POST-EXECUTION VERIFICATION

```bash
# Verify cleanup worked correctly
cd /home/smainer/Smainer

# 1. Check commits are there
git log --oneline origin/main..HEAD | wc -l
# Expected: Should show 4-6 commits

# 2. Verify submodules
git submodule status
# Expected: All show origin/main commit hashes, no backup branches

# 3. Check working tree
git status
# Expected: "On branch chore/repo-cleanup-*, nothing to commit"

# 4. Verify no commits accidentally included
git log --oneline -10 | grep -v "chore\|feat\|docs"
# Expected: Only shows previous commits, nothing new

# 5. Test one script works
bash scripts/launch-smainer-stack.sh --help
# Expected: Shows usage without errors
```

- [ ] Commit count correct (4-6 commits)
- [ ] All submodules on origin/main
- [ ] Working tree clean
- [ ] No unrelated commits mixed in
- [ ] Scripts are executable

**Gate:** All verifications pass

---

## 🟣 REVIEW ASSIGNMENT CHECKLIST

After execution completes:

```bash
# Find your branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Feature branch: $BRANCH"

# Get commit list
git log --oneline origin/main..$BRANCH
```

### Assign Reviews
Send to each code owner with this template:

**For Group 1 Reviewer (@security-expert):**
```
Please review commit 1/4 in PR: chore(config)
See CODE_OWNER_REVIEW_MATRIX.md → Group 1 for checklist
Expected time: 15 minutes
Decision: BLOCKING (must approve before merge)
```

**For Group 2 Reviewer (@systems-engineer):**
```
Please review commit 2/4 in PR: chore(scripts)
See CODE_OWNER_REVIEW_MATRIX.md → Group 2 for checklist
Run: bash scripts/launch-smainer-stack.sh --dry-run
Expected time: 20 minutes
Decision: BLOCKING (must approve before merge)
```

**For Group 3 Reviewer (@product-manager):**
```
Please review commit 3/4 in PR: docs(launch)
See CODE_OWNER_REVIEW_MATRIX.md → Group 3 for checklist
Key files: LAUNCH_GUIDE.md, PUBLIC_RELEASE_CHECKLIST.md
Expected time: 30 minutes
Decision: BLOCKING (must approve before merge)
```

**For Group 4 Reviewer (@devops-lead):**
```
Please review commit 4/4 in PR: feat(automation)
See CODE_OWNER_REVIEW_MATRIX.md → Group 4 for checklist
Run: bash scripts/smainer-stack-master.sh --help
Expected time: 25 minutes
Decision: BLOCKING (must approve before merge)
```

**For Group 5 Reviewer (@security-expert):**
```
Security validation scripts pending review (conditional).
Status: PENDING - requires dry-run and performance validation
Once approved: Can commit Group 5
```

**For Group 6 Reviewer (@chief-director):**
```
Release documentation ready for strategic review (decision gate).
Status: PENDING - awaiting chief director go/no-go
Once approved: Can commit Group 6
```

### Tracking
- [ ] Group 1: Awaiting @security-expert (due 48h)
- [ ] Group 2: Awaiting @systems-engineer (due 48h)
- [ ] Group 3: Awaiting @product-manager (due 48h)
- [ ] Group 4: Awaiting @devops-lead (due 48h)
- [ ] Group 5: Awaiting @security-expert conditional (due 72h)
- [ ] Group 6: Awaiting @chief-director decision (due 72h)

---

## ✅ DECISION TREE: What to Do If...

### "Review is taking too long"
```
Decision: Is it past the deadline?
  NO  → Keep waiting (reviews take 15-40 min)
  YES → Check: Did you notify the reviewer?
          NO  → Send reminder with specific commit
          YES → Escalate to reviewer's manager or backup
                (See CODE_OWNER_REVIEW_MATRIX.md → Escalation)
```

### "Reviewer requested changes"
```
Decision: What kind of changes?
  ONE-LINE FIX    → Edit file directly, amend commit, force-push
  MULTIPLE EDITS  → Create new commit with fixes, push again
  MAJOR REWORK    → Revert group, fix locally, re-request review
  
Command:
  git add <fixed-files>
  git commit --amend --no-edit
  git push origin $BRANCH --force-with-lease
```

### "Need to rollback"
```
Decision: How far back?
  LAST COMMIT ONLY         → git reset --soft HEAD~1
  ENTIRE GROUP (1-2 commits) → git reset --soft <commit-before-group>
  ALL COMMITS              → git reset --hard safety/pre-cleanup-*
  CORRUPTED STATE          → git reset --hard origin/main (NUCLEAR)
  
Check rollback worked:
  git log --oneline -10    # Should show expected history
  git status               # Should be clean
```

### "Submodule didn't update"
```
Decision: Check status:
  git submodule status
  # Still showing backup branch? = Error
  
Fix:
  cd backend  (or contracts, frontend, telegram)
  git fetch origin main
  git checkout origin/main
  cd ..
  git add backend
  git commit --amend --no-edit
  git push origin $BRANCH --force-with-lease
```

### "Script failed with syntax error"
```
Decision: Which script?
  
Fix:
  bash -n scripts/problem-script.sh    # Shows error line
  # Edit the file
  git add scripts/problem-script.sh
  git commit --amend --no-edit
  git push origin $BRANCH --force-with-lease
```

### "Secret accidentally committed"
```
Decision: Is it in latest commit?
  YES → git reset --soft HEAD~1
       (Remove secret from file)
       git add <file>
       git commit -m "fix: remove secret"
       
  NO (in earlier commit) → Escalate to @security-expert
                          May need git filter-branch
```

### "Need to pause & resume later"
```
Save your progress:
  git push origin $BRANCH
  # Leave PR open as draft
  
When resuming:
  git fetch origin
  git checkout $BRANCH
  # Continue from where stopped
```

---

## 🎯 MERGE READINESS CHECKLIST

Before merging to main, verify:

### All Reviews Complete
- [ ] Group 1: ✅ Approved by @security-expert AND @repo-architect
- [ ] Group 2: ✅ Approved by @systems-engineer
- [ ] Group 3: ✅ Approved by @product-manager
- [ ] Group 4: ✅ Approved by @devops-lead
- [ ] Group 5: ✅ Approved (CONDITIONAL) OR deferred to later
- [ ] Group 6: ✅ Approved (DECISION GATE) OR deferred to later

### No Merge Conflicts
```bash
git fetch origin main
git rebase origin/main
# Expected: "Fast-forward" or clean rebase, no conflicts
```

- [ ] No conflicts with origin/main
- [ ] Rebase successful (if needed)
- [ ] All commits still present

### Final Validation
```bash
# One last verification
git log --oneline origin/main..HEAD | wc -l
# Expected: 4-6 commits

git diff origin/main --stat | tail -1
# Expected: Reasonable number of files changed (< 50)
```

- [ ] All commits present
- [ ] Diff shows expected changes only
- [ ] No accidental files included

### PR Finalizations
- [ ] PR description complete and accurate
- [ ] All reviewer comments addressed
- [ ] Linked to any related GitHub issues
- [ ] Labels applied (e.g., "cleanup", "documentation")

**Gate:** When all boxes ☑️:
```bash
# Merge to main
gh pr merge $PR --squash  # Or --rebase if keeping all commits
```

---

## 🏁 POST-MERGE TASKS

After merged to main:

```bash
# 1. Switch to main
git checkout main
git pull origin main

# 2. Verify merge
git log --oneline -10  # Should see all 4-6 cleanup commits

# 3. Test cleanup worked
bash scripts/launch-smainer-stack.sh --help
# Expected: Help text, no errors

# 4. Delete feature branch
git branch -d chore/repo-cleanup-*
git push origin --delete chore/repo-cleanup-*

# 5. Update submodules
git submodule update --recursive

# 6. Tag the successful cleanup
git tag -a cleanup/complete-20260316 \
  -m "Repository cleanup successfully merged: 6 commits, all reviews passed"
git push origin cleanup/complete-20260316
```

- [ ] On main branch (VERIFY THIS FIRST)
- [ ] All 4-6 cleanup commits visible in history
- [ ] Scripts execute without errors
- [ ] Feature branch deleted (local and remote)
- [ ] Submodules updated
- [ ] Success tag created and pushed
- [ ] Notified team: "Cleanup complete, main branch now clean"

---

## 📊 Completion Metrics

When done, measure success:

```bash
# Repository health score
echo "=== REPOSITORY HEALTH SCORE ==="

# 1. Commit cleanliness
echo "Clean commits (6 groups):"
git log --oneline origin/main..HEAD | grep "^chore\|^docs\|^feat" | wc -l

# 2. Documentation coverage
echo "Docs committed:"
find . -name "*.md" -newer $(git log -n1 --format=%h -- REPO_CLEANUP_STRATEGY.md) \
  | wc -l

# 3. Secret scan
echo "Secret scan:"
git log -p origin/main..HEAD | grep -i "PRIVATE_KEY\|password" && echo "FAIL" || echo "PASS"

# 4. Script quality
echo "Scripts executable:"
stat -c "%a" scripts/*.sh | grep -c "755"

# 5. Submodule sync
echo "Submodules on main:"
git submodule status | grep -c "origin/main"
```

---

## 🆘 Emergency Contacts

If something goes wrong and you're stuck:

| Scenario | Contact | Action |
|----------|---------|--------|
| Code owner unavailable | Manager OR backup reviewer | Escalate per CODE_OWNER_REVIEW_MATRIX.md |
| Merge conflict | @repository-architect | Guide rebase or cherry-pick strategy |
| Secret committed | @security-expert | CRITICAL: Follow secret remediation |
| Script broken | @systems-engineer | Fix syntax or restore from backup tag |
| Unsure about rollback | @chief-director | Decision authority on full reset |

---

**Remember:**
- ✅ All changes are local until `git push origin`
- ✅ Rollback is always one command away: `git reset --hard <tag>`
- ✅ Reviews are YOUR safety net - use them!
- ✅ When in doubt, ask - this is collaboration

**Status:** Ready to execute ✅  
**Last Updated:** 2026-03-16
