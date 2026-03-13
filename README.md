# Smainer — Starknet Compute Marketplace

Run compute tasks on verified hardware. **Providers** earn STRK tokens by sharing resources. **Users** pay per task with transparent, on-chain settlement.

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

## Economics

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
Providers receive 3% gas subsidy automatically. Submit proofs without out-of-pocket gas costs.

### Cost Breakdown
Task submission shows exact fees upfront:
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

## Documentation

- `DEEP_DIVE.md`: Detailed architecture and implementation status
- `TESTNET_DEPLOYMENT_INSTRUCTIONS.md`: Testnet deployment runbook
- `FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md`: First provider node setup and validation
- `LAUNCH_GUIDE.md`: End-to-end launch flow, including Telegram integration
- `LAUNCH_ACTION_CHECKLIST.md`: Operational launch checklist
- `SUCCESS_METRICS.md`: Live test success targets
- `TIERED_REWARDS_IMPLEMENTATION_GUIDE.md`: Tier/reward implementation notes

## Community and Security

- `CONTRIBUTING.md`: How to contribute changes
- `SECURITY.md`: How to report vulnerabilities
- `CODE_OF_CONDUCT.md`: Community behavior expectations

## License

MIT
