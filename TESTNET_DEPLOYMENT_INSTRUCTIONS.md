# Smainer Testnet Deployment Guide

Deploy in this order: contracts -> relayer -> provider -> frontend.

## Prerequisites

- Scarb
- snforge
- starkli
- Python 3.11+
- Node.js 18+
- Redis

## Repository Setup

```bash
cd /home/smainer/Smainer
python3 -m venv .venv
source .venv/bin/activate
```

## 1. Contracts

```bash
cd contracts
scarb build
snforge test
ls target/dev/
```

Use the generated file names you actually see in `target/dev/`.

```bash
starkli declare target/dev/<generated_contract_class>.json
starkli deploy <class_hash> ...
```

Save the deployed compute contract address for relayer and frontend configuration.

## 2. Relayer

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

Run:

```bash
cd /home/smainer/Smainer/backend/relayer
source ../../.venv/bin/activate
pip install -e .
pytest tests/ -v
uvicorn relayer.main:app --host 0.0.0.0 --port 8000 --reload
```

## 3. Provider

Create `backend/provider/.env`:

```env
RELAYER_WS_URL=ws://localhost:8000
STARKNET_PRIVATE_KEY=0xYOUR_PROVIDER_PRIVATE_KEY
NODE_ID=test-node-01
MAX_CONCURRENT_TASKS=2
HEARTBEAT_INTERVAL=30
LOG_LEVEL=INFO
SANDBOX_TEMP_DIR=/tmp/provider_sandbox
ENABLE_CUSTOM_TASKS=false
```

Run:

```bash
cd /home/smainer/Smainer/backend/provider
source ../../.venv/bin/activate
pip install -e .
pytest tests/ -v
bash launch_provider.sh
```

## 4. Frontend

Create `frontend/.env.local`:

```env
NEXT_PUBLIC_STARKNET_CHAIN_ID=SN_SEPOLIA
NEXT_PUBLIC_COMPUTE_CONTRACT_ADDRESS=0xYOUR_DEPLOYED_COMPUTE_CONTRACT
NEXT_PUBLIC_TOKEN_CONTRACT_ADDRESS=0xYOUR_TOKEN_CONTRACT
NEXT_PUBLIC_RPC_URL=https://starknet-sepolia.public.blastapi.io
RELAYER_API_URL=http://localhost:8000
NEXT_PUBLIC_RELAYER_WS_URL=ws://localhost:8000/ws
```

Run:

```bash
cd /home/smainer/Smainer/frontend
npm install
npm test
npx next lint
npm run build
```

## Verification

```bash
curl http://localhost:8000/api/v1/health
curl -H "Authorization: Bearer dev-api-key" http://localhost:8000/api/v1/nodes
```

## Notes

- Do not commit `.env` files.
- Change `API_KEY` from the default before any shared test.
- Do not hardcode guessed contract artifact names; inspect `target/dev/`.
- If frontend lint still fails locally, do not treat the frontend as deployment-ready.
