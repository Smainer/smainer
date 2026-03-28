# Settlement System

> Module: `backend/relayer/src/relayer/settlement/`
> Owner Agent: `fee-economist` + `starknet-engineer`
> Status: Planned

## Purpose

Post-inference settlement that calculates actual cost from effort metrics, determines the fee split, and triggers on-chain settlement with automatic refund of excess escrow to the user.

## Design Principles

1. **Trustless**: Settlement amounts are enforced on-chain, not off-chain
2. **Fair to users**: Treasury takes 12% of actual cost, not escrowed ceiling
3. **Fair to providers**: Minimum reward floor (0.01 STRK) ensures every task is worth executing
4. **Atomic**: Provider payout + treasury fee + user refund all succeed or all revert

## Module Structure

```
settlement/
├── __init__.py
├── interfaces.py       # ISettlementManager, IRefundCalculator (ABCs)
├── models.py           # SettlementRecord, RefundRecord, FeeBreakdown
├── settler.py          # SettlementManager — orchestrates end-to-end settlement
└── refund.py           # RefundCalculator — compute refund amounts
```

## Settlement Pipeline

```
Task completed by node
         │
         ▼
┌─────────────────────────────────────────┐
│  1. EffortCalculator.calculate_actual() │
│     Input: EffortMetrics from node      │
│     Output: CostBreakdown               │
│       actual_cost: 0.42 STRK            │
│       effort_score: 3.24                │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  2. RefundCalculator.compute()          │
│     Input: escrowed=1.00, actual=0.42   │
│     Output: RefundRecord                │
│       refund_to_user: 0.58 STRK         │
│       provider_payout: 0.3696 STRK (88%)│
│       treasury_fee: 0.0504 STRK (12%)  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  3. SettlementManager.settle()          │
│     Calls: contract.settle_with_effort()│
│     Args: task_id, provider, result_hash│
│           actual_cost, effort_score,    │
│           signature_r, signature_s      │
│     On-chain: 3 transfers (atomic)      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  4. Emit events + update Redis state    │
│     EffortSettlement event on-chain     │
│     Redis: task status → "settled"      │
│     Callback to bot: result + refund    │
└─────────────────────────────────────────┘
```

## Class Design

```python
class ISettlementManager(ABC):
    @abstractmethod
    async def settle_task(
        self,
        task_id: str,
        on_chain_task_id: int,
        provider_address: str,
        result_hash: str,
        effort_metrics: EffortMetrics,
        signature_r: str,
        signature_s: str,
        tier: NodeTier,
    ) -> SettlementRecord: ...


class IRefundCalculator(ABC):
    @abstractmethod
    def compute_refund(
        self,
        escrowed_amount: int,
        actual_cost: int,
    ) -> RefundRecord: ...


@dataclass(frozen=True)
class FeeBreakdown:
    actual_cost: int            # Effort-based actual cost (wei)
    provider_payout: int        # 88% of actual_cost
    treasury_fee: int           # 12% of actual_cost
    gas_subsidy: int            # 3% (included in provider_payout)
    provider_base: int          # 85% (before gas subsidy)

@dataclass(frozen=True)
class RefundRecord:
    escrowed_amount: int
    actual_cost: int
    refund_amount: int          # escrowed - actual
    fee_breakdown: FeeBreakdown

@dataclass(frozen=True)
class SettlementRecord:
    task_id: str
    on_chain_task_id: int
    tx_hash: str                # Starknet transaction hash
    refund: RefundRecord
    effort_score: float         # The effort multiplier used
    settled_at: datetime
    status: str                 # "settled" | "failed"
    error: str | None
```

## SettlementManager Implementation

