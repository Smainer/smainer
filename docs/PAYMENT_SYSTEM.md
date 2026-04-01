# Smainer Payment System

Smainer uses an effort-based pricing model where users pay for actual compute consumed, not flat rates. Users escrow STRK tokens on-chain before inference. After task completion, the system calculates the actual cost from measured effort metrics, pays the compute provider, takes a protocol fee, and refunds the excess escrow to the user -- all atomically in a single on-chain transaction.

This document covers the full payment lifecycle: pricing formulas, fee structure, token counting, escrow verification, on-chain settlement, and the V2 trust model with staking and slashing.

---

## How Pricing Works

### Effort-Based Formula

Every task has two cost calculations: a **pre-inference estimate** (determines escrow amount) and a **post-inference actual cost** (determines settlement).

**Pre-inference estimate** (what the user escrows):

```
estimated_cost = base_rate * tier_multiplier * estimated_effort * SAFETY_MARGIN

estimated_effort = max(1.0,
    (input_tokens / BASE_INPUT) * INPUT_WEIGHT
  + (est_output_tokens / BASE_OUTPUT) * OUTPUT_WEIGHT
  + model_complexity_factor
)

SAFETY_MARGIN = 1.3    # 30% buffer for estimation variance
```

**Post-inference actual cost** (what is settled on-chain):

```
actual_cost = max(
    BASE_FLOOR,
    base_rate * tier_multiplier * min(actual_effort, MAX_EFFORT_MULTIPLIER)
)

actual_effort =
    (input_tokens / BASE_INPUT) * INPUT_WEIGHT
  + (output_tokens / BASE_OUTPUT) * OUTPUT_WEIGHT
  + model_complexity_factor
  + (gpu_seconds / BASE_GPU_SECONDS) * GPU_TIME_WEIGHT

MAX_EFFORT_MULTIPLIER = 7.5
BASE_FLOOR = base_rate * tier_multiplier    # minimum = flat tier price
```

The effort score is a weighted sum of four components: input token volume, output token volume, GPU compute time, and model complexity. Each component is normalized against a baseline value, then weighted according to its relative cost.

| Component | Baseline | Weight | Rationale |
|---|---|---|---|
| Input tokens | 100 tokens | 0.3 | Prompt processing is cheaper than generation |
| Output tokens | 256 tokens | 0.5 | Token generation is the primary compute cost |
| GPU time | 10.0 seconds | 0.2 | Hardware-dependent; accounts for variance |
| Model complexity | N/A | Added directly | Reflects model parameter count |

### Model Complexity Bars

Model complexity is determined by parameter count, not by model name. This makes the system generic: any model -- including custom fine-tunes and future architectures -- receives a complexity score purely from its size.

| Parameter Count | Complexity Score | Category |
|---|---|---|
| 0 -- 10B | 0.2 | Small |
| 10 -- 20B | 0.4 | Medium |
| 20 -- 50B | 0.6 | Large |
| 50 -- 200B | 0.8 | XL |
| 200B+ | 1.0 | Frontier |

**Resolution order** for determining a model's parameter count:

1. Explicit `param_count_billions` provided by the compute node.
2. Regex extraction from model identifier (e.g., `llama3.1:70b` extracts 70B; `mixtral:8x7b` extracts 56B via multiplication).
3. Fallback to default complexity score of 0.2 if neither method succeeds.

### Tier Multipliers

Tiers scale the base cost to reflect different service levels. These multipliers are encoded in the smart contract as basis points (BPS).

| Tier | Multiplier | BPS Value |
|---|---|---|
| BASIC | 1.0x | 10000 |
| PRO | 2.2x | 22000 |
| PREMIUM | 3.5x | 35000 |

### Worked Examples

**Example 1: Short prompt on BASIC tier**

```
Input tokens:  2
Output tokens: 15
GPU seconds:   0.5
Model:         llama3.1:8b (7B params -> complexity 0.2)

actual_effort = (2/100)*0.3 + (15/256)*0.5 + 0.2 + (0.5/10)*0.2
              = 0.006 + 0.029 + 0.2 + 0.01
              = 0.245

actual_cost = max(0.1, 0.1 * 1.0 * 0.245) = max(0.1, 0.0245) = 0.1 STRK

Floor applies. User pays base rate.
```

**Example 2: Long document analysis on PRO tier**

