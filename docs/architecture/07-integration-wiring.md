# Integration Wiring

> Module: Cross-cutting integration across scheduler, aggregator, and WebSocket handler
> Owner Agent: `relayer-architect`
> Status: Planned

## Purpose

Wire the new pricing, verification, and settlement modules into the existing relayer pipeline. This document maps every integration point where existing code must call into new modules.

## Integration Map

```
┌──────────────────────────────────────────────────────────────────────┐
│                        RELAYER PIPELINE                              │
│                                                                      │
│  ┌─────────┐    ┌────────────┐    ┌──────────┐    ┌──────────────┐  │
│  │  API     │───▶│ Verification│───▶│Scheduler │───▶│  Node Pool   │  │
│  │ Routes   │    │  Module    │    │          │    │  (WebSocket) │  │
│  └─────────┘    └────────────┘    └──────────┘    └──────────────┘  │
│       │              NEW              │                   │          │
│       │                               │                   │          │
│       │                               │                   ▼          │
│       │                               │           ┌──────────────┐  │
│       │                               │           │ Compute Node │  │
│       │                               │           │ (WebSocket)  │  │
│       │                               │           └──────┬───────┘  │
│       │                               │                  │          │
│       │                               ▼                  │          │
│       │                        ┌──────────────┐          │          │
│       │                        │  Aggregator  │◀─────────┘          │
│       │                        │              │   TaskCompletedEvent│
│       │                        └──────┬───────┘   + EffortMetrics  │
│       │                               │                             │
│       │                               ▼                             │
│       │                        ┌──────────────┐                     │
│       │                        │  Settlement  │                     │
│       │                        │   Manager    │                     │
│       │                        │     NEW      │                     │
│       │                        └──────┬───────┘                     │
│       │                               │                             │
│       │                               ▼                             │
│       │                        ┌──────────────┐                     │
│       │                        │   Starknet   │                     │
│       │                        │    Client    │                     │
│       │                        │ (chain/)     │                     │
│       │                        └──────────────┘                     │
│       │                                                             │
│       ▼                                                             │
│  ┌──────────────┐                                                   │
│  │  Callback to  │ ← Settlement result + refund info               │
│  │  Bot          │                                                   │
│  └──────────────┘                                                   │
└──────────────────────────────────────────────────────────────────────┘
```

## Integration Point 1: API Routes → Verification

**File**: `backend/relayer/src/relayer/api/routes.py`
**Function**: `POST /api/v1/tasks`

```python
# BEFORE:
@router.post("/tasks")
async def submit_task(submission: TaskSubmission):
    task_id = await scheduler.submit_task(submission)
    return {"task_id": task_id}

# AFTER:
@router.post("/tasks")
async def submit_task(submission: TaskSubmission):
    # NEW: Verify payment before scheduling
    if submission.on_chain_task_id is None:
        raise HTTPException(400, "on_chain_task_id required — payment must be made first")

    verification = await payment_verifier.verify_escrow(
        on_chain_task_id=submission.on_chain_task_id,
        expected_creator=submission.payload.get("starknet_address", ""),
        minimum_amount=submission.token_amount,
    )

    if not verification.verified:
        raise HTTPException(402, f"Payment verification failed: {verification.rejection_reason}")

    task_id = await scheduler.submit_task(submission, verified_escrow=verification)
    return {"task_id": task_id}
```

## Integration Point 2: Scheduler → Cost Estimator

**File**: `backend/relayer/src/relayer/core/scheduler.py`
**Function**: `submit_task()`

```python
# NEW: Store estimated effort alongside task data
async def submit_task(
    self,
    submission: TaskSubmission,
    verified_escrow: VerificationResult | None = None,
) -> str:
    # ... existing task_id generation ...

    # NEW: Calculate expected effort for the submitted prompt
    prompt = submission.payload.get("prompt", "")
    model_id = submission.payload.get("model", "llama3.1:8b")

    estimated = cost_estimator.estimate_max_cost(
        input_tokens=len(prompt) // 4,  # rough char-to-token
        model_id=model_id,
        tier=required_tier,
    )

    task_data = {
        # ... existing fields ...
        "estimated_effort": str(estimated.estimated_effort),      # NEW
        "estimated_max_cost": str(estimated.max_escrow_wei),      # NEW
        "verified_escrow_amount": str(verified_escrow.escrowed_amount) if verified_escrow else "",  # NEW
    }
```

## Integration Point 3: WebSocket Handler → EffortMetrics

**File**: `backend/relayer/src/relayer/api/websocket.py`
**Function**: Handle `task_completed` event

