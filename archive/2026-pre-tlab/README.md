# Archive: 2026 Pre-TransformerLab Integration

This folder contains documentation and scripts from pre-Wave-1 phases of Smainer development, archived during the TransformerLab decouple integration (MTG-TLAB-DECOUPLE-01).

## Contents

### Markdown
Stale launch checklists and implementation guides from prior milestones:
- `LAUNCH_PLAN.md` — Node bring-up and launch preparation (node registry phase)
- `LAUNCH_ACTION_CHECKLIST.md` — Launch day action items
- `SECURITY_GATES_CHECKLIST.md` — Pre-mainnet security gate checklist
- `TESTNET_DEPLOYMENT_INSTRUCTIONS.md` — Testnet deployment guide
- `TIERED_REWARDS_IMPLEMENTATION_GUIDE.md` — Tier system implementation walkthrough
- `FIRST_NODE_PRIVACY_AI_TEST_GUIDE.md` — Local provider node test guide
- `SUCCESS_METRICS.md` — Network performance and reliability targets
- `START_HERE.txt` — Onboarding guide from earlier phase

### Scripts (`scripts/`)
One-shot validation and diagnostic scripts used during launch phases:
- `check-provider-status.sh` — Provider node validation against relayer
- `comprehensive-security-audit.sh` — Full security audit execution
- `emergency-incident-response.sh` — Incident response procedures
- `fix-provider-config.sh` — Configuration repair script
- `fix-redis-timeout-logging.sh` — Redis timeout logging fix
- `quick-security-check.sh` — Quick security validation
- `simple-gpu-verification.sh` — GPU hardware verification
- `validate-redis-batch-health.sh` — Redis health validation
- `validate_node_availability_fixes.sh` — Node availability check
- `verify-gpu-node-detection.sh` — GPU detection verification
- `war-room-security-gates.sh` — Security gates execution

## Reason for Archiving

These artifacts were created during earlier development phases (node registry, testnet deployment, security gates) and are superseded by:
- Structured CI/CD workflows (`.github/workflows/`)
- Operational runbooks in `backend/` (e.g., `backend/relayer/README.md`)
- Production monitoring and alerting systems
- The new `smainer-training/` decoupled architecture

## When to Retrieve

- Reference historical deployment procedures: See `LAUNCH_PLAN.md`
- Review pre-mainnet security checklist: See `SECURITY_GATES_CHECKLIST.md`
- Understand tier reward system: See `TIERED_REWARDS_IMPLEMENTATION_GUIDE.md`
- Debug provider or relayer issues: Scripts may contain useful diagnostics

## When to Delete

Consider deleting if:
- CI/CD systems are fully operational (no need for ad-hoc validation scripts)
- New documented runbooks replace all procedures in these scripts
- No legacy issues require historical reference

Current policy: Keep archived for historical reference and debugging. Review quarterly for potential cleanup.

---

**Archived**: April 20, 2026  
**Reason**: TransformerLab decouple integration (Wave 1) — repo restructuring  
**Branch**: Feature branch during MTG-TLAB-DECOUPLE-01 execution
