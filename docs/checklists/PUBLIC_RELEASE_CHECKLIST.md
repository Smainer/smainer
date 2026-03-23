# PUBLIC RELEASE CHECKLIST
**Monorepo**: Smainer  
**Last Updated**: 2026-03-14  
**Status**: 🟡 In Progress — security improved, not universally green

> **How to use**: Work through phases top-to-bottom. Each phase must reach its pass criteria before proceeding. Blockers are documented at the bottom — resolve them first if they affect your phase.

---

## 📋 QUICK OVERVIEW

| Phase | Status | Owner |
|-------|--------|-------|
| 1. Security Hygiene | 🟡 Critical fixed, medium partial | @security-expert |
| 2. Backend Tests | 🟡 Relayer passing, provider env-sensitive | @relayer-architect / @systems-engineer |
| 3. Contracts Tests | 🟡 Suite exists, broken variant excluded | @starknet-engineer |
| 4. Frontend / Desktop / Telegram Tests | 🟡 Builds pass, e2e pending | @frontend-engineer |
| 5. Documentation Cleanup | 🟡 Docs present, stale references exist | @repository-architect |
| 6. Final Review | ⬜ Not started | All owners |
| 7. Push | ⬜ Not started | @repository-architect |

---

## PHASE 1 — Security Hygiene
**Owner**: @security-expert  
**Status**: 🟡 8 critical + 3 high resolved; 1 medium + 1 low remaining

### 1.1 Scan for Secrets in Working Tree
```bash
# Check for hardcoded secrets not yet committed
cd /home/smainer/Smainer
grep -rn --include="*.py" --include="*.ts" --include="*.tsx" \
  --include="*.js" --include="*.env*" --include="*.yml" \
  -E "(SECRET|PRIVATE_KEY|BOT_TOKEN|API_KEY)\s*=\s*['\"][a-zA-Z0-9/+]{20,}" \
  . --exclude-dir=node_modules --exclude-dir=.venv \
  --exclude-dir=orchestration_env --exclude-dir=target \
  --exclude-dir=.pytest_cache
```
- [ ] Output is empty (no live secrets)

### 1.2 Scan Git History for Leaked Secrets
```bash
git log --all --oneline | wc -l   # confirm history exists

# Quick grep of most recent 50 commits
git log --all -p --since="90 days ago" -- \
  '*.env' '*.env.prod' '*.env.local' \
  | grep -E "(PRIVATE_KEY|BOT_TOKEN|SECRET)\s*=" | grep -v "PLACEHOLDER\|REPLACE\|YOUR_"
```
- [ ] No live secrets found in history

### 1.3 Run Automated Security Validation
```bash
bash /home/smainer/Smainer/scripts/security-validation.sh
```
- [ ] Script exits 0 — all checks PASS

### 1.4 Run Security Gate Tests (Backend)
```bash
cd /home/smainer/Smainer/backend
source /home/smainer/Smainer/.venv/bin/activate
python -m pytest tests/test_mainnet_security_gates.py \
                 tests/test_security_secrets.py -v
```
- [ ] All security gate tests pass

### 1.5 File Permissions Audit
```bash
find /home/smainer/Smainer -name "*.env*" -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" -not -path "*/orchestration_env/*" \
  -exec stat -c "%a %n" {} \;
```
- [ ] No `.env` files are world-readable (600 or 640 acceptable; 644+ is a fail)

### 1.6 Verify No Hardcoded Default Keys Remain
```bash
grep -rn "DANGEROUS\|sk_test_\|REQUIRED_REPLACE\|0xdeadbeef\|change_me" \
  /home/smainer/Smainer \
  --include="*.py" --include="*.ts" --include="*.cairo" \
  --exclude-dir=node_modules --exclude-dir=.venv \
  --exclude-dir=orchestration_env
```
- [ ] Any hit containing `REQUIRED_REPLACE` is a template file — confirm no `.env.prod` is using it as-is

**Pass Criteria**: Script exits 0, no live secrets in tree or history, file permissions hardened.

---

## PHASE 2 — Backend Tests
**Owner**: @relayer-architect (relayer) / @systems-engineer (provider)

### 2.1 Activate Environment
```bash
source /home/smainer/Smainer/.venv/bin/activate
python --version   # must be 3.11+
```
- [ ] Python 3.11+ confirmed

### 2.2 Install Relayer Dependencies
```bash
cd /home/smainer/Smainer/backend/relayer
pip install -e ".[dev]" --quiet
```
- [ ] No dependency resolution errors

