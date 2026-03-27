# Smainer Development Agents

Specialized agents for building the Smainer decentralized compute marketplace.

> **Architecture Reference:** See [PIPELINE_TOPOLOGY.md](./PIPELINE_TOPOLOGY.md) for the full call graph, envelope schemas, code ownership map, and meeting protocol specs.

---

## TIER 0 — GATEWAY

**[@chief-director](./agents/chief-director.agent.md)**
Accepts input from user only. Routes to `planner` for multi-step work or directly to a single specialist for a targeted task. Never implements. Runs meetings via the [chief-director-agent-sync](./prompts/chief-director-agent-sync.prompt.md) prompt.

---

## TIER 1 — PLANNING

**[@planner](./agents/planner.agent.md)**
Accepts tasks from `chief-director`. Produces a Task Manifest (sequenced tasks with owners, critical path, parallel tracks). Delegates execution tasks to Tier 2. Does not write or edit code.

---

## TIER 2 — EXECUTION

Each specialist owns a specific code surface. They accept Task Briefs from `planner` or `chief-director` and return Delivery Reports.

| Agent | Code Ownership | Domain |
|---|---|---|
| [@relayer-architect](./agents/relayer-architect.agent.md) | `backend/relayer/` | FastAPI, WebSocket, Redis, job scheduling |
| [@systems-engineer](./agents/systems-engineer.agent.md) | `backend/provider/` | Python daemons, Docker sandboxing, systemd |
| [@starknet-engineer](./agents/starknet-engineer.agent.md) | `contracts/` | Cairo contracts, escrow, ERC-20, Scarb |
| [@frontend-engineer](./agents/frontend-engineer.agent.md) | `frontend/src/` | Next.js, starknet-react, wallet integration |
| [@tauri-desktop-engineer](./agents/tauri-desktop-engineer.agent.md) | `desktop/` | Tauri app, IPC, Windows Credential Manager |
| [@telegram-bot-developer](./agents/telegram-bot-developer.agent.md) | `telegram/smainer-bot/`, `telegram/miniapp/src/` | Telegram bot, MiniApp, Vercel serverless |
| [@fee-economist](./agents/fee-economist.agent.md) | Fee constants in `contracts/src/` + `backend/relayer/config.py` | Fee structure, treasury splits, gas subsidy |
| [@brand-designer](./agents/brand-designer.agent.md) | `frontend/src/styles/`, design tokens | Visual identity, color system, UI aesthetics |
| [@marketing-copywriter](./agents/marketing-copywriter.agent.md) | `docs/`, landing page copy in `frontend/src/app/` | Conversion copy, CTAs, onboarding |
| [@technical-copywriter](./agents/technical-copywriter.agent.md) | Technical docs in `docs/`, `README.md` | Power-user docs, API references |
| [@gtm-specialist](./agents/gtm-specialist.agent.md) | Launch docs in `.github/` and `docs/` | Go-to-market, launch checklists |
| [@agent-runtime-engineer](./agents/agent-runtime-engineer.agent.md) | `.github/agents/`, `.github/skills/`, `.github/instructions/` | Agent pipeline architecture, runtime policies |
| [@ai-inference-benchmarker](./agents/ai-inference-benchmarker.agent.md) | Read-only (metrics) | Inference benchmarks, latency gates |

---

## TIER 3 — VALIDATION

Tier 3 agents produce Validation Reports only. They set hard constraints; implementers accept or escalate.

**[@security-expert](./agents/security-expert.agent.md)**
Reviews Delivery Reports before release. Hard constraints: auth schemes, secret handling, replay protection, callback integrity. Returns `approved | approved_with_conditions | blocked`.

**[@repository-architect](./agents/repository-architect.agent.md)**
Dual-mode: Tier 2 for implementation tasks (repo setup, CI, deployment scripts). Tier 3 for release gates (validates branching, deployment state, governance). Owns all 6 repo structures.

---

## Allowed Call Graph

```
User
 └── chief-director (TIER 0)
      ├── planner (TIER 1)
      │    └── [any Tier 2 specialist]
      ├── [any Tier 2 specialist] (direct, single-domain tasks)
      └── [Tier 3 for validation or release gate]

Tier 2 specialists
 └── may request Tier 3 validation via Delivery Report flag
     (never call Tier 3 directly as a subagent)
```

**Forbidden patterns:**
- Tier 2 agents calling other Tier 2 agents as subagents
- Planner calling Tier 3 for validation (route through chief-director)
- Any agent bypassing the Task Manifest envelope when delegating multi-step work

---

## Meeting Relationship Map

Meetings are convened by `chief-director` only. Eight canonical alignment pairs:

| Rule-Setter | Implementer | Shared Concern |
|---|---|---|
| security-expert | relayer-architect | Auth scheme, callback integrity |
| security-expert | systems-engineer | Sandbox policy, secret handling |
| security-expert | telegram-bot-developer | Webhook validation, token storage |
| starknet-engineer | relayer-architect | On-chain event shapes, bundler interface |
| starknet-engineer | frontend-engineer | Wallet call encoding, ABI surface |
| fee-economist | starknet-engineer | Fee constant values, split math |
| fee-economist | relayer-architect | Gas subsidy logic, batch fee calc |
| relayer-architect | systems-engineer | WebSocket event protocol, task payload schema |

---

## Quick Commands

**Start any complex task:**
- `@chief-director` [describe goal] — routes automatically

**Direct specialist access (single-domain):**
- `@frontend-engineer` Build wallet connection UI
- `@starknet-engineer` Create escrow smart contract
- `@relayer-architect` Design task distribution system
- `@telegram-bot-developer` Implement payment flow
- `@brand-designer` Redesign color palette
- `@marketing-copywriter` Write landing page copy
- `@fee-economist` Model pricing strategy
- `@security-expert` Review auth, callbacks, and secret handling
- `@repository-architect` Coordinate deployment across components
- `@planner` Break down [feature] into sprint tasks with owners and dependencies
- `@agent-runtime-engineer` Define runtime policies and agent execution guardrails
- `@ai-inference-benchmarker` Produce tiered performance baseline and bottleneck report

---

## Context Files

Agents automatically load relevant context from:
- [crypto-security.instructions.md](./instructions/crypto-security.instructions.md) — Security patterns for crypto development
- [PIPELINE_TOPOLOGY.md](./PIPELINE_TOPOLOGY.md) — Full 4-tier architecture, envelope schemas, code ownership
- **[web3-integration.instructions.md](./instructions/web3-integration.instructions.md)** - Wallet connection and DeFi patterns

## Quick Prompts

- **`/telegram-api`** - Generate bot handlers, keyboards, commands
- **`/deployment-security`** - Docker configs, environment validation, production checklists

---

*Use `@agent-name task description` to invoke specialized agents. For complex workflows, start with @chief-director for coordination.*