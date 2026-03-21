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

### Bot (Python, runs on Runpod)
```
telegram/telegram-bot/src/telegram_bot/
├── main.py              # Entry point, async lifecycle
├── handlers.py          # /start, /help, /link, /balance, /models, text→inference
├── config.py            # Pydantic Settings, reads .env
├── wallet.py            # Starknet wallet link/unlink, balance checks
├── relayer_client.py    # POST /api/v1/tasks to Relayer
├── payment.py           # Reserve → settle/fail lifecycle
├── callback_server.py   # aiohttp server receiving streamed results
└── models.py            # Pydantic schemas shared across modules
```

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
telegram/miniapp/vercel.json   # Vercel config
telegram/miniapp/.env.local    # Local env vars (VITE_RELAYER_URL, etc.)
telegram/telegram-bot/.env     # Bot token, relayer URL, callback port
```

## Integration Points

### Bot → Relayer (REST)
- Endpoint: `POST /api/v1/tasks`
- Auth: API key in header
- Payload includes `callback_url` for result delivery
- Response: task ID for tracking

### Relayer → Bot (Callback)
- Bot runs aiohttp callback server (default port configured in .env)
- Relayer pushes to `/callback/stream` (partial chunks) and `/callback/complete` (final result)
- Bot edits Telegram message in real-time as chunks arrive

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
