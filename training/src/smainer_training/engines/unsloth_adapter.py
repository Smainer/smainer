"""
Unsloth adapter for the Smainer training engine.

Wave 3 implementation - AGPL-3.0 licensed engine that MUST run in subprocess
isolation to comply with license boundary requirements.
"""
from __future__ import annotations

import datetime
import json
import os
import subprocess
import time
import uuid
from pathlib import Path
from typing import Iterator, Dict, Any, Optional

from ..core.engine import TrainingEngine, JobHandle, JobStatus
from ..core.job_spec import JobSpec, TrainingMethod, LicenseTolerance
from ..core.host_caps import HostCapabilities  
from ..core.events import ProgressEvent
from ..core.artifact import Artifact
from ..core.exceptions import ValidationFailed, SecurityError
from ..runtime.subprocess_isolation import SubprocessIsolationStrategy


class UnslothAdapter(TrainingEngine):
    """
    Training engine adapter for unslothai/unsloth.
    
    AGPL-3.0 license requires subprocess isolation - cannot import directly.
    Communicates via authenticated subprocess with bearer tokens.
    
    Specializes in fast LoRA/QLoRA training with memory optimization.
    """

    def __init__(self):
        self.isolation_strategy = SubprocessIsolationStrategy(
            max_cpu_percent=90.0,  # Unsloth can use more CPU for optimization
            max_memory_gb=16.0,    # Higher memory limit for model loading
            max_runtime_hours=48.0, # Longer for large model training
        )
        self.active_handles: Dict[str, Any] = {}  # Maps job_id to container handle

    @property
    def name(self) -> str:
        return "unsloth"

    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora"}  # Unsloth specializes in LoRA variants

    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        """Check if Unsloth can handle this job specification."""
        
        # CRITICAL: Only run if license tolerance allows AGPL subprocess
        if spec.license_tolerance == LicenseTolerance.PERMISSIVE_ONLY:
            return False  # Cannot run AGPL engine with permissive-only tolerance

        # Check method support
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        if method not in self.supported_methods:
            return False

        # Check GPU requirements - Unsloth needs CUDA
        if not host_caps.gpus or not host_caps.supports_cuda:
            return False
        
        if spec.resource_request.requires_mlx or spec.resource_request.requires_rocm:
            return False  # Unsloth is CUDA-only
            
        # Check VRAM requirements - Unsloth is memory-efficient but still needs sufficient VRAM
        available_gpus = host_caps.gpus[:spec.resource_request.gpu_count]
        if len(available_gpus) < spec.resource_request.gpu_count:
            return False
            
        total_vram = sum(gpu.vram_free_gb for gpu in available_gpus)
        if total_vram < spec.resource_request.min_vram_gb:
            return False

        # Check that we have unsloth vendor code
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "unsloth"
        if not vendor_path.exists():
            return False

        return True

    def submit(self, spec: JobSpec) -> JobHandle:
        """Submit job to Unsloth engine in isolated subprocess."""
        
        # SECURITY: Double-check license tolerance
        if spec.license_tolerance == LicenseTolerance.PERMISSIVE_ONLY:
            raise SecurityError("Cannot run AGPL engine with permissive-only license tolerance")

        # Generate unique handle
        handle = JobHandle(
            handle_id=f"unsloth_{spec.job_id}_{uuid.uuid4().hex[:8]}",
            engine_name=self.name
        )

        # Create Unsloth configuration
        unsloth_config = self._create_unsloth_config(spec)

        # Launch in isolated subprocess
        container_handle = self.isolation_strategy.launch(
            engine_module="smainer_training.engines._unsloth_subprocess_worker",
            env={
                "JOB_ID": spec.job_id,
                "CONFIG": json.dumps(unsloth_config),
                "SPEC": json.dumps(self._serialize_spec(spec)),
            },
            mounts={},  # Working directory isolation handles file access
            gpu_mask=self._get_gpu_mask(spec),
        )

        self.active_handles[handle.handle_id] = container_handle
        return handle

    def _create_unsloth_config(self, spec: JobSpec) -> Dict[str, Any]:
        """Create Unsloth configuration from JobSpec."""
        
        config = {
            "model_name": spec.model_id,
            "dataset_path": self._convert_dataset_path(spec.dataset_uri),
            
            # LoRA configuration
            "lora_r": spec.hyperparams.get("lora_r", 16),
            "lora_alpha": spec.hyperparams.get("lora_alpha", 32),
            "lora_dropout": spec.hyperparams.get("lora_dropout", 0.1),
            "target_modules": spec.hyperparams.get("target_modules", ["q_proj", "k_proj", "v_proj", "o_proj"]),
            
            # Training parameters
            "learning_rate": spec.hyperparams.get("learning_rate", 2e-4),
            "num_train_epochs": spec.hyperparams.get("epochs", 3),
            "max_steps": spec.hyperparams.get("max_steps"),
            "per_device_train_batch_size": spec.hyperparams.get("batch_size", 2),
            "gradient_accumulation_steps": spec.hyperparams.get("gradient_accumulation", 4),
            "warmup_steps": spec.hyperparams.get("warmup_steps", 10),
            "logging_steps": spec.hyperparams.get("logging_steps", 10),
            "save_steps": spec.hyperparams.get("save_steps", 100),
            
            # Unsloth optimizations
            "use_4bit": spec.method == TrainingMethod.QLORA,
            "use_gradient_checkpointing": True,
            "use_fast_tokenizer": True,
            "max_seq_length": spec.hyperparams.get("max_seq_length", 2048),
            
            # Output configuration
            "output_dir": f"./outputs/{spec.job_id}",
        }
        
        return config

    def _convert_dataset_path(self, dataset_uri: str) -> str:
        """Convert dataset URI to Unsloth-compatible path."""
        if dataset_uri.startswith("hf://"):
            return dataset_uri[5:]  # Remove hf:// prefix
        elif dataset_uri.startswith("file://"):
            return dataset_uri[7:]  # Remove file:// prefix
        else:
            return dataset_uri

    def _serialize_spec(self, spec: JobSpec) -> Dict[str, Any]:
        """Serialize JobSpec for subprocess transmission."""
        return {
            "job_id": spec.job_id,
            "model_id": spec.model_id,
            "method": spec.method.value,
            "dataset_uri": spec.dataset_uri,
            "hyperparams": spec.hyperparams,
            "resource_request": {
                "min_vram_gb": spec.resource_request.min_vram_gb,
                "gpu_count": spec.resource_request.gpu_count,
            }
        }

    def _get_gpu_mask(self, spec: JobSpec) -> str:
        """Get CUDA_VISIBLE_DEVICES mask for GPU allocation."""
        return ",".join(str(i) for i in range(spec.resource_request.gpu_count))

    def poll(self, handle: JobHandle) -> JobStatus:
        """Get current job status via subprocess communication."""
        
        if handle.handle_id not in self.active_handles:
            return JobStatus(
                handle=handle,
                state="failed", 
                error=f"Job {handle.handle_id} not found"
            )

        container_handle = self.active_handles[handle.handle_id]
        
        # Check if subprocess is still running
        if not self.isolation_strategy.is_running(container_handle):
            return JobStatus(
                handle=handle,
                state="failed",
                error="Subprocess terminated unexpectedly"
            )

        try:
            # Send status request to subprocess
            response = self.isolation_strategy.communicate(
                container_handle,
                {"command": "status", "job_id": handle.handle_id}
            )
            
            return JobStatus(
                handle=handle,
                state=response.get("state", "unknown"),
                progress_pct=response.get("progress_pct", 0.0),
                message=response.get("message"),
                error=response.get("error"),
            )
            
        except Exception as e:
            return JobStatus(
                handle=handle,
                state="failed",
                error=f"Failed to get status: {e}"
            )

    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        """Stream progress events from Unsloth training subprocess."""
        
        if handle.handle_id not in self.active_handles:
            return

        container_handle = self.active_handles[handle.handle_id]
        
        try:
            # Request event stream from subprocess
            response = self.isolation_strategy.communicate(
                container_handle,
                {"command": "stream_events", "job_id": handle.handle_id}
            )
            
            # Parse events from response
            events = response.get("events", [])
            for event_data in events:
                yield ProgressEvent(
                    job_id=handle.handle_id,
                    timestamp=datetime.datetime.fromisoformat(event_data["timestamp"]),
                    step=event_data["step"],
                    total_steps=event_data.get("total_steps"),
                    loss=event_data.get("loss"),
                    learning_rate=event_data.get("learning_rate"),
                    throughput_tokens_per_sec=event_data.get("throughput"),
                    gpu_utilization_pct=event_data.get("gpu_utilization"),
                )
                
        except Exception:
            # Stream error - subprocess may have died
            return

    def cancel(self, handle: JobHandle) -> None:
        """Cancel a running training job."""
        
        if handle.handle_id not in self.active_handles:
            return

        container_handle = self.active_handles[handle.handle_id]
        
        try:
            # Send cancel command to subprocess
            self.isolation_strategy.communicate(
                container_handle,
                {"command": "cancel", "job_id": handle.handle_id}
            )
        except Exception:
            pass  # Continue with forceful termination
        
        # Force stop subprocess
        self.isolation_strategy.stop(container_handle)
        
        # Clean up
        if handle.handle_id in self.active_handles:
            del self.active_handles[handle.handle_id]

    def produce_artifact(self, handle: JobHandle) -> Artifact:
        """Produce training artifact from completed job."""
        
        status = self.poll(handle)
        if status.state != "completed":
            raise ValueError(f"Job {handle.handle_id} not completed, cannot produce artifact")

        if handle.handle_id not in self.active_handles:
            raise ValueError(f"Job {handle.handle_id} handle not found")

        container_handle = self.active_handles[handle.handle_id]

        try:
            # Request artifact production from subprocess
            response = self.isolation_strategy.communicate(
                container_handle,
                {"command": "produce_artifact", "job_id": handle.handle_id}
            )
            
            artifact_data = response.get("artifact")
            if not artifact_data:
                raise ValueError("No artifact data returned from subprocess")

            return Artifact(
                artifact_id=artifact_data["artifact_id"],
                job_id=artifact_data["job_id"],
                artifact_type=artifact_data["artifact_type"],
                format=artifact_data["format"],
                size_bytes=artifact_data["size_bytes"],
                checksum_sha256=artifact_data["checksum_sha256"],
                created_at=datetime.datetime.fromisoformat(artifact_data["created_at"]),
                metadata=artifact_data["metadata"]
            )
            
        except Exception as e:
            raise ValueError(f"Failed to produce artifact: {e}")


# Note: The _unsloth_subprocess_worker module would be a separate file that:
# 1. Imports unsloth directly (since it's in isolated subprocess)
# 2. Handles JSON communication with bearer token authentication  
# 3. Runs the actual Unsloth training
# 4. Scrubs any secrets from logs before sending back to main process
#
# This worker is not implemented in this wave but the interface is established.