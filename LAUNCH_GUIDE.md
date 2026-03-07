# Smainer Live Test & Launch Guide

Complete step-by-step configuration for deploying Smainer frontend to Vercel and testing with Telegram bot integration.

---

## Phase 1: Telegram Bot Setup (30 minutes)

### Step 1.1: Create Telegram Bot with BotFather

1. Open Telegram and search for **@BotFather**
2. Start conversation: `/start`
3. Create new bot: `/newbot`
4. Name your bot: `Smainer AI` (or your choice)
5. Username: Must be unique, suggest `smainer_ai_bot` or `smainer_test_bot`
6. **BotFather will return your BOT TOKEN** — save it securely

**Example response:**
```
Done! Congratulations on your new bot. Here are your bot's details:

Name: Smainer AI
@smainer_ai_bot
token: 7123456789:ABCdefGHIjklMNOPqrsTUVwxyzABCDEfGHI

You will find Telegram's newest features here. Enjoy!
```

### Step 1.2: Configure Bot Settings

Still in BotFather, configure your bot:

```
/mybots
→ Select your bot
→ Bot Settings
  → Group Privacy: ENABLED (so bot works in groups)
  → Inline Mode: DISABLED (not needed yet)
  → Inline Feedback: DISABLED
```

### Step 1.3: Set Bot Description & Commands

In BotFather:

```
/setdescription
→ Select your bot
→ Enter description:
"Private AI that never stores your data. Send a prompt, get instant responses. No accounts needed."

/setcommands
→ Select your bot
→ Send these lines:
help - Show available commands
start - Start using Smainer AI
privacy - Privacy policy
pricing - How much it costs
```

### Step 1.4: Get Your Bot Webhook Ready

Your webhook will be: `https://your-vercel-domain.vercel.app/api/telegram`

Save:
- **BOT_TOKEN**: `7123456789:ABCdefGHIjklMNOPqrsTUVwxyzABCDEfGHI` (from BotFather)
- **WEBHOOK_URL**: Will be set after Vercel deployment

---

## Phase 2: Prepare Frontend for Vercel (1 hour)

### Step 2.1: Update Environment Variables

Create `.env.local` in `/home/smainer/Smainer/frontend/`:

```bash
# Telegram Bot Configuration
NEXT_PUBLIC_TELEGRAM_BOT_URL=https://t.me/smainer_ai_bot
TELEGRAM_BOT_TOKEN=7123456789:ABCdefGHIjklMNOPqrsTUVwxyzABCDEfGHI
TELEGRAM_WEBHOOK_URL=https://your-vercel-domain.vercel.app/api/telegram

# Starknet Configuration (testnet for now)
NEXT_PUBLIC_STARKNET_RPC=https://starknet-testnet.public.blastapi.io/rpc/v0_7
NEXT_PUBLIC_STARKNET_CHAIN_ID=SN_SEPOLIA

# Contract Addresses (deploy these first, see Phase 3)
NEXT_PUBLIC_CONTRACT_ADDRESS=0x0... (will update after deployment)
NEXT_PUBLIC_TOKEN_ADDRESS=0x0... (STRK testnet address)

# Relayer Configuration
NEXT_PUBLIC_RELAYER_API=https://relayer.smainer.io (production) or http://localhost:8000 (dev)

# Feature Flags
NEXT_PUBLIC_ENV=production
```

### Step 2.2: Verify Frontend Builds Locally

```bash
cd /home/smainer/Smainer/frontend

# Clean build
rm -rf .next node_modules/.cache
npm run build

# Should complete with: ✓ Built successfully
```

If errors, fix them before proceeding.

### Step 2.3: Create Vercel Account & Link Project

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Navigate to frontend directory
cd /home/smainer/Smainer/frontend

