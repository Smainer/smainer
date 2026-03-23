# Smainer Deployment Playbook (DO + PC + Vercel)

Goal: one practical instruction file for the exact target setup.

Target setup:
- Relayer only on DigitalOcean
- Desktop app on this Windows PC (easy installer UX)
- Miniapp and bot entrypoints on Vercel
- Redis health and meaning
- Chain deployment truth and usage

---

## 1) Run Only Relayer on DigitalOcean

Scope on DO:
- Relayer API + scheduler
- Redis
- Optional provider (only if you intentionally want first node on DO)

Do not run website frontend on DO.

### Mandatory: Start From 0 (Clean DO Server)

Use this section first, every time you rebuild the DO environment from scratch.

1. Fresh droplet baseline
- New Ubuntu 22.04+ droplet preferred.
- If reusing an old server, remove previous Smainer services and data first.

2. Remove previous runtime (if server is reused)
- Stop old services:
	- sudo systemctl stop smainer-relayer || true
	- sudo systemctl stop smainer-bot || true
	- sudo systemctl stop smainer-provider || true
- Disable old services:
	- sudo systemctl disable smainer-relayer || true
	- sudo systemctl disable smainer-bot || true
	- sudo systemctl disable smainer-provider || true
- Remove old unit files:
	- sudo rm -f /etc/systemd/system/smainer-relayer.service
	- sudo rm -f /etc/systemd/system/smainer-bot.service
	- sudo rm -f /etc/systemd/system/smainer-provider.service
	- sudo systemctl daemon-reload

