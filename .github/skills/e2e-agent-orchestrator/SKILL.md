---
name: e2e-agent-orchestrator
description: "End-to-end multi-agent execution for long task lists. Use when you need to decompose a large backlog, route work to specialist agents, self-judge quality, reassign follow-up tasks, and continue iterating until all user tasks are fully completed."
argument-hint: "Paste goals or task list, constraints, and deadline"
user-invocable: true
disable-model-invocation: false
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

## Inputs Required
Collect or infer:
- Full user task list (ordered or unordered).
- Hard constraints (security, no regressions, no secret leakage, timeline, scope).
- Definition of done (tests, docs, deployment checks, acceptance criteria).
- Priority model if provided (critical, high, medium, low).

If details are missing, proceed with explicit assumptions and mark them for confirmation.

Default behavior for ambiguity:
- Continue execution with safe assumptions.
- Log assumptions explicitly.
- Ask focused follow-up questions without blocking unrelated tasks.

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

Use more than one agent for cross-cutting tasks, but keep one owner per task.

## End-to-End Procedure
1. Intake and normalize.
- Rewrite the user ask into concrete tasks with IDs.
- Split oversized tasks into shippable subtasks.
- Capture dependencies and blockers.

2. Build execution board.
- Create a task board with columns: not-started, in-progress, completed, blocked.
- Set acceptance criteria per task.
- Mark high-risk tasks (security, data integrity, irreversible ops).

3. Plan wave 1.
- Select the highest-impact independent tasks first.
- Assign owners (agents) and expected deliverables.
- Define verification checks for each task before execution.

4. Execute with specialist agents.
- Invoke specialist agents with focused prompts and required context.
- Aggregate outputs into concrete workspace changes.
- Keep traceability: task ID, owner, files changed, checks run.

5. Self-judge every result.
- Validate against acceptance criteria, repository rules, and security constraints.
- If output is weak or incomplete, generate a follow-up task and reassign.
- Never mark complete until evidence exists (code, tests, docs, or explicit rationale).

6. Run convergence loop.
- Reprioritize remaining tasks.
- Launch next wave for unresolved work.
- Continue until all tasks are completed or explicitly blocked by external constraints.

7. Finalize.
- Produce closure report covering each original task.
- List completed items, residual risks, blockers, and recommended next actions.

## Branching and Decision Logic
Use this branching logic during orchestration:
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
- Verification gate: relevant tests/checks run, including E2E tests when applicable, or explicit reason they could not run.
- Integration gate: no obvious regressions across touched components.
- Design gate: frontend/UI work avoids generic AI-style output and follows intentional brand-quality decisions.
- Communication gate: status and assumptions are documented clearly.

## Completion Criteria
The full request is complete only when:
- Every original user task maps to one terminal state: completed or blocked-with-reason.
- All completed tasks have evidence.
- Completed implementation tasks include: code implemented, tests/checks executed, docs updated, deployment/runbook updates where relevant.
- Risky tasks include explicit security review before completion.
- Blocked tasks include exact unblock condition and owner.
- Final summary is concise, auditable, and action-ready.

## Output Format
Use this format in responses:

1. Current wave summary.
2. Task board delta (what changed this wave).
3. Validation results (checks/tests/reviews).
4. Remaining tasks with next owners.
5. Final closure report when backlog reaches terminal state.

## Prompt Starters
- Orchestrate this end to end: <paste task list>. Keep running waves until everything is done.
- Take this backlog, route tasks to specialists, self-review outputs, and keep iterating to completion.
- Manage this full launch checklist with multi-agent execution and report only terminal outcomes.
