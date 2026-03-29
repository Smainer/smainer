# Effort-Based Pricing System

> Module: `backend/relayer/src/relayer/pricing/`
> Owner Agent: `fee-economist`
> Status: Planned

## Purpose

Replace flat per-tier pricing with dynamic effort-based pricing that reflects actual compute work performed. Users pay fairly for what they consume; providers earn fairly for what they deliver.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Effort multiplier cap | 7.5x base | Prevent shock pricing while allowing heavy workloads |
| Minimum cost | Base rate floor (0.1 STRK for BASIC) | Ensure providers always earn a viable minimum |
| Refund mechanism | On-chain refund to user wallet | Trustless — no credit system or off-chain holding |
| Treasury fee basis | 12% of actual cost (not escrowed) | Fair to users — treasury doesn't profit from overestimates |

## Cost Formula

### Pre-Inference: Estimated Cost (what user escrows)

```
estimated_cost = base_rate × tier_multiplier × estimated_effort × SAFETY_MARGIN

estimated_effort = max(1.0,
    (input_tokens / BASE_INPUT) × INPUT_WEIGHT
  + (est_output_tokens / BASE_OUTPUT) × OUTPUT_WEIGHT
  + model_complexity_factor
)

SAFETY_MARGIN = 1.3  (30% buffer for estimation variance)
```

### Post-Inference: Actual Cost (what is settled)

```
actual_cost = max(
    BASE_FLOOR,
    base_rate × tier_multiplier × min(actual_effort, MAX_EFFORT_MULTIPLIER)
)

actual_effort =
    (input_tokens / BASE_INPUT) × INPUT_WEIGHT
  + (output_tokens / BASE_OUTPUT) × OUTPUT_WEIGHT
  + model_complexity_factor
  + (gpu_seconds / BASE_GPU_SECONDS) × GPU_TIME_WEIGHT

MAX_EFFORT_MULTIPLIER = 7.5
BASE_FLOOR = base_rate × tier_multiplier  (minimum = flat tier price)
```

### Constants

```python
BASE_INPUT          = 100    # tokens (normalized baseline)
BASE_OUTPUT         = 256    # tokens (normalized baseline)
BASE_GPU_SECONDS    = 10.0   # seconds (normalized baseline)
INPUT_WEIGHT        = 0.3    # prompt processing is cheaper
OUTPUT_WEIGHT       = 0.5    # generation is the expensive part
GPU_TIME_WEIGHT     = 0.2    # GPU time accounts for hardware variance
SAFETY_MARGIN       = 1.3    # 30% buffer for pre-inference estimates
MAX_EFFORT_MULT     = 7.5    # hard cap on effort multiplier
MIN_REWARD_STRK     = 0.01   # absolute floor in STRK (covers gas)
```

### Model Complexity Factors

Complexity is determined by parameter count, not by model name.  This makes
the system generic: any model — including custom fine-tunes and future
architectures — receives a complexity score purely from its size.

```python
# COMPLEXITY_BARS: list[tuple[min_params_b, max_params_b_or_None, score]]
COMPLEXITY_BARS = [
    (0,    10,   0.2),   # Bar 1 — Small     (< 10 B params)
    (10,   20,   0.4),   # Bar 2 — Medium    (10 – 20 B params)
    (20,   50,   0.6),   # Bar 3 — Large     (20 – 50 B params)
    (50,   200,  0.8),   # Bar 4 — XL        (50 – 200 B params)
    (200,  None, 1.0),   # Bar 5 — Frontier  (200 B+ params)
]
DEFAULT_COMPLEXITY_BAR = 0.2   # fallback when param count is unknown
```

#### Resolution order (`get_model_complexity(model_id, param_count_billions)`)

1. If `param_count_billions` is provided explicitly (e.g. by the provider node),
   map it directly to a bar.
2. Otherwise, extract the parameter count from `model_id` using regex:
   - Standard: `"llama3.1:70b"` → 70 B
   - MoE: `"mixtral:8x7b"` → 8 × 7 = 56 B
3. Fall back to `DEFAULT_COMPLEXITY_BAR` (0.2) if neither succeeds.

This function is the **single entry point** for complexity lookup — no model
name dictionary exists anywhere in the pricing module.

### Tier Multipliers (unchanged from contract)

```
BASIC   = 1.0x   (10000 BPS)
PRO     = 2.2x   (22000 BPS)
PREMIUM = 3.5x   (35000 BPS)
```

