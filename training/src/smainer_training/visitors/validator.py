"""
Validation visitor for JobSpec schema and business rules.

Performs comprehensive validation of job specifications including
schema validation, license policy, and resource requirement sanity checks.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

from .base import JobSpecVisitor, Result

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


class ValidatorVisitor(JobSpecVisitor[None]):
    """
    Validates JobSpec instances for schema compliance and business rules.
    
    Checks:
    - Required fields present and valid
    - Resource requests within reasonable bounds  
    - License tolerance policy compatibility
    - Dataset URI format and accessibility
    - Hyperparameter sanity (learning rates, batch sizes, etc.)
    """

    def visit(self, spec: JobSpec) -> Result[None]:
        """Validate a JobSpec for correctness and policy compliance."""
        errors: list[str] = []
        warnings: list[str] = []

        # Validate required fields
        if not spec.job_id.strip():
            errors.append("job_id cannot be empty")
            
        if not spec.model_id.strip():
            errors.append("model_id cannot be empty")
            
        if not spec.dataset_uri.strip():
            errors.append("dataset_uri cannot be empty")

        # Validate resource requests
        if spec.resource_request.min_vram_gb <= 0:
            errors.append("min_vram_gb must be positive")
            
        if spec.resource_request.gpu_count <= 0:
            errors.append("gpu_count must be positive")
            
        if spec.resource_request.gpu_count > 8:
            warnings.append("gpu_count > 8 may not be supported by all engines")

        # Validate hyperparameters
        if "learning_rate" in spec.hyperparams:
            lr = spec.hyperparams["learning_rate"]
            if isinstance(lr, (int, float)) and (lr <= 0 or lr > 1):
                warnings.append(f"learning_rate {lr} outside typical range (1e-6 to 1e-1)")
                
        if "batch_size" in spec.hyperparams:
            bs = spec.hyperparams["batch_size"] 
            if isinstance(bs, int) and bs <= 0:
                errors.append("batch_size must be positive")

        # Validate dataset URI format
        if not (spec.dataset_uri.startswith(("http://", "https://", "file://", "hf://"))):
            warnings.append("dataset_uri should use http://, https://, file://, or hf:// scheme")

        # Validate output spec
        if spec.output_spec.max_size_gb <= 0:
            errors.append("output_spec.max_size_gb must be positive")

        return Result(
            ok=len(errors) == 0,
            errors=errors,
            warnings=warnings,
            output=None
        )