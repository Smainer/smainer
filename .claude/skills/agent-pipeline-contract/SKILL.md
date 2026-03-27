---
name: agent-pipeline-contract
description: Load when sending or receiving any cross-agent message. Defines all canonical envelope schemas for the Smainer agent pipeline. Every cross-tier delegation must use these typed structures — no informal prompt strings.
---

# Agent Pipeline Contract

## Purpose

This skill defines the six typed envelopes used for all cross-agent communication in the Smainer pipeline.

**No agent may communicate with another using free-form text when a structured envelope applies.**

## Input Contract

Caller provides:
- `envelope_type`: which envelope to produce
- `context`: the raw content to encode into the envelope

## Output Contract

Receiver produces:
- A fully-populated JSON envelope conforming to the schema below
- All required fields present; `null` is valid for optional fields
- No extra fields outside the schema

---

## Envelope 1: Task Brief

**Flow**: `chief-director` → `planner`
**When**: chief-director has a multi-task or multi-component user request requiring planning.

```json
{
  "envelope_type": "task_brief",
  "brief_id": "TB-NNN",
  "from": "chief-director",
  "to": "planner",
  "goal": "<one sentence describing desired outcome>",
  "constraints": ["<constraint 1>", "<constraint 2>"],
  "components_involved": ["relayer | provider | frontend | telegram | contracts | infra | docs"],
  "priority": "CRITICAL | HIGH | MEDIUM | LOW",
  "deadline": "<ISO date or null>",
  "meeting_minutes_ref": "<MTG-NNN or null>"
}
```

**Required fields**: `goal`, `from`, `components_involved`.

---

## Envelope 2: Task Manifest

**Flow**: `planner` → Tier 2 specialist
**When**: planner is delegating a specific implementation task to a specialist.

```json
{
  "envelope_type": "task_manifest",
  "manifest_id": "TM-NNN",
  "task_id": "T-NNN",
  "from": "planner",
  "to": "<specialist-agent-name>",
  "title": "<concise action-oriented title>",
  "component": "relayer | provider | frontend | telegram | contracts | infra | docs",
  "priority": "CRITICAL | HIGH | MEDIUM | LOW",
  "depends_on": ["T-NNN or null"],
  "context": "<relevant files, current state, prior decisions>",
  "objective": "<one clear sentence: what to build/fix/review>",
  "acceptance_criteria": [
    "<observable done-state item 1>",
    "<observable done-state item 2>"
  ],
  "out_of_scope": ["<what NOT to touch>"],
  "implementation_constraints": ["<non-negotiable items from Meeting Minutes, or empty array>"]
}
```

**Required fields**: `objective`, `acceptance_criteria`, `to`.
**Critical**: `implementation_constraints` must include ALL items from any referenced Meeting Minutes — no paraphrasing, verbatim copy.

---

## Envelope 3: Delivery Report

**Flow**: Tier 2 specialist → `chief-director`
**When**: specialist has completed (or is blocked on) a Task Manifest.

```json
{
  "envelope_type": "delivery_report",
  "report_id": "DR-NNN",
  "task_id": "T-NNN",
  "from": "<specialist-agent-name>",
  "status": "completed | blocked | partial",
  "deliverables": [
    "<path/to/file.py — description of change>"
  ],
  "validation_required": true,
  "validation_type": "security | release | none",
  "blocking_issue": "<description if status=blocked, else null>",
  "notes": "<any context useful for routing or next steps>"
}
```

**Required fields**: `task_id`, `from`, `status`.
**Rule**: If `status=blocked`, `blocking_issue` must be populated.

---

## Envelope 4: Validation Report

**Flow**: Tier 3 validator → `chief-director`
**When**: `security-expert` or `repository-architect` has reviewed a Delivery Report.

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
      "description": "<issue description>",
      "file": "<path/to/file.py or null>",
      "line": "<line number or null>",
      "remediation": "<required fix>"
    }
  ],
  "conditions": ["<conditions if verdict=pass-with-conditions>"],
  "approved_by": "<agent name>"
}
```

**Required fields**: `verdict`, `from`.
**Rule**: If `verdict=fail`, `issues` must not be empty.

---

## Envelope 5: Meeting Contribution

**Flow**: any Tier 2 or Tier 3 agent → `chief-director` (during a meeting)
**When**: chief-director has invited this agent to a Cross-Domain Alignment Meeting.

```json
{
  "envelope_type": "meeting_contribution",
  "meeting_id": "MTG-NNN",
  "from": "<agent-name>",
  "role": "rule-setter | implementer",
  "domain_requirements": [
    "<technical requirement this domain must enforce>"
  ],
  "hard_constraints": [
    "<non-negotiable — cannot be traded away>"
  ],
  "flexibilities": [
    "<item this domain can negotiate on>"
  ],
  "open_questions_for_peer": [
    "<question directed at the other meeting participant>"
  ]
}
```

**Required fields**: `from`, `role`, `hard_constraints`.

---

## Envelope 6: Meeting Minutes

**Flow**: `chief-director` → all meeting participants (becomes binding input to Task Manifests)
**When**: end of any Cross-Domain Alignment or Blocker Resolution meeting.

```json
{
  "envelope_type": "meeting_minutes",
  "meeting_id": "MTG-NNN",
  "meeting_type": "cross-domain-alignment | blocker-resolution | status-sync",
  "participants": ["<agent-name-1>", "<agent-name-2>"],
  "context": "<what was being designed or resolved>",
  "agreed_items": [
    "<concrete agreement item 1>",
    "<concrete agreement item 2>"
  ],
  "open_items": [
    "<unresolved item requiring follow-up>"
  ],
  "implementation_constraints": [
    "<direct instruction to implementer — non-negotiable>"
  ],
  "signed_off_by": ["<agent-name>"],
  "arbitrated_by": "chief-director"
}
```

**Critical**: `implementation_constraints[]` is the binding output. Every item here MUST appear verbatim in the downstream Task Manifest's `implementation_constraints[]` field.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Pass a free-form string prompt between agents across tiers | Use the appropriate typed envelope |
| Omit `implementation_constraints` from a Task Manifest that has Meeting Minutes | Copy all constraints verbatim |
| Mark a Delivery Report `completed` when acceptance criteria fail | Use `partial` with notes |
| Issue a Validation Report `pass` when issues exist | List all issues — even LOW severity |
| Invent fields outside the schema | Use `notes` for unstructured context |
