---
description: "Use when building wallet connections, blockchain integrations, DeFi interactions, or Web3 authentication flows. Covers multi-chain connectivity and transaction patterns."
applyTo: ["**/wallet/**", "**/web3/**", "**/blockchain/**", "**/defi/**", "**/integration/**"]
---

# Web3 Integration Patterns

## Wallet Connection Architecture

**Multi-chain wallet support**
```typescript
interface WalletConnection {
  address: string;
  chain: 'ethereum' | 'starknet' | 'ton';
  provider: any;
  disconnect: () => Promise<void>;
}

class WalletManager {
  private connections: Map<string, WalletConnection> = new Map();
  
  async connectWallet(type: 'metamask' | 'argent' | 'telegram'): Promise<WalletConnection> {
    switch (type) {
      case 'metamask':
        return await this.connectMetaMask();
      case 'argent':
        return await this.connectStarknet();
      case 'telegram':
        return await this.connectTelegramWallet();
    }
  }
}
```

**Connection state management**
```typescript
// Use React context or similar state management
interface WalletState {
  isConnecting: boolean;
  connections: WalletConnection[];
  activeWallet: WalletConnection | null;
  error: string | null;
}

const useWallet = () => {
  const [state, setState] = useState<WalletState>({
    isConnecting: false,
    connections: [],
    activeWallet: null,
    error: null
  });
  
  const connect = async (walletType: string) => {
    setState(s => ({ ...s, isConnecting: true, error: null }));
    try {
      const connection = await walletsManager.connectWallet(walletType);
      setState(s => ({ 
        ...s, 
        connections: [...s.connections, connection],
        activeWallet: connection,
        isConnecting: false 
      }));
    } catch (error) {
      setState(s => ({ 
        ...s, 
        error: error.message, 
        isConnecting: false 
      }));
    }
  };
  
  return { ...state, connect };
};
```

## Transaction Patterns

**Transaction builder with validation**
```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class TransactionParams:
    to_address: str
    amount: int  # in smallest unit (wei, etc.)
    token_contract: Optional[str] = None
    gas_limit: Optional[int] = None
    
class TransactionBuilder:
    def __init__(self, chain: str):
        self.chain = chain
        self.validators = self._get_validators()
    
    def build_transfer(self, params: TransactionParams) -> dict:
        # Validate parameters
        self._validate_params(params)
        
        # Build chain-specific transaction
        if self.chain == 'starknet':
            return self._build_starknet_tx(params)
        elif self.chain == 'ethereum':
            return self._build_ethereum_tx(params)
    
    def _validate_params(self, params: TransactionParams):
        if not self.validators['address'](params.to_address):
            raise ValueError("Invalid recipient address")
        
        if params.amount <= 0:
            raise ValueError("Amount must be positive")
        
        if params.token_contract and not self.validators['contract'](params.token_contract):
            raise ValueError("Invalid token contract")
```

## Error Handling & Retries

**Robust transaction submission**
```typescript
class TransactionSubmitter {
  async submitWithRetry(
    txData: any, 
    maxRetries: number = 3,
    backoffMs: number = 1000
  ): Promise<string> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const txHash = await this.submitTransaction(txData);
        return txHash;
        
      } catch (error) {
        if (this.isRetryableError(error) && attempt < maxRetries) {
          await this.sleep(backoffMs * attempt);
          continue;
        }
        
        // Log error without sensitive data
        console.error(`Transaction failed after ${attempt} attempts`);
        throw new Error('Transaction submission failed');
      }
    }
  }
  
  private isRetryableError(error: any): boolean {
    const retryableErrors = [
      'network error',
      'timeout',
      'nonce too low',
      'gas price too low'
    ];
    
    return retryableErrors.some(msg => 
      error.message?.toLowerCase().includes(msg)
    );
  }
}
```

## DeFi Protocol Integration

