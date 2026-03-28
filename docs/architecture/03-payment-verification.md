# Payment Verification Module

> Module: `backend/relayer/src/relayer/verification/`
> Owner Agent: `relayer-architect`
> Status: Planned

## Purpose

Verify that on-chain escrow payment exists and is valid **before** scheduling a task to a compute node. Prevents free compute — no valid escrow, no execution.

## Current Problem

The relayer currently:
1. Receives `on_chain_task_id` from the bot
2. **Trusts** that the MiniApp already created the escrow
3. Schedules inference immediately
4. Never queries the contract to confirm

This means a malicious client could submit a fake `on_chain_task_id` and get free compute.

## Design

### Verification Flow (Blocking)

```
Bot submits task with on_chain_task_id
         │
         ▼
┌─────────────────────────────────┐
│  PaymentVerifier.verify_escrow()│
│                                 │
│  1. RPC call: get_task(task_id) │
│  2. Check status == CREATED     │
│  3. Check amount >= minimum     │
│  4. Check creator matches user  │
│  5. Check token == STRK         │
└─────────────────────────────────┘
         │
    ┌────┴────┐
    │         │
  PASS      FAIL
    │         │
    ▼         ▼
 Schedule   Reject task
 to node    Return error
```

### Contract Change Required

The smart contract needs a new **view function** to expose task data:

```cairo
#[external(v0)]
fn get_task(self: @ContractState, task_id: u256) -> Task {
    let task = self.tasks.entry(task_id).read();
    assert(task.creator != contract_address_const::<0>(), 'Task does not exist');
    task
}
```

## Module Structure

```
verification/
├── __init__.py
├── interfaces.py       # IPaymentVerifier (ABC)
├── models.py           # VerificationResult, EscrowState
└── verifier.py         # PaymentVerifier implementation
```

## Class Design

```python
class IPaymentVerifier(ABC):
    """Verify on-chain escrow before task execution."""

    @abstractmethod
    async def verify_escrow(
        self,
        on_chain_task_id: int,
        expected_creator: str,
        minimum_amount: int,
    ) -> VerificationResult: ...


@dataclass(frozen=True)
class VerificationResult:
    verified: bool
    escrowed_amount: int        # Amount held in contract
    creator: str                # On-chain task creator address
    status: str                 # "created" | "assigned" | "completed" | "cancelled"
    required_tier: int          # Tier encoded in task
    task_hash: str              # Prompt hash for integrity check
    rejection_reason: str | None  # Human-readable if not verified


@dataclass(frozen=True)
class EscrowState:
    task_id: int
    creator: str
    token_address: str
    amount: int
    base_reward: int
    tier_multiplier: int
    adjusted_reward: int
    required_tier: int
    task_hash: str
    status: int                 # 0=CREATED, 1=ASSIGNED, 2=COMPLETED, 3=CANCELLED


class PaymentVerifier(IPaymentVerifier):
    """Verify on-chain escrow via Starknet RPC."""

    def __init__(
        self,
        rpc_url: str,
        contract_address: str,
        strk_token_address: str,
    ):
        self._provider = RpcProvider(rpc_url)
        self._contract_address = contract_address
        self._strk_token = strk_token_address

    async def verify_escrow(
        self,
        on_chain_task_id: int,
        expected_creator: str,
        minimum_amount: int,
    ) -> VerificationResult:
        """Query contract get_task() and validate escrow state."""

        try:
            escrow = await self._read_task(on_chain_task_id)
        except ContractError:
            return VerificationResult(
                verified=False,
                rejection_reason=f"Task {on_chain_task_id} does not exist on-chain",
                ...
            )

        # Validate escrow state
        if escrow.status != TASK_CREATED:
            return VerificationResult(
                verified=False,
                rejection_reason=f"Task status is {escrow.status}, expected CREATED",
                ...
            )

        if escrow.amount < minimum_amount:
            return VerificationResult(
                verified=False,
                rejection_reason=f"Escrowed {escrow.amount} < minimum {minimum_amount}",
                ...
            )

        # Normalize addresses for comparison
        if self._normalize(escrow.creator) != self._normalize(expected_creator):
            return VerificationResult(
                verified=False,
                rejection_reason="Creator address mismatch",
                ...
            )

        return VerificationResult(
            verified=True,
            escrowed_amount=escrow.amount,
            creator=escrow.creator,
            status="created",
            required_tier=escrow.required_tier,
            task_hash=escrow.task_hash,
            rejection_reason=None,
        )

    async def _read_task(self, task_id: int) -> EscrowState:
        """Raw RPC call to get_task view function."""
        # Split task_id into u256 (low, high) for calldata
        low = task_id & ((1 << 128) - 1)
        high = task_id >> 128

        result = await self._provider.call_contract(
            contract_address=self._contract_address,
            entry_point_selector="get_task",
            calldata=[low, high],
            block_id="latest",
        )

        return self._parse_task_result(result)
```

## Integration in Scheduler

```python
# In scheduler.py — submit_task()

async def submit_task(self, submission: TaskSubmission) -> str:
    # ... existing task_id generation ...

    # NEW: Verify on-chain escrow before scheduling
    if submission.on_chain_task_id is not None:
        verification = await self._payment_verifier.verify_escrow(
            on_chain_task_id=submission.on_chain_task_id,
            expected_creator=submission.payload.get("starknet_address", ""),
            minimum_amount=submission.token_amount,
        )

        if not verification.verified:
            logger.warning(
                "Payment verification failed for task %s: %s",
                submission.on_chain_task_id,
                verification.rejection_reason,
            )
            raise PaymentVerificationError(verification.rejection_reason)
    else:
        # No on_chain_task_id = reject (all tasks must be paid)
        raise PaymentVerificationError("Missing on_chain_task_id — payment required")

    # ... proceed with scheduling ...
```

## Caching & Performance

- Cache `VerificationResult` in Redis for 60 seconds (task status won't change that fast)
- Key: `escrow_verified:{on_chain_task_id}`
- Prevents redundant RPC calls for retries
- Cache is invalidated when task status changes

## Error Handling

| Scenario | Behavior |
|----------|----------|
| RPC timeout | Retry once, then reject with "verification_timeout" |
| Task doesn't exist | Reject immediately |
| Task already completed | Reject — cannot double-spend |
| Task cancelled | Reject — funds already refunded |
| Amount too low | Reject — user must create new task with correct amount |
| RPC node down | Reject with "rpc_unavailable" — fail safe, not fail open |

## Security Considerations

- **Fail closed**: If verification cannot be performed, task is NOT scheduled
- **Address normalization**: Compare addresses in canonical 64-hex format
- **No bypass flag**: There is no way to skip verification, even in development
- **Replay protection**: Each `on_chain_task_id` can only be used once per relayer task
