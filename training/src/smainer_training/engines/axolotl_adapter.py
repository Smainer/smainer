"""
Axolotl adapter for the Smainer training engine.

Wave 2 implementation - Apache-2.0 licensed engine that can run in-process
but supports subprocess mode for consistency with AGPL engines.
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
from ..core.job_spec import JobSpec, TrainingMethod
from ..core.host_caps import HostCapabilities  
from ..core.events import ProgressEvent
from ..core.artifact import Artifact
from ..core.exceptions import ValidationFailed, SecurityError


class AxolotlAdapter(TrainingEngine):
    """
    Training engine adapter for OpenAccess-AI-Collective/axolotl.
    
    Apache-2.0 license allows in-process execution, but we implement
    subprocess mode for consistency with AGPL engines and security isolation.
    
    Supports: LoRA, QLoRA, full fine-tuning with wide model compatibility.
    """

    def __init__(self, subprocess_mode: bool = True):
        self.subprocess_mode = subprocess_mode
        self.active_jobs: Dict[str, subprocess.Popen[str]] = {}
        self.job_configs: Dict[str, Dict[str, Any]] = {}

    @property
    def name(self) -> str:
        return "axolotl"

    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora", "full_ft"}

    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        """Check if Axolotl can handle this job specification."""
        
        # Check method support
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        if method not in self.supported_methods:
            return False

        # Check GPU requirements
        if not host_caps.gpus:
            return False
        
        # Axolotl requires CUDA
        if spec.resource_request.requires_cuda and not host_caps.supports_cuda:
            return False
            
        # Check VRAM requirements
        available_gpus = host_caps.gpus[:spec.resource_request.gpu_count]
        if len(available_gpus) < spec.resource_request.gpu_count:
            return False
            
        total_vram = sum(gpu.vram_free_gb for gpu in available_gpus)
        if total_vram < spec.resource_request.min_vram_gb:
            return False

        # Check that we have axolotl vendor code
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "axolotl"
        if not vendor_path.exists():
            return False

        return True

    def submit(self, spec: JobSpec) -> JobHandle:
        """Submit job to Axolotl engine."""
        
        # Generate unique handle
        handle = JobHandle(
            handle_id=f"axolotl_{spec.job_id}_{uuid.uuid4().hex[:8]}",
            engine_name=self.name
        )

        # Create Axolotl configuration
        axolotl_config = self._create_axolotl_config(spec)
        self.job_configs[handle.handle_id] = axolotl_config

        if self.subprocess_mode:
            self._submit_subprocess(handle, axolotl_config, spec)
        else:
            self._submit_inprocess(handle, axolotl_config, spec)

        return handle

    def _create_axolotl_config(self, spec: JobSpec) -> Dict[str, Any]:
        """Create Axolotl configuration from JobSpec."""
        
        # Map our methods to Axolotl config
        method_config = {
            "lora": {
                "adapter": "lora",
                "lora_r": spec.hyperparams.get("lora_r", 8),
                "lora_alpha": spec.hyperparams.get("lora_alpha", 16),
                "lora_dropout": spec.hyperparams.get("lora_dropout", 0.1),
            },
            "qlora": {
                "adapter": "qlora", 
                "load_in_4bit": True,
                "bnb_4bit_compute_dtype": "bfloat16",
                "lora_r": spec.hyperparams.get("lora_r", 8),
                "lora_alpha": spec.hyperparams.get("lora_alpha", 16),
            },
            "full_ft": {
                "adapter": None,
                "load_in_8bit": False,
                "load_in_4bit": False,
            }
        }

        config = {
            "base_model": spec.model_id,
            "model_type": "AutoModelForCausalLM",
            "tokenizer_type": "AutoTokenizer",
            
            # Training method specific config
            **method_config[spec.method.value],
            
            # Dataset configuration
            "datasets": [{
                "path": self._convert_dataset_path(spec.dataset_uri),
                "type": "completion",  # Default type
            }],
            
            # Training hyperparameters
            "learning_rate": spec.hyperparams.get("learning_rate", 1e-4),
            "num_epochs": spec.hyperparams.get("epochs", 3),
            "max_steps": spec.hyperparams.get("max_steps"),
            "per_device_train_batch_size": spec.hyperparams.get("batch_size", 4),
            "gradient_accumulation_steps": spec.hyperparams.get("gradient_accumulation", 1),
            "warmup_steps": spec.hyperparams.get("warmup_steps", 100),
            "logging_steps": spec.hyperparams.get("logging_steps", 10),
            "save_steps": spec.hyperparams.get("save_steps", 500),
            "eval_steps": spec.hyperparams.get("eval_steps", 500),
            
            # Output configuration
            "output_dir": f"./outputs/{spec.job_id}",
            "save_model": True,
            "push_dataset_to_hub": False,
            "push_to_hub": False,
            
            # Hardware configuration
            "bf16": True,
            "fp16": False,
            "tf32": True,
            
            # Validation
            "val_set_size": spec.hyperparams.get("val_set_size", 0.1),
            "eval_table_size": spec.hyperparams.get("eval_table_size", 0),
            
            # Early stopping
            "early_stopping_patience": spec.hyperparams.get("early_stopping_patience", 3),
            
            # Memory optimization
            "gradient_checkpointing": True,
            "dataloader_pin_memory": False,
        }
        
        return config

    def _convert_dataset_path(self, dataset_uri: str) -> str:
        """Convert dataset URI to Axolotl-compatible path."""
        if dataset_uri.startswith("hf://"):
            return dataset_uri[5:]  # Remove hf:// prefix
        elif dataset_uri.startswith("file://"):
            return dataset_uri[7:]  # Remove file:// prefix
        else:
            return dataset_uri

    def _submit_subprocess(self, handle: JobHandle, config: Dict[str, Any], spec: JobSpec) -> None:
        """Submit job in subprocess mode for security isolation."""
        
        # Create working directory
        work_dir = Path(f"/tmp/axolotl_job_{handle.handle_id}")
        work_dir.mkdir(parents=True, exist_ok=True)
        
        # Write config file
        config_path = work_dir / "config.yaml"
        with open(config_path, 'w') as f:
            import yaml
            yaml.dump(config, f)

        # Build subprocess command
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "axolotl"
        cmd = [
            "python", "-m", "axolotl.cli.train",
            str(config_path),
            "--config-name", "config.yaml"
        ]

        # Environment variables
        env = {
            "CUDA_VISIBLE_DEVICES": self._get_gpu_mask(spec),
            "PYTHONPATH": f"{vendor_path}:{Path.cwd()}",
            "HF_HOME": str(work_dir / "hf_cache"),
            "TRANSFORMERS_CACHE": str(work_dir / "transformers_cache"),
        }

        try:
            process = subprocess.Popen(
                cmd,
                cwd=work_dir,
                env={**os.environ, **env},
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            self.active_jobs[handle.handle_id] = process
            
        except Exception as e:
            raise SecurityError(f"Failed to launch Axolotl subprocess: {e}")

    def _submit_inprocess(self, handle: JobHandle, config: Dict[str, Any], spec: JobSpec) -> None:
        """Submit job in-process (not implemented in this wave)."""
        raise NotImplementedError("In-process mode not implemented in Wave 2")

    def _get_gpu_mask(self, spec: JobSpec) -> str:
        """Get CUDA_VISIBLE_DEVICES mask for GPU allocation."""
        return ",".join(str(i) for i in range(spec.resource_request.gpu_count))

    def poll(self, handle: JobHandle) -> JobStatus:
        """Get current job status."""
        
        if handle.handle_id not in self.active_jobs:
            return JobStatus(
                handle=handle,
                state="failed", 
                error=f"Job {handle.handle_id} not found"
            )

        process = self.active_jobs[handle.handle_id]
        
        # Check if process is still running
        poll_result = process.poll()
        
        if poll_result is None:
            # Still running
            return JobStatus(
                handle=handle,
                state="running",
                progress_pct=self._estimate_progress(handle),
                message="Training in progress"
            )
        elif poll_result == 0:
            # Completed successfully
            return JobStatus(
                handle=handle,
                state="completed",
                progress_pct=100.0,
                message="Training completed successfully"
            )
        else:
            # Failed
            return JobStatus(
                handle=handle,
                state="failed",
                error=f"Training failed with exit code {poll_result}"
            )

    def _estimate_progress(self, handle: JobHandle) -> float:
        """Estimate job progress by parsing logs (simplified)."""
        # In a real implementation, we'd parse training logs for step counts
        # For now, return a simple time-based estimate
        return min(50.0, time.time() % 100)  # Placeholder

    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        """Stream progress events from Axolotl training."""
        
        if handle.handle_id not in self.active_jobs:
            return

        process = self.active_jobs[handle.handle_id]
        
        # Parse stdout for training events
        step = 0
        while process.poll() is None:
            try:
                line = process.stdout.readline()
                if not line:
                    time.sleep(0.1)
                    continue

                # Parse Axolotl log lines for metrics
                if "{'loss':" in line or '"loss":' in line:
                    try:
                        # Extract metrics from log line
                        metrics = self._parse_axolotl_metrics(line)
                        if metrics:
                            step += 1
                            yield ProgressEvent(
                                job_id=handle.handle_id,
                                timestamp=datetime.datetime.now(datetime.timezone.utc),
                                step=step,
                                loss=metrics.get("loss"),
                                learning_rate=metrics.get("learning_rate"),
                                throughput_tokens_per_sec=metrics.get("throughput"),
                                gpu_utilization_pct=metrics.get("gpu_utilization"),
                            )
                    except Exception:
                        # Skip malformed log lines
                        continue
                        
            except Exception:
                # Stream closed
                break

    def _parse_axolotl_metrics(self, log_line: str) -> Optional[Dict[str, float]]:
        """Parse training metrics from Axolotl log line."""
        try:
            # Look for JSON-like metrics in log line
            import re
            
            # Extract loss value
            loss_match = re.search(r"'loss':\\s*([0-9.]+)", log_line)
            learning_rate_match = re.search(r"'learning_rate':\\s*([0-9.e-]+)", log_line)
            
            metrics = {}
            if loss_match:
                metrics["loss"] = float(loss_match.group(1))
            if learning_rate_match:
                metrics["learning_rate"] = float(learning_rate_match.group(1))
                
            return metrics if metrics else None
            
        except Exception:
            return None

    def cancel(self, handle: JobHandle) -> None:
        """Cancel a running training job."""
        
        if handle.handle_id not in self.active_jobs:
            return

        process = self.active_jobs[handle.handle_id]
        
        try:
            # Graceful termination
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                # Force kill
                process.kill()
                process.wait()
        except Exception:
            pass
        finally:
            # Clean up
            if handle.handle_id in self.active_jobs:
                del self.active_jobs[handle.handle_id]

    def produce_artifact(self, handle: JobHandle) -> Artifact:
        """Produce training artifact from completed job."""
        
        status = self.poll(handle)
        if status.state != "completed":
            raise ValueError(f"Job {handle.handle_id} not completed, cannot produce artifact")

        # Find output directory
        config = self.job_configs.get(handle.handle_id, {})
        output_dir = Path(config.get("output_dir", f"./outputs/{handle.handle_id.split('_')[1]}"))
        
        if not output_dir.exists():
            raise ValueError(f"Output directory {output_dir} not found")

        # Calculate artifact size (simplified)
        total_size = sum(f.stat().st_size for f in output_dir.rglob('*') if f.is_file())
        
        # Generate checksum (simplified - would use actual file hash in production)
        import hashlib
        checksum = hashlib.sha256(f"{handle.handle_id}_{total_size}".encode()).hexdigest()

        return Artifact(
            artifact_id=f"{handle.handle_id}_model",
            job_id=handle.handle_id.split('_')[1],  # Extract original job_id
            artifact_type="model",
            format=config.get("output_format", "pytorch"),
            size_bytes=total_size,
            checksum_sha256=checksum,
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={
                "engine": self.name,
                "method": config.get("adapter", "unknown"),
                "base_model": config.get("base_model", "unknown"),
                "output_dir": str(output_dir),
            }
        )