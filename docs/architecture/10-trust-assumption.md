# V2.0 Trust Assumption — Optimistic Verification with Staking & Slashing

> Module: `contracts/src/smainer_staking.cairo` + `backend/relayer/src/relayer/verifier/`
> Owner Agents: `starknet-engineer` + `relayer-architect` + `security-expert`
> Status: In Development
> Predecessor: [08-zk-effort-verification.md](08-zk-effort-verification.md)

---

## 1. Problem Statement

In V1, effort metrics (input token count, output token count, GPU time, model ID) are self-reported by the compute node and signed with its Starknet private key. The public security posture for this model centers on three active attack surfaces:

**Metric Inflation** — Provider inflates `input_tokens`, `output_tokens`, or `gpu_seconds` to drive up the effort multiplier toward the 7.5x cap. The `MAX_EFFORT_MULTIPLIER` bounds check limits per-task exposure but does not detect systematic max-claiming. A provider consistently reporting 7.5x on tasks that genuinely cost 1.2x extracts STRK from the treasury and user escrow at scale.

**Metric Deflation (Collusion)** — A provider and user operating as the same entity deflate metrics to minimize actual cost. The provider receives less STRK from the provider payout, but the user recovers the escrowed surplus via refund. Net effect: the 12% treasury fee is calculated on an artificially low `actual_cost`, starving the protocol treasury.

**Replay Attacks** — A provider caches the result of a prior inference and submits it for a new task, fabricating GPU time of zero (or a plausible low value) while reporting token counts from the original job. The current signature scheme binds `(task_id, provider, result_hash, actual_cost)`, which prevents cross-task signature reuse, but a provider can still produce a new valid signature over fabricated metrics for any task they are assigned.

V2.0 eliminates these vectors through optimistic verification with economic deterrence: providers stake STRK as collateral, a subset of tasks are re-executed by an independent verifier node, and confirmed discrepancies trigger graduated on-chain slashing.

---

## 2. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│  COMPUTE PROVIDER                                                      │
│                                                                        │
│  Run inference → EffortMetrics + result_hash + provider_signature      │
└────────────────────────────────┬───────────────────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────────────────┐
│  RELAYER                                                               │
│                                                                        │
│  ┌──────────────────────┐      ┌─────────────────────────────────────┐ │
│  │  Settlement Path     │      │  Spot-Check Selector                │ │
│  │  (every task)        │      │                                     │ │
│  │                      │      │  keccak256(block_hash ∥ task_id)    │ │
│  │  settler.py          │      │  mod 100 < rate_pct ?               │ │
│  │  → settle_with_effort│      │                                     │ │
│  │    () on-chain       │      │  rate_pct = reputation-adjusted     │ │
│  └──────────────────────┘      └──────────────────┬──────────────────┘ │
│                                                   │ selected           │
└───────────────────────────────────────────────────┼────────────────────┘
                                                    │
                                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│  VERIFIER NODE  (separate Starknet key, separate process)             │
│                                                                       │
│  Re-run same inference (same model, same prompt, temp=0)              │
│  Compare: input_tokens, output_tokens, result_hash                    │
│                                                                       │
│  Verdict: PASS | VIOLATION | INCONCLUSIVE                             │
└───────────────────────┬───────────────────────────────────────────────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
          ▼             ▼             ▼
       PASS          INCONCLUSIVE  VIOLATION
          │             │             │
      +rep score    -5 rep score      │
      no action     (3 consecutive    ▼
                     → manual flag) ┌──────────────────────┐
                                    │  Evidence Store       │
                                    │  (IPFS / S3)          │
                                    │                       │
                                    │  evidence_CID stored  │
                                    │  on-chain as          │
                                    │  reason_hash          │
                                    └──────────┬────────────┘
                                               │
                                               ▼
                                    ┌──────────────────────┐
                                    │  Slash Orchestrator   │
                                    │                       │
                                    │  initiate_slash()     │
                                    │  → 7-day appeal window│
                                    │                       │
                                    │  execute_slash()      │
                                    │  (callable by anyone  │
                                    │   after window)       │
                                    └──────────┬────────────┘
                                               │
                                               ▼
                                    ┌──────────────────────┐
                                    │  SmainerStaking       │
                                    │  Contract             │
                                    │                       │
                                    │  80% → treasury       │
                                    │  20% → verifier node  │
                                    └──────────────────────┘
