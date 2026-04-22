"""
Engine registry for managing available training engines.

Singleton registry that tracks installed training engine adapters.
Provides registration, lookup, and enumeration of available engines.
"""
from __future__ import annotations

from typing import Dict, List, TYPE_CHECKING

if TYPE_CHECKING:
    from ..core.engine import TrainingEngine


class EngineRegistry:
    """
    Singleton registry for training engine management.
    
    Maintains a registry of installed training engine adapters.
    Engines are registered by name and can be retrieved for job execution.
    
    Uses module-level singleton pattern with explicit reset for testing.
    """
    
    def __init__(self) -> None:
        self._engines: Dict[str, TrainingEngine] = {}
        
    def register(self, engine_cls: type[TrainingEngine]) -> None:
        """
        Register a training engine adapter class.
        
        The engine class will be instantiated once and stored.
        Registration typically happens during module import.
        """
        # Create single instance to store
        engine_instance = engine_cls()
        name = engine_instance.name
        self._engines[name] = engine_instance
        
    def unregister(self, name: str) -> None:
        """Remove an engine from the registry."""
        self._engines.pop(name, None)
        
    def get(self, name: str) -> TrainingEngine | None:
        """Get an engine instance by name."""
        return self._engines.get(name)
        
    def all(self) -> List[TrainingEngine]:
        """Get instances of all registered engines."""
        return list(self._engines.values())
        
    def names(self) -> List[str]:
        """Get names of all registered engines."""
        return list(self._engines.keys())
        
    def count(self) -> int:
        """Get count of registered engines."""
        return len(self._engines)

    def _reset_for_tests(self) -> None:
        """Reset registry state for testing. Test use only!"""
        self._engines.clear()


# Module-level singleton instance
_INSTANCE = EngineRegistry()


def get_registry() -> EngineRegistry:
    """Get the global engine registry instance."""
    return _INSTANCE