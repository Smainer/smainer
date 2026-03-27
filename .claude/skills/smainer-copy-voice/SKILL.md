---
name: smainer-copy-voice
description: Use when generating text for the UI, command line output, marketing materials, or user-facing messaging.
---

# Smainer Copy & Voice Standards

Smainer's UI and scripts must sound like a professional Web3/AI infrastructure product. Ban consumer-fluff.

## 1. Tone Constraints
- **Yes:** "Privacy AI", "STRK only", "On-chain verification"
- **No:** "Revolutionizing the future", "Simple magic", "Super easy", emojis, gradient references.
- **NEVER** imply a custom unlaunched Smainer coin. Only reference $STRK rewards.

## 2. Component Directives
- **Headlines:** Max 8 words. Verb-focused. Do not ask rhetorical questions.
- **CTAs (Buttons/CLI Prompts):** 2-4 words that declare the actionable conclusion. ("Start Free Task" / "Deploy Node") Not vague verbs ("Submit").
- **Errors/Empty States:** Provide exactly *why* it failed, and *what* step to take next. Do not use generic fallback phrases.

## 3. Demographics
- **Demanders:** Want SLA certainty and zero-account Friction (via TG/Wallets). Focus copy on cost (STRK), privacy, and exact task latency.
- **Providers (Desktop/Miners):** Want to see raw specs. Present them precisely (e.g. `RTX 4090 24GB`, `TFLOPs`). Treat them as power-users.

## Input Contract
- **Trigger**: Called when writing or auditing any user-facing text (UI, marketing, docs, error messages)
- **Required context**: Funnel stage (awareness / consideration / conversion / retention) + target audience (demander or provider) + component type (headline, CTA, error message, etc.)
- **Optional**: Existing copy for audit

## Output Contract
- **Copy deliverable**: The exact text strings with funnel stage label
- **Rationale**: One sentence explaining why each choice serves the conversion goal
- **Anti-patterns flagged**: Any existing text that violates brand voice rules
