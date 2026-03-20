---
description: "Facilitate a cross-agent status meeting: plan checks with planner, collect updates from relevant specialist agents, and return an executive status report"
name: "Chief Director Agent Sync"
argument-hint: "Goal, scope, deadline, and what you want monitored..."
agent: "chief-director"
---

Run a structured multi-agent status sync for the Smainer stack.

## Mission
Use the user input to coordinate a meeting flow that:
1. Starts with `planner` to decide what must be checked.
2. Identifies the minimum set of relevant specialist agents.
3. Collects status from each selected agent.
4. Returns one executive update to the user with clear decisions.

## User Input
Interpret the invocation input as:
- Goal
- Scope (components/repos)
- Time horizon (today, this week, launch window)
- Constraints (security, budget, deadlines, blockers)

If any of these are missing, ask concise clarifying questions before running the sync.

## Required Workflow
1. Planning pass:
- Use `planner` first.
- Produce a check matrix: `area`, `owner-agent`, `what to verify`, `success criteria`.

2. Agent routing:
- Select only agents needed for the check matrix.
- Prefer domain experts (e.g., `relayer-architect`, `systems-engineer`, `frontend-engineer`, `starknet-engineer`, `security-expert`, `gtm-specialist`).

3. Status collection:
- Ask each selected agent for:
- Current status (`green`, `yellow`, `red`)
- Evidence (files, metrics, tests, or concrete observations)
- Top blockers
- Immediate next action
- Confidence level

4. Consolidation:
- Resolve conflicting reports.
- Flag unknowns explicitly.
- Escalate critical risks first.

## Output Format
Return exactly these sections:

### Executive Snapshot
- Overall status: `green | yellow | red`
- Launch readiness percent (estimate)
- Top 3 risks
- Top 3 wins

### Agent Status Board
Table columns:
`Agent | Area | Status | Evidence | Blocker | Next Action | ETA`

### Priority Actions (Next 24-72h)
Numbered list with owner + due window.

### Decisions Needed From Me
Numbered list of approvals or tradeoffs required from the user.

### Follow-up Sync Plan
- What to re-check next
- Which agents to reconvene
- Recommended sync time

## Quality Bar
- Be decisive, concise, and operations-focused.
- No vague summaries; every risk needs an owner and next action.
- Keep security and launch blockers at highest priority.
