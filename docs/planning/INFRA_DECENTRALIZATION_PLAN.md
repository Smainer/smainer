# Smainer Infrastructure Decentralization Plan
## Migration from Single Relayer+Redis to Transparent Orchestration

**Document Version**: 1.0  
**Date**: March 13, 2026  
**Migration Type**: Hybrid Transparent → Progressive Decentralization  

---

## Executive Summary

Migration from centralized relayer to transparent/decentralized orchestration using a phased approach that maintains <100ms SLA targets while progressively distributing coordination responsibilities to provider nodes.

**Key Decision**: Hybrid Transparent Architecture for initial phase, progression to selective decentralization in 6+ months based on network maturity.

---

## 1. Runtime Topology Architecture

### Phase 1: Transparent Hybrid (30 days)
```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Starknet      │    │  Transparent        │    │  Provider       │
│   Governance    │    │  Relayer Cluster    │    │  Daemon Mesh    │
│   Contract      │◄──►│  (3x FastAPI +      │◄──►│  (Direct P2P    │
│                 │    │   Redis Cluster)    │    │   + WebSocket)  │
└─────────────────┘    └─────────────────────┘    └─────────────────┘
                               │                           │
                       ┌───────▼────────┐         ┌──────▼──────┐
                       │ Transparency   │         │ Cryptographic │
                       │ Proof Store    │         │ Task Logs   │
                       │ (PostgreSQL)   │         │ (Local)     │
                       └────────────────┘         └─────────────┘
```

### Phase 2: Selective Decentralization (60 days)
```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Starknet      │    │ Coordinator         │    │ Provider        │
│   Governance    │    │ Election Pool       │    │ Supernodes      │
│   + Staking     │◄──►│ (5 Elected Nodes)   │◄──►│ (Stake-weighted │
│   Contract      │    │                     │    │  coordinators)  │
└─────────────────┘    └─────────────────────┘    └─────────────────┘
                               │                           │
                       ┌───────▼────────┐         ┌──────▼──────┐
                       │ Consensus       │         │ Distributed │
                       │ State (RAFT)    │         │ Task Pool   │
                       │                 │         │ (DHT)       │
                       └────────────────┘         └─────────────┘
```

### Phase 3: Full Decentralization (90+ days)
```
┌─────────────────┐              ┌─────────────────────────────┐
│   Starknet      │              │     Provider Network        │
│   Governance    │◄─────────────┤  (Consensus Coordination)   │
│   Contract      │              │                             │
└─────────────────┘              └─────────────────────────────┘
                                          │
                                ┌─────────▼──────────┐
                                │ Network Partitions │
                                │ (Geographic Zones) │
                                └────────────────────┘
```

---

## 2. Environment-Specific Configurations

### Development Environment
**Purpose**: Local development and feature testing  
**Components**: Single node simulation with mocked P2P layer

```yaml
dev:
  relayer:
    replicas: 1
    resources: { cpu: "0.5", memory: "1Gi", storage: "5Gi" }
    features: [ "transparency_logging", "mock_consensus" ]
  redis:
    mode: "standalone"
    persistence: false
    resources: { memory: "512Mi" }
  providers:
    simulated_count: 5
    mock_gpu_types: [ "RTX3080", "RTX4090" ]
  networks:
    p2p_simulation: true
    websocket_local: "ws://localhost:8000"
```

### Staging Environment  
**Purpose**: Pre-production validation with realistic load patterns

```yaml
staging:
  relayer:
    replicas: 2
    resources: { cpu: "2", memory: "4Gi", storage: "20Gi" }
    features: [ "transparency_proofs", "partial_decentralization" ]
    load_balancer: "application"
  redis:
    mode: "cluster"
    replicas: 3
    persistence: true
    resources: { memory: "2Gi" }
  postgresql:
    replicas: 1
    resources: { cpu: "1", memory: "4Gi", storage: "50Gi" }
    backup_schedule: "daily"
  providers:
    target_count: 20
    geographic_distribution: ["us-east", "eu-west", "ap-southeast"]
  monitoring:
    prometheus: true
    grafana: true
    jaeger_tracing: true
```

### Production Environment
**Purpose**: High-availability, multi-region deployment