# Link to Vercel (creates vercel.json if needed)
vercel link
# Follow prompts:
# - Set project name: smainer-frontend
# - Framework: Next.js
# - Root directory: frontend
```

### Step 2.4: Configure Vercel Environment Variables

Via **Vercel Dashboard** (https://vercel.com/dashboard):

1. Go to your project: `smainer-frontend`
2. Settings → Environment Variables
3. Add each variable from `.env.local`:
   - `TELEGRAM_BOT_TOKEN` (secret)
   - `TELEGRAM_WEBHOOK_URL` 
   - `NEXT_PUBLIC_STARKNET_RPC`
   - `NEXT_PUBLIC_STARKNET_CHAIN_ID`
   - `NEXT_PUBLIC_TELEGRAM_BOT_URL`
   - `NEXT_PUBLIC_CONTRACT_ADDRESS`
   - `NEXT_PUBLIC_TOKEN_ADDRESS`
   - `NEXT_PUBLIC_RELAYER_API`
   - `NEXT_PUBLIC_ENV`

**Important**: Variables starting with `NEXT_PUBLIC_` are visible in browser; others are server-side only.

---

## Phase 3: Deploy to Vercel (20 minutes)

### Step 3.1: Deploy Frontend

```bash
cd /home/smainer/Smainer/frontend

# Deploy to Vercel
vercel deploy --prod

# Output will show:
# ✓ Production: https://smainer-frontend-xyz.vercel.app [in 45s]
```

**Save your production domain**: `https://smainer-frontend-xyz.vercel.app`

### Step 3.2: Update Telegram Webhook

Now that you have your Vercel domain:

1. Update `TELEGRAM_WEBHOOK_URL` in Vercel dashboard: `https://smainer-frontend-xyz.vercel.app/api/telegram`

2. Register webhook with Telegram (run once):

```bash
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"https://smainer-frontend-xyz.vercel.app/api/telegram\",
    \"secret_token\": \"your-webhook-secret-123\",
    \"allowed_updates\": [\"message\", \"callback_query\"]
  }"

# Response should be: {"ok":true,"result":true,"description":"Webhook was set"}
```

**Save your webhook secret for API route verification.**

### Step 3.3: Verify Deployment

```bash
# Test frontend is live
curl -s https://smainer-frontend-xyz.vercel.app | grep -i "privacy"
# Should return HTML containing "Privacy AI That Never Stores Your Data"

# Test Telegram webhook is registered
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo" | jq .
# Should show: "url": "https://smainer-frontend-xyz.vercel.app/api/telegram"
```

---

## Phase 4: Create Telegram API Route (30 minutes)

### Step 4.1: Create API Route for Telegram Webhook

Create `/home/smainer/Smainer/frontend/src/app/api/telegram/route.ts`:

