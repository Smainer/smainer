"""
Artifact management for training outputs.

Defines Artifact value objects and ArtifactRepository persistence interface.
Repository implementations (local, S3, IPFS) are plugged in at runtime.
"""
from __future__ import annotations

import abc
from dataclasses import dataclass
from typing import BinaryIO, Dict, Any
import datetime


@dataclass(frozen=True)
class Artifact:
    """
    Immutable artifact produced by a training job.
    
    Represents a trained model, LoRA adapter, checkpoint, or other
    training output with associated metadata.
    """
    artifact_id: str
    job_id: str
    artifact_type: str  # "model", "lora_adapter", "checkpoint", "logs"
    format: str         # "pytorch", "gguf", "safetensors", etc.
    size_bytes: int
    checksum_sha256: str
    created_at: datetime.datetime
    metadata: Dict[str, Any]  # Model name, training metrics, hyperparams, etc.


class ArtifactRepository(abc.ABC):
    """
    Abstract interface for artifact storage backends.
    
    Implementations handle the persistence layer for training outputs.
    Storage strategy is selected via dependency injection into TrainingService.
    """

    @abc.abstractmethod
    def put(self, artifact: Artifact, data: BinaryIO) -> None:
        """Store an artifact with its binary data."""
        pass

    @abc.abstractmethod
    def get(self, artifact_id: str) -> tuple[Artifact, BinaryIO]:
        """Retrieve an artifact and its binary data."""
        pass

    @abc.abstractmethod
    def exists(self, artifact_id: str) -> bool:
        """Check if an artifact exists in the repository."""
        pass

    @abc.abstractmethod
    def delete(self, artifact_id: str) -> None:
        """Delete an artifact from the repository."""
        pass

    @abc.abstractmethod
    def list_by_job(self, job_id: str) -> list[Artifact]:
        """List all artifacts produced by a specific job."""
        pass


class InMemoryArtifactRepository(ArtifactRepository):
    """
    In-memory artifact repository for testing and development.
    
    Stores artifacts in memory for the lifetime of the process.
    Not suitable for production use - artifacts are lost on restart.
    """
    
    def __init__(self) -> None:
        self._artifacts: Dict[str, Artifact] = {}
        self._data: Dict[str, bytes] = {}
        
    def put(self, artifact: Artifact, data: BinaryIO) -> None:
        """Store an artifact with its binary data."""
        self._artifacts[artifact.artifact_id] = artifact
        self._data[artifact.artifact_id] = data.read()
        
    def get(self, artifact_id: str) -> tuple[Artifact, BinaryIO]:
        """Retrieve an artifact and its binary data.""" 
        if artifact_id not in self._artifacts:
            raise KeyError(f"Artifact {artifact_id} not found")
            
        artifact = self._artifacts[artifact_id]
        data_bytes = self._data[artifact_id]
        
        from io import BytesIO
        return artifact, BytesIO(data_bytes)
        
    def exists(self, artifact_id: str) -> bool:
        """Check if an artifact exists in the repository."""
        return artifact_id in self._artifacts
        
    def delete(self, artifact_id: str) -> None:
        """Delete an artifact from the repository."""
        self._artifacts.pop(artifact_id, None)
        self._data.pop(artifact_id, None)
        
    def list_by_job(self, job_id: str) -> list[Artifact]:
        """List all artifacts produced by a specific job."""
        return [
            artifact for artifact in self._artifacts.values()
            if artifact.job_id == job_id
        ]