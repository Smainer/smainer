# Smainer Testnet Deployment Guide

## Built by Dedicated Developers

We're a committed group of developers building amazing apps that drive real network demand. This testnet deployment puts our vision into action—verifiable compute infrastructure that developers actually want to use.

**Ready to deploy? Follow this sequence:** contracts → relayer → provider → frontend.

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

## 5. Submit a Task to the Network

With the relayer running, you can submit compute tasks directly via the REST API. This is the core of what we build apps on top of.

### Authentication

All task endpoints require an `Authorization` header:

```
Authorization: Bearer <your-API_KEY>
```

Use the `API_KEY` value from your `backend/relayer/.env`.

---

### Submit a Task

**POST** `http://localhost:8000/api/v1/tasks`

```bash
curl -X POST http://localhost:8000/api/v1/tasks \
  -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "type": "inference",
      "prompt": "Summarise the concept of zero-knowledge proofs in two sentences."
    },
    "requirements": {
      "cpu_threads": 4,
      "ram_gb": 8,
      "gpu_required": false,
      "max_execution_time": 300
    },
    "token_amount": 1000,
    "description": "My first testnet task"
  }'
```

**Successful response (`201 Created`):**

```json
{
  "task_id": "abc123-...",
  "status": "pending",
  "created_at": "2026-03-10T12:00:00Z",
  "updated_at": "2026-03-10T12:00:00Z",
  "requirements": { "cpu_threads": 4, "ram_gb": 8, "gpu_required": false, "max_execution_time": 300 },
  "token_amount": 1000,
  "assigned_node_id": null,
  "result": null
}
```

---

### Task Requirements Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `cpu_threads` | int > 0 | Yes | CPU threads the task needs |
| `ram_gb` | int > 0 | Yes | RAM in GB the task needs |
| `gpu_required` | bool | No | Set `true` for GPU-intensive workloads |
| `min_vram_gb` | float | No | Minimum GPU VRAM in GB (only if `gpu_required: true`) |
| `required_tier` | string | No | `basic` / `pro` / `premium` (default: `basic`) |
| `max_execution_time` | int 1–3600 | Yes | Timeout in seconds |

---

### Poll Task Status

```bash
curl http://localhost:8000/api/v1/tasks/<task_id> \
  -H "Authorization: Bearer dev-api-key"
```

**Status lifecycle:** `pending` → `assigned` → `in_progress` → `completed` (or `failed` / `timeout`)

---

### GPU Task Example

```bash
curl -X POST http://localhost:8000/api/v1/tasks \
  -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": { "type": "image_generation", "prompt": "A sunset over Starknet" },
    "requirements": {
      "cpu_threads": 4,
      "ram_gb": 16,
      "gpu_required": true,
      "min_vram_gb": 8,
      "required_tier": "pro",
      "max_execution_time": 600
    },
    "token_amount": 5000,
    "description": "Image generation via GPU provider"
  }'
```

---

### Via the Frontend

Connect your Starknet wallet at `http://localhost:3000/tasks/submit` to submit tasks through the UI. No wallet? Use the Telegram bot (`@smainer_ai_bot`) — no wallet required.

## Notes

- Do not commit `.env` files.
- Change `API_KEY` from the default before any shared test.
- Do not hardcode guessed contract artifact names; inspect `target/dev/`.
- If frontend lint still fails locally, do not treat the frontend as deployment-ready.