```

---

## 3. Staking Model

Providers must stake STRK before receiving task assignments. The staking contract is `contracts/src/smainer_staking.cairo`. The relayer reads staking status via `is_eligible(provider)` before routing tasks.

### Minimum Stake Formula

```
MIN_STAKE = MAX_EFFORT_BPS × BASE_PROMPT_COST_WEI × MAX_CONCURRENT_TASKS
```

Where `MAX_EFFORT_BPS` is the effort multiplier ceiling expressed in basis points (75000 = 7.5x), `BASE_PROMPT_COST_WEI` is `0.1 STRK` in wei, and `MAX_CONCURRENT_TASKS` is the provider's declared concurrency tier. This ensures the stake covers full-effort payout on every simultaneous task the provider is authorized to hold — a provider cannot profit from slashing by accepting more tasks than their stake covers.

Hard floor: **5 STRK**, regardless of formula output. This prevents stake-minimization through a low `MAX_CONCURRENT_TASKS` declaration while still accepting tasks at the default concurrency level.

### Lockup and Withdrawal

| Action | Condition | Delay |
|---|---|---|
| `stake()` | Any time | Immediate (active at next block) |
| `request_unstake()` | `active_task_count == 0` | 7-day lockup |
| `withdraw()` | After lockup expires, no active slash | Immediate |

`request_unstake()` reverts if `active_task_count > 0`. There is no partial unstake while tasks are in flight.

**Task abandonment timeout**: 48 hours. If a provider holds a task without submitting results for 48 hours, the task is marked abandoned, `active_task_count` is decremented, and the escrowed amount is refunded to the user in full. A repeated abandonment pattern contributes to reputation degradation (see Section 7).

---

## 4. Spot-Check Selection

### Selection Formula

```
keccak256(block_hash || task_id) mod 100 < rate_pct
```

`block_hash` is the hash of the settlement block at the time the relayer processes the result. Both values are available on-chain and in relayer logs. Any external auditor can reproduce the selection set from the settlement transaction history alone — no relayer-internal state is required.

The verifier node runs this same formula independently and will only accept `initiate_slash()` calls for tasks that were deterministically selected. Any slash attempt against a non-selected task is rejected at the contract level.

### Reputation-Adjusted Rates

| Reputation Score | Spot-Check Rate |
|---|---|
| 90–100 | 2% |
| 70–89 | 5% |
| 50–69 | 15% |
| 0–49 | 30% |
| Active violation flag | 100% |

Base rate (new providers start at score 50, therefore base rate): **5%**.

The active violation flag (set at `initiate_slash()`, cleared at `execute_slash()` or `resolve_appeal()` in provider's favor) forces 100% spot-check on all subsequent tasks during the appeal window. This prevents a provider from avoiding additional detections by going idle after a first violation is detected.

---

## 5. Violation Taxonomy

The verifier re-runs inference using the original prompt, the claimed model, and `temperature=0`. Results are compared field by field.

| Metric | Condition | Verdict |
|---|---|---|
| Input token count | Mismatch (any delta) | VIOLATION |
| Output token count | Mismatch, `temperature=0` only | VIOLATION |
| Output token count | Mismatch, `temperature>0` | INCONCLUSIVE |
| Result content | Any diff, `temperature=0` | VIOLATION |
| Result content | Any diff, `temperature>0` | INCONCLUSIVE |
| GPU time | Any diff | Never a trigger |
| Re-run failed (timeout, model unavailable) | — | INCONCLUSIVE |
| Context mismatch (conversation history changed) | — | INCONCLUSIVE |

**GPU time is explicitly excluded as a violation trigger.** Hardware variance, VRAM scheduling, and background load make GPU duration non-deterministic across machines. Token counts and result content at `temperature=0` are fully deterministic and constitute the evidential standard.

**Consecutive INCONCLUSIVE handling**: Three consecutive INCONCLUSIVE verdicts for the same provider within the rolling 90-day window raise a manual review flag. This covers the scenario where a provider goes offline or returns errors specifically during spot-check re-runs without producing a clearcut VIOLATION.

---

## 6. Slash Mechanics

### Graduated Slashing — 90-Day Rolling Window

Offense count resets to zero after 90 days with no new violations.

| Offense (90-day window) | Slash Percentage | Provider Status After |
|---|---|---|
| First | 20% of staked STRK | Active |
| Second | 50% of staked STRK | Active |
| Third | 100% of staked STRK | `NODE_SUSPENDED` |

`NODE_SUSPENDED` providers are ineligible for task routing. Re-activation requires a new `stake()` call meeting the minimum stake formula, plus a manual review clearance from the contract owner.

### Two-Phase Slash Process

**Phase 1 — `initiate_slash(provider, task_id, reason_hash)`**

Callable by the authorized verifier node only. Commits the evidence CID hash on-chain, records the offense count, sets `active_violation_flag = true`, and starts the 7-day appeal window. No STRK is transferred at this stage.

**Phase 2 — `execute_slash(provider, slash_id)`**

Callable by anyone after the 7-day appeal window expires without a successful appeal. Transfers slashed STRK: 80% to the treasury, 20% to the verifier node address. Clears `active_violation_flag`.

### Slash Distribution

```
slashed_amount = stake × slash_percentage
treasury_share  = slashed_amount × 80%
verifier_share  = slashed_amount × 20%
```

The 20% verifier incentive creates an economic alignment: the verifier node earns only when it detects genuine violations backed by on-chain-auditable evidence. A verifier that initiates meritless slashes will lose appeals and accrue no reward.

### Cooldown and Concurrency Limits

- **24-hour cooldown** between slash initiations on the same provider address.
- **Maximum 1 active slash per provider** at any time. A second violation detected while an appeal is pending is queued and processed after the current slash resolves.

### Appeal Process

1. Provider calls `appeal_slash(slash_id)` — pauses the 7-day countdown, sets status to `APPEALING`.
2. Owner reviews evidence CID off-chain, inspects re-run logs.
3. Owner calls `resolve_appeal(slash_id, upheld: bool)`:
   - `upheld = true` → appeal denied, countdown resumes from where it paused.
   - `upheld = false` → slash cancelled, `active_violation_flag` cleared, offense count decremented.

---

## 7. Reputation System

Reputation is off-chain state stored in Redis. It is not a financial primitive — it gates spot-check frequency only. Scores are in the range `[0, 100]`.

**New provider starting score: 50** (base rate spot-check tier).

### Score Delta Table

| Event | Score Delta |
|---|---|
| Spot-check PASS | +2 |
| Honest pricing (actual cost ≤ 110% of estimate) | +1 |
| INCONCLUSIVE verdict | −5 |
| Confirmed VIOLATION | −15 |
| Full slash (3rd offense, `NODE_SUSPENDED`) | −50 |

### Design Constraints

**No passive decay.** Scores do not decrease over time without a cause. A provider that completes 500 tasks and stops operating retains their score; re-activation does not penalize them for inactivity.

**Recovery cap.** Score gain is capped at +2 per PASS regardless of task complexity. This prevents score recovery via a flood of trivially small tasks after a violation.

**Minimum task value for credit.** Tasks with an actual cost below **0.1 STRK** do not generate a score event (neither positive nor negative) for spot-check passes or honest pricing credits. This closes the reputation-farming vector via micro-tasks. Violations from micro-tasks still apply full penalties — there is no low-cost way to probe detection thresholds.

**Redis TTL.** `REPUTATION_SCORE_TTL_SECONDS = 0` by default (no expiry). Operators may set an explicit TTL to force re-evaluation of long-dormant providers, but this is not recommended in production.

---

## 8. Off-Chain Evidence

On-chain storage costs make storing raw inference results impractical. The evidence architecture uses content-addressed off-chain storage with an on-chain commitment.

### Evidence Blob Structure

```
EvidenceBlob {
    task_id:            str      // Task identifier
    provider:           str      // Provider Starknet address
    original_result:    bytes    // Provider's submitted result
    original_metrics:   dict     // Provider's submitted EffortMetrics
    rerun_result:       bytes    // Verifier's re-run result
    rerun_metrics:      dict     // Verifier's measured EffortMetrics
    verdict:            str      // "VIOLATION" | "INCONCLUSIVE"
    verifier_address:   str      // Verifier Starknet address
    block_hash:         str      // Settlement block hash (selection proof)
    timestamp_utc:      str      // ISO 8601
}
```

### Storage and On-Chain Commitment

```
evidence_CID   = IPFS CID or S3 object key of EvidenceBlob
reason_hash    = keccak256(evidence_CID)
```

Only `reason_hash` is stored on-chain in the slash record. The evidence blob itself is stored in IPFS (preferred, content-addressed and permanent) or S3 (operator-controlled, requires retention policy enforcement).

**Minimum retention period: 90 days**, matching the rolling violation window. An evidence blob that falls out of retention before a dispute is resolved invalidates the slash. Operators must ensure storage is reliable and accessible before `initiate_slash()` is called.

---

## 9. Security Properties

### What This Architecture Prevents

**Metric inflation** — Any spot-checked task where the provider reported inflated token counts will fail the deterministic `temperature=0` re-run comparison. Detection probability per task scales with spot-check rate; a provider at score 0–49 faces 30% re-verification, making sustained inflation statistically expensive.

**Metric deflation** — Extreme deflation (claiming near-zero tokens on a substantive response) produces an output token count mismatch at `temperature=0`. Minor deflation may fall under the detection threshold, but the treasury fee is calculated on `actual_cost`, not `escrowed_amount`, so deflation provides less advantage than inflation.

**Replay attacks** — The signature scheme binds `(task_id, provider, result_hash, actual_cost)`. A cached result from a prior task has a different `task_id`, producing a signature that the contract rejects. A provider cannot re-sign an old result for a new task without producing a new signature over fresh fields, which binds them to the current task's metrics.

**Selective avoidance during spot-checks** — Going offline or returning errors during a re-run attempt produces an INCONCLUSIVE verdict, not a PASS. Three consecutive INCONCLUSIVEs trigger a manual review flag. A provider who systematically drops connections during the 24-hour re-run window accrues reputation damage without ever producing a clean VIOLATION evidence blob.

### Residual Risks

**Small-delta token inflation (1–2 tokens)** — Token count arithmetic at tokenizer boundaries can produce ±1 token variance from model version differences. The verifier currently applies no tolerance window. A future `V2.1` iteration will introduce a statistical anomaly detector to distinguish single-task boundary variance from systematic small-delta inflation patterns.

**Verifier node compromise** — A compromised verifier key can initiate spurious slashes. Mitigations: verifier uses a separate Starknet key isolated from the relayer key; evidence blobs are publicly readable (anyone can audit the CID); appeal process provides a recovery path. `V2.1` target: verifier runs inside a TEE (Intel TDX) to produce hardware attestation alongside the evidence blob.

**Relayer captures slash queue** — A compromised relayer could suppress `execute_slash()` calls, preventing finalization. Mitigation: `execute_slash()` is callable by anyone after the appeal window expires. No relayer-exclusive authority is required to finalize a slash; any network participant can observe pending slashes on-chain and finalize them.

---

## 10. Configuration Reference

| Environment Variable | Default | Required (Production) | Description |
|---|---|---|---|
| `STAKING_CONTRACT_ADDRESS` | `""` | Yes | SmainerStaking contract address |
| `VERIFIER_PRIVATE_KEY` | `""` | Yes | Verifier Starknet private key (separate from relayer) |
| `VERIFIER_ACCOUNT_ADDRESS` | `""` | Yes | Verifier Starknet account address |
| `SPOT_CHECK_BASE_RATE_PCT` | `5` | No | Base spot-check rate (2–30%) |
| `VERIFIER_RERUN_TIMEOUT_HOURS` | `24` | No | Max hours for verifier re-run |
| `EVIDENCE_STORAGE_URL` | `""` | Yes | IPFS gateway or S3 URL for evidence |
| `REPUTATION_SCORE_TTL_SECONDS` | `0` | No | Redis TTL for reputation (0 = no expiry) |
| `TASK_ABANDONMENT_TIMEOUT_HOURS` | `48` | No | Hours before task marked abandoned |

All private key variables must be injected at runtime via environment. They must never appear in source control, container image layers, or log output. The verifier key (`VERIFIER_PRIVATE_KEY` / `VERIFIER_ACCOUNT_ADDRESS`) must be provisioned independently of the relayer key — shared key material eliminates the security separation between settlement and verification authority.

---

## Related Documents

| Document | Relevance |
|---|---|
| [08-zk-effort-verification.md](08-zk-effort-verification.md) | Predecessor: ZK roadmap; defines V2.0 as Option D (optimistic + slashing) |
| Public security posture | Bounds validation and ZK roadmap security constraints |
| [05-settlement-system.md](05-settlement-system.md) | Settlement pipeline that verifier integrates into |
| [00-overview.md](00-overview.md) | System constants: `BASE_PROMPT_COST`, `MAX_EFFORT_MULT`, fee splits |
