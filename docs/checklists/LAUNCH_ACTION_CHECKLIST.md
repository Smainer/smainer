# Launch Action Checklist

## Contracts
- [ ] `cd contracts && scarb build`
- [ ] `cd contracts && snforge test`
- [ ] Inspect `contracts/target/dev/` for generated artifacts
- [ ] Declare and deploy the contract with `starkli`
- [ ] Save deployed address for backend/frontend configuration

## Relayer
- [ ] Start Redis locally and verify with `redis-cli ping`
- [ ] `cd backend/relayer && pip install -e .`
- [ ] Create `backend/relayer/.env` with `REDIS_URL`, `STARKNET_RPC_URL`, `RELAYER_PRIVATE_KEY`, `CONTRACT_ADDRESS`, `API_KEY`, `LOG_LEVEL`, `HOST`, `PORT`, `CORS_ORIGINS`
- [ ] `cd backend/relayer && pytest tests/ -v`
- [ ] `cd backend/relayer && uvicorn relayer.main:app --host 0.0.0.0 --port 8000 --reload` (use 8001 if 8000 occupied)
- [ ] Verify `curl http://localhost:8000/api/v1/health` (or 8001 if using alternate port)

## Provider
- [ ] `cd backend/provider && pip install -e .`
- [ ] Create `backend/provider/.env` with `RELAYER_WS_URL`, `STARKNET_PRIVATE_KEY`, `NODE_ID`, `MAX_CONCURRENT_TASKS`, `HEARTBEAT_INTERVAL`, `LOG_LEVEL`, `SANDBOX_TEMP_DIR`, `ENABLE_CUSTOM_TASKS`
- [ ] `cd backend/provider && pytest tests/ -v`
- [ ] `cd backend/provider && bash launch_provider.sh`
- [ ] Verify node registration with `curl -H "Authorization: Bearer dev-api-key" http://localhost:8000/api/v1/nodes` (or 8001 if using alternate port)

## Frontend
- [ ] `cd frontend && npm install`
- [ ] Create `frontend/.env.local` with `NEXT_PUBLIC_STARKNET_CHAIN_ID`, `NEXT_PUBLIC_COMPUTE_CONTRACT_ADDRESS`, `NEXT_PUBLIC_TOKEN_CONTRACT_ADDRESS`, `NEXT_PUBLIC_RPC_URL`, `RELAYER_API_URL`, `NEXT_PUBLIC_RELAYER_WS_URL`
- [ ] `cd frontend && npm test`
- [ ] `cd frontend && npx next lint`
- [ ] `cd frontend && npm run build`

## Security
- [ ] No private keys or secrets committed to git
- [ ] API key changed from default before any shared test
- [ ] `ENABLE_CUSTOM_TASKS=false` unless you explicitly need custom code execution
- [ ] `.env` files are local-only and permission-restricted

## Observability
- [ ] Relayer logs are visible in terminal or log collector
- [ ] Provider heartbeat can be observed in logs
- [ ] Failed task submissions are visible and actionable

## Go-Live
- [ ] First node registers successfully
- [ ] First authenticated task is accepted by relayer
- [ ] First task reaches a terminal state through `/api/v1/tasks/{task_id}`
- [ ] Frontend loads locally against the relayer
- [ ] Rollback path is clear: stop relayer, stop provider, revert env values
