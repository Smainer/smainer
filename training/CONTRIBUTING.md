# Contributing to smainer-training

Thank you for contributing to the Smainer training framework! This guide outlines how to add a new engine adapter and maintain the codebase.

## Code of Conduct

We follow the [Smainer Code of Conduct](../CODE_OF_CONDUCT.md). Be respectful, inclusive, and professional.

---

## How to Add a New Engine Adapter

### 1. Create the Engine Module

Create a file `src/smainer_training/engines/your_engine.py`:

```python
from typing import Any, Dict
from smainer_training.core import TrainingEngine

class YourEngine(TrainingEngine):
    """Adapter for YourTrainingFramework."""

    def __init__(self):
        self.name = "your_engine"
        self.version = "1.0.0"

    def validate_config(self, config: Dict[str, Any]) -> bool:
        """
        Validate the training config for YourEngine.
        
        Expected config keys:
        - model_id: str (HuggingFace model or local path)
        - dataset_path: str
        - epochs: int
        - learning_rate: float
        
        Returns True if valid, False otherwise.
        """
        required_keys = {"model_id", "dataset_path", "epochs", "learning_rate"}
        return required_keys.issubset(config.keys())

    async def train(self, job_id: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute training and return results.
        
        Args:
            job_id: Unique job identifier (for logging/tracking)
            config: Validated training configuration
            
        Returns:
            {
                "job_id": str,
                "engine": str,
                "status": "completed" | "failed",
                "model_path": str,
                "metrics": {
                    "final_loss": float,
                    "eval_accuracy": float,
                    ...
                },
                "error": str (if failed)
            }
        """
        try:
            # 1. Validate config
            if not self.validate_config(config):
                return {
                    "job_id": job_id,
                    "engine": self.name,
                    "status": "failed",
                    "error": "Invalid config",
                    "model_path": None,
                    "metrics": {},
                }
            
            # 2. Import YourEngine (NOT smainer_backend!)
            from your_framework import Trainer
            
            # 3. Set up training
            trainer = Trainer(**config)
            
            # 4. Execute
            metrics = await trainer.fit()  # or whatever your framework provides
            
            # 5. Return results
            return {
                "job_id": job_id,
                "engine": self.name,
                "status": "completed",
                "model_path": config.get("output_dir", "/models/your_engine_output"),
                "metrics": metrics,
                "error": None,
            }
        except Exception as e:
            return {
                "job_id": job_id,
                "engine": self.name,
                "status": "failed",
                "model_path": None,
                "metrics": {},
                "error": str(e),
            }

    def get_supported_models(self) -> list[str]:
        """Return list of models this engine can fine-tune."""
        return [
            "meta-llama/Llama-2-7b",
            "meta-llama/Llama-2-13b",
            # ... add your supported models
        ]
```

### 2. Register in Engine Factory

Update `src/smainer_training/engines/__init__.py`:

```python
from smainer_training.engines.your_engine import YourEngine

__all__ = ["YourEngine"]
```

Update the factory in `src/smainer_training/factory.py` (or wherever engine registration happens):

```python
from smainer_training.engines import YourEngine

ENGINE_REGISTRY = {
    "your_engine": YourEngine,
    # ... other engines
}
```

### 3. Write Tests

Create `tests/test_your_engine.py`:

```python
import pytest
from smainer_training.engines.your_engine import YourEngine

@pytest.fixture
def engine():
    return YourEngine()

def test_validate_config_valid(engine):
    """Test that valid config passes validation."""
    config = {
        "model_id": "meta-llama/Llama-2-7b",
        "dataset_path": "/data/dataset.json",
        "epochs": 3,
        "learning_rate": 2e-5,
    }
    assert engine.validate_config(config) is True

def test_validate_config_missing_keys(engine):
    """Test that missing keys fail validation."""
    config = {"model_id": "meta-llama/Llama-2-7b"}  # Missing required keys
    assert engine.validate_config(config) is False

@pytest.mark.asyncio
async def test_train_returns_expected_structure(engine):
    """Test that train() returns the expected result structure."""
    config = {
        "model_id": "meta-llama/Llama-2-7b",
        "dataset_path": "/data/dataset.json",
        "epochs": 1,
        "learning_rate": 2e-5,
    }
    result = await engine.train("test_job_1", config)
    
    assert "job_id" in result
    assert "engine" in result
    assert "status" in result
    assert result["status"] in ["completed", "failed"]
    assert "metrics" in result
    assert "error" in result

def test_get_supported_models(engine):
    """Test that engine reports supported models."""
    models = engine.get_supported_models()
    assert isinstance(models, list)
    assert len(models) > 0
```