```
Input tokens:  3000
Output tokens: 1500
GPU seconds:   45
Model:         llama3.1:70b (70B params -> complexity 0.8)

actual_effort = (3000/100)*0.3 + (1500/256)*0.5 + 0.8 + (45/10)*0.2
              = 9.0 + 2.93 + 0.8 + 0.9
              = 13.63
              -> capped at 7.5

actual_cost = max(0.22, 0.1 * 2.2 * 7.5) = max(0.22, 1.65) = 1.65 STRK

Provider payout:  1.452 STRK (88%)
Treasury fee:     0.198 STRK (12%)

Pre-inference estimate would have been: 0.1 * 2.2 * 7.5 * 1.3 = 2.145 STRK (escrowed)
Refund to user: 2.145 - 1.65 = 0.495 STRK
```

**Example 3: Medium prompt on PREMIUM tier**

```
Input tokens:  500
Output tokens: 400
GPU seconds:   8
Model:         llama3.1:70b (70B params -> complexity 0.8)

actual_effort = (500/100)*0.3 + (400/256)*0.5 + 0.8 + (8/10)*0.2
              = 1.5 + 0.78 + 0.8 + 0.16
              = 3.24

actual_cost = max(0.35, 0.1 * 3.5 * 3.24) = max(0.35, 1.134) = 1.134 STRK

Provider payout:  0.998 STRK (88%)
Treasury fee:     0.136 STRK (12%)
```

---

## Fee Structure

### Fee Split

Fees are calculated on the **actual cost**, not the escrowed amount. The protocol never profits from overestimates.

| Recipient | Share | BPS | Description |
|---|---|---|---|
| Provider (base) | 85% | 8500 | Compensation for compute work |
| Provider (gas subsidy) | 3% | 300 | Covers provider's on-chain gas costs |
| **Provider total** | **88%** | **8800** | Base + gas subsidy |
| Treasury | 12% | 1200 | Protocol fee |

```
provider_payout = actual_cost - treasury_fee
treasury_fee    = actual_cost * 12%
refund          = escrowed_amount - actual_cost
```

### Per-Task Economics (v3 transactions — gas paid in STRK)

```
User pays:          0.10 STRK per task (BASIC tier)
├── Provider:       0.088 STRK (88%)
├── Treasury:       0.012 STRK (12%)
└── Gas subsidy:    included in the 3% rebate to provider

Relayer gas cost:   ~0.002 STRK per settlement (v3 tx)
Treasury net:       0.012 - 0.002 = ~0.01 STRK per task
```

All on-chain transactions use Starknet v3 (`execute_v3`), which pays gas in STRK — no ETH required for normal operations. The relayer's STRK balance funds settlement gas. Admin-only calls (upgrade, pause) from the Owner wallet also support v3 STRK gas.

### Minimum Reward Floor

Every settled task pays at least **0.01 STRK** (`10_000_000_000_000_000` wei). This ensures that providers always earn a viable minimum, even for trivially small tasks. The floor is enforced both off-chain (in the cost calculator) and on-chain (in the smart contract).

Additionally, the cost formula applies a **base floor** equal to `base_rate * tier_multiplier`. A BASIC tier task cannot settle below 0.1 STRK; a PRO tier task cannot settle below 0.22 STRK.

### Refund Mechanism

Excess escrow is returned to the user on-chain as part of the atomic settlement transaction. There is no credit system, no off-chain balance, and no manual withdrawal required. The refund transfer is part of the same transaction as the provider payout and treasury fee -- all three succeed or all three revert.

---

## Payment Flow

### End-to-End Sequence

