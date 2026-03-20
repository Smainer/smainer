---
description: "Use when running connection checks, cross-component integration reviews, system readiness meetings, or any task involving relayer/provider/telegram/frontend/contracts/desktop/repo coordination. Enforces interface inventory, endpoint evidence, edge ownership, and code-owner verification for every data-flow link."
---

# Component Interface Governance

Apply this instruction whenever work touches multiple Smainer components or agent domains.

Default scope: production-critical paths (relayer/provider/telegram/frontend/contracts).
If a task is outside that set, apply this only when the task explicitly impacts cross-component data flow.

## Required Interface Card Per Component

Every participating component must publish an Interface Card before integration sign-off.

Required fields:
- Component name
- Responsible agent role
- Code owner (GitHub handle or team)
- Source paths (code locations implementing interface)
- Exposed endpoints (REST, WebSocket, RPC, queue topics, file handoff paths)
- Expected input/output contract summary
- Healthcheck command and expected success output
- Current runtime status: `healthy`, `degraded`, or `down`
- Last verified timestamp (UTC)

If any field is unknown, mark it explicitly as `unknown` and flag it as a warning.

## Edge Contract Rule (Bidirectional Awareness)

For every edge in the pipeline graph (A -> B):
- Record producer component (A) and consumer component (B)
- Record exact interface path/endpoint/topic used on both sides
- Record who owns the contract on each side
- Record latest status from both sides, not only one side
- Record code-owner verification state for both sides

No edge is considered valid unless both connected components report matching contract expectations.

## Verification Evidence Standard

Do not accept claims like "working" without evidence.

For each endpoint/interface, provide:
- Verification method (command, test, log probe, or health endpoint)
- Short evidence snippet (status code, websocket connect success, queue depth, test pass)
- Time of evidence collection (UTC)

When evidence cannot be produced, mark interface as `unverified`.

## Connection Check Meeting Protocol

When facilitating a cross-component connection check meeting, always output:
1. Component registry table (all Interface Cards)
2. Data-flow edge matrix (all A -> B links)
3. Mismatch list (schema/path/status mismatches)
4. Blockers list (missing evidence, unknown owner, failed checks)
5. Owner action list with deadlines

Meeting should not be marked `ready` unless:
- All critical edges are `verified`
- All critical components have identified owners
- All failing checks have an assigned owner and ETA

Default enforcement mode: warning-first. Missing evidence should create action items and owners, not automatic merge/deploy blocks.

## Agent Reporting Format

Use this compact structure in status responses:

- `Component`: <name>
- `Owner`: <agent role> / <code owner>
- `Interface`: <endpoint or path>
- `Depends on`: <upstream components>
- `Dependent for`: <downstream components>
- `Verification`: <command or check>
- `Evidence`: <result>
- `Status`: <healthy|degraded|down|unverified>
- `Last Check`: <UTC timestamp>

## Escalation Rule

Escalate immediately when any of these occur:
- Endpoint path mismatch between two components
- One side reports healthy and the peer reports failing
- Interface has no clear code owner
- Contract changed without synchronized downstream confirmation

When escalating, include impacted edges, owner, and the exact failing verification artifact.
