# Smainer Agent Pipeline — Topology Reference

Authoritative specification for the Smainer AI agent hierarchy.
All agent files and skill files derive their structure from this document.

---

## 4-Tier Architecture

```
TIER 0 — GATEWAY
  chief-director           Single point of entry. Routes, orchestrates, facilitates meetings.
                           Never implements. Never writes code or edits files.
  prompt-engineer          Hidden director-only prompt clarification support.
                           Returns cleaned Director prompts or clarification questions.

TIER 1 — PLANNING
  planner                  Receives Task Brief from chief-director.
                           Produces Task Manifests. Never writes code or edits files.

TIER 2 — EXECUTION (13 specialists)
  relayer-architect        FastAPI relayer, WebSocket, Redis, job scheduling
  systems-engineer         Python daemons, systemd, GPU detection, remote ops
  starknet-engineer        Cairo contracts, Scarb, ERC-20, escrow, starknet.py
  frontend-engineer        Next.js, starknet-react, wallet UX, shadcn/ui, Tailwind
  telegram-bot-developer   Telegram bot (Vercel), MiniApp, wallet flows, payments
  tauri-desktop-engineer   Tauri app, Windows installer, node dashboard, GPU UI
  fee-economist            Fee structure, treasury splits, BPS arithmetic
  brand-designer           Brand identity, color systems, UI aesthetics
  marketing-copywriter     Marketing copy, headlines, CTAs, funnel copy
  technical-copywriter     Technical copy targeting power users, hardware specs
  gtm-specialist           Launch planning, GTM timelines, community activation
  agent-runtime-engineer   AI runtime policy, session lifecycle, tool guardrails
  repository-architect     Git ops, CI/CD, releases, multi-repo governance *

  * repository-architect also operates as Tier 3 validator in release-gate mode.

TIER 3 — VALIDATION
  security-expert          Stateless auditor. Reviews outputs. Never implements.
  repository-architect     Release gate mode only. CI/CD approval.

TIER 4 — UTILITY (read-only, callable from any tier)
  Explore                  Read-only codebase exploration
  ai-inference-benchmarker Read-only metrics and benchmarking
```

---

## Allowed Call Graph

```
User
  ↓
chief-director (TIER 0)
  ↓ Prompt Clarification Request, when user intent is unclear
prompt-engineer (TIER 0 support)
  ↓ Clean Director Prompt or Clarifying Questions
chief-director (TIER 0)
  ↓ Task Brief
planner (TIER 1)
  ↓ Task Manifests (one per specialist)
[specialist agents] (TIER 2)
  ↓ Delivery Reports
chief-director (TIER 0)
  ↓ Validation Requests
security-expert / repository-architect (TIER 3)
  ↓ Validation Reports
chief-director (TIER 0)
  ↓ Final delivery to user

Standard clear-intent flow:

chief-director (TIER 0)
  ↓ Task Brief
planner (TIER 1)
  ↓ Task Manifests (one per specialist)
[specialist agents] (TIER 2)
  ↓ Delivery Reports
chief-director (TIER 0)
  ↓ Validation Requests
security-expert / repository-architect (TIER 3)
  ↓ Validation Reports
chief-director (TIER 0)
  ↓ Final delivery to user

Any tier → Explore (TIER 4)                [read-only, any time]
Any tier → ai-inference-benchmarker (TIER 4) [read-only, any time]
```

---

## Forbidden Call Patterns

```
 Tier 2 → Tier 2   (no peer-to-peer between specialists)
 Tier 2 → Tier 0   (specialists cannot escalate to chief-director directly)
 Tier 2 → Tier 1   (specialists cannot call planner)
 Tier 1 → Tier 0   (planner cannot call chief-director back)
 Tier 0 → Tier 2   (chief-director must route multi-task work through planner)
 Tier 3 implementing anything (audit only — no code, no file edits)
 Any Tier 0/1 writing code or editing files
```

---

## Canonical Envelope Schemas

### 1. Task Brief — Tier 0 → Tier 1

```json
{
  "envelope_type": "task_brief",
  "brief_id": "TB-NNN",
  "from": "chief-director",
  "to": "planner",
  "goal": "One sentence describing the desired outcome",
  "constraints": ["constraint 1", "constraint 2"],
  "components_involved": ["relayer", "frontend", "contracts"],
  "priority": "CRITICAL | HIGH | MEDIUM | LOW",
  "deadline": "ISO date or null",
  "meeting_minutes_ref": "MTG-NNN or null"
}
```

### 2. Task Manifest — Tier 1 → Tier 2

```json
{
  "envelope_type": "task_manifest",
  "manifest_id": "TM-NNN",
  "task_id": "T-NNN",
  "from": "planner",
  "to": "<specialist-agent-name>",
  "title": "Concise action-oriented title",
  "component": "relayer | provider | frontend | telegram | contracts | infra | docs",
  "priority": "CRITICAL | HIGH | MEDIUM | LOW",
  "depends_on": ["T-NNN"],
  "context": "Relevant files, current state, prior decisions",
  "objective": "One clear sentence: what to build/fix/review",
  "acceptance_criteria": [
    "Observable done-state item 1",
    "Observable done-state item 2"
  ],
  "out_of_scope": ["What NOT to touch"],
  "implementation_constraints": ["Non-negotiable items from Meeting Minutes, or empty"]
}
```

