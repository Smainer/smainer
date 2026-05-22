---
name: uml-behavioral-diagrams
description: 'Create behavioral UML diagrams with a deterministic algorithm. Use when modeling interactions, workflows, states, and event timing through use-case/activity/state/sequence/communication/interaction-overview/timing diagrams for director and specialist code-owner agents.'
argument-hint: 'Scenario, actors, event triggers, and behavior questions to model'
---

# Behavioral UML Diagram Algorithm

## Purpose
Produce precise behavioral UML artifacts that explain how the system acts over time.

This skill covers all behavioral UML kinds in one workflow:
- Use Case Diagram
- Activity Diagram
- State Machine Diagram
- Sequence Diagram
- Communication Diagram
- Interaction Overview Diagram
- Timing Diagram

## Inputs Required
Gather these before modeling behavior:
- Primary actors (human, service, scheduler, external API)
- Triggers/events and business goals
- Normal flow and alternate/error flows
- Preconditions, guards, and postconditions
- Timing constraints or SLAs if applicable

If scenario boundaries are unclear, ask for one concrete scenario first.

## Global Algorithm
1. Define behavior objective
- Choose a single outcome/question the behavioral set must clarify.
- Example objective: "Describe order placement success and failure paths under timeout conditions."

2. Normalize scenario vocabulary
- Create canonical names for actors, events, commands, states, and messages.

3. Build behavior backbone
- Trigger -> decision points -> actions -> state updates -> final outcomes.

4. Select behavioral diagram set
- Use the decision matrix below.
- Use multiple diagrams when one diagram cannot answer all required behavior questions.

5. Generate diagrams from abstract to concrete
- Use Case (scope)
- Activity/State (control and lifecycle)
- Sequence/Communication (message-level collaboration)
- Interaction Overview and Timing (orchestration and temporal guarantees)

6. Validate cross-diagram consistency
- Actors, messages, guards, and outcomes must align across all diagrams.

7. Publish final bundle
- Include assumptions, exception paths, and validation summary.

## Decision Matrix (Behavioral)
Use this branching logic:

1. Need external actor goals and system responsibilities?
- Create a Use Case Diagram.

2. Need workflow logic, branching, concurrency, or process control?
- Create an Activity Diagram.

3. Need lifecycle of one entity as it reacts to events over time?
- Create a State Machine Diagram.

4. Need ordered message exchange between participants?
- Create a Sequence Diagram.

5. Need object collaboration network emphasizing links over strict timeline layout?
- Create a Communication Diagram.

6. Need high-level orchestration of multiple interaction fragments?
- Create an Interaction Overview Diagram.

7. Need explicit time constraints, durations, and state/value evolution on a timeline?
- Create a Timing Diagram.

If three or more branches are true, create a cohesive multi-diagram behavioral packet.

## Per-Diagram Algorithms

### A) Use Case Diagram
1. List actors and their goals.
2. Define use cases as goal-oriented verbs.
3. Draw actor-to-use-case associations.
4. Add include/extend relations where justified.
5. Draw system boundary and place use cases inside it.

Completion checks:
- Every use case maps to a user or system goal.
- Include/extend is not overused.
- Scope boundary is explicit.

### B) Activity Diagram
1. Define initial node and final outcomes.
2. Add actions in execution order.
3. Add decision/merge nodes with guard conditions.
4. Add fork/join for concurrency where needed.
5. Add swimlanes for ownership clarity.

Completion checks:
- Each decision has guards that are mutually understandable.
- Parallel branches have explicit synchronization.
- Every branch reaches a valid end state.

### C) State Machine Diagram
1. Choose one focal entity.
2. Enumerate meaningful states (stable, transitional, terminal).
3. Add transitions with triggering events.
4. Add guard conditions and entry/exit actions when needed.
5. Validate unreachable or dead-end states.

Completion checks:
- State names are mutually exclusive and observable.
- Transitions are event-driven, not implementation details.
- Error/recovery states are represented.

### D) Sequence Diagram
1. List participants and lifelines.
2. Place messages in strict chronological order.
3. Add activation bars for processing spans.
4. Add alt/opt/loop fragments for branching.
5. Add return messages only when they add decision value.

Completion checks:
- Message order matches real execution semantics.
- Fragment guards match activity/state guards.
- Critical failure or timeout path is shown when relevant.

### E) Communication Diagram
1. Place collaborating objects/roles.
2. Draw links that represent communication paths.
3. Annotate messages with sequence numbers.
4. Highlight dependency-heavy hubs.
5. Compare with sequence diagram for semantic parity.

Completion checks:
- Numbered messages encode unambiguous order.
- Links reflect actual collaboration, not physical deployment.
- Same scenario result as sequence diagram.

### F) Interaction Overview Diagram
1. Define control flow between interaction nodes.
2. Reuse referenced sequence/activity fragments.
3. Add decisions and merges at orchestration level.
4. Highlight handoffs between subsystems.
5. Validate end-to-end path completeness.

Completion checks:
- Overview hides low-level noise while preserving control truth.
- Referenced interactions are uniquely identified.
- Every major path has a terminal outcome.

### G) Timing Diagram
1. Identify lifelines that require temporal analysis.
2. Define state/value timelines for each lifeline.
3. Place events with relative or absolute timestamps.
4. Add duration constraints and deadlines.
5. Validate SLA and timeout behavior.

Completion checks:
- Time units and references are explicit.
- Deadlines and timeout transitions are modeled.
- Diagram supports performance/reliability decisions.

## Quality Gates (Must Pass)
- Behavioral completeness: Happy path plus key exception paths are present.
- Temporal integrity: Ordering and timing constraints are internally consistent.
- Traceability: Every diagram maps back to the scenario objective.
- Consistency: Same actors/events/guards across diagrams.
- Decision utility: Diagram set supports implementation, testing, or architecture decisions.

## Output Contract
Return:
1. Selected behavioral diagram kinds and rationale.
2. Diagram definitions in requested notation (PlantUML, Mermaid, or tool-native format).
3. Assumptions and unresolved questions.
4. Quality-gate checklist outcomes.

## Collaboration Notes
This skill is workspace-scoped and intended for all Smainer agents, including director and specialist code-owner agents, so behavior modeling remains consistent across delegations.
