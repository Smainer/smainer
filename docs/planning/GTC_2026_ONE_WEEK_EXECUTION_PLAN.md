# Smainer Accelerate: Execution-Ready Plan (Separate Project)

## 1) Current Wave Summary
- Decision locked: build Smainer Accelerate as a separate project first.
- Core Smainer remains stable and unchanged for current live-test path.
- Public messaging: add "In Work / Soon" teaser on site.
- Provider/miner path: opt-in upgrade only, with rollback.

## 2) Non-Negotiable Decisions
- Payment and settlement: STRK only.
- No forced migration from current runtime.
- Security-first rollout: signed artifacts, strict sandbox controls, clear fallback path.
- Product strategy: separate optimization plane, integrated by adapter.

## 3) NVIDIA Signal Impact (Why This Plan Is Correct)
NVIDIA Agent Toolkit and related runtime/sandbox announcements validate market demand for:
- Always-on safe agent execution.
- Policy-based runtime control.
- Evaluation-driven quality and trust.

Plan impact:
- No strategy pivot needed.
- Increase priority of guardrails and evaluation systems in Accelerate HLD.

## 4) HLD (High-Level Design) Snapshot

### 4.1 Product Boundaries
- Smainer Core: task routing, provider network, current runtime, STRK settlement.
- Smainer Accelerate: optimization, artifact build/sign, runtime policy, evaluation, performance telemetry.

### 4.2 Core Components
1. Accelerate API Gateway
- Auth, quotas, tenant policy, request intake.

2. Compile and Optimize Service
- Safe optimization modes: safe, balanced, aggressive.

3. Artifact Registry
- Signed artifacts, compatibility metadata, cache lookup.

4. Runtime Policy and Guardrails Service
- Tool/runtime allowlists, timeout policies, safety checks.

5. Evaluation and Trace Service
- Reasoning quality gates, eval scorecards, audit traces.

6. Compatibility Engine
- Match artifacts to provider capabilities and fallback rules.

7. Benchmark and Telemetry Service
- p50/p95/p99 latency, throughput, fallback rate, cache hit rate.

8. Core Integration Adapter (inside Smainer Core)
- Calls Accelerate APIs and preserves safe fallback to non-optimized execution.

### 4.3 Logical Data Flow
1. Core flags task as optimization-eligible.
2. Adapter requests artifact and policy from Accelerate.
3. Accelerate returns signed artifact + compatibility + guardrail profile.
4. Core routes task to compatible provider.
5. Provider verifies signature and executes.
6. Telemetry and eval traces return to dashboards.
7. If optimize fails, Core falls back automatically to standard path.

### 4.4 Security Controls
- Mandatory signature verification for artifacts.
- Compile and runtime limits (time, memory, allowed backends).
- Banned operation checks and policy deny paths.
- Separate incident playbook for Accelerate plane.

### 4.5 Non-Goals (Phase 1)
- No new token.
- No full migration of all tasks to optimized path.
- No breaking changes to provider defaults.

## 5) Task Board (Easy To Manage)

Status legend:
- not-started
- in-progress
- completed
- blocked

| ID | Title | Owner | Priority | Depends On | Status |
|---|---|---|---|---|---|
| A-001 | Finalize Accelerate HLD and boundaries | @planner + @chief-director | CRITICAL | none | not-started |
| A-002 | Define API contracts v0 (optimize/artifact/policy) | @relayer-architect | CRITICAL | A-001 | not-started |
| A-003 | Define provider upgrade levels and rollback flow | @systems-engineer | CRITICAL | A-001 | not-started |
| A-004 | Define artifact trust chain and threat model | @security-expert | CRITICAL | A-001 | not-started |
| A-005 | Define benchmark gate metrics and test methodology | @ai-inference-benchmarker | HIGH | A-002 | not-started |
| A-006 | Publish teaser content and waitlist instrumentation | @frontend-engineer + @gtm-specialist | HIGH | A-001 | not-started |
| A-007 | Branch governance and CI gate setup | @repository-architect | HIGH | A-001 | not-started |
| A-008 | Documentation pack and onboarding kit | @technical-copywriter | HIGH | A-002, A-003, A-004 | not-started |
| A-009 | MVP ticket decomposition by component | @planner | HIGH | A-002, A-003, A-004, A-005 | not-started |
| A-010 | Kickoff handoff package for new session | @chief-director | CRITICAL | A-008, A-009 | not-started |

