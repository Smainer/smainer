# Affiliate Traffic Fee System

> Module: `contracts/src/pricing.cairo` + `contracts/src/smainer.cairo` + `backend/relayer/src/relayer/settlement/` + `frontend/src/lib/affiliate.ts` + `telegram/smainer-bot/src/`
> Owner Agents: `fee-economist` + `starknet-engineer` + `technical-copywriter`
> Status: Implemented

---

## 1. Overview

The affiliate traffic fee system is Smainer's primary distribution growth mechanism. Any developer, community operator, or power user can deploy their own branded frontend or Telegram bot, set a single environment variable pointing to their Starknet wallet address, and earn 5% of every task fee generated through their deployment — permanently, with no registration, no approval process, and no cap.

One-sentence summary: Clone, set one env var, deploy, earn 5% of every task fee.

The economic proposition is straightforward. The treasury's existing 12% fee share is divided when an affiliate is present: 7% to treasury, 5% to the affiliate. The provider's 88% share is untouched in both paths. Total platform take remains 12% regardless of affiliate presence. This design means affiliate operators are paid entirely from treasury margin — there is no cost to users, no reduction in provider earnings, and no cross-subsidy between non-referred and referred traffic.

The system is intentionally permissionless. Affiliate addresses are not registered on-chain. Any valid Starknet address set in the deployment environment variable receives its share at settlement time. The 5% rate is low enough that the risk of any abuse scenario is bounded (see Section 8), and the simplicity of a single env var lowers the barrier to building Smainer-powered products to zero.

---

## 2. Fee Split Design

### Fee Split Comparison

| Recipient | Without Affiliate | With Affiliate |
|---|---|---|
| Provider | 88% (8800 BPS) | 88% (8800 BPS) |
| Affiliate | — | 5% (500 BPS) |
| Treasury | 12% (1200 BPS) | 7% (700 BPS) |
| **Total** | **100% (10000 BPS)** | **100% (10000 BPS)** |

### BPS Constants

All values are in basis points where 10000 BPS = 100%. The constants exist in both the Cairo contract and the Python relayer and must remain in sync.

**Cairo (contracts/src/pricing.cairo):**

```cairo
// Fee split constants (basis points, sum = 10000)
// 88% to provider, 12% to treasury
pub const TREASURY_FEE_BPS: u128 = 1200;
pub const PROVIDER_BPS: u128 = 8800;
pub const BPS_DENOMINATOR: u128 = 10000;

// Affiliate fee split constants (basis points, sum = 10000)
// When an affiliate is present: 88% provider, 5% affiliate, 7% treasury
pub const AFFILIATE_FEE_BPS: u128 = 500;                   // 5% affiliate
pub const TREASURY_FEE_BPS_WITH_AFFILIATE: u128 = 700;     // 7% treasury when affiliate present
```

**Cairo (contracts/src/smainer.cairo):**

```cairo
// Affiliate fee constant (basis points)
// When an affiliate is present: 5% to affiliate, 7% to treasury, 88% to provider
pub const AFFILIATE_FEE_BPS: u256 = 500;
```

**Python (backend/relayer/src/relayer/pricing/constants.py):**

```python
BPS_DENOMINATOR: int = 10_000

TREASURY_FEE_BPS: int = 700
"""7% of actual task cost routed to the Smainer treasury (affiliate path)."""

TREASURY_FEE_NO_AFFILIATE_BPS: int = 1_200
"""12% of actual task cost routed to the Smainer treasury (no-affiliate path)."""

AFFILIATE_FEE_BPS: int = 500
"""5% of actual task cost paid to the affiliate frontend deployer."""

GAS_SUBSIDY_BPS: int = 300
"""3% of actual task cost rebated to the provider as a gas subsidy."""

PROVIDER_BASE_BPS: int = 8_500
"""85% base provider payout share (before gas subsidy is added).

Total provider receipts = PROVIDER_BASE_BPS + GAS_SUBSIDY_BPS = 8 800 BPS.
"""
```

### Mathematical Invariants

Two invariants must hold at all times. Both are enforced independently by the Cairo contract and the Python relayer.

**Invariant 1 — Fee components sum to BPS_DENOMINATOR:**

```
# Affiliate path
TREASURY_FEE_BPS(700) + GAS_SUBSIDY_BPS(300) + PROVIDER_BASE_BPS(8500) + AFFILIATE_FEE_BPS(500) == 10000

# No-affiliate path
TREASURY_FEE_NO_AFFILIATE_BPS(1200) + GAS_SUBSIDY_BPS(300) + PROVIDER_BASE_BPS(8500) == 10000
```

