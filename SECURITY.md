<div align="center">

# Security Policy

[![Responsible Disclosure](https://img.shields.io/badge/Responsible%20Disclosure-security%40smainer.io-red.svg)](mailto:security@smainer.io)

</div>

---

## Supported Branch

Security fixes are applied to:
- `main`

---

## Reporting a Vulnerability

>  Please **do not** disclose vulnerabilities publicly before triage.

Report security issues by email to **[security@smainer.io](mailto:security@smainer.io)**.

Include the following in your report:

| Field | Details |
|-------|---------|
| **Affected component** | `backend`, `contracts`, `frontend`, `telegram`, or `desktop` |
| **Impact summary** | Brief description of the potential impact |
| **Reproduction steps** | Step-by-step guide to reproduce |
| **Proof-of-concept** | Any PoC details (optional but helpful) |

We will acknowledge receipt as soon as possible and coordinate a responsible disclosure timeline.

---

## Sensitive Data Rules

- Never commit private keys, mnemonics, API secrets, or credentials.
- Use environment variables for secrets.
- Validate all blockchain transaction inputs and addresses.
