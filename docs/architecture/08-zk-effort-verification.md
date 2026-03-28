# ZK Effort Verification Roadmap (V2)

> Status: Planned (Future — after V1 effort-based pricing is live)
> Owner Agent: `starknet-engineer` + `security-expert`

## Problem Statement

In V1, effort metrics (token counts, GPU time, model ID) are **self-reported by the compute node** and signed with its Starknet key. This creates a trust assumption:

- **Honest node**: Reports accurate metrics → fair pricing
- **Malicious node**: Inflates token counts or GPU time → earns more than deserved
- **Colluding node+user**: Deflates metrics → user pays less, provider gets less (but if they're the same entity, they dodge treasury fees)

V2 eliminates this trust assumption with zero-knowledge proofs of inference execution.

## Approach: ZK-Attested Inference Metrics

### What We Prove

A ZK proof that attests:
1. **Token count is accurate**: The model actually processed N input tokens and generated M output tokens
2. **Model identity**: The inference was run on the claimed model (not a smaller/cheaper one)
3. **Execution happened**: The computation actually occurred (not a cached/replayed result)

### What We Don't Prove (out of scope for V2)

- GPU time (hardware-dependent, not deterministic)
- Memory usage (OS-dependent)
- Power consumption

### Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐
│   Compute Node   │     │   ZK Prover      │     │   Starknet   │
│                  │     │   (co-processor)  │     │   Contract   │
│  1. Run inference│────▶│  2. Generate      │────▶│  3. Verify   │
│     with trace   │     │     ZK proof of   │     │     proof    │
│                  │     │     token counts  │     │     on-chain │
└──────────────────┘     └──────────────────┘     └──────────────┘
```

### Proof Contents

```
ZKEffortProof {
    // Public inputs (visible to verifier)
    model_hash: felt252,          // Hash of model weights (identifies model)
    input_token_count: u32,       // Verified token count
    output_token_count: u32,      // Verified token count
    result_hash: felt252,         // Hash of output (links to task)

    // Proof
    proof: Vec<felt252>,          // STARK proof data
}
```

### Integration with V1

```cairo
// V2 contract extension
fn settle_with_zk_proof(
    ref self: ContractState,
    task_id: u256,
    provider: ContractAddress,
    result_hash: felt252,
    zk_proof: ZKEffortProof,      // Replaces self-reported metrics
    signature_r: felt252,
    signature_s: felt252,
) {
    // Verify ZK proof on-chain
    let proof_valid = self.zk_verifier.verify(zk_proof);
    assert(proof_valid, 'Invalid effort proof');

    // Use proven token counts for pricing
    let actual_cost = self.calculate_cost_from_proven_metrics(
        zk_proof.input_token_count,
        zk_proof.output_token_count,
        zk_proof.model_hash,
    );

    // ... same settlement logic as settle_with_effort ...
}
```

## Technology Options

### Option A: RISC Zero (zkVM)

- Run inference in a RISC-V virtual machine
- ZK proof of entire execution trace
- **Pro**: General-purpose, can prove arbitrary computation
- **Con**: Massive overhead — LLM inference in zkVM is impractically slow today

### Option B: Custom ZK Circuit for Token Counting

- Only prove the tokenizer step + output length
- Don't prove the full inference (too expensive)
- **Pro**: Feasible with current ZK tech
- **Con**: Doesn't prove the model actually ran (only that tokens were counted correctly)

### Option C: Trusted Execution Environment (TEE) + Attestation

- Run inference in Intel SGX/TDX or ARM TrustZone
- TEE produces hardware attestation of metrics
- **Pro**: No ZK overhead, works today
- **Con**: Requires specific hardware, trusts CPU manufacturer

### Option D: Optimistic Verification with Slashing

- Accept self-reported metrics by default
- Random spot-checks: re-run inference on a trusted node
- If metrics don't match → slash provider's stake
- **Pro**: Simple, efficient, works today
- **Con**: Requires staking mechanism, probabilistic not deterministic

## Recommended Path

**V2.0**: Option D (Optimistic + Slashing) — implementable now
**V2.1**: Option C (TEE attestation) — for premium tier nodes
**V3.0**: Option B (ZK token counting) — when ZK tech matures

## Staking Mechanism for Optimistic Verification

```cairo
// Provider stakes STRK as collateral
fn stake(ref self: ContractState, amount: u256) {
    // Transfer STRK from provider to contract
    // Track staked amount per provider
}

// Slash provider if spot-check fails
fn slash_provider(
    ref self: ContractState,
    provider: ContractAddress,
    task_id: u256,
    evidence_hash: felt252,      // Hash of re-execution result showing discrepancy
) {
    // Only callable by authorized verifier
    // Slash percentage of stake
    // Distribute slashed amount to treasury
    // Emit SlashingEvent
}
```

## Spot-Check Protocol

```
1. Relayer randomly selects 5% of completed tasks for re-verification
2. Trusted verifier node re-runs the exact same inference
3. Compare: token counts, result similarity, execution time
4. If discrepancy > threshold:
   a. Slash provider's stake
   b. Flag provider for review
   c. Recalculate settlement for affected task
5. If no discrepancy:
   a. Provider's reputation score increases
   b. Spot-check frequency decreases for high-reputation providers
```

## Timeline

| Phase | Target | Scope |
|-------|--------|-------|
| V1 (current plan) | Q2 2026 | Self-reported metrics + signature |
| V2.0 | Q3 2026 | Optimistic verification + staking + slashing |
| V2.1 | Q4 2026 | TEE attestation for premium nodes |
| V3.0 | 2027 | ZK proof of token counting |

## Dependencies

- V2.0 requires: staking contract, verifier node, spot-check scheduler
- V2.1 requires: TEE-enabled hardware in node fleet
- V3.0 requires: ZK circuit development, on-chain verifier contract