```typescript
import { NextRequest, NextResponse } from 'next/server';

// Telegram Message Update type
interface TelegramUpdate {
  update_id: number;
  message?: {
    message_id: number;
    from: {
      id: number;
      is_bot: boolean;
      first_name: string;
    };
    chat: {
      id: number;
      type: 'private' | 'group';
      title?: string;
    };
    text: string;
    date: number;
  };
  callback_query?: {
    id: string;
    from: {
      id: number;
      first_name: string;
    };
    data: string;
  };
}

// Verify webhook secret
function verifyWebhookSecret(req: NextRequest): boolean {
  const secret = req.headers.get('X-Telegram-Bot-Api-Secret-Token');
  const expectedSecret = process.env.TELEGRAM_WEBHOOK_SECRET || 'your-webhook-secret-123';
  return secret === expectedSecret;
}

export async function POST(req: NextRequest) {
  try {
    // Verify webhook token
    if (!verifyWebhookSecret(req)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const update: TelegramUpdate = await req.json();
    const message = update.message;

    if (!message || !message.text) {
      return NextResponse.json({ ok: true });
    }

    const chatId = message.chat.id;
    const userId = message.from.id;
    const userText = message.text;
    const timestamp = message.date;

    // Route prompt to Relayer API
    const relayerUrl = process.env.NEXT_PUBLIC_RELAYER_API || 'http://localhost:8000';

    try {
      const taskResponse = await fetch(`${relayerUrl}/api/v1/tasks`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.TELEGRAM_BOT_TOKEN}`,
        },
        body: JSON.stringify({
          prompt: userText,
          tier: 'basic', // Default to basic tier for Telegram users
          user_id: userId,
          chat_id: chatId,
          timestamp,
        }),
      });

      const taskData = await taskResponse.json();
      const taskId = taskData.task_id;

      // Send acknowledgment to user
      await sendTelegramMessage(
        chatId,
        `⏳ Processing your request...\n\nTask ID: \`${taskId}\``,
        'MarkdownV2'
      );

      // Poll for result (timeout: 30 seconds)
      const maxAttempts = 10;
      for (let i = 0; i < maxAttempts; i++) {
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3s between polls

        const resultResponse = await fetch(`${relayerUrl}/api/v1/tasks/${taskId}/result`, {
          headers: {
            'Authorization': `Bearer ${process.env.TELEGRAM_BOT_TOKEN}`,
          },
        });

        if (resultResponse.status === 200) {
          const result = await resultResponse.json();
          const responseText = result.output || 'No response generated';

          // Send result to user
          await sendTelegramMessage(
            chatId,
            `✅ Response:\n\n${responseText}`,
            'MarkdownV2'
          );
          break;
        }

        if (i === maxAttempts - 1) {
          await sendTelegramMessage(
            chatId,
            '⚠️ Request timeout. Please try again.'
          );
        }
      }
    } catch (relayerError) {
      console.error('Relayer error:', relayerError);
      await sendTelegramMessage(
        chatId,
        '❌ Error processing request. Please try again later.'
      );
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

// Helper: Send Telegram message
async function sendTelegramMessage(
  chatId: number,
  text: string,
  parseMode: string = 'HTML'
): Promise<void> {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  if (!botToken) throw new Error('Missing TELEGRAM_BOT_TOKEN');

  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: parseMode,
    }),
  });

  if (!response.ok) {
    throw new Error(`Telegram API error: ${response.statusText}`);
  }
}

// GET endpoint for Telegram to verify webhook
export async function GET(req: NextRequest) {
  return NextResponse.json({
    status: 'Telegram webhook is active',
    timestamp: new Date().toISOString(),
  });
}
```

### Step 4.2: Add Webhook Secret to Vercel

```bash
# Update Vercel environment variable
vercel env add TELEGRAM_WEBHOOK_SECRET

# Enter: your-webhook-secret-123 (same as in curl command above)
```

### Step 4.3: Re-deploy Frontend with API Route

```bash
cd /home/smainer/Smainer/frontend
vercel deploy --prod
```

---

## Phase 5: Configure Starknet Contract (45 minutes)

### Step 5.1: Deploy Smart Contract to Testnet

```bash
cd /home/smainer/Smainer/contracts

# Set testnet RPC
export STARKNET_RPC_URL=https://starknet-testnet.public.blastapi.io/rpc/v0_7

# Build contract
scarb build

# Deploy contract (requires testnet STRK for gas)
sncast deploy \
  --contract smainer_SmainerContract \
  --constructor-args 0x01234567890 \
  --account testnet_account

# Output will show: Contract deployed at: 0x0abc123...
```

**Save contract address**: `0x0abc123...`

### Step 5.2: Fund Testnet Wallet

If you don't have testnet STRK:

1. Get testnet STRK from faucet: https://starknet-faucet.vercel.app/
2. Paste your wallet address from Argent X
3. Receive 0.5 testnet STRK

### Step 5.3: Update Contract Address in Vercel

1. Go to Vercel dashboard
2. Settings → Environment Variables
3. Update `NEXT_PUBLIC_CONTRACT_ADDRESS` with deployed address
4. Re-deploy: `vercel deploy --prod`

---

## Phase 6: Start Local Relayer (for testing)

### Step 6.1: Start Redis (Docker)

```bash
docker run -d -p 6379:6379 redis:7-alpine

# Verify Redis is running
redis-cli ping
# Should return: PONG
```

### Step 6.2: Start Relayer Service

```bash
cd /home/smainer/Smainer/relayer

