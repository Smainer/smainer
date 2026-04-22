"""
TrainingEngine: Abstract interface for training engine implementations.

Defines the stable contract that all engine adapters must honor. This interface
evolves only via Cross-Domain Alignment Meetings between repository-architect
and implementer agents.
"""
from __future__ import annotations

import abc
from dataclasses import dataclass
from typing import Iterator, TYPE_CHECKING

if TYPE_CHECKING:
    from .job_spec import JobSpec
    from .host_caps import HostCapabilities
    from .events import ProgressEvent
    from .artifact import Artifact


@dataclass(frozen=True)
class JobHandle:
    """Opaque handle to a submitted training job."""
    handle_id: str
    engine_name: str


@dataclass(frozen=True)
class JobStatus:
    """Current status of a training job."""
    handle: JobHandle
    state: str  # "queued", "running", "completed", "failed", "cancelled"
    progress_pct: float = 0.0
    message: str | None = None
    error: str | None = None


class TrainingEngine(abc.ABC):
    """
    Abstract base class for all training engine implementations.
    
    Each engine adapter (Axolotl, LLaMA-Factory, Unsloth, TransformerLab)
    implements this interface to provide a unified way to submit, monitor,
    and manage training jobs across different underlying libraries.
    """

    @property
    @abc.abstractmethod
    def name(self) -> str:
        """Engine name for identification and registry lookup."""
        pass

    @property
    @abc.abstractmethod  
    def supported_methods(self) -> set[str]:
        """Set of training methods this engine supports."""
        pass

    @abc.abstractmethod
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        """
        Check if this engine can handle the given job on the host.
        
        Returns True if the engine supports the job's method, model,
        resource requirements, and is compatible with the host capabilities.
        """
        pass

    @abc.abstractmethod
    def submit(self, spec: JobSpec) -> JobHandle:
        """
        Submit a job to this engine for execution.
        
        Returns immediately with a handle for polling status.
        Does not block for job completion.
        """
        pass

    @abc.abstractmethod
    def poll(self, handle: JobHandle) -> JobStatus:
        """Get current status of a job."""
        pass

    @abc.abstractmethod
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        """
        Stream progress events from a running job.
        
        Yields ProgressEvent instances with step counts, loss values,
        learning rates, and throughput metrics as they become available.
        """
        pass

    @abc.abstractmethod
    def cancel(self, handle: JobHandle) -> None:
        """Cancel a running or queued job."""
        pass

    @abc.abstractmethod
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        """
        Produce final artifact from a completed job.
        
        Only callable on jobs in "completed" state.
        Returns an Artifact with metadata and access to the trained model.
        """
        pass