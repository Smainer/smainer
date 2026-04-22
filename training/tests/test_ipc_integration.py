"""
IPC server integration tests.

Tests the Unix socket HTTP server with bearer token auth and complete
training service lifecycle through the actual IPC boundary.
"""
import json
import os
import socket
import tempfile
import threading
import time
import unittest
from unittest.mock import MagicMock

import requests_unixsocket

from smainer_training.runtime.ipc_server import UnixSocketIPCServer
from smainer_training.service.training_service import TrainingService
from smainer_training.core.job_spec import JobSpec, TrainingMethod, LicenseTolerance, GpuRequest, OutputSpec
from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.core.artifact import InMemoryArtifactRepository
from smainer_training.core.engine import TrainingEngine, JobHandle, JobStatus
from smainer_training.core.events import ProgressEvent
from smainer_training.events.event_bus import EventBus
from smainer_training.factory.engine_factory import TrainingEngineFactory
from smainer_training.registry.engine_registry import get_registry
from smainer_training.pipeline.validation_chain import ValidationChain
from smainer_training.runtime.container_strategy import ContainerStrategy, ContainerHandle


class MockEngine(TrainingEngine):
    """Mock engine for testing."""
    
    @property
    def name(self) -> str:
        return "mock_engine"
        
    @property
    def supported_methods(self) -> list[str]:
        return ["lora", "qlora"]
        
    def can_run(self, spec, host_caps) -> bool:
        return spec.method in self.supported_methods
        
    def submit(self, spec) -> JobHandle:
        return JobHandle(handle_id=f"handle_{spec.job_id}", engine_name=self.name)
        
    def poll(self, handle) -> JobStatus:
        return JobStatus(
            handle=handle,
            state="running",
            progress_pct=50.0,
            message="Training in progress"
        )
        
    def stream_events(self, handle):
        # Yield a couple of mock events
        import datetime
        yield ProgressEvent(
            job_id=handle.handle_id,
            timestamp=datetime.datetime.now(datetime.timezone.utc),
            step=100,
            total_steps=1000,
            loss=0.5,
            learning_rate=1e-4,
            throughput_tokens_per_sec=1200,
            gpu_utilization_pct=85.0,
            vram_used_gb=12.5
        )
        
    def cancel(self, handle) -> None:
        pass
        
    def produce_artifact(self, handle):
        return None


class MockContainerStrategy(ContainerStrategy):
    """Mock container strategy for testing."""
    
    @property
    def name(self) -> str:
        return "mock_strategy"
        
    def launch(self, image, env, mounts, gpu_mask) -> ContainerHandle:
        return ContainerHandle(
            container_id="mock_container_123",
            strategy_name=self.name,
            pid=12345
        )
        
    def stop(self, handle) -> None:
        pass
        
    def is_running(self, handle) -> bool:
        return True


