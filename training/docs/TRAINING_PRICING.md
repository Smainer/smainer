# Training Pricing Model (Public)

## 1) Executive Summary

Smainer Training currently uses a heuristic resource estimation model, not a final telemetry-calibrated billing model.

Today, the system computes:
- `estimated_gpu_hours`
- `estimated_storage_gb`
- `confidence_level`

And it intentionally leaves:
- `estimated_compute_cost_usd = None`

This means current output is best interpreted as a transparent planning estimate for expected resource consumption, with explicit low confidence (`0.3`) in Wave 1.

## 2) Current Heuristic Model and Formulas

Current logic is implemented in `CostEstimatorVisitor` and follows these formulas.

### 2.1 GPU-Hour Estimate

$$
\text{estimated\_gpu\_hours} = \text{base\_hours(model\_id)} \times \text{gpu\_count} \times \text{method\_multiplier(method)}
$$

Where:

- `base_hours(model_id)` is determined from model name pattern matching:
  - contains `7b` or `7-billion` -> `2.0`
  - contains `13b` or `13-billion` -> `4.0`
  - contains `70b` or `70-billion` -> `16.0`
  - otherwise -> `3.0`

- `method_multiplier(method)`:
  - `lora` -> `0.3`
  - `qlora` -> `0.4`
  - `full_ft` -> `1.0`
  - `dpo` -> `0.8`
  - `orpo` -> `0.9`
  - unknown method -> `1.0`

### 2.2 Storage Estimate

Start with:

$$
\text{base\_storage} = 2.0
$$

Then apply method rule:

- if `method == full_ft`: add `10.0`
- else: add `2.0`

If checkpoints are included (`include_checkpoints = true`):

$$
\text{base\_storage} = 2 \times \text{base\_storage}
$$

Final cap by output limit:

$$
\text{estimated\_storage\_gb} = \min(\text{base\_storage},\ \text{output\_spec.max\_size\_gb})
$$

### 2.3 Cost and Confidence Fields

- `estimated_compute_cost_usd` is currently always `None`.
- `confidence_level` is currently fixed at `0.3`.
- Warnings always include: "Cost estimates are preliminary - Wave 1 uses heuristic formulas".
- Additional warning is emitted for `gpu_count > 1`: multi-GPU accuracy is limited.

## 3) Variables Used vs Not Used Today

### Used by current estimator

- `model_id` (string pattern lookup for base hours)
- `method` / `method.value` (multiplier and storage branch)
- `resource_request.gpu_count` (linear multiplier)
- `output_spec.include_checkpoints` (storage doubling)
- `output_spec.max_size_gb` (storage cap)

### Present in JobSpec but not used by current estimator

- `dataset_uri`
- `hyperparams`
- `resource_request.min_vram_gb`
- `resource_request.preferred_vram_gb`
- `resource_request.requires_cuda`
- `resource_request.requires_mlx`
- `resource_request.requires_rocm`
- `output_spec.format`
- `output_spec.compression`
- `license_tolerance`
- `submitted_at`

### Telemetry metrics available in event models but not used in pricing yet

- `throughput_tokens_per_sec`
- `gpu_utilization_pct`
- `vram_used_gb`
- `loss`
- `learning_rate`
- `step` / `total_steps`
- `extra_metrics`

## 4) Worked Examples

## Example A: 7B LoRA, 1 GPU

Inputs:
- `model_id = "acme-model-7b"`
- `method = lora`
- `gpu_count = 1`
- `include_checkpoints = true`
- `max_size_gb = 10`

Compute:
- `base_hours = 2.0` (7B match)
- `method_multiplier = 0.3` (LoRA)
- `estimated_gpu_hours = 2.0 x 1 x 0.3 = 0.6`

Storage:
- `base_storage = 2.0 + 2.0 = 4.0` (non-`full_ft`)
- checkpoints included -> `8.0`
- cap at 10 -> `estimated_storage_gb = 8.0`