**Golden Test Suite**: All new engine adapters must pass:
- ✅ Config validation (valid inputs pass, invalid fail)
- ✅ Successful train() execution (or mock if you don't have the framework installed)
- ✅ Error handling (graceful failure on bad config)
- ✅ Expected return structure (job_id, engine, status, metrics, error)
- ✅ Type hints on all public methods (enforced by mypy)

### 4. License & Dependency Check

**If your engine depends on AGPL packages:**
- It MUST NOT be imported directly in `smainer-backend/`
- It MUST run as subprocess only
- Document this in the README under "AGPL Boundary"

**Verify license compliance:**
```bash
# In your feature branch
pip install -e ".[your_engine]"
pip-licenses --format=json | grep -i "agpl" || echo "✓ No AGPL"
```

### 5. Update Documentation

If your engine needs special config or setup, update the appropriate section of [README.md](README.md):

```markdown
### MyEngine Setup

YourEngine requires...
```

### 6. Open a Pull Request

- Ensure your branch passes all CI checks (see [.github/workflows](.github/workflows/)).
- Commit message format: `feat(engines): add my_engine adapter`
- **Required reviewers**: `security-expert`, `relayer-architect` (enforced by [CODEOWNERS](CODEOWNERS))

---

## Vendor Bump Procedure

### Adding a New Vendored Engine

If you need to add a new engine as a Git subtree (for tight integration or offline access):

```bash
# 1. Add the subtree
git subtree add --prefix vendors/my_engine https://github.com/owner/my_engine.git v1.0.0 --squash

# 2. Create adapter that uses vendors/my_engine
# src/smainer_training/engines/my_engine.py
from sys import path
path.insert(0, "vendors/my_engine")
from my_engine import Trainer

# 3. Add to pyproject.toml optional deps (if appropriate)
# [project.optional-dependencies]
# my_engine = [...]

# 4. Test and commit
pytest tests/
git add .
git commit -m "chore(vendors): add my_engine v1.0.0 as subtree"

# 5. Push
git push origin feature/add-my_engine
```

### Updating an Existing Vendor

```bash
# 1. Pull latest from upstream
git subtree pull --prefix vendors/axolotl https://github.com/OpenAccess-AI-Collective/axolotl.git main --squash

# 2. Test compatibility
pytest tests/

# 3. Commit
git commit -m "chore(vendors): bump axolotl to latest main"

# 4. Push
git push origin chore/bump-axolotl
```

---

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(engines): add transformerlab adapter
^    ^        ^
|    |        └─ description
|    └────────── scope (engines, core, factory, etc.)
└───────────── type (feat, fix, docs, chore, test, ci)

Optional body: Explain the "why" if non-obvious.

Optional footer: Closes #42
```

### Examples

```
feat(engines): add unsloth support

- Implement UnslothEngine adapter with 4-bit quantization support
- Add config validation for tensor types
- Update vendor bump procedure in vendors/README.md

Closes #12
```

```
fix(core): handle subprocess timeout gracefully

TimeoutError now surfaces with clear message to relayer instead of crashing.

Closes #8
```

---

## Code Quality

All code must pass:

```bash
# Linting
ruff check src/ tests/

# Type checking
mypy src/ tests/

# Unit tests
pytest tests/

# License scanning (for dependency review)
pip-licenses --format=json
```

Enable pre-commit hooks locally:

```bash
# Optional: install pre-commit
pip install pre-commit
pre-commit install

# Now `git commit` will auto-run these checks
```

---

## License

By contributing, you agree that your code will be licensed under [Apache-2.0](LICENSE).

If your adapter depends on AGPL libraries, that's allowed **as long as it runs in isolation** (subprocess, separate container). Document the boundary clearly.

---

## Questions?

- Check [README.md](README.md) for architecture overview
- File an issue with your question or suggestion
- Tag `security-expert` or `relayer-architect` for license/architecture concerns

Happy contributing! 🚀