```
 USER                    MINIAPP              RELAYER              PROVIDER            CONTRACT
  |                        |                    |                    |                    |
  |  1. Submit prompt      |                    |                    |                    |
  |----------------------->|                    |                    |                    |
  |                        |                    |                    |                    |
  |  2. Estimate cost      |                    |                    |                    |
  |  (effort + margin)     |                    |                    |                    |
  |  Show: ~0.42 STRK      |                    |                    |                    |
  |<-----------------------|                    |                    |                    |
  |                        |                    |                    |                    |
  |  3. Approve & escrow   |                    |                    |                    |
  |  0.55 STRK on-chain    |                    |                    |                    |
  |----------------------->|------------------create_task()--------->|                    |
  |                        |                    |                    |                    |
  |                        |  4. Submit task    |                    |                    |
  |                        |  with task_id      |                    |                    |
  |                        |------------------->|                    |                    |
  |                        |                    |                    |                    |
  |                        |                    |  5. Verify escrow  |                    |
  |                        |                    |  (fail-closed)     |                    |
  |                        |                    |--------get_task()--+------------------>|
  |                        |                    |<-------------------+----escrow data----|
  |                        |                    |                    |                    |
  |                        |                    |  6. Route task     |                    |
  |                        |                    |------------------->|                    |
  |                        |                    |                    |                    |
  |                        |                    |                    |  7. Run inference  |
  |                        |                    |                    |  Collect metrics:  |
  |                        |                    |                    |  - token counts    |
  |                        |                    |                    |  - GPU time        |
  |                        |                    |                    |  - model ID        |
  |                        |                    |                    |                    |
  |                        |                    |  8. Return result  |                    |
  |                        |                    |  + EffortMetrics   |                    |
  |                        |                    |  + signature       |                    |
  |                        |                    |<-------------------|                    |
  |                        |                    |                    |                    |
  |                        |                    |  9. Calculate      |                    |
  |                        |                    |  actual cost from  |                    |
  |                        |                    |  effort metrics    |                    |
  |                        |                    |                    |                    |
  |                        |                    |  10. Settle on-chain (atomic)           |
  |                        |                    |---------settle_with_effort()----------->|
  |                        |                    |                    |                    |
  |                        |                    |                    |  Provider: 88%  -->|
  |                        |                    |                    |  Treasury: 12%  -->|
  |  <---------- Refund: escrowed - actual ------------------------------------- user --|
  |                        |                    |                    |                    |
  |                        |                    |  11. (V2) Spot-check selection          |
  |                        |                    |  keccak256(block_hash || task_id)       |
  |                        |                    |  If selected: fire-and-forget re-run    |
  |                        |                    |                    |                    |
```

### Step-by-Step Summary

1. **User submits prompt** via the Telegram MiniApp.
2. **Cost estimation** runs client-side using the effort formula with a 1.3x safety margin.
3. **User escrows** the estimated amount on-chain by calling `create_task()` on the Smainer contract.
4. **Task submission** to the relayer includes the on-chain `task_id`.
5. **Escrow verification** -- the relayer calls `get_task()` on-chain to confirm: task exists, status is CREATED, amount is sufficient, creator address matches. If any check fails, the task is rejected. No exceptions.
6. **Task routing** to an eligible compute provider.
7. **Inference execution** -- the provider runs the model and collects effort metrics (token counts from the inference engine, GPU utilization via `nvidia-smi` polling).
8. **Result submission** -- the provider returns the inference result, signed effort metrics, and a cryptographic signature binding `(task_id, provider, result_hash, actual_cost)`.
9. **Actual cost calculation** -- the relayer applies the effort formula to the reported metrics.
10. **Atomic settlement** -- the relayer calls `settle_with_effort()`. The contract executes three transfers in a single transaction: provider payout (88%), treasury fee (12%), and user refund (escrowed - actual). All succeed or all revert.
11. **(V2) Spot-check** -- a deterministic selection function decides whether to re-verify this task via an independent verifier node.

---

## Token Counting

### Interface Design

Token counting is abstracted behind the `ITokenCounter` interface, allowing different inference engines to provide token counts through their native APIs.

```python
class ITokenCounter(ABC):
    @abstractmethod
    def extract_token_counts(self, engine_response: dict) -> TokenCounts:
        ...

@dataclass(frozen=True)
class TokenCounts:
    input_tokens: int
    output_tokens: int
    inference_duration_ns: int
    prompt_eval_duration_ns: int
```

### Ollama Reference Implementation

Ollama's `/api/generate` endpoint returns token counts directly in the response:

```json
{
  "response": "...",
  "done": true,
  "prompt_eval_count": 125,
  "eval_count": 340,
  "eval_duration": 4500000000,
  "prompt_eval_duration": 500000
}
```

The `OllamaTokenCounter` extracts `prompt_eval_count` as input tokens and `eval_count` as output tokens. No external tokenizer library is required.

**Fallback**: When the engine response does not include token counts, a character-based estimation is used at a rate of approximately 3.5 characters per token. This fallback is conservative and produces overestimates, which are safe because overestimates only increase the refund to the user.

### GPU Time Tracking

GPU compute time is measured via `nvidia-smi` polling at 1-second intervals during inference. The tracker records GPU utilization percentage at each sample and computes **utilization-weighted seconds**:

