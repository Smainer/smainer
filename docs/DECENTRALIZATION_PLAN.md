# Smainer Relayer Decentralization Plan

**Version**: 2.0 — Consolidated from all prior planning documents  
**Date**: March 23, 2026  
**Status**: Approved architecture. Implementation not started.  
**Owner**: Chief Director + Relayer Architect + Starknet Engineer

---

## 1. Why Decentralize the Relayer

Smainer's relayer is the coordination layer between users, providers, and the Starknet smart contract. Today it runs as a single FastAPI instance on one server. That creates three problems:

1. **Single point of failure.** If the server goes down, the entire network stops.
2. **Trust assumption.** Providers and users must trust Smainer to route tasks fairly.
3. **Censorship surface.** One operator can selectively block participants.

Decentralizing the relayer addresses all three. The goal is a network where multiple independent operators run relayer instances, task routing is verifiable, and no single entity can halt or manipulate the system.

The relayer source code is public. Coordination logic is auditable. Economic rules are enforced by contract. This is a core protocol commitment. The implementation plan follows.

---

## 2. Current State (March 2026)

| Component | Status |
|---|---|
| Relayer | Single FastAPI instance, DigitalOcean, port 8000 |
| Redis | Single instance, same server, no auth |
| Providers | 1 GPU node on Runpod via WebSocket |
| Smart contract | Starknet Sepolia, single `authorized_relayer` field |
| Decentralization code | None. Zero multi-relayer, consensus, or transparency code exists. |
| Decentralization contracts | None. RelayerRegistry, TaskCoordination, ProviderStaking, DisputeResolution — all unimplemented. |

**Honest assessment:** The system works as a centralized prototype. All decentralization is forward-looking.

---

## 3. Architecture Phases

### Phase 0: Transparent Single Relayer

Add verifiability to the existing single-relayer architecture. No infrastructure changes.

```
┌─────────────────┐    ┌───────────────────────────┐    ┌──────────────┐
│   Starknet      │    │  Single Relayer           │    │  Provider    │
│   Contract      │◄──►│  + Transparency Logging   │◄──►│  Daemon(s)   │
│                 │    │  + Assignment Commitments │    │              │
└─────────────────┘    └───────────────────────────┘    └──────────────┘
                                │
                       ┌────────▼────────┐
                       │ Redis           │
                       │ (commitment     │
                       │  hashes stored) │
                       └─────────────────┘
```

**What ships:**
- SHA-256 commitment hash for every task assignment: `hash(task_id, available_nodes[], scores, selected_node, timestamp)`
- Public audit endpoint: `GET /api/v1/transparency/assignments?task_id=X`
- Periodic Merkle root over last 100 commitment hashes, published to Redis Streams
- Relayer identity config (`RELAYER_ID` env var) preparing for multi-instance

**What this proves:** Any assignment can be verified after the fact. Retroactive tampering is detectable via Merkle chain.

**Cost:** Zero. No new infrastructure. ~0.01ms overhead per assignment.

### Phase 1: Active-Standby Multi-Relayer

Eliminate single-point-of-failure with a second relayer instance sharing Redis state.

```
┌──────────────┐    ┌──────────────────────┐    ┌──────────────┐
│  Relayer A   │───►│  Redis Sentinel      │◄───│  Relayer B   │
│  (leader)    │    │  (3 nodes: 1 primary │    │  (standby)   │
└──────┬───────┘    │   + 2 replicas)      │    └──────┬───────┘
       │            └──────────────────────┘           │
       │◄──── WebSocket ────►│◄──── WebSocket ─────────┘
       │      (providers)    │      (providers)
       │                     │
┌──────▼─────────────────────▼──────┐
│          Load Balancer            │
│  (sticky sessions for WebSocket)  │
└───────────────────────────────────┘
```

**How it works:**
- Leader election via Redis: `SET relayer:leader {id} NX EX 30` — renewed every 15s
- If leader key expires, standby promotes itself within seconds
- Redis Sentinel replaces single Redis (3 nodes: 1 primary, 2 replicas)
- Providers connect to both relayers. Only the leader sends task assignments.
- DigitalOcean load balancer with sticky sessions for REST, TCP passthrough for WebSocket

**What this does NOT include:** Inter-relayer consensus, task re-assignment across relayers, on-chain relayer registry, stake-weighted elections. Those belong in Phase 2.

**Infrastructure cost:** ~$228/month (Redis cluster $72, 2 relayer nodes $96, LB $20, PostgreSQL $40)