## Worked Examples

### Example 1: Short prompt "Hi" on BASIC tier

```
Input tokens:  2
Output tokens: 15
GPU seconds:   0.5
Model:         llama3.1:8b (7b class → complexity 0.2)

actual_effort = (2/100)*0.3 + (15/256)*0.5 + 0.2 + (0.5/10)*0.2
              = 0.006 + 0.029 + 0.2 + 0.01
              = 0.245

actual_cost = max(0.1, 0.1 × 1.0 × 0.245) = max(0.1, 0.0245) = 0.1 STRK
→ Floor applies. User pays base rate. Provider earns minimum.
```

### Example 2: Long document analysis on PRO tier

```
Input tokens:  3000
Output tokens: 1500
GPU seconds:   45
Model:         llama3.1:70b (70b class → complexity 0.8)

actual_effort = (3000/100)*0.3 + (1500/256)*0.5 + 0.8 + (45/10)*0.2
              = 9.0 + 2.93 + 0.8 + 0.9
              = 13.63
→ Capped at 7.5

actual_cost = max(0.22, 0.1 × 2.2 × 7.5) = max(0.22, 1.65) = 1.65 STRK
```

### Example 3: Medium prompt on PREMIUM tier

```
Input tokens:  500
Output tokens: 400
GPU seconds:   8
Model:         llama3.1:70b (70b class → complexity 0.8)

actual_effort = (500/100)*0.3 + (400/256)*0.5 + 0.8 + (8/10)*0.2
              = 1.5 + 0.78 + 0.8 + 0.16
              = 3.24

actual_cost = max(0.35, 0.1 × 3.5 × 3.24) = max(0.35, 1.134) = 1.134 STRK
```

## Module Structure

```
pricing/
├── __init__.py
├── interfaces.py      # ICostEstimator, IEffortCalculator (ABCs)
├── models.py           # EffortMetrics, CostEstimate, CostBreakdown, SettlementCost
├── constants.py        # All weights, base rates, model complexity map, caps
├── estimator.py        # CostEstimator — pre-inference max cost calculation
└── calculator.py       # EffortCalculator — post-inference actual cost calculation
```

## Class Interfaces

```python
class ICostEstimator(ABC):
    """Pre-inference cost estimation."""

    @abstractmethod
    def estimate_max_cost(
        self,
        input_tokens: int,
        model_id: str,
        tier: NodeTier,
        max_output_tokens: int = 512,
    ) -> CostEstimate: ...

class IEffortCalculator(ABC):
    """Post-inference actual cost calculation."""

    @abstractmethod
    def calculate_actual_cost(
        self,
        metrics: EffortMetrics,
        tier: NodeTier,
    ) -> CostBreakdown: ...
```

## Data Flow

```
                    PRE-INFERENCE                          POST-INFERENCE
                    ─────────────                          ──────────────
User prompt ──→ CostEstimator.estimate_max_cost()    Node metrics ──→ EffortCalculator.calculate_actual_cost()
                     │                                                      │
                     ▼                                                      ▼
              CostEstimate {                                        CostBreakdown {
                estimated_max: 2.145 STRK                             actual_cost: 1.65 STRK
                base_rate: 0.1 STRK                                   provider_payout: 1.452 STRK (88%)
                tier_multiplier: 2.2                                  treasury_fee: 0.198 STRK (12%)
                effort_estimate: 7.5 (capped)                         refund_to_user: 0.495 STRK
                safety_margin: 1.3                                    effort_score: 7.5 (capped)
              }                                                       min_reward_applied: false
                     │                                                }
                     ▼
              User escrows 2.145 STRK on-chain
```

## Dependencies

- `relayer/models/schemas.py` — imports `EffortMetrics` model
- `relayer/core/scheduler.py` — calls `CostEstimator` before task scheduling
- `relayer/core/aggregator.py` — calls `EffortCalculator` before settlement
- `contracts/src/smainer.cairo` — receives `actual_cost` in `settle_with_effort()`

## Future: ZK Proof Integration (V2)

In V2, effort metrics will be verifiable via zero-knowledge proofs:
- Node generates ZK proof of inference execution (token counts, GPU time)
- Proof is submitted alongside result signature
- Contract verifies ZK proof before releasing funds
- Eliminates trust in self-reported metrics

See [10-zk-effort-verification.md](10-zk-effort-verification.md) for the ZK roadmap.