```
gpu_seconds = SUM(dt_i * utilization_i)
```

where `dt_i` is the time delta between consecutive samples and `utilization_i` is the GPU utilization as a fraction (0.0 to 1.0). This metric reflects actual GPU work, not idle wall-clock time.

AMD (`rocm-smi`) and Intel (`xpu-smi`) backends use the same interface with vendor-specific CLI calls.

---

## Payment Verification

### Fail-Closed Design

Payment verification is **blocking and fail-closed**. If the relayer cannot confirm a valid escrow on-chain, the task is rejected. There is no bypass flag, no fallback to unverified execution, and no way to skip verification even in development.

This prevents a malicious client from submitting a fake `on_chain_task_id` and receiving free compute.

### On-Chain Checks

The `PaymentVerifier` calls `get_task()` on the smart contract and validates:

| Check | Condition | Failure Behavior |
|---|---|---|
| Task existence | `get_task()` returns valid data | Reject: "Task does not exist on-chain" |
| Task status | `status == CREATED` | Reject: "Task already completed/cancelled" |
| Escrow amount | `amount >= minimum_amount` | Reject: "Insufficient escrow" |
| Creator match | `creator == expected_address` | Reject: "Creator address mismatch" |
| Token type | `token_address == STRK` | Reject: "Invalid token" |

### Caching and Retry

- Verification results are cached in Redis with a **60-second TTL** to reduce RPC calls during retries.
- Cache key: `escrow_verified:{on_chain_task_id}`
- RPC failures trigger **exponential backoff retry** (up to 3 attempts).
- If all retries fail, the task is rejected with `verification_timeout`.

| Failure Scenario | Behavior |
|---|---|
| RPC timeout | Retry with backoff, then reject |
| Task does not exist | Reject immediately |
| Task already completed | Reject (no double-spend) |
| Task cancelled | Reject (funds already refunded) |
| Amount too low | Reject (user must create new task) |
| RPC node down | Reject with "rpc_unavailable" |

---

## Settlement

### Pipeline

Settlement follows a five-step pipeline, orchestrated by the `SettlementManager`:

```
Task completed by provider
         |
         v
+---------------------------------------+
|  1. Calculate actual cost              |
|     EffortCalculator.calculate()       |
|     Input: EffortMetrics               |
|     Output: CostBreakdown              |
|       actual_cost, effort_score        |
+---------------------------------------+
         |
         v
+---------------------------------------+
|  2. Read escrowed amount               |
|     From cached verification result    |
+---------------------------------------+
         |
         v
+---------------------------------------+
|  3. Compute refund                     |
|     RefundCalculator.compute()         |
|     refund = escrowed - actual_cost    |
|     provider_payout = 88% of actual    |
|     treasury_fee = 12% of actual       |
+---------------------------------------+
         |
         v
+---------------------------------------+
|  4. On-chain settlement                |
|     contract.settle_with_effort()      |
|     3 atomic transfers:               |
|       provider <- 88%                  |
|       treasury <- 12%                  |
|       user     <- refund               |
+---------------------------------------+
         |
         v
+---------------------------------------+
|  5. Update state                       |
|     Redis: task status -> "settled"    |
|     Emit EffortSettlement event        |
|     Callback to client with result     |
+---------------------------------------+
```

### Atomic On-Chain Settlement

The `settle_with_effort()` contract function executes three ERC-20 transfers in a single transaction. If any transfer fails, the entire transaction reverts. This guarantees that:

- The provider is never paid without the treasury receiving its fee.
- The user refund is never lost due to a partial execution.
- The task status is only marked COMPLETED after all transfers succeed.

The contract follows the **Checks-Effects-Interactions (CEI)** pattern:
1. **Checks**: Validate caller, task status, cost bounds, effort bounds, signature.
2. **Effects**: Mark signature as used, update task status.
3. **Interactions**: Execute the three ERC-20 transfers.

### Backward Compatibility

The original `submit_proof_and_claim()` function remains available. When a compute node running an older version submits results without effort metrics, the relayer falls back to flat-price settlement using the full escrowed amount. No refund is issued in this case.

---

## Trust and Verification (V2)

V1 relies on self-reported effort metrics signed by the provider. V2 introduces economic deterrence through optimistic verification: providers stake STRK as collateral, a subset of tasks are re-verified by an independent node, and confirmed discrepancies trigger graduated on-chain slashing.

