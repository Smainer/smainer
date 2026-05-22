---
name: starknet-cairo-patterns
description: "Use when writing or reviewing Starknet Cairo contracts, fee arithmetic, tier multipliers, or starknet.py transaction batching."
argument-hint: "Cairo smart contracts, starknet.py integrations..."
user-invocable: true
disable-model-invocation: false
---

# Starknet & Cairo Patterns

## 1. Zero-Fraction Arithmetic (BPS)
- **Always use Basis Points (BPS)**: `10000 = 100%`. Never use floating point math or raw percentages that can lose precision.
- **Dust Management**: Ensure that fee split components map perfectly to the required payout amount without leaving unwithdrawable 1-wei dust. E.g. `treasury_fee + gas_subsidy + provider_payout == amount`.

## 2. Global Contract Constants
Maintain system-wide naming consistency across Cairo state and Python nodes:
- **Tiers**: Use exact terms `TIER_BASIC`, `TIER_PRO`, `TIER_PREMIUM`.
- **Ecosystem BPS**: `TOTAL_FEE_BPS` (1500), `TREASURY_FEE_BPS` (1200), `GAS_SUBSIDY_BPS` (300).

## 3. Provider Payload Verification (`starknet.py`)
- Python Relayer integration must cryptographically verify provider results *before* constructing batch elements.
- Always use `multicall` patterns when deploying rewards on Starknet to compress gas spikes.

## 4. Scarb Rules
- Confirm `scarb build` correctness and rely on explicit interfaces for any external calls.
- Every contract feature must be paired with negative-path (abuse) tests in the deployment verification script.

## Input Contract
- **Trigger**: Called when writing or reviewing Cairo contracts, fee arithmetic, tier multipliers, or starknet.py transaction batching
- **Required context**: The contract function or feature being built/reviewed; target network (testnet or mainnet)
- **Optional**: Existing contract file paths; fee structure constants

## Output Contract
- **Cairo code**: Complete, compilable Cairo snippet or full contract function with security comments
- **Security notes**: Any access control, reentrancy, or arithmetic edge cases called out explicitly
- **Test stub**: Minimum negative-path test for the function