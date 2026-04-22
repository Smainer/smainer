"""
Container strategies for training job isolation.

Defines strategies for running training jobs in isolated containers.
Default is per-job Docker containers, with future support for always-on
containers and other isolation mechanisms.
"""
from __future__ import annotations

import abc
from dataclasses import dataclass
from typing import Dict, Any, List, TYPE_CHECKING

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


@dataclass(frozen=True)
class ContainerHandle:
    """Handle to a running container instance."""
    container_id: str
    strategy_name: str
    pid: int | None = None
    ports: Dict[str, int] | None = None  # Port mappings


class ContainerStrategy(abc.ABC):
    """
    Abstract base class for container isolation strategies.
    
    Different strategies handle the trade-offs between isolation,
    resource efficiency, and startup latency for training jobs.
    """

    @property
    @abc.abstractmethod
    def name(self) -> str:
        """Strategy name for identification."""
        pass

    @abc.abstractmethod
    def launch(
        self, 
        image: str, 
        env: Dict[str, str], 
        mounts: Dict[str, str],
        gpu_mask: str
    ) -> ContainerHandle:
        """
        Launch a container for training execution.
        
        Args:
            image: Docker image to run
            env: Environment variables to set
            mounts: Host path -> container path mount mappings
            gpu_mask: CUDA_VISIBLE_DEVICES value for GPU allocation
            
        Returns:
            Handle to the running container
        """
        pass

    @abc.abstractmethod
    def stop(self, handle: ContainerHandle) -> None:
        """Stop and clean up a container."""
        pass

    @abc.abstractmethod
    def is_running(self, handle: ContainerHandle) -> bool:
        """Check if a container is still running."""
        pass


class PerJobDockerStrategy(ContainerStrategy):
    """
    Default strategy: spawn a new Docker container per training job.
    
    Provides maximum isolation between jobs at the cost of startup overhead.
    Each job gets its own container instance that is destroyed on completion.
    """

    @property
    def name(self) -> str:
        return "per_job_docker"

    def launch(
        self,
        image: str,
        env: Dict[str, str],
        mounts: Dict[str, str], 
        gpu_mask: str
    ) -> ContainerHandle:
        """Launch a new Docker container for the job."""
        # Import docker SDK lazily to keep import time fast
        try:
            import docker  # type: ignore
        except ImportError:
            raise RuntimeError("docker package required for PerJobDockerStrategy")

        client = docker.from_env()
        
        # Build docker run arguments
        environment = {**env, "CUDA_VISIBLE_DEVICES": gpu_mask}
        volumes = {host_path: {"bind": container_path, "mode": "rw"} 
                  for host_path, container_path in mounts.items()}

        # Launch container (stub implementation for Wave 1)
        container = client.containers.run(
            image=image,
            environment=environment,
            volumes=volumes,
            detach=True,
            remove=False,  # Keep container for debugging until explicit cleanup
            network_mode="none",  # No network access for security
        )

        return ContainerHandle(
            container_id=container.id,
            strategy_name=self.name,
            pid=None,  # Docker manages PID internally
        )

    def stop(self, handle: ContainerHandle) -> None:
        """Stop and remove the Docker container."""
        try:
            import docker  # type: ignore
            client = docker.from_env()
            container = client.containers.get(handle.container_id)
            container.stop(timeout=30)
            container.remove()
        except Exception:
            # Container may already be stopped/removed
            pass

    def is_running(self, handle: ContainerHandle) -> bool:
        """Check if the Docker container is running."""
        try:
            import docker  # type: ignore
            client = docker.from_env()
            container = client.containers.get(handle.container_id)
            container.reload()
            return container.status == "running"
        except Exception:
            return False


class AlwaysOnDockerStrategy(ContainerStrategy):
    """
    Placeholder strategy: reuse long-running containers across jobs.
    
    Future implementation for reduced startup latency when isolation
    requirements are relaxed. Not implemented in Wave 1.
    """

    @property
    def name(self) -> str:
        return "always_on_docker"

    def launch(
        self,
        image: str,
        env: Dict[str, str],
        mounts: Dict[str, str],
        gpu_mask: str
    ) -> ContainerHandle:
        raise NotImplementedError("AlwaysOnDockerStrategy not implemented in Wave 1")

    def stop(self, handle: ContainerHandle) -> None:
        raise NotImplementedError("AlwaysOnDockerStrategy not implemented in Wave 1")

    def is_running(self, handle: ContainerHandle) -> bool:
        raise NotImplementedError("AlwaysOnDockerStrategy not implemented in Wave 1")