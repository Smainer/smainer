# Smainer Effort-Based Pricing System — Architecture Overview

> Last updated: 2026-03-28

## What This Is

A complete redesign of Smainer's payment system from flat per-tier pricing to dynamic effort-based pricing. Users pay for actual compute consumed; providers earn for actual work delivered; excess escrow is refunded on-chain automatically.

## Decision Log

| # | Decision | Choice |
|---|----------|--------|
| 1 | Effort multiplier cap | 7.5x base |
| 2 | Minimum cost | Base rate floor (provider always earns minimum) |
| 3 | Refund mechanism | On-chain refund to user wallet (trustless) |
| 4 | Effort metrics V1 | Self-reported by node + signed |
| 5 | Effort metrics V2 | ZK proof roadmap (optimistic → TEE → ZK) |
| 6 | Payment verification | Blocking (no free compute) |
| 7 | Contract view function | `get_task()` added for verification |
| 8 | Settlement model | On-chain via `settle_with_effort()` |
| 9 | Effort attestation | Both: node signs metrics, relayer attests score |
| 10 | MIN_REWARD floor | 0.01 STRK |
| 11 | Treasury fee basis | 12% of actual cost (fair to users) |

## System Documents

| # | Document | Module | Owner |
|---|----------|--------|-------|
| 01 | [Effort Pricing](01-effort-pricing.md) | `relayer/pricing/` | fee-economist |
| 02 | [Provider Metrics](02-provider-metrics.md) | `provider/metrics/` | systems-engineer |
| 03 | [Payment Verification](03-payment-verification.md) | `relayer/verification/` | relayer-architect |
| 04 | [Smart Contract Upgrades](04-smart-contract-upgrades.md) | `contracts/src/` | starknet-engineer |
| 05 | [Settlement System](05-settlement-system.md) | `relayer/settlement/` | fee-economist |
| 06 | [MiniApp Cost Estimation](06-miniapp-cost-estimation.md) | `miniapp/src/` | frontend-engineer |
| 07 | [Integration Wiring](07-integration-wiring.md) | Cross-cutting | relayer-architect |
| 08 | [ZK Effort Verification](08-zk-effort-verification.md) | Future (V2/V3) | starknet-engineer |
| 09 | [Security Review](09-security-review.md) | Cross-cutting | security-expert |
| 10 | [Trust Assumption](10-trust-assumption.md) | `contracts/src/smainer_staking.cairo` + `relayer/verifier/` | starknet-engineer + relayer-architect |

## Implementation Order

```
Phase 1 ─── pricing/models.py + constants.py + interfaces.py
  │
Phase 2 ─── provider/metrics/ (token_counter, gpu_tracker, collector)
  │
Phase 3 ─── pricing/estimator.py + calculator.py
  │
Phase 4 ─── verification/verifier.py
  │
Phase 5 ─── Contract: get_task() view + settle_with_effort()
  │
Phase 6 ─── settlement/settler.py + refund.py
  │
Phase 7 ─── MiniApp: useCostEstimate hook + PaymentFlow UI
  │
Phase 8 ─── Integration wiring (scheduler, aggregator, routes, websocket)
  │
Phase 9 ─── E2E tests + benchmarks
  │
Phase 10 ── Security review + ZK roadmap formalization
```

## Agent Orchestration

```
fee-economist ──────────── Phases 1, 3, 6
systems-engineer ───────── Phase 2
relayer-architect ──────── Phases 4, 7 (wiring), 8
starknet-engineer ──────── Phase 5
frontend-engineer ──────── Phase 7
ai-inference-benchmarker ─ Phase 9
security-expert ────────── Phase 10
```

## Payment Flow: Before vs After

### BEFORE (flat pricing)

```
User prompt → Bot shows button → MiniApp escrows 0.1 STRK (flat)
→ Node runs inference → Relayer settles full 0.1 STRK on-chain
→ Provider: 0.088 STRK | Treasury: 0.012 STRK | Refund: 0
```

### AFTER (effort-based)

```
User prompt → Bot shows button → MiniApp estimates ~0.42 STRK, escrows 0.55 STRK (with margin)
→ Relayer verifies escrow on-chain (blocking)
→ Node runs inference, reports: 500 input tokens, 400 output, 8s GPU
→ Relayer calculates actual: 0.39 STRK (effort 3.24x, capped at 7.5x)
→ Contract settles: Provider 0.343 STRK (88%) | Treasury 0.047 STRK (12%) | Refund 0.16 STRK → user
```

## Key Constants

```
BASE_PROMPT_COST    = 0.1 STRK (100_000_000_000_000_000 wei)
MIN_REWARD          = 0.01 STRK (10_000_000_000_000_000 wei)
MAX_EFFORT_MULT     = 7.5x
SAFETY_MARGIN       = 1.3x (30% buffer for estimation)
TREASURY_FEE        = 12% of actual cost
GAS_SUBSIDY         = 3% of actual cost (part of provider payout)
PROVIDER_PAYOUT     = 88% of actual cost (85% base + 3% gas subsidy)

Tier Multipliers:
  BASIC   = 1.0x
  PRO     = 2.2x
  PREMIUM = 3.5x

Effort Weights:
  INPUT_WEIGHT    = 0.3
  OUTPUT_WEIGHT   = 0.5
  GPU_TIME_WEIGHT = 0.2
  BASE_INPUT      = 100 tokens
  BASE_OUTPUT     = 256 tokens
  BASE_GPU_SECS   = 10.0 seconds
```

## Repository Structure (new modules)

```
backend/relayer/src/relayer/
├── pricing/                    # NEW
│   ├── __init__.py
│   ├── interfaces.py
│   ├── models.py
│   ├── constants.py
│   ├── estimator.py
│   └── calculator.py
├── verification/               # NEW
│   ├── __init__.py
│   ├── interfaces.py
│   ├── models.py
│   └── verifier.py
├── settlement/                 # NEW
│   ├── __init__.py
│   ├── interfaces.py
│   ├── models.py
│   ├── settler.py
│   └── refund.py
├── verifier/                   # NEW (V2)
│   ├── __init__.py
│   ├── spot_check.py
│   ├── rerun.py
│   └── slash_orchestrator.py
├── core/                       # MODIFIED
│   ├── scheduler.py            # + verification + cost estimation
│   └── aggregator.py           # + settlement manager
├── api/                        # MODIFIED
│   ├── routes.py               # + payment verification gate
│   └── websocket.py            # + effort metrics handling
└── chain/                      # MODIFIED
    └── client.py               # + settle_with_effort()

backend/provider/src/provider/
├── metrics/                    # NEW
│   ├── __init__.py
│   ├── models.py
│   ├── token_counter.py
│   ├── gpu_tracker.py
│   └── collector.py
├── enhanced_executor.py        # MODIFIED (+ metrics collection)
└── enhanced_api_client.py      # MODIFIED (+ effort_metrics in events)

contracts/src/
├── smainer.cairo               # MODIFIED (+ get_task, settle_with_effort)
├── smainer_staking.cairo       # NEW (V2 — provider staking, slashing, appeals)
├── interfaces.cairo            # MODIFIED (+ new function signatures)
└── pricing.cairo               # NEW (on-chain effort validation helpers)

telegram/miniapp/src/
├── hooks/
│   ├── useCostEstimate.ts      # NEW
│   └── useSmainerContract.ts   # MODIFIED (dynamic escrow amount)
├── components/
│   └── PaymentFlow.tsx         # MODIFIED (cost breakdown UI)
└── lib/
    └── starknet.ts             # MODIFIED (+ MODEL_COMPLEXITY, estimateTokenCount)
```
