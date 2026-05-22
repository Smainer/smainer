---
name: clean-code
description: "Use when performing a codebase cleanup sweep: removing dead code, eliminating duplication, deleting unused scripts, purging stale or redundant markdown files, and extracting shared logic into reusable modules. Director loads this skill to orchestrate every domain specialist against their code ownership area. Triggers: clean up, dead code, remove duplication, unused scripts, stale docs, refactor for reuse, code hygiene."
argument-hint: "Scope (all domains | specific area like relayer/frontend/contracts) and optional depth (surface | deep)"
user-invocable: true
---

# Clean Code — Director Orchestration Skill

## Purpose

Give the Director a step-by-step playbook to drive a full codebase cleanup by delegating each domain to its **code owner agent**. The Director never touches files directly — it delegates, verifies, and iterates until every domain is clean.

---

## Code Ownership Map

| Domain | Agent | Root Path(s) |
|---|---|---|
| Relayer API | `relayer-architect` | `backend/relayer/` |
| Provider daemon / AI node | `systems-engineer` | `backend/provider/`, `backend/ai-compute-node/`, `deployment/` |
| Cairo contracts | `starknet-engineer` | `contracts/` |
| Next.js frontend | `frontend-engineer` | `frontend/` |
| Telegram bot + MiniApp | `telegram-bot-developer` | `telegram/` |
| Tauri desktop app | `tauri-desktop-engineer` | `desktop/` |
| Repo root, scripts, docs, CI | `repository-architect` | `scripts/`, `docs/`, `.github/`, root `*.md`, `*.sh` |

---

## Cleanup Checklist (per domain)

Every agent must run through all five categories in their ownership area:

### 1. Dead Code
- Functions, classes, or modules that are never imported or called
- Commented-out code blocks older than the current feature
- Feature flags or env vars that are always `false` / never set
- Unreachable branches (`if False`, stub endpoints with `pass`, `TODO: remove`)

### 2. Duplication
- Logic copy-pasted across ≥2 files — extract to a shared util/helper
- Identical config blocks in multiple compose/env files — consolidate
- Duplicate type definitions or interfaces

### 3. Unnecessary Scripts
- One-off migration scripts already applied (check git history + comments)
- Debug/test scripts in production paths (`test_*.sh`, `debug_*.py` in non-test dirs)
- Redundant install or setup scripts superseded by CI or Makefile

### 4. Stale / Redundant Markdown Files
- `*_REPORT.md`, `*_CLEANUP.md`, `*_AUDIT.md`, `WAVE*.md` — archive if already merged, delete if content is superseded
- Duplicate READMEs (multiple `README.md` at the same level covering the same thing)
- Draft or placeholder docs with no real content (e.g., `# TODO` only files)
- Keep: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, skill/agent docs

### 5. Reusability / Extraction
- Identify logic in one module that 2+ other modules would benefit from
- Propose (do not auto-extract without confirming) shared utilities if the change spans modules owned by different agents

---

## Director Execution Steps

### Step 1 — Scope Assessment

Before delegating, use the `Explore` agent to get a fast inventory:

```javascript
runSubagent({
  agentName: "Explore",
  description: "Inventory files for cleanup candidates",
  prompt: `List all .sh scripts outside test dirs, all *_REPORT.md / *CLEANUP* / *AUDIT* / WAVE* markdown files, 
  and identify any obvious dead code signals (commented blocks, stub files) across the workspace.
  Return a structured list grouped by domain path.`
})
```

### Step 2 — Parallel Domain Delegation

After the inventory, fire **all domain agents in parallel** (they own non-overlapping paths):

```javascript
// Fire all simultaneously — they don't conflict
runSubagent({ agentName: "relayer-architect-claude", ... })
runSubagent({ agentName: "systems-engineer-claude", ... })
runSubagent({ agentName: "starknet-engineer-claude", ... })
runSubagent({ agentName: "frontend-engineer-claude", ... })
runSubagent({ agentName: "telegram-bot-developer-claude", ... })
runSubagent({ agentName: "tauri-desktop-engineer-claude", ... })
```

