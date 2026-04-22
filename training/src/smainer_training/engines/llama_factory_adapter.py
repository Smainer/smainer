"""
LLaMA-Factory adapter for the Smainer training engine.

Wave 4 implementation - Apache-2.0 licensed engine supporting comprehensive
training methods with excellent model coverage and optimization.
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


class LlamaFactoryAdapter(TrainingEngine):
    """
    Training engine adapter for hiyouga/LLaMA-Factory.
    
    Apache-2.0 license allows in-process execution, but we implement subprocess
    mode for consistency with AGPL engines and enhanced security isolation.
    
    Supports comprehensive training methods with excellent LLaMA model family support.
    """

    def __init__(self, subprocess_mode: bool = True):
        self.subprocess_mode = subprocess_mode
        self.active_jobs: Dict[str, subprocess.Popen[str]] = {}
        self.job_configs: Dict[str, Dict[str, Any]] = {}

    @property
    def name(self) -> str:
        return "llama_factory"

    @property
    def supported_methods(self) -> set[str]:
        return {"lora", "qlora", "full_ft", "dpo", "orpo"}  # Comprehensive method support

    def can_run(self, spec: JobSpec, host_caps: HostCapabilities) -> bool:
        """Check if LLaMA-Factory can handle this job specification."""
        
        # Check method support
        method = spec.method.value if hasattr(spec.method, 'value') else str(spec.method)
        if method not in self.supported_methods:
            return False

        # Check GPU requirements
        if not host_caps.gpus:
            return False
        
        # LLaMA-Factory supports CUDA and potentially ROCm
        if spec.resource_request.requires_cuda and not host_caps.supports_cuda:
            return False
        if spec.resource_request.requires_rocm and not host_caps.supports_rocm:
            return False
        if spec.resource_request.requires_mlx:
            return False  # No MLX support yet
            
        # Check VRAM requirements
        available_gpus = host_caps.gpus[:spec.resource_request.gpu_count]
        if len(available_gpus) < spec.resource_request.gpu_count:
            return False
            
        total_vram = sum(gpu.vram_free_gb for gpu in available_gpus)
        if total_vram < spec.resource_request.min_vram_gb:
            return False

        # Check that we have llama-factory vendor code
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "LLaMA-Factory"
        if not vendor_path.exists():
            return False

        return True

    def submit(self, spec: JobSpec) -> JobHandle:
        """Submit job to LLaMA-Factory engine."""
        
        # Generate unique handle
        handle = JobHandle(
            handle_id=f"llama_factory_{spec.job_id}_{uuid.uuid4().hex[:8]}",
            engine_name=self.name
        )

        # Create LLaMA-Factory configuration
        factory_config = self._create_factory_config(spec)
        self.job_configs[handle.handle_id] = factory_config

        if self.subprocess_mode:
            self._submit_subprocess(handle, factory_config, spec)
        else:
            self._submit_inprocess(handle, factory_config, spec)

        return handle

    def _create_factory_config(self, spec: JobSpec) -> Dict[str, Any]:
        """Create LLaMA-Factory configuration from JobSpec."""
        
        # Base training arguments
        config = {
            # Model configuration
            "model_name_or_path": spec.model_id,
            "template": self._detect_template(spec.model_id),
            
            # Dataset configuration  
            "dataset": self._convert_dataset_name(spec.dataset_uri),
            "dataset_dir": "./data",
            "cutoff_len": spec.hyperparams.get("max_seq_length", 2048),
            "preprocessing_num_workers": 4,
            
            # Training configuration
            "stage": self._get_training_stage(spec.method),
            "do_train": True,
            "finetuning_type": self._get_finetuning_type(spec.method),
            
            # Optimization
            "learning_rate": spec.hyperparams.get("learning_rate", 5e-5),
            "num_train_epochs": spec.hyperparams.get("epochs", 3),
            "max_steps": spec.hyperparams.get("max_steps", -1),
            "per_device_train_batch_size": spec.hyperparams.get("batch_size", 2),
            "gradient_accumulation_steps": spec.hyperparams.get("gradient_accumulation", 8),
            "lr_scheduler_type": spec.hyperparams.get("lr_scheduler", "cosine"),
            "warmup_ratio": spec.hyperparams.get("warmup_ratio", 0.1),
            "weight_decay": spec.hyperparams.get("weight_decay", 0.01),
            
            # Logging and saving
            "output_dir": f"./outputs/{spec.job_id}",
            "logging_steps": spec.hyperparams.get("logging_steps", 10),
            "save_steps": spec.hyperparams.get("save_steps", 500),
            "eval_steps": spec.hyperparams.get("eval_steps", 500) if spec.hyperparams.get("val_set_size") else None,
            "save_strategy": "steps",
            "evaluation_strategy": "steps" if spec.hyperparams.get("val_set_size") else "no",
            
            # Hardware optimization
            "bf16": True,
            "fp16": False,
            "tf32": True,
            "dataloader_pin_memory": False,
            "gradient_checkpointing": True,
            "ddp_find_unused_parameters": False,
            
            # Validation
            "val_size": spec.hyperparams.get("val_set_size", 0.1) if spec.hyperparams.get("val_set_size") else 0,
            "max_samples": spec.hyperparams.get("max_samples"),
        }

        # Add method-specific configuration
        if spec.method in [TrainingMethod.LORA, TrainingMethod.QLORA]:
            config.update({
                "lora_rank": spec.hyperparams.get("lora_r", 8),
                "lora_alpha": spec.hyperparams.get("lora_alpha", 16),
                "lora_dropout": spec.hyperparams.get("lora_dropout", 0.1),
                "lora_target": spec.hyperparams.get("lora_target", "all"),
            })
            
            if spec.method == TrainingMethod.QLORA:
                config.update({
                    "quantization_bit": 4,
                    "double_quantization": True,
                    "quantization_type": "nf4",
                })

        elif spec.method == TrainingMethod.DPO:
            config.update({
                "dpo_beta": spec.hyperparams.get("dpo_beta", 0.1),
                "dpo_loss_type": spec.hyperparams.get("dpo_loss_type", "sigmoid"),
                "dpo_ftx": spec.hyperparams.get("dpo_ftx", 0.0),
            })

        elif spec.method == TrainingMethod.ORPO:
            config.update({
                "orpo_alpha": spec.hyperparams.get("orpo_alpha", 0.5),
                "orpo_beta": spec.hyperparams.get("orpo_beta", 0.1),
            })

        return config

    def _detect_template(self, model_id: str) -> str:
        """Detect chat template for the model."""
        model_lower = model_id.lower()
        
        if "llama" in model_lower:
            return "llama2"
        elif "mistral" in model_lower or "mixtral" in model_lower:
            return "mistral"
        elif "qwen" in model_lower:
            return "qwen"
        elif "baichuan" in model_lower:
            return "baichuan2"
        elif "chatglm" in model_lower:
            return "chatglm3"
        else:
            return "default"

    def _convert_dataset_name(self, dataset_uri: str) -> str:
        """Convert dataset URI to LLaMA-Factory dataset name."""
        if dataset_uri.startswith("hf://"):
            dataset_name = dataset_uri[5:]  # Remove hf:// prefix
            # Convert to LLaMA-Factory dataset naming convention
            return dataset_name.replace("/", "_")
        elif dataset_uri.startswith("file://"):
            return "custom_data"
        else:
            return dataset_uri

    def _get_training_stage(self, method: TrainingMethod) -> str:
        """Get LLaMA-Factory training stage for method."""
        if method in [TrainingMethod.LORA, TrainingMethod.QLORA, TrainingMethod.FULL_FT]:
            return "sft"  # Supervised fine-tuning
        elif method == TrainingMethod.DPO:
            return "dpo"
        elif method == TrainingMethod.ORPO:
            return "orpo"
        else:
            return "sft"

    def _get_finetuning_type(self, method: TrainingMethod) -> str:
        """Get LLaMA-Factory finetuning type for method."""
        if method == TrainingMethod.LORA:
            return "lora"
        elif method == TrainingMethod.QLORA:
            return "qlora"
        elif method == TrainingMethod.FULL_FT:
            return "full"
        else:
            return "lora"  # Default for DPO/ORPO

    def _submit_subprocess(self, handle: JobHandle, config: Dict[str, Any], spec: JobSpec) -> None:
        """Submit job in subprocess mode for security isolation."""
        
        # Create working directory
        work_dir = Path(f"/tmp/llama_factory_job_{handle.handle_id}")
        work_dir.mkdir(parents=True, exist_ok=True)
        
        # Create data directory for datasets
        data_dir = work_dir / "data"
        data_dir.mkdir(exist_ok=True)
        
        # Write config file as JSON for CLI
        config_path = work_dir / "config.json"
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)

        # Build subprocess command
        vendor_path = Path(__file__).parent.parent.parent.parent / "vendors" / "LLaMA-Factory"
        cmd = [
            "python", "-m", "llamafactory.cli.train",
            str(config_path)
        ]

        # Environment variables
        env = {
            "CUDA_VISIBLE_DEVICES": self._get_gpu_mask(spec),
            "PYTHONPATH": f"{vendor_path}/src:{Path.cwd()}",
            "HF_HOME": str(work_dir / "hf_cache"),
            "TRANSFORMERS_CACHE": str(work_dir / "transformers_cache"),
            "HF_DATASETS_CACHE": str(work_dir / "datasets_cache"),
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
            raise SecurityError(f"Failed to launch LLaMA-Factory subprocess: {e}")

    def _submit_inprocess(self, handle: JobHandle, config: Dict[str, Any], spec: JobSpec) -> None:
        """Submit job in-process (not implemented in this wave)."""
        raise NotImplementedError("In-process mode not implemented in Wave 4")

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
        # In a real implementation, we'd parse training logs for step/epoch counts
        # For now, return a simple time-based estimate
        return min(60.0, (time.time() % 120) / 2)  # Placeholder

    def stream_events(self, handle: JobHandle) -> Iterator[ProgressEvent]:
        """Stream progress events from LLaMA-Factory training."""
        
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

                # Parse LLaMA-Factory log lines for metrics
                if "train_loss" in line or "{'loss':" in line:
                    try:
                        # Extract metrics from log line
                        metrics = self._parse_factory_metrics(line)
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

    def _parse_factory_metrics(self, log_line: str) -> Optional[Dict[str, float]]:
        """Parse training metrics from LLaMA-Factory log line."""
        try:
            import re
            
            # Extract various metrics patterns
            metrics = {}
            
            # Loss patterns
            loss_patterns = [
                r"train_loss['\"]?:\\s*([0-9.]+)",
                r"'loss':\\s*([0-9.]+)",
                r"\"loss\":\\s*([0-9.]+)"
            ]
            
            for pattern in loss_patterns:
                match = re.search(pattern, log_line)
                if match:
                    metrics["loss"] = float(match.group(1))
                    break
            
            # Learning rate pattern
            lr_match = re.search(r"learning_rate['\"]?:\\s*([0-9.e-]+)", log_line)
            if lr_match:
                metrics["learning_rate"] = float(lr_match.group(1))
                
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
                process.wait(timeout=15)
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
        output_dir = Path(config.get("output_dir", f"./outputs/{handle.handle_id.split('_')[2]}"))
        
        if not output_dir.exists():
            raise ValueError(f"Output directory {output_dir} not found")

        # Calculate artifact size
        total_size = sum(f.stat().st_size for f in output_dir.rglob('*') if f.is_file())
        
        # Generate checksum (simplified)
        import hashlib
        checksum = hashlib.sha256(f"{handle.handle_id}_{total_size}".encode()).hexdigest()

        return Artifact(
            artifact_id=f"{handle.handle_id}_model",
            job_id=handle.handle_id.split('_')[2],  # Extract original job_id
            artifact_type="model",
            format=config.get("output_format", "pytorch"),
            size_bytes=total_size,
            checksum_sha256=checksum,
            created_at=datetime.datetime.now(datetime.timezone.utc),
            metadata={
                "engine": self.name,
                "method": config.get("stage", "unknown"),
                "finetuning_type": config.get("finetuning_type", "unknown"),
                "base_model": config.get("model_name_or_path", "unknown"),
                "output_dir": str(output_dir),
            }
        )