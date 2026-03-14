---
description: "Use when handling cryptocurrency, private keys, wallet integration, blockchain transactions, secure data storage, or crypto payment flows. Covers security patterns and privacy-preserving practices."
applyTo: ["**/telegram/**", "**/bot/**", "**/crypto/**", "**/wallet/**", "**/blockchain/**"]
---

# Crypto Security Guidelines

## Key Management

**NEVER hardcode private keys or mnemonics**
```typescript
// ❌ WRONG
const PRIVATE_KEY = "0x123abc..."

// ✅ CORRECT
const privateKey = process.env.WALLET_PRIVATE_KEY;
if (!privateKey) throw new Error('WALLET_PRIVATE_KEY not set');
```

**Use environment variables with validation**
```python
import os
from cryptography.fernet import Fernet

# Validate required env vars at startup
REQUIRED_VARS = ['BOT_TOKEN', 'WALLET_PRIVATE_KEY', 'ENCRYPTION_KEY']
for var in REQUIRED_VARS:
    if not os.getenv(var):
        raise ValueError(f"Required environment variable {var} not set")
```

**Encrypt sensitive data at rest**
```python
# Use strong encryption for stored wallet data
def encrypt_wallet_data(data: str, key: bytes) -> str:
    f = Fernet(key)
    return f.encrypt(data.encode()).decode()

def decrypt_wallet_data(encrypted_data: str, key: bytes) -> str:
    f = Fernet(key)
    return f.decrypt(encrypted_data.encode()).decode()
```

## Transaction Security

**Always validate transaction parameters**
```python
def validate_transaction(amount: int, recipient: str, token_address: str):
    # Amount validation
    if amount <= 0:
        raise ValueError("Amount must be positive")
    if amount > MAX_TRANSACTION_AMOUNT:
        raise ValueError(f"Amount exceeds maximum: {MAX_TRANSACTION_AMOUNT}")
    
    # Address validation
    if not is_valid_address(recipient):
        raise ValueError("Invalid recipient address")
    
    # Token validation
    if token_address not in APPROVED_TOKENS:
        raise ValueError("Token not approved for transactions")
```

**Implement transaction limits and rate limiting**
```python
from functools import wraps
import time

def rate_limit(max_calls_per_hour=10):
    def decorator(func):
        calls = {}
        @wraps(func)
        def wrapper(user_id, *args, **kwargs):
            now = time.time()
            hour_ago = now - 3600
            
            # Clean old entries
            calls[user_id] = [t for t in calls.get(user_id, []) if t > hour_ago]
            
            if len(calls[user_id]) >= max_calls_per_hour:
                raise Exception("Rate limit exceeded")
            
            calls[user_id].append(now)
            return func(user_id, *args, **kwargs)
        return wrapper
    return decorator
```

## Privacy Patterns

**Ephemeral data handling**
```python
class EphemeralSession:
    def __init__(self):
        self.data = {}
        
    def store_temporary(self, user_id: str, data: dict, ttl: int = 300):
        """Store data that self-destructs after TTL seconds"""
        self.data[user_id] = {
            'data': data,
            'expires': time.time() + ttl
        }
        
    def get_and_destroy(self, user_id: str):
        """Retrieve data and immediately delete it"""
        if user_id in self.data:
            session_data = self.data[user_id]
            del self.data[user_id]
            
            if time.time() > session_data['expires']:
                return None
                
            return session_data['data']
        return None
```

**Zero-log transaction processing**
```python
def process_private_transaction(tx_data: dict):
    """Process transaction without logging sensitive data"""
    try:
        # Only log non-sensitive metadata
        logger.info(f"Processing transaction type: {tx_data['type']}")
        
        # Process transaction
        result = execute_blockchain_transaction(tx_data)
        
        # Clear sensitive data from memory
        tx_data.clear()
        
        # Only return transaction hash, not details
        return {'tx_hash': result['hash'], 'status': 'success'}
        
    except Exception as e:
        logger.error(f"Transaction failed: {type(e).__name__}")  # Don't log sensitive details
        raise
```

## Input Sanitization

**Sanitize all user inputs**
```python
import re

def sanitize_wallet_input(address: str) -> str:
    """Sanitize wallet address input"""
    # Remove whitespace
    address = address.strip()
    
    # Validate format (example for Ethereum)
    if not re.match(r'^0x[a-fA-F0-9]{40}$', address):
        raise ValueError("Invalid address format")
    
    return address.lower()

def sanitize_amount_input(amount_str: str) -> int:
    """Convert amount string to wei (smallest unit)"""
    try:
        # Remove any non-numeric characters except decimal point
        clean_amount = re.sub(r'[^\d.]', '', amount_str)
        amount = float(clean_amount)
        
        if amount <= 0:
            raise ValueError("Amount must be positive")
            
        # Convert to wei (18 decimals for ETH)
        return int(amount * 10**18)
        
    except (ValueError, OverflowError):
        raise ValueError("Invalid amount format")
```

## Error Handling

**Never expose sensitive data in error messages**
```python
def create_wallet_connection():
    try:
        private_key = os.getenv('WALLET_PRIVATE_KEY')
        wallet = create_wallet_from_private_key(private_key)
        return wallet
        
    except Exception as e:
        # ❌ WRONG - exposes private key
        # logger.error(f"Failed to create wallet with key {private_key}: {e}")
        
        # ✅ CORRECT - generic error
        logger.error("Failed to create wallet connection")
        raise Exception("Wallet connection failed") from None
```

## Security Headers & Validation

**Implement signature verification for webhooks**
```python
import hmac
import hashlib

def verify_telegram_webhook(token: str, data: bytes, signature: str) -> bool:
    """Verify Telegram webhook signature"""
    expected = hmac.new(
        token.encode(),
        data,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected)

def verify_wallet_signature(message: str, signature: str, public_key: str) -> bool:
    """Verify cryptographic signature from wallet"""
    # Implementation depends on the blockchain/wallet type
    # Always use constant-time comparison
    pass
```