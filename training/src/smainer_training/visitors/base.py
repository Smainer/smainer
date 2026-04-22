"""
Base visitor pattern for JobSpec operations.

Defines the Visitor pattern interface and Result dataclass for operations
that traverse and analyze JobSpec instances without modifying them.
"""
from __future__ import annotations

import abc
from dataclasses import dataclass
from typing import Generic, TypeVar, TYPE_CHECKING

if TYPE_CHECKING:
    from ..core.job_spec import JobSpec

T = TypeVar('T')


@dataclass(frozen=True)
class Result(Generic[T]):
    """
    Result of a visitor operation on a JobSpec.
    
    Encapsulates success/failure status, error messages, warnings,
    and the computed output of the visitor operation.
    """
    ok: bool
    errors: list[str]
    warnings: list[str]
    output: T


class JobSpecVisitor(abc.ABC, Generic[T]):
    """
    Abstract base class for JobSpec visitor operations.
    
    Implements the Visitor pattern for cross-cutting concerns like
    validation, cost estimation, secret scrubbing, and telemetry
    that operate on JobSpec instances.
    """

    @abc.abstractmethod
    def visit(self, spec: JobSpec) -> Result[T]:
        """
        Visit a JobSpec and perform the visitor's operation.
        
        Returns a Result with success status, error/warning messages,
        and the computed output specific to this visitor type.
        """
        pass