```yaml
production:
  relayer:
    replicas: 3
    regions: ["primary", "disaster_recovery", "edge"]
    resources: { cpu: "4", memory: "8Gi", storage: "100Gi" }
    features: [ "full_transparency", "consensus_coordination" ]
    auto_scaling: { min: 3, max: 10, cpu_threshold: 70 }
  redis:
    mode: "cluster_ha"
    replicas: 6  # 3 masters, 3 replicas
    persistence: true
    backup: "continuous"
    resources: { memory: "8Gi" }
  postgresql:
    mode: "ha_cluster"
    replicas: 3
    resources: { cpu: "2", memory: "8Gi", storage: "500Gi" }
    backup: "point_in_time_recovery"
  providers:
    target_count: 500+
    geographic_zones: 8
    stake_requirements: { minimum: "1000 STRK", coordinator: "10000 STRK" }
  security:
    tls_everywhere: true
    cert_rotation: "30d"
    network_policies: "zero_trust"
```

---

## 3. Observability & SLAs

### Core SLA Targets

| **Metric** | **Current** | **Phase 1** | **Phase 2** | **Phase 3** |
|------------|-------------|-------------|-------------|-------------|
| Event Processing Latency | <100ms | <100ms | <150ms | <200ms |
| Task Assignment Time | 2-5s | 2-5s | 3-7s | 5-10s |
| Provider Connection Recovery | <2min | <2min | <3min | <5min |
| System Availability | 99.5% | 99.9% | 99.95% | 99.9% |
| Task Completion Rate | 98% | 99% | 97% | 95% |

### observability Stack

```yaml
monitoring:
  metrics:
    - prometheus:
        retention: "30d"
        targets: ["relayer", "redis", "postgres", "providers"]
        custom_metrics: ["task_throughput", "gpu_utilization", "consensus_latency"]
    
    - grafana:
        dashboards:
          - "system_health"
          - "task_flow_analysis" 
          - "provider_network_topology"
          - "consensus_performance"
          - "financial_metrics"
    
  logging:
    - loki:
        retention: "90d"
        log_levels: ["ERROR", "WARN", "INFO"]
        structured_format: true
    
    - correlation_ids:
        task_lifecycle: true
        provider_sessions: true
        consensus_rounds: true
    
  tracing:
    - jaeger:
        sampling_rate: 0.1  # 10% trace sampling
        trace_flows:
          - "task_submission_to_completion"
          - "provider_registration_flow"
          - "consensus_decision_path"
          - "payment_distribution_flow"
    
  alerting:
    - prometheus_rules:
        - name: "sla_violations"
          conditions:
            - "event_processing_latency > 200ms for 5m"
            - "task_failure_rate > 10% for 10m"
            - "provider_churn > 30% for 15m"
            - "consensus_stalls > 3 consecutive"
        
    - pager_duty:
        escalation: ["on_call_engineer", "systems_lead", "cto"]
        severity_levels: ["P1", "P2", "P3"]
        
  custom_dashboards:
    - transparency_audit:
        tracking: ["decision_proofs", "assignment_fairness", "provider_selection_logic"]
    
    - decentralization_progress:
        metrics: ["coordinator_distribution", "consensus_participation", "network_partition_health"]
    
    - financial_performance:
        tracking: ["payment_processing_time", "gas_cost_optimization", "provider_earnings_distribution"]
```

### Health Check Endpoints

```python
# /health/system - Overall system status
{
  "status": "healthy",
  "timestamp": "2026-03-13T10:30:00Z",
  "components": {
    "relayer_cluster": "healthy",
    "redis_cluster": "healthy", 
    "provider_network": "degraded",
    "consensus_layer": "healthy",
    "on_chain_integration": "healthy"
  },
  "sla_compliance": {
    "event_latency": "95ms (within <100ms target)",
    "availability": "99.97% (exceeds 99.9% target)",
    "task_success_rate": "98.5%"
  }
}
```

---

## 4. Failover & Recovery Runbooks

### Runbook 1: Relayer Node Failure

**Trigger**: Relayer node health check failure or unresponsive for >30s

```bash
# Automated Response (30-90s)
1. AWS ALB removes failed instance from rotation
2. New instance launched from AMI with current config
3. Redis connections migrate to healthy nodes
4. Provider WebSocket connections auto-reconnect

# Manual Intervention (if automation fails)
5. Check logs: kubectl logs relayer-pod-xyz
6. Verify Redis connectivity: redis-cli ping
7. Force restart: kubectl delete pod relayer-pod-xyz
8. Monitor metrics recovery in Grafana

# Escalation (if >5min downtime)
9. Page on-call engineer
10. Activate disaster recovery region
11. Provider notification via WebSocket broadcast
```

### Runbook 2: Redis Cluster Split-Brain

**Trigger**: Redis cluster reports multiple masters or >50% nodes unreachable