## 6) Wave Plan (7 Days)

### Day 1
- A-001 complete with explicit service boundaries.
- A-007 branch model and PR rules defined.

### Day 2
- A-002 draft contracts for optimize and artifact endpoints.
- A-003 provider upgrade level matrix defined.

### Day 3
- A-004 threat model + required controls complete.
- A-006 teaser copy approved and UI placement mapped.

### Day 4
- A-005 benchmark methodology with launch gates finalized.
- A-008 docs structure and templates created.

### Day 5
- A-006 teaser + analytics verification shipped.
- A-003 rollback and upgrade operator guide drafted.

### Day 6
- A-009 component ticket set generated and assigned.
- Architecture and risk review pass.

### Day 7
- A-010 handoff package finalized for next session.
- First implementation sprint ready to start.

## 7) Documentation Update Tasks (Explicit)

### 7.1 New Docs To Create
- docs/accelerate/HLD.md
- docs/accelerate/API_V0.md
- docs/accelerate/SECURITY_MODEL.md
- docs/accelerate/PROVIDER_UPGRADE_GUIDE.md
- docs/accelerate/BENCHMARK_GATES.md
- docs/accelerate/INCIDENT_RUNBOOK.md
- docs/accelerate/SESSION_KICKOFF.md

### 7.2 Existing Docs To Update
- README.md: add Accelerate teaser status and scope boundaries.
- LAUNCH_GUIDE.md: add "separate-project in-work" status lane.
- SYSTEM_ARCHITECTURE.md: add Accelerate plane diagram and adapter boundary.
- SECURITY_GATES_CHECKLIST.md: add artifact/policy/eval gates.
- FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md: add opt-in miner upgrade preview section.

### 7.3 Doc Acceptance Criteria
- Every new component has owner, purpose, inputs, outputs, failure modes.
- Every critical API includes request/response and fallback behavior.
- Security doc includes deny paths and incident actions.
- Upgrade guide includes one-command rollback procedure.

## 8) Improvement Examples (Ready To Execute)

### Example 1: Reliability Improvement
Before:
- Optimization failure can block request path.

After:
- Automatic fallback to standard path with zero user interruption.

Success metric:
- fallback_rate visible and task completion unaffected.

### Example 2: Miner Experience Improvement
Before:
- Unclear whether miner hardware is compatible for optimized workloads.

After:
- Upgrade checker reports compatibility tier and safe next step.

Success metric:
- miners can complete compatibility check and rollback without manual intervention.

### Example 3: Security Improvement
Before:
- Runtime artifact trust assumptions not explicit.

After:
- Signature verification + policy checks enforced before execution.

Success metric:
- unsigned or incompatible artifact execution is denied and audited.

### Example 4: Product Clarity Improvement
Before:
- Users unsure if current service is being replaced.

After:
- Site clearly states: current Smainer unchanged, Accelerate in work/soon.

Success metric:
- reduced support confusion and increased waitlist conversion.

## 9) Validation Results Checklist
- Scope gate: separate project only, no core destabilization.
- Correctness gate: HLD and API contracts reviewed by owners.
- Safety gate: security controls and deny paths documented.
- Verification gate: benchmark and launch metrics defined.
- Integration gate: adapter behavior and fallback semantics specified.
- Communication gate: teaser messaging aligned with delivery status.

## 10) Remaining Tasks With Next Owners
1. @planner
- Convert A-001 to A-010 into implementation epics and child tasks.

2. @relayer-architect
- Deliver API v0 contract draft for adapter integration.

3. @systems-engineer
- Deliver provider compatibility schema and rollback script outline.

4. @security-expert
- Deliver threat model and artifact trust matrix.

5. @frontend-engineer + @gtm-specialist
- Deliver teaser placement and waitlist event schema.

## 11) Final Closure Report Template
Use this template when this wave is complete:

- Completed:
  - [list task IDs completed]

- Blocked:
  - [task ID, blocker, unblock owner, ETA]

