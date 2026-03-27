---
name: e2e-agent-orchestrator
description: End-to-end multi-agent execution for long task lists. Use when you need to decompose a large backlog, route work to specialist agents, self-judge quality, reassign follow-up tasks, and continue iterating until all user tasks are fully completed.
---

# E2E Agent Orchestrator

## What This Skill Produces
This skill turns a long or ambiguous request into an execution loop that runs until completion.

Output includes:
- A normalized task backlog with priorities and dependencies.
- Agent routing decisions per task.
- Iterative execution waves with validation after each wave.
- Completion report that confirms every requested task is done or explicitly blocked.

## When to Use
Use this skill when the user asks for any of the following:
- "Handle everything end to end" across multiple components.
- "Take this long task list and finish all of it."
- Multi-domain work that requires several specialists (frontend, backend, security, contracts, docs, GTM).
- Work where intermediate outputs must be judged and refined before final delivery.

Avoid this skill for:
- Single-file quick edits.
- One-step Q&A.
- Tiny changes where full orchestration overhead is unnecessary.

## Agent Routing Map
Route each task to the smallest capable specialist:
- Product planning and decomposition: planner.
- Frontend and UX delivery: frontend-engineer.
- Python daemons, systems, infra scripts: systems-engineer.
- Relayer/API coordination services: relayer-architect.
- Smart contracts and Starknet/Cairo: starknet-engineer.
- Security review and threat checks: security-expert.
- Branding and visual audits: brand-designer.
- Launch sequencing and rollout plans: chief-director or gtm-specialist.
- Repo-wide governance and release ops: repository-architect.

## End-to-End Procedure
1. **Intake and normalize**: Rewrite the user ask into concrete tasks with IDs. Split oversized tasks into shippable subtasks. Capture dependencies and blockers.

2. **Build execution board**: Create a task board with columns: not-started, in-progress, completed, blocked. Set acceptance criteria per task. Mark high-risk tasks.

3. **Plan wave 1**: Select the highest-impact independent tasks first. Assign owners (agents) and expected deliverables. Define verification checks for each task.

4. **Execute with specialist agents**: Invoke specialist agents with focused prompts and required context. Aggregate outputs into concrete workspace changes. Keep traceability: task ID, owner, files changed, checks run.

5. **Self-judge every result**: Validate against acceptance criteria, repository rules, and security constraints. If output is weak or incomplete, generate a follow-up task and reassign. Never mark complete until evidence exists.

6. **Run convergence loop**: Reprioritize remaining tasks. Launch next wave for unresolved work. Continue until all tasks are completed or explicitly blocked by external constraints.

7. **Finalize**: Produce closure report covering each original task. List completed items, residual risks, blockers, and recommended next actions.

## Branching and Decision Logic
- If a task spans multiple domains: split by domain and assign one owner each.
- If a dependency is missing: create unblocker task first.
- If an agent result fails validation: create remediation task and reroute.
- If risk is security-critical: require security-expert review before completion.
- If requirements are ambiguous: choose safe default + ask targeted clarification while continuing unaffected tasks.
- If blocked by unavailable external systems: mark blocked with evidence and proceed with remaining tasks.

## Quality Gates
A task can move to completed only when all gates pass:
- Scope gate: matches user intent and acceptance criteria.
- Correctness gate: implementation is logically and technically sound.
- Safety gate: no secret leakage, unsafe commands, or policy violations.
- Verification gate: relevant tests/checks run, or explicit reason they could not run.
- Integration gate: no obvious regressions across touched components.
- Design gate: frontend/UI work follows intentional brand-quality decisions.
- Communication gate: status and assumptions are documented clearly.

## Pipeline Enforcement Rules
- **Tier 3 validation gate**: Between every wave, if any task in the wave produced code changes, route a Validation Report request to `security-expert` before proceeding to the next wave.
- **No informal agent-to-agent conversations**: All cross-agent communication is via typed envelopes (Task Manifest → Delivery Report).
- **Meeting check before each wave**: If the next wave involves a task where Agent B's output must conform to Agent A's rules, trigger a Cross-Domain Alignment Meeting before distributing that wave's Task Manifests.
- **Blocked tasks**: Never let a blocked task sit silently. Immediately trigger a Blocker Resolution Meeting when `status=blocked` appears in any Delivery Report.

## Input Contract
- **Accepts**: Task Manifest set (array of Task Manifests from planner) OR backlog description (natural language)
- **Required**: List of tasks with owners, priorities, and dependencies

## Output Contract
- **Wave summary**: Which tasks ran, which passed, which are blocked
- **Delivery Report set**: Typed Delivery Report for each completed task
- **Completion Report**: Final audit confirming all tasks reached terminal state (completed or blocked-with-reason)