class TestIPCIntegration(unittest.TestCase):
    """Integration tests for Unix socket IPC server."""
    
    def setUp(self):
        """Set up test environment."""
        # Create temporary socket path
        self.temp_dir = tempfile.mkdtemp()
        self.socket_path = os.path.join(self.temp_dir, "training.sock")
        
        # Set up test bearer token
        self.test_bearer_token = "test-bearer-token-2026-secure-random"
        
        # Set up mock training service
        self.event_bus = EventBus()
        self.registry = get_registry()
        
        # Clear registry and register mock engine
        self.registry._reset_for_tests()
        self.registry.register(MockEngine)
        
        self.factory = TrainingEngineFactory()
        self.validation_chain = ValidationChain()
        self.artifact_repo = InMemoryArtifactRepository()
        self.container_strategy = MockContainerStrategy()
        
        # Create mock GPU info
        gpu_info = GpuInfo(
            device_id=0,
            name="Mock GPU",
            vram_total_gb=24.0,
            vram_free_gb=20.0,
            compute_capability="8.6",
            vendor="nvidia"
        )
        
        self.host_caps = HostCapabilities(
            gpus=[gpu_info],
            total_vram_gb=24.0,
            cpu_count=8,
            available_disk_gb=1000.0,
            supports_cuda=True,
            supports_mlx=False,
            supports_rocm=False,
            max_concurrent_jobs=2
        )
        
        self.training_service = TrainingService(
            registry=self.registry,
            factory=self.factory,
            event_bus=self.event_bus,
            validation_chain=self.validation_chain,
            artifact_repo=self.artifact_repo,
            container_strategy=self.container_strategy,
            host_capabilities=self.host_caps
        )
        
        # Start IPC server with test bearer token
        self.ipc_server = UnixSocketIPCServer(
            self.socket_path, 
            self.training_service,
            bearer_token=self.test_bearer_token
        )
        self.ipc_server.start()
        time.sleep(0.1)  # Give server time to start
        
        # Set up HTTP session for Unix socket
        self.session = requests_unixsocket.Session()
        self.base_url = f"http+unix://{self.socket_path.replace('/', '%2F')}"
        
    def tearDown(self):
        """Clean up test environment."""
        self.ipc_server.stop()
        
        # Clean up temp directory
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
        
        # Reset registry
        self.registry._reset_for_tests()
        
    def test_auth_required(self):
        """Test that bearer token authentication is enforced."""
        response = self.session.post(f"{self.base_url}/jobs", json={})
        self.assertEqual(response.status_code, 401)
        self.assertIn("Authentication required", response.json()["error"])
        
    def test_submit_job_success(self):
        """Test successful job submission."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        job_spec = {
            "job_id": "test_job_001",
            "model_id": "microsoft/DialoGPT-medium",
            "method": "lora",
            "dataset_uri": "hf://dataset/alpaca-cleaned",
            "hyperparams": {"learning_rate": 1e-4},
            "resource_request": {
                "min_vram_gb": 8,
                "gpu_count": 1
            },
            "output_spec": {
                "format": "pytorch"
            }
        }
        
        response = self.session.post(f"{self.base_url}/jobs", json=job_spec, headers=headers)
        self.assertEqual(response.status_code, 201)
        
        result = response.json()
        self.assertEqual(result["job_id"], "test_job_001")
        
    def test_get_job_status(self):
        """Test job status endpoint."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        # Submit a job first
        job_spec = {
            "job_id": "test_job_002",
            "model_id": "microsoft/DialoGPT-medium",
            "method": "lora",
            "dataset_uri": "hf://dataset/alpaca-cleaned",
            "hyperparams": {"learning_rate": 1e-4}
        }
        
        submit_response = self.session.post(f"{self.base_url}/jobs", json=job_spec, headers=headers)
        self.assertEqual(submit_response.status_code, 201)
        
        # Get job status
        response = self.session.get(f"{self.base_url}/jobs/test_job_002", headers=headers)
        self.assertEqual(response.status_code, 200)
        
        status = response.json()
        self.assertEqual(status["job_id"], "test_job_002")
        self.assertEqual(status["state"], "running")
        self.assertEqual(status["progress_pct"], 50.0)
        
    def test_list_jobs(self):
        """Test list jobs endpoint."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        # Submit a couple of jobs
        for i in range(2):
            job_spec = {
                "job_id": f"test_job_00{i+3}",
                "model_id": "microsoft/DialoGPT-medium", 
                "method": "lora",
                "dataset_uri": "hf://dataset/alpaca-cleaned"
            }
            response = self.session.post(f"{self.base_url}/jobs", json=job_spec, headers=headers)
            self.assertEqual(response.status_code, 201)
            
        # List jobs
        response = self.session.get(f"{self.base_url}/jobs", headers=headers)
        self.assertEqual(response.status_code, 200)
        
        result = response.json()
        jobs = result["jobs"]
        self.assertGreaterEqual(len(jobs), 2)
        
    def test_cancel_job(self):
        """Test job cancellation."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        # Submit a job first
        job_spec = {
            "job_id": "test_job_004", 
            "model_id": "microsoft/DialoGPT-medium",
            "method": "lora",
            "dataset_uri": "hf://dataset/alpaca-cleaned"
        }
        
        submit_response = self.session.post(f"{self.base_url}/jobs", json=job_spec, headers=headers)
        self.assertEqual(submit_response.status_code, 201)
        
        # Cancel job
        response = self.session.delete(f"{self.base_url}/jobs/test_job_004", headers=headers)
        self.assertEqual(response.status_code, 200)
        
        result = response.json()
        self.assertTrue(result["cancelled"])
        
    def test_cancel_nonexistent_job(self):
        """Test cancelling a non-existent job."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        response = self.session.delete(f"{self.base_url}/jobs/nonexistent", headers=headers)
        self.assertEqual(response.status_code, 404)
        self.assertIn("Job not found", response.json()["error"])
        
    def test_invalid_job_spec(self):
        """Test submitting invalid job specification."""
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        # Missing required fields
        invalid_spec = {
            "job_id": "",  # Invalid: empty job_id
            "method": "lora"
        }
        
        response = self.session.post(f"{self.base_url}/jobs", json=invalid_spec, headers=headers)
        self.assertEqual(response.status_code, 500)  # Validation error should bubble up
        
    def test_malformed_json(self):
        """Test handling of malformed JSON requests.""" 
        headers = {"Authorization": f"Bearer {self.test_bearer_token}"}
        
        # Send invalid JSON
        response = self.session.post(
            f"{self.base_url}/jobs", 
            data="invalid json{", 
            headers={**headers, "Content-Type": "application/json"}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid JSON", response.json()["error"])
        

if __name__ == '__main__':
    unittest.main()