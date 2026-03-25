#!/usr/bin/env python3
"""Offline verification that provider signing matches contract verification.

Run with: python3 scripts/verify_signature_alignment.py

This script simulates the full flow:
  1. Provider computes result_hash, task_id_felt, message_hash, and signs
  2. Relayer verifier recomputes the same message_hash and verifies
  3. Relayer chain client constructs the same calldata the contract would see
"""

import hashlib
import json
import sys

# Add project paths
sys.path.insert(0, "backend/relayer/src")
sys.path.insert(0, "backend/provider/src")

from starknet_py.hash.utils import pedersen_hash, message_signature, verify_message_signature
from starknet_py.net.signer.stark_curve_signer import KeyPair

FIELD_PRIME = 2**251 + 17 * 2**192 + 1

# ─── Helpers (must match both provider and relayer) ──────────────────

def compute_result_hash(result_data: dict) -> int:
    result_json = json.dumps(result_data, sort_keys=True, separators=(",", ":"))
    h = int.from_bytes(hashlib.sha256(result_json.encode("utf-8")).digest(), "big")
    return h % FIELD_PRIME

def task_id_to_felt(task_id: str) -> int:
    h = int(hashlib.sha256(task_id.encode("utf-8")).hexdigest(), 16)
    return h % FIELD_PRIME

# ─── Simulation ──────────────────────────────────────────────────────

def main():
    # Use a test private key (not a real one)
    test_private_key = 0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF
    kp = KeyPair.from_private_key(test_private_key)
    public_key = kp.public_key
    print(f"Public key:  0x{public_key:064x}")

    # Simulate a task
    task_id = "f8fbd675-f719-4cc9-938b-748b8fe079e6"
    result_data = {
        "exit_code": 0,
        "result": "Hello from GPU compute",
        "resource_report": {"execution_time_seconds": 2.5},
        "status": "success",
        "stderr": "",
        "stdout": "Hello from GPU compute",
    }

    # ─── Step 1: Provider-side ───
    result_hash = compute_result_hash(result_data)
    task_id_felt = task_id_to_felt(task_id)
    provider_addr = public_key  # In this system, provider address IS the public key

    message_hash = pedersen_hash(pedersen_hash(task_id_felt, provider_addr), result_hash)
    sig_r, sig_s = message_signature(msg_hash=message_hash, priv_key=test_private_key)

    print(f"\n--- Provider side ---")
    print(f"task_id_felt:  {task_id_felt}")
    print(f"result_hash:   {result_hash}")
    print(f"message_hash:  {message_hash}")
    print(f"sig_r:         0x{sig_r:x}")
    print(f"sig_s:         0x{sig_s:x}")

    # ─── Step 2: Relayer verifier ───
    # Recompute the same way
    v_result_hash = compute_result_hash(result_data)
    v_task_id_felt = task_id_to_felt(task_id)
    v_message_hash = pedersen_hash(pedersen_hash(v_task_id_felt, public_key), v_result_hash)

    assert v_message_hash == message_hash, "MISMATCH: verifier message_hash != provider message_hash"
    verified = verify_message_signature(v_message_hash, [sig_r, sig_s], public_key)
    print(f"\n--- Relayer verifier ---")
    print(f"message_hash match: {v_message_hash == message_hash}")
    print(f"signature valid:    {verified}")

    # ─── Step 3: Relayer chain client calldata ───
    # Same task_id_felt as provider
    c_task_id_int = task_id_to_felt(task_id)
    c_task_id_low = c_task_id_int & ((1 << 128) - 1)
    c_task_id_high = c_task_id_int >> 128

    print(f"\n--- Relayer calldata ---")
    print(f"task_id_low:   {c_task_id_low}")
    print(f"task_id_high:  {c_task_id_high}")
    print(f"provider_addr: 0x{public_key:x}")
    print(f"result_hash:   {result_hash}")
    print(f"sig_r:         {sig_r}")
    print(f"sig_s:         {sig_s}")

    # ─── Step 4: Contract-side simulation ───
    # The contract does: task_id_felt = u256(low, high).try_into()
    # For values < 2^251, this is identity
    contract_task_id_felt = c_task_id_low + (c_task_id_high << 128)
    assert contract_task_id_felt == task_id_felt, "MISMATCH: contract task_id_felt != provider"

    contract_message_hash = pedersen_hash(
        pedersen_hash(contract_task_id_felt, public_key), result_hash
    )
    assert contract_message_hash == message_hash, "MISMATCH: contract message_hash != provider"

    contract_verified = verify_message_signature(contract_message_hash, [sig_r, sig_s], public_key)
    print(f"\n--- Contract simulation ---")
    print(f"message_hash match:  {contract_message_hash == message_hash}")
    print(f"signature valid:     {contract_verified}")

    if verified and contract_verified:
        print(f"\n✓ ALL CHECKS PASSED — signature alignment is correct")
    else:
        print(f"\n✗ VERIFICATION FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
