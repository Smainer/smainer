<div align="center">

# ⚡ Smainer

### Decentralized Compute-Sharing Protocol on Starknet

*Share your GPU. Earn STRK. Power the future of permissionless compute.*

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Built on Starknet](https://img.shields.io/badge/Built%20on-Starknet-ff6b35.svg)](https://starknet.io)
[![Cairo](https://img.shields.io/badge/Cairo-Smart%20Contracts-blueviolet.svg)](https://book.cairo-lang.org)
[![Next.js](https://img.shields.io/badge/Frontend-Next.js-black.svg)](https://nextjs.org)
[![Python](https://img.shields.io/badge/Backend-Python%203.11+-3776AB.svg)](https://python.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</div>

---

A Web3 compute marketplace built on Starknet where **Providers** share hardware resources and **Demanders** pay for compute tasks using ERC-20 tokens — transparently, on-chain, and without intermediaries.

> Pull Requests are welcomed. Please see the [Contributing Guide](CONTRIBUTING.md) before opening a Pull Request.

---

## Index

- [Architecture](#architecture)
- [Protocol Economics](#protocol-economics)
- [Monorepo Structure](#monorepo-structure)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Community & Security](#community--security)
- [License](#license)

---

## Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   Frontend      │◄────►│    Relayer        │◄────►│  Provider Node  │
│   (Next.js)     │ REST │  (FastAPI + WS)   │  WS  │  (Python Daemon)│
└────────┬────────┘      └────────┬─────────┘      └─────────────────┘
         │                        │
         │  starknet-react        │  starknet.py
         │                        │
         ▼                        ▼
    ┌─────────────────────────────────────┐
    │         Starknet L2 Network         │
    │  ┌───────────────────────────────┐  │
    │  │  Cairo Smart Contracts        │  │
    │  │  - Provider Registry          │  │
    │  │  - Escrow System              │  │
    │  │  - Proof Verification         │  │
    │  └───────────────────────────────┘  │
    └─────────────────────────────────────┘
```

---

## Protocol Economics

### Fee Structure (17% Total)

On task completion, the smart contract automatically splits payment:

| Recipient | Share | BPS | Description |
|-----------|-------|-----|-------------|
| **Provider** | 83% | 8300 | Base compute payout |
| **Provider** (gas subsidy) | 5% | 500 | Rebated to cover Starknet gas costs |
| **Relayer Operators** | 4% | 400 | Distributed to staked relayer operators |
| **Smainer Treasury** | 8% | 800 | Platform maintenance & development |

- **Provider total**: 88% of task amount (83% payout + 5% gas subsidy) — unchanged
- **Relayer pool**: 4% funds decentralized coordination operators
- **Treasury**: 8% for protocol development
- All math uses basis points (`BPS_DENOMINATOR = 10000`) for precision
- Fee split is enforced on-chain in `submit_proof_and_claim` — no off-chain calculation
- See [`docs/DECENTRALIZATION_PLAN.md`](docs/DECENTRALIZATION_PLAN.md) for the full economic model

### Gas Subsidies

The 5% gas subsidy is automatically added to the provider's payout so providers don't have to pay out-of-pocket to submit proofs. This lowers the barrier to onboarding new compute nodes.

### Transparent Pricing (Frontend)

When users submit tasks, the cost estimator shows a full breakdown:
```
  Compute Cost:                       X STRK
  Smainer Network Fee (17%):          Y STRK
    |-- Treasury (8%):                ...
    |-- Relayer Operators (4%):       ...
    |-- Gas Subsidy to Provider (5%): ...
  ──────────────────────────────────────────
  Total:                              Z STRK
```

---

## Monorepo Structure

| Directory | Description | Stack |
|-----------|-------------|-------|
| [`contracts/`](contracts/) | Starknet smart contracts | Cairo, Scarb, OpenZeppelin |
| [`backend/`](backend/) | Coordination middleware & provider daemon | Python, FastAPI, Redis |
| [`frontend/`](frontend/) | Web3 dashboard | Next.js, starknet-react, shadcn/ui |
| [`telegram/`](telegram/) | Telegram bot integration | Python, aiogram |
| [`desktop/`](desktop/) | Windows node onboarding app | Tauri v2, Rust, React |

> Desktop app repository: [Smainer/smainer-desktop](https://github.com/Smainer/smainer-desktop)

---

## Quick Start

```bash
# Smart Contracts
cd contracts && scarb build && scarb test

# Backend (Relayer + Provider Node)
cd backend && pip install -e ".[dev]" && pytest

# Frontend
cd frontend && npm install && npm run dev

# Telegram Bot
cd telegram && pip install -e ".[dev]"
```

**Note**: The relayer service runs on port 8000 by default, with automatic fallback to 8001 if occupied. The relayer endpoint is fully configurable via `RELAYER_API_URL` environment variable for both security and operational flexibility.

---

## Documentation

All docs live in [`docs/`](docs/). Key references:

| Document | Description |
|----------|-------------|
| [`docs/SYSTEM_ARCHITECTURE.md`](docs/SYSTEM_ARCHITECTURE.md) | Component topology, data flows, event-driven design |
| [`docs/DEEP_DIVE.md`](docs/DEEP_DIVE.md) | Technical deep-dive and protocol economics |
| [`docs/DECENTRALIZATION_PLAN.md`](docs/DECENTRALIZATION_PLAN.md) | Relayer decentralization roadmap, revenue model, contracts |
| [`docs/operations/DEPLOYMENT_PLAYBOOK.md`](docs/operations/DEPLOYMENT_PLAYBOOK.md) | End-to-end deployment guide |
| [`docs/operations/LAUNCH_GUIDE.md`](docs/operations/LAUNCH_GUIDE.md) | Launch flow including Telegram integration |
| [`docs/README.md`](docs/README.md) | Full documentation index |

---

## Community & Security

| Document | Description |
|----------|-------------|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute changes |
| [`SECURITY.md`](SECURITY.md) | How to report vulnerabilities |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community behavior expectations |

---

## License

Released under the [MIT License](LICENSE).
