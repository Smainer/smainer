# Smainer Training Usage Guide

This document is the canonical operator guide for `smainer-training`.

## What This Service Does

`smainer-training` runs model training jobs behind a Unix socket IPC boundary.
The service exposes an HTTP API over Unix socket for:

- submit job
- inspect status
- stream progress events
- list active jobs
- cancel running job

The boundary keeps AGPL-sensitive engine dependencies isolated from the Apache-2.0 backend.

## Prerequisites

- Linux host with Python 3.11+
- local clone of this repository
- optional GPU drivers/runtime for CUDA workloads

## Install

From the `training/` directory:

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"
```

Optional engine extras:

```bash
pip install -e ".[axolotl]"
pip install -e ".[unsloth]"
pip install -e ".[llamafactory]"
```

## Run The Daemon

Default socket path:

```bash
python -m smainer_training
```

Custom socket path and debug logging:

```bash
python -m smainer_training \
  --socket-path /tmp/smainer-training.sock \
  --log-level DEBUG
```

Job-specific socket suffix (multi-tenant style):

```bash
python -m smainer_training --job-id job42
```

With `--job-id job42`, the daemon uses `/run/smainer-training-job42.sock`.

## Authentication Token

API endpoints require a bearer token header:

```text
Authorization: Bearer <REDACTED>
```

Important:

- The current implementation uses a static token constant in runtime code.
- Treat it as sensitive and never commit real tokens to logs or docs.
- Prefer external secret injection when hardening this service for production.

## API Lifecycle

Base URL for Unix socket clients:

```text
http+unix://%2Ftmp%2Fsmainer-training.sock
```

Update the encoded socket path to match your selected `--socket-path`.

### 1. Submit Job

Endpoint: `POST /jobs`

Minimal request body:

```json
{
  "job_id": "job_001",
  "model_id": "microsoft/DialoGPT-medium",
  "method": "lora",
  "dataset_uri": "hf://dataset/alpaca-cleaned"
}
```

Full request body example:

```json
{
  "job_id": "job_001",
  "model_id": "microsoft/DialoGPT-medium",
  "method": "lora",
  "dataset_uri": "hf://dataset/alpaca-cleaned",
  "hyperparams": {
    "learning_rate": 0.0001,
    "batch_size": 4,
    "epochs": 3
  },
  "resource_request": {
    "min_vram_gb": 8,
    "preferred_vram_gb": 16,
    "gpu_count": 1,
    "requires_cuda": true,
    "requires_mlx": false,
    "requires_rocm": false
  },
  "output_spec": {
    "format": "pytorch",
    "compression": "zstd",
    "max_size_gb": 10,
    "include_checkpoints": true
  },
  "license_tolerance": "permissive_only"
}
```

Success response (`201`):

```json
{
  "job_id": "job_001"
}
```

### 2. Get Status

Endpoint: `GET /jobs/{job_id}`

Success response (`200`):

```json
{
  "job_id": "job_001",
  "state": "running",
  "progress_pct": 50.0,
  "message": "Training in progress",
  "error": null
}
```

### 3. Stream Progress Events (SSE)

Endpoint: `GET /jobs/{job_id}/events`

Event format:

```json
{
  "job_id": "job_001",
  "timestamp": "2026-04-20T12:34:56.789012+00:00",
  "step": 100,
  "total_steps": 1000,
  "loss": 0.5,
  "learning_rate": 0.0001,
  "throughput_tokens_per_sec": 1200,
  "gpu_utilization_pct": 85.0,
  "vram_used_gb": 12.5
}
```

### 4. List Active Jobs

Endpoint: `GET /jobs`

Response (`200`):

```json
{
  "jobs": [
    {
      "job_id": "job_001",
      "engine": "mock_engine",
      "state": "running",
      "progress_pct": 50.0
    }
  ]
}
```

### 5. Cancel Job

Endpoint: `DELETE /jobs/{job_id}`

Response (`200`):

```json
{
  "cancelled": true
}
```

If not found (`404`):

```json
{
  "error": "Job not found"
}
```

## End-to-End Example (Python)

```python
import requests_unixsocket

TOKEN = "<REDACTED>"
SOCKET = "/tmp/smainer-training.sock"
BASE_URL = f"http+unix://{SOCKET.replace('/', '%2F')}"
HEADERS = {"Authorization": f"Bearer {TOKEN}"}

session = requests_unixsocket.Session()

submit_payload = {
    "job_id": "job_001",
    "model_id": "microsoft/DialoGPT-medium",
    "method": "lora",
    "dataset_uri": "hf://dataset/alpaca-cleaned",
}

submit = session.post(f"{BASE_URL}/jobs", json=submit_payload, headers=HEADERS)
print("submit", submit.status_code, submit.json())

status = session.get(f"{BASE_URL}/jobs/job_001", headers=HEADERS)
print("status", status.status_code, status.json())

jobs = session.get(f"{BASE_URL}/jobs", headers=HEADERS)
print("list", jobs.status_code, jobs.json())

cancel = session.delete(f"{BASE_URL}/jobs/job_001", headers=HEADERS)
print("cancel", cancel.status_code, cancel.json())
```

## cURL Example (Unix Socket)

```bash
curl --unix-socket /tmp/smainer-training.sock \
  -H "Authorization: Bearer <REDACTED>" \
  -H "Content-Type: application/json" \
  -d '{
    "job_id":"job_002",
    "model_id":"microsoft/DialoGPT-medium",
    "method":"lora",
    "dataset_uri":"hf://dataset/alpaca-cleaned"
  }' \
  http://localhost/jobs
```

## Troubleshooting

### Daemon does not start

- Check socket path permissions.
- Ensure no stale socket file blocks bind.
- Run with `--log-level DEBUG` and inspect startup errors.

### `401 Invalid authentication`

- Missing or invalid `Authorization` header.
- Use `Authorization: Bearer <REDACTED>`.

### `500` on submit

- Spec failed validation or method is unsupported by available engines.
- Confirm required fields: `job_id`, `model_id`, `method`, `dataset_uri`.
- Verify host capabilities satisfy requested resources.

### Job never progresses

- Verify selected engine can run method + resource profile.
- Review daemon logs for engine launch or polling errors.

## Security Notes

- Never print bearer tokens in shell history, logs, or CI output.
- Keep AGPL engines isolated via subprocess and IPC boundary.
- Do not import training engine packages directly into backend runtime.
- Run the license gate (`HC-10`) in CI to prevent license boundary drift.

## Operational Notes

- This service tracks active jobs in-memory for the running process.
- Restarting the daemon clears in-memory active job state.
- For production persistence, back this API with durable state in a future release.