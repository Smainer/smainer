"""
Test TrainingEngine ABC enforcement.

Verifies that TrainingEngine cannot be instantiated directly and that
concrete subclasses must implement all abstract methods.
"""
from __future__ import annotations

import datetime
import pytest
from typing import Iterator

from smainer_training.core.engine import TrainingEngine, JobHandle, JobStatus
from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.core.events import ProgressEvent
from smainer_training.core.artifact import Artifact


def test_cannot_instantiate_abstract_engine():
    """Test that TrainingEngine ABC cannot be instantiated directly."""
    with pytest.raises(TypeError, match="Can't instantiate abstract class"):
        TrainingEngine()  # type: ignore


def test_incomplete_subclass_fails():
    """Test that subclass missing abstract methods cannot be instantiated."""
    
    class IncompleteEngine(TrainingEngine):
        """Engine missing most abstract methods."""
        
        @property
        def name(self) -> str:
            return "incomplete"
        
        # Missing all other abstract methods
    
    with pytest.raises(TypeError, match="Can't instantiate abstract class"):
        IncompleteEngine()  # type: ignore


def test_complete_subclass_works():
    """Test that complete implementation of all abstract methods works."""
    
    class CompleteEngine(TrainingEngine):
        """Complete engine implementation for testing."""
        
        @property
        def name(self) -> str:
            return "complete"
            
        @property
        def supported_methods(self) -> set[str]:
            return {"lora", "qlora"}
            
        def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
            return spec.method.value in self.supported_methods
            
        def submit(self, spec: JobSpec) -> JobHandle:
            return JobHandle(handle_id="test", engine_name=self.name)
            
        def poll(self, handle: JobHandle) -> JobStatus:
            return JobStatus(handle=handle, state="completed")
            
        def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
            yield ProgressEvent(
                job_id="test",
                timestamp=datetime.datetime.now(datetime.timezone.utc),
                step=1
            )
            
        def cancel(self, handle: JobHandle) -> None:
            pass
            
        def produce_artifact(self, handle: JobHandle) -> Artifact:
            return Artifact(
                artifact_id="test",
                job_id=handle.handle_id,
                artifact_type="model",
                format="pytorch",
                size_bytes=1024,
                checksum_sha256="abc123",
                created_at=datetime.datetime.now(datetime.timezone.utc),
                metadata={}
            )
    
    # Should be able to instantiate complete engine
    engine = CompleteEngine()
    assert engine.name == "complete"
    assert engine.supported_methods == {"lora", "qlora"}


def test_abstract_methods_defined():
    """Test that all expected abstract methods are defined."""
    # Get all abstract methods from TrainingEngine
    abstract_methods = TrainingEngine.__abstractmethods__
    
    expected_methods = {
        "name",  # property
        "supported_methods",  # property
        "can_run",
        "submit", 
        "poll",
        "stream_events",
        "cancel",
        "produce_artifact"
    }
    
    assert abstract_methods == expected_methods


def test_jobhandle_immutable():
    """Test that JobHandle is immutable."""
    handle = JobHandle(handle_id="test", engine_name="test_engine")
    
    # Should not be able to modify
    with pytest.raises(AttributeError):
        handle.handle_id = "modified"  # type: ignore
        
    with pytest.raises(AttributeError):
        handle.engine_name = "modified"  # type: ignore


def test_jobstatus_immutable():
    """Test that JobStatus is immutable."""
    handle = JobHandle(handle_id="test", engine_name="test_engine")
    status = JobStatus(handle=handle, state="running", progress_pct=50.0)
    
    # Should not be able to modify
    with pytest.raises(AttributeError):
        status.state = "completed"  # type: ignore
        
    with pytest.raises(AttributeError):
        status.progress_pct = 100.0  # type: ignore