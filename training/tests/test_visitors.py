"""
Test visitor pattern implementations.

Tests ValidatorVisitor, SecretScrubberVisitor, CostEstimatorVisitor,
and TelemetryVisitor functionality for JobSpec processing.
"""
from __future__ import annotations

import datetime
from unittest.mock import Mock

import pytest

from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.visitors.validator import ValidatorVisitor
from smainer_training.visitors.secret_scrubber import SecretScrubberVisitor
from smainer_training.visitors.cost_estimator import CostEstimatorVisitor
from smainer_training.visitors.telemetry import TelemetryVisitor
from smainer_training.events.event_bus import get_event_bus


def create_test_spec(
    job_id: str = "test_job",
    model_id: str = "test_model",
    dataset_uri: str = "hf://test/dataset",
    hyperparams: dict | None = None,
    min_vram_gb: int = 8
) -> JobSpec:
    """Create a test JobSpec with customizable fields."""
    return JobSpec(
        job_id=job_id,
        model_id=model_id,
        method=TrainingMethod.LORA,
        dataset_uri=dataset_uri,
        hyperparams=hyperparams or {},
        resource_request=GpuRequest(min_vram_gb=min_vram_gb, gpu_count=1),
        output_spec=OutputSpec(format="pytorch", max_size_gb=5.0),
        license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
        submitted_at=datetime.datetime.now(datetime.timezone.utc)
    )


class TestValidatorVisitor:
    """Test ValidatorVisitor functionality."""
    
    def test_valid_spec_passes(self):
        """Test that valid JobSpec passes validation."""
        spec = create_test_spec()
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        assert len(result.errors) == 0
        assert result.output is None
    
    def test_empty_fields_fail(self):
        """Test that empty required fields cause validation failure."""
        spec = create_test_spec(job_id="", model_id="", dataset_uri="")
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is False
        assert "job_id cannot be empty" in result.errors
        assert "model_id cannot be empty" in result.errors
        assert "dataset_uri cannot be empty" in result.errors
    
    def test_negative_resources_fail(self):
        """Test that negative resource values cause validation failure."""
        spec = JobSpec(
            job_id="test",
            model_id="test",
            method=TrainingMethod.LORA,
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=-1, gpu_count=0),  # Invalid values
            output_spec=OutputSpec(format="pytorch"),
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is False
        assert "min_vram_gb must be positive" in result.errors
        assert "gpu_count must be positive" in result.errors
    
    def test_hyperparameter_validation(self):
        """Test hyperparameter validation warnings."""
        spec = create_test_spec(hyperparams={
            "learning_rate": 10.0,  # Too high
            "batch_size": -5        # Invalid
        })
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is False  # batch_size error should fail
        assert "batch_size must be positive" in result.errors
        # learning_rate should generate warning (in production)
        
    def test_dataset_uri_warnings(self):
        """Test dataset URI format warnings."""
        spec = create_test_spec(dataset_uri="invalid_scheme://data")
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True  # Warnings don't fail validation
        assert any("scheme" in warning for warning in result.warnings)
    
    def test_output_spec_validation(self):
        """Test output specification validation."""
        spec = JobSpec(
            job_id="test",
            model_id="test",
            method=TrainingMethod.LORA,
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=8),
            output_spec=OutputSpec(format="pytorch", max_size_gb=-1),  # Invalid
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        visitor = ValidatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is False
        assert "output_spec.max_size_gb must be positive" in result.errors


class TestSecretScrubberVisitor:
    """Test SecretScrubberVisitor functionality."""
    
    def test_no_secrets_unchanged(self):
        """Test that specs without secrets are unchanged."""
        spec = create_test_spec()
        visitor = SecretScrubberVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        assert len(result.warnings) == 0
        scrubbed_dict = result.output
        assert scrubbed_dict["dataset_uri"] == spec.dataset_uri
    
    def test_hf_token_redacted(self):
        """Test that HuggingFace tokens are redacted."""
        spec = create_test_spec(dataset_uri="https://example.com/data?hf_token=hf_abcdef123456789012345678")
        visitor = SecretScrubberVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        assert "Dataset URI contains secrets" in " ".join(result.warnings)
        scrubbed_dict = result.output
        assert "HF_TOKEN_REDACTED" in scrubbed_dict["dataset_uri"]
        assert "hf_abcdef123456789012345678" not in scrubbed_dict["dataset_uri"]
    
    def test_hyperparameter_secrets(self):
        """Test that secrets in hyperparameters are redacted."""
        spec = create_test_spec(hyperparams={
            "learning_rate": 1e-4,
            "api_key": "secret123456789012345",
            "normal_param": "value"
        })
        visitor = SecretScrubberVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        scrubbed_dict = result.output
        
        # Normal params should be unchanged
        assert scrubbed_dict["hyperparams"]["learning_rate"] == 1e-4
        assert scrubbed_dict["hyperparams"]["normal_param"] == "value"
        
        # Secret should be redacted
        assert "API_KEY_REDACTED" in str(scrubbed_dict["hyperparams"])
    
    def test_aws_signature_redacted(self):
        """Test that AWS signatures are redacted."""
        spec = create_test_spec(
            dataset_uri="https://bucket.s3.amazonaws.com/data?X-Amz-Signature=abcd1234567890abcdef"
        )
        visitor = SecretScrubberVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        scrubbed_dict = result.output
        assert "AWS_SIGNATURE_REDACTED" in scrubbed_dict["dataset_uri"]
        assert "abcd1234567890abcdef" not in scrubbed_dict["dataset_uri"]
    
    def test_nested_dict_scrubbing(self):
        """Test that nested dictionaries are properly scrubbed."""
        spec = create_test_spec(hyperparams={
            "training": {
                "learning_rate": 1e-4,
                "auth": {
                    "api_key": "secret123456789012345"
                }
            }
        })
        visitor = SecretScrubberVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        scrubbed_dict = result.output
        # Check that nested secret was scrubbed
        auth_str = str(scrubbed_dict["hyperparams"]["training"]["auth"])
        assert "API_KEY_REDACTED" in auth_str


