"""
TrainingEngineFactory: Engine selection logic based on job specs and host capabilities.

Implements Factory + Strategy patterns to choose the best available engine
for a given training job. Selection rules prioritize license compatibility,
resource requirements, and engine capabilities.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

from ..core.exceptions import EngineUnavailable, LicenseViolation
from ..registry.engine_registry import get_registry

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec
    from ..core.host_caps import HostCapabilities
    from ..core.engine import TrainingEngine


class TrainingEngineFactory:
    """
    Factory for selecting training engines based on job requirements.
    
    Encapsulates engine selection logic to keep callers clean. Selection
    rules filter by compatibility, then prefer permissive licenses unless
    spec allows AGPL, then prefer fastest (future: telemetry-driven).
    """

    def select(self, spec: JobSpec, host_caps: HostCapabilities) -> TrainingEngine:
        """
        Select the best engine for the given job and host.
        
        Selection algorithm:
        1. Filter engines by can_run(spec, host_caps)
        2. Filter by license tolerance policy
        3. Prefer fastest engine (for now: registry order; later: telemetry)
        
        Raises:
            EngineUnavailable: No compatible engines found
            LicenseViolation: Only AGPL engines available but spec forbids them
        """
        registry = get_registry()
        available_engines = registry.all()
        
        # Filter by compatibility
        compatible_engines = [
            engine for engine in available_engines
            if engine.can_run(spec, host_caps)
        ]
        
        if not compatible_engines:
            raise EngineUnavailable(
                f"No engines can handle job {spec.job_id} with method {spec.method}",
                requested_method=spec.method
            )
        
        # Filter by license tolerance 
        license_filtered_engines = self._filter_by_license(compatible_engines, spec)
        
        if not license_filtered_engines:
            raise LicenseViolation(
                f"Job {spec.job_id} requires AGPL engines but license_tolerance is {spec.license_tolerance}"
            )
        
        # Select fastest (for now: first in registry order)
        # TODO: Use telemetry data to rank by actual performance
        return license_filtered_engines[0]

    def _filter_by_license(
        self, 
        engines: list[TrainingEngine], 
        spec: JobSpec
    ) -> list[TrainingEngine]:
        """Filter engines based on license tolerance policy."""
        
        # For Wave 1, we don't have actual engines to check licenses on
        # In later waves, this would check engine.license property
        # and filter AGPL engines unless spec.license_tolerance allows them
        
        if spec.license_tolerance.value == "permissive_only":
            # TODO: Filter out AGPL engines when they're added
            # return [e for e in engines if e.license not in ["AGPL-3.0", "AGPL-3.0+"]]
            pass
            
        return engines