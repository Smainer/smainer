"""
Event system for training progress and status reporting.

Defines event dataclasses used in the Observer pattern for progress streaming.
Events flow from training engines through the event bus to IPC clients.
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass
from typing import Any, Dict


@dataclass(frozen=True)
class ProgressEvent:
    """Training progress metrics emitted during job execution."""
    job_id: str
    timestamp: datetime.datetime
    step: int
    total_steps: int | None = None
    loss: float | None = None
    learning_rate: float | None = None
    throughput_tokens_per_sec: float | None = None
    gpu_utilization_pct: float | None = None
    vram_used_gb: float | None = None
    extra_metrics: Dict[str, Any] | None = None


@dataclass(frozen=True)
class StatusEvent:
    """Job lifecycle status changes."""
    job_id: str
    timestamp: datetime.datetime
    old_status: str
    new_status: str  # "queued", "running", "completed", "failed", "cancelled"
    message: str | None = None


@dataclass(frozen=True)
class CheckpointEvent:
    """Checkpoint creation notifications."""
    job_id: str
    timestamp: datetime.datetime
    checkpoint_path: str
    step: int
    loss: float | None = None
    size_bytes: int | None = None
    is_best: bool = False  # True if this is the best checkpoint so far


@dataclass(frozen=True)
class ErrorEvent:
    """Error conditions during training."""
    job_id: str
    timestamp: datetime.datetime
    error_type: str  # "validation_failed", "resource_exhausted", "engine_crashed", etc.
    error_message: str
    recoverable: bool = False
    stack_trace: str | None = None