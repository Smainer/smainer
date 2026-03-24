# Smainer Website Copy v2 — Full Rewrite

> Generated: 2026-03-24
> Status: REVIEWED & APPROVED — Ready for frontend implementation
> Pages: 8 public pages (Homepage, Products, Roadmap, Pricing, Technology, Windows, How It Works, Providers, About)

---

## Page Architecture

| Route | Page Title | Theme |
|-------|-----------|-------|
| `/` | Home | Short hero + 3 value props + network proof + 3 paths |
| `/products` | Products | Multi-product platform showcase |
| `/roadmap` | Roadmap | Progressive decentralization timeline |
| `/pricing` | Pricing | Provider & user economics |
| `/technology` | Technology | Starknet advantages + private compute architecture |
| `/windows` | Windows Setup | WSL2 GPU passthrough guide |
| `/how-it-works` | How It Works | Task lifecycle + PubSub coordination engine |
| `/providers` | Providers | Merged provider onboarding (benefits → requirements → install → register → earn) |
| `/about` | About | Mission, open source, team |
| `/docs` | Docs | API reference (no changes) |

### Navigation Structure

```
┌─ Products ▼
│  ├─ Privacy AI Bot
│  ├─ GPU Marketplace
│  └─ Telegram MiniApp
├─ How It Works
├─ Pricing
├─ Technology ▼
│  ├─ Starknet Advantages
│  ├─ Private Compute
│  └─ Architecture
├─ Windows Setup
├─ Providers
├─ Roadmap
└─ About
```

Footer: Docs, Dashboard, GitHub, Discord, Twitter

### Redirects
- `/download` → `/windows`
- `/create` → `/providers`
- `/telegram-bot` → `/products`
- `/providers/onboarding` → `/providers`

---

# PAGE 1: HOMEPAGE `/`

## Section 1: Hero

**Headline:** Run AI Tasks Privately

**Subheadline:** Decentralized compute with zero data retention. Pay per task, keep 88%.

**Paragraph:** Submit AI tasks through Telegram. GPU providers earn 88% of task fees. Your data never touches centralized servers.

**CTAs:**
- [PRIMARY_CTA: Try Privacy AI] → Telegram @smainer_ai_bot
- [SECONDARY_CTA: Start Earning] → /providers

## Section 2: Three-Column Value Props

**Column 1: Private Compute**
Your prompts run on distributed GPUs, then get completely discarded. [Learn more →](/technology)

**Column 2: 88% Provider Revenue**
GPU owners keep 85% base rate plus 3% gas subsidies. Highest in the industry. [See breakdown →](/pricing)

**Column 3: Windows GPU Support**
RTX 4060+ cards earn automatically. Keep your Windows desktop. [Get started →](/windows)

## Section 3: Network Proof

[LIVE_METRICS from relayer API — OR qualitative trust signals if API not ready:]
- **Open Source** — All code public and auditable
- **On-Chain Verified** — Every task settled on Starknet
- **Zero Data Retention** — Prompts discarded after execution

## Section 4: Three Paths Forward

**AI Users**
Message @smainer_ai_bot for instant private AI responses.
[BUTTON: Try Now] → Telegram

**GPU Providers**
Turn idle graphics cards into verifiable income streams.
[BUTTON: Start Earning] → /providers

**Developers**
Build on decentralized compute infrastructure via API.
[BUTTON: Read Docs] → /docs

---

# PAGE 2: PRODUCTS `/products`

## Privacy AI Bot

**Private AI through Telegram. Zero accounts, zero retention.**

Message @smainer_ai_bot with any prompt. Get responses from frontier models. Your conversation gets permanently deleted after each response. No data collection, no training on your inputs, no corporate surveillance.

**Key differentiator:** Complete data disposal after every interaction.

[CTA: Message @smainer_ai_bot] → Telegram

## GPU Marketplace

**Web dashboard for compute task submission with wallet escrow.**

Connect your Starknet wallet to submit AI tasks, image generation, or code execution jobs. Pay only for successful completion. Tier-based pricing rewards premium hardware. On-chain escrow protects both parties.

**Key differentiator:** Blockchain-enforced payment protection with no subscriptions.

[CTA: Open Dashboard] → /dashboard