```python
class SettlementManager(ISettlementManager):
    def __init__(
        self,
        chain_client: StarknetClient,
        effort_calculator: IEffortCalculator,
        refund_calculator: IRefundCalculator,
        redis: Redis,
    ):
        self._chain = chain_client
        self._effort = effort_calculator
        self._refund = refund_calculator
        self._redis = redis

    async def settle_task(
        self,
        task_id: str,
        on_chain_task_id: int,
        provider_address: str,
        result_hash: str,
        effort_metrics: EffortMetrics,
        signature_r: str,
        signature_s: str,
        tier: NodeTier,
    ) -> SettlementRecord:
        # 1. Calculate actual cost from effort metrics
        cost = self._effort.calculate_actual_cost(effort_metrics, tier)

        # 2. Read escrowed amount from Redis (cached from verification step)
        escrowed = int(
            await self._redis.hget(f"task:{task_id}", "adjusted_reward")
        )

        # 3. Compute refund
        refund = self._refund.compute_refund(escrowed, cost.actual_cost_wei)

        # 4. Submit on-chain settlement
        try:
            tx_hash = await self._chain.settle_with_effort(
                task_id=on_chain_task_id,
                provider=provider_address,
                result_hash=result_hash,
                actual_cost=cost.actual_cost_wei,
                effort_score=int(cost.effort_score * 10000),  # Convert to BPS
                signature_r=signature_r,
                signature_s=signature_s,
            )
        except StarknetError as e:
            return SettlementRecord(
                task_id=task_id,
                on_chain_task_id=on_chain_task_id,
                tx_hash="",
                refund=refund,
                effort_score=cost.effort_score,
                settled_at=datetime.utcnow(),
                status="failed",
                error=str(e),
            )

        # 5. Update Redis
        await self._redis.hset(f"task:{task_id}", mapping={
            "status": "settled",
            "settlement_tx": tx_hash,
            "actual_cost": str(cost.actual_cost_wei),
            "effort_score": str(cost.effort_score),
            "refund_amount": str(refund.refund_amount),
        })

        return SettlementRecord(
            task_id=task_id,
            on_chain_task_id=on_chain_task_id,
            tx_hash=tx_hash,
            refund=refund,
            effort_score=cost.effort_score,
            settled_at=datetime.utcnow(),
            status="settled",
            error=None,
        )
```

## RefundCalculator

```python
class RefundCalculator(IRefundCalculator):
    def compute_refund(
        self,
        escrowed_amount: int,
        actual_cost: int,
    ) -> RefundRecord:
        # Clamp actual_cost to valid range
        actual = max(MIN_REWARD_WEI, min(actual_cost, escrowed_amount))

        # Fee split on actual cost
        treasury_fee = (actual * TREASURY_FEE_BPS) // BPS_DENOMINATOR
        gas_subsidy = (actual * GAS_SUBSIDY_BPS) // BPS_DENOMINATOR
        provider_base = actual - treasury_fee - gas_subsidy
        provider_payout = provider_base + gas_subsidy

        refund = escrowed_amount - actual

        return RefundRecord(
            escrowed_amount=escrowed_amount,
            actual_cost=actual,
            refund_amount=refund,
            fee_breakdown=FeeBreakdown(
                actual_cost=actual,
                provider_payout=provider_payout,
                treasury_fee=treasury_fee,
                gas_subsidy=gas_subsidy,
                provider_base=provider_base,
            ),
        )
```

## Fallback: No Effort Metrics

When a node running an old version reports no effort metrics:

```python
if effort_metrics is None:
    # Fallback to existing submit_proof_and_claim (flat settlement)
    tx_hash = await self._chain.submit_proof_and_claim(
        task_id=on_chain_task_id,
        provider=provider_address,
        result_hash=result_hash,
        signature_r=signature_r,
        signature_s=signature_s,
    )
    # Full escrow paid out — no refund
```

## Integration in Aggregator

The aggregator calls `SettlementManager` instead of directly calling `chain_client`:

```python
# In aggregator.py — process_batch()

for result in batch_results:
    if result.effort_metrics:
        record = await self._settlement_mgr.settle_task(
            task_id=result.task_id,
            on_chain_task_id=result.on_chain_task_id,
            provider_address=result.provider_address,
            result_hash=result.result_hash,
            effort_metrics=result.effort_metrics,
            signature_r=result.signature_r,
            signature_s=result.signature_s,
            tier=result.tier,
        )
    else:
        # Legacy flat settlement
        await self._chain.submit_proof_and_claim(...)
```

## Monitoring

New Prometheus metrics:
- `settlement_actual_cost_strk` — histogram of actual costs per tier
- `settlement_refund_strk` — histogram of refund amounts
- `settlement_effort_score` — histogram of effort scores
- `settlement_duration_seconds` — time to complete on-chain settlement
- `settlement_errors_total` — counter of failed settlements by error type
