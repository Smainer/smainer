"""
Checkpoint storage strategies for training persistence.

Defines pluggable strategies for storing training checkpoints and artifacts.
Default is local filesystem storage, with future support for S3 and IPFS.
"""
from __future__ import annotations

import abc
import os
from pathlib import Path
from typing import BinaryIO, Dict, Any, TYPE_CHECKING

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec


class CheckpointStrategy(abc.ABC):
    """
    Abstract base class for checkpoint storage strategies.
    
    Different strategies handle trade-offs between performance,
    durability, and cost for storing training checkpoints and artifacts.
    """

    @property
    @abc.abstractmethod
    def name(self) -> str:
        """Strategy name for identification."""
        pass

    @abc.abstractmethod
    def store_checkpoint(
        self, 
        job_id: str, 
        step: int, 
        checkpoint_data: BinaryIO,
        metadata: Dict[str, Any]
    ) -> str:
        """
        Store a training checkpoint.
        
        Returns the checkpoint path/identifier for later retrieval.
        """
        pass

    @abc.abstractmethod
    def load_checkpoint(self, checkpoint_path: str) -> tuple[BinaryIO, Dict[str, Any]]:
        """Load a checkpoint and its metadata."""
        pass

    @abc.abstractmethod
    def delete_checkpoint(self, checkpoint_path: str) -> None:
        """Delete a checkpoint from storage."""
        pass

    @abc.abstractmethod  
    def list_checkpoints(self, job_id: str) -> list[str]:
        """List all checkpoint paths for a job."""
        pass


class LocalCheckpointStrategy(CheckpointStrategy):
    """
    Default strategy: store checkpoints on local filesystem.
    
    Stores checkpoints under /var/lib/smainer-provider/transformerlab/{job_id}/
    as specified in the meeting minutes. Provides fast access but no redundancy.
    """

    def __init__(self, base_path: str = "/var/lib/smainer-provider/transformerlab"):
        self.base_path = Path(base_path)

    @property
    def name(self) -> str:
        return "local_filesystem"

    def store_checkpoint(
        self,
        job_id: str,
        step: int,
        checkpoint_data: BinaryIO,
        metadata: Dict[str, Any]
    ) -> str:
        """Store checkpoint to local filesystem."""
        job_dir = self.base_path / job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        
        checkpoint_path = job_dir / f"checkpoint_step_{step}.bin"
        metadata_path = job_dir / f"checkpoint_step_{step}.json"
        
        # Write checkpoint data
        with open(checkpoint_path, "wb") as f:
            f.write(checkpoint_data.read())
        
        # Write metadata
        import json
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)
            
        return str(checkpoint_path)

    def load_checkpoint(self, checkpoint_path: str) -> tuple[BinaryIO, Dict[str, Any]]:
        """Load checkpoint and metadata from filesystem."""
        import json
        from io import BytesIO
        
        # Load checkpoint data
        with open(checkpoint_path, "rb") as f:
            data = BytesIO(f.read())
        
        # Load metadata
        metadata_path = checkpoint_path.replace(".bin", ".json")
        with open(metadata_path, "r") as f:
            metadata = json.load(f)
            
        return data, metadata

    def delete_checkpoint(self, checkpoint_path: str) -> None:
        """Delete checkpoint and metadata files."""
        Path(checkpoint_path).unlink(missing_ok=True)
        metadata_path = checkpoint_path.replace(".bin", ".json")
        Path(metadata_path).unlink(missing_ok=True)

    def list_checkpoints(self, job_id: str) -> list[str]:
        """List all checkpoint files for a job."""
        job_dir = self.base_path / job_id
        if not job_dir.exists():
            return []
            
        checkpoints = []
        for checkpoint_file in job_dir.glob("checkpoint_step_*.bin"):
            checkpoints.append(str(checkpoint_file))
            
        return sorted(checkpoints)


class S3CheckpointStrategy(CheckpointStrategy):
    """
    Placeholder strategy: store checkpoints in S3.
    
    Future implementation for durable, scalable checkpoint storage.
    Not implemented in Wave 1.
    """

    @property
    def name(self) -> str:
        return "s3"

    def store_checkpoint(
        self,
        job_id: str,
        step: int,
        checkpoint_data: BinaryIO,
        metadata: Dict[str, Any]
    ) -> str:
        raise NotImplementedError("S3CheckpointStrategy not implemented in Wave 1")

    def load_checkpoint(self, checkpoint_path: str) -> tuple[BinaryIO, Dict[str, Any]]:
        raise NotImplementedError("S3CheckpointStrategy not implemented in Wave 1")

    def delete_checkpoint(self, checkpoint_path: str) -> None:
        raise NotImplementedError("S3CheckpointStrategy not implemented in Wave 1")

    def list_checkpoints(self, job_id: str) -> list[str]:
        raise NotImplementedError("S3CheckpointStrategy not implemented in Wave 1")


class IPFSCheckpointStrategy(CheckpointStrategy):
    """
    Placeholder strategy: store checkpoints on IPFS.
    
    Future implementation for decentralized checkpoint storage.
    Not implemented in Wave 1.
    """

    @property
    def name(self) -> str:
        return "ipfs"

    def store_checkpoint(
        self,
        job_id: str,
        step: int,
        checkpoint_data: BinaryIO,
        metadata: Dict[str, Any]
    ) -> str:
        raise NotImplementedError("IPFSCheckpointStrategy not implemented in Wave 1")

    def load_checkpoint(self, checkpoint_path: str) -> tuple[BinaryIO, Dict[str, Any]]:
        raise NotImplementedError("IPFSCheckpointStrategy not implemented in Wave 1")

    def delete_checkpoint(self, checkpoint_path: str) -> None:
        raise NotImplementedError("IPFSCheckpointStrategy not implemented in Wave 1")

    def list_checkpoints(self, job_id: str) -> list[str]:
        raise NotImplementedError("IPFSCheckpointStrategy not implemented in Wave 1")