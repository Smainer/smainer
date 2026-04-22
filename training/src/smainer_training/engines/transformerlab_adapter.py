"""
TransformerLab adapter for the Smainer training engine.

Wave 5 implementation - AGPL-3.0 licensed engine that MUST run in subprocess
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


class TransformerLabAdapter(TrainingEngine):
    """
    Training engine adapter for transformerlab/transformerlab.
    
    AGPL-3.0 license requires subprocess isolation - cannot import directly.
    Communicates via authenticated subprocess with bearer tokens.
    
    Focuses on research-oriented training with experiment tracking and visualization.
    """

    def __init__(self):
        self.isolation_strategy = SubprocessIsolationStrategy(
            max_cpu_percent=85.0,
            max_memory_gb=20.0,    # Higher for research workloads
            max_runtime_hours=72.0, # Very long for research experiments
        )
        self.active_handles: Dict[str, Any] = {}  # Maps job_id to container handle

    @property
    def name(self) -> str:
        return "transformerlab"

    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora", "full_ft", "dpo"}  # Research-focused methods

    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        """Check if TransformerLab can handle this job specification."""
        
        # CRITICAL: Only run if license tolerance allows AGPL subprocess
        if spec.license_tolerance == LicenseTolerance.PERMISSIVE_ONLY:
            return False  # Cannot run AGPL engine with permissive-only tolerance

        # Check method support
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        if method not in self.supported_methods:
            return False

        # Check GPU requirements
        if not host_caps.gpus:
            return False
        
        # TransformerLab supports CUDA primarily, with potential MLX support
        if spec.resource_request.requires_cuda and not host_caps.supports_cuda:
            return False
        if spec.resource_request.requires_mlx and not host_caps.supports_mlx:
            return False  # Limited MLX support
        if spec.resource_request.requires_rocm and not host_caps.supports_rocm:
            return False
            
        # Check VRAM requirements
        available_gpus = host_caps.gpus[:spec.resource_request.gpu_count]
        if len(available_gpus) < spec.resource_request.gpu_count:
            return False
            
        total_vram = sum(gpu.vram_free_gb for gpu in available_gpus)
        if total_vram < spec.resource_request.min_vram_gb:
            return False

        # Check that we have transformerlab vendor code
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "transformerlab"
        if not vendor_path.exists():
            return False

        return True

    def submit(self, spec: JobSpec) -> JobHandle:
        """Submit job to TransformerLab engine in isolated subprocess."""
        
        # SECURITY: Double-check license tolerance
        if spec.license_tolerance == LicenseTolerance.PERMISSIVE_ONLY:
            raise SecurityError("Cannot run AGPL engine with permissive-only license tolerance")

        # Generate unique handle
        handle = JobHandle(
            handle_id=f"transformerlab_{spec.job_id}_{uuid.uuid4().hex[:8]}",
            engine_name=self.name
        )

        # Create TransformerLab experiment configuration
        lab_config = self._create_lab_config(spec)

        # Launch in isolated subprocess
        container_handle = self.isolation_strategy.launch(
            engine_module="smainer_training.engines._transformerlab_subprocess_worker",
            env={
                "JOB_ID": spec.job_id,
                "CONFIG": json.dumps(lab_config),
                "SPEC": json.dumps(self._serialize_spec(spec)),
            },
            mounts={},  # Working directory isolation handles file access
            gpu_mask=self._get_gpu_mask(spec),
        )

        self.active_handles[handle.handle_id] = container_handle
        return handle

    def _create_lab_config(self, spec: JobSpec) -> Dict[str, Any]:
        """Create TransformerLab experiment configuration from JobSpec."""
        
        config = {
            # Experiment metadata
            "experiment_name": f"smainer_{spec.job_id}",
            "description": f"Training job {spec.job_id} via Smainer",
            "tags": ["smainer", spec.method.value],
            
            # Model configuration
            "model": {
                "name": spec.model_id,
                "type": "causal_lm",
                "trust_remote_code": spec.hyperparams.get("trust_remote_code", False),
            },
            
            # Dataset configuration
            "dataset": {
                "name": self._extract_dataset_name(spec.dataset_uri),
                "path": self._convert_dataset_path(spec.dataset_uri),
                "type": "completion",
                "preprocessing": {
                    "max_length": spec.hyperparams.get("max_seq_length", 2048),
                    "truncation": True,
                    "padding": "max_length",
                }
            },
            
            # Training configuration
            "training": {
                "method": self._get_training_method(spec.method),
                "parameters": self._get_training_parameters(spec),
                "optimization": {
                    "learning_rate": spec.hyperparams.get("learning_rate", 3e-4),
                    "optimizer": "adamw",
                    "lr_scheduler": spec.hyperparams.get("lr_scheduler", "cosine"),
                    "warmup_ratio": spec.hyperparams.get("warmup_ratio", 0.05),
                    "weight_decay": spec.hyperparams.get("weight_decay", 0.01),
                },
                "batch_config": {
                    "per_device_batch_size": spec.hyperparams.get("batch_size", 2),
                    "gradient_accumulation_steps": spec.hyperparams.get("gradient_accumulation", 4),
                    "dataloader_num_workers": 4,
                },
                "epoch_config": {
                    "num_epochs": spec.hyperparams.get("epochs", 3),
                    "max_steps": spec.hyperparams.get("max_steps"),
                    "eval_steps": spec.hyperparams.get("eval_steps", 100),
                    "save_steps": spec.hyperparams.get("save_steps", 500),
                    "logging_steps": spec.hyperparams.get("logging_steps", 10),
                }
            },
            
            # Hardware configuration
            "hardware": {
                "precision": "bf16" if spec.hyperparams.get("use_bf16", True) else "fp16",
                "gradient_checkpointing": True,
                "compile_mode": spec.hyperparams.get("compile_mode", "default"),
                "gpu_memory_fraction": spec.hyperparams.get("gpu_memory_fraction", 0.9),
            },
            
            # Output configuration
            "output": {
                "dir": f"./experiments/{spec.job_id}",
                "save_model": True,
                "save_checkpoints": spec.output_spec.include_checkpoints,
                "checkpoint_format": spec.output_spec.format,
                "compression": spec.output_spec.compression,
            },
            
            # Experiment tracking
            "tracking": {
                "log_metrics": True,
                "save_plots": True,
                "track_gradients": spec.hyperparams.get("track_gradients", False),
                "track_weights": spec.hyperparams.get("track_weights", False),
            }
        }
        
        return config

    def _extract_dataset_name(self, dataset_uri: str) -> str:
        """Extract human-readable dataset name from URI."""
        if dataset_uri.startswith("hf://"):
            return dataset_uri[5:].split("/")[-1]
        elif dataset_uri.startswith("file://"):
            return Path(dataset_uri[7:]).stem
        else:
            return Path(dataset_uri).stem

    def _convert_dataset_path(self, dataset_uri: str) -> str:
        """Convert dataset URI to TransformerLab-compatible path."""
        if dataset_uri.startswith("hf://"):
            return dataset_uri[5:]  # Remove hf:// prefix
        elif dataset_uri.startswith("file://"):
            return dataset_uri[7:]  # Remove file:// prefix
        else:
            return dataset_uri

    def _get_training_method(self, method: TrainingMethod) -> Dict[str, Any]:
        """Convert training method to TransformerLab format."""
        if method == TrainingMethod.LORA:
            return {
                "type": "peft",
                "peft_type": "lora",
                "config": {
                    "r": 8,
                    "alpha": 16,
                    "dropout": 0.1,
                    "bias": "none",
                    "task_type": "CAUSAL_LM"
                }
            }
        elif method == TrainingMethod.QLORA:
            return {
                "type": "peft",
                "peft_type": "lora", 
                "quantization": {
                    "load_in_4bit": True,
                    "bnb_4bit_compute_dtype": "bfloat16",
                    "bnb_4bit_quant_type": "nf4",
                    "bnb_4bit_use_double_quant": True,
                },
                "config": {
                    "r": 8,
                    "alpha": 16,
                    "dropout": 0.1,
                    "bias": "none",
                    "task_type": "CAUSAL_LM"
                }
            }
        elif method == TrainingMethod.FULL_FT:
            return {
                "type": "full_finetune",
                "config": {}
            }
        elif method == TrainingMethod.DPO:
            return {
                "type": "alignment",
                "alignment_type": "dpo",
                "config": {
                    "beta": 0.1,
                    "loss_type": "sigmoid",
                }
            }
        else:
            return {"type": "full_finetune", "config": {}}

    def _get_training_parameters(self, spec: JobSpec) -> Dict[str, Any]:
        """Extract training parameters specific to the method."""
        method_params = spec.hyperparams.copy()
        
        # Remove general parameters to avoid conflicts
        general_keys = {
            "learning_rate", "epochs", "batch_size", "max_steps",
            "gradient_accumulation", "warmup_ratio", "weight_decay",
            "logging_steps", "save_steps", "eval_steps", "lr_scheduler"
        }
        
        return {k: v for k, v in method_params.items() if k not in general_keys}

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
            },
            "output_spec": {
                "format": spec.output_spec.format,
                "include_checkpoints": spec.output_spec.include_checkpoints,
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
        """Stream progress events from TransformerLab training subprocess."""
        
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
                    extra_metrics=event_data.get("extra_metrics"),
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
                metadata={
                    **artifact_data["metadata"],
                    "experiment_tracking": True,
                    "research_features": True,
                }
            )
            
        except Exception as e:
            raise ValueError(f"Failed to produce artifact: {e}")


# Note: The _transformerlab_subprocess_worker module would be a separate file that:
# 1. Imports transformerlab directly (since it's in isolated subprocess)
# 2. Handles JSON communication with bearer token authentication  
# 3. Runs the actual TransformerLab experiment
# 4. Provides experiment tracking and visualization data
# 5. Scrubs any secrets from logs before sending back to main process
#
# This worker is not implemented in this wave but the interface is established.