"""
TrainingService: Main facade for training operations.

Provides a clean, high-level interface that hides the complexity of 
factories, registries, visitors, and container strategies. This is the
single class the IPC layer interacts with.
"""
from __future__ import annotations

import datetime
from typing import Dict, Any, Iterator, TYPE_CHECKING

from ..core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from ..core.exceptions import ValidationFailed
from ..factory.engine_factory import TrainingEngineFactory
from ..visitors.validator import ValidatorVisitor
from ..visitors.secret_scrubber import SecretScrubberVisitor
from ..visitors.telemetry import TelemetryVisitor
from ..pipeline.validation_chain import ValidationChain

if TYPE_CHECKING:
    from ..core.engine import JobHandle
    from ..core.events import ProgressEvent
    from ..core.host_caps import HostCapabilities  
    from ..core.artifact import ArtifactRepository
    from ..registry.engine_registry import EngineRegistry
    from ..events.event_bus import EventBus
    from ..runtime.container_strategy import ContainerStrategy


class TrainingService:
    """
    Facade for training engine operations.
    
    Coordinates job submission, validation, monitoring, and artifact management.
    Constructed per IPC server instance to allow dependency injection for testing.
    NOT a module-level singleton - allows clean testing with mocked dependencies.
    """

    def __init__(
        self,
        registry: EngineRegistry,
        factory: TrainingEngineFactory,
        event_bus: EventBus,
        validation_chain: ValidationChain,
        artifact_repo: ArtifactRepository,
        container_strategy: ContainerStrategy,
        host_capabilities: HostCapabilities,
    ):
        self.registry = registry
        self.factory = factory
        self.event_bus = event_bus
        self.validation_chain = validation_chain
        self.artifact_repo = artifact_repo
        self.container_strategy = container_strategy
        self.host_capabilities = host_capabilities
        self._active_jobs: Dict[str, JobHandle] = {}

    def submit_job(self, spec_dict: Dict[str, Any]) -> str:
        """
        Submit a new training job from dictionary specification.
        
        Validates the spec, selects an engine, and submits for execution.
        Returns the job ID for tracking progress.
        """
        # Parse spec dictionary into JobSpec
        spec = self._parse_job_spec(spec_dict)
        
        # Run validation chain (license → resource → secret → quota)
        validation_result = self.validation_chain.run(spec)
        if not validation_result.ok:
            raise ValidationFailed(
                f"Job validation failed: {'; '.join(validation_result.errors)}",
                validation_errors=validation_result.errors
            )
        
        # Apply telemetry visitor
        telemetry_visitor = TelemetryVisitor()
        spec.accept(telemetry_visitor)
        
        # Select and submit to engine
        engine = self.factory.select(spec, self.host_capabilities)
        handle = engine.submit(spec)
        
        self._active_jobs[spec.job_id] = handle
        return spec.job_id

    def get_status(self, job_id: str) -> Dict[str, Any]:
        """Get current status of a training job."""
        if job_id not in self._active_jobs:
            return {"error": f"Job {job_id} not found"}
            
        handle = self._active_jobs[job_id]
        engine = self.registry.get(handle.engine_name)
        if not engine:
            return {"error": f"Engine {handle.engine_name} not available"}
            
        status = engine.poll(handle)
        return {
            "job_id": job_id,
            "state": status.state,
            "progress_pct": status.progress_pct,
            "message": status.message,
            "error": status.error,
        }

    def stream_progress(self, job_id: str) -> Iterator[ProgressEvent]:
        """Stream progress events from a running job."""
        if job_id not in self._active_jobs:
            return
            
        handle = self._active_jobs[job_id]
        engine = self.registry.get(handle.engine_name)
        if not engine:
            return
            
        yield from engine.stream_events(handle)

    def cancel_job(self, job_id: str) -> bool:
        """Cancel a running job. Returns True if cancelled successfully."""
        if job_id not in self._active_jobs:
            return False
            
        handle = self._active_jobs[job_id]
        engine = self.registry.get(handle.engine_name)
        if not engine:
            return False
            
        engine.cancel(handle)
        del self._active_jobs[job_id]
        return True

    def list_jobs(self, filter_dict: Dict[str, Any] | None = None) -> list[Dict[str, Any]]:
        """List active jobs, optionally filtered."""
        jobs = []
        for job_id, handle in self._active_jobs.items():
            engine = self.registry.get(handle.engine_name)
            if engine:
                status = engine.poll(handle)
                job_info = {
                    "job_id": job_id,
                    "engine": handle.engine_name,
                    "state": status.state,
                    "progress_pct": status.progress_pct,
                }
                
                # Apply filters if provided
                if filter_dict:
                    if all(
                        job_info.get(k) == v for k, v in filter_dict.items()
                    ):
                        jobs.append(job_info)
                else:
                    jobs.append(job_info)
                    
        return jobs

    def _parse_job_spec(self, spec_dict: Dict[str, Any]) -> JobSpec:
        """Parse a job specification dictionary into a JobSpec instance."""
        # Parse resource request
        resource_dict = spec_dict.get("resource_request", {})
        resource_request = GpuRequest(
            min_vram_gb=resource_dict.get("min_vram_gb", 8),
            preferred_vram_gb=resource_dict.get("preferred_vram_gb"),
            gpu_count=resource_dict.get("gpu_count", 1),
            requires_cuda=resource_dict.get("requires_cuda", True),
            requires_mlx=resource_dict.get("requires_mlx", False),
            requires_rocm=resource_dict.get("requires_rocm", False),
        )
        
        # Parse output spec
        output_dict = spec_dict.get("output_spec", {})
        output_spec = OutputSpec(
            format=output_dict.get("format", "pytorch"),
            compression=output_dict.get("compression"),
            max_size_gb=output_dict.get("max_size_gb", 10.0),
            include_checkpoints=output_dict.get("include_checkpoints", True),
        )
        
        return JobSpec(
            job_id=spec_dict["job_id"],
            model_id=spec_dict["model_id"],
            method=TrainingMethod(spec_dict["method"]),
            dataset_uri=spec_dict["dataset_uri"],
            hyperparams=spec_dict.get("hyperparams", {}),
            resource_request=resource_request,
            output_spec=output_spec,
            license_tolerance=LicenseTolerance(spec_dict.get("license_tolerance", "permissive_only")),
            submitted_at=datetime.datetime.now(datetime.timezone.utc),
        )