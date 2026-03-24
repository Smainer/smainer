---
name: agent-meeting
description: "Use when facilitating a cross-agent meeting on a subject. The Director gathers each relevant specialist's analysis, summary, and improvement proposals, then produces a meeting file with all perspectives and a final Director opinion."
argument-hint: "Meeting subject / topic to discuss across agents..."
user-invocable: true
disable-model-invocation: false
---

# Agent Meeting Facilitation

## What This Skill Produces

A structured meeting where the Director consults every relevant specialist agent about a given subject. Each agent provides their domain-specific analysis, and the Director synthesizes everything into a meeting artifact file.

**Final output:** A markdown meeting file saved to `/home/smainer/Smainer/docs/meetings/` with:
- Meeting metadata (date, subject, attendees)
- Each agent's summary and improvement proposals
- Cross-agent conflicts or agreements noted
- Director's final opinion and recommended actions

## When to Use

- User says "facilitate a meeting about X" or "get everyone's input on X".
- A subject needs multi-domain perspective before a decision is made.
- Architecture reviews, launch readiness discussions, post-mortems, design critiques.
- Any topic where hearing from multiple specialists produces better outcomes than one agent acting alone.

Do not use for:
- Single-domain tasks where one agent is clearly the owner.
- Pure implementation work (use `director-orchestration` or `e2e-agent-orchestrator` instead).

## Meeting Procedure

### Phase 1: Identify Attendees

Given the subject, select which agents have a relevant perspective. Use this mapping:

| Domain Signal in Subject | Invite Agent |
|---|---|
| API, endpoints, WebSocket, Redis, scheduling | `relayer-architect` |
| Daemon, systemd, GPU, Runpod, DO, infra | `systems-engineer` |
| Contracts, Cairo, Starknet, escrow, token | `starknet-engineer` |
| UI, frontend, wallet UX, dashboard, React | `frontend-engineer` |
| Telegram bot, MiniApp, Telegram UX | `Telegram Bot Developer` |
| Security, auth, keys, threats, audit | `security-expert` |
| Git, CI/CD, releases, repo structure | `repository-architect` |
| Fees, pricing, economics, treasury | `fee-economist` |
| Copy, messaging, marketing, CTAs | `marketing-copywriter` |
| Brand, visual, design, aesthetics | `brand-designer` |
| AI runtime, session lifecycle, guardrails | `agent-runtime-engineer` |
| Latency, throughput, benchmarks, perf | `ai-inference-benchmarker` |
| Launch plan, GTM, timeline, campaign | `gtm-specialist` |
| Sprint plan, backlog, task breakdown | `planner` |
| Desktop app, Tauri, Windows, node onboarding | `tauri-desktop-engineer` |
| Technical copy for power users | `Technical Marketing Copywriter` |

**Rules:**
- Only invite agents whose domain is directly relevant to the subject. Do not pad the meeting.
- If the subject is broad (e.g., "launch readiness"), invite all component owners.
- If the subject is narrow (e.g., "WebSocket reconnect strategy"), invite only the 2-3 relevant specialists.
- Always include `security-expert` if the subject touches auth, keys, or data integrity.

### Phase 1.5: Review Meeting History

Before setting the agenda, check for previous meeting files:

```
ls /home/smainer/Smainer/docs/meetings/
```

If prior meetings exist:
1. Read the most recent 1-3 meeting files.
2. Check their **Action Items** tables — are any still open?
3. If open action items relate to today's subject, add them to the agenda as **carryover items**.
4. In the meeting file, include a "Previous Action Item Status" section showing what was completed, what is still open, and what is now obsolete.

If no prior meetings exist, skip this phase.

### Phase 2: Set the Agenda

Before consulting agents, define:

```
SUBJECT:      <one-line topic>
GOAL:         <what decision or insight should this meeting produce?>
CONSTRAINTS:  <any hard boundaries — budget, timeline, security rules>
KEY QUESTION: <the single most important question each agent should answer>
```

### Phase 3: Consult Each Agent

Call each invited agent sequentially with this prompt template:

