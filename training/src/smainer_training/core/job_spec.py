"""
JobSpec: Immutable specification for training jobs.

The Bridge pattern abstraction that evolves independently from training engine internals.
JobSpecs are immutable value objects that accept Visitor pattern operations for
validation, cost estimation, secret scrubbing, and telemetry.
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass
from enum import StrEnum
from typing import Any, Dict, TYPE_CHECKING

if TYPE_CHECKING:
    from ..visitors.base import JobSpecVisitor, Result


class TrainingMethod(StrEnum):
    """Supported training/fine-tuning methods."""
    LORA = "lora"
    QLORA = "qlora" 
    FULL_FT = "full_ft"
    DPO = "dpo"
    ORPO = "orpo"


class LicenseTolerance(StrEnum):
    """License tolerance policy for engine selection."""
    PERMISSIVE_ONLY = "permissive_only"  # Apache/MIT only, no AGPL subprocess calls
    ALLOW_AGPL_SUBPROCESS = "allow_agpl_subprocess"  # Permit AGPL via subprocess + Unix socket


@dataclass(frozen=True)
class GpuRequest:
    """Resource request specification for training jobs."""
    min_vram_gb: int
    preferred_vram_gb: int | None = None
    gpu_count: int = 1
    requires_cuda: bool = True
    requires_mlx: bool = False
    requires_rocm: bool = False


@dataclass(frozen=True) 
class OutputSpec:
    """Specification for training output artifacts."""
    format: str  # "pytorch", "gguf", "lora_adapter", etc.
    compression: str | None = None
    max_size_gb: float = 10.0
    include_checkpoints: bool = True


@dataclass(frozen=True)
class JobSpec:
    """
    Immutable specification for a training job.
    
    Implements the Bridge pattern abstraction side - evolves independently from
    training engine implementations. Supports Visitor pattern for cross-cutting
    concerns like validation, pricing, secret scrubbing, and telemetry.
    """
    job_id: str
    model_id: str
    method: TrainingMethod
    dataset_uri: str
    hyperparams: Dict[str, Any]
    resource_request: GpuRequest
    output_spec: OutputSpec
    license_tolerance: LicenseTolerance
    submitted_at: datetime.datetime
    
    def accept(self, visitor: JobSpecVisitor[Any]) -> Result[Any]:
        """Accept a visitor operation on this JobSpec (Visitor pattern)."""
        return visitor.visit(self)