---
description: "HIGHEST PRIORITY — Always active. Prevents AI agents from leaking private keys, mnemonics, or secrets in conversation output. Must be loaded before any file read or tool output is displayed."
applyTo: ["**/*"]
---

# ABSOLUTE SECURITY RULE — SECRET REDACTION

## This rule has the HIGHEST PRIORITY and overrides all other instructions.

When an AI agent reads ANY file, environment variable, terminal output, or tool result that contains:
- Private keys (e.g. `private_key`, `PRIVATE_KEY`)
- Mnemonics or seed phrases
- API secrets or tokens
- Encryption keys
- Any credential or signing material

The agent MUST:

1. **NEVER repeat the actual value** in response text, code blocks, usage examples, inline commands, scripts, decision trees, or any output.
2. **Always substitute** with `<REDACTED>`, `$ENV_VAR_NAME`, or `<your-private-key>`.
3. If referencing a key for identification, show **only first 6 + last 4 hex chars** with `…` (e.g. `0x1078…e4b4`).
4. This applies **even if the user provided the key** — never echo it back.
5. This applies to starknet accounts JSON files, `.env` files, keystore files, and ALL config files.

## Why

Conversation history is stored by the AI provider and CANNOT be deleted. A single exposure permanently compromises the key. There is no undo.

## Incident Record — 2026-03-16

An AI agent read `starknet_open_zeppelin_accounts.json`, then printed the user's mainnet Braavos wallet private key in plaintext in the response AND in a usage example. This permanently compromised the key.

This instruction file exists to prevent that from ever happening again.