The Python relayer enforces both invariants at module import time via explicit `raise ValueError` (not `assert`, which is suppressed by Python's `-O` flag — see SEC-013 in the relayer source):

```python
# SEC-013: Use explicit raise so this check survives Python -O.
if TREASURY_FEE_BPS + GAS_SUBSIDY_BPS + PROVIDER_BASE_BPS + AFFILIATE_FEE_BPS != BPS_DENOMINATOR:
    raise ValueError(
        "Fee BPS components (affiliate path) do not sum to 10 000.  "
        ...
    )

if TREASURY_FEE_NO_AFFILIATE_BPS + GAS_SUBSIDY_BPS + PROVIDER_BASE_BPS != BPS_DENOMINATOR:
    raise ValueError(
        "Fee BPS components (no-affiliate path) do not sum to 10 000.  "
        ...
    )
```

If any constant is edited without updating the others, the relayer process refuses to start.

**Invariant 2 — Fee split parts sum to actual_cost exactly (no wei lost to integer division):**

```
treasury_fee + affiliate_fee + provider_payout == actual_cost
refund_amount + actual_cost == escrowed_amount
```

### Why Provider Share Is Untouched

The provider's 88% is computed first from `PROVIDER_BPS = 8800` and is identical in both code paths. The affiliate introduction carved 5% from the treasury's original 12%, not from the provider. This was a deliberate design decision: providers make hardware and infrastructure investments on the basis of expected earnings. Retroactively reducing provider share to fund affiliate payouts would violate that expectation and undermine node operator incentives.

### Why Treasury Absorbs the 5% Reduction

Treasury operates as a protocol reserve with no fixed obligations. The 7% treasury share with an affiliate present is still sufficient to cover infrastructure costs at any realistic volume (see Section 9). The 5% affiliate carve-out is therefore a controllable cost of distribution, not a solvency risk.

### Dust and Rounding

Integer division in both Cairo and Python floors all BPS calculations. The subtraction-last formula in both implementations ensures that rounding dust accumulates in the residual component rather than being lost:

- In the Cairo `calculate_fee_split_with_affiliate()` function, `treasury_amount` is computed as `actual_cost - provider_amount - affiliate_amount` rather than `actual_cost * 700 / 10000`. This guarantees `provider + affiliate + treasury == actual_cost` exactly.
- In the Python `RefundCalculator.compute_refund()`, `provider_base` absorbs the residue of all floor divisions: `provider_base = actual - treasury_fee - affiliate_fee - gas_subsidy`.

---

## 3. How It Works — End-to-End Flow

```
AFFILIATE SETUP
───────────────
  1. Affiliate clones smainer repo
  2. Sets NEXT_PUBLIC_AFFILIATE_WALLET (frontend) or AFFILIATE_ADDRESS (bot)
  3. Deploys to Vercel or equivalent

USER TASK SUBMISSION
─────────────────────
  4. User opens affiliate's frontend / bot
  5. AFFILIATE_WALLET is resolved at build time (NEXT_PUBLIC_ prefix)
  6. frontend/src/lib/relayer-client.ts injects affiliate_address into POST body:
       POST /api/v1/tasks  { ..., affiliate_address: "0xABC..." }

RELAYER INGESTION
──────────────────
  7. Relayer validates affiliate_address via Pydantic pattern:
       r"^0x[0-9a-fA-F]{1,64}$"
  8. Relayer stores affiliate_address in Redis task hash:
       HSET task:{id} affiliate_address 0xABC...
     This write is IMMUTABLE — the affiliate cannot be changed after creation

TASK EXECUTION
───────────────
  9. Task is routed to a matching provider node (tier-based routing)
 10. Provider runs inference, measures EffortMetrics
 11. Provider signs (task_id, provider, result_hash, actual_cost) with Starknet key
     NOTE: affiliate address is NOT included in the signed message

SETTLEMENT — RELAYER SIDE
───────────────────────────
 12. SettlementManager reads affiliate_address from Redis:
       affiliate_address_raw = await redis.hget(f"task:{task_id}", "affiliate_address")
 13. Self-referral check:
       if affiliate_address.lower() == provider_address.lower():
           affiliate_address = None  # blocked
 14. RefundCalculator.compute_refund() selects fee path:
       has_affiliate → treasury 7% + affiliate 5% + provider 88%
       no affiliate  → treasury 12% + provider 88%
 15. SettlementManager routes to one of two contract calls:
       has_affiliate → _settle_with_effort_and_affiliate()
       no affiliate  → _settle_with_effort()

SETTLEMENT — ON-CHAIN
──────────────────────
 16. Contract validates: relayer authorization, task status, effort bounds,
     actual_cost <= escrowed, provider active, signature not replayed
 17. CEI pattern: all state changes written BEFORE any ERC-20 transfers
       task.status = TASK_SETTLED
       used_signatures[(r,s)] = true
 18. calculate_fee_split_with_affiliate(actual_cost, has_affiliate) executes:
       provider_amount = actual_cost * 8800 / 10000  (88%)
       affiliate_amount = actual_cost * 500 / 10000  (5%)   [or 0]
       treasury_amount = actual_cost - provider - affiliate  (absorbs dust)
 19. Atomic ERC-20 transfers (all succeed or the transaction reverts):
       Transfer → provider    (provider_payout)
       Transfer → affiliate   (affiliate_fee)   [skipped if affiliate is zero]
       Transfer → treasury    (treasury_fee)
       Transfer → creator     (refund_amount)   [skipped if zero]
 20. EffortSettlementV2 event emitted with all fields indexed
```

### Settlement Routing Decision

```
affiliate_address in Redis?
         │
    Yes  ├──→ self-referral? (affiliate == provider?)
         │         │
         │    Yes  ├──→ affiliate_address = None
         │         │
         │    No   └──→ has_affiliate = True
         │
    No   └──→ has_affiliate = False
                   │
                   ▼
         has_affiliate = True?
                   │
              Yes  ├──→ settle_with_effort_and_affiliate()
                   │    → EffortSettlementV2 event
                   │
              No   └──→ settle_with_effort()
                        → EffortSettlement event
```

---

## 4. Quick Start — For Affiliates

### Frontend Deployment

The Smainer frontend is a Next.js application deployable to Vercel in under 5 minutes.

**Steps:**

1. Fork or clone `https://github.com/smainer/smainer` (frontend directory)
2. Create a Vercel project from the fork
3. In Vercel project settings → Environment Variables, add:

```
NEXT_PUBLIC_AFFILIATE_WALLET=0x<your_starknet_address>
```

4. Deploy. Every task submitted through your frontend will carry your wallet address as the affiliate.

**Env var format and validation rules:**

- Must be `0x`-prefixed hexadecimal
- Hex body: 1 to 63 characters (not 64 — the module regex is `^0x[0-9a-fA-F]{1,63}$`)
- Case is normalized to lowercase at resolution time
- If the var is unset or fails validation, the affiliate field is silently omitted and the no-affiliate fee path is used — the frontend continues to function normally

**What happens with a malformed value:**

```typescript
// frontend/src/lib/affiliate.ts
const STARKNET_ADDRESS_RE = /^0x[0-9a-fA-F]{1,63}$/;

function resolveAffiliateWallet(): string | null {
  const raw = process.env.NEXT_PUBLIC_AFFILIATE_WALLET?.trim();
  if (!raw) return null;
  if (!STARKNET_ADDRESS_RE.test(raw)) {
    console.warn(
      '[affiliate] NEXT_PUBLIC_AFFILIATE_WALLET is set but failed validation. ' +
      'Expected 0x-prefixed hex (1-63 chars). Affiliate split will be skipped.'
    );
    return null;
  }
  return raw.toLowerCase();
}

export const AFFILIATE_WALLET: string | null = resolveAffiliateWallet();
```

A malformed address logs a warning to the browser console and falls back gracefully. It does not throw or break submission.

**SSR safety:** `NEXT_PUBLIC_AFFILIATE_WALLET` is inlined at build time by Next.js. It is available on the client without any server-side data fetching. There is no runtime `process.env` access on the client — the value is compiled into the bundle at `next build`.

**Footer attribution:** The `AFFILIATE_WALLET` export is also consumed by the footer component, which conditionally renders a "Powered by [affiliate brand]" attribution when the wallet is set. The attribution links back to the deployer's configured URL. If `AFFILIATE_WALLET` is null, the standard Smainer attribution renders.

### Telegram Bot Deployment

The Smainer Telegram bot is a Python serverless application deployable to Vercel.

**Steps:**

1. Fork or clone `https://github.com/smainer/smainer` (telegram directory)
2. Set environment variables in Vercel (or `.env` for local development):

```
TELEGRAM_BOT_TOKEN=<from BotFather>
AFFILIATE_ADDRESS=0x<your_starknet_address>
```

3. Deploy. Every inference request submitted through your bot will carry your affiliate address.

**Validation rules (telegram/smainer-bot/src/config.py):**

```python
_STARKNET_ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{1,64}$")

@field_validator("affiliate_address", mode="before")
@classmethod
def _validate_affiliate_address(cls, v: Optional[str]) -> Optional[str]:
    if v is None or v == "":
        return None
    if not _STARKNET_ADDRESS_RE.match(v):
        return None
    return v
```

Note the bot allows 64 hex chars (vs the frontend's 63). Both are valid Starknet addresses. An invalid `AFFILIATE_ADDRESS` silently becomes `None` — the bot continues operating on the no-affiliate fee path.

**How the address reaches the relayer (telegram/smainer-bot/src/relayer_client.py):**

```python
body = TaskSubmissionPayload(
    payload=payload_dict,
    requirements={...},
    token_amount=req.cost_strk,
    description=f"AI inference ({req.model}) via Telegram",
    on_chain_task_id=on_chain_task_id,
    affiliate_address=settings.affiliate_address,
)
```

`settings.affiliate_address` is the validated field from `config.py`. It is passed directly into `TaskSubmissionPayload` and forwarded to the relayer as part of the standard task submission body.

---

## 5. Smart Contract Architecture

### Interface Definition

The affiliate-aware settlement function is defined in `contracts/src/interfaces.cairo`:

```cairo
// Effort-based settlement with affiliate support.
// When affiliate is non-zero: provider 88%, affiliate 5%, treasury 7%.
// When affiliate is zero: identical split to settle_with_effort (provider 88%, treasury 12%).
// Provider signs the same hash as settle_with_effort — affiliate is NOT included in the
// signed message. Only callable by the authorized relayer.
// effort_score must be in [10000, 75000] BPS (1.0x – 7.5x).
fn settle_with_effort_and_affiliate(
    ref self: TContractState,
    task_id: u256,
    provider: ContractAddress,
    affiliate: ContractAddress,
    result_hash: felt252,
    actual_cost: u256,
    effort_score: u256,
    signature_r: felt252,
    signature_s: felt252
);
```

The pre-existing `settle_with_effort()` function is unchanged and remains the settlement path for all non-affiliate traffic.

### Fee Split Function

`contracts/src/pricing.cairo` — `calculate_fee_split_with_affiliate()`:

```cairo
/// Split actual_cost into provider, affiliate, and treasury amounts.
///
/// When has_affiliate is true (affiliate address is non-zero):
///   - provider_amount = actual_cost * 8800 / 10000  (88%)
///   - affiliate_amount = actual_cost * 500 / 10000  (5%)
///   - treasury_amount = actual_cost - provider - affiliate  (7%, absorbs dust)
///
/// When has_affiliate is false:
///   - provider_amount = actual_cost * 8800 / 10000  (88%)
///   - affiliate_amount = 0
///   - treasury_amount = actual_cost - provider  (12%, absorbs dust)
///
/// Returns (provider_amount, affiliate_amount, treasury_amount).
pub fn calculate_fee_split_with_affiliate(
    actual_cost: u256, has_affiliate: bool
) -> (u256, u256, u256) {
    let bps_denom: u256 = BPS_DENOMINATOR.into();
    let provider_bps: u256 = PROVIDER_BPS.into();

    let provider_amount = (actual_cost * provider_bps) / bps_denom;

    if has_affiliate {
        let affiliate_bps: u256 = AFFILIATE_FEE_BPS.into();
        let affiliate_amount = (actual_cost * affiliate_bps) / bps_denom;
        // Subtraction absorbs integer-division dust so that
        // provider + affiliate + treasury == actual_cost exactly.
        let treasury_amount = actual_cost - provider_amount - affiliate_amount;
        (provider_amount, affiliate_amount, treasury_amount)
    } else {
        let treasury_amount = actual_cost - provider_amount;
        (provider_amount, 0_u256, treasury_amount)
    }
}
```

The `has_affiliate` flag is derived inside `settle_with_effort_and_affiliate()` from the affiliate address:

```cairo
let has_affiliate = !affiliate.is_zero();
let (provider_payout, affiliate_fee, treasury_fee) =
    calculate_fee_split_with_affiliate(actual_cost, has_affiliate);
```

This means calling `settle_with_effort_and_affiliate()` with `affiliate = 0x0` produces exactly the same split as calling `settle_with_effort()`. The relayer always calls the correct function for the path, but the contract handles a zero affiliate address safely in either case.

### EffortSettlementV2 Event

Emitted by every `settle_with_effort_and_affiliate()` call. All three principal addresses are indexed keys for efficient event filtering:

```cairo
/// Emitted by settle_with_effort_and_affiliate when a task is settled with an affiliate.
/// When affiliate is non-zero: provider 88%, affiliate 5%, treasury 7%.
/// When affiliate is zero: provider 88%, affiliate_fee = 0, treasury 12%.
/// provider_payout + affiliate_fee + treasury_fee + refund_amount == task.amount (full escrow).
#[derive(Drop, starknet::Event)]
pub struct EffortSettlementV2 {
    #[key]
    pub task_id: u256,
    #[key]
    pub provider: ContractAddress,
    #[key]
    pub affiliate: ContractAddress,
    pub actual_cost: u256,
    pub effort_score: u256,
    pub provider_payout: u256,
    pub affiliate_fee: u256,
    pub treasury_fee: u256,
    pub refund_amount: u256,
}
```

To query all settlements for a specific affiliate, filter `EffortSettlementV2` events where `affiliate == <your_address>`. The invariant `provider_payout + affiliate_fee + treasury_fee + refund_amount == task.amount` holds for every emitted event.

### Backward Compatibility and Upgrade Path

The existing `settle_with_effort()` function is not modified. All existing provider integrations, monitoring dashboards, and event parsers continue to work without changes. The original `EffortSettlement` event is still emitted by the non-affiliate path.

The contract is upgraded via the existing `upgrade(new_class_hash)` function (OwnableComponent gate):

```cairo
fn upgrade(ref self: TContractState, new_class_hash: starknet::ClassHash);
```

No storage migration is required. The affiliate system adds no new storage slots — affiliate addresses are not stored on-chain. All affiliate routing is determined by the calldata passed at settlement time.

**Contract address (mainnet):**
`0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe`

**Gas cost differential:** The affiliate path adds one conditional ERC-20 `transfer()` call (the affiliate payout) when `has_affiliate == true`. When `has_affiliate == false`, no additional transfers occur. Gas overhead is therefore +1 transfer (~10,000–15,000 gas on Starknet) only for affiliate-referred settlements.

### Signature Scheme Stability

The provider signs `pedersen(pedersen(pedersen(task_id, provider), result_hash), actual_cost)` — the same message hash used by `settle_with_effort()`. The affiliate address is intentionally excluded from the signed message. This design choice means:

1. Existing providers do not need to update their signing code to support affiliates.
2. The relayer can attach or suppress an affiliate address without requiring a new provider signature format.
3. The trust model is: the relayer is trusted to pass the correct affiliate address, consistent with its role as the settlement authority (see Section 8).

---

## 6. Relayer Integration

### API Schema

`affiliate_address` is an optional field on `TaskSubmission` (`backend/relayer/src/relayer/models/schemas.py`):

```python
class TaskSubmission(BaseModel):
    """Request model for task submission."""
    payload: Dict[str, Any] = Field(description="Task payload data")
    requirements: TaskRequirements = Field(description="Resource requirements")
    token_amount: int = Field(gt=0, description="Payment amount in tokens")
    description: Optional[str] = Field(None, max_length=500, description="Task description")
    on_chain_task_id: Optional[int] = Field(None, ge=0, description="On-chain task ID from create_task() for escrow payment flow")
    affiliate_address: Optional[str] = Field(
        None,
        min_length=3,
        max_length=66,
        pattern=r"^0x[0-9a-fA-F]{1,64}$",
        description="Starknet address of the affiliate frontend deployer. Earns 5% of task cost.",
    )
```

The Pydantic validator rejects any `affiliate_address` that does not match `^0x[0-9a-fA-F]{1,64}$`. Malformed values cause a 422 response before the task is created. A missing (null) `affiliate_address` is accepted — the no-affiliate path is used for that task.

### Redis Storage

When the scheduler creates a task record in Redis, it writes `affiliate_address` into the task hash alongside the other task fields:

```
HSET task:{task_id} affiliate_address 0xABC...
```

This write happens at task creation time and is never updated. The affiliate address is immutable for the lifetime of the task. A user cannot change their affiliate after submission. The relayer cannot be tricked into changing the affiliate between submission and settlement because the settlement code reads from the same Redis hash that the scheduler wrote.

### Dual-Path Fee Calculation

`RefundCalculator.compute_refund()` in `backend/relayer/src/relayer/settlement/refund.py` implements both fee paths:

```python
# --- 2. Determine affiliate presence -----------------------------------
has_affiliate = (
    affiliate_address is not None
    and affiliate_address != "0x0"
    and len(affiliate_address) > 2
)

# --- 3. BPS fee split on actual cost -----------------------------------
# Integer floor division -- no floating-point at any step.
if has_affiliate:
    treasury_fee = (actual * TREASURY_FEE_BPS) // BPS_DENOMINATOR
    affiliate_fee = (actual * AFFILIATE_FEE_BPS) // BPS_DENOMINATOR
else:
    treasury_fee = (actual * TREASURY_FEE_NO_AFFILIATE_BPS) // BPS_DENOMINATOR
    affiliate_fee = 0

gas_subsidy = (actual * GAS_SUBSIDY_BPS) // BPS_DENOMINATOR

# --- 4. Provider base absorbs BPS integer division residue ------------
provider_base = actual - treasury_fee - affiliate_fee - gas_subsidy

# --- 5. Total provider receipt ----------------------------------------
provider_payout = provider_base + gas_subsidy
```

The relayer computes these amounts for internal record-keeping, logging, and Redis persistence. The contract re-computes them independently from `actual_cost` and enforces them on-chain. The relayer's calculation and the contract's calculation must agree — if they diverge, the on-chain invariant check will revert.

### Self-Referral Block

Located in `backend/relayer/src/relayer/settlement/settler.py`:

```python
# Self-referral block: affiliate == provider -> no affiliate payout.
# Comparison is case-insensitive since addresses are hex-encoded.
if affiliate_address is not None and affiliate_address.lower() == provider_address.lower():
    logger.warning(
        "SettlementManager.settle_task: self-referral blocked "
        "affiliate=%s provider=%s task_id=%s",
        affiliate_address,
        provider_address,
        task_id,
    )
    affiliate_address = None
```

When a provider submits a task through their own affiliate frontend, the affiliate address matches the provider address. Setting `affiliate_address = None` before calling `compute_refund()` forces the no-affiliate fee path, so the provider receives no affiliate payment. This check occurs after reading the task from Redis and before computing the fee split. It is enforced at the relayer layer; the contract itself does not check for self-referral (it has no means to do so, as the provider and affiliate are separate calldata fields).

### Settlement Routing

`settler.py` routes to the appropriate contract function based on `has_affiliate`:

```python
# Determine affiliate presence for on-chain routing
has_affiliate = (
    affiliate_address is not None
    and affiliate_address != "0x0"
    and len(affiliate_address) > 2
)

if has_affiliate:
    tx_hash = await self._settle_with_effort_and_affiliate(
        on_chain_task_id=on_chain_task_id,
        provider_address=provider_address,
        result_hash=result_hash,
        actual_cost=refund.actual_cost,
        effort_bps=effort_bps,
        signature_r=signature_r,
        signature_s=signature_s,
        affiliate_address=affiliate_address,
    )
else:
    tx_hash = await self._settle_with_effort(
        on_chain_task_id=on_chain_task_id,
        provider_address=provider_address,
        result_hash=result_hash,
        actual_cost=refund.actual_cost,
        effort_bps=effort_bps,
        signature_r=signature_r,
        signature_s=signature_s,
    )
```

The calldata for the affiliate path appends one additional element — the affiliate address as a felt252 integer — at the end of the standard `settle_with_effort` calldata array:

```python
calldata=[
    task_id_low,        # task_id u256 low
    task_id_high,       # task_id u256 high
    provider_addr_int,  # provider: ContractAddress
    result_hash_int,    # result_hash: felt252
    actual_cost_low,    # actual_cost u256 low
    actual_cost_high,   # actual_cost u256 high
    effort_bps,         # effort_score_bps: u32
    sig_r_int,          # signature_r: felt252
    sig_s_int,          # signature_s: felt252
    affiliate_addr_int, # affiliate: ContractAddress  ← affiliate path only
],
```

### BPS Invariant Guard

The constants module raises `ValueError` at import time if any path's BPS components do not sum to 10000. This means the relayer process cannot start with a misconfigured fee split. The check is implemented with an explicit `raise` rather than `assert` to survive Python's `-O` optimization flag, which strips all `assert` statements:

```python
# SEC-013: Use explicit raise so this check survives Python -O.
# Affiliate path: TREASURY(7%) + AFFILIATE(5%) + GAS(3%) + PROVIDER(85%) = 100%
if TREASURY_FEE_BPS + GAS_SUBSIDY_BPS + PROVIDER_BASE_BPS + AFFILIATE_FEE_BPS != BPS_DENOMINATOR:
    raise ValueError(
        "Fee BPS components (affiliate path) do not sum to 10 000.  "
        f"Got {TREASURY_FEE_BPS} + {GAS_SUBSIDY_BPS} + {PROVIDER_BASE_BPS} "
        f"+ {AFFILIATE_FEE_BPS} "
        f"= {TREASURY_FEE_BPS + GAS_SUBSIDY_BPS + PROVIDER_BASE_BPS + AFFILIATE_FEE_BPS}"
    )
```

### Prometheus Metrics

The settlement system emits per-task Prometheus metrics. Affiliate-specific tracking is covered by the existing `settlement_*` histogram family, since every `SettlementRecord` now includes `affiliate_fee` and `affiliate_address` fields. Operators can filter affiliate settlements by querying for records where `affiliate_fee > 0`. Additional affiliate-specific counters can be added to the metrics layer without contract changes.

---

## 7. Frontend Integration

### The affiliate.ts Module

`frontend/src/lib/affiliate.ts` is the single source of truth for affiliate wallet resolution in the frontend:

```typescript
const STARKNET_ADDRESS_RE = /^0x[0-9a-fA-F]{1,63}$/;

function resolveAffiliateWallet(): string | null {
  const raw = process.env.NEXT_PUBLIC_AFFILIATE_WALLET?.trim();
  if (!raw) return null;
  if (!STARKNET_ADDRESS_RE.test(raw)) {
    console.warn(
      '[affiliate] NEXT_PUBLIC_AFFILIATE_WALLET is set but failed validation. ' +
      'Expected 0x-prefixed hex (1-63 chars). Affiliate split will be skipped.'
    );
    return null;
  }
  return raw.toLowerCase();
}

export const AFFILIATE_WALLET: string | null = resolveAffiliateWallet();
```

`AFFILIATE_WALLET` is evaluated once at module initialization (build time, via Next.js static inlining of `NEXT_PUBLIC_` vars). It is a module-level constant — never re-evaluated on each request.

### Injection in relayer-client.ts

`frontend/src/lib/relayer-client.ts` imports `AFFILIATE_WALLET` and injects it into task submission payloads using a conditional spread:

```typescript
import { AFFILIATE_WALLET } from './affiliate';

// Inside submitTaskToRelayer():
return this.request<RelayerTaskResult>('/api/v1/tasks', {
  method: 'POST',
  body: JSON.stringify({
    ...taskData,
    ...(AFFILIATE_WALLET && { affiliate_address: AFFILIATE_WALLET }),
  }),
});
```

The conditional spread `...(AFFILIATE_WALLET && { affiliate_address: AFFILIATE_WALLET })` means the `affiliate_address` key is only present in the JSON body when `AFFILIATE_WALLET` is a non-null string. Absent the env var, the submitted JSON body contains no `affiliate_address` field at all — not a null value, not an empty string, but a missing key. This is the correct behavior for the relayer's Pydantic optional field.

### .env.example Documentation

The env var is documented in `frontend/.env.example`:

```
# Affiliate Program
# Your Starknet wallet address (0x-prefixed hex).
# Deployers who set this earn 5% of the Smainer treasury fee on every task.
# Leave unset to deploy without affiliate earnings.
# NEXT_PUBLIC_AFFILIATE_WALLET=0x
```

The line is commented out in the example. Deployers uncomment it and fill in their address. The trailing `=0x` is not a valid address (it would fail the regex) — it serves as a visual cue for the expected format.

---

## 8. Security Model

### Threat Model and Mitigations

| Threat | Attack Vector | Mitigation | Residual Risk |
|---|---|---|---|
| Affiliate address spoofing | Attacker injects their own affiliate address into a task submission | Permissionless by design — any address can be an affiliate. Worst case: the attacker benefits from their own traffic, same as any legitimate affiliate. No user is harmed. | Low |
| Self-referral | Provider submits tasks through their own affiliate deployment to collect 5% | Blocked at relayer layer: `affiliate.lower() == provider.lower()` sets affiliate to None | Relayer compromise could bypass; see trust boundary below |
| Wash trading | Actor creates tasks as both user and provider, routes them through affiliate to capture 5% back | Self-liquidating: attacker pays full task cost as user, earns 88% as provider and 5% as affiliate = 93% return per cycle. Each cycle destroys 7% to treasury. Not profitable — 7 cycles reduces capital to 63% | Economically bounded |
| Reentrancy | Attacker contract re-enters `settle_with_effort_and_affiliate()` during a transfer | CEI pattern enforced: `task.status = TASK_SETTLED` and `used_signatures[(r,s)] = true` are written before any `erc20.transfer()` calls. Second call hits `'Invalid task status'` or `'Signature already used'` assertion | None — CEI is structurally sound |
| MITM affiliate injection | Network attacker intercepts API call and substitutes affiliate address | HTTPS transport encryption. Relayer binds affiliate at creation (immutable Redis write). Post-creation modification is not possible. | None with HTTPS |
| Zero-address affiliate | Affiliate address is `0x0`, triggering unexpected transfer | `has_affiliate = !affiliate.is_zero()` — zero address affiliate skips the affiliate transfer entirely. Treasury receives its normal 7% share (but this is a no-affiliate call path so treasury gets 12%). | None |
| Treasury address manipulation | Relayer submits wrong treasury | Treasury is stored on-chain, set by contract owner. Relayer cannot override it. | None |

### Trust Boundaries

The relayer is the trust anchor for the affiliate system. It makes three security-relevant decisions that are not re-verified on-chain:

1. **Affiliate address binding**: The relayer reads `affiliate_address` from the request and stores it in Redis. The contract trusts whatever address the relayer passes as `affiliate` in `settle_with_effort_and_affiliate()`.
2. **Self-referral enforcement**: The self-referral block is enforced by the relayer. A compromised relayer could pass an affiliate address equal to the provider address and the contract would pay the affiliate. This is acceptable: the relayer already controls the settlement call entirely (it is the only authorized caller). Affiliate bypass is a subset of the broader relayer trust assumption.
3. **Effort score and actual_cost**: The relayer computes these and passes them to the contract. The contract validates bounds but not correctness. This is the V1 trust model documented in [10-trust-assumption.md](10-trust-assumption.md).

### Why Permissionless Is Acceptable

On-chain affiliate registration would require a transaction per affiliate, a registry storage slot, and governance over registration/revocation. For a 5% fee on a subset of traffic, this overhead is not justified. The permissionless model means:

- Any Starknet address receives its affiliate share automatically at settlement
- No Smainer team involvement is required to onboard an affiliate
- A malicious affiliate receives at most 5% of the task cost they referred, which is the same rate any legitimate affiliate earns
- There is no mechanism to steal user funds or provider earnings through affiliate manipulation alone

---

## 9. Economic Analysis

### Treasury Sustainability at 7%

With no affiliate traffic, the treasury collects 12% of every settled task. With full affiliate coverage (all traffic referred through affiliates), the treasury floor is 7%. At a network volume of `V` STRK per month in settled task costs:

- No-affiliate: treasury = `0.12V`
- Full-affiliate: treasury = `0.07V`

The 5% differential represents the maximum growth cost. Infrastructure costs are fixed in absolute terms, not percentage terms. A growing network increases both the absolute treasury take and the affiliate payouts, so treasury sustainability improves with volume regardless of affiliate coverage fraction.

### No-Affiliate Traffic Safety Valve

Direct traffic (through `app.smainer.io` or any deployment without `NEXT_PUBLIC_AFFILIATE_WALLET` set) uses the no-affiliate path and contributes 12% to the treasury. This direct traffic serves as a revenue floor that is independent of affiliate growth dynamics.

### Why Wash Trading Is Unprofitable

An actor who operates as both user and provider can route tasks through their own affiliate deployment:

```
Task cost: 1.0 STRK
User pays: 1.0 STRK (escrowed)
Provider earns: 0.88 STRK
Affiliate earns: 0.05 STRK
Treasury takes: 0.07 STRK

Net position after one cycle: 0.88 + 0.05 - 1.0 = -0.07 STRK
```

Each cycle destroys 0.07 STRK (7%) to the treasury. After 10 cycles the actor has destroyed 70% of their starting capital. This is not a viable attack — it is a donation to the protocol treasury.

### Self-Referral as a 5% Rebate

Without the self-referral block, a provider could deploy their own affiliate frontend, submit all their own tasks through it, and receive a 5% rebate on every task they execute. This would reduce effective treasury take from 12% to 7% on provider-self-served traffic. The relayer blocks this at the settlement layer as described in Section 6. Even if the block were circumvented, the economic impact would be a 5% improvement in provider economics at treasury expense — not a threat to user funds or network integrity.

### No Cap or Vesting

Affiliate earnings are paid immediately at settlement, proportional to task cost, with no cap and no vesting schedule. This simplicity is intentional: adding complexity (caps, lockups, vesting) would require storage, indexing, and governance without providing a meaningful security improvement given the 5% rate.

---

## 10. Rollout Plan

### Deployment Sequence

The affiliate system is backward compatible and requires no coordination with existing providers or users. The deployment sequence is:

1. **Deploy updated contract class** — `scarb build && sncast declare`. The new class adds `settle_with_effort_and_affiliate()` and `AFFILIATE_FEE_BPS` constant. No storage changes.

2. **Upgrade live contract** — `contract.upgrade(new_class_hash)` called by contract owner. The existing `settle_with_effort()` function continues to work identically during and after the upgrade. In-flight tasks (created before upgrade, settled after) will use `settle_with_effort()` and emit `EffortSettlement` events — this is correct behavior and requires no special handling.

3. **Deploy updated relayer** — The updated `settler.py` and `refund.py` read `affiliate_address` from Redis and route to the new contract function. Tasks created before the relayer update will have no `affiliate_address` in their Redis hash — `hget` returns `None`, `has_affiliate = False`, and `settle_with_effort()` is called. Backward compatible by construction.

4. **Deploy updated frontend** — `affiliate.ts` and updated `relayer-client.ts` go live. The `NEXT_PUBLIC_AFFILIATE_WALLET` env var is set for the canonical `app.smainer.io` deployment (or left unset — the system works either way). Affiliate deployments set their own wallet address.

5. **Deploy updated Telegram bot** — `config.py` with `affiliate_address` field and updated `relayer_client.py` deployed. Existing bot instances without `AFFILIATE_ADDRESS` continue to function on the no-affiliate path.

### In-Flight Task Handling

Tasks created before the relayer update that reach settlement after the update will have no `affiliate_address` Redis field. The settlement code handles this correctly: `hget` returns `None`, the no-affiliate path is taken, and `settle_with_effort()` is called. No special migration or cutover logic is required.

Tasks cannot be created after the relayer update but settled before the contract upgrade — if `has_affiliate == True` and the relayer calls `settle_with_effort_and_affiliate()` on an un-upgraded contract, the call will revert with "Entry point not found". To prevent this edge case, the contract upgrade (step 1-2) must be completed before the relayer update (step 3).

### Monitoring — First 10 Settlements

After the contract upgrade and relayer deployment, monitor the first 10 affiliate settlements:

1. Confirm `EffortSettlementV2` events are emitted (not `EffortSettlement`)
2. Verify `affiliate_fee` field in emitted events matches expected 5% of `actual_cost`
3. Verify `treasury_fee` field matches expected 7% of `actual_cost`
4. Verify ERC-20 transfer to affiliate address occurred in the settlement transaction
5. Cross-check Redis `affiliate_fee` field written by settler matches on-chain event

---

## 11. File Reference

| Repo | Path | Change |
|---|---|---|
| contracts | `src/pricing.cairo` | Added `AFFILIATE_FEE_BPS = 500`, `TREASURY_FEE_BPS_WITH_AFFILIATE = 700`, `calculate_fee_split_with_affiliate()` |
| contracts | `src/smainer.cairo` | Added `AFFILIATE_FEE_BPS = 500` constant, `EffortSettlementV2` event, `settle_with_effort_and_affiliate()` implementation |
| contracts | `src/interfaces.cairo` | Added `settle_with_effort_and_affiliate()` to `ISmainer` trait |
| backend | `relayer/src/relayer/pricing/constants.py` | Added `TREASURY_FEE_BPS = 700`, `TREASURY_FEE_NO_AFFILIATE_BPS = 1200`, `AFFILIATE_FEE_BPS = 500`, both BPS invariant guards |
| backend | `relayer/src/relayer/settlement/refund.py` | Dual-path `compute_refund()` with `affiliate_address` parameter |
| backend | `relayer/src/relayer/settlement/settler.py` | Redis affiliate read, self-referral block, `_settle_with_effort_and_affiliate()` helper |
| backend | `relayer/src/relayer/models/schemas.py` | `affiliate_address` optional field on `TaskSubmission` and `TaskResponse` |
| frontend | `src/lib/affiliate.ts` | New module: `resolveAffiliateWallet()`, `AFFILIATE_WALLET` export |
| frontend | `src/lib/relayer-client.ts` | Import `AFFILIATE_WALLET`, conditional spread into task submission body |
| frontend | `.env.example` | `NEXT_PUBLIC_AFFILIATE_WALLET` documentation (commented) |
| telegram | `smainer-bot/src/config.py` | `affiliate_address` optional field with validator |
| telegram | `smainer-bot/src/relayer_client.py` | `affiliate_address=settings.affiliate_address` in `TaskSubmissionPayload` |

---

## 12. Appendix: Worked Example

### Parameters

- Task: AI inference via Telegram bot with `AFFILIATE_ADDRESS` set
- Tier: PREMIUM (RTX 4090, 24GB GDDR6X)
- Model: `llama3.1:70b`
- Escrowed amount: 1.3 STRK (30% safety margin applied to 1.0 STRK base estimate)
- Effort score: 2.1x (21000 BPS) — moderate workload, within [10000, 75000] bounds
- Actual cost: 1.0 STRK (effort pricing resolved to base estimate)
- Affiliate: `0xDEAD...` (distinct from provider address — self-referral check passes)

### With Affiliate Present

```
Actual cost:       1.000000000000000000 STRK  (10^18 wei)
Escrowed amount:   1.300000000000000000 STRK

Fee split on actual_cost = 1.000000000000000000:
  provider_amount  = 1.0 * 8800 / 10000 = 0.880000000000000000 STRK  (88%)
  affiliate_amount = 1.0 * 500  / 10000 = 0.050000000000000000 STRK  (5%)
  treasury_amount  = 1.0 - 0.88 - 0.05  = 0.070000000000000000 STRK  (7%)

Refund to creator:
  refund = escrowed - actual_cost = 1.3 - 1.0 = 0.300000000000000000 STRK

Verification (full escrow accounted for):
  0.88 + 0.05 + 0.07 + 0.30 = 1.30 STRK = escrowed amount  [INVARIANT HOLDS]

On-chain transfers (settle_with_effort_and_affiliate):
  1. Transfer 0.880000000000000000 STRK → provider
  2. Transfer 0.050000000000000000 STRK → affiliate (0xDEAD...)
  3. Transfer 0.070000000000000000 STRK → treasury
  4. Transfer 0.300000000000000000 STRK → creator (refund)

Event emitted: EffortSettlementV2 {
  task_id:         42
  provider:        0xPROV...
  affiliate:       0xDEAD...
  actual_cost:     1000000000000000000
  effort_score:    21000
  provider_payout: 880000000000000000
  affiliate_fee:   50000000000000000
  treasury_fee:    70000000000000000
  refund_amount:   300000000000000000
}
```

### Without Affiliate (same task, no affiliate address set)

```
Actual cost:       1.000000000000000000 STRK
Escrowed amount:   1.300000000000000000 STRK

Fee split on actual_cost = 1.000000000000000000:
  provider_amount  = 1.0 * 8800 / 10000 = 0.880000000000000000 STRK  (88%)
  affiliate_amount = 0                                                  (0%)
  treasury_amount  = 1.0 - 0.88          = 0.120000000000000000 STRK  (12%)

Refund to creator:
  refund = 1.3 - 1.0 = 0.300000000000000000 STRK

Verification:
  0.88 + 0.00 + 0.12 + 0.30 = 1.30 STRK  [INVARIANT HOLDS]

On-chain transfers (settle_with_effort):
  1. Transfer 0.880000000000000000 STRK → provider
  2. Transfer 0.120000000000000000 STRK → treasury
  3. Transfer 0.300000000000000000 STRK → creator (refund)

Event emitted: EffortSettlement {
  task_id:         43
  provider:        0xPROV...
  actual_cost:     1000000000000000000
  effort_score:    21000
  provider_payout: 880000000000000000
  treasury_fee:    120000000000000000
  refund_amount:   300000000000000000
}
```

### Integer Division Dust (worst case)

When `actual_cost` is not evenly divisible by 10000, the subtraction-last formula absorbs the dust into treasury. Example with `actual_cost = 1000000000000000001` wei (1 STRK + 1 wei):

```
provider_amount  = 1000000000000000001 * 8800 / 10000 = 880000000000000000  (floor)
affiliate_amount = 1000000000000000001 * 500  / 10000 = 50000000000000000   (floor)
treasury_amount  = 1000000000000000001 - 880000000000000000 - 50000000000000000
                 = 70000000000000001   (absorbs the 1 wei of dust)

Sum check: 880000000000000000 + 50000000000000000 + 70000000000000001
         = 1000000000000000001  [EXACT — no wei lost]
```

---

## Related Documents

| Document | Relevance |
|---|---|
| [05-settlement-system.md](05-settlement-system.md) | Settlement pipeline architecture; effort calculator and RefundCalculator design |
| [09-security-review.md](09-security-review.md) | SEC-013 invariant guard rationale; broader fee system security review |
| [10-trust-assumption.md](10-trust-assumption.md) | Relayer trust model; optimistic verification V2.0 architecture |
| [00-overview.md](00-overview.md) | System constants: BASE_PROMPT_COST, MAX_EFFORT_MULT, fee splits |
