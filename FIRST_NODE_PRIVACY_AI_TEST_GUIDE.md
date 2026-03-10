# First Node Privacy AI Test Guide

Run one local provider node, connect it to the relayer, and submit a test task end to end.

## Linux Prerequisites

```bash
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3-pip git redis-server
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
redis-cli ping
```

## Repository Setup

```bash
cd /home/smainer/Smainer
python3.11 -m venv .venv
source .venv/bin/activate
```

## Install Dependencies

```bash
cd backend/relayer && pip install -e .
cd ../provider && pip install -e .
cd ../../frontend && npm install
cd /home/smainer/Smainer
```

## Environment Files

Create `backend/relayer/.env`:

```env
REDIS_URL=redis://localhost:6379/0
STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io
RELAYER_PRIVATE_KEY=0xYOUR_RELAYER_PRIVATE_KEY
CONTRACT_ADDRESS=0xYOUR_DEPLOYED_COMPUTE_CONTRACT
API_KEY=dev-api-key
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000
CORS_ORIGINS=http://localhost:3000
```

Create `backend/provider/.env`:

```env
RELAYER_WS_URL=ws://localhost:8000
STARKNET_PRIVATE_KEY=0xYOUR_PROVIDER_PRIVATE_KEY
NODE_ID=privacy-ai-test-node
MAX_CONCURRENT_TASKS=2
HEARTBEAT_INTERVAL=30
LOG_LEVEL=INFO
SANDBOX_TEMP_DIR=/tmp/provider_sandbox
ENABLE_CUSTOM_TASKS=false
```

Create `frontend/.env.local`:

```env
NEXT_PUBLIC_STARKNET_CHAIN_ID=SN_SEPOLIA
NEXT_PUBLIC_COMPUTE_CONTRACT_ADDRESS=0xYOUR_DEPLOYED_COMPUTE_CONTRACT
NEXT_PUBLIC_TOKEN_CONTRACT_ADDRESS=0xYOUR_TOKEN_CONTRACT
NEXT_PUBLIC_RPC_URL=https://starknet-sepolia.public.blastapi.io
RELAYER_API_URL=http://localhost:8000
NEXT_PUBLIC_RELAYER_WS_URL=ws://localhost:8000/ws
```

## Start Services

### Terminal 1: Redis

```bash
redis-server
```

### Terminal 2: Relayer

```bash
cd /home/smainer/Smainer/backend/relayer
source ../../.venv/bin/activate
uvicorn relayer.main:app --host 0.0.0.0 --port 8000 --reload
```

### Terminal 3: Provider

```bash
cd /home/smainer/Smainer/backend/provider
source ../../.venv/bin/activate
bash launch_provider.sh
```

### Terminal 4: Frontend

```bash
cd /home/smainer/Smainer/frontend
npm run dev
```

## Verify Health

```bash
curl http://localhost:8000/api/v1/health
curl -H "Authorization: Bearer dev-api-key" http://localhost:8000/api/v1/nodes
```

## Submit a Test Task

```bash
curl -X POST http://localhost:8000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-api-key" \
  -d '{
    "payload": {
      "algorithm": "matrix_multiplication",
      "matrix_a": [[1, 2], [3, 4]],
      "matrix_b": [[5, 6], [7, 8]],
      "parameters": {"precision": "float64"}
    },
    "requirements": {
      "cpu_threads": 4,
      "ram_gb": 8,
      "gpu_required": false,
      "max_execution_time": 300
    },
    "token_amount": 1000,
    "description": "First local Privacy AI test"
  }'
```

Copy the returned `task_id`, then check status:

```bash
curl -H "Authorization: Bearer dev-api-key" http://localhost:8000/api/v1/tasks/<task_id>
```

## Troubleshooting

- If Redis is not running, start it before relayer.
- If provider does not appear in `/api/v1/nodes`, check the relayer terminal and provider terminal for connection errors.
- If task submission fails with 401, verify the `Authorization` header matches `API_KEY` in `backend/relayer/.env`.
- If the frontend does not load relayer data, verify `RELAYER_API_URL` and `NEXT_PUBLIC_RELAYER_WS_URL`.
- Rerun frontend lint locally before treating the frontend as deployment-ready.