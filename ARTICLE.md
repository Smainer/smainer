# Smainer: Privacy AI That Never Stores Your Data

## The Simple Answer

Smainer is **Privacy AI via Telegram**. Send a prompt, get an AI response, your data gets completely discarded. No central servers, no data storage, no accounts needed.

**For Users:** Message @smainer_ai_bot → Get private AI responses  
**For GPU Owners:** Share compute power → Earn STRK tokens passively

Think of it as Uber for AI: users need AI compute, GPU owners provide it, Smainer matches them. Except your ride request (prompt) gets shredded after the ride ends.

---

## What Are We Mining? STRK Tokens Only

**You mine STRK** — Starknet's native L2 token. **Not a custom Smainer token.**

Why STRK instead of creating our own token?

1. **Real Liquidity**: STRK trades on Binance, OKX, major exchanges
2. **No Speculation**: Users pay with established currency, miners earn established currency  
3. **Immediate Utility**: Withdraw earnings and trade instantly
4. **Regulatory Clarity**: Building on established Starknet economy, not launching securities

**Bottom Line:** You earn actual STRK that you can withdraw and trade immediately. No made-up tokens, no vesting, no speculation required.

### How Providers Get Paid

When a task completes, the contract splits the escrowed STRK:

| Recipient | Share |
|-----------|-------|
| Provider (base payout) | 85% |
| Provider (gas subsidy) | 3% |
| Smainer Treasury | 12% |

The 3% gas subsidy means providers never pay out-of-pocket for transaction fees. This is enforced in Cairo — not an off-chain promise.

---

## The Three Tiers

Not all GPUs are equal. Smainer detects your hardware and assigns a tier:

| Tier | GPU Example | VRAM | Reward Multiplier |
|------|-------------|------|-------------------|
| **Basic** | RTX 4060, RTX 3090 | < 24 GB | 1.0x |
| **Pro** | RTX 4090, A6000 | 24 GB+ | 2.2x |
| **Premium** | RTX 5090 | 32 GB GDDR7 | 3.5x |

An RTX 5090 mining Premium-tier tasks earns 3.5x what a basic node earns for the same work. The multiplier is enforced on-chain — the contract calculates `adjusted_reward = base_amount * tier_multiplier` before escrowing funds.

---

## Privacy-First AI via Telegram

This is the core product for users who just want AI without surveillance.

**How it works:**

1. Open Telegram. Message `@smainer_ai_bot`.
2. Send a prompt ("Explain quantum computing simply").
3. The Relayer finds an available compute node, routes your prompt to it.
4. The node runs inference (Llama, Mistral, etc.), signs the result cryptographically.
5. The result comes back to your Telegram chat.

**What makes it different:**

- **No prompts stored.** The compute node processes your request and discards it. The Relayer routes traffic but doesn't store payloads.
- **No central server.** There's no "Smainer server" running your inference. It's a coordination layer (the Relayer) connecting you to independent compute nodes.
- **No app download.** Telegram is the interface. One billion people already have it.
- **Scales infinitely.** 1,000 simultaneous users? The Relayer finds 1,000 available nodes. No capacity planning needed.

For power users who want custom compute jobs (specific resource requirements, on-chain task tracking), there's also a wallet-connected submission form on the web dashboard.

---

## The Architecture

```
Telegram User / Web Dashboard
          |
          v
    Relayer (FastAPI + Redis)
    - Routes tasks to nodes
    - Verifies cryptographic signatures
    - Batches proofs for on-chain submission
          |
    ------+------
    |            |
    v            v
Provider A    Provider B    ...
(GPU daemon)  (GPU daemon)
    |            |
    v            v
    Starknet L2 Smart Contract
    - Escrow (holds STRK until task completes)
    - Payout (85% provider + 3% gas + 12% treasury)
    - Tier multipliers (enforced on-chain)
```

### Key Design Decisions

**Why Starknet?** Gas costs are a fraction of Ethereum mainnet. The contract submits proofs per task batch — on mainnet this would be prohibitively expensive. Starknet's ZK-rollup architecture also aligns with compute verification.

**Why ERC-20 agnostic?** The contract doesn't hardcode a token. This lets us start with STRK and optionally migrate to a native token later without redeploying the contract.

**Why a Relayer instead of pure P2P?** Pure decentralization would require nodes to discover each other and negotiate directly. The Relayer is a coordination layer — it doesn't touch funds (the contract handles that) and it doesn't store data (compute nodes handle that). It's the minimal centralized piece needed for practical UX.

**Why WSL2 optimization?** Most gaming PCs run Windows. WSL2 is the bridge that gives the Smainer daemon direct GPU access via NVIDIA Container Toolkit without requiring users to switch operating systems.

---

## What's Built

| Component | Status | Details |
|-----------|--------|---------|
| **Smart Contract** (Cairo) | Deployed on testnet | Provider registry, tiered escrow, proof verification, fee splits |
| **Relayer** (FastAPI + Redis) | Working | Job scheduling, tier-aware node matching, signature verification, batch submission |
| **Provider Daemon** (Python) | Working | Auto-detects GPU tier, VRAM, WSL2; sandboxed execution; cryptographic signing |
| **Frontend** (Next.js) | Working | Dual-sided landing page, tier pricing, dashboard, task submission |
| **Telegram Bot** | Working | `@smainer_ai_bot` — routes prompts to nodes, handles STRK micropayments |
| **Telegram Mini App** | Working | In-chat AI interface with wallet integration |

---

## What's Next

1. **Mainnet deployment** — Contract and Relayer pointing at Starknet mainnet instead of Sepolia testnet.
2. **On-chain signature verification** — Currently the Relayer verifies provider signatures. Moving this on-chain makes the system fully trustless.
3. **One-line installer** — `curl -sSL install.smainer.com | sh` to get a provider node running in 60 seconds.
4. **Real-time stats** — Dashboard currently shows simulated metrics. Connecting to live Relayer API data.
5. **Model marketplace** — Let providers advertise which AI models they have loaded, so demanders can target specific models.

---

## The Economics in Plain English

**If you're a miner:** You install the daemon, it detects your GPU, and you start earning STRK for every AI inference task your machine completes. Better GPU = higher tier = more STRK per task. The 3% gas subsidy means you never lose money on transaction fees.

**If you're a user:** You message a Telegram bot and get AI responses. Your prompts are processed on a random compute node and never stored. You pay small amounts of STRK per prompt (configurable, currently ~0.1 STRK). No accounts, no subscriptions, no data collection.

**If you're an investor/partner:** Smainer captures 12% of every task as a treasury fee. More tasks = more revenue. The tiered multiplier system incentivizes high-end hardware to join the network, which attracts more demanding (and more lucrative) AI workloads, creating a flywheel.

---

*Smainer — Decentralized compute for tomorrow. Privacy-first AI today.*