### 3. Delivery Report — Tier 2 → Tier 0

```json
{
  "envelope_type": "delivery_report",
  "report_id": "DR-NNN",
  "task_id": "T-NNN",
  "from": "<specialist-agent-name>",
  "status": "completed | blocked | partial",
  "deliverables": [
    "path/to/file.py — description of change"
  ],
  "validation_required": true,
  "validation_type": "security | release | none",
  "blocking_issue": "Description if status=blocked, else null",
  "notes": "Any context useful for the director"
}
```

### 4. Validation Report — Tier 3 → Tier 0

```json
{
  "envelope_type": "validation_report",
  "report_id": "VR-NNN",
  "delivery_report_ref": "DR-NNN",
  "from": "security-expert | repository-architect",
  "verdict": "pass | fail | pass-with-conditions",
  "severity": "CRITICAL | HIGH | MEDIUM | LOW | NONE",
  "issues": [
    {
      "id": "SEC-NNN",
      "description": "Issue description",
      "file": "path/to/file.py or null",
      "line": "line number or null",
      "remediation": "Required fix"
    }
  ],
  "conditions": ["Conditions if verdict=pass-with-conditions"],
  "approved_by": "<agent name>"
}
```

### 5. Meeting Contribution — agent → chief-director (during a meeting)

```json
{
  "envelope_type": "meeting_contribution",
  "meeting_id": "MTG-NNN",
  "from": "<agent-name>",
  "role": "rule-setter | implementer",
  "domain_requirements": [
    "Technical requirement this domain must enforce"
  ],
  "hard_constraints": [
    "Non-negotiable item — cannot be traded away"
  ],
  "flexibilities": [
    "Item this domain can negotiate on"
  ],
  "open_questions_for_peer": [
    "Question directed at the other agent in this meeting"
  ]
}
```

### 6. Meeting Minutes — chief-director → all participants (binding contract)

```json
{
  "envelope_type": "meeting_minutes",
  "meeting_id": "MTG-NNN",
  "meeting_type": "cross-domain-alignment | blocker-resolution | status-sync",
  "participants": ["<agent-name-1>", "<agent-name-2>"],
  "context": "What was being designed or resolved",
  "agreed_items": [
    "Concrete agreement item 1",
    "Concrete agreement item 2"
  ],
  "open_items": [
    "Unresolved item requiring follow-up"
  ],
  "implementation_constraints": [
    "Direct instruction to implementer — non-negotiable"
  ],
  "signed_off_by": ["<agent-name>"],
  "arbitrated_by": "chief-director"
}
```

---

## Meeting Types Quick Reference

| Type | Trigger | Participants | Output |
|------|---------|--------------|--------|
| Status Sync | User requests status / launch health | chief-director + selected Tier 2/3 agents | Executive Snapshot |
| Blocker Resolution | Delivery Report status=blocked or Validation Report severity=CRITICAL | chief-director + blocked agent + upstream owner | Unblock Task Manifest |
| Cross-Domain Alignment | Task B output must conform to Agent A rules (different domain) | chief-director + rule-setter (A) + implementer (B) | Meeting Minutes |

### Frequent Meeting Pairs

| Rule-Setter (Agent A) | Implementer (Agent B) | Topic |
|---|---|---|
| security-expert | systems-engineer | Deployment protocols, daemon hardening |
| security-expert | relayer-architect | Auth middleware, callback verification |
| security-expert | telegram-bot-developer | Webhook validation, payment auth |
| fee-economist | relayer-architect | Fee routing, BPS arithmetic in middleware |
| starknet-engineer | relayer-architect | Event schemas, tx bundling contracts |
| brand-designer | frontend-engineer | Design token API, component visual contracts |
| relayer-architect | frontend-engineer | API response shapes, WebSocket event names |
| relayer-architect | telegram-bot-developer | Payload schemas, task result format |

---

## Code Ownership Map

| Agent | Owned Paths |
|-------|-------------|
| relayer-architect | `backend/relayer/` (smainer-backend) |
| systems-engineer | `backend/provider/` (smainer-backend) |
| starknet-engineer | `contracts/` (smainer-contracts) |
| frontend-engineer | `frontend/src/` (smainer-frontend) |
| telegram-bot-developer | `telegram/smainer-bot/`, `telegram/miniapp/src/` (smainer-telegram) |
| tauri-desktop-engineer | `desktop/` (smainer-desktop) |
| fee-economist | Fee constants in contracts + relayer config |
| brand-designer | `frontend/src/styles/`, design tokens, brand assets |
| marketing-copywriter | Landing page copy, public README, `docs/` |
| technical-copywriter | Technical docs, hardware spec copy |
| gtm-specialist | Launch docs, community content |
| agent-runtime-engineer | `.github/agents/`, `.github/skills/`, `.github/instructions/` |
| repository-architect | All 6 repos — governance, CI/CD, releases |
