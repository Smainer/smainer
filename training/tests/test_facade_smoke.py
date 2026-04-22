"""
TrainingService facade smoke test.

Tests round-trip job submission with fake implementations to verify
the facade correctly coordinates all subsystems without real engines.
"""
from __future__ import annotations

import datetime
from typing import Dict, Any, BinaryIO, Iterator, List, Tuple
from io import BytesIO

import pytest

from smainer_training.service.training_service import TrainingService
from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.core.engine import TrainingEngine, JobHandle, JobStatus
from smainer_training.core.events import ProgressEvent
from smainer_training.core.artifact import Artifact, ArtifactRepository
from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.runtime.container_strategy import ContainerStrategy, ContainerHandle
from smainer_training.registry.engine_registry import get_registry
from smainer_training.events.event_bus import get_event_bus
from smainer_training.factory.engine_factory import TrainingEngineFactory
from smainer_training.pipeline.validation_chain import ValidationChain


class FakeEngine(TrainingEngine):
    """Fake engine implementation for testing."""
    
    def __init__(self):
        self.submitted_jobs: Dict[str, JobSpec] = {}
        self.job_statuses: Dict[str, str] = {}
    
    @property
    def name(self) -> str:
        return "fake_engine"
    
    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora", "full_ft", "dpo", "orpo"}
    
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        return method in self.supported_methods
    
    def submit(self, spec: JobSpec) -> JobHandle:
        handle = JobHandle(handle_id=spec.job_id, engine_name=self.name)
        self.submitted_jobs[spec.job_id] = spec
        self.job_statuses[spec.job_id] = "running"
        return handle
    
    def poll(self, handle: JobHandle) -> JobStatus:
        state = self.job_statuses.get(handle.handle_id, "unknown")
        return JobStatus(
            handle=handle,
            state=state,
            progress_pct=50.0 if state == "running" else 100.0,
            message=f"Job {handle.handle_id} is {state}"
        )
    
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        # Yield a few fake progress events
        for step in range(1, 4):
            yield ProgressEvent(
                job_id=handle.handle_id,
                timestamp=datetime.datetime.now(datetime.timezone.utc),
                step=step,
                total_steps=10,
                loss=1.0 / step,  # Decreasing loss
                learning_rate=1e-4,
                throughput_tokens_per_sec=1000.0
            )
    
    def cancel(self, handle: JobHandle) -> None:
        if handle.handle_id in self.job_statuses:
            self.job_statuses[handle.handle_id] = "cancelled"
    
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        return Artifact(
            artifact_id=f"{handle.handle_id}_artifact",
            job_id=handle.handle_id,
            artifact_type="model",
            format="pytorch",
            size_bytes=1024,
            checksum_sha256="fake_checksum",
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={"fake": True}
        )


class InMemoryArtifactRepository(ArtifactRepository):
    """In-memory artifact repository for testing."""
    
    def __init__(self):
        self.artifacts: Dict[str, Artifact] = {}
        self.data: Dict[str, bytes] = {}
    
    def put(self, artifact: Artifact, data: BinaryIO) -> None:
        self.artifacts[artifact.artifact_id] = artifact
        self.data[artifact.artifact_id] = data.read()
    
    def get(self, artifact_id: str) -> Tuple[Artifact, BinaryIO]:
        artifact = self.artifacts[artifact_id]
        data = BytesIO(self.data[artifact_id])
        return artifact, data
    
    def exists(self, artifact_id: str) -> bool:
        return artifact_id in self.artifacts
    
    def delete(self, artifact_id: str) -> None:
        self.artifacts.pop(artifact_id, None)
        self.data.pop(artifact_id, None)
    
    def list_by_job(self, job_id: str) -> List[Artifact]:
        return [a for a in self.artifacts.values() if a.job_id == job_id]


class FakeContainerStrategy(ContainerStrategy):
    """Fake container strategy for testing."""
    
    @property
    def name(self) -> str:
        return "fake_container"
    
    def launch(
        self, 
        image: str, 
        env: Dict[str, str], 
        mounts: Dict[str, str],
        gpu_mask: str
    ) -> ContainerHandle:
        return ContainerHandle(
            container_id=f"fake_container_{image}",
            strategy_name=self.name
        )
    
    def stop(self, handle: ContainerHandle) -> None:
        pass
    
    def is_running(self, handle: ContainerHandle) -> bool:
        return True


