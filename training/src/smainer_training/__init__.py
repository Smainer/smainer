from __future__ import annotations

"""
Smainer Training Engine API - Public Interface

This package provides a plugin-based training engine system for distributed GPU training
on the Smainer network. It abstracts multiple training engines behind a stable interface
that evolves independently from the underlying training libraries.

Wave 1 delivers the OOP scaffold and golden test suite.
Concrete engine adapters ship in later waves.
"""

from .core.job_spec import JobSpec
from .core.engine import TrainingEngine
from .core.artifact import Artifact, ArtifactRepository
from .core.events import ProgressEvent, StatusEvent, CheckpointEvent, ErrorEvent
from .core.exceptions import TrainingError
from .service.training_service import TrainingService
from .registry.engine_registry import get_registry
from .events.event_bus import get_event_bus

__all__ = [
    "TrainingService",
    "JobSpec", 
    "TrainingEngine",
    "Artifact",
    "ArtifactRepository",
    "ProgressEvent",
    "StatusEvent", 
    "CheckpointEvent",
    "ErrorEvent",
    "TrainingError",
    "get_registry",
    "get_event_bus",
]

__all__ = [
    "TrainingService",
    "JobSpec", 
    "TrainingEngine",
    "Artifact",
    "ArtifactRepository",
    "ProgressEvent",
    "StatusEvent", 
    "CheckpointEvent",
    "ErrorEvent",
    "TrainingError",
    "get_registry",
    "get_event_bus",
]