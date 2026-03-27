#!/usr/bin/env python3
"""Fix the provider's on-chain public key via set_provider_public_key.

Usage: python3 fix_provider_pubkey.py <account_private_key_hex> <provider_private_key_hex>
"""

import asyncio
import sys

from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.account.account import Account
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import StarkCurveSigner, KeyPair
from starknet_py.net.client_models import Call
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.hash.utils import private_to_stark_key

MAINNET_RPC = "https://api.cartridge.gg/x/starknet/mainnet"
ACCOUNT_ADDRESS = 0x071cd50ddd9a2d0e1e95e6decd9f0a292b489dc6b9b13e68aac43b2295b626d6
CONTRACT_ADDRESS = 0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe


async def main():
    if len(sys.argv) != 3:
        print("Usage: python3 fix_provider_pubkey.py <account_priv_key> <provider_priv_key>")
        sys.exit(1)

    account_pk = int(sys.argv[1], 16)
    provider_pk = int(sys.argv[2], 16)
    public_key_int = private_to_stark_key(provider_pk)
    print(f"Account signer public key: {hex(private_to_stark_key(account_pk))}")
    print(f"Provider public key (to set on-chain): {hex(public_key_int)}")

    private_key_int = account_pk  # use account key for signing tx

    # Query current on-chain key
    client = FullNodeClient(node_url=MAINNET_RPC)
    result = await client.call_contract(
        Call(
            to_addr=CONTRACT_ADDRESS,
            selector=get_selector_from_name("get_provider_public_key"),
            calldata=[ACCOUNT_ADDRESS],
        )
    )
    current_key = result[0]
    print(f"Current on-chain key: {hex(current_key)}")

    if current_key == public_key_int:
        print("Already correct - no update needed.")
        return

    # Build account
    key_pair = KeyPair.from_private_key(private_key_int)
    signer = StarkCurveSigner(
        account_address=ACCOUNT_ADDRESS,
        key_pair=key_pair,
        chain_id=StarknetChainId.MAINNET,
    )
    account = Account(
        address=ACCOUNT_ADDRESS,
        client=client,
        signer=signer,
        chain=StarknetChainId.MAINNET,
    )

    # Call set_provider_public_key
    call = Call(
        to_addr=CONTRACT_ADDRESS,
        selector=get_selector_from_name("set_provider_public_key"),
        calldata=[public_key_int],
    )
    print("Submitting set_provider_public_key tx...")
    tx = await account.execute_v3(calls=[call], auto_estimate=True)
    print(f"Tx hash: {hex(tx.transaction_hash)}")

    print("Waiting for acceptance...")
    await client.wait_for_tx(tx.transaction_hash)
    print("Accepted!")

    # Verify
    result2 = await client.call_contract(
        Call(
            to_addr=CONTRACT_ADDRESS,
            selector=get_selector_from_name("get_provider_public_key"),
            calldata=[ACCOUNT_ADDRESS],
        )
    )
    print(f"Updated on-chain key: {hex(result2[0])}")
    if result2[0] == public_key_int:
        print("SUCCESS - on-chain public key matches provider signing key.")
    else:
        print("MISMATCH - verification failed!")


if __name__ == "__main__":
    asyncio.run(main())