```bash
# Immediate Response (0-2min)
1. Stop all write operations to Redis
2. Identify healthy partition with majority nodes
3. Force failover to healthy partition
4. Update relayer to connect to healthy Redis masters

# Recovery Actions (2-10min)  
5. Restart Redis instances in failed partition
6. Rejoin nodes to cluster: redis-cli cluster meet <healthy_ip> 6379
7. Verify cluster health: redis-cli cluster nodes
8. Resume write operations gradually

# Data Integrity Check (10-30min)
9. Compare task queues across partitions
10. Reconcile any duplicate task assignments
11. Verify no lost tasks: check provider completion status
12. Update monitoring to prevent future split-brain
```

### Runbook 3: Provider Network Partition

**Trigger**: >30% of providers disconnect simultaneously or consensus stalls

```bash
# Assessment (0-5min)
1. Identify affected geographic region/ISP
2. Check if consensus quorum maintained (>51% stake)
3. Verify task assignment still functional
4. Monitor on-chain transaction success rate

# Mitigation (5-15min)
5. If quorum lost: pause new task acceptance
6. Route tasks to healthy partition providers  
7. Enable relayer fallback mode for critical tasks
8. Extend task deadline for affected region

# Recovery (15-60min)
9. Provider reconnection burst: stagger WebSocket accepts
10. Re-distribute tasks from isolated providers
11. Consensus re-synchronization once network healed
12. Provider stake slashing assessment for disconnect duration
```

### Runbook 4: On-Chain Transaction Failures

**Trigger**: Starknet transaction failure rate >10% or payment delays >1hr

```bash
# Immediate Actions (0-5min)
1. Check Starknet network status: public RPC endpoints
2. Verify gas price adequacy: compare to network median
3. Switch to backup RPC endpoint if primary failing
4. Queue pending transactions for retry with higher gas

# Escalation (5-30min)
5. Contact Starknet core team if network-wide issue
6. Implement manual payment processing for critical tasks
7. Provider notification about delayed payments
8. Switch to L1 Ethereum for urgent transactions if needed

# Post-Recovery (30min+)
9. Process queued payments in batch transactions
10. Reconcile provider balances with pending payments
11. Update gas estimation algorithm to prevent future issues
12. Provider communication about resolved payment delays
```

---

## 5. Capacity Planning & Bottleneck Analysis

### Current Baseline Performance

```yaml
current_metrics:
  relayer:
    max_concurrent_connections: 1000
    task_processing_rate: "200 tasks/sec"
    memory_utilization: "2.5GB peak"
    cpu_utilization: "40% average, 80% peak"
    
  redis:
    operations_per_second: 50000
    memory_usage: "4GB active dataset"
    network_bandwidth: "100Mbps peak"
    
  provider_network:
    active_providers: 150
    geographic_distribution: "3 regions"
    task_completion_rate: "95% within 30s"
```

### Projected Scaling Requirements

**6-Month Horizon (500 providers)**
```yaml
scaling_6mo:
  relayer:
    required_instances: 3
    memory_per_instance: "8GB"
    cpu_per_instance: "4 cores"
    estimated_cost: "$400/month"
    
  redis:
    cluster_size: 6
    memory_per_node: "8GB"  
    estimated_cost: "$800/month"
    
  bandwidth:
    provider_connections: "5Mbps sustained"
    blockchain_sync: "10Mbps peak"
    
  storage:
    transparency_logs: "500GB/month" 
    task_results_cache: "2TB active"
```

**12-Month Horizon (2000 providers)**
```yaml
scaling_12mo:
  architecture: "Multi-region active-active"
  relayer:
    required_instances: 12  # 4 per region
    memory_per_instance: "16GB"
    cpu_per_instance: "8 cores"
    estimated_cost: "$2400/month"
    
  consensus_layer:
    coordinator_nodes: 20
    stake_requirement: "5000 STRK minimum"
    election_rotation: "weekly"
    
  database:
    postgresql_cluster: "3 regions"
    storage_per_region: "10TB"
    backup_bandwidth: "1Gbps sustained"
    
  network:
    p2p_mesh_overhead: "20% of task bandwidth"
    consensus_bandwidth: "50Mbps sustained"
```

### Identified Bottlenecks & Mitigation

| **Component** | **Bottleneck** | **Impact at Scale** | **Mitigation Strategy** |
|---------------|----------------|--------------------|-----------------------|
| **Redis Memory** | Task queue growth | OOM at 3000+ providers | Implement queue sharding, TTL cleanup |
| **WebSocket Connections** | File descriptor limits | Connection drops at 10k+ | Connection pooling, async multiplexing |
| **Consensus Latency** | Network round-trips | >500ms at global scale | Regional consensus clusters |
| **Database Writes** | Transparency log volume | Write contention | Batch logging, async writes |
| **Provider Discovery** | DHT lookup time | O(log n) scaling issue | Precomputed provider indices |
| **Task Distribution** | Single relayer hotspot | CPU limit at 1000+ tasks/s | Consistent hashing, load balancing |