### Staking Requirements

Providers must stake STRK before receiving task assignments. The staking contract is `smainer_staking.cairo`.

**Minimum stake formula:**

```
MIN_STAKE = MAX_EFFORT_BPS * BASE_PROMPT_COST_WEI * MAX_CONCURRENT_TASKS
```

Hard floor: **5 STRK**, regardless of formula output. This prevents stake minimization through a low concurrency declaration.

| Action | Condition | Delay |
|---|---|---|
| `stake()` | Any time | Immediate (active at next block) |
| `request_unstake()` | `active_task_count == 0` | 7-day lockup |
| `withdraw()` | After lockup expires, no active slash | Immediate |

`request_unstake()` reverts if the provider has any active tasks. There is no partial unstake. Tasks not submitted within **48 hours** are marked abandoned, decrementing the active task count and refunding the user in full.

### Spot-Check Selection

A deterministic function selects tasks for re-verification:

```
keccak256(block_hash || task_id) mod 100 < rate_pct
```

`block_hash` is the settlement block hash. Both values are available on-chain, making the selection set fully auditable by any external party without access to relayer-internal state.

**Reputation-adjusted rates:**

| Reputation Score | Spot-Check Rate |
|---|---|
| 90 -- 100 | 2% |
| 70 -- 89 | 5% |
| 50 -- 69 | 15% |
| 0 -- 49 | 30% |
| Active violation flag | 100% |

New providers start at score 50, placing them in the 5% spot-check tier.

### Violation Detection

The verifier re-runs inference using the original prompt, the claimed model, and `temperature=0`. Results are compared field by field:

| Metric | Condition | Verdict |
|---|---|---|
| Input token count | Any mismatch | VIOLATION |
| Output token count | Mismatch at `temperature=0` | VIOLATION |
| Output token count | Mismatch at `temperature>0` | INCONCLUSIVE |
| Result content | Any diff at `temperature=0` | VIOLATION |
| Result content | Any diff at `temperature>0` | INCONCLUSIVE |
| GPU time | Any diff | Never a trigger |
| Re-run failure | Timeout, model unavailable | INCONCLUSIVE |

GPU time is explicitly excluded as a violation trigger because hardware variance, VRAM scheduling, and background load make GPU duration non-deterministic across machines.

Three consecutive INCONCLUSIVE verdicts for the same provider within a 90-day window raise a manual review flag.

### Graduated Slashing

Offense count resets to zero after 90 days with no new violations.

| Offense (90-day window) | Slash Percentage | Provider Status After |
|---|---|---|
| First | 20% of staked STRK | Active |
| Second | 50% of staked STRK | Active |
| Third | 100% of staked STRK | NODE_SUSPENDED |

`NODE_SUSPENDED` providers are ineligible for task routing. Re-activation requires a new `stake()` meeting the minimum formula plus manual review clearance from the contract owner.

**Slash distribution:**

```
slashed_amount  = stake * slash_percentage
treasury_share  = slashed_amount * 80%
verifier_share  = slashed_amount * 20%
```

The 20% verifier incentive creates economic alignment: the verifier earns only when it detects genuine violations backed by auditable evidence.

**Constraints:**
- 24-hour cooldown between slash initiations on the same provider.
- Maximum 1 active slash per provider at any time. A second violation detected while an appeal is pending is queued.

### Provider Reputation

Reputation is stored off-chain in Redis. It is not a financial primitive -- it gates spot-check frequency only. Scores are in the range [0, 100].

| Event | Score Delta |
|---|---|
| Spot-check PASS | +2 |
| Honest pricing (actual cost <= 110% of estimate) | +1 |
| INCONCLUSIVE verdict | -5 |
| Confirmed VIOLATION | -15 |
| Full slash (3rd offense, NODE_SUSPENDED) | -50 |

**Design constraints:**
- No passive decay. Inactive providers retain their score.
- Score gain capped at +2 per PASS, preventing rapid recovery via trivially small tasks.
- Tasks with actual cost below 0.1 STRK do not generate positive score events (closes reputation-farming via micro-tasks). Violations from micro-tasks still apply full penalties.

### Appeal Process

