# RUN_LOCAL_NODE.md

## Local Smainer Provider Node Setup

This guide documents the working configuration for running a Smainer provider node locally against a local relayer.

### Exact Commands That Worked

1. **Activate environment**: 
   ```bash
   source /home/smainer/Smainer/.venv/bin/activate
   ```

2. **Start Redis**: 
   ```bash
   redis-server &  # System Redis worked, deployment/redis.conf had config issues
   ```

3. **Start Relayer**: 
   ```bash
   cd backend/relayer
   pip install -e .
   nohup python -m relayer.main > /tmp/relayer.log 2>&1 &
   ```

4. **Configure Provider**: 
   ```bash
   cd backend/provider
   pip install -e .
   # Configure .env (see below)
   nohup python -m provider.main > /tmp/provider.log 2>&1 &
   ```

### Critical Fixes Applied

#### 1. `.env` vs `.env.local` Split-Brain Fix
**File**: `backend/provider/.env.local` → `backend/provider/.env`
**Problem**: Code loads `.env` but scripts use `.env.local`
**Solution**: Created symlink `.env.local -> .env`
```bash
cd backend/provider
rm -f .env.local
ln -s .env .env.local
```

#### 2. WebSocket URL Double-Path Fix  
**File**: `backend/provider/.env`
**Problem**: `RELAYER_WS_URL=ws://localhost:8000/ws` caused double `/ws/ws/` in final URL
**Solution**: Remove `/ws` from base URL since `get_ws_url_with_node_id()` adds it
```
RELAYER_WS_URL=ws://localhost:8000  # NOT ws://localhost:8000/ws
```

#### 3. Provider Config Schema Fix
**File**: `backend/provider/.env` 
**Problem**: Config validation failed on `RELAYER_API_URL` and `SANDBOX_PATH` (undefined fields)
**Solution**: Use correct field names from `config.py`:
- `SANDBOX_TEMP_DIR` (not `SANDBOX_PATH`)
- Remove `RELAYER_API_URL` (not used)

#### 4. Missing Account Address
**File**: `backend/provider/.env`
**Problem**: Missing `STARKNET_ACCOUNT_ADDRESS` caused auth failure
**Solution**: Added production account address:
```
STARKNET_ACCOUNT_ADDRESS=0x071cd50ddd9a2d0e1e95e6decd9f0a292b489dc6b9b13e68aac43b2295b626d6
```

### Working Provider Configuration (backend/provider/.env)

**⚠️ SECURITY WARNING: Never commit actual private keys to version control!**

```env
RELAYER_WS_URL=ws://localhost:8000
STARKNET_PRIVATE_KEY=<REDACTED - generate your own test key for local dev>
STARKNET_ACCOUNT_ADDRESS=<YOUR_ACCOUNT_ADDRESS_CORRESPONDING_TO_PRIVATE_KEY>
NODE_ID=<GENERATE_UNIQUE_UUID_FOR_NODE>
MAX_CONCURRENT_TASKS=2
HEARTBEAT_INTERVAL=30
LOG_LEVEL=INFO
SANDBOX_TEMP_DIR=/tmp/provider_sandbox_smainer
ENABLE_CUSTOM_TASKS=false
```

### API Verification

**Working Command**:
```bash
curl -s -H "X-API-Key: lduph40yLQQQI1ql64cajqdYKBsok1k9" http://localhost:8000/api/v1/nodes
```

**Note**: Use `X-API-Key` header, not `Authorization: Bearer` (relayer API auth issue).

### Process Status
- **Redis**: System Redis running
- **Relayer**: PID varies, check with `pgrep -f relayer.main`  
- **Provider**: PID varies, check with `pgrep -f provider.main`

### Logs
- Relayer: `/tmp/relayer.log`
- Provider: `/tmp/provider.log`

### Next Steps
Provider registration ≠ inference capability. Ollama setup is stage-2 for actual task execution.