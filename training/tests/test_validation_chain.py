"""
Test validation chain with Chain of Responsibility pattern.

Verifies that validation chain executes links in order and short-circuits
on first failure, implementing proper Chain of Responsibility semantics.
"""
from __future__ import annotations

import datetime

import pytest

from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.pipeline.validation_chain import (
    ValidationChain, ValidationLink, LicenseLink, ResourceLink, 
    SecretScrubLink, QuotaLink, ValidationContext
)
from smainer_training.visitors.base import Result


def create_valid_spec() -> JobSpec:
    """Create a valid JobSpec for testing."""
    return JobSpec(
        job_id="test_job",
        model_id="test_model",
        method=TrainingMethod.LORA,
        dataset_uri="hf://test/dataset",
        hyperparams={"learning_rate": 1e-4},
        resource_request=GpuRequest(min_vram_gb=8, gpu_count=1),
        output_spec=OutputSpec(format="pytorch", max_size_gb=5.0),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )


def create_invalid_spec() -> JobSpec:
    """Create an invalid JobSpec for testing failures."""
    return JobSpec(
        job_id="",  # Invalid: empty job_id
        model_id="",  # Invalid: empty model_id
        method=TrainingMethod.LORA,
        dataset_uri="",  # Invalid: empty dataset_uri
        hyperparams={},
        resource_request=GpuRequest(min_vram_gb=-1, gpu_count=0),  # Invalid: negative/zero values
        output_spec=OutputSpec(format="pytorch", max_size_gb=-1),  # Invalid: negative size
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )


class FailingLink(ValidationLink):
    """Test link that always fails."""
    
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        return Result(
            ok=False,
            errors=["Failing link error"],
            warnings=["Failing link warning"],
            output=context
        )


class PassingLink(ValidationLink):
    """Test link that always passes."""
    
    def __init__(self, next_link: ValidationLink | None = None, name: str = "passing"):
        super().__init__(next_link)
        self.name = name
        self.called = False
        
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        self.called = True
        
        # Continue to next link if successful
        if self.next_link:
            return self.next_link.handle(spec, context)
        else:
            return Result(
                ok=True,
                errors=[],
                warnings=[f"{self.name} executed"],
                output=context
            )


def test_validation_chain_success():
    """Test that validation chain passes with valid spec."""
    chain = ValidationChain()
    spec = create_valid_spec()
    
    result = chain.run(spec)
    
    assert result.ok is True
    assert len(result.errors) == 0
    # May have warnings from individual links
    assert result.output.original_spec == spec


def test_validation_chain_schema_failure():
    """Test that validation chain fails on schema validation."""
    chain = ValidationChain() 
    spec = create_invalid_spec()
    
    result = chain.run(spec)
    
    assert result.ok is False
    assert len(result.errors) > 0
    # Should fail on multiple schema issues
    expected_errors = ["job_id cannot be empty", "model_id cannot be empty", "dataset_uri cannot be empty"]
    for error in expected_errors:
        assert any(error in err for err in result.errors)


def test_chain_short_circuit():
    """Test that chain short-circuits on first failure."""
    # Create chain: Passing -> Failing -> Passing
    link3 = PassingLink(name="third")
    link2 = FailingLink(link3)
    link1 = PassingLink(link2, "first")
    
    spec = create_valid_spec()
    context = ValidationContext(original_spec=spec)
    
    result = link1.handle(spec, context)
    
    assert result.ok is False
    assert "Failing link error" in result.errors
    assert link1.called is True
    assert link3.called is False  # Should not reach third link


def test_chain_complete_execution():
    """Test that chain executes all links when no failures."""
    # Create chain: Passing -> Passing -> Passing
    link3 = PassingLink(name="third")
    link2 = PassingLink(link3, "second")
    link1 = PassingLink(link2, "first")
    
    spec = create_valid_spec()
    context = ValidationContext(original_spec=spec)
    
    result = link1.handle(spec, context)
    
    assert result.ok is True
    assert link1.called is True
    assert link2.called is True
    assert link3.called is True
    assert "third executed" in result.warnings


def test_license_link():
    """Test LicenseLink validation."""
    link = LicenseLink()
    spec = create_valid_spec()
    context = ValidationContext(original_spec=spec)
    
    result = link.handle(spec, context)
    
    assert result.ok is True
    assert len(result.errors) == 0


def test_resource_link():
    """Test ResourceLink validation."""
    link = ResourceLink()
    context = ValidationContext(original_spec=create_valid_spec())
    
    # Test valid resource requirements
    spec = create_valid_spec()
    result = link.handle(spec, context)
    assert result.ok is True
    
    # Test invalid resource requirements
    invalid_spec = JobSpec(
        job_id="test",
        model_id="test",
        method=TrainingMethod.LORA,
        dataset_uri="hf://test",
        hyperparams={},
        resource_request=GpuRequest(
            min_vram_gb=-5,  # Invalid: negative VRAM
            gpu_count=0,     # Invalid: zero GPUs
            requires_cuda=True,
            requires_mlx=True  # Invalid: conflicting GPU types
        ),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )
    
    result = link.handle(invalid_spec, context)
    assert result.ok is False
    assert "min_vram_gb must be positive" in result.errors
    assert "gpu_count must be positive" in result.errors
    assert "Cannot require multiple GPU types (CUDA, MLX, ROCm)" in result.errors


def test_secret_scrub_link():
    """Test SecretScrubLink functionality.""" 
    link = SecretScrubLink()
    
    # Create spec with secrets in dataset URI
    spec_with_secrets = JobSpec(
        job_id="test",
        model_id="test",
        method=TrainingMethod.LORA,
        dataset_uri="https://example.com/data?hf_token=hf_abcdef123456789012345678&key=secret",
        hyperparams={"api_key": "secret123"},
        resource_request=GpuRequest(min_vram_gb=8),
        output_spec=OutputSpec(format="pytorch"),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )
    
    context = ValidationContext(original_spec=spec_with_secrets)
    result = link.handle(spec_with_secrets, context)
    
    assert result.ok is True
    assert result.output.scrubbed_spec_dict is not None
    # Check that secrets were redacted in the scrubbed version
    scrubbed_uri = result.output.scrubbed_spec_dict["dataset_uri"]
    assert "HF_TOKEN_REDACTED" in scrubbed_uri


def test_quota_link():
    """Test QuotaLink validation."""
    link = QuotaLink()
    spec = create_valid_spec()
    context = ValidationContext(original_spec=spec)
    
    result = link.handle(spec, context)
    
    # Wave 1 quota link always passes
    assert result.ok is True


def test_default_validation_chain_order():
    """Test that default ValidationChain builds links in correct order.""" 
    chain = ValidationChain()
    
    # Verify the chain structure by checking types
    current = chain.head
    assert isinstance(current, LicenseLink)
    
    current = current.next_link
    assert isinstance(current, ResourceLink)
    
    current = current.next_link
    assert isinstance(current, SecretScrubLink)
    
    current = current.next_link
    assert isinstance(current, QuotaLink)
    
    assert current.next_link is None  # End of chain