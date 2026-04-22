# Skills Catalog Policy

## Goal
Keep Copilot UI clean while preserving cross-runtime compatibility.

## Source of Truth
- Canonical, user-visible skills live in `.github/skills/`.
- `.claude/skills/` is a compatibility mirror and must remain non-invocable.

## Required Metadata
For every mirrored skill in `.claude/skills/*/SKILL.md`:
- `user-invocable: false`
- `disable-model-invocation: true`

For canonical skills in `.github/skills/*/SKILL.md`:
- Set `user-invocable` intentionally (`true` only when direct user invocation is desirable).
- Keep descriptions short and task-scoped to control context size.

## Adding a New Skill
1. Add canonical version under `.github/skills/<skill-name>/SKILL.md`.
2. Add compatibility mirror under `.claude/skills/<skill-name>/SKILL.md` with non-invocable metadata.
3. Prefer concise runbooks over long prose; link to deep docs when needed.

## Why This Works
This avoids duplicate skill choices in Copilot while keeping parity for Claude-specific workflows.
