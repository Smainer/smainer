---
name: uml-structural-diagrams
description: 'Create structural UML diagrams with a deterministic algorithm. Use when designing class/object/component/deployment/package/composite-structure views, validating static architecture, or preparing implementation-ready models for director and specialist code-owner agents.'
argument-hint: 'System context, scope boundary, and desired structural UML outputs'
---

# Structural UML Diagram Algorithm

## Purpose
Produce precise structural UML artifacts that represent the static architecture of a system.

This skill covers all structural UML kinds in one workflow:
- Class Diagram
- Object Diagram
- Component Diagram
- Deployment Diagram
- Package Diagram
- Composite Structure Diagram

## Inputs Required
Collect these before diagramming:
- System scope and boundary
- Primary modules/services and ownership
- Core entities or classes and relationships
- Runtime topology (nodes, containers, environments)
- External systems and interfaces
- Constraints (security, performance, compliance)

If key inputs are missing, ask focused questions first.

## Global Algorithm
1. Define objective
- Choose one target question the diagrams must answer.
- Example objective: "Validate whether service boundaries and interfaces are implementation-ready."

2. Fix system boundary
- List in-scope elements and out-of-scope elements.
- Reject mixed abstraction levels in one diagram.

3. Build canonical element inventory
- Entities/classes
- Objects/instances
- Components/services
- Packages/namespaces
- Nodes/artifacts
- Internal parts/ports/connectors

4. Select structural diagram set
- Use the decision matrix below to choose required diagram kinds.
- Avoid creating diagrams with no explicit decision value.

5. Generate diagrams in dependency order
- Start with package or component level (macro).
- Then class/composite structure (meso).
- Then object/deployment snapshots (micro/runtime mapping).

6. Validate consistency across diagrams
- Names, cardinalities, interfaces, and dependencies must agree.
- Any contradiction triggers correction before completion.

7. Publish final bundle
- Include diagram list, assumptions, open risks, and unresolved questions.

## Decision Matrix (Structural)
Use this branching logic:

1. Need type system, attributes, methods, inheritance, and associations?
- Create a Class Diagram.

2. Need a point-in-time instance snapshot of real objects and links?
- Create an Object Diagram.

3. Need software module boundaries, provided/required interfaces, or microservice contracts?
- Create a Component Diagram.

4. Need mapping of artifacts/services onto infrastructure nodes or environments?
- Create a Deployment Diagram.

5. Need organization of namespaces/modules and dependency direction between them?
- Create a Package Diagram.

6. Need internals of one classifier (parts, ports, connectors) beyond class-level abstraction?
- Create a Composite Structure Diagram.

If more than two branches return true, produce a multi-diagram structural set.

## Per-Diagram Algorithms

### A) Class Diagram
1. Extract classes from domain nouns and core services.
2. Add attributes with business-relevant types only.
3. Add behavior-significant operations.
4. Add relationships: association, aggregation, composition, inheritance, dependency.
5. Add multiplicities on every non-trivial association.
6. Validate against invariants and terminology.

Completion checks:
- No orphan classes without relationships unless intentional.
- Multiplicity is explicit where cardinality matters.
- Inheritance is justified by substitutability, not code reuse convenience.

### B) Object Diagram
1. Select scenario instant (timestamp or transaction moment).
2. Instantiate objects from class model.
3. Assign concrete sample values where needed.
4. Draw links between object instances.
5. Verify consistency with class constraints.

Completion checks:
- Every object maps to an existing class.
- Links obey class multiplicities.
- Snapshot explains a specific business or debugging question.

### C) Component Diagram
1. Identify deployable or logical components.
2. Define provided interfaces and required interfaces.
3. Add inter-component dependency arrows.
4. Mark external systems and contracts.
5. Annotate communication style (sync/async, protocol) when relevant.

Completion checks:
- All critical use cases can be traced through components.
- Interfaces have clear ownership.
- Dependency direction matches intended architecture.

### D) Deployment Diagram
1. Enumerate runtime nodes (client, edge, app, db, worker, third-party).
2. Place artifacts/containers/services on nodes.
3. Add network links and trust boundaries.
4. Add environment variants only if needed (dev/stage/prod).
5. Mark scaling and high-availability patterns if relevant.

Completion checks:
- Each runtime artifact is assigned to exactly one primary node.
- Security boundaries are visible.
- Runtime topology matches component interactions.

### E) Package Diagram
1. Group classes/components by bounded context or module.
2. Draw package dependencies with direction.
3. Remove cyclic dependencies when possible.
4. Label package responsibilities.
5. Validate layering rules.

Completion checks:
- Dependency arrows represent allowed coupling only.
- Cycles are either removed or explicitly justified.
- Package names are business-meaningful.

### F) Composite Structure Diagram
1. Choose a classifier requiring internal detail.
2. Define internal parts and their roles.
3. Define ports for interaction points.
4. Connect parts via connectors.
5. Map connectors to interface contracts.

Completion checks:
- Internal collaboration explains external behavior.
- Ports are typed and purpose-specific.
- Internal structure does not duplicate unrelated class detail.

## Quality Gates (Must Pass)
- Correctness: Notation and semantics align with UML intent.
- Consistency: Terms and dependencies match across all produced diagrams.
- Sufficiency: Chosen diagram set answers the original objective.
- Minimality: No redundant diagram elements.
- Actionability: Engineers can derive implementation or refactor tasks.

## Output Contract
Return:
1. Selected structural diagram kinds and why each was chosen.
2. Diagram content in the requested notation (PlantUML, Mermaid, or tool-native spec).
3. Assumptions and unresolved ambiguities.
4. Validation checklist results.

## Collaboration Notes
This skill is workspace-scoped and intended for all Smainer agents, including director and specialist code-owner agents, to keep architecture communication uniform.
