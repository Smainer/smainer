---
name: director-docs-accuracy-sweep
description: "Loaded by chief-director only. Use when running a full documentation accuracy and clarity sweep: each specialist agent scans code they own, reads relevant docs, fixes incorrect/outdated text, and adds correct class and data-flow diagrams. Triggers: doc sweep, docs refresh, docs alignment, architecture docs update, diagram correctness."
argument-hint: "Scope (all domains or specific paths) and depth (quick|standard|deep)"
user-invocable: false
disable-model-invocation: false
---

# Director Docs Accuracy Sweep

## Purpose

Provide the Director with a deterministic orchestration workflow to improve documentation quality across the repository.

The Director does not edit files directly. The Director delegates documentation work to domain owners, validates outputs, and drives follow-up until all quality gates pass.

## Ownership Map

| Domain | Agent | Owned Paths |
|---|---|---|
| Relayer | `relayer-architect-copilot` | `backend/relayer/` |
| Provider and node systems | `systems-engineer-copilot` | `backend/provider/`, `backend/ai-compute-node/`, `deployment/` |
| Contracts | `starknet-engineer-copilot` | `contracts/` |
| Frontend | `frontend-engineer-copilot` | `frontend/` |
| Telegram | `telegram-bot-developer-copilot` | `telegram/` |
| Desktop app | `tauri-desktop-engineer-copilot` | `desktop/` |
| Shared docs and repo-wide files | `repository-architect-copilot` | `docs/`, `.github/`, root `*.md`, shared scripts |

If your environment exposes `*-claude` variants instead of `*-copilot`, use the available equivalent agent names.

## Required Outputs Per Domain

Each delegated domain agent must produce all of the following in its owned paths:

1. Documentation corrections for factual accuracy against current code.
2. Clarity edits (terminology, structure, examples, intent) to make docs easier to understand.
3. At least one diagram update when applicable:
   - Class or component structure diagram.
   - Data flow or sequence/workflow diagram.
4. A brief change summary that maps each doc update to code evidence.

If a domain has no classes or meaningful data pipeline, agent must explicitly report: `diagram: not applicable` with rationale.

## Execution Procedure

### Step 1: Director Scope Intake

Collect these inputs:
- Scope: full repository or specific domains/paths.
- Depth:
  - `quick`: critical docs only (README, architecture, runbooks).
  - `standard`: critical + module docs.
  - `deep`: all docs including secondary references.
- Diagram format preference: Mermaid (default), PlantUML, or existing project format.

### Step 2: Build Domain Work Queue

For each domain owner:
- Enumerate candidate docs in owned paths (`README*`, `docs/**`, architecture/runbook files, inline protocol docs).
- Enumerate core code entry points and interfaces for evidence.
- Prioritize docs with high mismatch risk (auth flows, API contracts, env/config, transaction flow, deployment steps).

### Step 3: Delegate Domain Sweeps

Use one delegation per domain. Parallelize delegations only when agents operate on non-overlapping files.

Delegation contract (must include all four):
1. Context
2. Objective
3. Success Criteria
4. Boundary

Template:

```text
CONTEXT:
You own [DOMAIN] under [OWNED_PATHS].
Target depth: [quick|standard|deep].
Diagram format: [Mermaid|PlantUML|existing].

OBJECTIVE:
Scan owned code first, then read and update all relevant docs so they are correct, clear, and easy to understand.
Add or correct class/component and data-flow diagrams where applicable.

SUCCESS CRITERIA:
- Every edited statement is consistent with current code behavior.
- Terminology is consistent across all edited docs.
- At least one correct class/component diagram and one correct data-flow/workflow diagram per subsystem where applicable.
- Output includes a "doc-to-code evidence map" listing each edited doc section and matching source files/functions.

BOUNDARY:
- Do not edit files outside owned paths.
- Do not invent behavior not present in code.
- Do not include secrets, credentials, or private keys in docs or examples.
```

### Step 4: Cross-Domain Alignment

When docs touch shared interfaces (API contracts, events, payload schemas, auth handoffs):
- Run a cross-domain alignment pass before finalizing.
- If two domains disagree, escalate to a meeting via `agent-meeting-protocol` and publish meeting minutes.

### Step 5: Director Validation Gate

Before accepting a domain result, verify:
- Accuracy: statements match code.
- Clarity: the intended reader can follow setup, flow, and constraints.
- Diagram correctness: nodes/edges, class relationships, and directionality match implementation.
- Traceability: evidence map references real files/symbols.
- Security hygiene: no secrets or sensitive values exposed.

If any check fails, redelegate with concrete correction requests.

### Step 6: Final Consolidation

After all domains pass:
- Ensure terminology is unified across root docs.
- Ensure diagram style is consistent.
- Publish a final sweep summary:
  - Domains completed.
  - Docs edited.
  - Diagrams added/updated.
  - Open follow-ups (if any).

## Decision Rules

1. If task is single-domain and isolated, delegate directly to that owner.
2. If task spans multiple domains, optionally call `planner-copilot` for task decomposition, then execute owner delegations.
3. If the request is ambiguous, ask one clarifying question before delegating.
4. If a delegated agent returns plans instead of edits, redelegate with: `Execute changes now; return a diff-oriented summary.`
5. If diagram correctness is uncertain, require the agent to cite exact implementation references and revise.

## Quality Checklist

- [ ] Each domain owner scanned owned code before editing docs.
- [ ] Relevant documentation was updated, not just summarized.
- [ ] Documentation text is correct, clear, and easy to understand.
- [ ] Class/component diagrams are present where applicable and match code.
- [ ] Data-flow/workflow diagrams are present where applicable and match code.
- [ ] Evidence map exists for every domain response.
- [ ] Cross-domain contracts are consistent.
- [ ] No secret values appear in outputs.

## Example Prompts

- "Run a deep docs accuracy sweep across all domains with Mermaid diagrams."
- "Run this skill only for `backend/relayer` and `docs/architecture` with standard depth."
- "Refresh all user-facing setup docs and add correct data-flow diagrams for relayer and provider."