**Generic protocol interaction pattern**
```python
from abc import ABC, abstractmethod

class DeFiProtocol(ABC):
    def __init__(self, contract_address: str, chain: str):
        self.contract_address = contract_address
        self.chain = chain
        self.contract = self._load_contract()
    
    @abstractmethod
    def get_pool_info(self, pool_id: str) -> dict:
        pass
    
    @abstractmethod
    def calculate_rewards(self, user_address: str) -> int:
        pass
    
    @abstractmethod
    def stake(self, amount: int, user_address: str) -> dict:
        pass

class StarknetProtocol(DeFiProtocol):
    def get_pool_info(self, pool_id: str) -> dict:
        return self.contract.functions.get_pool_info(pool_id).call()
    
    def stake(self, amount: int, user_address: str) -> dict:
        # Build Starknet transaction
        call = self.contract.functions.stake(amount)
        return {
            'contract_address': self.contract_address,
            'entry_point_selector': call.selector,
            'calldata': call.calldata
        }
```

## Gas Optimization

**Dynamic gas estimation**
```typescript
class GasEstimator {
  async estimateOptimalGas(transaction: any): Promise<{
    gasLimit: number;
    gasPrice: number;
    maxFeePerGas?: number;
    maxPriorityFeePerGas?: number;
  }> {
    try {
      // Get network gas info
      const gasPrice = await this.provider.getGasPrice();
      const gasLimit = await this.provider.estimateGas(transaction);
      
      // Add 20% buffer for gas limit
      const adjustedGasLimit = Math.floor(gasLimit * 1.2);
      
      // For EIP-1559 networks
      if (await this.supportsEIP1559()) {
        const { maxFeePerGas, maxPriorityFeePerGas } = 
          await this.getEIP1559Fees();
          
        return {
          gasLimit: adjustedGasLimit,
          gasPrice: 0, // Not used in EIP-1559
          maxFeePerGas,
          maxPriorityFeePerGas
        };
      }
      
      return {
        gasLimit: adjustedGasLimit,
        gasPrice: gasPrice
      };
      
    } catch (error) {
      // Fallback to higher default values
      return this.getDefaultGasSettings();
    }
  }
}
```

## Authentication & Authorization

**Wallet-based authentication**
```python
import time
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

def create_auth_challenge(user_address: str) -> dict:
    """Create a challenge for wallet signature"""
    timestamp = int(time.time())
    nonce = os.urandom(16).hex()
    
    message = f"Sign in to Smainer\nAddress: {user_address}\nTime: {timestamp}\nNonce: {nonce}"
    
    return {
        'message': message,
        'timestamp': timestamp,
        'nonce': nonce,
        'expires_at': timestamp + 300  # 5 minute expiry
    }

def verify_auth_signature(
    challenge: dict, 
    signature: str, 
    user_address: str
) -> bool:
    """Verify the wallet signature against the challenge"""
    # Check expiry
    if time.time() > challenge['expires_at']:
        return False
    
    # Verify signature (implementation depends on chain)
    return verify_wallet_signature(
        challenge['message'], 
        signature, 
        user_address
    )
```

## Connection Monitoring

**Health checks and reconnection**
```typescript
class ConnectionMonitor {
  private healthCheckInterval: number = 30000; // 30 seconds
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  
  startMonitoring(connection: WalletConnection) {
    const healthCheck = setInterval(async () => {
      try {
        await connection.provider.getNetwork();
        this.reconnectAttempts = 0; // Reset on success
        
      } catch (error) {
        console.warn('Wallet connection health check failed');
        await this.attemptReconnection(connection);
      }
    }, this.healthCheckInterval);
    
    return healthCheck;
  }
  
  private async attemptReconnection(connection: WalletConnection) {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      await connection.disconnect();
      return;
    }
    
    this.reconnectAttempts++;
    try {
      await connection.provider.send('eth_requestAccounts', []);
    } catch (error) {
      console.error(`Reconnection attempt ${this.reconnectAttempts} failed`);
    }
  }
}
```