---

## 6. Migration Milestones & Timeline

### 30-Day Milestone: Transparent Hybrid Live

**Week 1: Infrastructure Foundation**
- [ ] Deploy 3-node relayer cluster with application load balancer
- [ ] Migrate to Redis Cluster (3 masters + 3 replicas)  
- [ ] Implement PostgreSQL for transparency logging
- [ ] Set up comprehensive monitoring stack (Prometheus/Grafana)

**Week 2: Transparency Features**
- [ ] Implement cryptographic proof generation for all task assignments
- [ ] Deploy transparency audit APIs returning Merkle proofs
- [ ] Provider dashboard showing assignment fairness metrics
- [ ] On-chain transparency contract for audit trail verification

**Week 3: Enhanced Resilience**
- [ ] Circuit breaker patterns for all external dependencies
- [ ] Automated failover testing and validation
- [ ] Provider connection redundancy (multi-path WebSocket)
- [ ] Geographic distribution for disaster recovery

**Week 4: Performance & Security Validation**
- [ ] Load testing with 2x current provider count
- [ ] Security audit of transparency mechanisms
- [ ] SLA compliance measurement and tuning
- [ ] Provider onboarding documentation for transparent mode

**Success Criteria**: 
- Event processing <100ms maintained under 2x load
- 99.9% uptime achieved with no single point of failure
- Full transparency audit trail for every task assignment
- Zero loss of provider connections during relayer failovers

### 60-Day Milestone: Selective Decentralization

**Week 5-6: Coordinator Election Framework**
- [ ] Smart contract for stake-based coordinator election
- [ ] Provider node capability to act as task coordinators
- [ ] Consensus mechanism for coordinator rotation (weekly)
- [ ] Stake slashing for coordinator misbehavior  

**Week 7-8: Distributed Task Coordination**
- [ ] P2P task distribution bypassing central relayer for 20% of tasks
- [ ] Provider-to-provider result verification
- [ ] Load balancing across elected coordinators
- [ ] Geographic partitioning for reduced latency

**Success Criteria**:
- 20% of tasks successfully coordinated P2P without relayer
- Coordinator elections complete within 5 minutes
- Geographic task latency reduced by 30% for P2P tasks
- Zero Byzantine failures during coordinator operation

### 90-Day Milestone: Progressive Decentralization

**Week 9-12: Full P2P Transition Plan**
- [ ] 50% task coordination through elected coordinators
- [ ] Consensus resilience testing with Byzantine node simulation
- [ ] Provider economic incentive balancing (stake vs earnings)
- [ ] Network partition recovery and healing mechanisms

**Success Criteria**:
- 95% consensus success rate under 10% Byzantine node simulation
- Economic incentives balanced: coordinator rewards vs operational costs
- Network healing from 30% partition within 15 minutes
- Provider earnings distribution maintains fairness across geographic regions

---

## 7. Risk Mitigation Matrix

| **Risk Category** | **Probability** | **Impact** | **Mitigation Plan** |
|-------------------|-----------------|------------|---------------------|
| **Provider Churn** | High | High | Stake-based commitment, graduated rewards |
| **Consensus Attack** | Medium | Critical | 66% Byzantine tolerance, stake slashing |
| **Network Partition** | Medium | High | Geographic redundancy, partition healing |
| **Performance Degradation** | High | Medium | Gradual migration, performance gates |
| **Regulatory Issues** | Low | Critical | Legal review, compliance documentation |
| **Economic Manipulation** | Medium | High | Token economics audit, whale protection |

---

## Implementation Team & Responsibilities

| **Role** | **30-Day Focus** | **60-Day Focus** | **90-Day Focus** |
|----------|-----------------|------------------|------------------|
| **Systems Engineer** | Redis clustering, failover automation | P2P networking, consensus implementation | Performance optimization, scaling validation |
| **Security Expert** | Transparency proofs, audit mechanisms | Stake slashing, Byzantine protection | Economic attack prevention, game theory |
| **Blockchain Engineer** | Governance contracts, transparency on-chain | Coordinator election, stake management | Economic incentive balancing |
| **DevOps Engineer** | Multi-region deployment, monitoring | Automated testing, chaos engineering | Production scaling, capacity management |
| **Frontend Engineer** | Provider transparency dashboard | Coordinator election visibility | Network health visualization |

This plan provides a practical path from centralized relayer to decentralized orchestration while maintaining security, performance, and user experience throughout the transition.