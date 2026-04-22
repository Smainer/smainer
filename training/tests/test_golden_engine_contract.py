"""
GOLDEN TEST: Engine Contract Validation

This is the GOLDEN TEST that every TrainingEngine implementation must pass.
Any adapter PR MUST add their engine to this test and verify it passes.

The contract defines the stable interface that all engines must honor,
ensuring compatibility across different training libraries and versions.
"""
from __future__ import annotations

import datetime
from typing import Iterator, Union, Any
import pytest

from smainer_training.core.engine import TrainingEngine, JobHandle, JobStatus
from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.core.events import ProgressEvent
from smainer_training.core.artifact import Artifact


class FakeEngine(TrainingEngine):
    """
    Reference implementation that demonstrates the contract.
    
    This engine passes all contract tests and serves as a template
    for implementing real engine adapters. Future adapters MUST
    implement all the same behaviors demonstrated here.
    """
    
    def __init__(self):
        self.submitted_jobs: dict[str, JobSpec] = {}
        self.job_states: dict[str, str] = {}
        self.progress_counters: dict[str, int] = {}
    
    @property
    def name(self) -> str:
        return "fake_engine"
    
    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora", "full_ft", "dpo", "orpo"}
    
    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        # Check method support
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        if method not in self.supported_methods:
            return False
        
        # Check resource requirements
        if not host_caps.gpus:
            return False
            
        total_vram = sum(gpu.vram_free_gb for gpu in host_caps.gpus[:spec.resource_request.gpu_count])
        if total_vram < spec.resource_request.min_vram_gb:
            return False
            
        # Check GPU type requirements
        if spec.resource_request.requires_cuda and not host_caps.supports_cuda:
            return False
        if spec.resource_request.requires_mlx and not host_caps.supports_mlx:
            return False
        if spec.resource_request.requires_rocm and not host_caps.supports_rocm:
            return False
            
        return True
    
    def submit(self, spec: JobSpec) -> JobHandle:
        handle = JobHandle(handle_id=spec.job_id, engine_name=self.name)
        self.submitted_jobs[spec.job_id] = spec
        self.job_states[spec.job_id] = "queued"
        self.progress_counters[spec.job_id] = 0
        
        # Simulate immediate transition to running
        self.job_states[spec.job_id] = "running"
        
        return handle
    
    def poll(self, handle: JobHandle) -> JobStatus:
        job_id = handle.handle_id
        state = self.job_states.get(job_id, "unknown")
        
        if state == "unknown":
            return JobStatus(
                handle=handle,
                state="failed",
                error=f"Job {job_id} not found"
            )
        
        progress = min(100.0, (self.progress_counters.get(job_id, 0) / 10.0) * 100)
        
        return JobStatus(
            handle=handle,
            state=state,
            progress_pct=progress,
            message=f"Job {job_id} is {state}"
        )
    
    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        job_id = handle.handle_id
        if job_id not in self.submitted_jobs:
            return
            
        # Simulate progress events
        for step in range(1, 6):
            self.progress_counters[job_id] = step
            yield ProgressEvent(
                job_id=job_id,
                timestamp=datetime.datetime.now(datetime.timezone.utc),
                step=step,
                total_steps=10,
                loss=max(0.1, 2.0 - step * 0.3),  # Decreasing loss
                learning_rate=1e-4 * (0.95 ** step),  # Decaying LR
                throughput_tokens_per_sec=1000.0 + step * 100,
                gpu_utilization_pct=80.0 + step * 2,
                vram_used_gb=12.0 + step * 0.5
            )
        
        # Mark as completed after streaming
        if job_id in self.job_states:
            self.job_states[job_id] = "completed"
    
    def cancel(self, handle: JobHandle) -> None:
        job_id = handle.handle_id
        if job_id in self.job_states and self.job_states[job_id] not in ["completed", "failed"]:
            self.job_states[job_id] = "cancelled"
    
    def produce_artifact(self, handle: JobHandle) -> Artifact:
        job_id = handle.handle_id
        
        if job_id not in self.submitted_jobs:
            raise ValueError(f"Job {job_id} not found")
            
        if self.job_states.get(job_id) != "completed":
            raise ValueError(f"Job {job_id} not completed, cannot produce artifact")
            
        return Artifact(
            artifact_id=f"{job_id}_artifact",
            job_id=job_id,
            artifact_type="model",
            format="pytorch",
            size_bytes=1024 * 1024,  # 1MB
            checksum_sha256="fake_checksum_" + job_id,
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={
                "engine": self.name,
                "method": self.submitted_jobs[job_id].method.value,
                "model_id": self.submitted_jobs[job_id].model_id
            }
        )


def create_test_spec(job_id: str = "contract_test") -> JobSpec:
    """Create a standard test JobSpec for contract testing."""
    return JobSpec(
        job_id=job_id,
        model_id="microsoft/DialoGPT-small",
        method=TrainingMethod.LORA,
        dataset_uri="hf://squad",
        hyperparams={"learning_rate": 1e-4, "batch_size": 8},
        resource_request=GpuRequest(min_vram_gb=8, gpu_count=1, requires_cuda=True),
        output_spec=OutputSpec(format="pytorch", max_size_gb=2.0),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )


def create_test_host_caps() -> HostCapabilities:
    """Create standard test host capabilities."""
    return HostCapabilities(
        gpus=[
            GpuInfo(device_id=0, name="RTX 4090", vram_total_gb=24, vram_free_gb=20),
            GpuInfo(device_id=1, name="RTX 4090", vram_total_gb=24, vram_free_gb=18)
        ],
        total_vram_gb=48,
        cpu_count=16,
        available_disk_gb=1000,
        supports_cuda=True,
        supports_mlx=False,
        supports_rocm=False
    )


# List of all engines to test - ADD YOUR ENGINE HERE
ENGINES_TO_TEST = [
    FakeEngine,
    # Wave 2-5 engines (added by systems-engineer in MTG-W25-AGPL-01)
    lambda: __import__('smainer_training.engines.axolotl_adapter', fromlist=['AxolotlAdapter']).AxolotlAdapter(),
    lambda: __import__('smainer_training.engines.unsloth_adapter', fromlist=['UnslothAdapter']).UnslothAdapter(),
    lambda: __import__('smainer_training.engines.llama_factory_adapter', fromlist=['LlamaFactoryAdapter']).LlamaFactoryAdapter(),
    lambda: __import__('smainer_training.engines.transformerlab_adapter', fromlist=['TransformerLabAdapter']).TransformerLabAdapter(),
]


@pytest.fixture(params=ENGINES_TO_TEST)
def engine(request) -> TrainingEngine:
    """Parametrized fixture to test all engines against the contract."""
    return request.param()


class TestEngineContract:
    """
    Golden contract tests that every TrainingEngine must pass.
    
    These tests define the stable interface contract. Any breaking
    changes require approval from repository-architect + security-expert
    via Cross-Domain Alignment Meeting.
    """
    
    def test_engine_has_name(self, engine: TrainingEngine) -> None:
        """Contract: Engine must have a non-empty name."""
        assert isinstance(engine.name, str)
        assert len(engine.name.strip()) > 0
    
    def test_engine_has_supported_methods(self, engine: TrainingEngine) -> None:
        """Contract: Engine must declare supported training methods."""
        methods = engine.supported_methods
        assert isinstance(methods, set)
        assert len(methods) > 0
        
        # All methods must be valid TrainingMethod values
        valid_methods = {method.value for method in TrainingMethod}
        assert methods.issubset(valid_methods)
    
    def test_can_run_respects_method_support(self, engine: TrainingEngine) -> None:
        """Contract: can_run must return False for unsupported methods."""
        host_caps = create_test_host_caps()
        
        for method in TrainingMethod:
            spec = JobSpec(
                job_id="test",
                model_id="test/model",
                method=method,
                dataset_uri="hf://test",
                hyperparams={},
                resource_request=GpuRequest(min_vram_gb=1),  # Minimal requirements
                output_spec=OutputSpec(format="pytorch"),
                license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
                submitted_at=datetime.datetime.now(datetime.timezone.utc)
            )
            
            can_run = engine.can_run(spec, host_caps)
            
            if method.value in engine.supported_methods:
                # Might still return False due to other constraints, but should not
                # automatically reject supported methods with minimal requirements
                pass  # Allow either True or False
            else:
                # Must return False for unsupported methods
                assert can_run is False, f"Engine {engine.name} claims it can run unsupported method {method.value}"
    
    def test_can_run_respects_resource_limits(self, engine: TrainingEngine) -> None:
        """Contract: can_run must respect resource constraints.""" 
        # Insufficient VRAM
        insufficient_host = HostCapabilities(
            gpus=[GpuInfo(device_id=0, name="Low VRAM", vram_total_gb=2, vram_free_gb=1)],
            total_vram_gb=2,
            cpu_count=4,
            available_disk_gb=100,
            supports_cuda=True
        )
        
        high_vram_spec = JobSpec(
            job_id="test",
            model_id="test/model", 
            method=TrainingMethod(next(iter(engine.supported_methods))),  # Use supported method
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=50),  # Impossible requirement
            output_spec=OutputSpec(format="pytorch"),
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        
        # Should reject due to insufficient VRAM
        assert engine.can_run(high_vram_spec, insufficient_host) is False
    
    def test_submit_returns_valid_handle(self, engine: TrainingEngine) -> None:
        """Contract: submit must return valid JobHandle."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        # Only test if engine can run the job
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        
        assert isinstance(handle, JobHandle)
        assert handle.handle_id == spec.job_id
        assert handle.engine_name == engine.name
    
    def test_poll_returns_valid_status(self, engine: TrainingEngine) -> None:
        """Contract: poll must return valid JobStatus."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        status = engine.poll(handle)
        
        assert isinstance(status, JobStatus)
        assert status.handle == handle
        assert isinstance(status.state, str)
        assert len(status.state.strip()) > 0
        assert 0 <= status.progress_pct <= 100
    
    def test_stream_events_yields_progress_events(self, engine: TrainingEngine) -> None:
        """Contract: stream_events must yield ProgressEvent instances."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        
        # Collect first few events
        events = []
        event_stream = engine.stream_events(handle)
        
        for i, event in enumerate(event_stream):
            events.append(event)
            if i >= 2:  # Get at least 3 events
                break
        
        # Verify we got events and they're valid
        assert len(events) > 0
        
        for event in events:
            assert isinstance(event, ProgressEvent)
            assert event.job_id == spec.job_id
            assert isinstance(event.timestamp, datetime.datetime)
            assert isinstance(event.step, int)
            assert event.step > 0
    
    def test_cancel_changes_job_state(self, engine: TrainingEngine) -> None:
        """Contract: cancel should affect job state."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        
        # Job should initially be running or queued
        initial_status = engine.poll(handle)
        assert initial_status.state in ["queued", "running"]
        
        # Cancel the job
        engine.cancel(handle)
        
        # Status should reflect cancellation (might take a moment)
        cancelled_status = engine.poll(handle)
        assert cancelled_status.state in ["cancelled", "failed", "stopped"]
    
    def test_produce_artifact_requires_completion(self, engine: TrainingEngine) -> None:
        """Contract: produce_artifact only works on completed jobs."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        
        # Should fail on non-completed job
        initial_status = engine.poll(handle)
        if initial_status.state != "completed":
            with pytest.raises((ValueError, RuntimeError, Exception)):
                engine.produce_artifact(handle)
        
        # For FakeEngine, complete the job by streaming events
        if engine.name == "fake_engine":
            # Stream all events to completion  
            list(engine.stream_events(handle))
            
            # Now should be able to produce artifact
            artifact = engine.produce_artifact(handle)
            assert isinstance(artifact, Artifact)
            assert artifact.job_id == spec.job_id
            assert len(artifact.checksum_sha256) > 0
            assert artifact.size_bytes > 0
    
    def test_handle_immutability(self, engine: TrainingEngine) -> None:
        """Contract: JobHandle objects must be immutable."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        
        # Should not be able to modify handle
        with pytest.raises(AttributeError):
            handle.handle_id = "modified"  # type: ignore
        
        with pytest.raises(AttributeError):
            handle.engine_name = "modified"  # type: ignore
    
    def test_status_immutability(self, engine: TrainingEngine) -> None:
        """Contract: JobStatus objects must be immutable."""
        spec = create_test_spec()
        host_caps = create_test_host_caps()
        
        if not engine.can_run(spec, host_caps):
            pytest.skip(f"Engine {engine.name} cannot run test spec")
        
        handle = engine.submit(spec)
        status = engine.poll(handle)
        
        # Should not be able to modify status
        with pytest.raises(AttributeError):
            status.state = "modified"  # type: ignore
        
        with pytest.raises(AttributeError):
            status.progress_pct = 999.0  # type: ignore