## Telegram MiniApp

**In-chat AI interface with wallet integration and NFT rewards.**

Access AI models directly within Telegram chats. Connect wallets, select models, mint achievement NFTs. Full Web3 functionality without leaving the messaging interface.

**Key differentiator:** Web3 AI interactions inside familiar chat environments.

[CTA: Launch MiniApp] → Telegram WebApp

## Model Marketplace

**Providers advertise loaded models, users target specific capabilities.**

GPU providers will advertise which models they have loaded (Llama 3.1, Mistral Large, etc.). Users can route tasks to specific model clusters for specialized use cases like coding, creative writing, or analysis.

Coming Q2 2026

## Custom Compute

**Arbitrary code execution in sandboxed environments with resource limits.**

Submit Python scripts, data processing workflows, or computational research jobs. Providers execute code in isolated containers with CPU/memory/time limits. Perfect for batch processing and scientific computing.

Coming Q3 2026

---

# PAGE 3: ROADMAP `/roadmap`

## Progressive Decentralization Timeline

### Phase 0: Transparent Single Relayer
**Status:** [CURRENT]

- Verifiable task assignments via SHA-256 commitment hashes
- Public audit endpoint for every task assignment
- Merkle root commitments recorded on Starknet
- Zero infrastructure changes needed for existing providers

**What this means:** Full transparency without decentralization complexity. Anyone can audit task distribution fairness.

### Phase 1: Active-Standby Multi-Relayer
**Status:** [Q1-Q2 2026]

- Eliminates single point of failure with multiple relayer instances
- Redis Sentinel clustering across 3 geographic nodes
- Leader election with sticky WebSocket sessions
- Automatic failover under 30 seconds

**What this means:** High availability infrastructure. Providers stay connected during relayer maintenance.

### Phase 2: Staked Multi-Relayer
**Status:** [Q2-Q3 2026]

- 3-7 staked relayer operators governed by smart contract
- RelayerRegistry, ProviderStaking, and TaskCoordination contracts
- On-chain recording of all task assignments
- Provider multi-connect for redundancy

**What this means:** Economic security through staking. Relayer operators have skin in the game.

### Phase 3: Full Decentralization
**Status:** [Q3+ 2026]

- Consensus-based task distribution without central coordination
- Provider-to-provider task routing and communication
- Potential libp2p integration for peer discovery
- Relayers become infrastructure providers, not gatekeepers

**What this means:** True P2P compute network. No central points of control or failure.

---

# PAGE 4: PRICING `/pricing`

## For GPU Providers: 88% Total Revenue

**Base Rate: 85%** of task fees go directly to providers
**Gas Subsidy: 3%** additional payment for Starknet transaction costs
**Total Provider Share: 88%** — enforced by Cairo smart contract

### Competitor Comparison

| Network | Provider Revenue |
|---------|-----------------|
| **Smainer** | **88%** |
| Vast.ai | ~80% |
| Akash Network | ~75% |
| Render Network | ~70% |
| io.net | 65-70% |

### Tier System

| Tier | Multiplier | Hardware |
|------|-----------|----------|
| Basic | 1.0x | RTX 4060, RTX 4060 Ti, RTX 4070 |
| Pro | 2.2x | RTX 4080, RTX 4090, RTX 4080 Super |
| Premium | 3.5x | RTX 5090, H100, A100 |

The 3% gas subsidy covers your Starknet transaction costs. This isn't an off-chain promise — it's enforced in the smart contract code.

[CTA: Calculate Earnings] → /providers

## For AI Users: Pay-Per-Task, Not Subscriptions

**Zero idle billing.** Pay only when your tasks complete successfully.

### Cost Comparison vs. Subscription Services

| Task Type | Smainer | Subscription Model | Savings |
|-----------|---------|-------------------|---------|
| Text Summary | $0.02 | $0.83-1.67 | 97-99% |
| Code Generation | $0.08 | $2.67-5.33 | 97-99% |
| Complex Reasoning | $0.15 | $4.00-8.00 | 96-98% |

*Subscription costs calculated as monthly fee divided by average tasks per power user*

### Blockchain Costs
**Starknet gas:** ~$0.001 per transaction
**Task escrow:** Locked until completion, then released automatically
**No hidden fees:** Contract code is open source and auditable