1. Provider calls `appeal_slash(slash_id)` -- pauses the 7-day countdown, sets status to APPEALING.
2. Contract owner reviews evidence off-chain (evidence blobs are content-addressed and publicly readable).
3. Owner calls `resolve_appeal(slash_id, upheld)`:
   - `upheld = true`: Appeal denied, countdown resumes from where it paused.
   - `upheld = false`: Slash cancelled, violation flag cleared, offense count decremented.

Evidence blobs are stored in IPFS (preferred) or S3, with only the `keccak256(evidence_CID)` committed on-chain as `reason_hash`. Minimum retention period: 90 days, matching the rolling violation window.

---

## Smart Contract Interface

### Key Functions

**View functions:**

```cairo
fn get_task(self: @ContractState, task_id: u256) -> Task
```

Returns the full task struct including creator, amount, status, tier, and token address. Used by the relayer for escrow verification.

**Settlement functions:**

```cairo
fn settle_with_effort(
    ref self: ContractState,
    task_id: u256,
    provider: ContractAddress,
    result_hash: felt252,
    actual_cost: u256,
    effort_score: u256,       // Effort multiplier in BPS (e.g., 75000 = 7.5x)
    signature_r: felt252,
    signature_s: felt252,
)
```

Settles a task with effort-based pricing. Validates bounds, verifies provider signature (which commits to the exact `actual_cost`), executes atomic transfers, and emits events. Only callable by the authorized relayer.

```cairo
fn submit_proof_and_claim(
    ref self: ContractState,
    task_id: u256,
    provider: ContractAddress,
    result_hash: felt252,
    signature_r: felt252,
    signature_s: felt252,
)
```

Legacy flat-price settlement. Pays the full escrowed amount with the standard fee split. Retained for backward compatibility.

**Staking functions (V2):**

```cairo
fn stake(ref self: ContractState, amount: u256)
fn request_unstake(ref self: ContractState)
fn withdraw(ref self: ContractState)
fn is_eligible(self: @ContractState, provider: ContractAddress) -> bool
```

**Slashing functions (V2):**

```cairo
fn initiate_slash(ref self: ContractState, provider: ContractAddress, task_id: u256, reason_hash: felt252)
fn execute_slash(ref self: ContractState, provider: ContractAddress, slash_id: u256)
fn appeal_slash(ref self: ContractState, slash_id: u256)
fn resolve_appeal(ref self: ContractState, slash_id: u256, upheld: bool)
```

**Admin functions:**

```cairo
fn set_min_reward(ref self: ContractState, min_reward: u256)
fn set_max_effort_score(ref self: ContractState, max_score_bps: u256)
```

### Events

```cairo
struct EffortSettlement {
    task_id: u256,            // Indexed
    escrowed_amount: u256,
    actual_cost: u256,
    effort_score: u256,       // BPS
    provider_payout: u256,
    treasury_fee: u256,
    refund_amount: u256,
}

struct RefundIssued {
    task_id: u256,            // Indexed
    creator: ContractAddress, // Indexed
    amount: u256,
    token_address: ContractAddress,
}
```

**Signature scheme:**

The provider signs a Pedersen hash chain binding the task identity, result, and exact cost:

```
h1 = Pedersen(task_id, provider)
h2 = Pedersen(h1, result_hash)
message_hash = Pedersen(h2, actual_cost)
```

Replay protection is enforced via a `used_signatures` mapping. Each `(signature_r, signature_s)` pair can only be used once.

---

## Configuration

### Environment Variables

| Variable | Default | Required | Description |
|---|---|---|---|
| `SMAINER_CONTRACT_ADDRESS` | -- | Yes | Main Smainer escrow contract address |
| `STRK_TOKEN_ADDRESS` | -- | Yes | STRK ERC-20 token contract address |
| `RELAYER_PRIVATE_KEY` | -- | Yes | Relayer Starknet private key (settlement authority) |
| `RELAYER_ACCOUNT_ADDRESS` | -- | Yes | Relayer Starknet account address |
| `STARKNET_RPC_URL` | -- | Yes | Starknet JSON-RPC endpoint |
| `REQUIRE_PAYMENT_VERIFICATION` | `true` | No | Fail startup if verifier cannot initialize |
| `STAKING_CONTRACT_ADDRESS` | -- | Yes (V2) | SmainerStaking contract address |
| `VERIFIER_PRIVATE_KEY` | -- | Yes (V2) | Verifier Starknet private key (separate from relayer) |
| `VERIFIER_ACCOUNT_ADDRESS` | -- | Yes (V2) | Verifier Starknet account address |
| `SPOT_CHECK_BASE_RATE_PCT` | `5` | No | Base spot-check rate (2--30%) |
| `VERIFIER_RERUN_TIMEOUT_HOURS` | `24` | No | Max hours for verifier re-run |
| `EVIDENCE_STORAGE_URL` | -- | Yes (V2) | IPFS gateway or S3 URL for evidence blobs |
| `REPUTATION_SCORE_TTL_SECONDS` | `0` | No | Redis TTL for reputation (0 = no expiry) |
| `TASK_ABANDONMENT_TIMEOUT_HOURS` | `48` | No | Hours before task is marked abandoned |