3. Remove old app folders and stale state (if reused)
- sudo rm -rf /opt/smainer /root/Smainer
- Keep Redis only if you explicitly want to preserve state.
- For full reset, clear Redis data:
	- sudo systemctl stop redis-server
	- sudo rm -rf /var/lib/redis/*
	- sudo systemctl start redis-server

4. Reinstall base dependencies
- sudo apt update && sudo apt upgrade -y
- sudo apt install -y git curl jq python3 python3-venv python3-pip redis-server

5. Re-prepare clean app directory
- sudo mkdir -p /opt/smainer
- sudo chown -R $USER:$USER /opt/smainer

6. Clean-start verification before install
- systemctl list-units --type=service | grep -E "smainer|relayer|provider|telegram" || true
- Expected: no active old smainer services.
- redis-cli ping
- Expected: PONG

### Steps

1. Prepare server
- Ubuntu 22.04+
- Open ports: 8000 (relayer API), 6379 (Redis internal only)

2. Start Redis
- sudo systemctl enable redis-server
- sudo systemctl start redis-server
- redis-cli ping
- Expected: PONG

3. Configure relayer environment
- Set Redis URL
- Set API auth keys
- Set Starknet RPC and contract addresses
- Set heartbeat and node timeout values

4. Start relayer service
- Use existing repo service/run scripts for relayer
- Confirm process is bound to 0.0.0.0:8000

5. Verify relayer
- curl http://127.0.0.1:8000/health
- curl with auth to /api/v1/nodes
- Expected: healthy status, nodes array present

### DO Clean-State Acceptance Criteria

All must pass:
1. No leftover smainer systemd units from previous installs.
2. Redis responds and has expected clean or intentional state.
3. Relayer starts from clean config and passes health endpoint.
4. No stale processes binding old ports (8000/8110) before relaunch.

### Success criteria
- Relayer health endpoint returns healthy
- Redis connected
- Node list endpoint responds
- Task creation endpoint accepts requests

---

## 2) Desktop App on This PC (Easy Installer Flow)

Desired UX:
- Download installer from site
- Small Windows install wizard
- Finish button
- App opens on finish

### Current blocker
- No published desktop release assets means no actual installer file to download.

### Steps to enable installer download

1. Build desktop installer in desktop repo
- Produce Windows installer artifact (exe or msi)
- Confirm app launches after install

2. Publish GitHub Release in Smainer/smainer-desktop
- Create tag and release
- Upload installer asset(s)
- Publish release

3. Verify release asset links
- Open releases/latest page
- Confirm the installer file is visible and downloadable

4. Site download path
- User path: site -> Download -> Create page -> Download for Windows
- This must resolve to a release with assets

### Desktop registration flow checks

1. Open app on this Windows PC
2. Connect wallet
3. Register node
4. Start provider
5. Confirm node appears in relayer nodes endpoint

---

## 3) Deploy Miniapp and Bot on Vercel + Verification

Important note:
- Miniapp is straightforward on Vercel.
- Python long-running bot is not a natural Vercel runtime.
- For Vercel, use webhook entrypoint pattern (serverless route) for bot-facing HTTP handling.

### 3A) Miniapp on Vercel

1. Deploy telegram miniapp project to Vercel
2. Set production env vars
- VITE_RELAYER_URL
- VITE_STARKNET_CHAIN_ID
- VITE contract addresses
- VITE_TELEGRAM_BOT_USERNAME

3. Verify miniapp
- Open miniapp URL in mobile browser first
- Then open from Telegram menu button
- Confirm no 404
- Confirm wallet connect mode works

### 3B) Bot entrypoint on Vercel

1. Use Vercel webhook endpoint for Telegram updates
- Current codebase includes API route pattern for Telegram webhook handling

2. Set bot env vars on Vercel
- TELEGRAM_BOT_TOKEN
- TELEGRAM_WEBHOOK_SECRET
- RELAYER URL/API key variables used by webhook handler

3. Configure Telegram webhook
- Set webhook URL to Vercel endpoint
- Set secret token

4. Verify bot
- Send /start
- Send one normal prompt
- Confirm response time and no 401/500 errors

### Telegram verification checklist

- Bot responds in chat
- Miniapp opens from menu button
- Miniapp can reach relayer
- No NOT_FOUND in Telegram in-app browser

---

## 4) Redis Check + Explanation

What Redis does here:
- Fast state store for node presence
- Heartbeats and active node sets
- Queue/scheduler coordination metadata

### Core checks

1. Basic liveness
- redis-cli ping
- Expected: PONG

2. Active nodes set
- Check active node keys/sets used by relayer
- Verify at least one active node after provider heartbeat

3. Heartbeat freshness
- Inspect heartbeat keys and TTL
- Heartbeat must refresh before timeout window

4. Relayer dependency check
- If Redis is slow/down, relayer status will degrade and scheduling fails

### Healthy signs
- Stable ping latency
- Active node keys present
- Heartbeat keys refreshing continuously

---

## 5) Chain: What Is Deployed and How We Use It

What chain layer is responsible for:
- Node registration state
- Task escrow and payouts
- Wallet-authenticated writes

Known addresses used in current stack:
- Compute contract: 0x044bf558b2e5ba7b3b24a18ff4944833ef9526b47907bcbdcbf94c33f4431abe
- Token contract: 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d

How components use chain:

1. Website and desktop/miniapp
- Wallet connect
- Register node transaction
- Read node/task/earnings state

2. Relayer
- Coordinates off-chain execution and on-chain settlement-related flow

3. Provider
- Registers identity and contributes compute off-chain

### Chain verification checklist

1. Wallet connected to correct Starknet chain
2. Contract reads succeed
3. Register node write returns tx hash
4. Explorer confirms status change
5. Dashboard reflects updated state

---

## 6) End-to-End Smoke Test (Must Pass)

1. Relayer healthy on DO
2. Redis healthy and heartbeats visible
3. Desktop app installs from published release
4. Desktop register node succeeds
5. Node appears in relayer active nodes
6. Telegram bot responds
7. Miniapp opens without 404 and connects wallet
8. One prompt completes end-to-end

If any one fails, do not call system ready.

---

## 7) Ownership Summary

- Relayer/Redis on DO: relayer-architect + systems-engineer
- Desktop installer and onboarding UX: tauri-desktop-engineer
- Miniapp and Vercel routing: frontend-engineer
- Bot webhook and runtime behavior: systems-engineer
- Chain contracts and tx correctness: starknet-engineer
- Final go/no-go: chief-director
