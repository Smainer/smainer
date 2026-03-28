# Smart Contract Upgrades

> Module: `contracts/src/smainer.cairo`
> Owner Agent: `starknet-engineer`
> Status: Planned

## Purpose

Upgrade the on-chain escrow contract to support:
1. **`get_task` view function** — expose task data for relayer verification
2. **`settle_with_effort` function** — variable settlement based on actual effort
3. **`pricing.cairo` helpers** — on-chain effort validation and bounds checking

## Current Contract State

- **Address**: `0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe`
- **Framework**: Cairo 2024_07, Starknet v2.16.0, OpenZeppelin v0.20.0
- **Upgradeable**: Yes (via `upgrade(new_class_hash)`)
- **Current settlement**: `submit_proof_and_claim()` — pays full escrow with fixed 12%/3%/85% split

## Change 1: `get_task` View Function

```cairo
/// Read-only function to expose task data for off-chain verification.
/// Used by the relayer to confirm escrow exists before scheduling compute.
#[external(v0)]
fn get_task(self: @ContractState, task_id: u256) -> Task {
    let task = self.tasks.entry(task_id).read();
    assert(
        task.creator != contract_address_const::<0>(),
        'Task does not exist'
    );
    task
}
```

**Why**: The relayer needs to verify escrow state before scheduling. Currently task data is write-only — it goes in but can never be read externally.

## Change 2: `settle_with_effort` Function

This is the core change. Instead of paying the full escrowed amount, the relayer submits the actual effort-based cost and the contract settles accordingly.

```cairo
/// Settle a task with effort-based pricing.
/// Pays provider based on actual_cost (not full escrow).
/// Refunds excess to task creator.
///
/// Only callable by authorized relayer.
/// actual_cost must be >= MIN_REWARD and <= escrowed amount.
///
/// Fee split applied to actual_cost (not escrowed amount):
///   - Provider: 88% of actual_cost
///   - Treasury: 12% of actual_cost
///   - Refund:   escrowed - actual_cost → back to creator
#[external(v0)]
fn settle_with_effort(
    ref self: ContractState,
    task_id: u256,
    provider: ContractAddress,
    result_hash: felt252,
    actual_cost: u256,           // NEW: effort-based actual cost
    effort_score: u256,          // NEW: effort multiplier × 10000 (BPS)
    signature_r: felt252,
    signature_s: felt252,
) {
    // --- CHECKS ---

    // 1. Caller is authorized relayer
    let caller = get_caller_address();
    let relayer = self.authorized_relayer.read();
    assert(caller == relayer, 'Only relayer can settle');

    // 2. Task exists and is in valid state
    let task = self.tasks.entry(task_id).read();
    assert(
        task.status == TASK_CREATED || task.status == TASK_ASSIGNED,
        'Invalid task status'
    );

    // 3. Actual cost bounds
    assert(actual_cost >= self.min_reward.read(), 'Below minimum reward');
    assert(actual_cost <= task.amount, 'Exceeds escrowed amount');

    // 4. Effort score bounds (max 7.5x = 75000 BPS)
    assert(effort_score <= 75000, 'Effort score exceeds cap');

    // 5. Provider is active
    let node_status = self.node_status.entry(provider).read();
    assert(node_status == NODE_ACTIVE, 'Provider not active');

    // 6. Signature verification (same as submit_proof_and_claim)
    let provider_key = self.provider_public_keys.entry(provider).read();
    assert(provider_key != 0, 'Provider has no public key');

    // Verify signature hasn't been used (replay protection)
    let sig_used = self.used_signatures.entry((signature_r, signature_s)).read();
    assert(!sig_used, 'Signature already used');

    // Message hash includes effort data:
    // hash = Pedersen(Pedersen(Pedersen(task_id, provider), result_hash), actual_cost)
    let h1 = PedersenTrait::new(0).update(task_id.try_into().unwrap()).update(provider.into()).finalize();
    let h2 = PedersenTrait::new(0).update(h1).update(result_hash).finalize();
    let message_hash = PedersenTrait::new(0).update(h2).update(actual_cost.try_into().unwrap()).finalize();

    check_ecdsa_signature(message_hash, provider_key, signature_r, signature_s);

    // --- EFFECTS ---

    // Mark signature as used
    self.used_signatures.entry((signature_r, signature_s)).write(true);

    // Update task
    self.tasks.entry(task_id).status.write(TASK_COMPLETED);
    self.tasks.entry(task_id).assigned_provider.write(provider);

    // --- INTERACTIONS (CEI pattern) ---

    let erc20 = IERC20Dispatcher { contract_address: task.token_address };

    // Calculate fee split on ACTUAL cost (not escrowed)
    let treasury_fee = (actual_cost * TREASURY_FEE_BPS) / BPS_DENOMINATOR;   // 12%
    let gas_subsidy = (actual_cost * GAS_SUBSIDY_BPS) / BPS_DENOMINATOR;     // 3%
    let provider_payout = actual_cost - treasury_fee - gas_subsidy;           // 85%
    let provider_total = provider_payout + gas_subsidy;                       // 88%

    // Refund excess to creator
    let refund_amount = task.amount - actual_cost;

    // Transfer to provider (88% of actual)
    let success_provider = erc20.transfer(provider, provider_total);
    assert(success_provider, 'Provider transfer failed');

    // Transfer to treasury (12% of actual)
    let treasury = self.treasury_address.read();
    let success_treasury = erc20.transfer(treasury, treasury_fee);
    assert(success_treasury, 'Treasury transfer failed');

    // Refund excess to creator
    if refund_amount > 0 {
        let success_refund = erc20.transfer(task.creator, refund_amount);
        assert(success_refund, 'Refund transfer failed');
    }

    // --- EVENTS ---

    self.emit(TaskCompleted {
        task_id,
        provider,
        result_hash,
    });

    self.emit(EffortSettlement {
        task_id,
        escrowed_amount: task.amount,
        actual_cost,
        effort_score,
        provider_payout: provider_total,
        treasury_fee,
        refund_amount,
    });
}
```

