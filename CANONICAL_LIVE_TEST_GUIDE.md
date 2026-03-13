# Smainer Implementation Validation Guide

Primary reference for verifying component integration. Use this guide for deployment validation.

## 1) Current Full Status

### Contracts (Starknet Cairo)
- Status: Implemented in code, not yet validated by you in your environment.
- Confirmed in code:
- Tier constants exist: `TIER_BASIC`, `TIER_PRO`, `TIER_PREMIUM` (`contracts/src/smainer.cairo:31`)
- Tier multipliers map exists: `tier_multipliers` (`contracts/src/smainer.cairo:52`)
- Tiered task creation exists: `create_tiered_task` (`contracts/src/smainer.cairo:259`)
- Tier payout path exists in claim flow: `submit_proof_and_claim` (`contracts/src/smainer.cairo:360`)
- Multiplier admin function exists: `set_tier_multipliers` (`contracts/src/smainer.cairo:470`)
- What is not verified yet:
- You have not run build/tests/deploy locally in this cycle.

### Relayer (FastAPI + Redis)
- Status: Tier-aware scheduling appears implemented, not runtime-validated by you.
- Confirmed in code:
- Tier reward multipliers constant exists (`backend/relayer/src/relayer/core/scheduler.py:19`)
- Tier-compatible node selection exists (`backend/relayer/src/relayer/core/node_pool.py:173`)
- Scheduler routes by required tier (`backend/relayer/src/relayer/core/scheduler.py:289`)
- Health route uses queue stats (`backend/relayer/src/relayer/api/routes.py:271`)
- Queue stats function exists (`backend/relayer/src/relayer/core/scheduler.py:403`)
- What is not verified yet:
- You have not run relayer tests or done live API checks in this cycle.

### Provider Daemon
- Status: Hardware tier logic appears implemented, not runtime-validated by you.
- Confirmed in code:
- WSL2 detection exists (`backend/provider/src/provider/monitor.py:281`)
- Tier determination exists (`backend/provider/src/provider/monitor.py:296`)
- Registration + heartbeat loop exists (`backend/provider/src/provider/api_client.py:121`, `backend/provider/src/provider/api_client.py:278`)
- Node tier in models exists (`backend/provider/src/provider/models.py:46`)
- What is not verified yet:
- You have not run provider tests or first-node live registration in this cycle.

### Frontend (Next.js)
- Status: Major launch messaging and tier UI exist in code, not build-verified by you.
- Confirmed in code:
- Telegram bot CTA usage exists (`frontend/src/app/page.tsx:30`)
- STRK-only messaging exists (`frontend/src/app/page.tsx:203`)
- `/how-it-works` exists (`frontend/src/app/how-it-works/page.tsx:1`)
- Tier components exist (`frontend/src/components/ui/tier-badge.tsx:36`, `frontend/src/components/tasks/tier-pricing.tsx:37`)
- `TIER_CONFIG` exported (`frontend/src/types/index.ts:134`)
- What is not verified yet:
- You have not run test/lint/build in this cycle.

### Telegram Mini App
- Status: Build scripts and core app exist, but no single proof from your environment yet.
- Confirmed in code:
- Mini app build script exists (`telegram/miniapp/package.json:7`)
- Telegram app entry exists (`telegram/miniapp/src/main.tsx:1`)
- What is not verified yet:
- You have not completed production deploy + SSL + performance checks in this cycle.

### GTM / Marketing
- Status: Launch tasks are defined, execution pending technical confirmation.
- Your benco tasks are queued but should be sequenced behind technical gates below.

## 2) What Is Done vs Not Done (Based On Your Plan)

### Week 1 Technical
- Deploy Mini App to Production: Not done (not verified).
- Test Daemon/Seamon Service: Not done (you stated no testing yet).
- Smart Contract Final Testing: Not done in your current cycle.

### Week 1 Marketing (benco)
- Creative Assets: Can start draft now, finalization should wait until technical gate passes.
- Community Announcement Strategy: Draft now, lock final schedule only after technical gate passes.

### Week 2 Launch
- Mainnet Contract Deployment: Not started.
- 2x Rewards Activation: Logic appears implemented across stack, but activation is not verified/deployed.
- Marketing Blitz + 2x Campaign: Not started.

## 3) Validation Priority Order

1. Establish local technical validation (single-node full flow)
2. Deploy and verify on Starknet testnet  
3. Confirm frontend and mini app production readiness
4. Complete technical validation before external campaigns

## 4) Exact Testnet-First Execution Checklist

### Phase A: Environment Setup
1. Create Python venv at repo root and activate.
2. Install tools: `scarb`, `snforge`, `starkli`, Node 18+, Redis.
3. Prepare `.env` files:
- `backend/relayer/.env`
- `backend/provider/.env`
- `frontend/.env.local`