# Activate Python env
source /home/smainer/Smainer/.venv/bin/activate

# Run relayer
python -m uvicorn src.relayer.main:app --host 0.0.0.0 --port 8000 --reload

# Should show:
# Uvicorn running on http://0.0.0.0:8000
```

### Step 6.3: Verify Relayer is Running

```bash
curl http://localhost:8000/health
# Should return: {"status": "healthy"}
```

---

## Phase 7: Test Telegram Integration (30 minutes)

### Step 7.1: Start Provider Daemon

```bash
cd /home/smainer/Smainer/provider

# Activate venv
source /home/smainer/Smainer/.venv/bin/activate

# Run provider
python -m provider.monitor --relayer-url http://localhost:8000

# Should show:
# [2026-03-07 14:30:15] Provider daemon started
# [2026-03-07 14:30:16] Detected GPU: RTX 4090 (24GB) → Tier: PRO
# [2026-03-07 14:30:17] Connected to relayer at http://localhost:8000
```

### Step 7.2: Test Telegram Bot Directly

Open Telegram and:

1. Find your bot: `@smainer_ai_bot` (or whatever you named it)
2. Send a message: `"Explain quantum computing in one sentence"`
3. Wait for response (should see "⏳ Processing your request...")
4. After 3-5 seconds, should see: `"✅ Response: [AI-generated response]"`

### Step 7.3: Test Multiple Prompts

Send several different prompts to verify:
- Text summarization works
- Code generation works
- Math problems are solved
- Follow-up questions work

**Log file to check errors**:
```bash
# Check Relayer logs
tail -f /tmp/relayer.log

# Check Provider logs
tail -f /tmp/provider.log
```

---

## Phase 8: End-to-End Testing Checklist

### Functionality Tests

- [ ] **Landing page loads** (< 3s on 3G)
  ```bash
  curl -w "%{time_total}\n" -o /dev/null -s https://smainer-frontend-xyz.vercel.app
  ```

- [ ] **Privacy AI messaging is clear** (no crypto jargon)
  ```bash
  curl -s https://smainer-frontend-xyz.vercel.app | grep -i "never stores"
  ```

- [ ] **/how-it-works page loads**
  ```bash
  curl -s https://smainer-frontend-xyz.vercel.app/how-it-works | grep -i "VRAM"
  ```

- [ ] **Telegram bot responds** (< 5s per prompt)
  - Send 10 prompts, measure response time

- [ ] **Provider daemon joins network**
  - Check relayer logs: `Connected node: provider-001`

- [ ] **Task routes to correct tier**
  - Send task, verify relayer assigns to PRO tier node (if Pro GPU available)

- [ ] **Payment settles on-chain**
  - Check contract state: verify STRK transferred from escrower to provider wallet

### Security Tests

- [ ] **Telegram webhook secret verified**
  ```bash
  curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo" | jq .url
  # Should match your Vercel domain
  ```

- [ ] **No secrets in git**
  ```bash
  git log --all --full-history -S "TELEGRAM_BOT_TOKEN" -- .
  # Should return nothing
  ```

- [ ] **Environment variables on Vercel are secret**
  - Vercel dashboard shows `***` for sensitive vars

- [ ] **API endpoints require authentication**
  - Test without Bearer token should get 401

### Performance Tests

- [ ] **Provider daemon startup** (< 10s)
- [ ] **Relayer API latency** (< 100ms per request)
- [ ] **Telegram response time** (< 5s, including LLM inference)
- [ ] **Frontend lighthouse score** (> 80)

---

## Phase 9: Troubleshooting

### Issue: Telegram webhook not receiving messages

**Diagnosis**:
```bash
# Check webhook registration
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo" | jq .

# Look for:
# - "url": matches your Vercel domain
# - "has_custom_certificate": false
# - "pending_update_count": 0 (or low)
```

**Fix**:
- Re-register webhook with correct URL
- Restart Vercel deployment
- Wait 30 seconds for propagation

### Issue: Relayer can't connect to contract

**Diagnosis**:
```bash
# Check contract address is correct
echo $NEXT_PUBLIC_CONTRACT_ADDRESS

