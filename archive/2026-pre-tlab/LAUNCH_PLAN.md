# Smainer Launch Plan

Consolidated execution plan covering local node bring-up, production-parity launch rehearsal, frontend recovery, and the new node catalog page. Each section has owners, ordered actions, acceptance checks, and go/no-go gates. This document is the source of truth for the next execution cycle.

---

## Section 1 — Local Node Bring-Up (venv path)

**Critical dependency chain**: Redis → Relayer → Provider.
Provider defaults to `ws://localhost:8000` ([backend/provider/src/provider/config.py](backend/provider/src/provider/config.py#L12)), example config matches in [backend/provider/.env.example](backend/provider/.env.example#L2), and the relayer defaults to port `8000` per [backend/relayer/README.md](backend/relayer/README.md#L94). The earlier `18000` assumption is wrong.

**Two repo-specific traps**:
- The provider code reads `.env`, not `.env.local`, in [backend/provider/src/provider/config.py](backend/provider/src/provider/config.py#L12), while the helper daemon script expects `.env.local` in [backend/provider/local-provider-daemon.sh](backend/provider/local-provider-daemon.sh#L10).
- The relayer health route is actually `/api/v1/health` because the router prefix in [backend/relayer/src/relayer/api/routes.py](backend/relayer/src/relayer/api/routes.py#L45) wraps the `/health` handler in [backend/relayer/src/relayer/api/routes.py](backend/relayer/src/relayer/api/routes.py#L399).

### Detailed Plan

1. **Preflight venv and provider package.** Use the existing venv at `/home/smainer/Smainer/.venv`, then run [backend/provider/validate_provider_setup.sh](backend/provider/validate_provider_setup.sh). Expected: `starknet-py` and `websockets` import checks pass. Failure branch: repair the shared root venv, do not create a second provider-only venv.
2. **Start Redis first.** Use [deployment/redis.conf](deployment/redis.conf) and validate with [validate-redis-batch-health.sh](validate-redis-batch-health.sh). Expected: `redis-cli ping` returns `PONG`. Failure branch: if validator targets `redis` instead of `localhost`, override `REDIS_HOST=localhost`.
3. **Bring up the relayer on port 8000 inside the same root venv.** Use [backend/relayer/.env.example](backend/relayer/.env.example) as the env template and start from [backend/relayer/src/relayer/main.py](backend/relayer/src/relayer/main.py). Expected: `/api/v1/health` answers OK. Failure branch: if `python -m relayer.main` fails, follow the dev path in [backend/relayer/README.md](backend/relayer/README.md#L107) or run with `PYTHONPATH=src`.
4. **Configure the provider via `.env`, not `.env.local`.** Canonical loader: [backend/provider/src/provider/config.py](backend/provider/src/provider/config.py#L12). Expected: `RELAYER_WS_URL=ws://localhost:8000`, unique `NODE_ID`, valid non-placeholder Starknet key, writable sandbox path (e.g. `/tmp/provider_sandbox_<user>`). Failure branch: if using [backend/provider/local-provider-daemon.sh](backend/provider/local-provider-daemon.sh), duplicate the same settings into `.env.local`.
5. **Launch the provider with the root venv and the repo-supported entrypoint.** Prefer [backend/provider/launch_provider.sh](backend/provider/launch_provider.sh) or the installed console script declared in [backend/provider/pyproject.toml](backend/provider/pyproject.toml#L39). Expected: `test_setup.py` passes, daemon stays alive, attempts WebSocket registration. Failure branch: switch to foreground via `provider-daemon` or `python -m provider.main` to surface the auth error directly.
6. **Validate provider registration through the API, not just logs.** Use [check-provider-status.sh](check-provider-status.sh), which queries `/api/v1/nodes` and requires `RELAYER_API_KEY`. Expected: node appears in node list with hardware metadata. Failure branch: inspect [backend/relayer/src/relayer/api/websocket.py](backend/relayer/src/relayer/api/websocket.py#L189) before changing provider startup again.
7. **Separate "node online" from "node can run AI tasks".** Inference path uses Ollama defaults in [backend/provider/src/provider/config.py](backend/provider/src/provider/config.py#L81) and the local Ollama API in [backend/provider/src/provider/enhanced_executor.py](backend/provider/src/provider/enhanced_executor.py#L417). Expected: registration works without Ollama; AI jobs require Ollama at `127.0.0.1:11434`. Failure branch: treat Ollama as a second-stage runtime dependency, not a startup blocker.

### Blockers To Plan Around

- `.env` vs `.env.local` mismatch between provider code and helper script.
- Some scripts still probe `/health`; canonical route is `/api/v1/health`.
- WebSocket auth may still fail post-startup — see [backend/provider/validate_provider_setup.sh](backend/provider/validate_provider_setup.sh#L93).
- [check-provider-status.sh](check-provider-status.sh#L8) requires `RELAYER_API_KEY` (or `API_KEY`) exported.
- Real Starknet key required for realistic auth testing — placeholder in [backend/provider/.env.example](backend/provider/.env.example#L5) is template only.

### Recommended First Execution Sequence

1. Activate root venv and validate provider dependencies.
2. Start Redis locally and confirm response.
3. Copy [backend/relayer/.env.example](backend/relayer/.env.example) to `.env`, fill required values, start relayer on port `8000`.
4. Copy [backend/provider/.env.example](backend/provider/.env.example) to `.env`, set `RELAYER_WS_URL=ws://localhost:8000`, real Starknet key, unique `NODE_ID`, `/tmp` sandbox path.
5. Start provider with [backend/provider/launch_provider.sh](backend/provider/launch_provider.sh) or `provider-daemon`.
6. Export `RELAYER_API_KEY`, run [check-provider-status.sh](check-provider-status.sh).
7. Only after registration is green, add Ollama and task-execution verification.

---

## Section 2 — Production-Parity Launch Rehearsal

**This is a production-parity product rehearsal, not endpoint testing.** Success is stable daemon lifecycle plus real task execution flow under production constraints — not API reachability.

### Mandatory Runtime Model

- Run daemon with production process semantics (systemd/cgroup isolation), not ad-hoc foreground dev execution.
- Use production config semantics and signing path with real credentials loaded securely.
- Use production-equivalent sandboxing and shutdown behavior.

### Two Approved Rehearsal Variants

- **Single-host production-sim**: same process model, same resource limits, same config loading behavior.
- **Real staging dry-run**: full relayer + Redis topology, websocket auth, task dispatch and completion path.

### Hard No-Go Conditions

- Any fake/test key usage.
- Any endpoint-only proof (curl health checks alone).
- Any plaintext secret leakage in logs / process environment / artifacts.
- Any daemon run outside production process isolation.
- Any mismatch between configured sandbox policy and runtime sandbox path.

### Required Launch Evidence

- Process isolation proof (cgroup/systemd evidence).
- Authenticated websocket session and stable relayer connectivity.
- Real task execution with signed result path.
- Graceful shutdown and cleanup evidence.
- Secret-redaction verification from runtime logs.
- Resource-limit compliance during sustained run window.

### Security Verdict — Pass With Conditions

Before rehearsal is considered valid, tighten:

1. **Unified sandbox path.** Enforce `/var/lib/smainer-provider/sandbox` exclusively across all scripts; remove `/tmp` fallbacks in [war-room-infra-startup.sh](war-room-infra-startup.sh#L48) and [backend/provider/launch_provider.sh](backend/provider/launch_provider.sh#L20).
2. **Secure credential injection.** Replace environment variable passthrough (`--setenv`) with systemd `EnvironmentFile=/var/lib/smainer-provider/.env` (mode 600). Use `STARKNET_SIGNER_FILE` instead of `STARKNET_PRIVATE_KEY`. Avoid env var names containing "KEY".
3. **cgroups hardening.** Replace `systemd-run --user` scopes with system service using `DynamicUser=yes`. Remove `PrivateTmp=yes` from systemd template referenced in [backend/provider/README.md](backend/provider/README.md#L137); enforce only `ReadWritePaths=/var/lib/smainer-provider/sandbox`.
4. **Runtime secret-redaction validation.** `journalctl -u smainer-provider --since=1min | grep -v '0x[a-fA-F0-9]\{64\}' | wc -l` must equal total log lines. Provider daemon must implement log sanitization middleware before structured logging.

### Additional Guardrails

- **Network exposure**: WebSocket client must verify TLS chain in production. Provider must not bind any listening sockets (outbound client only). Add `PrivateNetwork=yes` to systemd service if possible.
- **Artifact storage**: All task execution artifacts must be written to sandbox subdirectories only. Cleanup within 60s post-completion. Sandbox mounted `noexec,nosuid`.

### Mandatory Launch Rehearsal Checklist

- [ ] systemd service uses `EnvironmentFile=/var/lib/smainer-provider/.env` (mode 600).
- [ ] Sandbox path is `/var/lib/smainer-provider/sandbox` in ALL configurations.
- [ ] `journalctl -u smainer-provider --since=5min` contains NO private key material.
- [ ] Resource limits active: `systemctl show smainer-provider | grep -E "(MemoryMax|CPUQuota)"`.
- [ ] Provider daemon authenticates to relayer within 30 seconds.
- [ ] Test task execution completes within sandbox without filesystem escapes.
- [ ] Emergency shutdown via `systemctl stop smainer-provider` completes within 10 seconds.

### Pre-execution Security Gate

```bash
./war-room-security-gates.sh && echo "SECURITY: GO" || echo "SECURITY: NO-GO"
```

### Deployment Evidence Artifacts Required

- systemd service definition file.
- Environment file permissions proof (`ls -la /var/lib/smainer-provider/.env`).
- Resource usage baseline from 5-minute test run.
- WebSocket authentication success logs (with credentials redacted).

### Concrete Next Action

Execute only the production-rehearsal gate path via [backend/provider/war-room-infra-startup.sh](backend/provider/war-room-infra-startup.sh) plus [war-room-security-gates.sh](war-room-security-gates.sh). Reject the run unless all go/no-go conditions above are green.

---

## Section 3 — Frontend Recovery Track

**Objective**: keep `main` as the stable baseline. Create one new implementation branch from `main`. Audit the unmerged `feat/website-overhaul-v2` for salvageable content. Rebuild pages and copy on the fresh branch with better design and stronger messaging.

### Ordered Steps

1. **Branch reset.** Owner: frontend-engineer. Action: create a fresh branch from `main` and treat `feat/website-overhaul-v2` as reference only. Acceptance: new branch builds cleanly from `main` with no inherited design debt.
2. **Branch diff audit.** Owner: frontend-engineer. Action: compare `main` vs `feat/website-overhaul-v2`; classify changes into page structure, components, styling, text. Acceptance: page-by-page audit with keep/revise/discard decisions.
3. **Content salvage review.** Owner: marketing-copywriter. Action: compare homepage and major page copy on both branches; keep only stronger text and stronger content intent. Acceptance: copy decision matrix for hero, value props, CTAs, feature sections, pricing text, supporting page messaging.
4. **Design triage.** Owner: frontend-engineer. Action: discard the weak design direction from the unmerged branch; keep only useful layout/component ideas that can be rebuilt cleanly. Acceptance: approved list of salvageable UI patterns and rejected patterns before implementation starts.
5. **Copy upgrade pass.** Owner: marketing-copywriter. Action: rewrite selected content into stronger, shorter, more professional Smainer copy. Acceptance: tight headlines, action-led CTAs, clearer than both current `main` and `feat/website-overhaul-v2`.
6. **Fresh-page rebuild.** Owner: frontend-engineer. Action: rebuild target pages on the new branch from `main` using approved copy and only salvageable structural ideas from the old branch. Acceptance: pages render cleanly, design is coherent, no weak visual patterns from the abandoned branch remain.
7. **Final validation.** Owner: frontend-engineer + marketing-copywriter. Action: review each page for visual quality, copy quality, alignment with intended site direction. Acceptance: each page is better than current `main` and better than the unmerged overhaul branch in both design and messaging.

### Branch Workflow

- Reference branch: `feat/website-overhaul-v2`.
- Implementation branch: new branch from `main`.
- Rule: do not merge or continue development directly on `feat/website-overhaul-v2`.

### Key Risks

- Strong copy may exist in the unmerged branch while design is weak — text and design must be evaluated separately.
- Reusing too much from `feat/website-overhaul-v2` will carry forward the same design problems.
- Copy and layout must be reviewed together so rewritten text still fits the rebuilt pages cleanly.

### Recommended First Action

Have frontend-engineer produce the `main` vs `feat/website-overhaul-v2` audit, then have marketing-copywriter mark exactly which text survives, which gets rewritten, which gets dropped.

---

## Section 4 — Node Types Catalog + GPU/CPU Clarity

**Objective**: launch a new catalog page listing available node types (cloud-style cards with specs and availability) while clearly explaining GPU vs CPU usage with minimal architecture change.

### Ordered Steps

1. **Owner: frontend-engineer.** Action: create a new Node Catalog page with two top-level tabs `GPU` and `CPU`, plus filters for tier and availability. Acceptance: page renders from existing node data source and supports responsive desktop/mobile layouts.
2. **Owner: frontend-engineer.** Action: implement "node type cards" that aggregate identical hardware profiles and show model/spec details. Acceptance: each card shows accelerator model, VRAM (or CPU-only label), CPU threads, RAM, tier, current availability count.
3. **Owner: frontend-engineer.** Action: keep architecture impact low by reusing the existing node listing pipeline and adding a UI aggregation layer only. Acceptance: no major backend redesign; only small API-shape extension if a field is missing.
4. **Owner: systems-engineer.** Action: provide technical truth block for the page — current support status and workload guidance for GPU vs CPU. Acceptance: wording is validated against runtime behavior before publish.
5. **Owner: marketing-copywriter.** Action: rewrite all user-facing text on this page into concise, clear product copy (headlines, labels, helper text, empty states). Acceptance: copy is short, specific, avoids vague marketing language.
6. **Owner: frontend-engineer + marketing-copywriter.** Action: add an inline "How to choose" section under the tabs. Acceptance: users can understand in under 10 seconds which node type they need.
7. **Owner: security-expert.** Action: review this page for claim safety (no over-promising CPU AI performance). Acceptance: approved wording for launch.

### GPU/CPU Explanation To Include On The Page

- Smainer is built for both GPU nodes and CPU nodes.
- GPU nodes are for interactive AI inference and heavy model workloads where latency matters.
- CPU nodes are for deterministic compute tasks like hashing, matrix/data processing, and script execution.
- CPU can run some AI paths technically, but response times are significantly slower than GPU; GPU is the recommended path for chat-like experiences.
- If a user needs fast AI responses, choose GPU. If they need lower-cost non-LLM compute, CPU is the better fit.

### UI Copy Draft — "How It Works"

- **GPU tab helper**: "Best for AI inference and model workloads that need fast response times."
- **CPU tab helper**: "Best for deterministic compute workloads such as hashing, matrix operations, and data processing."
- **CPU caveat line**: "AI on CPU is possible but much slower than GPU and not ideal for interactive chat."

### Go / No-Go For This Section

1. **Go**: GPU/CPU guidance is technically validated and the catalog is populated from real availability data.
2. **No-Go**: page implies CPU delivers GPU-like AI latency, OR availability is static/mock at launch.

---

## Cross-Section Execution Order (Recommended)

1. **Section 2 first** — production-parity rehearsal is the highest urgency gate before any launch.
2. **Section 1 in parallel** — local node bring-up unblocks individual contributors.
3. **Section 3 in parallel** — frontend recovery is independent of daemon work.
4. **Section 4 last** — node catalog page depends on stable node registration (Section 1+2 outcomes).


---

## Section 5 — One-Tap Approve→Execute Flow (Telegram + Braavos)

**Status**: Designed and verified through 3 review rounds (telegram-bot-developer + relayer-architect + starknet-engineer + security-expert). Security verdict: **GO-WITH-CONDITIONS**.

**Target user flow** (verbatim, no extra steps):

```
/start or prompt message in bot
    ↓
Bot: "Tap to approve in Braavos"  (single MiniApp button)
    ↓
User opens Braavos → ONE approve(spender, amount) → signs
    ↓ (no second popup, no confirm step, no second tx)
Bot: "Waiting for your approval on-chain…"  (spinner, event-driven)
    ↓
Relayer detects on-chain Approval → binds via dust-nonce → fires job
    ↓
Bot: "Running your prompt…"
    ↓
Bot: result
```

### 5.1 Locked Design Decisions

| Decision | Final Rule | Source |
|---|---|---|
| Entry mechanism | MiniApp WebApp button → `Telegram.WebApp.openLink(braavos_deeplink)` (controlled shim) | telegram-bot-developer |
| Spender address | `SMAINER_COMPUTE` contract (canonical, single value across protocol) | starknet-engineer |
| Dust derivation | `dust = keccak256(chat_id ‖ wallet_address) % 100_000` | security-expert (round 2) |
| Approve amount | `approve_amount = base_cost + dust` | aligned |
| Approval event source | Relayer polls `starknet_getEvents` every 3s, filtered to `(STRK_token, spender=SMAINER_COMPUTE)` | relayer-architect |
| Dedup primary | Redis `processed_approval:{tx_hash}:{log_index}` (TTL 24h) | security-expert (round 2) |
| Dedup defense-in-depth | On-chain map `approval_executions[(tx_hash, user)] = bool` | starknet-engineer |
| Allowance consumption | `decrease_allowance(0)` immediately after `transferFrom` pull | security-expert (round 2) |
| New Cairo function | `pull_and_execute(...)` REQUIRED — existing `create_task` pulls in same tx, `settle_task` uses pre-escrowed balance | starknet-engineer (round 2) |
| Bot ↔ Relayer transport | HMAC-signed HTTP callback (existing `deliver_result_callback` pattern) | relayer-architect |
| Session TTL | 300s (approval must land within 5 min, then session auto-expires) | relayer-architect |
| init_data verification | HMAC-SHA256 with bot token, 5-min auth_date window, MANDATORY on every MiniApp call | security-expert |

### 5.2 Two-Phase Session Registration (round 3 fix)

The bot cannot compute `keccak(chat_id ‖ wallet)` at prompt time because the wallet address isn't known yet. Resolution:

- **Phase 1 (bot)**: User sends prompt → bot stores `pending_prompt:{chat_id} → {prompt, model, base_cost}` in Redis (TTL 600s) → bot returns MiniApp button.
- **Phase 2 (MiniApp)**: MiniApp loads, calls `starknet.js` to get connected wallet account → computes `dust = keccak256(chat_id ‖ wallet) % 100_000` → POSTs `{chat_id, wallet, dust, init_data}` to relayer's `POST /api/v1/approval-session` (init_data verified) → relayer stores `approval_session:{wallet}:{dust} → {chat_id, prompt, deadline_block, base_cost}` (TTL 300s) → MiniApp triggers `strk.approve(SMAINER_COMPUTE, base_cost + dust)`.
- **Phase 3 (relayer watcher)**: Approval event observed → extract `(owner, value)` → compute `dust = value % 100_000` → `GETDEL approval_session:{owner}:{dust}` (atomic consume) → if hit, fire `pull_and_execute` call and notify bot via callback.
- **Phase 4 (bot)**: Receives `approval_detected` callback → edits "Waiting…" message to "Running…" → existing `/api/callback/complete` flow delivers result.

### 5.3 Files To Change (final list)

**Cairo contracts** (`contracts/src/`):
- `smainer.cairo` — add `pull_and_execute(owner, token, approved_amount, actual_cost, job_id, provider, result_hash, effort_score, sig_r, sig_s, tx_hash)`, add storage `approval_executions: Map<(felt252, ContractAddress), bool>`, add event `ApprovalExecuted`.
- `interfaces.cairo` — add the function signature.

**Relayer** (`backend/relayer/src/relayer/`):
- `chain/approval_watcher.py` *(new)* — polling loop, event decoder, dust matcher.
- `models/approval.py` *(new)* — `ApprovalSession`, `ApprovalEvent` Pydantic models.
- `api/routes.py` — add `POST /api/v1/approval-session` (with init_data HMAC verify), `GET /api/v1/approval-session/{chat_id}/status`.
- `main.py` — start `ApprovalWatcher` in lifespan.
- `config.py` — add `escrow_contract_address`, `token_contract_address`, `approval_poll_interval_seconds=3`, `approval_session_ttl_seconds=300`, `dust_modulus=100000`.
- `tests/test_approval_watcher.py` *(new)* — 8 acceptance tests (see 5.5).

**Telegram bot** (`telegram/smainer-bot/`):
- `src/handlers.py` — `handle_prompt()` stores `pending_prompt`, returns MiniApp button.
- `src/models.py` — `PendingPrompt`, `ApprovalCallback` schemas.
- `api/callback/approval.py` *(new)* — receives relayer callback, edits message, kicks off task.

**Telegram MiniApp** (`telegram/miniapp/src/`):
- `routes/approve.tsx` *(new)* — minimal page: read URL params, get wallet, compute dust, POST session, call approve, close.
- `lib/dust.ts` *(new)* — `computeDust(chatId, walletAddress): bigint` (keccak256 wrapper).
- `lib/approveTx.ts` *(new)* — single-tx approve helper.

### 5.4 Mandatory Security Controls (5/5 must be live before launch)

1. **Event dedup**: Redis `SETNX processed_approval:{tx_hash}:{log_index}` AND on-chain `approval_executions` write.
2. **init_data HMAC**: every MiniApp → relayer call MUST verify Telegram WebApp init_data signature with 5-min `auth_date` window.
3. **Escrow address pinning**: MiniApp imports `SMAINER_COMPUTE` from a build-time constant, NEVER from URL params or runtime config.
4. **Allowance wipe**: `pull_and_execute` MUST emit `decrease_allowance(0)` for the owner before returning success.
5. **Min-amount validation**: relayer rejects approval matches where `value < base_cost`. Below-threshold approvals are logged and ignored, never trigger jobs.

### 5.5 Acceptance Tests (must all pass)

| # | Test | Proves |
|---|---|---|
| 1 | Happy path: prompt → button → approve → result delivered, latency < 30s + inference time | E2E |
| 2 | Replay same Approval event twice → only 1 job fires | Dedup primary |
| 3 | Two concurrent users, same dust → second `SETNX` fails, MiniApp re-rolls (offset) | Collision guard |
| 4 | Stale approval (> 300s after session) → `GETDEL` returns nil → ignored | TTL cleanup |
| 5 | Approval with `value < base_cost` → relayer logs and drops | Min-amount control |
| 6 | Forged init_data → relayer rejects `POST /api/v1/approval-session` with 401 | init_data HMAC |
| 7 | Wallet A approves, attacker with wallet B sees event and tries to bind to chat_id → `keccak(chat_id ‖ B) ≠ A's dust` → no match | Wallet binding |
| 8 | After `pull_and_execute`, `allowance(owner, escrow) == 0` | Allowance wipe |
| 9 | Poller killed mid-batch, restarted → resumes from `continuation_token`, no duplicate jobs | Crash recovery |
| 10 | Bot callback signature invalid → bot rejects | HMAC integrity |

### 5.6 Hard No-Go Conditions

- ANY second wallet popup or confirm step in the user flow.
- ANY hardcoded dust formula that omits wallet address.
- ANY MiniApp endpoint accepting requests without init_data HMAC verification.
- ANY production `pull_and_execute` callable by an address other than the authorized relayer.
- ANY allowance left non-zero after a successful pull.
- Dust collision rate measured > 1 in 10^7 under simulated 100 concurrent sessions.

### 5.7 Implementation Order

1. **Contracts first** — add `pull_and_execute` + tests, deploy to testnet, record address.
2. **Relayer next** — `ApprovalWatcher` + `POST /api/v1/approval-session` + dedup + HMAC verify.
3. **MiniApp** — `/approve` route + `computeDust` + single-tap approve.
4. **Bot** — prompt handler + callback receiver.
5. **End-to-end testnet rehearsal** — run all 10 acceptance tests above.
6. **Security re-audit** — security-expert signs off all 5 mandatory controls live.
7. **Mainnet deploy** — only after rehearsal + audit pass.

---

## Section 6 — User-Facing Usage Steps (POST-implementation)

**Use this section ONLY after Section 5 is fully implemented, all 10 acceptance tests pass, and security has signed off all 5 mandatory controls.**

### For end users (you, testing the live flow)

1. **Open the Smainer Telegram bot** — `@SmainerBot` (or your dev bot handle).
2. **Send `/start`** — bot replies with welcome + "Send any prompt to begin."
3. **Send any prompt**, e.g. `Summarize this article: <text>`.
4. **Bot responds** with the cost line and a single button:
   >  0.12 STRK required
   > Tap below to approve in Braavos. No second confirmation needed.
   > **[ Approve in Wallet ]**
5. **Tap the button** — Telegram opens the Smainer MiniApp briefly. The MiniApp handshakes with your connected Braavos wallet, then deep-links you into the Braavos app.
6. **In Braavos** — you see ONE approve dialog showing:
   - Spender: `SMAINER_COMPUTE` (verify the address matches the published contract on the Smainer docs).
   - Amount: e.g. `0.120042 STRK` (the trailing dust is the chat-binding nonce — this is normal, do not modify).
7. **Tap "Confirm"** in Braavos. You return to Telegram automatically.
8. **Bot updates** to: `⏳ Waiting for your approval on-chain…` (spinner). You do nothing here.
9. **Within 6–15 seconds** (Starknet block time), bot updates to: ` Payment confirmed. Running your prompt…`.
10. **Result arrives** as a normal Telegram message, e.g.:
    > Here is the summary: …
    > _Computed in 2.3s · model: llama3 · 0.10 STRK billed_

**That's the entire flow.** One tap, one signature, no second confirm.

### Failure recovery (what to do if something goes wrong)

| What you see | What to do |
|---|---|
| Bot says `⏱ Approval not detected within 90 seconds` | Tap the **[Retry]** button. Your previous approval is still valid; the bot re-rolls a fresh dust-nonce for safety. |
| Braavos shows "Insufficient balance" | Top up STRK (the bot includes a deep-link to Ekubo if balance is too low). |
| Bot says ` Transaction cancelled in wallet` | Tap **[Approve in Wallet]** again — nothing was charged. |
| Bot stays silent after approval signed | Wait up to 30s for the next Starknet block. If still silent, send `/status` — bot will report whether the approval landed and whether the job is queued. |
| Bot says ` Network error` | Tap **[Retry]** — relayer recovery is automatic from the last `continuation_token`. |

### For operators (you, monitoring during live test)

1. **Tail the relayer ApprovalWatcher logs**:
   ```bash
   journalctl -u smainer-relayer -f | grep -E "approval_watcher|ApprovalDetected|pull_and_execute"
   ```
2. **Verify dedup is healthy** — Redis key count for `processed_approval:*` should grow monotonically with each approval. No duplicate `task_id` should appear in the relayer's task queue.
3. **Verify allowance wipe** — after each successful job, query the STRK contract:
   ```
   STRK.allowance(user_wallet, SMAINER_COMPUTE) == 0
   ```
4. **Monitor for collision retries** — Redis counter `approval_session_collision_retries` should stay near zero. A spike indicates either an attack or that `dust_modulus` needs tuning.
5. **Monitor min-amount drops** — `approval_below_threshold_dropped` counter; non-zero means someone is probing.
6. **Emergency stop** — `systemctl stop smainer-relayer` halts the watcher; pending sessions auto-expire after 300s without firing.

