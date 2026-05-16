---
name: director-macro-debugging
description: "Loaded by chief-director when bugs recur, fixes create new bugs, multiple agents only see local symptoms, or the system needs big-picture debugging across desktop, provider, relayer, contracts, Telegram, frontend, deployment, or repo state. Produces a macro failure map and coordinated fix plan before micro-fix delegation."
argument-hint: "Recurring bug / cross-component failure / specialists fixed locally but system still broken..."
user-invocable: true
disable-model-invocation: false
---

# Director Macro Debugging

## Purpose

Use this skill when local specialist fixes are not enough because the real failure is systemic. The Director must stop treating each bug as an isolated micro-task and first build the whole-system picture: user workflow, component boundaries, shared contracts, runtime environment, deployment state, and previous fix attempts.

This skill produces a **Macro Failure Map** and a coordinated fix sequence. It does not replace specialist agents; it gives them the shared context they were missing.

## When To Use

Load this skill before delegation when any signal appears:
- The same bug returns after one or more fixes.
- A fix in one component creates a bug in another component.
- Multiple agents report green status, but the user-visible workflow is still broken.
- A problem spans desktop, provider, relayer, contracts, Telegram, frontend, deployment, or repository state.
- The failure is phrased as "it works here but not there", "node is online but tasks fail", "status says offline after install", "no one sees the full picture", or "bugs never get fixed".
- The Director is about to re-delegate a third micro-fix without proving the system-level cause.

Avoid this skill for isolated single-file bugs with obvious cause, no shared interface, and no repeated failure history.

## Core Rule

Do not delegate implementation until the Director can state:
1. The end-to-end workflow that is failing.
2. The components and agents involved.
3. The shared contract or runtime boundary where the failure likely crosses components.
4. The evidence that separates symptoms from root cause.
5. The validation path that proves the full user workflow is fixed.

## Procedure

### 1. Freeze Micro-Fix Loop

If a bug has already bounced between agents or fixes, stop reassigning narrow patches. Record:
- Original user-visible failure.
- Prior fixes attempted.
- Files or components touched.
- What remained broken after each fix.
- Any new bug introduced by a fix.

### 2. Build The End-To-End Workflow

Describe the failing flow from the user action to the final expected state. Include every component that participates, even if it is probably innocent.

Template:

```text
User action -> UI/client -> local daemon/process -> API/relayer -> queue/state -> provider/node -> external service -> callback/status -> user-visible result
```

For each step, name:
- Component/repo/path if known.
- Owning specialist agent.
- Input received.
- Output promised.
- State written or read.
- Runtime dependency, environment variable, sidecar, service, network endpoint, or deployment assumption.

### 3. Identify Cross-Boundary Contracts

List all contracts that must align across components:
- API request/response schema.
- WebSocket event shape.
- Redis key/state semantics.
- Tauri command and sidecar path behavior.
- Installer/package resources.
- Environment variables and generated config files.
- On-chain event/ABI shape.
- Auth/signature/callback expectations.
- UX status meaning versus backend state.

Mark each contract as:
- `verified` - evidence proves both sides match.
- `suspect` - one side may be stale, missing, or inconsistent.
- `unknown` - no agent has checked both sides together.

### 4. Collect Specialist Statuses With Shared Context

Ask only the minimum relevant agents for status, but give every agent the same Macro Failure Map draft. Do not ask for generic status. Ask for boundary-specific evidence.

Delegation prompt shape:

```text
Macro debugging context:
<end-to-end workflow>

Your owned boundary:
<specific component/interface/runtime surface>

Return:
1. Evidence from your side of the boundary.
2. What the adjacent component must provide.
3. One likely root cause, or why your boundary is cleared.
4. The exact check that would prove this boundary is healthy.

Do not implement yet unless explicitly asked in a follow-up task.
```

### 5. Build The Root-Cause Hypothesis Table

Create a table before implementation:

| Hypothesis | Boundary | Evidence For | Evidence Against | Check Needed | Owner |
|---|---|---|---|---|---|

Rules:
- Prefer hypotheses that explain all observed symptoms.
- Reject hypotheses that only explain one component's local failure.
- Treat "agent says green" as weak evidence unless tied to a workflow check.
- Keep unknowns explicit instead of letting them become assumptions.

### 6. Choose Fix Sequence By System Leverage

Pick the smallest fix sequence that addresses the root boundary, not just the loudest symptom.

Ordering rules:
1. Fix shared contract or startup/deployment invariant first.
2. Fix component-specific implementation second.
3. Fix UI/status messaging last, unless wrong status is blocking diagnosis.
4. If two agents must align on one boundary, use `agent-meeting-protocol/SKILL.md` before implementation.

### 7. Delegate Implementation With The Macro Map

Every implementation delegation must include:
- The Macro Failure Map section relevant to that agent.
- The root-cause hypothesis being tested.
- Adjacent component expectations.
- Exact regression checks across the full workflow.
- Explicit out-of-scope boundaries.

Do not allow an agent to return "fixed locally" without cross-boundary evidence.

### 8. Validate The User Workflow End-To-End

Before reporting completion, verify the original workflow from the user's perspective.

Validation must include at least one macro check:
- Fresh install / first-run path if installer or desktop onboarding changed.
- Service absent / service installed-but-stopped / service running cases if runtime dependency detection changed.
- Node registration through task eligibility if provider/relayer changes are involved.
- Callback/status update if result delivery or dashboard state changed.
- Dependent agent regression check when a shared contract changed.

If full live validation cannot run, state the exact missing environment and run the closest deterministic checks available.

## Macro Failure Map Output

When this skill is loaded, the Director should produce or maintain this working artifact internally:

```markdown
## Macro Failure Map

User-visible failure:
- ...

End-to-end workflow:
1. ...

Component boundaries:
| Step | Component | Owner | Input | Output | State/Dependency | Status |
|---|---|---|---|---|---|---|

Contract inventory:
| Contract | Producers | Consumers | Status | Evidence |
|---|---|---|---|---|

Root-cause hypotheses:
| Hypothesis | Boundary | Evidence For | Evidence Against | Check Needed | Owner |
|---|---|---|---|---|---|

Fix sequence:
1. ...

End-to-end validation:
- ...
```

## Completion Criteria

The macro debugging loop is complete only when:
- The original user-visible failure has an end-to-end validation result.
- Every shared boundary touched by the fix has evidence from both producer and consumer sides.
- Any changed shared contract includes a regression check for dependent components or agents.
- The Director can explain why the chosen fix addresses the system-level cause.
- No agent output is accepted solely because it fixed a local symptom.

## Anti-Patterns

Do not:
- Keep reassigning micro-fixes after repeated failure.
- Ask agents for generic "status" without boundary-specific questions.
- Treat green local tests as proof the product workflow is fixed.
- Let the last agent who touched the code become the assumed owner of the root cause.
- Patch UI status text when the runtime or deployment invariant is actually broken.
- Report "done" until the whole failing workflow has been checked.

## Prompt Starters

- Use macro debugging for this recurring bug: <describe symptoms and prior fixes>.
- Build the big-picture failure map before assigning more fixes: <paste bug thread>.
- The specialists keep fixing local pieces but the workflow is still broken. Find the system-level cause.
- Stop micro-fixing and debug the full path from user action to provider/relayer result.