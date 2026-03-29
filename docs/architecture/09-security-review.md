# Security Review — Smainer Effort-Based Pricing System (Phase 10)

> Review Date: 2026-03-28
> Validation ID: VR-20260328-001
> Verdict: CONDITIONAL_PASS — P0 issues resolved inline, P1 items tracked
> Overall Severity: HIGH

## 1. Threat Model

### 1.1 Malicious Provider — Inflated Metrics

V1 effort metrics are self-reported. A provider can inflate `input_tokens`, `output_tokens`, and `gpu_seconds` to claim the maximum 7.5x multiplier. The `MAX_EFFORT_MULTIPLIER` cap limits per-task damage but does not detect persistent max-claiming.

**Mitigations applied:**
- SEC-001: Per-field bounds validation in `aggregator.py` rejects out-of-range metrics
- Signature replay defended by on-chain `used_signatures` map

### 1.2 Malicious User — Underpayment

Contract enforces `actual_cost <= task.amount`. Relayer clamps actual cost in `RefundCalculator`. Double-covered.

### 1.3 Relayer Compromise

`RELAYER_PRIVATE_KEY` authorizes all settlements. A compromise allows draining all ACTIVE escrows.

**Recommendation (P4):** Time-locked relayer rotation (24h).

### 1.4 Front-Running — MEV

Starknet sequencer model has no public mempool. Accepted risk for V1.

### 1.5 DoS — RPC Exhaustion

`PaymentVerifier` doesn't cache NOT_FOUND results. Rate limiting at API layer is the defense.

## 2. Code Review Findings

### SEC-001 — CRITICAL (RESOLVED): Self-Reported Metrics Accepted Without Bounds

**File:** `aggregator.py:388–394`
**Fix:** Added per-field validation (input_tokens <= 128K, output_tokens <= 16K, gpu_seconds <= 3600, model_id truncated to 128 chars). Invalid metrics cause fallback to legacy path.

### SEC-007 — HIGH (RESOLVED): Unclamped effort_score Used for effort_bps

**File:** `settler.py:143`
**Fix:** `clamped_effort = min(cost.effort_score, MAX_EFFORT_MULTIPLIER)` before BPS conversion. Prevents contract revert on high-effort tasks.

### SEC-004 — HIGH (RESOLVED): Redis Key Injection via Unsanitized node_id

**File:** `main.py:224`
**Fix:** Regex validation `^[a-zA-Z0-9_\-]{1,64}$` at WebSocket connection time.

### SEC-010 — MEDIUM (RESOLVED): PaymentVerifier Silently Disabled

**Files:** `config.py`, `main.py`, `routes.py`
**Fix:** `REQUIRE_PAYMENT_VERIFICATION` env flag. When set, startup fails if verifier can't init; route returns 503 if verifier is unavailable.

### SEC-013 — LOW (RESOLVED): assert() Guards Financial Invariants

**Files:** `constants.py`, `refund.py`
**Fix:** Replaced `assert` with explicit `raise ValueError` that survives Python `-O`.

### SEC-002 — HIGH (P1): Float Arithmetic in MiniApp Wei Calculations

**File:** `useCostEstimate.ts:42–46`, `starknet.ts:223`
**Issue:** `Number(BASE_PROMPT_COST)` loses precision for values near 10^18.
**Recommendation:** Use BigInt BPS arithmetic throughout.

### SEC-003 — MEDIUM (P1): get_task Response Field Mapping

**File:** `verifier.py:363–389`
**Issue:** `_parse_get_task_response` may parse wrong fields from 9-field ABI response.
**Recommendation:** Verify against deployed contract ABI on devnet.

### SEC-005 — MEDIUM (P2): Escrowed Amount from Redis, Not On-Chain

**File:** `settler.py:114`
**Recommendation:** Re-verify on-chain before settlement call.

### SEC-006 — HIGH (P1): Stale Verification Cache Enables Double Settlement

**File:** `verifier.py:139–146`
**Recommendation:** Invalidate cache before settlement. Add Redis NX idempotency key.

## 3. Smart Contract Security

### CEI Pattern — COMPLIANT
`settle_with_effort` follows Checks-Effects-Interactions correctly. Task lock released only after all transfers.

### Reentrancy — LOW RISK
STRK token is standard ERC-20 with no callbacks. However, contract accepts any `token_address` in `create_task`.
**Recommendation (P4):** Add token allowlist restricting to STRK.

### Access Control — CORRECT
Relayer-only access enforced via `assert(caller == authorized_relayer)`.

### Signature Verification — CORRECT
Message hash includes `(task_id, provider, result_hash, actual_cost)` — provider commits to exact cost.

### Integer Arithmetic — SAFE
Cairo u256 with overflow-panicking semantics. `calculate_fee_split` uses subtraction-as-residual.

## 4. ZK Roadmap Security (V2)

- Minimum 7-day challenge period for optimistic verification
- Provider stake >= `MAX_EFFORT × BASE_COST × max_concurrent_tasks`
- ZK verification key stored on-chain (not relayer-supplied)
- Proof staleness protection via block hash binding
- Downgrade prevention: `proof_requirement` field per task

## 5. Recommendations Summary

| Priority | ID | Action |
|----------|----|--------|
| P0 (Done) | SEC-001 | Effort metrics bounds validation |
| P0 (Done) | SEC-007 | Clamp effort_bps before on-chain call |
| P0 (Done) | SEC-004 | Validate node_id regex |
| P0 (Done) | SEC-010 | Require payment verification flag |
| P0 (Done) | SEC-013 | Replace assert with raise |
| P1 | SEC-002 | BigInt arithmetic in MiniApp |
| P1 | SEC-003 | Verify get_task ABI field mapping |
| P1 | SEC-006 | Cache invalidation + idempotency |
| P2 | SEC-005 | Re-verify escrow on-chain before settlement |
| P4 | — | Token allowlist in contract |
| P4 | — | Time-locked relayer rotation |
| P4 | — | Fee constant consolidation across Cairo/Python |