# Test contract is deployed
curl "https://starknet-testnet.public.blastapi.io/rpc/v0_7" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"starknet_getClassAt","params":["block_id":{"block_number":1},"contract_address":"0x0abc..."]}'
```

**Fix**:
- Verify contract address in Vercel matches deployed address
- Re-deploy contract if address changed
- Clear browser cache (NEXT_PUBLIC_ vars are baked in builds)

### Issue: Provider daemon can't detect GPU tier

**Diagnosis**:
```bash
# Check NVIDIA drivers
nvidia-smi

# Check pynvml installation
python -c "from pynvml import nvmlInit; nvmlInit(); print('pynvml OK')"
```

**Fix**:
- Install NVIDIA drivers: `sudo apt install nvidia-driver-550`
- On Windows (WSL2): Follow [WSL2 NVIDIA guide](https://docs.nvidia.com/cuda/wsl-user-guide/)
- Reinstall pynvml: `pip install --upgrade nvidia-ml-py`

### Issue: Telegram bot times out (> 30s response)

**Diagnosis**:
- Check Relayer is running: `curl http://localhost:8000/health`
- Check Provider daemon is connected: grep "Connected node" in relayer logs
- Check LLM inference time (depends on model size)

**Fix**:
- Increase polling timeout in `/api/telegram/route.ts` from 30s to 60s
- Scale Relayer horizontally (deploy more instances)
- Use faster model (smaller LLM) if available

---

## Phase 10: Go Live Checklist

Before announcing to users:

### Pre-Launch
- [ ] All tests passing (see Phase 8)
- [ ] At least 3 provider nodes running stably for 24h
- [ ] Telegram bot responding reliably
- [ ] Costs and pricing clearly documented
- [ ] Support contact published (Discord/email)
- [ ] Announce copy written (Discord, Twitter, TG)

### Launch Day (Live Test with Beta Users)

1. **Hour 0**: Deploy all components
2. **Hour 1**: Test with 10 internal users
3. **Hour 2**: If stable, invite 100 community beta testers
4. **Hour 3+**: Monitor metrics, scale if needed

### Monitoring During Live Test

**Run these continuously**:

```bash
# 1. Monitor Telegram message volume
watch 'curl -s http://localhost:8000/metrics | grep telegram_messages'

# 2. Check provider node count
watch 'curl -s http://localhost:8000/api/v1/nodes | jq ".count"'

# 3. Monitor Starknet settlement success
watch 'curl -s http://localhost:8000/api/v1/settlement | jq ".success_rate"'

# 4. Check Relayer latency
watch 'curl -w "%{time_total}s\n" -o /dev/null -s http://localhost:8000/health'
```

---

## Summary Checklist

- [ ] **Phase 1**: Telegram bot created, token saved
- [ ] **Phase 2**: Frontend ready, `.env.local` configured
- [ ] **Phase 3**: Frontend deployed to Vercel, domain saved
- [ ] **Phase 4**: Telegram API route created, webhook registered
- [ ] **Phase 5**: Smart contract deployed, address saved
- [ ] **Phase 6**: Redis + Relayer running locally
- [ ] **Phase 7**: Telegram bot responding end-to-end
- [ ] **Phase 8**: All tests passing
- [ ] **Phase 9**: Troubleshooting issues resolved
- [ ] **Phase 10**: Ready for live launch

---

## Quick Start (if you already have components running)

```bash
# 1. Deploy frontend
cd frontend && vercel deploy --prod

# 2. Register Telegram webhook
curl -X POST "https://api.telegram.org/bot$(cat .env.local | grep TELEGRAM_BOT_TOKEN | cut -d= -f2)/setWebhook" \
  -d url=https://your-vercel-domain.vercel.app/api/telegram

# 3. Start Relayer
python -m uvicorn src.relayer.main:app --port 8000 &

# 4. Start Provider
python -m provider.monitor &

# 5. Test
curl http://localhost:8000/health
```

**You're live!** 🚀