All private key variables must be injected at runtime. They must never appear in source control, container images, or log output. The verifier key must be provisioned independently of the relayer key -- shared key material eliminates the security separation between settlement and verification authority.

---

## Constants Reference

| Constant | Value | Unit | Description |
|---|---|---|---|
| `BASE_PROMPT_COST` | 0.1 | STRK | Base cost per task (before tier multiplier) |
| `BASE_PROMPT_COST_WEI` | 100,000,000,000,000,000 | wei | Base cost in token wei (10^17) |
| `MIN_REWARD` | 0.01 | STRK | Absolute floor on settlement amount |
| `MIN_REWARD_WEI` | 10,000,000,000,000,000 | wei | Minimum reward in token wei (10^16) |
| `MAX_EFFORT_MULTIPLIER` | 7.5 | x | Hard cap on effort score |
| `MAX_EFFORT_BPS` | 75,000 | BPS | Effort cap in basis points |
| `SAFETY_MARGIN` | 1.3 | x | Pre-inference estimate buffer (30%) |
| `BASE_INPUT` | 100 | tokens | Normalized baseline for input tokens |
| `BASE_OUTPUT` | 256 | tokens | Normalized baseline for output tokens |
| `BASE_GPU_SECONDS` | 10.0 | seconds | Normalized baseline for GPU time |
| `INPUT_WEIGHT` | 0.3 | -- | Effort weight for input tokens |
| `OUTPUT_WEIGHT` | 0.5 | -- | Effort weight for output tokens |
| `GPU_TIME_WEIGHT` | 0.2 | -- | Effort weight for GPU time |
| `DEFAULT_COMPLEXITY` | 0.2 | -- | Fallback model complexity score |
| `TREASURY_FEE_BPS` | 1,200 | BPS | Treasury fee (12% of actual cost) |
| `GAS_SUBSIDY_BPS` | 300 | BPS | Gas subsidy to provider (3% of actual cost) |
| `PROVIDER_PAYOUT_BPS` | 8,800 | BPS | Total provider share (88% of actual cost) |
| `BPS_DENOMINATOR` | 10,000 | BPS | Basis point denominator |
| `TIER_BASIC` | 1.0 | x | BASIC tier multiplier |
| `TIER_PRO` | 2.2 | x | PRO tier multiplier |
| `TIER_PREMIUM` | 3.5 | x | PREMIUM tier multiplier |
| `MIN_STAKE` | 5.0 | STRK | Hard floor on provider stake (V2) |
| `UNSTAKE_LOCKUP` | 7 | days | Withdrawal delay after unstake request (V2) |
| `SLASH_APPEAL_WINDOW` | 7 | days | Appeal period before slash execution (V2) |
| `TASK_ABANDONMENT_TIMEOUT` | 48 | hours | Max time before task marked abandoned (V2) |
| `SLASH_COOLDOWN` | 24 | hours | Cooldown between slash initiations (V2) |
| `EVIDENCE_RETENTION` | 90 | days | Minimum retention for evidence blobs (V2) |
| `VIOLATION_WINDOW` | 90 | days | Rolling window for offense count reset (V2) |

---

## Repository Structure

Modules involved in the payment system:

```
backend/relayer/src/relayer/
  pricing/          Cost estimation and actual cost calculation
  verification/     On-chain escrow verification (fail-closed)
  settlement/       Post-inference settlement orchestration
  verifier/         Spot-check selection and re-verification (V2)

backend/provider/src/provider/
  metrics/          Token counting, GPU tracking, metrics collection

contracts/src/
  smainer.cairo           Main escrow contract (get_task, settle_with_effort)
  smainer_staking.cairo   Provider staking and slashing (V2)
  interfaces.cairo        Contract interface definitions
  pricing.cairo           On-chain effort validation helpers
```
