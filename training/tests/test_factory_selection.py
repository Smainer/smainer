"""
Test engine factory selection logic.

Verifies that TrainingEngineFactory correctly selects engines based on
compatibility, license tolerance, and preference rules.
"""
from __future__ import annotations

import datetime
from typing import Iterator

import pytest

from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec  
from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.core.engine import TrainingEngine, JobHandle, JobStatus
from smainer_training.core.events import ProgressEvent
from smainer_training.core.artifact import Artifact
from smainer_training.core.exceptions import EngineUnavailable
from smainer_training.factory.engine_factory import TrainingEngineFactory
from smainer_training.registry.engine_registry import get_registry


class MockPermissiveEngine(TrainingEngine):
    """Mock engine with permissive license."""
    
    @property
    def name(self) -> str:
        return "mock_permissive"
        
    @property  
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora"}
        
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        return spec.method.value in self.supported_methods
        
    def submit(self, spec: JobSpec) -> JobHandle:
        return JobHandle(handle_id=spec.job_id, engine_name=self.name)
        
    def poll(self, handle: JobHandle) -> JobStatus:
        return JobStatus(handle=handle, state="running")
        
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        return iter([])
        
    def cancel(self, handle: JobHandle) -> None:
        pass
        
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        return Artifact(
            artifact_id=f"{handle.handle_id}_artifact",
            job_id=handle.handle_id,
            artifact_type="model",
            format="pytorch", 
            size_bytes=1024,
            checksum_sha256="abc123",
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={}
        )


class MockAGPLEngine(TrainingEngine):
    """Mock engine with AGPL license (future waves)."""
    
    @property
    def name(self) -> str:
        return "mock_agpl"
        
    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "full_ft"}
        
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        return spec.method.value in self.supported_methods
        
    def submit(self, spec: JobSpec) -> JobHandle:
        return JobHandle(handle_id=spec.job_id, engine_name=self.name)
        
    def poll(self, handle: JobHandle) -> JobStatus:
        return JobStatus(handle=handle, state="running")
        
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        return iter([])
        
    def cancel(self, handle: JobHandle) -> None:
        pass
        
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        return Artifact(
            artifact_id=f"{handle.handle_id}_artifact",
            job_id=handle.handle_id,
            artifact_type="model",
            format="pytorch",
            size_bytes=1024, 
            checksum_sha256="abc123",
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={}
        )


class MockIncompatibleEngine(TrainingEngine):
    """Mock engine that doesn't support the requested method."""
    
    @property
    def name(self) -> str:
        return "mock_incompatible"
        
    @property
    def supported_methods(self) -> set[str]:
        return {"dpo", "orpo"}  # Different methods
        
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        return False  # Never compatible
        
    def submit(self, spec: JobSpec) -> JobHandle:
        return JobHandle(handle_id=spec.job_id, engine_name=self.name)
        
    def poll(self, handle: JobHandle) -> JobStatus:
        return JobStatus(handle=handle, state="running")
        
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        return iter([])
        
    def cancel(self, handle: JobHandle) -> None:
        pass
        
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        return Artifact(
            artifact_id=f"{handle.handle_id}_artifact",
            job_id=handle.handle_id,
            artifact_type="model",
            format="pytorch",
            size_bytes=1024,
            checksum_sha256="abc123", 
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={}
        )


def setup_test_engines():
    """Register test engines in the registry.""" 
    registry = get_registry()
    registry._reset_for_tests()
    registry.register(MockPermissiveEngine)
    registry.register(MockAGPLEngine)
    registry.register(MockIncompatibleEngine)


def create_test_spec(
    method: TrainingMethod = TrainingMethod.LORA,
    license_tolerance: LicenseTolerance = LicenseTolerance.PERMISSIVE_ONLY
) -> JobSpec:
    """Create a test JobSpec."""
    return JobSpec(
        job_id="test_job",
        model_id="test_model",
        method=method,
        dataset_uri="hf://test/dataset",
        hyperparams={},
        resource_request=GpuRequest(min_vram_gb=8),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=license_tolerance,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )


def create_test_host_caps() -> HostCapabilities:
    """Create test host capabilities."""
    return HostCapabilities(
        gpus=[GpuInfo(device_id=0, name="RTX 4090", vram_total_gb=24, vram_free_gb=20)],
        total_vram_gb=24,
        cpu_count=16,
        available_disk_gb=1000,
        supports_cuda=True
    )


def test_factory_selects_compatible_engine():
    """Test that factory selects an engine that can handle the job."""
    setup_test_engines()
    
    factory = TrainingEngineFactory()
    spec = create_test_spec(method=TrainingMethod.LORA)
    host_caps = create_test_host_caps()
    
    engine = factory.select(spec, host_caps)
    assert engine.name == "mock_permissive"  # Should select compatible engine


def test_factory_rejects_incompatible_method():
    """Test that factory raises error when no engines support the method."""
    # Only register incompatible engine
    registry = get_registry()
    registry._reset_for_tests()
    registry.register(MockIncompatibleEngine)
    
    factory = TrainingEngineFactory()
    spec = create_test_spec(method=TrainingMethod.LORA)  # Incompatible method
    host_caps = create_test_host_caps()
    
    with pytest.raises(EngineUnavailable, match="No engines can handle"):
        factory.select(spec, host_caps)


def test_factory_respects_license_tolerance():
    """Test license filtering based on tolerance policy."""
    setup_test_engines()
    
    factory = TrainingEngineFactory()
    host_caps = create_test_host_caps()
    
    # Permissive only - should work with current engines (Wave 1 has no license checks yet)
    spec_permissive = create_test_spec(license_tolerance=LicenseTolerance.PERMISSIVE_ONLY)
    engine = factory.select(spec_permissive, host_caps)
    assert engine is not None  # Should succeed
    
    # Allow AGPL - should also work
    spec_agpl = create_test_spec(license_tolerance=LicenseTolerance.ALLOW_AGPL_SUBPROCESS)
    engine = factory.select(spec_agpl, host_caps) 
    assert engine is not None  # Should succeed


def test_factory_returns_first_compatible():
    """Test that factory returns first compatible engine (registry order).""" 
    setup_test_engines()
    
    factory = TrainingEngineFactory()
    spec = create_test_spec(method=TrainingMethod.LORA)
    host_caps = create_test_host_caps()
    
    engine = factory.select(spec, host_caps)
    # Should return first compatible engine in registration order
    assert engine.name == "mock_permissive"


def test_no_engines_registered():
    """Test behavior when no engines are registered."""
    registry = get_registry() 
    registry._reset_for_tests()  # Empty registry
    
    factory = TrainingEngineFactory()
    spec = create_test_spec()
    host_caps = create_test_host_caps()
    
    with pytest.raises(EngineUnavailable):
        factory.select(spec, host_caps)