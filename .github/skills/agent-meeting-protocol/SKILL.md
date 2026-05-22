---
name: agent-meeting-protocol
description: "Loaded by chief-director only. Defines all three meeting types (Status Sync, Blocker Resolution, Cross-Domain Alignment), their facilitation sequences, the Meeting Minutes schema, and the when-to-meet vs direct-delegate decision tree."
argument-hint: "Meeting type: status-sync | blocker-resolution | cross-domain-alignment | [describe the situation]"
user-invocable: false
disable-model-invocation: false
---

# Agent Meeting Protocol

## Purpose

This skill defines how `chief-director` facilitates structured meetings between specialist agents.

A meeting is **not** a conversation. It is a structured, bounded sequence of `runSubagent` calls that produces a binding output (Meeting Minutes or Executive Snapshot) **before any implementation begins**.

Load this skill before facilitating any meeting. Use `agent-pipeline-contract` skill for all envelope schemas.

---

## Meeting Decision Tree

Run this top-to-bottom before every delegation. Stop at first match.

```
1. Is the task single-domain with no output consumed by another domain?
   YES → DELEGATE DIRECTLY to specialist. No meeting.
   NO  → continue

2. Does implementing Task B require conforming to rules owned by Agent A (different domain)?
   YES → CROSS-DOMAIN ALIGNMENT MEETING before issuing any Task Manifest
   NO  → continue

3. Is a Delivery Report arriving with status=blocked?
   YES → BLOCKER RESOLUTION MEETING
   NO  → continue

4. Is a Validation Report arriving with severity=CRITICAL?
   YES → BLOCKER RESOLUTION MEETING (security-expert mandatory participant)
   NO  → continue

5. Are two Delivery Reports in conflict on a shared interface?
   YES → CROSS-DOMAIN ALIGNMENT MEETING to resolve interface
   NO  → continue

6. Is the user requesting system health, launch readiness, or cross-component status?
   YES → STATUS SYNC
   NO  → DELEGATE DIRECTLY
```

**Never skip a meeting to save time.** Resolving a protocol conflict after implementation costs 10× more than a 3-step alignment meeting before the first line is written.

---

## Meeting Type 1: Status Sync

**Purpose**: Collect project health across components. Observation only — no implementation decisions.
**Trigger**: User asks for system status, launch readiness, or component health check.
**Output**: Executive Snapshot (not Meeting Minutes — this is read-only).

### Facilitation Sequence

**Step 1** — Invoke `planner` to determine which agents to query:

```javascript
runSubagent({
  agentName: "planner",
  description: "determine status check matrix",
  prompt: `
    ## Context
    Status sync requested for: <scope/goal>
    Time horizon: <today | this week | launch window>

    ## Objective
    Produce a check matrix: minimum set of agents to query, what to verify per area,
    and success criteria per area.

    ## Output Format
    JSON array:
    [{ "agent": "relayer-architect", "area": "WebSocket stability",
       "what_to_verify": "...", "success_criteria": "..." }]

    ## Constraint
    Minimum agents only. No agents with no relevant status to report.
  `
})
```

**Step 2** — Fan out status queries to each agent in the check matrix:

```javascript
// For each entry in the check matrix:
runSubagent({
  agentName: "<agent-name>",
  description: "status sync report",
  prompt: `
    ## Context
    Status Sync meeting facilitated by chief-director.
    Component: <area>
    What to verify: <what_to_verify>
    Success criteria: <success_criteria>

    ## Request
    Respond using your ## Status Report Protocol section.
    Return the five-field Status Report JSON.
  `
})
```

**Step 3** — Consolidate into Executive Snapshot:

```markdown
## Executive Snapshot — <date>

**Overall Status**: green | yellow | red
**Launch Readiness**: <N>%
**Top 3 Risks**: ...
**Top 3 Wins**: ...

## Agent Status Board
| Agent | Area | Status | Evidence | Blocker | Next Action | Confidence |

## Priority Actions (Next 24–72h)
1. [owner] [action] — due <window>

## Decisions Needed From User
1. ...

## Follow-Up Sync
- Re-check: ...
- Recommended timing: ...
```

---

## Meeting Type 2: Blocker Resolution Meeting

**Purpose**: Unblock a stalled Delivery Report by aligning blocked agent with dependency owner.
**Trigger**: Delivery Report `status=blocked` OR Validation Report `severity=CRITICAL`.
**Output**: Unblock Task Manifest (fed directly to blocked agent).

### Facilitation Sequence

**Step 1** — Identify blocked agent and upstream dependency owner from the Delivery Report or Validation Report.

**Step 2** — Invoke blocked agent for their contribution:

```javascript
runSubagent({
  agentName: "<blocked-agent>",
  description: "blocker resolution — your constraints",
  prompt: `
    ## Context
    Blocker Resolution Meeting: MTG-<NNN>
    Your Delivery Report DR-<NNN> is blocked: <blocking_issue>

    ## Request
    Produce a Meeting Contribution (meeting_contribution envelope from agent-pipeline-contract).
    Your role: "implementer"
    Focus on: what you need to unblock, constraints you're working within,
    flexibility you have to work around the issue.
  `
})
```

**Step 3** — Invoke upstream owner with blocked agent's contribution:

```javascript
runSubagent({
  agentName: "<upstream-owner>",
  description: "blocker resolution — resolution options",
  prompt: `
    ## Context
    Blocker Resolution Meeting: MTG-<NNN>
    <blocked-agent> is blocked on your output: <description>

    Their contribution:
    <insert Meeting Contribution from Step 2>

    ## Request
    Produce a Meeting Contribution (meeting_contribution envelope).
    Your role: "rule-setter"
    Focus on: resolution options, what you can provide, hard constraints you cannot relax.
  `
})
```