[CTA: Try Privacy AI] → Telegram @smainer_ai_bot

---

# PAGE 5: TECHNOLOGY `/technology`

## Hero

**Compute Settlement on Starknet. Privacy by Architecture.**

Smainer settles GPU compute tasks on Starknet L2 — where zero-knowledge proofs are native, gas fees are negligible, and fee splits are enforced by Cairo smart contracts. No trust required. No data retained.

## Section A: Why Starknet

Most compute networks settle on Ethereum mainnet. That's expensive. A single proof submission on L1 costs $2-8 in gas. Starknet batch-proves thousands of transactions for a fraction of a cent each — a 1000x+ gas fee reduction.

This isn't just cheaper. It changes what's economically viable.

Smainer submits batch proofs of compute task completions constantly. Every task result, every fee split, every provider payout — all verified on-chain. On Ethereum L1, this would cost more than the compute itself. On Starknet, it's negligible.

[DIAGRAM: Side-by-side — ETH L1 gas per proof vs. Starknet L2 gas per proof, 1000x delta]

**ZK-native alignment.** Starknet is built on STARK proofs. It doesn't bolt on zero-knowledge verification as an afterthought — it's the foundation. Compute verification maps directly to Starknet's proving architecture.

**Fast finality.** Tasks settle in seconds. Not 12-second block times with variable confirmation depths. Providers get paid quickly. Users get results quickly.

**Integer math. No rounding errors.** All fee calculations use basis points (BPS) with a denominator of 10,000. No floating point. No rounding exploits:

```
TREASURY_FEE_BPS  = 1200    // 12% → Treasury
GAS_SUBSIDY_BPS   =  300    // 3%  → Provider gas rebate
PROVIDER_BASE     = 8500    // 85% → Provider
                             // Provider total: 88%
BPS_DENOMINATOR   = 10000
```

**ERC-20 agnostic.** The contract works with any Starknet ERC-20 token. Currently STRK. The token address is a parameter, not a hardcoded dependency.

## Section B: Privacy by Architecture

Smainer doesn't promise privacy through policy. It enforces it through architecture. There is no place where your data accumulates, because no component retains it.

**No prompts stored. Anywhere.**

The relayer routes tasks. It does not store prompt content after delivery. Provider nodes process tasks in isolated sandboxes. After execution completes, the sandbox is destroyed. The result returns to the user. That's it.

[DIAGRAM: Linear flow — User → Relayer (route only) → GPU Node (sandbox) → Result → User. Each step annotated with data retention: "none"]

**Sandboxed execution.** Every task runs in its own isolated directory:

- Unique temporary directory per task, `chmod 700` — owner-only access
- `SIGKILL` on timeout — hard termination
- Process tracking with guaranteed cleanup within 5 seconds
- Network disabled by default during execution

**Result signing.** Every completed task result is signed with the provider's Starknet ECDSA private key. The smart contract verifies this signature before releasing payment. Forged results don't settle.

**Cryptographic proof chain:**

```
Task Created → ECDSA Signed Result → Pedersen Hash Verification →
Signature Replay Protection → Atomic Payment Split → On-Chain Event
```

No component trusts another. The contract verifies. The math settles.

## Section C: On-Chain Enforcement

The SmainerContract is a Cairo smart contract deployed on Starknet. It handles provider registration, task escrow, proof verification, and atomic fee distribution. The code is public. Every parameter is auditable.

**Provider Registry:** Providers self-register by submitting their Starknet public key. Three tiers, enforced on-chain:

| Tier | ID | Multiplier | Target Hardware |
|------|---|-----------|----------------|
| Basic | 1 | 1.0x | RTX 4060, RTX 3090 |
| Pro | 2 | 2.2x | RTX 4090, A6000 (24GB+) |
| Premium | 3 | 3.5x | RTX 5090, A100 (32GB+) |

**Task Lifecycle:**

```
1. User calls create_tiered_task() → STRK escrowed
2. Relayer identifies optimal provider (tier-aware)
3. Provider executes, signs result with ECDSA key
4. Provider calls submit_proof_and_claim()
5. Contract verifies ECDSA signature + Pedersen hash
6. Atomic fee split: 85% + 3% → Provider, 12% → Treasury
7. If ANY transfer fails, entire transaction reverts
```

