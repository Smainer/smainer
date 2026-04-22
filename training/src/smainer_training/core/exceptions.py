"""
Domain exceptions for training engine operations.

Defines the exception hierarchy for training-specific error conditions.
All training-related errors inherit from TrainingError base class.
"""
from __future__ import annotations


class TrainingError(Exception):
    """Base exception for all training-related errors."""
    
    def __init__(self, message: str, job_id: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.job_id = job_id


class EngineUnavailable(TrainingError):
    """Raised when no suitable training engine is available for a job."""
    
    def __init__(self, message: str, requested_method: str | None = None) -> None:
        super().__init__(message)
        self.requested_method = requested_method


class IncompatibleSpec(TrainingError):
    """Raised when a job spec is incompatible with available engines or host capabilities."""
    
    def __init__(self, message: str, spec_issues: list[str] | None = None) -> None:
        super().__init__(message)
        self.spec_issues = spec_issues or []


class LicenseViolation(TrainingError):
    """Raised when engine selection would violate license tolerance policy."""
    
    def __init__(self, message: str, engine_license: str | None = None) -> None:
        super().__init__(message)
        self.engine_license = engine_license


class ResourceExhausted(TrainingError):
    """Raised when insufficient resources are available for training."""
    
    def __init__(self, message: str, required_resources: dict | None = None) -> None:
        super().__init__(message)
        self.required_resources = required_resources or {}


class ValidationFailed(TrainingError):
    """Raised when job validation fails before execution."""
    
    def __init__(self, message: str, validation_errors: list[str] | None = None) -> None:
        super().__init__(message) 
        self.validation_errors = validation_errors or []


class SecurityError(TrainingError):
    """Raised when security constraints are violated."""
    
    def __init__(self, message: str, violation_type: str | None = None) -> None:
        super().__init__(message)
        self.violation_type = violation_type


class ValidationFailed(TrainingError):
    """Raised when job specification validation fails."""
    
    def __init__(self, message: str, validation_errors: list[str] | None = None) -> None:
        super().__init__(message)
        self.validation_errors = validation_errors or []