### Phase 2: Staked Multi-Relayer with On-Chain Registry

Multiple independent relayer operators, coordinated by smart contract.

```
┌─────────────────┐    ┌──────────────────────────┐    ┌──────────────┐
│   Starknet      │    │  Relayer Operator Pool   │    │  Provider    │
│   Governance    │    │  (3-7 staked operators)  │    │  Network     │
│   + Relayer     │◄──►│  Leader-follower pattern │◄──►│  (staked,    │
│     Registry    │    │  Shared Redis state      │    │   multi-     │
│   + Provider    │    │                          │    │   connect)   │
│     Staking     │    └──────────────────────────┘    └──────────────┘
└─────────────────┘              │
                        ┌────────▼────────┐
                        │ PostgreSQL      │
                        │ Transparency    │
                        │ Audit Trail     │
                        └─────────────────┘
```

**What ships:**
- RelayerRegistry contract: registration, staking, basic elections
- ProviderStaking contract: tier-based staking, bond management
- TaskCoordination contract: on-chain assignment recording, proofs
- Leader-follower relayer coordination (simpler than full RAFT)
- Provider multi-connect with automatic failover
- Transparency dashboard in frontend

### Phase 3: Full Decentralization

This phase is deliberately underspecified. It depends on lessons from Phase 2.

**Direction:** Consensus-based task distribution, provider-to-provider coordination, relayer becomes infrastructure rather than product. Potential integration with libp2p for P2P task routing.

**Prerequisites:** Stable multi-relayer operation for 3+ months, 500+ active providers, proven economic viability of relayer operator model.

---

## 4. Relayer Revenue Model

**Problem solved:** No one will run a relayer node without economic incentive. The prior plan had zero revenue model for relayer operators.

### New Fee Structure

The protocol fee increases from 15% to 17%. Provider net earnings are unchanged.

| Recipient | Current (15% total) | New (17% total) | Change |
|---|---|---|---|
| **Provider base** | 85% | 83% | -2% |
| **Provider gas rebate** | 3% | 5% | +2% |
| **Provider net total** | **88%** | **88%** | **Unchanged** |
| Treasury | 12% | 8% | -4% |
| **Relayer operators** | 0% | **4%** | +4% (new) |
| Gas subsidy pool | 3% | 5% | +2% |

**Why this works:**
- Provider net earnings stay at 88% — no impact on the supply side
- Protocol fee rises 2 percentage points (15% → 17%) — modest and justified by decentralization
- Treasury shrinks from 12% to 8% — still substantial, aligns incentives (Smainer benefits from decentralizing because treasury share drops only when external relayers exist)
- 4% relayer pool creates genuine operator economics

### Fee Constants (Cairo)

```cairo
pub const TOTAL_FEE_BPS: u256 = 1700;       // 17% total
pub const PROVIDER_BASE_BPS: u256 = 8300;   // 83% to provider
pub const TREASURY_FEE_BPS: u256 = 800;     // 8% to treasury
pub const RELAYER_FEE_BPS: u256 = 400;      // 4% to relayer operators
pub const GAS_SUBSIDY_BPS: u256 = 500;      // 5% gas rebate to provider
```

### Relayer Operator Economics

**Revenue per task** (at average 1.0 STRK task value):

```
Relayer fee: 4% × 1.0 STRK = 0.04 STRK per task
```

**Break-even analysis:**

| Monthly tasks (network) | Per-relayer tasks (7 relayers) | Monthly STRK earned | Break-even? (300 STRK/mo infra) |
|---|---|---|---|
| 10,000 | 1,429 | 57 STRK | No |
| 25,000 | 3,571 | 143 STRK | No |
| 50,000 | 7,143 | 286 STRK | Near |
| 75,000 | 10,714 | 429 STRK | **Yes + 43% margin** |

**Conclusion:** Relayer economics require network scale. Early relayer incentives are critical.

### Early Relayer Multiplier

Relayer operators who register during the first 90 days receive a **2x relayer fee multiplier**, permanent and enforced by contract (same model as the early provider 2x multiplier).

```cairo
pub const EARLY_RELAYER_MULTIPLIER: u256 = 2;
pub const EARLY_RELAYER_WINDOW: u64 = 7776000; // 90 days in seconds
```

With 2x multiplier, effective relayer share = 8% of task value. Break-even drops to ~25,000 tasks/month network-wide (assuming 7 relayers, all with early multiplier). The extra 4% is funded by treasury allocation, not by increasing user fees.