**Security stack:** OpenZeppelin OwnableComponent, PausableComponent, UpgradeableComponent. Signature replay protection. CEI pattern on all state transitions.

**Zero hidden parameters.** Provider selection, tier multipliers, fee percentages — all readable on-chain.

[CTA: Read the Contract → GitHub]

---

# PAGE 6: WINDOWS SETUP `/windows`

## Hero

**Your Windows Rig. Starknet Compute Node.**

WSL2 gives your GPU a Linux runtime without touching your Windows install. Full CUDA passthrough. Full STRK earnings. No dual-boot. No VM overhead.

## The Problem

You built a machine for performance — RTX 5090, custom loop cooling, NVMe storage. It runs Windows because that's where your games, tools, and workflows live.

Smainer's provider daemon runs on Linux. NVIDIA Container Toolkit needs a Linux kernel. Traditionally, that means dual-boot or a dedicated machine.

WSL2 eliminates that tradeoff.

## The Solution: WSL2 Native GPU Access

Windows Subsystem for Linux 2 runs a real Linux kernel inside Windows with direct GPU passthrough. `nvidia-smi` inside WSL2 sees your GPU at full capability. CUDA works. cuDNN works. The daemon runs at near-native performance.

Your Windows desktop stays exactly as it is. Games, apps, everything — untouched.

[DIAGRAM: Windows 11 Host → WSL2 Linux Kernel → NVIDIA GPU Passthrough → Smainer Provider Daemon]

## Five Steps. One Reboot.

```powershell
# Step 1: Enable WSL2 (PowerShell, Admin)
wsl --install -d Ubuntu-22.04
# Reboot once.
```

```bash
# Step 2: Inside WSL2 — Install NVIDIA Container Toolkit

# Step 3: Run the Smainer one-line installer
curl -sSL install.smainer.com | sh

# Step 4: Daemon auto-detects your GPU
# Output: "Detected RTX 4090 24GB GDDR6X → Pro Tier (2.2x multiplier)"

# Step 5: Connected to relayer. Earning STRK.
```

[ANIMATION: Terminal session — GPU detection, tier assignment, WebSocket connection, first heartbeat]

## Hardware Tiers

Tier assignment is automatic. The daemon reads VRAM, compute capability, and model identification at startup.

| GPU | VRAM | Tier | Multiplier |
|-----|------|------|-----------|
| RTX 5090 | 32GB GDDR7 | Premium | 3.5x |
| RTX 4090 | 24GB GDDR6X | Pro | 2.2x |
| A6000 | 48GB GDDR6 | Pro | 2.2x |
| RTX 4060 Ti | 16GB GDDR6 | Basic | 1.0x |
| RTX 3090 | 24GB GDDR6X | Basic | 1.0x |

## What Runs on Your Machine

The provider daemon is a Python process running inside WSL2. It maintains a persistent WebSocket connection to the relayer and executes tasks in sandboxed environments.

**Sandbox isolation:** `/var/lib/smainer-provider/sandbox`, permissions `2750`, unique subdirectory per task with `chmod 700`, SIGKILL on timeout, 5-second cleanup guarantee.

**Resource allocation:** Auto-detects host resources, limits to 50% by default. Example on 32GB / 8-core: `MemoryMax=16G`, `CPUQuota=400%`. Windows workloads get the other half.

**Authentication:** ECDSA signature: `authenticate_node:{node_id}:{address}:{timestamp}`. Every task result also signed.

## Deploy Your Node

Your hardware is already paid for. Put it to work.

[CTA: Install on WSL2]
[CTA: View Hardware Requirements → anchor to tiers]

---

# PAGE 7: HOW IT WORKS `/how-it-works`

## Hero

**From Prompt to Payment. Every Step Verified.**

A task enters. A GPU processes it. A smart contract settles it. Data is discarded. Here's exactly how.

## Section A: For AI Users

### Submit a Task. Get a Result. Keep Your Data.

You don't create an account. You don't upload files to a server. You send a prompt — through Telegram or the web dashboard — and receive a result.

