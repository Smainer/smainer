# Provider Metrics Collection

> Module: `backend/provider/src/provider/metrics/`
> Owner Agent: `systems-engineer`
> Status: Planned

## Purpose

Extend the compute node daemon to capture granular effort metrics during task execution. These metrics are signed by the node's Starknet key and reported to the relayer for effort-based pricing settlement.

## Current State

The provider daemon already captures:
- `execution_time` (wall-clock seconds)
- `cpu_usage_percent` (average during execution)
- `memory_used_mb` (current RSS)
- `peak_memory_mb` (max RSS during execution)

**Not captured (needed for effort pricing):**
- Token counts (input/output)
- GPU compute time (distinct from wall-clock)
- Model identifier and parameter count
- Peak VRAM usage during inference
- Throughput (tokens/second)

## Architecture

```
metrics/
├── __init__.py
├── models.py           # EffortMetrics dataclass
├── token_counter.py    # TokenCounter — count tokens via model API response
├── gpu_tracker.py      # GPUTracker — poll nvidia-smi/rocm-smi during inference
└── collector.py        # MetricsCollector — orchestrates all metric sources
```

## Token Counting Strategy

### For Ollama-based inference (current execution path)

Ollama API (`/api/generate`) returns token counts in its response:

```json
{
  "response": "...",
  "done": true,
  "total_duration": 5000000000,
  "load_duration": 1000000000,
  "prompt_eval_count": 125,        // ← input tokens
  "prompt_eval_duration": 500000,
  "eval_count": 340,               // ← output tokens
  "eval_duration": 4500000000
}
```

**Approach:** Parse Ollama response fields directly. No external tokenizer needed.

```python
class TokenCounter:
    """Extract token counts from inference engine responses."""

    def extract_from_ollama(self, response: dict) -> TokenCounts:
        return TokenCounts(
            input_tokens=response.get("prompt_eval_count", 0),
            output_tokens=response.get("eval_count", 0),
            inference_duration_ns=response.get("eval_duration", 0),
            prompt_eval_duration_ns=response.get("prompt_eval_duration", 0),
        )
```

### For future inference engines (vLLM, TGI, etc.)

Each engine adapter implements `ITokenCounter`:

```python
class ITokenCounter(ABC):
    @abstractmethod
    def extract_token_counts(self, engine_response: dict) -> TokenCounts: ...
```

## GPU Tracking Strategy

### nvidia-smi polling (NVIDIA GPUs)

```python
class GPUTracker:
    """Track GPU utilization during task execution."""

    def __init__(self, poll_interval: float = 1.0):
        self._poll_interval = poll_interval
        self._samples: list[GPUSample] = []
        self._running = False

    async def start(self) -> None:
        """Begin GPU polling in background task."""
        self._running = True
        self._task = asyncio.create_task(self._poll_loop())

    async def stop(self) -> GPUReport:
        """Stop polling and return aggregated report."""
        self._running = False
        await self._task
        return self._aggregate()

    async def _poll_loop(self) -> None:
        while self._running:
            sample = await self._read_gpu_stats()
            self._samples.append(sample)
            await asyncio.sleep(self._poll_interval)

    async def _read_gpu_stats(self) -> GPUSample:
        """Query nvidia-smi for current GPU state."""
        proc = await asyncio.create_subprocess_exec(
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total,power.draw",
            "--format=csv,noheader,nounits",
            stdout=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        gpu_util, mem_used, mem_total, power = stdout.decode().strip().split(", ")

        return GPUSample(
            timestamp=time.monotonic(),
            gpu_utilization_pct=float(gpu_util),
            vram_used_mb=float(mem_used),
            vram_total_mb=float(mem_total),
            power_draw_w=float(power),
        )

    def _aggregate(self) -> GPUReport:
        return GPUReport(
            gpu_time_seconds=self._calculate_gpu_seconds(),
            peak_vram_used_gb=max(s.vram_used_mb for s in self._samples) / 1024,
            avg_gpu_utilization=sum(s.gpu_utilization_pct for s in self._samples) / len(self._samples),
            total_samples=len(self._samples),
        )

    def _calculate_gpu_seconds(self) -> float:
        """Compute effective GPU-seconds (utilization-weighted time)."""
        total = 0.0
        for i in range(1, len(self._samples)):
            dt = self._samples[i].timestamp - self._samples[i-1].timestamp
            util = self._samples[i].gpu_utilization_pct / 100.0
            total += dt * util
        return total
```

