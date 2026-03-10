# Security Policy

## Supported Branch

Security fixes are applied to:
- `main`

## Reporting a Vulnerability

Please do not disclose vulnerabilities publicly before triage.

Report security issues by email:
- `security@smainer.io`

Include:
- Affected component (`backend`, `contracts`, `frontend`, `telegram`, `desktop`)
- Impact summary
- Reproduction steps
- Any proof-of-concept details

We will acknowledge receipt as soon as possible and coordinate a responsible disclosure timeline.

## Sensitive Data Rules

- Never commit private keys, mnemonics, API secrets, or credentials.
- Use environment variables for secrets.
- Validate all blockchain transaction inputs and addresses.