```
1. Send prompt → @smainer_ai_bot on Telegram (or web dashboard)
2. STRK is escrowed in the SmainerContract
3. Relayer matches your task to an available GPU node
   └─ Tier-aware: your task goes to hardware that can handle it
4. GPU node executes in an isolated sandbox
   └─ Unique directory, network disabled, SIGKILL on timeout
5. Result signed with provider's Starknet ECDSA key
6. Smart contract verifies signature → releases payment atomically
   └─ 88% to provider, 12% to treasury
7. All task data discarded — sandbox destroyed
```

[DIAGRAM: Horizontal flow — User → STRK escrowed → Relayer routes → GPU executes → Result signed → Contract settles → Data gone]

**Why Telegram?** 1B+ users already have it installed. No app download. No signup form. No wallet connection required to submit your first task.

**What the relayer sees:** Task metadata (type, tier requirement, token amount). Not your prompt content.

**What the provider sees:** The task payload during execution only. After the result is returned, the sandbox is destroyed.

## Section B: For GPU Providers

### Install. Connect. Earn.

Your machine runs the provider daemon. The daemon maintains a WebSocket connection to the relayer. When a task matches your hardware tier, it arrives over that connection.

```
1. Install provider daemon (Linux / WSL2 / Docker)
2. Daemon auto-detects GPU → assigns tier (Basic/Pro/Premium)
3. Registers with relayer via authenticated WebSocket
   └─ ECDSA signature: authenticate_node:{node_id}:{address}:{timestamp}
4. Heartbeats sent every 90 seconds (CPU, memory, active tasks)
5. Task assigned → matched to hardware tier and availability
6. Execute in sandboxed environment
   └─ /var/lib/smainer-provider/sandbox/{task_id}/
7. Sign result with Starknet key → return to relayer
8. Smart contract verifies → 88% STRK released to your address
```

[DIAGRAM: Daemon ←WebSocket→ Relayer. Task → sandbox → result signed → payment on-chain]

**Tier economics:**

| Tier | Multiplier | Revenue | Hardware |
|------|-----------|---------|----------|
| Basic | 1.0x | 88% | RTX 4060, RTX 3090 |
| Pro | 2.2x | 88% × 2.2 | RTX 4090, A6000 |
| Premium | 3.5x | 88% × 3.5 | RTX 5090, A100 |

[CTA: Deploy Your Node → /providers]

## Section C: The Coordination Engine

### Real-Time Orchestration via Redis Streams

Every task, node, and system state change propagates through a pub/sub event bus in under 100ms. No polling. No missed state transitions.

Behind the relayer is a coordination engine built on Redis Streams. It replaces traditional request-response polling with event-driven architecture.

**Why Redis Streams?**

- **Persistent event log** — events aren't lost after consumption. Persist for replay and debugging.
- **Consumer groups** — multiple independent consumers read from the same stream.
- **Acknowledgment tracking** — unacknowledged events are automatically redelivered.
- **TTL management** — events auto-expire after 7 days.
- **Sub-millisecond latency** — Redis is in-memory. No disk I/O on the critical path.

[DIAGRAM: Three streams (events:tasks, events:nodes, events:system) → three consumer groups (schedulers, monitors, analytics)]

### Three Streams. Three Concerns.

```
events:tasks    → Task lifecycle (submitted, assigned, started, completed, failed, cancelled, timeout)
events:nodes    → Node lifecycle (connected, disconnected, heartbeat, overloaded, recovered)
events:system   → Orchestration  (schedule_requested, queue_starvation, system_health_check)
```

| Consumer Group | Stream | Purpose |
|---------------|--------|---------|
| schedulers | events:tasks | Fair queue scheduling decisions |
| monitors | events:nodes | Node health, overload detection |
| analytics | events:system | Metrics collection, capacity planning |

### 15 Event Types. Full Lifecycle Coverage.

**Task events (7):**
- TASK_SUBMITTED → New task enters queue
- TASK_ASSIGNED → Matched to a node
- TASK_STARTED → Execution begins
- TASK_COMPLETED → Result returned with execution metrics
- TASK_FAILED → Error code, retry count, retry decision
- TASK_CANCELLED → User or system cancelled
- TASK_TIMEOUT → Exceeded execution deadline

