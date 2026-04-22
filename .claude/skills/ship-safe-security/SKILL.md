---
name: ship-safe-security
description: Use when running security scans with Ship Safe against codebases or MCP manifests before merge or deployment.
user-invocable: false
disable-model-invocation: true
---

# Ship Safe Security

Load this skill for tool-assisted security audits when `ship_safe_*` tools are available in the active runtime.

## Minimal Workflow
1. `ship_safe_audit({ path: "<target>", severity: "high", deep: true })`
2. `ship_safe_get_findings({ path: "<target>", severity: "critical" })`
3. `ship_safe_scan_mcp({ target: "<manifest-path-or-url>" })`
4. Convert output into a severity-ordered Validation Report.
5. Use `ship_safe_suppress_finding` only for verified false positives.

## Reference
See `.github/ship-safe-security.md` for full details.
