#!/usr/bin/env python3
"""
Simple test script to verify Starknet imports and key derivation.
"""

import os
from pathlib import Path

print("Testing Starknet imports...")

try:
    from dotenv import load_dotenv
    print("✓ dotenv import OK")
    
    from starknet_py.hash.utils import private_to_stark_key
    print("✓ private_to_stark_key import OK")
    
    from starknet_py.net.signer.stark_curve_signer import StarkCurveSigner, KeyPair
    print("✓ StarkCurveSigner imports OK")
    
    # Test key derivation
    provider_env = Path("/home/smainer/Smainer/backend/provider/.env")
    if provider_env.exists():
        load_dotenv(provider_env)
        private_key = os.getenv("STARKNET_PRIVATE_KEY")
        if private_key:
            print(f"✓ Found STARKNET_PRIVATE_KEY")
            private_key_int = int(private_key, 16)
            public_key_int = private_to_stark_key(private_key_int)
            print(f"✓ Derived public key: 0x{public_key_int:x}")
            
            # Check if it matches expected
            expected = 0x2b923c87f6cac664fb4975683e5fd5e0cfccc0f6512d07cb563fde0ad509cbd
            if public_key_int == expected:
                print("✅ Public key matches expected value!")
            else:
                print(f"❌ Public key mismatch:")
                print(f"   Got:      0x{public_key_int:x}")  
                print(f"   Expected: 0x{expected:x}")
        else:
            print("❌ No STARKNET_PRIVATE_KEY found")
    else:
        print("❌ Provider env file not found")
    
    print("\n✅ All tests passed!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()