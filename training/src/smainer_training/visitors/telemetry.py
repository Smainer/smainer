"""
Telemetry visitor for job submission tracking.

Emits telemetry events when jobs are submitted for monitoring,
analytics, and performance optimization of the training system.
"""
from __future__ import annotations

from typing import TYPE_CHECKING
import datetime
from dataclasses import dataclass

from .base import JobSpecVisitor, Result
from ..events.event_bus import get_event_bus

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


@dataclass(frozen=True)
class SubmissionRecorded:
    """Event emitted when a training job is submitted."""
    job_id: str
    timestamp: datetime.datetime
    method: str
    model_id: str
    gpu_count: int
    estimated_duration_hours: float | None = None


class TelemetryVisitor(JobSpecVisitor[None]):
    """
    Emits telemetry events for job submissions.
    
    Records job submission events to the event bus for monitoring,
    analytics, and performance tracking. Helps optimize engine
    selection and resource allocation over time.
    """

    def visit(self, spec: JobSpec) -> Result[None]:
        """Record telemetry for a job submission."""
        
        # Emit submission event to event bus
        event = SubmissionRecorded(
            job_id=spec.job_id,
            timestamp=datetime.datetime.now(datetime.timezone.utc),
            method=spec.method.value,
            model_id=spec.model_id,
            gpu_count=spec.resource_request.gpu_count,
            estimated_duration_hours=None  # Could integrate with CostEstimatorVisitor
        )
        
        event_bus = get_event_bus()
        event_bus.publish("job.submitted", event)

        return Result(
            ok=True,
            errors=[],
            warnings=[],
            output=None
        )