Output summary:
- `estimated_gpu_hours = 0.6`
- `estimated_storage_gb = 8.0`
- `estimated_compute_cost_usd = None`
- `confidence_level = 0.3`

## Example B: 70B Full Fine-Tune, 4 GPUs

Inputs:
- `model_id = "foundation-70b"`
- `method = full_ft`
- `gpu_count = 4`
- `include_checkpoints = true`
- `max_size_gb = 50`

Compute:
- `base_hours = 16.0` (70B match)
- `method_multiplier = 1.0` (`full_ft`)
- `estimated_gpu_hours = 16.0 x 4 x 1.0 = 64.0`

Storage:
- `base_storage = 2.0 + 10.0 = 12.0` (`full_ft`)
- checkpoints included -> `24.0`
- cap at 50 -> `estimated_storage_gb = 24.0`

Output summary:
- `estimated_gpu_hours = 64.0`
- `estimated_storage_gb = 24.0`
- warning includes multi-GPU accuracy limitation

## Example C: Unknown Model Name, QLoRA, 2 GPUs, Tight Output Cap

Inputs:
- `model_id = "custom-transformer-x"` (no 7B/13B/70B token)
- `method = qlora`
- `gpu_count = 2`
- `include_checkpoints = false`
- `max_size_gb = 3`

Compute:
- `base_hours = 3.0` (default branch)
- `method_multiplier = 0.4` (QLoRA)
- `estimated_gpu_hours = 3.0 x 2 x 0.4 = 2.4`

Storage:
- `base_storage = 2.0 + 2.0 = 4.0` (non-`full_ft`)
- no checkpoint doubling -> `4.0`
- cap at 3 -> `estimated_storage_gb = 3.0`

Output summary:
- `estimated_gpu_hours = 2.4`
- `estimated_storage_gb = 3.0`

## 5) Heuristic vs Future Telemetry Roadmap

### Current state (Wave 1)

- Deterministic heuristic formulas.
- Explicit low confidence (`0.3`).
- No USD pricing integration (`estimated_compute_cost_usd = None`).
- Submission telemetry events are emitted, but not yet feeding the estimator.

### Roadmap direction

Planned progression is to replace or calibrate heuristics using observed runtime telemetry, including:
- throughput trends
- GPU utilization
- VRAM usage
- step completion dynamics
- method/model empirical performance

Expected roadmap outcomes:
- Higher confidence scores based on historical fit.
- Better multi-GPU scaling accuracy.
- Eventual non-`None` compute price field once pricing integration is enabled.

## 6) Transparency: What Users Pay For and What They Do Not

### What users are paying for conceptually

The model is designed to estimate consumption of:
- GPU-time envelope (`estimated_gpu_hours`)
- output/storage envelope (`estimated_storage_gb`)

These are the transparent units currently produced by the estimator.

### What users are not charged for in the current estimator output

- There is no computed USD amount in this estimator today (`estimated_compute_cost_usd` is always `None`).
- No telemetry-driven surcharge or dynamic adjustment is currently applied.
- No hidden multipliers outside the documented formula branches above.

## 7) Limitations and Disclaimers

- This is a heuristic Wave 1 model intended for planning, not guaranteed final billing.
- Confidence is intentionally low (`0.3`) for all jobs.
- Multi-GPU estimates have explicitly limited accuracy.
- Model-name pattern matching can misclassify custom naming schemes.
- Dataset size, hyperparameters, and real runtime behavior are not yet incorporated.
- Storage estimate is simplified and capped by `max_size_gb`; real artifact outcomes can differ.

## 8) Update Policy

This document is updated whenever estimator logic or output semantics change.

Minimum triggers for update:
- any change to base-hour mapping logic
- any change to method multipliers
- any change to storage formula or capping behavior
- any activation of non-`None` compute-cost field
- any telemetry-to-pricing integration that alters outcomes

Versioning and review expectations:
- updates should ship in the same PR as estimator logic changes
- examples in this file should be recomputed when formulas change
- public wording should remain implementation-accurate and avoid undisclosed pricing behavior
