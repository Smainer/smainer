"""
Validation chain using Chain of Responsibility pattern.

Implements ordered validation pipeline where each link validates a specific
aspect of job specifications. First failure short-circuits the chain.
"""
from __future__ import annotations

import abc
from dataclasses import dataclass
from typing import TYPE_CHECKING, Dict, Any

from ..visitors.base import Result
from ..visitors.validator import ValidatorVisitor
from ..visitors.secret_scrubber import SecretScrubberVisitor

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


@dataclass(frozen=True)
class ValidationContext:
    """Context object passed through the validation chain."""
    original_spec: JobSpec
    scrubbed_spec_dict: Dict[str, Any] | None = None
    metadata: Dict[str, Any] | None = None


class ValidationLink(abc.ABC):
    """
    Abstract base class for validation chain links.
    
    Each link validates one aspect of a JobSpec and either passes
    control to the next link or fails with errors.
    """
    
    def __init__(self, next_link: ValidationLink | None = None):
        self.next_link = next_link
        
    @abc.abstractmethod
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        """
        Handle validation for this link.
        
        Returns a Result with success/failure and potentially modified context.
        If successful and next_link exists, calls next_link.handle().
        """
        pass


class LicenseLink(ValidationLink):
    """Validates license compatibility and tolerance policies."""
    
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        """Validate license tolerance settings."""
        errors: list[str] = []
        warnings: list[str] = []
        
        # Validate license tolerance enum value
        valid_tolerances = ["permissive_only", "allow_agpl_subprocess"]
        if spec.license_tolerance.value not in valid_tolerances:
            errors.append(f"Invalid license_tolerance: {spec.license_tolerance}")
            
        # For Wave 1, no specific engine license checks since no engines are registered
        # Future waves will check engine licenses against tolerance policy
        
        if errors:
            return Result(
                ok=False,
                errors=errors,
                warnings=warnings,
                output=context
            )
            
        # Continue to next link if successful
        if self.next_link:
            return self.next_link.handle(spec, context)
        else:
            return Result(ok=True, errors=[], warnings=warnings, output=context)


class ResourceLink(ValidationLink):
    """Validates resource requirements and availability."""
    
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        """Validate resource requirements are reasonable."""
        errors: list[str] = []
        warnings: list[str] = []
        
        # Validate GPU requirements
        req = spec.resource_request
        if req.min_vram_gb <= 0:
            errors.append("min_vram_gb must be positive")
            
        if req.gpu_count <= 0:
            errors.append("gpu_count must be positive")
            
        # Check for unreasonable requirements
        if req.min_vram_gb > 80:  # Current max GPU VRAM
            warnings.append(f"min_vram_gb {req.min_vram_gb} exceeds typical GPU capabilities")
            
        if req.gpu_count > 8:
            warnings.append(f"gpu_count {req.gpu_count} may not be supported")
            
        # Validate conflicting GPU requirements
        gpu_types = sum([req.requires_cuda, req.requires_mlx, req.requires_rocm])
        if gpu_types > 1:
            errors.append("Cannot require multiple GPU types (CUDA, MLX, ROCm)")
            
        if errors:
            return Result(
                ok=False,
                errors=errors,
                warnings=warnings,
                output=context
            )
            
        # Continue to next link
        if self.next_link:
            return self.next_link.handle(spec, context)
        else:
            return Result(ok=True, errors=[], warnings=warnings, output=context)


class SecretScrubLink(ValidationLink):
    """Scrubs secrets for safe logging and adds to context."""
    
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        """Scrub secrets and add safe version to context."""
        scrubber = SecretScrubberVisitor()
        scrub_result = scrubber.visit(spec)
        
        if not scrub_result.ok:
            return Result(
                ok=False,
                errors=scrub_result.errors,
                warnings=scrub_result.warnings,
                output=context
            )
            
        # Add scrubbed spec to context
        updated_context = ValidationContext(
            original_spec=context.original_spec,
            scrubbed_spec_dict=scrub_result.output,
            metadata=context.metadata
        )
        
        # Continue to next link
        if self.next_link:
            return self.next_link.handle(spec, updated_context)
        else:
            return Result(
                ok=True, 
                errors=[], 
                warnings=scrub_result.warnings, 
                output=updated_context
            )


class QuotaLink(ValidationLink):
    """Validates quota and rate limiting constraints."""
    
    def handle(self, spec: JobSpec, context: ValidationContext) -> Result[ValidationContext]:
        """Validate quota constraints."""
        errors: list[str] = []
        warnings: list[str] = []
        
        # Stub quota validation for Wave 1
        # Future waves will integrate with actual quota/billing system
        
        # Validate output size constraints
        if spec.output_spec.max_size_gb > 100:
            warnings.append(f"Large output size {spec.output_spec.max_size_gb}GB may hit quotas")
            
        # No quota violations for Wave 1 - all jobs allowed
        
        # Continue to next link or return success
        if self.next_link:
            return self.next_link.handle(spec, context)
        else:
            return Result(ok=True, errors=errors, warnings=warnings, output=context)


class ValidationChain:
    """
    Validation pipeline using Chain of Responsibility pattern.
    
    Builds and executes an ordered chain of validation links.
    First link failure short-circuits the entire chain.
    """
    
    def __init__(self):
        # Build default validation chain: License → Resource → Secret → Quota
        self.head = LicenseLink(
            ResourceLink(
                SecretScrubLink(
                    QuotaLink()
                )
            )
        )
        
    def run(self, spec: JobSpec) -> Result[ValidationContext]:
        """
        Run the complete validation chain on a JobSpec.
        
        Returns aggregate result with all errors, warnings, and context.
        Short-circuits on first validation failure.
        """
        # Also run basic validator for schema validation
        validator = ValidatorVisitor()
        schema_result = validator.visit(spec)
        
        if not schema_result.ok:
            context = ValidationContext(original_spec=spec)
            return Result(
                ok=False,
                errors=schema_result.errors,
                warnings=schema_result.warnings,
                output=context
            )
        
        # Run the validation chain
        context = ValidationContext(original_spec=spec)
        return self.head.handle(spec, context)