**Node events (5):**
- NODE_CONNECTED → New node registered with hardware tier
- NODE_DISCONNECTED → Triggers task reassignment
- NODE_HEARTBEAT → Periodic health update
- NODE_OVERLOADED → Temporarily removed from scheduling
- NODE_RECOVERED → Re-entered into scheduling pool

**System events (3):**
- SCHEDULE_REQUESTED → Scheduling cycle triggered
- QUEUE_STARVATION → No available nodes alert
- SYSTEM_HEALTH_CHECK → Periodic diagnostics

### Operational Guarantees

| Property | Implementation |
|----------|---------------|
| Delivery | At-least-once via consumer group acknowledgment |
| Ordering | Per-stream ordering guaranteed |
| Persistence | 7-day TTL with automatic cleanup |
| Backpressure | Stream max 10,000 entries with approximate trimming |
| Recovery | Unacknowledged messages redelivered |
| Startup | Consumer groups auto-created |

## Page CTA

**The Network is Live.**

[CTA: Submit a Workload → Telegram @smainer_ai_bot]
[CTA: Deploy Your Node → /providers]

---

# PAGE 8: PROVIDERS `/providers`

## Hero

# Earn STRK with Your GPU

Turn idle hardware into verified compute nodes. Process privacy AI tasks that self-destruct after completion. Withdraw earnings anytime.

- 88% of task revenue (85% base + 3% gas subsidy enforced in Cairo)
- Automatic tier detection: Basic 1.0x • Pro 2.2x • Premium 3.5x
- Use hardware you already own — no upfront cost
- Half-resource mode: daemon uses 50% of your machine by default

## Hardware Requirements

**Minimum specs:** RTX 4060 • 8GB VRAM • 16GB RAM • 10 Mbps stable connection

| Tier | GPU Examples | VRAM | Multiplier | Est. Daily STRK |
|------|-------------|------|-----------|----------------|
| Basic | RTX 4060, RTX 3090 | 8-12 GB | 1.0x | $20-$50 |
| Pro | RTX 4090, A6000 | 16-24 GB | 2.2x | $80-$180 |
| Premium | RTX 5090, H100 | 32+ GB | 3.5x | $180-$420 |

Higher VRAM processes larger AI models for more STRK per task. Earnings depend on network demand.

## Installation

Choose your deployment path:

**Windows (WSL2)**
Native Windows GPU performance with WSL2 backend. Automatic setup script.
→ [View Windows Guide](/windows)

**Linux**
Direct installation on Ubuntu/Debian. One command:
```bash
curl -sSL install.smainer.io | sudo bash
```

**Docker**
Container-based deployment with GPU passthrough:
```bash
docker run -d --gpus all smainer/provider:latest
```

## On-Chain Registration

1. **Connect Starknet wallet** (Argent X or Braavos)
2. **Register as provider** on SmainerContract
3. **Verify hardware tier** — automatic VRAM detection
4. **Start receiving tasks** — daemon connects to relayer WebSocket

## Earnings

**Basic tier (RTX 4060):** $20-$50 daily STRK
Handle standard AI inference. 1.0x base multiplier. Gaming PCs when not in use.

**Pro tier (RTX 4090):** $80-$180 daily STRK
Larger language models. 2.2x multiplier. Dedicated rigs see consistent volume.

**Premium tier (RTX 5090):** $180-$420 daily STRK
Premium workloads requiring 32GB+ VRAM. 3.5x multiplier.

*Earnings vary with network demand. Withdraw anytime.*

[CTA: Deploy Your Node]
[CTA: View Windows Guide → /windows]

---

# PAGE 9: ABOUT `/about`

## Mission

Build transparent, privacy-first compute infrastructure on Starknet. We connect people who need AI computation with people who have spare GPU power — without surveillance or data retention.

## How It Works

Providers run GPUs with our daemon software. Users submit tasks through Telegram or web interfaces. Smart contracts on Starknet handle payments and verification. No central servers store your data.

## Open Source

All code is public. Smart contracts are verified on Starknet. Task assignment algorithms use publicly auditable commitment schemes. Infrastructure transparency builds user trust.

## Team

[TEAM_SECTION_PLACEHOLDER]

[CTA: View GitHub] → GitHub
[CTA: Join Discord] → Discord