```javascript
runSubagent({
  agentName: "agent-name",
  description: "Meeting input on: <subject>",
  prompt: `
    ## Meeting Context
    Subject: <subject>
    Goal: <goal>
    Constraints: <constraints>

    ## Your Role
    You are attending a cross-team meeting as the <domain> specialist.

    ## Respond With
    1. **Summary** — Your assessment of the current state of <subject> from your domain's perspective (3-5 sentences).
    2. **Improvements** — 2-4 concrete, actionable improvements you recommend. Each should have: what to change, why, and expected impact.
    3. **Risks** — Any risks or concerns from your domain if this subject is handled poorly (1-3 items).
    4. **Dependencies** — What you need from other domains to execute your improvements.

    Keep your response focused and under 300 words.
  `
})
```

### Phase 4: Identify Cross-Agent Patterns

After all agents have responded, analyze:

- **Agreements** — Where do multiple agents recommend the same thing?
- **Conflicts** — Where do two agents contradict each other?
- **Gaps** — What did no agent cover that should have been addressed?
- **Dependencies** — Which agent's proposal requires another agent's work first?

### Phase 5: Director's Opinion

The Director writes a final opinion that:

1. States the recommended path forward (1-3 sentences).
2. Resolves any conflicts between agents with a clear decision and rationale.
3. Prioritizes the top 3 actions from all proposals.
4. Identifies who owns each action.
5. Flags any unresolved risks that need user decision.

### Phase 6: Write Meeting File

Create a meeting file at:
```
/home/smainer/Smainer/docs/meetings/YYYY-MM-DD-<subject-slug>.md
```

Use this template:

```markdown
# Meeting: <Subject>

**Date:** YYYY-MM-DD
**Facilitator:** Chief Director
**Attendees:** <list of agent names>
**Goal:** <meeting goal>

---

## Agent Perspectives

### <Agent Name 1>
**Summary:** <their summary>
**Improvements:**
1. <improvement 1>
2. <improvement 2>
**Risks:** <their risks>
**Dependencies:** <their dependencies>

### <Agent Name 2>
...

---

## Previous Action Items

| # | Action (from previous meeting) | Status | Notes |
|---|-------------------------------|--------|-------|
| 1 | <action> | Done / Open / Obsolete | <context> |

*(Omit this section if no prior meetings exist.)*

---

## Cross-Agent Analysis

### Agreements
- <shared recommendations>

### Conflicts
- <conflicting proposals and which agents disagree>

### Gaps
- <uncovered topics>

---

## Director's Opinion

<Director's synthesis, recommended path, conflict resolution, top 3 actions with owners>

## Action Items

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | <action> | <agent> | High/Med/Low |
| 2 | <action> | <agent> | High/Med/Low |
| 3 | <action> | <agent> | High/Med/Low |

---

*Meeting facilitated by Chief Director using agent-meeting skill.*
```

## Quality Checks

Before finalizing the meeting file:

- [ ] Every invited agent contributed (no silent attendees).
- [ ] Each agent's response addresses the key question.
- [ ] Conflicts are explicitly identified, not swept under the rug.
- [ ] Director's opinion doesn't just summarize — it makes a decision.
- [ ] Action items have clear owners and priorities.
- [ ] Meeting file is saved to the correct path.
- [ ] Previous action items reviewed and status updated (if prior meetings exist).

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Invite agents with no stake in the subject | Only invite agents whose domain is directly relevant |
| Let the Director implement proposals during the meeting | Meeting produces decisions; implementation is separate |
| Skip agents that might disagree | Disagreement is valuable — always invite the contrarian domain |
| Write a vague Director opinion ("both sides have merit") | Make a clear call, state the rationale, accept the tradeoff |
| Forget to write the meeting file | The artifact IS the deliverable — no file means no meeting |

## Prompt Starters

- Facilitate a meeting about: <subject>
- Get every agent's input on: <topic>. Write up the meeting notes.
- Run an architecture review meeting on: <component or system change>.
- Hold a launch readiness meeting — invite all relevant agents.