def test_add_your_engine_here():
    """
    INSTRUCTIONS FOR ADAPTER IMPLEMENTERS:
    
    When you implement a new TrainingEngine adapter, you MUST:
    
    1. Add your adapter class to the ENGINES_TO_TEST list above
    2. Run this test file: `python -m pytest tests/test_golden_engine_contract.py -v`
    3. Ensure ALL tests pass for your adapter
    4. If any test fails, fix your adapter implementation (not the test!)
    5. Only submit PR when your adapter passes the full golden contract
    
    The contract tests are the canonical definition of TrainingEngine behavior.
    They may only be changed via Cross-Domain Alignment Meeting between
    repository-architect and security-expert.
    
    Example adapter registration:
    
    ```python
    from your_adapter_module import YourEngineAdapter
    
    ENGINES_TO_TEST = [
        FakeEngine,
        YourEngineAdapter,  # <-- Add your adapter here
        # ... other adapters
    ]
    ```
    
    Your adapter will then be tested against the full contract automatically.
    """
    # This test just documents the contract - actual testing happens in parametrized tests above
    assert len(ENGINES_TO_TEST) >= 1, "At least FakeEngine should be registered"
    
    # Verify FakeEngine passes (our reference implementation)
    fake_engine = FakeEngine()
    assert fake_engine.name == "fake_engine"
    assert len(fake_engine.supported_methods) > 0
    
    print(f"\n📋 GOLDEN CONTRACT TEST SUMMARY:")
    print(f"   • Total engines under test: {len(ENGINES_TO_TEST)}")
    print(f"   • Contract tests per engine: {len(TestEngineContract.__dict__) - 1}")  # Exclude __init__
    print(f"   • Add your adapter to ENGINES_TO_TEST list to validate!")
    print(f"   • All tests must pass before submitting adapter PR")
    
    # Future adapter implementers: add assertion here to verify your engine is in the list
    # assert YourEngineAdapter in ENGINES_TO_TEST, "Add your adapter to ENGINES_TO_TEST!"