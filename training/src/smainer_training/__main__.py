"""
Main entry point for Smainer training daemon.

Starts the Unix socket IPC server with a fully configured training service.
This is the process entry point that the provider daemon communicates with
via Unix socket boundary.
"""
import argparse
import logging
import os
import signal
import sys
from pathlib import Path

from smainer_training.core.host_caps import HostCapabilities, GpuInfo
from smainer_training.core.artifact import InMemoryArtifactRepository  
from smainer_training.events.event_bus import EventBus
from smainer_training.factory.engine_factory import TrainingEngineFactory
from smainer_training.pipeline.validation_chain import ValidationChain
from smainer_training.registry.engine_registry import get_registry
from smainer_training.runtime.container_strategy import ContainerStrategy
from smainer_training.runtime.ipc_server import UnixSocketIPCServer
from smainer_training.service.training_service import TrainingService


def setup_logging(log_level: str) -> None:
    """Configure structured logging for the training daemon."""
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s %(name)s[%(process)d] %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def validate_security_config() -> None:
    """Validate security configuration and provide setup guidance."""
    logger = logging.getLogger(__name__)
    
    bearer_token = os.environ.get('TRAINING_SERVICE_BEARER_TOKEN')
    is_production = (
        os.environ.get('TRAINING_SERVICE_ENVIRONMENT', '').lower() == 'production' or
        os.environ.get('NODE_ENV', '').lower() == 'production'
    )
    
    if not bearer_token:
        if is_production:
            logger.error(
                "CRITICAL: TRAINING_SERVICE_BEARER_TOKEN not configured. "
                "This environment variable is required for secure authentication."
            )
            sys.exit(1)
        else:
            logger.warning(
                "Bearer token not configured. Using development default. "
                "Set TRAINING_SERVICE_BEARER_TOKEN for production deployment."
            )
    else:
        # Validate token strength (basic checks)
        if len(bearer_token) < 16:
            logger.warning(
                "Bearer token appears weak (less than 16 characters). "
                "Consider using a stronger token for production."
            )
        
        # Check for obvious weak patterns
        weak_patterns = ['password', 'secret', '123', 'token', 'default', 'test']
        if any(pattern in bearer_token.lower() for pattern in weak_patterns):
            logger.warning(
                "Bearer token contains common weak patterns. "
                "Consider using a cryptographically random token."
            )
        
        logger.info("Bearer token configured and validated")


def detect_host_capabilities() -> HostCapabilities:
    """Detect available GPU and compute capabilities."""
    try:
        import psutil
        import GPUtil
        
        gpus = GPUtil.getGPUs()
        gpu_info_list = []
        total_vram = 0.0
        
        for i, gpu in enumerate(gpus):
            vram_total = gpu.memoryTotal / 1024  # MB to GB
            vram_free = gpu.memoryFree / 1024    # MB to GB
            total_vram += vram_total
            
            gpu_info = GpuInfo(
                device_id=i,
                name=gpu.name,
                vram_total_gb=vram_total,
                vram_free_gb=vram_free,
                compute_capability=None,  # GPUtil doesn't provide this
                vendor="nvidia"  # Assume NVIDIA if GPU detected
            )
            gpu_info_list.append(gpu_info)
            
        if gpu_info_list:
            return HostCapabilities(
                gpus=gpu_info_list,
                total_vram_gb=total_vram,
                cpu_count=psutil.cpu_count(),
                available_disk_gb=psutil.disk_usage('/').free / (1024**3),  # Bytes to GB
                supports_cuda=True,  # Assume CUDA if GPU detected
                supports_mlx=sys.platform == "darwin",  # MLX only on macOS
                supports_rocm=False,  # TODO: Add ROCm detection
                max_concurrent_jobs=max(1, len(gpus))
            )
    except ImportError:
        pass
    
    # Fallback: CPU-only capabilities
    try:
        import psutil
        cpu_count = psutil.cpu_count()
        disk_free = psutil.disk_usage('/').free / (1024**3)
    except ImportError:
        cpu_count = 1
        disk_free = 100.0
    
    return HostCapabilities(
        gpus=[],
        total_vram_gb=0.0,
        cpu_count=cpu_count,
        available_disk_gb=disk_free,
        supports_cuda=False,
        supports_mlx=False,
        supports_rocm=False,
        max_concurrent_jobs=1
    )


def create_training_service(host_caps: HostCapabilities) -> TrainingService:
    """Create a fully configured training service with dependencies."""
    registry = get_registry()
    factory = TrainingEngineFactory()
    event_bus = EventBus()
    validation_chain = ValidationChain()
    artifact_repo = InMemoryArtifactRepository()
    container_strategy = ContainerStrategy()
    
    return TrainingService(
        registry=registry,
        factory=factory,
        event_bus=event_bus,
        validation_chain=validation_chain,
        artifact_repo=artifact_repo,
        container_strategy=container_strategy,
        host_capabilities=host_caps
    )


def main() -> None:
    """Main entry point for training daemon."""
    parser = argparse.ArgumentParser(description="Smainer training service daemon")
    parser.add_argument(
        "--socket-path",
        default="/run/smainer-training.sock",
        help="Unix socket path for IPC communication"
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level"
    )
    parser.add_argument(
        "--job-id", 
        help="Optional job ID suffix for multi-tenant socket paths"
    )
    parser.add_argument(
        "--bearer-token",
        help="Bearer token for API authentication (overrides TRAINING_SERVICE_BEARER_TOKEN env var)"
    )
    
    args = parser.parse_args()
    
    # Configure logging
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)
    
    # Validate security configuration
    validate_security_config()
    
    # Override environment bearer token if provided via CLI
    if args.bearer_token:
        os.environ['TRAINING_SERVICE_BEARER_TOKEN'] = args.bearer_token
        logger.info("Bearer token set via command line argument")
    
    # Adjust socket path for job-specific instances
    socket_path = args.socket_path
    if args.job_id:
        socket_path = f"/run/smainer-training-{args.job_id}.sock"
        
    logger.info(f"Starting Smainer training daemon on {socket_path}")
    
    try:
        # Detect host capabilities
        host_caps = detect_host_capabilities()
        logger.info(f"Detected host capabilities: {len(host_caps.gpus)} GPUs, {host_caps.total_vram_gb:.1f}GB VRAM")
        
        # Create training service
        training_service = create_training_service(host_caps)
        
        # Start IPC server
        ipc_server = UnixSocketIPCServer(socket_path, training_service)
        
        # Set up signal handlers for graceful shutdown
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down gracefully")
            ipc_server.stop()
            sys.exit(0)
            
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Start server
        ipc_server.start()
        logger.info("Training daemon started successfully")
        
        # Keep main thread alive
        try:
            while True:
                signal.pause()
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt received")
        finally:
            ipc_server.stop()
            
    except Exception as e:
        logger.error(f"Failed to start training daemon: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()