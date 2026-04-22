"""
Secret scrubbing visitor for safe logging of JobSpecs.

Creates redacted copies of JobSpecs with sensitive information (API tokens,
presigned URLs, credentials) replaced with safe placeholders for logging
and telemetry without exposing secrets.
"""
from __future__ import annotations

import re
from typing import TYPE_CHECKING, Any, Dict
import copy

from .base import JobSpecVisitor, Result

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


class SecretScrubberVisitor(JobSpecVisitor[Any]):
    """
    Creates safe-to-log versions of JobSpecs with secrets redacted.
    
    Identifies and replaces sensitive patterns in dataset URIs,
    hyperparameters, and other fields to prevent credential leakage
    in logs, telemetry, and debugging output.
    
    Critical for security - prevents accidental exposure of:
    - HuggingFace tokens
    - Presigned S3 URLs  
    - API keys and credentials
    - Private dataset access tokens
    """

    # Patterns for detecting secrets (case-insensitive)
    SECRET_PATTERNS = {
        "hf_token": re.compile(r"hf_[a-zA-Z0-9]{20,}", re.IGNORECASE),
        "aws_signature": re.compile(r"X-Amz-Signature=[a-f0-9]{64}", re.IGNORECASE),
        "aws_credential": re.compile(r"X-Amz-Credential=[^&\s]+", re.IGNORECASE), 
        "bearer_token": re.compile(r"Bearer\s+[a-zA-Z0-9._-]+", re.IGNORECASE),
        "api_key": re.compile(r"api[_-]?key[=:]\s*['\"]?[a-zA-Z0-9._-]{16,}['\"]?", re.IGNORECASE),
        "presigned_url_query": re.compile(r"[?&](signature|token|key|secret)=[^&\s]+", re.IGNORECASE)
    }

    def visit(self, spec: JobSpec) -> Result[Any]:
        """Create a redacted copy of JobSpec safe for logging."""
        warnings: list[str] = []
        
        # Create deep copy to avoid mutating original
        redacted_spec_dict = self._deep_copy_spec_as_dict(spec)
        
        # Scrub dataset URI
        original_uri = redacted_spec_dict["dataset_uri"]
        redacted_uri = self._scrub_string(original_uri)
        if redacted_uri != original_uri:
            warnings.append("Dataset URI contains secrets that were redacted")
            redacted_spec_dict["dataset_uri"] = redacted_uri
        
        # Scrub hyperparameters 
        redacted_spec_dict["hyperparams"] = self._scrub_dict(spec.hyperparams)
        if redacted_spec_dict["hyperparams"] != spec.hyperparams:
            warnings.append("Hyperparameters contain secrets that were redacted")

        return Result(
            ok=True,
            errors=[],
            warnings=warnings,
            output=redacted_spec_dict
        )

    def _deep_copy_spec_as_dict(self, spec: JobSpec) -> Dict[str, Any]:
        """Convert JobSpec to dict for safe manipulation."""
        return {
            "job_id": spec.job_id,
            "model_id": spec.model_id,
            "method": spec.method.value,
            "dataset_uri": spec.dataset_uri,
            "hyperparams": copy.deepcopy(spec.hyperparams),
            "resource_request": {
                "min_vram_gb": spec.resource_request.min_vram_gb,
                "preferred_vram_gb": spec.resource_request.preferred_vram_gb,
                "gpu_count": spec.resource_request.gpu_count,
                "requires_cuda": spec.resource_request.requires_cuda,
                "requires_mlx": spec.resource_request.requires_mlx,
                "requires_rocm": spec.resource_request.requires_rocm,
            },
            "output_spec": {
                "format": spec.output_spec.format,
                "compression": spec.output_spec.compression,
                "max_size_gb": spec.output_spec.max_size_gb,
                "include_checkpoints": spec.output_spec.include_checkpoints,
            },
            "license_tolerance": spec.license_tolerance.value,
            "submitted_at": spec.submitted_at.isoformat(),
        }

    def _scrub_string(self, value: str) -> str:
        """Scrub secrets from a string value."""
        scrubbed = value
        for pattern_name, pattern in self.SECRET_PATTERNS.items():
            scrubbed = pattern.sub(f"<{pattern_name.upper()}_REDACTED>", scrubbed)
        return scrubbed

    def _scrub_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively scrub secrets from a dictionary."""
        # Key names that indicate secrets
        SECRET_KEY_NAMES = {
            "api_key", "apikey", "secret", "token", "password", "private_key",
            "access_token", "auth_token", "bearer_token", "secret_key"
        }
        
        scrubbed = {}
        for key, value in data.items():
            # Check if key name indicates a secret
            if key.lower().replace("_", "").replace("-", "") in {name.replace("_", "").replace("-", "") for name in SECRET_KEY_NAMES}:
                if isinstance(value, str):
                    scrubbed[key] = f"<{key.upper()}_REDACTED>"
                else:
                    scrubbed[key] = value
            elif isinstance(value, str):
                scrubbed[key] = self._scrub_string(value)
            elif isinstance(value, dict):
                scrubbed[key] = self._scrub_dict(value)
            elif isinstance(value, list):
                scrubbed[key] = [
                    self._scrub_string(item) if isinstance(item, str) else item
                    for item in value
                ]
            else:
                scrubbed[key] = value
        return scrubbed