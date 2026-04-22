# smainer_training

Plugin-based training engine adapter framework for the Smainer distributed training network. Provides a unified interface for multiple ML training frameworks through a composable OOP architecture.

## Package Structure

```
src/smainer_training/
├── __init__.py                     # Public API surface
├── __main__.py                     # Daemon entry point + security startup gate
├── core/                           # Stable ABCs and value objects
│   ├── engine.py                   # TrainingEngine ABC
│   ├── job_spec.py                 # JobSpec dataclass
│   ├── host_caps.py                # HostCapabilities dataclass (VRAM, etc.)
│   ├── artifact.py                 # Artifact + ArtifactRepository ABCs
│   ├── events.py                   # Event dataclasses (Progress, Status, Checkpoint, Error)
│   └── exceptions.py               # TrainingError hierarchy
├── factory/                        # Engine selection logic
│   └── engine_factory.py           # TrainingEngineFactory.select(job_spec, host_caps)
├── registry/                       # Singleton adapter registry
│   └── engine_registry.py          # Global registry of installed adapters
├── engines/                        # Concrete engine adapters (Waves 2-5)
│   ├── axolotl_adapter.py          # Wave 2 adapter
│   ├── unsloth_adapter.py          # Wave 3 adapter
│   ├── llama_factory_adapter.py    # Wave 4 adapter
│   ├── transformerlab_adapter.py   # Wave 5 adapter
│   └── __init__.py                 # Adapter exports
├── service/                        # Facade
│   └── training_service.py         # Single entry point (submit_job, cancel_job, stream_progress)
├── visitors/                       # Visitor pattern — pre-flight checks
│   ├── base.py                     # JobSpecVisitor ABC
│   ├── validator.py                # ValidatorVisitor
│   ├── secret_scrubber.py          # SecretScrubbingVisitor
│   ├── cost_estimator.py           # CostEstimatorVisitor
│   └── telemetry.py                # TelemetryVisitor
├── events/                         # Event bus
│   └── event_bus.py                # Thread-safe pub/sub + get_event_bus() singleton
├── pipeline/                       # Chain of Responsibility — validation chain
└── runtime/                        # IPC server + container strategy
    ├── ipc_server.py               # Unix socket HTTP + HMAC bearer auth
    └── container_strategy.py       # Per-job Docker container strategy
```

## Public API

| Import | Type | Description |
|--------|------|-------------|
| `TrainingService` | Class | Main facade for job submission and management |
| `JobSpec` | Dataclass | Training job specification |
| `TrainingEngine` | ABC | Base class for engine adapters |
| `Artifact`, `ArtifactRepository` | ABC | Artifact storage abstractions |
| `ProgressEvent`, `StatusEvent`, `CheckpointEvent`, `ErrorEvent` | Dataclasses | Event types |
| `TrainingError` | Exception | Base exception class |
| `get_registry()` | Function | Access global engine registry |
| `get_event_bus()` | Function | Access global event bus |

## Design Patterns

- **Factory**: `TrainingEngineFactory.select()` picks engine based on job spec and host capabilities
- **Registry/Singleton**: Global registry of installed adapters
- **Abstract Base**: `TrainingEngine` ABC that all adapters implement
- **Facade**: `TrainingService` provides single entry point for IPC layer
- **Visitor**: Pre-flight validation, secret scrubbing, cost estimation, telemetry
- **Observer/Event Bus**: Thread-safe pub/sub for progress events
- **Repository**: Artifact storage abstraction
- **Chain of Responsibility**: Validation pipeline before training begins
- **Bridge**: Engines decoupled from core ABCs; IPC bridge via Unix socket
- **Strategy**: Per-job Docker container strategies

## Security Contract

- **AGPL engines MUST be invoked via subprocess only** — never imported directly
- Bearer token authentication via `TRAINING_SERVICE_BEARER_TOKEN` environment variable
- `hmac.compare_digest()` for constant-time token comparison
- `TRAINING_SERVICE_ENVIRONMENT=production` startup gate required in production

## Engine Adapters (Implemented)

| Engine | License | Status |
|--------|---------|--------|
| Axolotl | Apache-2.0 | Implemented (Wave 2) |
| Unsloth | AGPL-3.0 | Implemented (Wave 3, subprocess isolation) |
| LLaMA-Factory | Apache-2.0 | Implemented (Wave 4) |
| TransformerLab | AGPL-3.0 | Implemented (Wave 5, subprocess isolation) |

## Adding an Engine Adapter

1. **Create adapter class**:
```python
from smainer_training.core.engine import TrainingEngine

class MyEngineAdapter(TrainingEngine):
    @property
    def name(self) -> str:
        return "my-engine"

    @property
    def supported_methods(self) -> set[str]:
        return {"lora"}

    def can_run(self, spec, host_caps) -> bool:
        return True

    def submit(self, spec):
        ...

    def poll(self, handle):
        ...

    def stream_events(self, handle):
        ...

    def cancel(self, handle) -> None:
        ...

    def produce_artifact(self, handle):
        ...
```

2. **Register adapter**:
```python
from smainer_training import get_registry

get_registry().register(MyEngineAdapter)
```

## Documentation

- **Full operator guide**: [../../docs/USAGE.md](../../docs/USAGE.md)
- **Architecture diagram**: [../../../README.md](../../../README.md)