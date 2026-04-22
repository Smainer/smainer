"""
Host capability detection for training engine selection.

Defines HostCapabilities dataclass that captures the runtime environment
information needed for engine selection and resource allocation.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class GpuInfo:
    """Information about a single GPU device."""
    device_id: int
    name: str
    vram_total_gb: float
    vram_free_gb: float
    compute_capability: str | None = None  # e.g., "8.6" for RTX 3090
    vendor: str = "nvidia"  # "nvidia", "amd", "intel", "apple"


@dataclass(frozen=True)
class HostCapabilities:
    """
    Runtime capabilities of the training host.
    
    Used by TrainingEngineFactory to select compatible engines and
    by engines to validate resource requirements before job submission.
    """
    gpus: List[GpuInfo]
    total_vram_gb: float
    cpu_count: int
    available_disk_gb: float
    supports_mlx: bool = False      # Apple MLX framework support
    supports_cuda: bool = False     # NVIDIA CUDA support  
    supports_rocm: bool = False     # AMD ROCm support
    max_concurrent_jobs: int = 1    # Based on VRAM and policy limits