### AMD (rocm-smi) and Intel (xpu-smi) support

Same interface, different CLI backends — GPU vendor is already detected at registration time.

## MetricsCollector — Orchestrator

```python
class MetricsCollector:
    """Orchestrates all metric sources for a single task execution."""

    def __init__(
        self,
        token_counter: ITokenCounter,
        gpu_tracker: GPUTracker,
        resource_monitor: ResourceMonitor,  # Existing class
    ):
        self._token_counter = token_counter
        self._gpu_tracker = gpu_tracker
        self._resource_monitor = resource_monitor

    async def start_collection(self) -> None:
        """Begin background metric collection."""
        await self._gpu_tracker.start()
        self._resource_monitor.start()
        self._start_time = time.monotonic()

    async def finalize(self, engine_response: dict, model_id: str) -> EffortMetrics:
        """Stop collection and build signed effort metrics."""
        wall_time = time.monotonic() - self._start_time
        gpu_report = await self._gpu_tracker.stop()
        resource_report = self._resource_monitor.stop()
        token_counts = self._token_counter.extract_token_counts(engine_response)

        return EffortMetrics(
            tokens_input=token_counts.input_tokens,
            tokens_output=token_counts.output_tokens,
            gpu_time_seconds=gpu_report.gpu_time_seconds,
            model_id=model_id,
            model_params_billions=self._infer_param_count(model_id),
            peak_vram_used_gb=gpu_report.peak_vram_used_gb,
            throughput_tps=token_counts.output_tokens / wall_time if wall_time > 0 else 0,
            wall_time_seconds=wall_time,
            cpu_usage_percent=resource_report.avg_cpu_percent,
            peak_memory_mb=resource_report.peak_memory_mb,
        )

    @staticmethod
    def _infer_param_count(model_id: str) -> float:
        """Extract parameter count from model name (e.g., 'llama3.1:70b' → 70.0)."""
        import re
        match = re.search(r'(\d+)b', model_id.lower())
        return float(match.group(1)) if match else 7.0  # Default to 7B
```

## Data Models

```python
@dataclass(frozen=True)
class TokenCounts:
    input_tokens: int
    output_tokens: int
    inference_duration_ns: int     # From engine (more precise than wall-clock)
    prompt_eval_duration_ns: int

@dataclass(frozen=True)
class GPUSample:
    timestamp: float               # monotonic clock
    gpu_utilization_pct: float
    vram_used_mb: float
    vram_total_mb: float
    power_draw_w: float

@dataclass(frozen=True)
class GPUReport:
    gpu_time_seconds: float        # Utilization-weighted GPU time
    peak_vram_used_gb: float
    avg_gpu_utilization: float
    total_samples: int

@dataclass(frozen=True)
class EffortMetrics:
    tokens_input: int
    tokens_output: int
    gpu_time_seconds: float
    model_id: str
    model_params_billions: float
    peak_vram_used_gb: float
    throughput_tps: float
    wall_time_seconds: float
    cpu_usage_percent: float
    peak_memory_mb: float
```

## Integration Point

In `enhanced_executor.py`, the existing `_execute_ai_inference()` method wraps with `MetricsCollector`:

```python
# BEFORE (current):
result = await client.post(url, json=payload)
return TaskResult(result_data={"result": response_text}, execution_time=elapsed)

# AFTER (with metrics):
await self._metrics_collector.start_collection()
result = await client.post(url, json=payload)
effort_metrics = await self._metrics_collector.finalize(result.json(), model_id)
return TaskResult(
    result_data={"result": response_text},
    execution_time=elapsed,
    effort_metrics=effort_metrics,  # NEW field
)
```

## Signing

Effort metrics are included in the result hash that the node signs:

```python
# Current: hash = SHA256(result_data)
# New:     hash = SHA256(result_data + effort_metrics_json)
```

This ensures the relayer cannot tamper with reported metrics.

## Backward Compatibility

- `effort_metrics` field is `Optional` on `TaskCompletedEvent`
- Nodes running old versions send `effort_metrics: null`
- Relayer falls back to flat pricing when metrics are absent
- No breaking change to WebSocket protocol