## Change 3: New Storage Variables

```cairo
// Minimum reward floor (in token wei)
min_reward: u256,                           // Set to 0.01 STRK = 10_000_000_000_000_000

// Maximum effort score in BPS (7.5x = 75000)
max_effort_score_bps: u256,
```

## Change 4: New Events

```cairo
#[derive(Drop, starknet::Event)]
struct EffortSettlement {
    #[key]
    task_id: u256,
    escrowed_amount: u256,
    actual_cost: u256,
    effort_score: u256,                     // BPS (e.g., 75000 = 7.5x)
    provider_payout: u256,                  // 88% of actual_cost
    treasury_fee: u256,                     // 12% of actual_cost
    refund_amount: u256,                    // escrowed - actual
}

#[derive(Drop, starknet::Event)]
struct RefundIssued {
    #[key]
    task_id: u256,
    #[key]
    creator: ContractAddress,
    amount: u256,
    token_address: ContractAddress,
}
```

## Change 5: Admin Functions

```cairo
/// Set minimum reward floor (owner only)
fn set_min_reward(ref self: ContractState, min_reward: u256) {
    self.ownable.assert_only_owner();
    self.min_reward.write(min_reward);
}

/// Set maximum effort score in BPS (owner only)
fn set_max_effort_score(ref self: ContractState, max_score_bps: u256) {
    self.ownable.assert_only_owner();
    assert(max_score_bps >= BPS_DENOMINATOR, 'Must be >= 1.0x');
    assert(max_score_bps <= 100000, 'Must be <= 10.0x');
    self.max_effort_score_bps.write(max_score_bps);
}
```

## Backward Compatibility

- `submit_proof_and_claim()` remains unchanged — flat-price settlement still works
- `settle_with_effort()` is a new function — no existing behavior modified
- Relayer chooses which settlement function to call based on whether effort metrics are available
- Upgrade via `upgrade(new_class_hash)` — no state migration needed (new storage slots default to zero)

## Constructor Updates

```cairo
fn constructor(ref self: ContractState, owner: ContractAddress) {
    // ... existing init ...

    // NEW: Effort pricing defaults
    self.min_reward.write(10_000_000_000_000_000);   // 0.01 STRK
    self.max_effort_score_bps.write(75000);           // 7.5x cap
}
```

## Security Considerations

- **actual_cost bounds**: Must be >= min_reward AND <= escrowed amount
- **effort_score bounds**: Must be <= max_effort_score_bps (7.5x)
- **Signature covers actual_cost**: Provider signs the cost, preventing relayer from inflating/deflating
- **Atomic transfers**: All three transfers (provider, treasury, refund) must succeed or all revert
- **CEI pattern**: Checks-Effects-Interactions ordering prevents reentrancy

## Test Cases Required

1. Basic effort settlement with refund
2. Settlement at minimum reward floor
3. Settlement at full escrow (no refund)
4. Settlement with effort_score at cap (7.5x)
5. Reject: actual_cost > escrowed
6. Reject: actual_cost < min_reward
7. Reject: effort_score > cap
8. Reject: invalid signature
9. Reject: non-relayer caller
10. Reject: inactive provider
11. Fee precision with small amounts (dust test)
12. Backward compat: submit_proof_and_claim still works after upgrade
