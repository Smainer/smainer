---
name: telegram-product-engineer
description: "Use when building, designing, debugging, or innovating on the Smainer Telegram bot or MiniApp. Covers UX design patterns, bot-to-relayer integration, Vercel deployment, Runpod operations, wallet flows, and Telegram WebApp SDK."
argument-hint: "Telegram feature / UX improvement / bot debugging / miniapp deployment..."
user-invocable: true
disable-model-invocation: false
---

# Telegram Product Engineer Skill

## Purpose

This skill encodes the operational knowledge, design standards, and integration patterns for the Smainer Telegram bot and MiniApp. Load this skill when working on any Telegram-related task to ensure consistency, quality, and correct integration with the broader Smainer system.

## Codebase Map

### Bot (Python, deployed on Vercel — serverless webhook)
```
telegram/smainer-bot/
├── api/
│   ├── webhook.py           # Main Telegram webhook entry point
│   ├── health.py            # Health check endpoint
│   ├── setup_webhook.py     # Admin endpoint to register webhook
│   └── callback/
│       ├── complete.py      # Receives task completion from Relayer
│       └── stream.py        # Reserved for streaming (empty)
├── src/
│   ├── handlers.py          # /start, /help, /link, /balance, /models, text→pay→compute
│   ├── config.py            # Pydantic Settings, env vars via Vercel dashboard
│   ├── wallet.py            # Starknet wallet link/unlink, balance checks
│   ├── relayer_client.py    # POST /api/v1/tasks to Relayer (httpx, stateless)
│   ├── payment.py           # Log-only payment tracking (no Redis)
│   ├── callback_auth.py     # HMAC-SHA256 callback signature verification
│   └── models.py            # Pydantic schemas shared across modules
├── vercel.json              # Vercel deployment config
└── requirements.txt         # Python deps
```

> **IMPORTANT:** `telegram/telegram-bot/` is the LEGACY version (polling, long-running, Redis-backed). It is NOT deployed. All production work goes to `telegram/smainer-bot/`.

### MiniApp (React/TS, deployed on Vercel)
```
telegram/miniapp/src/
├── App.tsx              # Routes: /home, /chat, /nft, /dashboard
├── main.tsx             # Vite entry
├── index.css            # Global styles + CSS variables
├── components/
│   ├── ChatInterface.tsx    # AI chat with streaming
│   ├── WalletConnect.tsx    # ArgentX/Braavos connection
│   ├── ModelSelector.tsx    # GPU model picker
│   ├── CostEstimator.tsx    # Real-time cost display
│   ├── NFTPreview.tsx       # AI image → NFT mint flow
│   └── DebugOverlay.tsx     # Dev-only debug panel
├── hooks/
│   ├── useRelayerAPI.ts     # Relayer HTTP client
│   └── useTelegramData.ts   # Telegram WebApp SDK bridge
├── lib/                     # Utility functions
└── types/                   # TypeScript interfaces
```

### Deployment
```
telegram/smainer-bot/vercel.json   # Bot Vercel config (serverless functions)
telegram/miniapp/vercel.json       # MiniApp Vercel config (static SPA)
telegram/miniapp/.env.local        # Local env vars (VITE_RELAYER_URL, etc.)
```
- Bot env vars are set in Vercel dashboard (not .env files)
- Production deploys from `main` branch only
- DO (138.197.11.147) runs ONLY the relayer — NO bot processes

## Integration Points

### Bot → Relayer (REST)
- Endpoint: `POST /api/v1/tasks`
- Auth: API key in header
- Payload includes `complete_callback_url` for result delivery
- Payload includes optional `on_chain_task_id` for escrow flow
- Response: task ID for tracking

### Relayer → Bot (Callback)
- Relayer POSTs to `https://bot.smainer.io/api/callback/complete` (Vercel serverless function)
- HMAC-SHA256 signature verification via `X-Smainer-Signature` header
- Bot edits Telegram placeholder message with result

### MiniApp → Relayer (REST)
- Uses `useRelayerAPI` hook
- Same `/api/v1/tasks` endpoint
- Wallet address passed for payment attribution

### MiniApp ↔ Telegram SDK
- `useTelegramData` hook bridges Telegram WebApp SDK
- Reads `initData`, theme params, viewport size
- Handles `MainButton`, `BackButton`, haptic feedback