**Step 4** — Director arbitrates if positions conflict. Produce unblock Task Manifest with:
- `implementation_constraints[]` from agreed resolution
- Updated `acceptance_criteria[]` reflecting the unblocked path
- Clear `objective` for the unblocked work

---

## Meeting Type 3: Cross-Domain Alignment Meeting

**Purpose**: Establish a binding protocol contract between a rule-setter (Agent A) and implementer (Agent B) **before any code is written**.
**Trigger**: Task B output must conform to rules owned by Agent A in a different domain.
**Output**: Meeting Minutes → inline into Agent B's Task Manifest `implementation_constraints[]`.

### Facilitation Sequence

**Step 1** — Identify rule-setter (Agent A) and implementer (Agent B).

Common pairs (from PIPELINE_TOPOLOGY.md):
- security-expert ↔ systems-engineer (deployment protocols)
- security-expert ↔ relayer-architect (auth, callbacks)
- security-expert ↔ telegram-bot-developer (webhook, payments)
- fee-economist ↔ relayer-architect (fee routing)
- starknet-engineer ↔ relayer-architect (event schemas)
- brand-designer ↔ frontend-engineer (design tokens, component API)
- relayer-architect ↔ frontend-engineer (API shapes)
- relayer-architect ↔ telegram-bot-developer (payload schemas)

**Step 2** — Invoke Agent A (rule-setter) with task context:

```javascript
runSubagent({
  agentName: "<rule-setter>",
  description: "alignment meeting — domain constraints",
  prompt: `
    ## Context
    Cross-Domain Alignment Meeting: MTG-<NNN>
    Topic: <what is being designed>
    You are the rule-setter. <implementer> will implement this and must conform
    to your domain's requirements.

    Task context: <details of what Agent B will implement>

    ## Request
    Produce a Meeting Contribution (meeting_contribution envelope, role: "rule-setter").
    1. What your domain technically requires
    2. What is non-negotiable (hard_constraints)
    3. What you can be flexible on
    4. What you need to know from <implementer>
  `
})
```

**Step 3** — Invoke Agent B (implementer) with Agent A's constraints:

```javascript
runSubagent({
  agentName: "<implementer>",
  description: "alignment meeting — counterproposal",
  prompt: `
    ## Context
    Cross-Domain Alignment Meeting: MTG-<NNN>
    Topic: <what you will implement>
    Agent A (<rule-setter>) has provided these constraints:
    <insert Agent A's Meeting Contribution>

    ## Request
    Produce a Meeting Contribution (meeting_contribution envelope, role: "implementer").
    1. Which constraints you can implement as stated
    2. Which constraints create technical problems — explain why (specific, not vague)
    3. What modifications or alternatives you propose for conflicting items
    4. What flexibility Agent A has in how a constraint is expressed
  `
})
```

**Step 4** — Director arbitrates if positions conflict:
- Ruling priority: **security > correctness > performance > convenience**
- Director's ruling is final and recorded in Meeting Minutes `arbitrated_by` field
- If no conflict: proceed directly to Step 5

**Step 5** — Obtain Agent A sign-off (or skip if no conflicts remained after arbitration):

```javascript
runSubagent({
  agentName: "<rule-setter>",
  description: "alignment meeting — sign-off",
  prompt: `
    ## Context
    Cross-Domain Alignment Meeting: MTG-<NNN>
    Proposed implementation approach from <implementer>:
    <insert Agent B's Meeting Contribution / arbitration ruling>

    ## Request
    Return ONE of:
    - { "signed_off": true, "notes": "..." }
    - { "signed_off": false, "objection": "<must cite a specific hard_constraint>" }

    If you have no valid hard_constraint objection, you must sign off.
    Style preference is not a valid objection.
  `
})
```

**Step 6** — Produce Meeting Minutes using the `meeting_minutes` envelope from `agent-pipeline-contract`.

```javascript
// Example:
const minutes = {
  envelope_type: "meeting_minutes",
  meeting_id: "MTG-NNN",
  meeting_type: "cross-domain-alignment",
  participants: ["<rule-setter>", "<implementer>"],
  context: "<what was being designed>",
  agreed_items: [...],
  open_items: [...],
  implementation_constraints: [
    // These go VERBATIM into Agent B's Task Manifest
  ],
  signed_off_by: ["<rule-setter>"],
  arbitrated_by: "chief-director"
}
```

**Step 7** — Issue Agent B's Task Manifest. Copy all `implementation_constraints[]` from Meeting Minutes verbatim into the manifest's `implementation_constraints[]` field. No paraphrasing.

---

## Escalation Rules

| Signal | Action |
|--------|--------|
| Two consecutive blocked reports on same issue | Director resolves via direct arbitration — no further meetings |
| Agent A refuses sign-off without citing a hard_constraint | Director overrides, records override in Meeting Minutes |
| Meeting produces open_items that block implementation | Create follow-up meeting before releasing Task Manifest |
| Agent B's counterproposal reveals Agent A's constraint was unenforceable | Director reshapes constraint to be implementable, records in Meeting Minutes |

---

## Quality Bar for Every Meeting

Before closing any meeting and issuing Task Manifests, verify:

- [ ] All `hard_constraints` from the rule-setter are addressed (accepted, modified with agreement, or arbitrated)
- [ ] `implementation_constraints[]` in Meeting Minutes are specific enough to be directly coded against
- [ ] No `open_items` are blocking implementation (create follow-up meeting if so)
- [ ] At least one participant has signed off (or Director has recorded arbitration)
