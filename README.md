<div align="center">

#  Smainer

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
│   Frontend      │◄────►│    Relayer       │◄────►│  Provider Node  │
│   (Next.js)     │ REST │  (FastAPI + WS)  │  WS  │  (Python Daemon)│
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

### Fee Structure (15% Total)

On task completion, the smart contract automatically splits payment:

| Recipient | Share | BPS | Description |
|-----------|-------|-----|-------------|
| **Provider** | 85% | 8500 | Base compute payout |
| **Provider** (gas subsidy) | 3% | 300 | Rebated to cover Starknet gas costs |
| **Smainer Treasury** | 12% | 1200 | Platform maintenance & infrastructure |

- **Provider total**: 88% of task amount (85% payout + 3% gas subsidy)
- **Treasury total**: 12% of task amount
- All math uses basis points (`BPS_DENOMINATOR = 10000`) for precision
- Fee split is enforced on-chain in `submit_proof_and_claim` — no off-chain calculation

### Gas Subsidies

The 3% gas subsidy is automatically added to the provider's payout so providers don't have to pay out-of-pocket to submit proofs. This lowers the barrier to onboarding new compute nodes.

### Transparent Pricing (Frontend)

When users submit tasks, the cost estimator shows a full breakdown:
```
  Compute Cost:                       X STRK
  Smainer Network Fee (15%):          Y STRK
    |-- Treasury (12%):               ...
    |-- Gas Subsidy to Provider (3%): ...
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

| Document | Description |
|----------|-------------|
| [`DEEP_DIVE.md`](DEEP_DIVE.md) | Detailed architecture and implementation status |
| [`TESTNET_DEPLOYMENT_INSTRUCTIONS.md`](TESTNET_DEPLOYMENT_INSTRUCTIONS.md) | Testnet deployment runbook |
| [`FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md`](FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md) | First provider node setup and validation |
| [`LAUNCH_ACTION_CHECKLIST.md`](LAUNCH_ACTION_CHECKLIST.md) | Operational launch checklist |
| [`SUCCESS_METRICS.md`](SUCCESS_METRICS.md) | Live test success targets |
| [`TIERED_REWARDS_IMPLEMENTATION_GUIDE.md`](TIERED_REWARDS_IMPLEMENTATION_GUIDE.md) | Tier/reward implementation notes |

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
