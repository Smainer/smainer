"""
Test JobSpec immutability and visitor pattern dispatch.

Verifies that JobSpec instances are immutable value objects and
correctly dispatch to visitor operations via the accept method.
"""
from __future__ import annotations

import datetime
import pytest
from dataclasses import FrozenInstanceError

from smainer_training.core.job_spec import (
    JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
)
from smainer_training.visitors.base import JobSpecVisitor, Result


def test_jobspec_immutability():
    """Test that JobSpec instances are immutable."""
    spec = JobSpec(
        job_id="test_job",
        model_id="test_model", 
        method=TrainingMethod.LORA,
        dataset_uri="hf://test/dataset",
        hyperparams={"learning_rate": 1e-4},
        resource_request=GpuRequest(min_vram_gb=8),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )
    
    # Should not be able to modify fields
    with pytest.raises(FrozenInstanceError):
        spec.job_id = "modified"  # type: ignore
        
    with pytest.raises(FrozenInstanceError):
        spec.method = TrainingMethod.FULL_FT  # type: ignore


def test_nested_immutability():
    """Test that nested objects (GpuRequest, OutputSpec) are also immutable.""" 
    spec = JobSpec(
        job_id="test_job",
        model_id="test_model",
        method=TrainingMethod.LORA,
        dataset_uri="hf://test/dataset", 
        hyperparams={},
        resource_request=GpuRequest(min_vram_gb=8),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )
    
    # Should not be able to modify nested objects
    with pytest.raises(FrozenInstanceError):
        spec.resource_request.min_vram_gb = 16  # type: ignore
        
    with pytest.raises(FrozenInstanceError):
        spec.output_spec.format = "gguf"  # type: ignore


class MockVisitor(JobSpecVisitor[str]):
    """Mock visitor for testing accept dispatch."""
    
    def visit(self, spec: JobSpec) -> Result[str]:
        return Result(
            ok=True,
            errors=[],
            warnings=[],
            output=f"Visited job {spec.job_id}"
        )


def test_visitor_accept_dispatch():
    """Test that JobSpec.accept correctly dispatches to visitors.""" 
    spec = JobSpec(
        job_id="test_job",
        model_id="test_model",
        method=TrainingMethod.LORA,
        dataset_uri="hf://test/dataset",
        hyperparams={},
        resource_request=GpuRequest(min_vram_gb=8),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )
    
    visitor = MockVisitor()
    result = spec.accept(visitor)
    
    assert result.ok is True
    assert result.output == "Visited job test_job"
    assert result.errors == []
    assert result.warnings == []


def test_enum_values():
    """Test that enum values are properly defined."""
    # Test TrainingMethod enum
    assert TrainingMethod.LORA.value == "lora"
    assert TrainingMethod.QLORA.value == "qlora"
    assert TrainingMethod.FULL_FT.value == "full_ft"
    assert TrainingMethod.DPO.value == "dpo"
    assert TrainingMethod.ORPO.value == "orpo"
    
    # Test LicenseTolerance enum
    assert LicenseTolerance.PERMISSIVE_ONLY.value == "permissive_only"
    assert LicenseTolerance.ALLOW_AGPL_SUBPROCESS.value == "allow_agpl_subprocess"


def test_default_values():
    """Test that default values are properly set."""
    gpu_request = GpuRequest(min_vram_gb=8)
    assert gpu_request.preferred_vram_gb is None
    assert gpu_request.gpu_count == 1
    assert gpu_request.requires_cuda is True
    assert gpu_request.requires_mlx is False
    assert gpu_request.requires_rocm is False
    
    output_spec = OutputSpec(format="pytorch")
    assert output_spec.compression is None
    assert output_spec.max_size_gb == 10.0
    assert output_spec.include_checkpoints is True