```python
# BEFORE:
async def _handle_task_completed(self, event: TaskCompletedEvent):
    await scheduler.complete_task(
        event.task_id, event.result_data, event.execution_time
    )

# AFTER:
async def _handle_task_completed(self, event: TaskCompletedEvent):
    await scheduler.complete_task(
        task_id=event.task_id,
        result_data=event.result_data,
        execution_time=event.execution_time,
        effort_metrics=event.effort_metrics,  # NEW: Optional[EffortMetrics]
    )
```

## Integration Point 4: Aggregator → Settlement Manager

**File**: `backend/relayer/src/relayer/core/aggregator.py`
**Function**: `process_batch()` / `submit_batch()`

```python
# BEFORE:
async def submit_batch(self, batch: List[Dict]):
    await chain_client.submit_batch_proof(batch)

# AFTER:
async def submit_batch(self, batch: List[Dict]):
    for result in batch:
        effort_json = result.get("effort_metrics")

        if effort_json:
            effort_metrics = EffortMetrics(**json.loads(effort_json))
            record = await settlement_manager.settle_task(
                task_id=result["task_id"],
                on_chain_task_id=int(result["on_chain_task_id"]),
                provider_address=result["provider_address"],
                result_hash=result["result_hash"],
                effort_metrics=effort_metrics,
                signature_r=result["signature_r"],
                signature_s=result["signature_s"],
                tier=NodeTier(result["tier"]),
            )
            logger.info("Effort-settled task %s: actual=%s refund=%s",
                result["task_id"], record.refund.actual_cost, record.refund.refund_amount)
        else:
            # Legacy flat settlement
            await chain_client.submit_batch_proof({"results": [result]})
```

## Integration Point 5: Chain Client → settle_with_effort

**File**: `backend/relayer/src/relayer/chain/client.py`
**Function**: New `settle_with_effort()` method

```python
async def settle_with_effort(
    self,
    task_id: int,
    provider: str,
    result_hash: str,
    actual_cost: int,
    effort_score: int,        # BPS (e.g., 32400 = 3.24x)
    signature_r: str,
    signature_s: str,
) -> str:
    """Call contract settle_with_effort() and return tx hash."""

    task_id_low = task_id & ((1 << 128) - 1)
    task_id_high = task_id >> 128
    actual_cost_low = actual_cost & ((1 << 128) - 1)
    actual_cost_high = actual_cost >> 128
    effort_low = effort_score & ((1 << 128) - 1)
    effort_high = effort_score >> 128

    call = Call(
        to_addr=self.contract_address,
        selector=get_selector_from_name("settle_with_effort"),
        calldata=[
            task_id_low, task_id_high,
            int(provider, 16),
            int(result_hash, 16),
            actual_cost_low, actual_cost_high,
            effort_low, effort_high,
            int(signature_r, 16),
            int(signature_s, 16),
        ]
    )

    tx = await self.account.execute_v3(calls=[call], auto_estimate=True)
    await self.account.client.wait_for_tx(tx.transaction_hash)
    return hex(tx.transaction_hash)
```

## Integration Point 6: Bot Callback → Refund Info

**File**: `telegram/smainer-bot/api/callback/complete.py`
**Function**: Handle task completion callback

```python
# Add refund information to the user-facing message

# BEFORE:
text = f"Result:\n{result_text}"

# AFTER:
refund_amount = body.get("refund_amount")
actual_cost = body.get("actual_cost")

if refund_amount and int(refund_amount) > 0:
    refund_strk = format_strk(int(refund_amount))
    actual_strk = format_strk(int(actual_cost))
    text = f"Result:\n{result_text}\n\nPaid: {actual_strk} STRK | Refunded: {refund_strk} STRK"
else:
    text = f"Result:\n{result_text}"
```

## Dependency Injection

All new modules are instantiated in the relayer's startup and injected:

```python
# In main.py or app factory

# Pricing
cost_estimator = CostEstimator()
effort_calculator = EffortCalculator()

# Verification
payment_verifier = PaymentVerifier(
    rpc_url=settings.starknet_rpc_url,
    contract_address=settings.contract_address,
    strk_token_address=settings.strk_token_address,
)

# Settlement
refund_calculator = RefundCalculator()
settlement_manager = SettlementManager(
    chain_client=chain_client,
    effort_calculator=effort_calculator,
    refund_calculator=refund_calculator,
    redis=redis,
)

# Inject into scheduler
scheduler = TaskScheduler(
    redis=redis,
    node_pool=node_pool,
    cost_estimator=cost_estimator,
    payment_verifier=payment_verifier,
)

# Inject into aggregator
aggregator = ResultAggregator(
    redis=redis,
    settlement_manager=settlement_manager,
)
```

## Testing Strategy

1. **Unit tests**: Each module tested in isolation with mocked dependencies
2. **Integration tests**: Full pipeline with Redis + mocked Starknet RPC
3. **Contract tests**: Cairo tests for `settle_with_effort()` with various inputs
4. **E2E tests**: MiniApp → Bot → Relayer → Node → Settlement → Refund