Use these canonical env names:
- Frontend: `NEXT_PUBLIC_COMPUTE_CONTRACT_ADDRESS`, `NEXT_PUBLIC_TOKEN_CONTRACT_ADDRESS`, `NEXT_PUBLIC_RPC_URL`, `RELAYER_API_URL`, `NEXT_PUBLIC_RELAYER_WS_URL`
- Relayer: `STARKNET_RPC_URL`, `CONTRACT_ADDRESS`, `API_KEY`

### Phase B: Contract Validation + Testnet Deploy
1. `cd contracts`
2. `scarb build`
3. `snforge test`
4. Inspect `contracts/target/dev/` for actual generated artifact name.
5. Declare via `starkli declare target/dev/<actual_contract_artifact>.json`
6. Deploy via `starkli deploy <class_hash> ...`
7. Save deployed contract address and class hash in your launch notes.

Exit Criteria:
- Build succeeds.
- Tests pass.
- Contract address confirmed on Starknet Sepolia explorer.

### Phase C: Relayer + Provider Integration
1. Start Redis.
2. Run relayer tests: `cd backend/relayer && pytest tests/ -v`
3. Start relayer: `uvicorn relayer.main:app --host 0.0.0.0 --port 8000 --reload`
4. Run provider tests: `cd backend/provider && pytest tests/ -v`
5. Start provider: `bash launch_provider.sh`
6. Verify health and nodes:
- `curl http://localhost:8000/api/v1/health`
- `curl -H "Authorization: Bearer <API_KEY>" http://localhost:8000/api/v1/nodes`

Exit Criteria:
- Health endpoint returns healthy/degraded with valid JSON.
- At least one node visible.

### Phase D: First End-to-End Task
1. Submit one basic task to `POST /api/v1/tasks`.
2. Poll by task id from `/api/v1/tasks/<task_id>` until terminal state.
3. Confirm path: `pending -> assigned -> in_progress -> completed` (or documented failure).

Exit Criteria:
- One full task lifecycle observed and logged.

### Phase E: Frontend + Mini App Readiness
1. Frontend:
- `cd frontend && npm install`
- `npm test`
- `npx next lint`
- `npm run build`
2. Mini app:
- `cd telegram/miniapp && npm install`
- `npm run lint`
- `npm run type-check`
- `npm run build`
3. Deploy mini app to production URL with SSL.
4. Run performance checks (mobile and desktop, initial load + key route interaction).

Exit Criteria:
- Both frontend and mini app build cleanly.
- Mini app is accessible via HTTPS with valid cert.

## 5) What You Need To Deploy Contract

Minimum required now:
1. Starknet Sepolia account + funded wallet for deploy gas.
2. Installed `starkli` and account configured.
3. Successful local build artifact from `scarb build`.
4. Constructor params decided (owner, relayer, treasury, fee token addresses as needed by current constructor).
5. A deployment log capturing:
- commit hash
- class hash
- deployed address
- constructor args
- deployment timestamp

## 6) Clear Next Steps For You (No Testing Done Yet)

### Today (must do)
1. Finish Phase A and Phase B.
2. Paste deploy outputs into your launch notes (class hash, address).

### Next (same day if possible)
1. Finish Phase C and confirm one provider node shows up.
2. Run Phase D and capture one successful task id.

### Then (tomorrow)
1. Finish Phase E frontend + mini app build/deploy verification.
2. Only after that, lock Week 2 date and let benco finalize announcements.

## 7) Agent Assignment Map (Operational Ownership)

- `starknet-engineer`: Contract test/deploy execution checklist validation and constructor argument sanity check.
- `relayer-architect`: Relayer runtime checks, queue/task visibility, API health validation.
- `systems-engineer`: Provider registration, heartbeat stability, GPU/WSL2 detection validation.
- `frontend-engineer`: Frontend and mini app build/deploy readiness, CTA and env consistency.
- `repository-architect`: GitHub issue board hygiene, dependency links, labels and milestones.
- `gtm-specialist`: Sequence benco campaign tasks to technical gate completion.

## 8) Definition Of Ready For Mainnet

All must be true:
1. Contract build/test/deploy completed on Sepolia with documented artifacts.
2. One full end-to-end task succeeds with real node registration.
3. Frontend and mini app production builds pass.
4. Mini app is live on HTTPS URL and linked correctly.
5. GTM copy uses final verified dates and confirmed functionality.

## 9) What To Ignore For Now

Until this file is complete, do not branch into new docs or new features. Focus only on proving the full pipeline once.

---

Owner: You (execution) + Engineering agents (validation)
Last updated: 2026-03-10