### 2.3 Run Relayer Test Suite
```bash
cd /home/smainer/Smainer/backend/relayer
python -m pytest tests/ -v --tb=short 2>&1 | tee /tmp/relayer-test-results.txt
grep -E "passed|failed|error" /tmp/relayer-test-results.txt | tail -3
```
- [ ] 0 failures, 0 errors (warnings acceptable)

### 2.4 Relayer Import Smoke Test
```bash
cd /home/smainer/Smainer/backend/relayer
python -c "from src.relayer.main import app; print('✅ App loaded')"
```
- [ ] Prints `✅ App loaded`

### 2.5 Relayer Security-Specific Tests
```bash
cd /home/smainer/Smainer/backend/relayer
python -m pytest tests/test_security_attacks.py \
                 tests/test_security_auth.py \
                 tests/test_rate_limiting.py \
                 tests/test_log_security.py -v
```
- [ ] All pass

### 2.6 Install Provider Dependencies
```bash
cd /home/smainer/Smainer/backend/provider
pip install -e ".[dev]" --quiet
```
- [ ] Installs without fatal errors  
  > ⚠️ `nvidia-ml-py` may log warnings on CPU-only hosts — this is expected (graceful fallback in `monitor.py`). See [Blocker B-1](#b-1-nvidia-ml-py-on-cpu-only-environments).

### 2.7 Run Provider Test Suite
```bash
cd /home/smainer/Smainer/backend/provider
python -m pytest tests/ -v --tb=short 2>&1 | tee /tmp/provider-test-results.txt
grep -E "passed|failed|error|skip" /tmp/provider-test-results.txt | tail -3
```
- [ ] 0 failures, 0 errors (GPU-specific tests may be skipped — acceptable)

### 2.8 Run Release Gate Validation
```bash
cd /home/smainer/Smainer/backend
source /home/smainer/Smainer/.venv/bin/activate
bash validate_release_gates.sh 2>&1 | tee /tmp/release-gates.txt
grep -E "PASS|FAIL|ERROR" /tmp/release-gates.txt
```
- [ ] All gates GREEN

**Pass Criteria**: Relayer full suite + security tests pass. Provider tests pass with GPU skips allowed. Release gate script exits 0.

---

## PHASE 3 — Contracts Tests
**Owner**: @starknet-engineer

### 3.1 Verify Scarb and snforge Tools
```bash
cd /home/smainer/Smainer/contracts
scarb --version
snforge --version
starkli --version
```
- [ ] All tools present and version-matched to `Scarb.toml`

### 3.2 Build Contracts
```bash
cd /home/smainer/Smainer/contracts
scarb build 2>&1 | tee /tmp/scarb-build.txt
grep -E "error|warning|Finished" /tmp/scarb-build.txt
```
- [ ] `Finished` with 0 errors (warnings acceptable)
- [ ] Artifacts exist in `contracts/target/dev/`

### 3.3 Run Contract Test Suite
```bash
cd /home/smainer/Smainer/contracts
snforge test 2>&1 | tee /tmp/snforge-results.txt
grep -E "passed|failed|FAILED" /tmp/snforge-results.txt | tail -5
```
- [ ] 0 failures  
  > ⚠️ `test_signature_verification.cairo.broken` is intentionally excluded — do not rename it. See [Blocker B-2](#b-2-broken-cairo-test-variant).

### 3.4 Security-Specific Contract Tests
```bash
cd /home/smainer/Smainer/contracts
snforge test tests/test_security_mainnet_gates.cairo \
             tests/test_security_fixes.cairo -v
```
- [ ] Replay protection test passes
- [ ] Access control test passes
- [ ] Arithmetic safety test passes

### 3.5 Confirm Contract Addresses Consistent
```bash
# Ensure all components reference the same deployed contract address
grep -rn "COMPUTE_CONTRACT_ADDRESS\|CONTRACT_ADDRESS" \
  /home/smainer/Smainer/frontend/.env* \
  /home/smainer/Smainer/telegram/miniapp/.env* \
  /home/smainer/Smainer/backend/relayer/.env* \
  2>/dev/null | grep -v "example\|template"
```
- [ ] All non-template files point to the same mainnet contract address

**Pass Criteria**: `scarb build` clean, `snforge test` 0 failures, security gates pass, addresses consistent.

---

## PHASE 4 — Frontend / Desktop / Telegram Tests
**Owner**: @frontend-engineer

### 4.1 Frontend — Install & Lint
```bash
cd /home/smainer/Smainer/frontend
npm ci --prefer-offline
npx next lint 2>&1 | tail -10
```
- [ ] `npm ci` exits 0
- [ ] No lint errors (warnings acceptable)

### 4.2 Frontend — Unit Tests
```bash
cd /home/smainer/Smainer/frontend
npx vitest run --reporter=verbose 2>&1 | tee /tmp/frontend-tests.txt
grep -E "passed|failed|Tests" /tmp/frontend-tests.txt | tail -5
```
- [ ] 0 failures

### 4.3 Frontend — Production Build
```bash
cd /home/smainer/Smainer/frontend
npm run build 2>&1 | tee /tmp/frontend-build.txt
grep -E "error|✓|Route" /tmp/frontend-build.txt | tail -10
```
- [ ] Build exits 0, no `error` lines

### 4.4 Frontend — Security Scan
```bash
cd /home/smainer/Smainer/frontend
bash run-security-tests.sh
```
- [ ] Exits 0

### 4.5 Desktop App — Build Check
```bash
cd /home/smainer/Smainer/desktop
npm ci --prefer-offline
npm run build 2>&1 | tail -5
```
- [ ] Exits 0 (no code changes expected; confirm clean build)

### 4.6 Telegram Bot — Dependency Check
```bash
cd /home/smainer/Smainer/telegram/telegram-bot
pip install -r requirements.txt --dry-run 2>&1 | grep -E "error|conflict" || echo "✅ No conflicts"
```
- [ ] No conflicts

### 4.7 Telegram Miniapp — Build
```bash
cd /home/smainer/Smainer/telegram/miniapp
npm ci --prefer-offline
npm run build 2>&1 | tail -5
```
- [ ] Exits 0

**Pass Criteria**: Frontend builds, unit tests pass, security scan clean. Desktop builds. Telegram miniapp builds.

---

## PHASE 5 — Documentation Cleanup
**Owner**: @repository-architect

### 5.1 Verify README Accuracy
```bash
# Check all placeholder URLs/addresses in READMEs
grep -rn "localhost:8000\|YOUR_\|PLACEHOLDER\|TODO\|FIXME" \
  /home/smainer/Smainer/README.md \
  /home/smainer/Smainer/frontend/README.md \
  /home/smainer/Smainer/backend/relayer/README.md \
  /home/smainer/Smainer/contracts/README.md
```
- [ ] Any hits are intentional placeholders in setup instructions (not stale data)

### 5.2 Verify CONTRIBUTING.md Is Current
```bash
head -30 /home/smainer/Smainer/CONTRIBUTING.md
```
- [ ] Branch naming, PR process, and setup instructions reflect current codebase

### 5.3 Verify SECURITY.md Disclosure Process
```bash
cat /home/smainer/Smainer/SECURITY.md | grep -E "contact|email|report"
```
- [ ] A working disclosure contact exists

### 5.4 Verify LICENSE Present in All Components
```bash
for dir in frontend backend/relayer backend/provider contracts telegram desktop; do
  [ -f /home/smainer/Smainer/$dir/LICENSE ] \
    && echo "✅ $dir" || echo "❌ MISSING: $dir"
done
```
- [ ] All components have LICENSE files

### 5.5 Check for Sensitive Comments in Public Docs
```bash
grep -rn --include="*.md" \
  -E "(password|secret|private.?key|api.?key)\s*[:=]\s*\S" \
  /home/smainer/Smainer \
  --exclude-dir=node_modules --exclude-dir=.venv \
  --exclude-dir=orchestration_env
```
- [ ] No live credentials in markdown files

**Pass Criteria**: READMEs accurate, contributing guide current, SECURITY.md has disclosure contact, all components licensed, no secrets in docs.

---

## PHASE 6 — Final Review
**Owner**: All owners sign off

### 6.1 Full Secret Scan (Final Gate)
```bash
cd /home/smainer/Smainer
bash scripts/security-validation.sh && echo "✅ SECURITY GATE PASSED"
```
- [ ] Script exits 0

### 6.2 Dependency Vulnerability Audit
```bash
# Python (relayer + provider)
source /home/smainer/Smainer/.venv/bin/activate
pip-audit --desc 2>&1 | grep -E "vuln|CRITICAL|HIGH" || echo "✅ No high/critical CVEs"

# Frontend
cd /home/smainer/Smainer/frontend
npm audit --audit-level=high 2>&1 | tail -10
```
- [ ] No critical or high CVEs unmitigated

### 6.3 Confirm .env Files Not Staged
```bash
cd /home/smainer/Smainer
git status --short | grep -E "\.env$|\.env\.prod$|\.env\.local$" | grep -v example | grep -v template
```
- [ ] Output is empty (no live env files staged)

### 6.4 Confirm .gitignore Covers All Env Files
```bash
git check-ignore -v \
  backend/relayer/.env \
  backend/provider/.env \
  frontend/.env.local \
  telegram/miniapp/.env.local 2>&1
```
- [ ] All files are ignored by git

### 6.5 Cross-Component Contract Address Consistency (Final Check)
```bash
# Extract unique CONTRACT_ADDRESS values across all non-template envs
grep -rh "CONTRACT_ADDRESS=" \
  /home/smainer/Smainer/backend/relayer/.env \
  /home/smainer/Smainer/frontend/.env.local \
  /home/smainer/Smainer/telegram/miniapp/.env.local \
  2>/dev/null | sort -u
```
- [ ] Exactly one unique address value (all components agree)

### 6.6 Mainnet Network Consistency Check
```bash
grep -rh "STARKNET_RPC_URL\|NEXT_PUBLIC_RPC_URL\|RPC_URL" \
  /home/smainer/Smainer/backend/relayer/.env \
  /home/smainer/Smainer/frontend/.env.local \
  /home/smainer/Smainer/telegram/telegram-bot/.env \
  2>/dev/null | grep -v "testnet\|goerli\|sepolia" | head -10
```
- [ ] All configured URLs point to mainnet (no testnet RPC in production envs)

### 6.7 E2E Smoke Test (Staging or Mainnet)
```bash
# Relayer health
curl -sf https://<RELAYER_PROD_URL>/api/v1/health | python3 -m json.tool

# Frontend availability
curl -sf -o /dev/null -w "%{http_code}" https://<FRONTEND_PROD_URL>/
```
- [ ] Relayer returns `{"status": "ok"}` (or equivalent)  
- [ ] Frontend returns HTTP 200

### 6.8 Owner Sign-Off
| Owner | Area | Signed Off |
|-------|------|-----------|
| @security-expert | Security gates, secret scan, CVE audit | [ ] |
| @relayer-architect | Relayer tests, release gates, API health | [ ] |
| @systems-engineer | Provider tests, infrastructure, .env audit | [ ] |
| @starknet-engineer | Contract build, snforge tests, address consistency | [ ] |
| @frontend-engineer | Frontend build/tests, miniapp build | [ ] |
| @repository-architect | Docs, gitignore, final secret scan, git hygiene | [ ] |

**Pass Criteria**: All 6.1–6.7 checks green. All 6 owners signed off.

---

## PHASE 7 — Push
**Owner**: @repository-architect

### 7.1 Review Staged Changes
```bash
cd /home/smainer/Smainer
git diff --stat HEAD
git status --short
```
- [ ] Only expected files in diff — no `.env`, no keystore files, no secrets

### 7.2 Run Pre-Push Checks
```bash
cd /home/smainer/Smainer
git diff --name-only HEAD | xargs grep -l "PRIVATE_KEY\|SECRET\|password" 2>/dev/null \
  | grep -v "\.example\|template\|REQUIRED_REPLACE" || echo "✅ No secrets in diff"
```
- [ ] Output: `✅ No secrets in diff`

### 7.3 Commit with Conventional Message
```bash
git add -p   # stage interactively — review each hunk
git commit -m "chore(release): public release readiness — all gates passed"
```
- [ ] Commit message follows conventional commits format

### 7.4 Tag Release
```bash
cd /home/smainer/Smainer
git tag -a v0.1.0 -m "Public release v0.1.0 — initial mainnet readiness"
```
- [ ] Tag created

### 7.5 Push Branch and Tag
```bash
git push origin <branch-name>
git push origin v0.1.0
```
- [ ] CI passes on remote (GitHub Actions green)
- [ ] No secrets scanner alerts triggered

**Pass Criteria**: Push accepted, CI green, no security alerts triggered, tag visible on remote.

---

## 🚧 KNOWN BLOCKERS

### B-1: `nvidia-ml-py` on CPU-Only Environments
**Affected**: `backend/provider` install + tests  
**Symptom**: `pip install` may succeed but `pynvml` module may print runtime warnings on hosts without NVIDIA drivers.  
**Status**: Gracefully handled — `monitor.py` wraps `import pynvml` in `try/except ImportError` with `pynvml = None` fallback. GPU metric collection skips automatically.  
**Remediation**:
```bash
# Verify graceful fallback on CPU host
cd /home/smainer/Smainer/backend/provider
python -c "from src.provider.monitor import ResourceMonitor; print('✅ Monitor imports clean')"

# If tests that require GPU are flagging:
python -m pytest tests/test_monitor.py -v -k "not gpu"
```
**Owner**: @systems-engineer  
**Blocking release**: No — non-GPU provider nodes degrade gracefully.

---

### B-2: Broken Cairo Test Variant (`test_signature_verification.cairo.broken`)
**Affected**: `contracts/tests/`  
**Symptom**: `snforge test` may attempt to compile `.broken` file depending on Scarb version.  
**Status**: File retained intentionally (documents a known issue). Not included in test runs at this time.  
**Remediation**:
```bash
# Confirm snforge ignores it (Scarb should not compile non-.cairo extensions)
cd /home/smainer/Smainer/contracts
snforge test 2>&1 | grep "broken" || echo "✅ .broken file ignored"

# If it causes a compile error, exclude explicitly:
snforge test --filter-contract "^(?!.*broken).*$"
```
**Owner**: @starknet-engineer  
**Blocking release**: No — fix or explicitly exclude before tagging.

---

### B-3: Relayer `.env` Must Be Set Before Any Live Tests
**Affected**: Phase 2, Phase 6 smoke tests  
**Symptom**: `uvicorn` startup or health endpoint fails if `.env` is missing or using defaults.  
**Status**: `.env.example` exists; production values not committed (correct).  
**Remediation**:
```bash
cd /home/smainer/Smainer/backend/relayer
[ -f .env ] && echo "✅ .env exists" || cp .env.example .env && echo "⚠️ Copied .env.example — populate required values"

# Required values to populate:
# REDIS_URL, STARKNET_RPC_URL, RELAYER_PRIVATE_KEY,
# CONTRACT_ADDRESS, API_KEY (change from default!)
```
**Owner**: @relayer-architect  
**Blocking release**: Yes — must be populated before Phase 6 smoke test and production deploy.

---

### B-4: Vercel Environment Variables Not Synced
**Affected**: Phase 4 (frontend production build), Phase 6 smoke test  
**Symptom**: Frontend builds locally but serves wrong contract address on Vercel.  
**Status**: Mainnet addresses coded; Vercel env not confirmed updated.  
**Remediation**:
```bash
# Verify Vercel project env vars via CLI
vercel env ls --scope=production 2>/dev/null | grep -E "CONTRACT|RPC|CHAIN"

# Or update manually:
vercel env add NEXT_PUBLIC_COMPUTE_CONTRACT_ADDRESS production
vercel env add NEXT_PUBLIC_RPC_URL production
vercel --prod
```
**Owner**: @frontend-engineer  
**Blocking release**: Yes — must be verified before Phase 7 push.

---

### B-5: Provider Daemon Not Deployed / Verified
**Affected**: E2E smoke test (Phase 6.7)  
**Symptom**: No provider nodes register with relayer; tasks never route.  
**Status**: Provider daemon code complete; deployment not verified per 2026-03-14 war room notes.  
**Remediation**:
```bash
# On provider host:
cd /home/smainer/Smainer/backend/provider
bash launch_provider.sh

# Verify registration on relayer:
curl -H "Authorization: Bearer $API_KEY" \
  https://<RELAYER_URL>/api/v1/nodes | python3 -m json.tool
```
**Owner**: @systems-engineer  
**Blocking release**: Yes for full E2E test; no for component-level release.

---

### B-6: Medium/Low Security Findings (Residual)
**Affected**: Phase 1  
**Symptom**: `SECURITY_AUDIT_REPORT.md` documents 1 medium + 1 low severity finding not yet remediated.  
**Status**: All critical and high fixed. Medium partially done, low planned.  
**Remediation**: Review `SECURITY_AUDIT_REPORT.md` §Medium and §Low sections; determine if acceptable for initial public release or must be fixed.  
**Owner**: @security-expert  
**Blocking release**: Judgment call — document risk acceptance decision if shipping with these open.

---

## APPENDIX — Useful One-Liners

```bash
# Full test run across all Python components
source /home/smainer/Smainer/.venv/bin/activate
python -m pytest backend/relayer/tests/ backend/provider/tests/ backend/tests/ -v --tb=short

# Check all Python imports are healthy
python -c "
from src.relayer.main import app
print('relayer ✅')
" 2>&1  # run from backend/relayer

# Quick secret grep (safe to re-run anytime)
grep -rn --include="*.py" --include="*.ts" --include="*.cairo" \
  -E "0x[a-fA-F0-9]{60,}" \
  /home/smainer/Smainer \
  --exclude-dir=node_modules --exclude-dir=.venv \
  --exclude-dir=target --exclude-dir=orchestration_env \
  | grep -v "test\|mock\|example\|placeholder" | head -20

# Git log — confirm no accidental secret commits
git log --all --oneline --since="7 days ago"
```
