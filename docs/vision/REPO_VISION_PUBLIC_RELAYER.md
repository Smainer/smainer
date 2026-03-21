# Smainer Repo Vision: Public Relayer, Verifiable Coordination, and Early Provider Incentives

Date: March 15, 2026
Status: Repository vision and public positioning baseline

## Vision Statement

Smainer's relayer must be public.

That is core to the protocol thesis: participants should be able to inspect, audit, and run compatible coordination software rather than trusting a black box.

At the same time, public software does not mean exposing sensitive operational internals. We publish protocol and coordination logic while protecting keys, infrastructure details, and anti-abuse controls.

## Vision Commitments

1. Coordination logic is public and auditable.
2. Economic rules are explicit and enforced by contract.
3. Operational security is strict and never sacrificed for optics.
4. Decentralization progresses through measurable milestones.
5. Provider trust is earned with verifiable fairness, not claims.

## Why the Relayer Code Is Public

1. Trust through verification, not promises.
2. Fairness can be audited by providers and demanders.
3. Community contributors can improve reliability and performance.
4. Multi-relayer decentralization becomes possible only when implementation is open.
5. Public code aligns with Smainer's Starknet-native transparency model.

## What Is Public vs What Is Private

### Public by Default

1. Relayer source code and routing logic.
2. Smart contract source code and payout logic.
3. Task lifecycle and status model.
4. Fee math and reward formulas.
5. Protocol documentation and API contracts.

### Private by Design

1. Private keys and signing material.
2. Internal infrastructure topology and hardening details.
3. Dynamic anti-spam and anti-abuse thresholds.
4. Sensitive incident response procedures.
5. Private user data and encrypted payload content.

## Decentralization Path

Smainer uses staged decentralization with explicit milestones:

1. Transparent single-operator relayer with public code and auditability.
2. Multi-operator relayer participation with compatibility requirements.
3. Governance-driven coordination and further trust minimization.

This path keeps launch speed while preserving long-term protocol credibility.

## Early Provider Incentive: First-Month x2 by Contract, Permanent

To bootstrap the provider side of the network, Smainer grants an early provider multiplier:

1. Providers who qualify during the first 30 days receive a permanent 2x base reward multiplier.
2. The multiplier is enforced on-chain by contract logic, not by manual off-chain accounting.
3. The benefit is intended as a long-term reward for early network risk and contribution.

Canonical statement:

"Providers that qualify during the first 30 days receive a permanent 2x base reward multiplier enforced by smart contract."

## Qualification and Integrity Rules

The permanent multiplier should remain simple, auditable, and abuse-resistant. Public docs and UI should clearly define:

1. Qualification window start and end timestamps.
2. Minimum activity requirement to activate eligibility.
3. One qualification per unique provider identity.
4. Objective performance requirements (uptime and successful completion).
5. Transparent disqualification conditions for abuse.

## Messaging Guidelines

Use:

1. "Open relayer code, protected operations."
2. "Auditable coordination, on-chain enforced rewards."
3. "First-month providers: permanent 2x base multiplier by contract."

Avoid:

1. "Guaranteed returns" or investment language.
2. "Unhackable" or absolute security claims.
3. Ambiguous wording like "x2 forever" without eligibility criteria.

## Launch-Ready Copy Block

Smainer runs public relayer software because transparent coordination is the product, not a marketing claim. Anyone can inspect and verify routing logic, fee logic, and reward logic. Sensitive operations remain protected so the system stays safe under real adversarial conditions.

To reward early network builders, providers who qualify in the first month receive a permanent 2x base reward multiplier enforced by contract. The rule is programmatic, auditable, and applied by protocol logic, not by manual exceptions.

## Decision Summary

1. Yes, the relayer should be public.
2. No, operational secrets should not be public.
3. Yes, first-month qualified providers get permanent 2x base rewards by contract.
4. Publish exact eligibility rules alongside this policy before launch.