### Step 3 — Repo Root Sweep (after domain agents complete)

Delegate to `repository-architect` last — it handles root-level files, cross-domain scripts, and docs that may reference now-deleted domain files:

```javascript
runSubagent({
  agentName: "repository-architect-claude",
  description: "Root-level cleanup sweep",
  prompt: `Clean the repo root and shared paths (see delegation template below).
  Note: domain agents have already cleaned their paths — do not re-enter them.
  Focus: scripts/, docs/, .github/, and all *.md / *.sh files at repo root.`
})
```

### Step 4 — Verify and Close

For each agent that reports back, verify against the acceptance criteria. If an agent returns a plan instead of actual changes, re-delegate:

```
"You returned a plan. Execute it. Delete/edit the files. Return a diff summary."
```

---

## Delegation Template (per agent)

Fill `[AGENT_DOMAIN]`, `[AGENT_PATHS]`, and paste inventory output from Step 1:

```
CONTEXT:
You own [AGENT_DOMAIN] under [AGENT_PATHS].
Inventory findings for your area: [paste relevant section from Explore output]

OBJECTIVE:
Perform a full clean-code sweep of [AGENT_PATHS] and make all changes directly.

EXECUTE the following cleanup checklist — do not plan, act:
1. DELETE dead code (unreachable functions, commented blocks, always-false flags)
2. ELIMINATE duplication — extract shared logic into utils where ≥2 callers exist
3. DELETE unnecessary scripts: one-off migrations, debug scripts outside test dirs
4. DELETE stale markdown: *_REPORT.md, *_CLEANUP.md, *_AUDIT.md, WAVE*.md, placeholder docs
   - PRESERVE: README.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, CHANGELOG.md
5. FLAG (do not auto-extract) any reusable logic that spans outside your paths

CRITERIA (your output is accepted only when):
- No dead code remains in [AGENT_PATHS]
- No duplication of ≥10 lines exists without a shared util
- All one-off/debug scripts deleted or moved to tests/
- All stale MD files deleted or archived under archive/
- All deletions confirmed with a brief diff summary

BOUNDARY:
- Do NOT touch paths owned by other agents
- Do NOT refactor logic that changes behavior — cleanup only
- Do NOT add new features or abstractions; only remove or consolidate existing ones
```

---

## Acceptance Criteria (Director level)

The cleanup is **done** when ALL of the following are true:

- [ ] Every domain agent has returned a diff summary (not just a plan)
- [ ] `repository-architect` has swept root + docs + scripts
- [ ] No `*_REPORT.md`, `*_CLEANUP.md`, `*_AUDIT.md`, `WAVE*.md` remain outside `archive/`
- [ ] No debug/migration scripts remain outside `tests/` or `archive/`
- [ ] No obvious dead code visible in any domain path
- [ ] `get_errors` / linting passes for modified paths

---

## Escalation Rules

| Situation | Action |
|---|---|
| Agent proposes changes instead of executing | Re-delegate with "Execute, don't plan." |
| Agent says "I can't delete, I need approval" | Director confirms deletion and re-delegates |
| Agent touches another agent's path | Stop, reassign that change to the correct owner |
| Linting / type errors after cleanup | Delegate fix to same agent with error output |
| Reusable logic spans 2+ domains | Convene relayer-architect + affected agent to agree on shared module location |

---

## Notes

- **Parallelism**: Steps 2 agents can run simultaneously. Step 3 must wait for Step 2 to complete.
- **Archive vs Delete**: If a file may have historical reference value, move to `archive/` instead of deleting. Prefer delete for generated reports and cleanup logs.
- **Never break a test**: Any deletion that causes a test import error must be fixed by the same agent before reporting done.