### Bot ↔ Starknet
- `wallet.py` calls Starknet RPC for balance checks
- Payment settlement triggers on-chain escrow via Relayer

## Runpod Operations Playbook

### Check bot status
```bash
ssh vrh09kn5mzzjq5-64410b1d@ssh.runpod.io -i ~/.ssh/runpod_smainer
# Check if bot is running
ps aux | grep telegram
# Check logs
tail -100 /path/to/bot/logs
```

### Restart bot safely
```bash
# Use PID file — never pkill -f (kills SSH session)
kill $(cat /root/telegram-bot.pid) 2>/dev/null
cd /path/to/telegram-bot
nohup python -m telegram_bot.main > bot.log 2>&1 &
echo $! > /root/telegram-bot.pid
```

### Debug connectivity
```bash
# Can bot reach relayer?
curl -s http://194.68.245.210:8000/health
# Can relayer reach bot callback?
curl -s http://<runpod-ip>:<callback-port>/health
```

## Vercel Deployment Playbook

### Deploy MiniApp
```bash
cd telegram/miniapp
# Vercel auto-deploys on push to main
git push origin main
# Or manual deploy
npx vercel --prod
```

### Environment variables (Vercel dashboard)
- `VITE_RELAYER_URL` — Relayer base URL
- `VITE_FRONTEND_URL` — MiniApp public URL
- `VITE_STARKNET_NETWORK` — mainnet or testnet

## UX Design Patterns

### Flow-First Thinking
Before building any feature, map the user journey:
1. What triggers the flow? (bot command, miniapp button, deeplink)
2. What's the happy path? (minimum taps to completion)
3. What can go wrong? (no wallet, low balance, timeout)
4. How does each error state guide the user forward?

### Telegram-Specific Constraints
- MiniApp viewport is small — design for 360px width minimum
- No browser chrome — use Telegram's back button, not custom nav
- Theme follows Telegram's dark/light mode via CSS variables
- Animations must be lightweight — Telegram WebView is not a full browser
- Inline keyboards are more discoverable than typed commands
- Message editing for streaming responses — never spam multiple messages

### The "One More Tap" Test
For every flow, count the taps. Then ask: can you remove one? The answer is almost always yes.

### Error State Hierarchy
1. **Preventable**: Don't let the user get there (disable button if balance too low)
2. **Recoverable**: Show what happened + action to fix ("Link wallet to continue")
3. **Informative**: If truly stuck, explain clearly ("Network congestion, retry in 30s")

## Innovation Research Patterns

When exploring new ideas:
1. Use `fetch_webpage` to study top Telegram bots (Wallet, Fragment, Notcoin patterns)
2. Look at Web3 mobile UX leaders (Rainbow Wallet, Uniswap Mobile, Phantom)
3. Study best-in-class chat UIs (ChatGPT, Claude, Perplexity — the chat chrome, not the AI)
4. Bring mobile-native patterns into Telegram's constrained viewport

## Quality Checklist

Before shipping any Telegram change:
- [ ] Tested on Telegram mobile (iOS + Android) and desktop
- [ ] Wallet connect/disconnect flow works end-to-end
- [ ] Streaming response renders smoothly (no flicker, no layout shift)
- [ ] Error states show actionable messages
- [ ] Bot commands respond within 2 seconds
- [ ] MiniApp loads under 3 seconds on 4G
- [ ] No secrets in logs or response messages
- [ ] Callback server accessible from Relayer

## Input Contract
- **Trigger**: Called when building, designing, debugging, or innovating on the Smainer Telegram bot or MiniApp
- **Required context**: The specific component (bot handler, MiniApp screen, wallet flow, payment flow) + task description
- **Optional**: Existing file paths, Vercel deployment logs, Telegram WebApp SDK version

## Output Contract
- One of:
  1. **Code deliverable**: Production-ready Python (bot) or React/TypeScript (MiniApp) with inline rationale for UX decisions
  2. **Deployment action**: Commands executed on Vercel, DO, or Runpod with pre/post verification steps
  3. **UX proposal**: Flow diagram or component specification with Steve Jobs filter applied (each screen justified)
