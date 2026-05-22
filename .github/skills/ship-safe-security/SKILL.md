---
name: ship-safe-security
description: Use when running security scans with Ship Safe against codebases or MCP manifests before merge or deployment.
argument-hint: "path and scope for security scan"
user-invocable: false
disable-model-invocation: false
---

# Ship Safe Security

Load this skill for tool-assisted security audits when `ship_safe_*` tools are available in the active runtime.

## Why This Skill Exists
- Keep security scans structured and repeatable.
- Prioritize exploitable issues over scanner noise.
- Minimize context bloat by pulling only actionable findings.

## Minimal Workflow
1. Run a baseline scan:
   - `ship_safe_audit({ path: "<target>", severity: "high", deep: true })`
2. Pull focused findings only:
   - `ship_safe_get_findings({ path: "<target>", severity: "critical" })`
   - `ship_safe_get_findings({ path: "<target>", severity: "high" })`
3. For MCP manifests, scan before trust:
   - `ship_safe_scan_mcp({ target: "<manifest-path-or-url>" })`
4. Convert findings into a Validation Report with severity ordering and concrete remediation.
5. Suppress only after verification:
   - `ship_safe_suppress_finding({ file: "<path>", line: <n>, reason: "<why safe>" })`

## Context Discipline
- Scan only the component in scope.
- Do one deep scan first, then narrow follow-ups.
- Avoid re-printing full reports; summarize top actionable issues.

## Hard Rules
- Never suppress findings before code-path verification.
- Never auto-suppress critical findings.
- Never expose secrets from findings in output.

## Reference
For full tool details and examples, see `.github/ship-safe-security.md`.
