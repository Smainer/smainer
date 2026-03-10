# Smainer — Decentralized Compute-Sharing Protocol

A Web3 compute marketplace built on Starknet where **Providers** share hardware resources and **Demanders** pay for compute tasks using ERC-20 tokens.

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

## Protocol Economics

### Fee Structure (15% Total — 1500 Basis Points)

On successful job completion, the smart contract automatically splits the escrowed payment:

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

### Transparent Display (Frontend)
When users submit tasks, the cost estimator shows a full breakdown:
```
  Compute Cost:                      X STRK
  Smainer Network Fee (15%):         Y STRK
    |-- Treasury (12%):              ...
    |-- Gas Subsidy to Provider (3%): ...
  ─────────────────────────────────────────
  Total:                             Z STRK
```

## Monorepo Structure

| Directory | Description | Stack |
|-----------|-------------|-------|
| `contracts/` | Starknet smart contracts | Cairo, Scarb, OpenZeppelin |
| `relayer/` | Coordination middleware | Python, FastAPI, Redis |
| `provider/` | Compute node daemon | Python, Docker SDK, starknet.py |
| `frontend/` | Web3 dashboard | Next.js, starknet-react, shadcn/ui |
| `desktop/` | Windows node onboarding app | Tauri v2, Rust, React |

Desktop repository: https://github.com/Smainer/smainer-desktop

## Quick Start

```bash
# Smart Contracts
cd contracts && scarb build && scarb test

# Relayer
cd relayer && pip install -e ".[dev]" && pytest

# Provider Node
cd provider && pip install -e ".[dev]" && pytest

# Frontend
cd frontend && npm install && npm run dev
```

## License

MIT