### Relayer Reward Distribution

Rewards are distributed using a **hybrid base + performance model**:

```
base_share = 40% of relayer pool ÷ active_relayer_count
performance_share = 60% of relayer pool × (relayer_tasks ÷ total_tasks)
```

This guarantees minimum income for all active relayers while rewarding operators who process more tasks. Prevents lazy relayers from earning equal shares without contributing.

---

## 5. Smart Contract Changes

### Phase 0: Multi-Relayer Foundation

Upgrade `authorized_relayer` from a single address to a registry:

```cairo
// Replace:
authorized_relayer: ContractAddress,

// With:
relayer_registry: Map<ContractAddress, RelayerInfo>,
active_relayer_count: u8,

#[derive(Drop, Serde, starknet::Store)]
pub struct RelayerInfo {
    pub stake_amount: u256,
    pub is_active: bool,
    pub registration_time: u64,
    pub tasks_processed: u256,
}
```

### Staking Requirements (Revised)

Original plan proposed 10,000 STRK for relayers. Too high for early network.

| Role | Original | Revised | Rationale |
|---|---|---|---|
| Relayer operator | 10,000 STRK | **2,000 STRK** | Accessible to serious operators without excluding independents |
| Provider Basic | 100 STRK | **50 STRK** | Low barrier for GPU owners |
| Provider Pro | 500 STRK | **200 STRK** | Mid-tier commitment |
| Provider Premium | 1,000 STRK | **500 STRK** | Serious infrastructure operators |

### Contract Build Priority

| Order | Contract | Dependencies |
|---|---|---|
| 1st | **RelayerRegistry** | None — works alongside current contract |
| 2nd | **ProviderStaking** | Interfaces with RelayerRegistry for slasher auth |
| 3rd | **TaskCoordination** | Requires both above for validation |
| 4th | **DisputeResolution** | Requires all three — complex governance |

### Upgrade Strategy

- Deploy via **proxy pattern** with 72-hour upgrade timelock
- Run parallel on Sepolia for 1 week before activating
- Maintain backward compatibility: existing `authorized_relayer` logic works until Phase 2
- Emergency pause mechanism for 30 days post-deployment

---

## 6. Relayer Code Changes

### New Modules (Phase 0)

| File | Purpose |
|---|---|
| `core/transparency.py` | Assignment commitment hashing, Merkle tree builder, Redis audit storage |
| `core/leader_election.py` | Redis-based leader election (SET NX), heartbeat, role state machine |
| `core/relayer_identity.py` | Instance registration, RELAYER_ID config, heartbeat to sorted set |
| `api/transparency_router.py` | `GET /api/v1/transparency/assignments` and `/merkle-roots` |
| `models/transparency_schemas.py` | Pydantic models for AssignmentCommitment, MerkleRoot, AuditLogEntry |

### Modified Modules (Phase 0)

| File | Change |
|---|---|
| `config.py` | Add `relayer_id`, `relayer_role`, `leader_election_enabled`, `transparency_enabled` |
| `core/scheduler.py` | Call `TransparencyService.record_assignment()` after each task assignment |
| `core/enhanced_scheduler.py` | Same — record with WFQ scoring context |
| `main.py` | Initialize TransparencyService, mount transparency_router |
| `api/routes.py` | Add `relayer_id` and `role` to health endpoint |
| `core/events.py` | Add `ASSIGNMENT_COMMITTED` and `MERKLE_ROOT_PUBLISHED` event types |

### Provider Daemon Changes (Phase 1)

- Accept list of relayer WebSocket URLs (not just one)
- Connect to all, accept task assignments only from leader
- Automatic failover if primary disconnects

---

## 7. Security Requirements

### Top Risks (ranked)

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | **Cross-relayer task hijacking** — same task assigned to multiple providers | Critical | Distributed task locks via Redis Cluster before multi-relayer |
| 2 | **Signature replay across relayers** — valid signature replayed to different relayer | Critical | Include `relayer_address` in signature message hash |
| 3 | **Stake-weighted Sybil attack** — one entity controls all relayer slots | High | Max 2 slots per entity (25% cap), quadratic voting for disputes |
| 4 | **Relayer authentication** — no auth between relayer instances | High | mTLS with on-chain public key registry |
| 5 | **Redis state corruption** — malicious relayer poisons shared state | Medium | Redis AUTH + TLS, namespace isolation per relayer |

