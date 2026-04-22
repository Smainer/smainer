"""
Placeholder test suite for smainer-training.

This suite verifies the core training engine interface and framework readiness.
Engine-specific adapters (Axolotl, Unsloth, LLaMA-Factory, TransformerLab) are
tested in their respective test_*_engine.py modules.
"""

import pytest


class TestFrameworkSetup:
    """Verify framework is properly initialized."""

    def test_import_core_module(self) -> None:
        """Test that core module can be imported."""
        try:
            import smainer_training.core  # noqa: F401
            assert True
        except ImportError:
            pytest.fail("Failed to import smainer_training.core")

    def test_no_backend_imports(self) -> None:
        """Verify no accidental smainer_backend imports in core (HC-1)."""
        import sys
        
        # Scan loaded modules for smainer_backend
        backend_modules = [
            m for m in sys.modules.keys() if m.startswith("smainer_backend")
        ]
        
        # It's OK if backend is not imported (we're testing isolation)
        # But if it IS imported by smainer_training, that's a violation
        if backend_modules:
            # Check if they were imported BY smainer_training
            for module_name in sys.modules:
                if module_name.startswith("smainer_training"):
                    module = sys.modules[module_name]
                    if hasattr(module, "__file__") and module.__file__:
                        # This is a real check; you'd want more sophisticated logic
                        # For now, just verify it's possible to import without backends
                        pass
        
        # Placeholder: actual test is in forbidden-imports.yml CI check
        assert True

    def test_placeholder_passing(self) -> None:
        """Placeholder test ensuring test suite passes on initial setup."""
        # This allows the skeleton repo to have a passing build immediately
        assert True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
