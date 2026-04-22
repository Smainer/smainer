# Vendor Management

This directory contains Git subtrees for upstream training engines integrated into smainer-training.

## Overview

Vendored engines are integrated as Git subtrees (not submodules) to:
- Keep history preserved (git-subtree preserves full upstream history)
- Allow local patches if needed
- Enable atomic commits across engine updates

## Available Engines

| Engine | Repository | License | Status |
|--------|------------|---------|--------|
| **Axolotl** | github.com/OpenAccess-AI-Collective/axolotl | Apache-2.0 | Planned |
| **Unsloth** | github.com/unslothai/unsloth | AGPL-3.0 | Planned |
| **LLaMA-Factory** | github.com/hiyouga/LLaMA-Factory | Apache-2.0 | Planned |
| **TransformerLab** | github.com/transformerlab/transformerlab | AGPL-3.0 | Planned |

---

## Adding a New Vendor

### 1. Add the subtree at a stable tag

```bash
# Example: Add Axolotl at v0.3.0
git subtree add --prefix vendors/axolotl \
  https://github.com/OpenAccess-AI-Collective/axolotl.git \
  v0.3.0 \
  --squash
```

**Flags explained:**
- `--prefix vendors/axolotl`: Local directory where vendor lives
- `--squash`: Squash upstream commits into a single commit (keeps our history clean)

### 2. Create adapter module

Create `src/smainer_training/engines/my_engine.py` that:
- Imports from `vendors/my_engine`
- Implements the `TrainingEngine` interface
- Handles errors gracefully

### 3. Test the integration

```bash
pytest tests/test_my_engine.py -v
```

### 4. Update pyproject.toml (if needed)

If the vendor has runtime dependencies, add to optional dependencies:

```toml
[project.optional-dependencies]
my_engine = [
    "some-dependency>=1.0",
]
```

### 5. Commit

```bash
git add .
git commit -m "chore(vendors): add my_engine v0.3.0"
git push origin feature/add-my_engine
```

---

## Updating a Vendor

### 1. Pull latest from upstream

```bash
# Update to latest tag
git subtree pull --prefix vendors/axolotl \
  https://github.com/OpenAccess-AI-Collective/axolotl.git \
  v0.4.0 \
  --squash

# Or pull latest main branch
git subtree pull --prefix vendors/axolotl \
  https://github.com/OpenAccess-AI-Collective/axolotl.git \
  main \
  --squash
```

### 2. Test for compatibility

```bash
# Run adapter tests
pytest tests/test_my_engine.py -v

# Run full suite
pytest tests/

# Type checking
mypy src/

# Linting
ruff check src/
```

### 3. If tests fail

Investigate what broke:
- Did the engine API change?
- Are there new required config fields?
- Update your adapter in `src/smainer_training/engines/my_engine.py`
- Update tests in `tests/test_my_engine.py`

### 4. Commit and push

```bash
git add .
git commit -m "chore(vendors): bump axolotl to v0.4.0

- Update MyEngine adapter for new API
- Add config field: quantization_type
- Extend test coverage
"
git push origin chore/bump-axolotl
```

---

## Removing a Vendor

If an engine is no longer maintained or used:

```bash
# Remove the subtree
git rm -r vendors/my_engine
git commit -m "chore(vendors): remove my_engine

Rationale: No longer actively maintained. API adapter moved to archive."
```

---

## Checking Vendor Status

View what vendors are currently integrated:

```bash
# Show git subtree splits
git log --grep="git-subtree" --oneline

# Or manually list vendors/
ls -la vendors/

# Check version of a specific vendor
cd vendors/axolotl && git describe --tags && cd ../..
```

---

## Notes for Contributors

**DO:**
- ✅ Test thoroughly before updating a vendor
- ✅ Use `--squash` to keep our history clean
- ✅ Document breaking changes in commit message
- ✅ Update adapter code and tests together
- ✅ Run full CI before pushing

**DON'T:**
- ❌ Directly edit files inside `vendors/` — they'll be overwritten on next pull
- ❌ Skip testing after a vendor bump
- ❌ Use `--no-squash` (creates messy history)
- ❌ Pull from `main`/unstable branches without testing (use stable tags)

---

## Troubleshooting

### "Subtree not found" error

If git subtree complains the prefix doesn't exist yet (on first add):

```bash
# Make sure you're adding to an empty prefix
git subtree add --prefix vendors/my_new_engine ... --squash
```

### Conflict during subtree pull

If there are local changes conflicting with upstream:

```bash
# 1. Stash local changes
git stash

# 2. Pull the update
git subtree pull --prefix vendors/axolotl ... --squash

# 3. Reapply your changes
git stash pop

# 4. Resolve conflicts manually if needed
git status  # shows conflicts
# Edit files to resolve...
git add .
git commit -m "chore: resolve merge conflicts after axolotl update"
```

### How do I see if there are commits upstream I don't have?

```bash
# Fetch without pulling
git fetch https://github.com/OpenAccess-AI-Collective/axolotl.git v0.5.0

# See what's new
git log HEAD..FETCH_HEAD --oneline
```

---

## References

- [Git Subtree Documentation](https://git-scm.com/book/en/v2/Git-Tools-Subtrees)
- [Atlassian Git Subtree Guide](https://www.atlassian.com/git/tutorials/git-subtree)

---

## Questions?

- See [CONTRIBUTING.md](../CONTRIBUTING.md) for vendor bump procedures
- Open an issue tagged `vendors` or `dependencies`