### Phase 0 Security Prerequisites

Before adding a second relayer operator:

- [ ] Redis AUTH + TLS encryption enabled
- [ ] On-chain relayer registry with public keys deployed
- [ ] Distributed task lock mechanism (prevent double-assignment)
- [ ] Signature scheme extended: `pedersen(task_id, provider, result_hash, relayer_address)`
- [ ] Single-relayer mode remains functional as fallback

### Slashing Safety

The original plan proposed 50% fraud slashing with no appeals. This is unsafe.

**Graduated approach:**
1. **Phase 1:** Warning-only slashing (no funds lost, behavior logged)
2. **Phase 2:** 5% maximum slashing with mandatory 48-hour challenge period
3. **Phase 3:** Full slashing (up to 50%) only after 6+ months of stable operation

---

## 8. Infrastructure Plan

### Phase 0: No Changes
Use existing single Redis + single relayer. Add transparency logging only.

### Phase 1: Multi-Node

| Component | Spec | Monthly Cost |
|---|---|---|
| Redis Sentinel (3 nodes) | DigitalOcean `s-2vcpu-4gb` | $72 |
| Relayer nodes (2) | DigitalOcean `s-4vcpu-8gb` | $96 |
| Load balancer | DigitalOcean standard | $20 |
| PostgreSQL (transparency) | Managed `db-s-2vcpu-4gb` | $40 |
| **Total** | | **$228/month** |

### Phase 2: Scaled

| Component | Spec | Monthly Cost |
|---|---|---|
| Redis Cluster (6 nodes) | 3 master + 3 replica | $144 |
| Relayer nodes (3-7) | Operated by independent stakers | Variable |
| PostgreSQL HA | Multi-region | ~$120 |
| Monitoring stack | Prometheus + Grafana | ~$50 |
| **Total (Smainer-operated)** | | **~$314/month** |

By Phase 2, relayer infrastructure costs are partially covered by the 4% relayer fee. At 50,000 tasks/month with 1 STRK average, the relayer pool generates 2,000 STRK/month.

---

## 9. SLA Targets by Phase

| Metric | Phase 0 | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|---|
| Event processing latency | <100ms | <100ms | <150ms | <200ms |
| Task assignment time | 2-5s | 2-5s | 3-7s | 5-10s |
| System availability | 99.5% | 99.9% | 99.95% | 99.9% |
| Task completion rate | 98% | 99% | 97% | 95% |
| Transparency coverage | 100% logged | 100% logged | 100% on-chain | 100% on-chain |

Latency increases in later phases are the expected cost of decentralized coordination. The tradeoff is justified by censorship resistance and fault tolerance.

---

## 10. Risk Matrix

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Provider churn during transition | High | High | Backward compatibility, zero provider-side changes in Phase 0-1 |
| Consensus attack | Medium | Critical | 33% Byzantine fault tolerance (requires >66% honest operators), graduated slashing |
| Network partition | Medium | High | Geographic redundancy, automatic partition healing |
| Performance degradation | High | Medium | Gradual migration with phase gates |
| Relayer economics not viable | Medium | High | Early 2x multiplier, treasury backstop during ramp |
| Whale captures all relayer slots | Medium | High | 25% max stake per entity, slot cap |

---

## 11. Open Questions

These must be resolved before Phase 2 begins:

1. **Relayer operator onboarding:** Who qualifies? What hardware requirements? How is KYC handled for stakes >100K STRK?
2. **Relayer-to-relayer networking:** Phase 1 uses shared Redis. Phase 2 needs a defined inter-relayer protocol. RAFT? Custom? Over what transport?
3. **libp2p feasibility:** Python libp2p is immature. Phase 3 may require Go/Rust implementations. Decision deferred until Phase 2 results are in.
4. **Governance for parameter changes:** Who votes on fee split adjustments? Relayers only? Providers too? Token holders?
5. **Cross-relayer fee reconciliation:** When multiple relayers process different task types, how are fees pooled and distributed?

---

## 12. What This Replaces

This document consolidates and supersedes:

- `INFRA_DECENTRALIZATION_PLAN.md` (root and docs/planning/)
- `STARKNET_DECENTRALIZATION_PLAN.md` (root and docs/planning/)
- `DECENTRALIZE_RELAYER_MEETING_BRIEF.md` (docs/planning/ and .github/internal/)

Those files will be removed from the repository. This is the single source of truth for the decentralization roadmap.
