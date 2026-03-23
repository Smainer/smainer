# Live Test Operations Index

Purpose: one canonical entry point for Telegram live-test operations across DigitalOcean, Runpod, Vercel, and Starknet.

## Canonical Files

1. `OPERATIONS_TRUTH_MAP.md`
- Runtime ownership (what runs where)
- Verification matrix
- Monitoring commands and evidence checklist

2. `CANONICAL_LIVE_TEST_GUIDE.md`
- End-to-end live-test sequence
- Required pass/fail gates

3. `LAUNCH_ACTION_CHECKLIST.md`
- Tactical launch checklist
- Final go/no-go items

4. `SYSTEM_ARCHITECTURE.md`
- Component-level architecture and data flow

5. `DEPLOYMENT_PLAYBOOK_DO_PC_VERCEL.md`
- Deployment topology and environment setup baseline

## Runtime Truth (Current)

- DigitalOcean: relayer, redis, telegram bot
- Runpod: first provider GPU node
- Vercel: miniapp and frontend
- Starknet: contract settlement layer

## Fast Debug Path (When Telegram fails)

1. Validate miniapp URLs configured in bot env:
- `MINIAPP_URL`
- optional `MINIAPP_CONNECT_URL`
- optional `MINIAPP_OPEN_URL`

2. Validate relayer node visibility:
- `GET /api/v1/nodes`
- `GET /api/v1/ai/capable-nodes`

3. Validate provider websocket registration:
- Provider must connect to `.../ws/node/{NODE_ID}`
- `node_register` and heartbeats visible in relayer logs

4. Validate callback path:
- Telegram bot callback host must be public + HTTPS policy-compatible on relayer side

## Repository Neatness Rule

Do not delete existing markdown history during active launch testing. Instead:
- Add/update canonical index files
- Mark stale docs in PR notes
- Archive after live test in a dedicated cleanup pass
