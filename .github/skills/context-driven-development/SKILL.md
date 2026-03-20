---
name: context-driven-development
description: "Use when orchestrating multi-agent work, planning sprints, routing tasks to specialists, or any workflow where multiple agents must operate in parallel without drift. CDD ensures every agent shares a live project context so alignment comes from understanding, not rigid handoffs."
argument-hint: "Goal statement, project context, agent assignments..."
user-invocable: true
disable-model-invocation: false
---

# Context Driven Development (CDD)

## Core Principle

Agents align because they **understand the environment**, not because they receive narrow task specs.

Traditional orchestration passes tasks down a chain:
Director -> Task spec -> Agent -> Output -> Validation

CDD inverts the information flow:
Director -> **Full Context + Goal** -> All Agents in parallel -> Self-aligned outputs

The difference: every agent sees the same project reality. Conflicts are prevented by shared understanding, not caught after the fact by review.

## When to Use

- Multi-agent task execution across 2+ components or domains.
- Sprint planning where specialists must work in parallel.
- Any workflow where the `chief-director` routes work to specialist agents.
- System-wide changes (API contract shifts, architecture pivots, launch coordination).
- When past orchestration produced misaligned outputs because agents lacked context.

Do not use for single-agent, single-file edits where full context propagation adds overhead without value.

## The Context Document

Every CDD session begins by assembling a **Context Document** — the shared reality that every participating agent receives. This is the coordination primitive.

### Required Sections

```
## 1. Goal
One sentence. What the Director wants achieved this wave.
Example: "All provider WebSocket reconnection paths handle auth re-registration within 5s."

## 2. Architecture State
Current system topology relevant to the goal.
- Which components are involved (relayer, provider, frontend, contracts, telegram, desktop).
- How they connect (endpoints, WebSocket paths, Redis queues, contract calls).
- What is healthy, degraded, or down right now.

## 3. Constraints
Non-negotiable boundaries.
- Security: no secret leakage, no unsigned payloads.
- Performance: latency budgets, resource limits.
- Compatibility: existing API contracts that must not break.
- Scope: what is explicitly out of bounds.

## 4. Component Context
Per-component snapshot for each involved component:
- Relevant source paths.
- Current behavior (what it does today).
- Target behavior (what it should do after this wave).
- Owner (agent role + code owner).

## 5. Dependencies and Edges
Which components depend on which.
- Data-flow direction (A produces, B consumes).
- Contract expectations on both sides.
- Known mismatches or unverified edges.

## 6. Success Criteria
Observable evidence that the goal is met.
- Specific checks, test commands, or log patterns.
- Not vague ("it works") — concrete ("ws connection established in <2s, auth event acked").
```

### Building the Context Document

The Director (typically `chief-director`) assembles the Context Document by:
1. Reading relevant source files and configs.
2. Pulling component health status (healthchecks, logs, recent test results).
3. Reviewing the interface governance cards if they exist.
4. Stating the goal and constraints explicitly.

If any section is unknown, mark it `UNKNOWN — requires discovery` and assign a discovery task before execution begins.

## Goal Cascade

Goals flow from Director downward, but every level retains the full context.

```
Director Goal: "Ship provider auto-reconnect for GTC demo"
    │
    ├── systems-engineer goal: "Implement exponential backoff reconnect loop with re-auth"
    │   (receives: full Context Document)
    │
    ├── relayer-architect goal: "Handle reconnecting nodes without duplicate registration"
    │   (receives: full Context Document)
    │
    └── security-expert goal: "Verify reconnect path cannot bypass auth or replay stale tokens"
        (receives: full Context Document)
```

Each specialist sees:
- The Director's top-level goal (so they understand *why*).
- The full architecture state (so they don't break adjacent components).
- The constraints (so they self-enforce boundaries).
- Other agents' goals (so they anticipate integration points).

This eliminates the "worked in isolation, broke in integration" failure mode.

## Parallel Execution Protocol

Because all agents share context, they can execute in parallel with confidence.

### Rules for Parallel Work

1. **Read-only overlap is safe.** Multiple agents can read the same files. No coordination needed.
2. **Write isolation by component.** Each agent owns writes to their component's source paths. No two agents write to the same file in the same wave.
3. **Shared interface changes require a contract announcement.** If Agent A needs to change an interface that Agent B consumes, Agent A must declare the change in the Context Document *before* the wave starts. Agent B adjusts proactively.
4. **Edge validation after each wave.** After parallel execution, run cross-component edge checks before starting the next wave.

### Wave Structure

```
Wave N:
  1. Director updates Context Document with current state.
  2. Director assigns goals to specialists with full context.
  3. Specialists execute in parallel (no blocking on each other).
  4. Specialists report: changes made, evidence collected, edge impacts.
  5. Director validates: cross-component edges, goal progress, constraint adherence.
  6. Director updates Context Document for Wave N+1.
```

## Decision Logic

- **If an agent discovers the Context Document is stale or wrong**: Stop. Report the discrepancy to the Director. Director updates context before the agent continues.
- **If two agents need to modify the same interface**: Escalate to Director. Director sequences the change or creates a joint task.
- **If a goal is blocked by missing context**: Create a discovery task. Do not guess. Mark the goal as `blocked-pending-context`.
- **If an agent's output contradicts another agent's output**: The Context Document is the tiebreaker. If the document is ambiguous, Director resolves.
- **If constraints conflict with the goal**: Constraints win. Escalate to Director to renegotiate the goal, never the constraint.

## Integration with Existing Skills

CDD is a **methodology layer** that other skills execute under:

| Skill | CDD Integration |
|---|---|
| `e2e-agent-orchestrator` | Orchestrator follows CDD by building a Context Document at intake and propagating it to every wave. |
| `api-contract-alignment` | API contracts are a subset of the Context Document's "Dependencies and Edges" section. |
| `component-interface-governance` | Interface Cards feed directly into the "Component Context" section. |
| `systemd-service-hardening` | Constraints section captures resource limits and security posture for service deployments. |

## Quality Checks

A CDD wave passes quality only when:

- **Context gate**: Every agent confirms they had sufficient context to execute without guessing.
- **Alignment gate**: No agent's output contradicts another agent's output or the stated goal.
- **Edge gate**: All cross-component interfaces are verified after the wave (not just assumed).
- **Goal gate**: Director confirms the wave moved measurably toward the top-level goal.
- **Constraint gate**: No constraint was violated, even under time pressure.

## Anti-Patterns

Avoid these — they indicate CDD is not being followed:

| Anti-Pattern | CDD Correction |
|---|---|
| Agent receives only a task title, no context | Always attach the Context Document |
| Agent asks "what does component X do?" mid-execution | Context Document should have answered this upfront |
| Two agents produce conflicting API changes | Write isolation + contract announcements were skipped |
| Director validates by re-reading all code | Success criteria should have been defined upfront with concrete checks |
| Agent operates on stale assumptions | Context Document was not refreshed between waves |
| Goal is vague ("make it better") | Director must state a measurable, observable goal |

## Prompt Starters

- Use CDD to coordinate this multi-component change: <describe goal>. Build the Context Document first, then assign waves.
- Apply Context Driven Development: goal is <X>, involved components are <Y>, constraints are <Z>. Route to specialists with full context.
- Run this task list under CDD methodology — share full project context with every agent and execute in parallel waves.