- Evidence:
  - [doc links, PR links, test output references]

- Risks remaining:
  - [risk + mitigation]

- Next wave start:
  - [first 3 tasks and owners]

## 12) New Session Kickoff Pack
Copy/paste this at the start of the next session:

"Continue Smainer Accelerate separate-project execution. Use task board IDs A-001 to A-010. Keep core runtime stable, ship teaser In Work/Soon, and prepare provider opt-in upgrade and rollback readiness. Produce implementation tickets and start with API v0 + security trust chain + benchmark gates."

## 13) Implementation-Ready Ticket Seeds
Use these as direct issue drafts.

### A-001: Finalize Accelerate HLD and Service Boundaries
- Owner: @planner + @chief-director
- Deliverable:
  - Final architecture boundary map for Core vs Accelerate.
  - Final dependency diagram and critical path.
- Acceptance Criteria:
  - All components in section 4.2 mapped to one owner.
  - No unresolved high-risk boundary decisions.

### A-002: API Contracts v0 (Optimize, Artifact, Policy)
- Owner: @relayer-architect
- Deliverable:
  - Request and response contracts.
  - Error and fallback contract behavior.
- Acceptance Criteria:
  - Contract examples include success, partial, and fallback responses.
  - Adapter integration assumptions documented.

### A-003: Provider Upgrade Levels and Rollback Flow
- Owner: @systems-engineer
- Deliverable:
  - Compatibility schema and operator runbook.
  - One-command rollback flow definition.
- Acceptance Criteria:
  - Level 0 through Level 3 behavior clearly defined.
  - Rollback path tested in dry-run mode.

### A-004: Artifact Trust Chain and Threat Model
- Owner: @security-expert
- Deliverable:
  - Trust chain diagram and verification points.
  - Threat model with controls and deny paths.
- Acceptance Criteria:
  - Unsigned artifact behavior is explicitly deny and audit.
  - Top abuse cases include mitigation owner and test plan.

### A-005: Benchmark Gates and Launch Metrics
- Owner: @ai-inference-benchmarker
- Deliverable:
  - p50, p95, p99 target definitions.
  - Throughput and fallback threshold gates.
- Acceptance Criteria:
  - Launch gates include fail and pass criteria.
  - Methodology is reproducible and documented.

### A-006: Teaser and Waitlist Launch
- Owner: @frontend-engineer + @gtm-specialist
- Deliverable:
  - In Work / Soon teaser component.
  - Waitlist event and conversion tracking.
- Acceptance Criteria:
  - Teaser appears in intended placements.
  - Analytics confirms events are firing correctly.

### A-007: Branch Governance and CI Rules
- Owner: @repository-architect
- Deliverable:
  - Branch naming rules and PR gate matrix.
  - Required checks for architecture and security docs.
- Acceptance Criteria:
  - Governance documented and shared with all owners.
  - CI blocks merge on missing critical docs.

### A-008: Documentation Pack and Onboarding Kit
- Owner: @technical-copywriter
- Deliverable:
  - Docs listed in section 7.1 completed as draft set.
  - Reader path for operator, developer, and miner roles.
- Acceptance Criteria:
  - Every draft has owner, status, and last-updated timestamp.
  - Links and references resolve correctly.

### A-009: MVP Ticket Decomposition
- Owner: @planner
- Deliverable:
  - Epics and child tasks mapped by component.
  - Dependency graph with critical path and parallel lanes.
- Acceptance Criteria:
  - Each ticket has a single owner.
  - Each ticket has measurable done criteria.

### A-010: Handoff Package for Next Session
- Owner: @chief-director
- Deliverable:
  - Session starter pack with ordered first tasks.
  - Open risks, blockers, and owner follow-ups.
- Acceptance Criteria:
  - New session can start without rediscovery.
  - No ambiguity on first 48 hours of work.

## 14) First Session Execution Checklist (90 Minutes)
1. Confirm ownership for A-001 to A-010.
2. Lock the branch model and review policy.
3. Finalize API contract skeleton and fallback semantics.
4. Confirm provider upgrade and rollback assumptions.
5. Confirm security trust chain checkpoints.
6. Open and assign all first-wave tickets.
7. Publish kickoff summary with timestamps and owners.