def setup_training_service() -> TrainingService:
    """Set up a TrainingService with fake implementations."""
    # Reset singletons
    registry = get_registry()
    registry._reset_for_tests()
    
    event_bus = get_event_bus()
    event_bus._reset_for_tests()
    
    # Register fake engine
    registry.register(FakeEngine)
    
    # Create fake implementations
    factory = TrainingEngineFactory()
    validation_chain = ValidationChain()
    artifact_repo = InMemoryArtifactRepository()
    container_strategy = FakeContainerStrategy()
    
    host_capabilities = HostCapabilities(
        gpus=[GpuInfo(device_id=0, name="Fake GPU", vram_total_gb=24, vram_free_gb=20)],
        total_vram_gb=24,
        cpu_count=8,
        available_disk_gb=1000,
        supports_cuda=True
    )
    
    return TrainingService(
        registry=registry,
        factory=factory,
        event_bus=event_bus,
        validation_chain=validation_chain,
        artifact_repo=artifact_repo,
        container_strategy=container_strategy,
        host_capabilities=host_capabilities
    )


def test_submit_job_round_trip():
    """Test complete job submission round trip."""
    service = setup_training_service()
    
    # Create job spec dict
    spec_dict = {
        "job_id": "test_job_001",
        "model_id": "test/model",
        "method": "lora",
        "dataset_uri": "hf://test/dataset",
        "hyperparams": {"learning_rate": 1e-4},
        "resource_request": {
            "min_vram_gb": 8,
            "gpu_count": 1,
            "requires_cuda": True
        },
        "output_spec": {
            "format": "pytorch",
            "max_size_gb": 5.0
        },
        "license_tolerance": "permissive_only"
    }
    
    # Submit job
    job_id = service.submit_job(spec_dict)
    assert job_id == "test_job_001"
    
    # Check status
    status = service.get_status(job_id)
    assert status["job_id"] == job_id
    assert status["state"] == "running"
    assert status["progress_pct"] == 50.0
    
    # List jobs
    jobs = service.list_jobs()
    assert len(jobs) == 1
    assert jobs[0]["job_id"] == job_id
    assert jobs[0]["engine"] == "fake_engine"


def test_stream_progress():
    """Test progress event streaming."""
    service = setup_training_service()
    
    spec_dict = {
        "job_id": "streaming_job",
        "model_id": "test/model",
        "method": "lora",
        "dataset_uri": "hf://test/dataset",
        "hyperparams": {},
        "resource_request": {"min_vram_gb": 8}
    }
    
    job_id = service.submit_job(spec_dict)
    
    # Stream progress events
    events = list(service.stream_progress(job_id))
    
    assert len(events) == 3  # FakeEngine yields 3 events
    assert all(event.job_id == job_id for event in events)
    assert events[0].step == 1
    assert events[1].step == 2
    assert events[2].step == 3
    
    # Loss should decrease
    assert events[0].loss > events[1].loss > events[2].loss


def test_cancel_job():
    """Test job cancellation."""
    service = setup_training_service()
    
    spec_dict = {
        "job_id": "cancel_job",
        "model_id": "test/model",
        "method": "lora",
        "dataset_uri": "hf://test/dataset",
        "hyperparams": {},
        "resource_request": {"min_vram_gb": 8}
    }
    
    job_id = service.submit_job(spec_dict)
    
    # Cancel job
    success = service.cancel_job(job_id)
    assert success is True
    
    # Job should be removed from active jobs
    status = service.get_status(job_id)
    assert "error" in status  # Job not found


def test_validation_failure():
    """Test that validation failures are properly handled."""
    service = setup_training_service()
    
    # Invalid spec - missing required fields
    invalid_spec_dict = {
        "job_id": "",  # Invalid: empty
        "model_id": "",  # Invalid: empty
        "method": "lora",
        "dataset_uri": "",  # Invalid: empty
    }
    
    with pytest.raises(Exception):  # Should raise ValidationFailed
        service.submit_job(invalid_spec_dict)


def test_list_jobs_with_filter():
    """Test job listing with filters."""
    service = setup_training_service()
    
    # Submit multiple jobs
    for i in range(3):
        spec_dict = {
            "job_id": f"job_{i}",
            "model_id": f"model_{i}",
            "method": "lora",
            "dataset_uri": "hf://test/dataset",
            "hyperparams": {},
            "resource_request": {"min_vram_gb": 8}
        }
        service.submit_job(spec_dict)
    
    # List all jobs
    all_jobs = service.list_jobs()
    assert len(all_jobs) == 3
    
    # List with filter
    filtered_jobs = service.list_jobs({"engine": "fake_engine"})
    assert len(filtered_jobs) == 3  # All should match
    
    # Filter that matches nothing
    no_jobs = service.list_jobs({"engine": "nonexistent"})
    assert len(no_jobs) == 0


def test_nonexistent_job_operations():
    """Test operations on nonexistent jobs."""
    service = setup_training_service()
    
    # Status of nonexistent job
    status = service.get_status("nonexistent")
    assert "error" in status
    
    # Cancel nonexistent job
    success = service.cancel_job("nonexistent")
    assert success is False
    
    # Stream from nonexistent job
    events = list(service.stream_progress("nonexistent"))
    assert len(events) == 0