"""
Cost estimation visitor for training job resource consumption.

Estimates GPU-hours, storage requirements, and compute costs for training jobs
based on model size, method, dataset size, and resource requests.
"""
from __future__ import annotations

from typing import TYPE_CHECKING
from dataclasses import dataclass

from .base import JobSpecVisitor, Result

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


@dataclass(frozen=True)
class CostEstimate:
    """Estimated resource consumption for a training job."""
    estimated_gpu_hours: float
    estimated_storage_gb: float
    estimated_compute_cost_usd: float | None = None  # Future: pricing integration
    confidence_level: float = 0.5  # 0.0 to 1.0, how confident we are


class CostEstimatorVisitor(JobSpecVisitor[CostEstimate]):
    """
    Estimates resource costs for training jobs.
    
    Uses heuristics based on training method, model parameters,
    dataset size, and resource requests to predict GPU-hours
    and storage requirements. 
    
    Wave 1 implements basic stub formulas. Future waves will integrate
    telemetry data for improved accuracy.
    """

    def visit(self, spec: JobSpec) -> Result[CostEstimate]:
        """Estimate resource costs for a JobSpec."""
        warnings: list[str] = []
        
        # Stub cost estimation formulas for Wave 1
        # TODO: Replace with telemetry-driven models in later waves
        
        base_hours = self._estimate_base_hours(spec)
        gpu_multiplier = spec.resource_request.gpu_count
        method_multiplier = self._get_method_multiplier(spec.method.value)
        
        estimated_gpu_hours = base_hours * gpu_multiplier * method_multiplier
        estimated_storage_gb = self._estimate_storage_requirements(spec)
        
        # Add confidence warnings for stub estimates
        warnings.append("Cost estimates are preliminary - Wave 1 uses heuristic formulas")
        
        if spec.resource_request.gpu_count > 1:
            warnings.append("Multi-GPU cost estimation accuracy is limited")

        estimate = CostEstimate(
            estimated_gpu_hours=estimated_gpu_hours,
            estimated_storage_gb=estimated_storage_gb,
            estimated_compute_cost_usd=None,  # No pricing integration yet
            confidence_level=0.3  # Low confidence for stub estimates
        )

        return Result(
            ok=True,
            errors=[],
            warnings=warnings,
            output=estimate
        )

    def _estimate_base_hours(self, spec: JobSpec) -> float:
        """Estimate base training hours before multipliers."""
        # Stub: rough estimates based on model ID patterns
        model_id_lower = spec.model_id.lower()
        
        if "7b" in model_id_lower or "7-billion" in model_id_lower:
            return 2.0
        elif "13b" in model_id_lower or "13-billion" in model_id_lower:
            return 4.0
        elif "70b" in model_id_lower or "70-billion" in model_id_lower:
            return 16.0
        else:
            return 3.0  # Default for unknown models

    def _get_method_multiplier(self, method: str) -> float:
        """Get training time multiplier based on training method."""
        multipliers = {
            "lora": 0.3,      # LoRA is fastest
            "qlora": 0.4,     # QLoRA slightly slower
            "full_ft": 1.0,   # Full fine-tuning baseline
            "dpo": 0.8,       # DPO typically faster than full FT
            "orpo": 0.9,      # ORPO similar to DPO
        }
        return multipliers.get(method, 1.0)

    def _estimate_storage_requirements(self, spec: JobSpec) -> float:
        """Estimate storage requirements in GB."""
        # Base storage for checkpoints and logs
        base_storage = 2.0
        
        # Add storage based on method and output requirements
        if spec.method.value == "full_ft":
            base_storage += 10.0  # Full model checkpoints
        else:
            base_storage += 2.0   # LoRA adapters are smaller
            
        if spec.output_spec.include_checkpoints:
            base_storage *= 2  # Multiple checkpoints
            
        return min(base_storage, spec.output_spec.max_size_gb)