# Candidates for Deletion

The following files are one-shot patches and cleanup scripts that are likely no longer needed. They have been staged here for review and approval before permanent deletion.

## Patch Scripts (`.js` files)

**Purpose**: One-time patches to fix hardcoded contract addresses and values in the miniapp.

Once applied (values embedded in source files), these scripts are no longer needed. Suggest deleting if:
- All contract addresses are now sourced from environment variables or config files
- Values are no longer hardcoded in miniapp

**Files**:
- `patch_compute_hook.js` — Patched compute hook contract references
- `patch_connect_button.js` — Patched wallet connect button
- `patch_escrow_hook.js` — Patched escrow hook contract references
- `patch_miniapp_addresses.js` — Patched miniapp contract addresses (changed 0x01-0x05 to 0x0)
- `patch_miniapp_starknet.js` — Patched miniapp Starknet integration
- `patch_miniapp_wallet_connect.js` — Patched miniapp wallet connect

**Recommendation**: **DELETE** — These are one-shot patches; value is baked into code now.

---

## Cleanup Scripts

### `repo-cleanup-execute.sh`
**Purpose**: Execution script for a previous `REPO_CLEANUP_STRATEGY.md` phase.

Implements multi-phase repository cleanup (submodule fixes, file organization, commit grouping). This is a **previous cleanup attempt** that's now superseded by the current organized structure.

**Status**: Used in prior cleanup phase; no longer needed.

**Recommendation**: **DELETE** — Legacy cleanup script from prior phase. Keep archive/README.md instead.

### `runpod-provider-verification.sh`
**Purpose**: Runpod-specific WebSocket and GPU detection verification for the provider node.

Tests provider connectivity to relayer and GPU availability on Runpod instances.

**Status**: May still be useful for Runpod deployments, but likely superseded by CI/CD checks and monitoring.

**Recommendation**: **ARCHIVE to `backend/provider/scripts/`** if still used, or **DELETE** if not needed for current Runpod workflow. Check with `systems-engineer` or `relayer-architect`.

---

## Summary for Approval

| File | Type | Recommendation | Reason |
|------|------|-----------------|--------|
| patch_*.js (6 files) | Patch | DELETE | One-shot patches; values now in code |
| repo-cleanup-execute.sh | Cleanup | DELETE | Legacy script from prior phase |
| runpod-provider-verification.sh | Diagnostic | UNKNOWN | Verify with systems team |

**Action Required**: Review each file above and approve deletion. Once approved, execute:

```bash
# Permanent deletion (after approval)
cd /home/smainer/Smainer
git rm archive/2026-pre-tlab/candidates-for-deletion/patch_*.js
git rm archive/2026-pre-tlab/candidates-for-deletion/repo-cleanup-execute.sh
git rm archive/2026-pre-tlab/candidates-for-deletion/runpod-provider-verification.sh  # if approved
git commit -m "chore: permanently delete one-shot patches and cleanup scripts"
```

Or move specific files to `backend/provider/scripts/` if they are still operationally useful.

---

**File List for Safe Review**:
```
archive/2026-pre-tlab/candidates-for-deletion/
├── patch_compute_hook.js
├── patch_connect_button.js
├── patch_escrow_hook.js
├── patch_miniapp_addresses.js
├── patch_miniapp_starknet.js
├── patch_miniapp_wallet_connect.js
├── repo-cleanup-execute.sh
└── runpod-provider-verification.sh
```

No files have been deleted yet. They are preserved in git history at this path for review.