class TestCostEstimatorVisitor:
    """Test CostEstimatorVisitor functionality."""
    
    def test_basic_estimation(self):
        """Test basic cost estimation."""
        spec = create_test_spec(model_id="test-7b")
        visitor = CostEstimatorVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        estimate = result.output
        assert estimate.estimated_gpu_hours > 0
        assert estimate.estimated_storage_gb > 0
        assert estimate.confidence_level < 1.0  # Low confidence for Wave 1
    
    def test_model_size_affects_estimate(self):
        """Test that larger models get higher estimates."""
        spec_7b = create_test_spec(model_id="model-7b")
        spec_70b = create_test_spec(model_id="model-70b")
        visitor = CostEstimatorVisitor()
        
        result_7b = visitor.visit(spec_7b)
        result_70b = visitor.visit(spec_70b)
        
        assert result_7b.ok and result_70b.ok
        assert result_70b.output.estimated_gpu_hours > result_7b.output.estimated_gpu_hours
    
    def test_method_affects_estimate(self):
        """Test that training method affects estimates."""
        spec_lora = JobSpec(
            job_id="test",
            model_id="test-model",
            method=TrainingMethod.LORA,
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=8),
            output_spec=OutputSpec(format="pytorch"),
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        
        spec_full = JobSpec(
            job_id="test",
            model_id="test-model",
            method=TrainingMethod.FULL_FT,
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=8),
            output_spec=OutputSpec(format="pytorch"),
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        
        visitor = CostEstimatorVisitor()
        result_lora = visitor.visit(spec_lora)
        result_full = visitor.visit(spec_full)
        
        assert result_lora.ok and result_full.ok
        assert result_full.output.estimated_gpu_hours > result_lora.output.estimated_gpu_hours
    
    def test_gpu_count_multiplier(self):
        """Test that GPU count affects estimates."""
        spec_1gpu = create_test_spec()
        spec_4gpu = JobSpec(
            job_id="test",
            model_id="test-model",
            method=TrainingMethod.LORA,
            dataset_uri="hf://test",
            hyperparams={},
            resource_request=GpuRequest(min_vram_gb=8, gpu_count=4),
            output_spec=OutputSpec(format="pytorch"),
            license_tolerance=LicenseTolerance.PERMISSIVE_ONLY,
            submitted_at=datetime.datetime.now(datetime.timezone.utc)
        )
        
        visitor = CostEstimatorVisitor()
        result_1gpu = visitor.visit(spec_1gpu)
        result_4gpu = visitor.visit(spec_4gpu)
        
        assert result_1gpu.ok and result_4gpu.ok
        # GPU hours should scale with GPU count
        assert result_4gpu.output.estimated_gpu_hours == 4 * result_1gpu.output.estimated_gpu_hours


class TestTelemetryVisitor:
    """Test TelemetryVisitor functionality."""
    
    def test_emits_submission_event(self):
        """Test that telemetry visitor emits submission event.""" 
        # Reset event bus and capture events
        event_bus = get_event_bus()
        event_bus._reset_for_tests()
        
        captured_events = []
        def capture_event(event):
            captured_events.append(event)
        
        event_bus.subscribe("job.submitted", capture_event)
        
        spec = create_test_spec()
        visitor = TelemetryVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        assert len(captured_events) == 1
        
        event = captured_events[0]
        assert event.job_id == spec.job_id
        assert event.method == spec.method.value
        assert event.model_id == spec.model_id
        assert event.gpu_count == spec.resource_request.gpu_count
    
    def test_visitor_returns_none(self):
        """Test that telemetry visitor returns None output."""
        spec = create_test_spec()
        visitor = TelemetryVisitor()
        
        result = visitor.visit(spec)
        
        assert result.ok is True
        assert result.output is None
        assert len(result.errors) == 0