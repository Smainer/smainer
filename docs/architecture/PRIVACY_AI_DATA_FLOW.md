# Smainer Privacy AI — End-to-End Data Flow

> **Scope:** Full request lifecycle from Telegram user message to AI result delivery, including
> wallet/payment gating, relayer scheduling, Redis/PubSub internals, provider WebSocket execution,
> Ollama inference, and result callback. Wallet charging happens **outside Telegram** via linked
> wallet / external wallet flow.  
> **Audience:** Developers who want to follow the code and debug production issues.  
> **Last updated:** 2026-05-05

---

## Table of Contents

1. [System Overview](#1-system-overview)  
2. [Request Lifecycle (step-by-step)](#2-request-lifecycle)  
3. [Protocols, Endpoints, and Events Reference](#3-protocols-endpoints-and-events)  
4. [File / Function Map](#4-file--function-map)  
5. [Relayer Scheduling and Redis/PubSub Internals](#5-relayer-scheduling-and-redispubsub-internals)  
6. [Provider WebSocket Execution and Ollama Inference](#6-provider-websocket-execution-and-ollama-inference)  
7. [Payment and Wallet — Outside-Telegram Design](#7-payment-and-wallet--outside-telegram-design)  
8. [Debugging Checklist](#8-debugging-checklist)  
9. [Common Failure Modes](#9-common-failure-modes)  

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  User                                                                         │
│  Telegram Client                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │  HTTPS POST  (Telegram Bot API)
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Smainer Bot  (Vercel serverless / webhook)                                   │
│  telegram/smainer-bot/                                                        │
│  api/webhook.py → src/handlers.py                                             │
│  Wallet link stored via Relayer KV API (HMAC-keyed, optional Fernet)         │
└─────────────────────────────────────────────────────────────────────────────┘
         │  Wallet/payment gate: user taps "Pay & Compute" button
         │  → opens MiniApp (smainer-miniapp.vercel.app)
         │
         │  MiniApp calls on-chain escrow contract (Starknet, external to Telegram)
         │  User approves $STRK transfer in ArgentX/Braavos
         │  MiniApp calls Telegram.WebApp.sendData(JSON) on success
         │
         │  Telegram delivers web_app_data back to bot webhook
         │
         │  Bot verifies on-chain escrow via PaymentVerifier → Starknet RPC
         │
         │  HTTPS POST  (Bearer token)
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Relayer  (DigitalOcean droplet, uvicorn behind nginx)                        │
│  backend/relayer/  —  api.smainer.io                                          │
│  FastAPI app — routes.py / ai_inference.py                                   │
│  Redis (task queue, node pool, event streams)                                 │
│  JobScheduler: pending_tasks list → assigns to best node                      │
│  EventBus: Redis Streams (events:tasks, events:nodes, events:system)          │
└─────────────────────────────────────────────────────────────────────────────┘
         │  WebSocket  (wss://api.smainer.io/ws/{node_id})
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Provider Daemon  (Runpod GPU node)                                           │
│  backend/provider/                                                             │
│  EnhancedRelayerAPIClient (websockets, circuit breakers)                      │
│  EnhancedSandboxedExecutor._execute_ai_inference_task()                       │
│  → Ollama HTTP API  (localhost:11434/api/generate)                            │
└─────────────────────────────────────────────────────────────────────────────┘
         │  WebSocket TASK_COMPLETED event
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Relayer receives result, calls deliver_result_callback()                     │
│  HTTPS POST to https://bot.smainer.io/api/callback/complete                  │
│  (HMAC-SHA256 signed, 300 s replay window)                                   │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Bot callback endpoint  (Vercel)                                              │
│  telegram/smainer-bot/api/callback/complete.py                                │
│  bot.edit_message_text() — AI response shown to user                          │
│  SettlementManager.settle_task() — on-chain fee split (88% provider, 12% treasury) │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Request Lifecycle

### Step 1 — Telegram delivers update to bot webhook

**File:** `telegram/smainer-bot/api/webhook.py`  
**Class:** `handler` (inherits `BaseHTTPRequestHandler`)  
**Method:** `handler.do_POST`

1. Reads `Content-Length`, reads body bytes.
2. Calls `_verify_webhook_secret(secret_header)`:
   - Reads `X-Telegram-Bot-Api-Secret-Token` header.
   - Compares with `settings.webhook_secret` using `hmac.compare_digest()` to prevent timing attacks.
   - If `webhook_secret` is unset in Vercel env, verification is skipped with a warning (dev only).
3. JSON-parses the body into a `dict`.
4. Runs `asyncio.run(_process_update(update))`.

**Function:** `_process_update(update: dict)`

- Instantiates `Bot(token=settings.telegram_bot_token)`, `RelayerClient`, `WalletManager`, `PaymentManager` **per invocation** (stateless serverless).
- Checks for `message.web_app_data` first → routes to `handle_webapp_data`.
- Checks for `callback_query` (inline button press) → acknowledges via `bot.answer_callback_query`.
- For text messages, dispatches to the appropriate command handler or to `handle_inference` / `handle_one_tap_inference`.

---

### Step 2 — Wallet gate (text message → `handle_inference`)

**File:** `telegram/smainer-bot/src/handlers.py`  
**Function:** `handle_inference(update, bot, wallet_mgr, payment_mgr, relayer)`

1. **Session touch:** `touch_session(user_id)` — in-process TTL tracking (TM-004, 15-minute idle).
2. **Model preference lookup:** `await relayer.kv_get(f"prefs:{user_id}:model")` — calls Relayer KV REST endpoint (`GET /api/v1/bot/kv/{key}`). Falls back to `settings.default_model`.
3. **`infer_tier(model_name)`** — heuristic: names containing `70b/65b/72b` → `ModelTier.LARGE`, `34b/33b/13b/14b` → `ModelTier.MEDIUM`, otherwise `ModelTier.SMALL`.
4. **Node availability check:** `await relayer.list_available_models()` — calls `GET /api/v1/ai/capable-nodes` on the Relayer. Returns JSON list. If empty, sends "No compute nodes online" and returns.
5. **Wallet link check:** `await wallet_mgr.get_linked_address(user_id)`.
   - If linked, calls `await wallet_mgr.has_sufficient_balance(address)` → queries Starknet RPC for `$STRK` balance (see §7).
   - Insufficient balance → informs user.
6. **Sends "Pay & Compute" button** — an `InlineKeyboardMarkup` with a `WebAppInfo(url=pay_url)` button. The `pay_url` encodes the prompt, model, and `message_id` so the MiniApp knows what to pay for.

The placeholder message ID is stored in memory (encoded in the URL) so the relayer callback can edit the same message with the AI result.

---

### Step 3 — MiniApp payment (outside Telegram)

**See §7 for full design.** The MiniApp (`telegram/miniapp/src/`) opens in the Telegram WebApp container:

1. Reads URL params (prompt, model, cost).
2. Connects wallet via raw `RpcProvider` (not `InjectedConnector`; browser extensions don't work in Telegram WebView).
3. Calls `create_task()` on the Starknet escrow contract — this transfers $STRK from the user's wallet into escrow. The contract returns an `on_chain_task_id`.
4. On approval: calls `Telegram.WebApp.sendData(JSON.stringify({ action: "payment_complete", on_chain_task_id, prompt }))`.
5. Telegram delivers this as a `web_app_data` message to the bot webhook.

---

### Step 4 — Bot processes `web_app_data` → verifies escrow → submits task

**File:** `telegram/smainer-bot/src/handlers.py`  
**Function:** `handle_webapp_data(update, bot, wallet_mgr, payment_mgr, relayer)`

1. Reads `message.web_app_data.data` (raw JSON string).
2. Parses JSON. **TM-003:** `action` value must be in `ALLOWED_WEBAPP_ACTIONS = frozenset({"wallet_connect", "wallet_disconnect", "payment_complete"})` — anything else is rejected.
3. For `action == "payment_complete"`:
   - Extracts `on_chain_task_id` and `prompt` from payload.
   - Looks up `starknet_address` via `wallet_mgr.get_linked_address(user_id)`.
   - **On-chain verification:** instantiates `PaymentVerifier()` and calls `await verifier.verify_escrow(on_chain_task_id, starknet_address)`.
     - Retry logic: up to 2 extra delayed attempts (2 s, 4 s backoff) if initial result is "not found" — handles tx propagation lag.
     - If still failing: sends "Payment verification failed" to user and returns.
   - Sends typing indicator + placeholder message: `"Payment confirmed (Task #N). Running compute task..."`.
   - Builds `InferenceRequest` with `telegram_user_id`, `chat_id`, `message_id`, `prompt`, `model`, `model_tier`, `starknet_address`, `cost_strk`.
   - Calls `await relayer.submit_inference(req, on_chain_task_id=int(on_chain_task_id))`.
   - On success: calls `await payment_mgr.reserve_payment(...)` to log the pending payment.
   - Edits placeholder to: `"Task #N submitted (abc12345...). Computing results..."`.

---

### Step 5 — Relayer receives task

**File:** `backend/relayer/src/relayer/api/routes.py`  
**Function:** `submit_task(task: TaskSubmission, _, redis, scheduler)` — `POST /api/v1/tasks`

1. Auth: `AuthenticatedUser` dependency checks `Authorization: Bearer {RELAYER_API_KEY}` header.
2. Validates `TaskSubmission` schema (Pydantic). Returns 422 if invalid.
3. Calls **payment verification** (Phase 8) via `PaymentVerifier` if `on_chain_task_id` is present.
4. Calls `await scheduler.submit_task(submission, verified_escrow=...)`.
5. Returns `HTTP 201` with `{"task_id": "..."}`.

**File:** `backend/relayer/src/relayer/api/ai_inference.py`  
**Function:** `store_callback_url(redis, task_id, callback_url)`

Called from `submit_task` — stores the bot's callback URL (`https://bot.smainer.io/api/callback/complete`) in Redis:
- Key: `task_callback:{task_id}` (TTL: 3600 s)
- Value prefix: `"complete:{url}"` — signals `deliver_result_callback` to use the URL as-is (not append `/callback/complete`).
- SSRF guard: `is_allowed_callback_url()` enforces HTTPS, allowlist, blocks private IP, loopback, credentials.

---

### Step 6 — Scheduler queues and assigns task

**File:** `backend/relayer/src/relayer/core/scheduler.py`  
**Class:** `JobScheduler`  
**Method:** `submit_task(submission, verified_escrow)`

Full detail in §5. Summary:

1. Generates `task_id = str(uuid.uuid4())`.
2. Calculates `adjusted_reward = int(base_reward * tier_multiplier)` using `TIER_REWARD_MULTIPLIERS` (`BASIC=1.0x`, `PRO=2.2x`, `PREMIUM=3.5x`).
3. Builds `task_data` dict and atomically `HSET task:{task_id}` + `LPUSH pending_tasks {task_id}` via a Redis pipeline.
4. Fires `asyncio.create_task(self._schedule_pending_tasks())`.

`_schedule_single_task(task_id)` picks an eligible node using `evaluate_node_ai_eligibility()` (checks model, privacy mode, capability contract freshness) then calls `assign_task_to_node(task_id, node_id)`.

`assign_task_to_node` atomically:
- Sets status → `ASSIGNED`, records `assigned_node_id`, `assigned_at`.
- Moves task from `pending_tasks` list → `assigned_tasks` set.
- Writes `task_assignments` hash: `{task_id: node_id}`.
- Adds to `task_timeouts` sorted set (score = UTC expiry timestamp).
- Sends `TaskAssignedEvent` JSON over the open WebSocket to the provider node.
- Fires an intermediate `"assigned"` callback (via `deliver_result_callback`) for UX feedback.

---

### Step 7 — Provider receives task, executes via Ollama

**File:** `backend/provider/src/provider/enhanced_api_client.py`  
**Class:** `EnhancedRelayerAPIClient`

1. Receives `TaskAssignedEvent` JSON from the WebSocket.
2. Parses to `TaskPayload`. Routes to `self.task_handler` → `ProviderDaemon._handle_task(task)`.

**File:** `backend/provider/src/provider/enhanced_executor.py`  
**Class:** `EnhancedSandboxedExecutor`  
**Method:** `execute_task(task)` → `_execute_ai_inference_task(task)`

1. Extracts `prompt = task.args.get("prompt") or task.code`, `model = task.args.get("model") or config.OLLAMA_DEFAULT_MODEL`.
2. Calls `MetricsCollector().start(model_id=model)` — starts effort tracking (Phase 8).
3. **Ollama HTTP call:**
   ```
   POST {config.OLLAMA_BASE_URL}/api/generate
   {
     "model": "<model>",
     "prompt": "<prompt>",
     "stream": false,
     "options": {"num_predict": 512}
   }
   ```
   Timeout: 120 s via `httpx.AsyncClient`.
4. Extracts `response_text = data["response"]`.
5. Calls `await metrics_collector.finish(data)` — captures token counts, timing.
6. Returns `TaskResult(status=COMPLETED, result=response_text, effort_metrics=...)`.

**Back in `EnhancedRelayerAPIClient`:**

7. Signs result via `StarknetSigner.sign_task_result(result)` — Pedersen hash + ECDSA over the result hash.
8. Sends `TaskCompletedEvent` JSON back to relayer over the same WebSocket.

---

### Step 8 — Relayer receives result, delivers callback

**File:** `backend/relayer/src/relayer/api/websocket.py`  
**Class:** `WebSocketManager`  
**Method:** `_handle_task_completed(websocket, node_id, event)`

1. Calls `await self.scheduler.complete_task(task_id, result_data, execution_time, effort_metrics)`.
   - Atomically: sets status → `COMPLETED`, stores result JSON, removes from `assigned_tasks` and `task_timeouts`.
   - Decrements node task counter.
2. Calls `await deliver_result_callback(redis, task_id, payload)`.

**File:** `backend/relayer/src/relayer/api/ai_inference.py`  
**Function:** `deliver_result_callback(redis, task_id, payload, *, final=True)`

1. Reads callback URL from `task_callback:{task_id}`.
2. **Enriches payload** with `chat_id`, `message_id`, `model`, `on_chain_task_id` from `task:{task_id}` hash in Redis — so the bot knows which Telegram message to edit.
3. Signs request: `_build_callback_headers(payload)` — `HMAC-SHA256(timestamp + "." + sorted_json_body, CALLBACK_SIGNING_SECRET)`.
4. `POST` to `https://bot.smainer.io/api/callback/complete` with headers `X-Smainer-Signature` and `X-Smainer-Timestamp`.
5. On 2xx: increments `CALLBACK_DELIVERY_TOTAL{result="success"}` Prometheus metric.
6. `final=True` → deletes callback URL key from Redis.

---

### Step 9 — Bot callback endpoint delivers result to Telegram

**File:** `telegram/smainer-bot/api/callback/complete.py`  
**Class:** `handler`  
**Method:** `handler.do_POST`

1. **Rate limit:** `check_rate_limit_by_ip("callback-complete", client_ip, max_requests=60, window_seconds=60)` — in-memory sliding window, returns `429` if exceeded.
2. Reads raw body bytes.
3. **HMAC verification:** calls `verify_callback_signature(raw_body, timestamp_header, sig_header)`:
   - `callback_auth.py` — rebuilds `HMAC-SHA256(timestamp + "." + body, secret)`, compares with `X-Smainer-Signature` using `hmac.compare_digest`.
   - Rejects if `abs(now - timestamp) > 300` (replay protection).
   - **Fail-closed:** if `CALLBACK_SIGNING_SECRET` is unset and `SMAINER_CALLBACK_DEV_BYPASS` is not `true`, rejects unconditionally.
4. Parses body as `TaskCallback` Pydantic model.
5. Calls `_handle_task_complete(callback, chat_id, message_id)`.

**Function:** `_handle_task_complete(callback, chat_id, message_id)`

1. For `status == "completed"`:
   - Reads result text from `callback.result["result"]` or `["stdout"]`.
   - Calls `bot.edit_message_text(chat_id, message_id, text, parse_mode=MARKDOWN)`.
   - Falls back to plain text if Markdown parse fails.
   - Calls `await payment_mgr.settle_payment(task_id)` — log-only in serverless (no Redis).
   - Fire-and-forget: `_mint_completion_badge(callback)` — POSTs to `POST /api/v1/nft/mint` on Relayer with `wallet_address` and `category=3` (COMPUTE_CERTIFICATE).
2. For failure: edits message to `"Compute failed: {error}"`, calls `payment_mgr.fail_payment`.

---

### Step 10 — On-chain settlement

**File:** `backend/relayer/src/relayer/settlement/settler.py`  
**Class:** `SettlementManager`  
**Method:** `settle_task(task_id, on_chain_task_id, provider_address, result_hash, effort_metrics, signature_r, signature_s, tier)`

1. Computes actual cost from `EffortMetrics` via `IEffortCalculator`.
2. Reads escrowed amount from Redis (`task:{task_id}` → `verified_escrow_amount`).
3. Computes user refund and fee split via `IRefundCalculator`:
   - Provider: 88% (`TOTAL_FEE_BPS=1500`, `TREASURY_FEE_BPS=1200`, `GAS_SUBSIDY_BPS=300`).
   - Treasury: 12%.
4. Calls `settle_with_effort()` on the escrow contract via `StarknetClient`.
5. Writes `SettlementRecord` to Redis with `status="settled"`.

---

## 3. Protocols, Endpoints, and Events

### REST Endpoints

| Direction | Method | URL | Auth | Purpose |
|-----------|--------|-----|------|---------|
| Telegram → Bot | POST | `https://bot.smainer.io/api/webhook` | `X-Telegram-Bot-Api-Secret-Token` | Receive Telegram updates |
| Bot → Relayer | POST | `https://api.smainer.io/api/v1/tasks` | `Authorization: Bearer {RELAYER_API_KEY}` | Submit compute task |
| Bot → Relayer | GET | `https://api.smainer.io/api/v1/ai/capable-nodes` | None (public since 2026-03-24) | List online nodes |
| Bot → Relayer | GET/SET | `https://api.smainer.io/api/v1/bot/kv/{key}` | Bearer | Wallet links, user prefs |
| Bot → Starknet RPC | `call_contract` | `settings.starknet_rpc_url` | None | Balance check, escrow verify |
| Relayer → Bot | POST | `https://bot.smainer.io/api/callback/complete` | `X-Smainer-Signature`, `X-Smainer-Timestamp` | Deliver AI result |
| Bot → Relayer | POST | `https://api.smainer.io/api/v1/nft/mint` | `X-API-Key` | Mint completion badge (fire-and-forget) |
| Relayer health | GET | `https://api.smainer.io/api/v1/health` | None | Health check |

### WebSocket Protocol (Relayer ↔ Provider)

**URL:** `wss://api.smainer.io/ws/{node_id}`

All messages are JSON objects with an `event_type` discriminator field.

| `event_type` | Direction | Struct | When |
|---|---|---|---|
| `node_register` | Provider → Relayer | `NodeRegisterEvent` | On connect; includes `node_id`, `starknet_address`, `hardware_spec`, `auth_signature`, `starknet_public_key`, optional `capability_contract` |
| `ack` | Relayer → Provider | `AckEvent` | After successful register/heartbeat; `ack_event_id` echoes the original `event_id` |
| `node_heartbeat` | Provider → Relayer | `NodeHeartbeatEvent` | Periodic (config-driven); `cpu_usage`, `memory_usage` |
| `task_assigned` | Relayer → Provider | `TaskAssignedEvent` | When scheduler assigns a task; includes `task_id`, `payload`, `requirements`, `timeout_seconds`, `token_amount` |
| `task_completed` | Provider → Relayer | `TaskCompletedEvent` | On successful inference |
| `task_failed` | Provider → Relayer | `TaskFailedEvent` | On error |
| `ping` / `pong` | Both | `PingEvent` / `PongEvent` | Keep-alive |
| `error` | Relayer → Provider | `ErrorEvent` | On parse failure, auth failure |

**Registration authentication:**  
`SignatureVerifier.verify_node_authentication_signature(node_id, starknet_address, timestamp_iso, auth_signature, starknet_public_key)` — verifies a Starknet ECDSA signature over `pedersen_hash(node_id, starknet_address, timestamp)`.

### Redis Event Streams (Internal PubSub)

| Stream | Consumer Groups | Events |
|--------|----------------|--------|
| `events:tasks` | `schedulers`, `monitors`, `analytics` | Task lifecycle events |
| `events:nodes` | `monitors`, `analytics` | Node connect/disconnect/heartbeat |
| `events:system` | `analytics` | System health events |

`EventBus.publish(event)` → `redis.xadd(stream, event_data, maxlen=10000, approximate=True)`.  
Consumers: `EventBus._consume_stream()` via `redis.xreadgroup(group, consumer, {stream: ">"}, count=10, block=1000)`.

### Redis Key Schema

| Key | Type | Purpose |
|-----|------|---------|
| `task:{task_id}` | Hash | Full task state (status, payload, requirements, result, routing fields) |
| `pending_tasks` | List | Queue of pending task IDs (LPUSH / LRANGE / LREM) |
| `assigned_tasks` | Set | Currently assigned task IDs |
| `task_assignments` | Hash | `{task_id: node_id}` mapping |
| `task_timeouts` | Sorted Set | Score = expiry UTC timestamp |
| `node:{node_id}` | Hash | Node info (hardware_spec, tier, starknet_address, capability_contract) |
| `heartbeat:{node_id}` | String | Last heartbeat ISO timestamp (TTL = `node_heartbeat_timeout`) |
| `tasks:{node_id}` | String | Current task count |
| `active_nodes` | Set | Registered and active node IDs |
| `task_callback:{task_id}` | String | Callback URL (TTL 3600 s); prefix `complete:` = full URL |
| `wallet:{user_id}` or `wallet:hmac:{hash}` | String | Encrypted/HMAC-keyed wallet address (via Relayer KV API) |
| `prefs:{user_id}:model` | String | User model preference |
| `events:tasks`, `events:nodes`, `events:system` | Stream | Redis Streams for event bus |

---

## 4. File / Function Map

### Telegram Bot (`telegram/smainer-bot/`)

```
api/
  webhook.py
    _verify_webhook_secret(secret_header)       — HMAC compare vs WEBHOOK_SECRET
    _process_update(update: dict)                — route update to handlers
    handler.do_POST                              — Vercel entry point

  callback/
    complete.py
      handler.do_POST                            — Vercel entry point for callbacks
      _handle_task_complete(callback, chat_id, message_id)  — edit message, settle
      _mint_completion_badge(callback)           — fire-and-forget NFT mint

src/
  handlers.py
    handle_start(update, bot, wallet_mgr)        — /start, deep-link wallet payload
    handle_link(update, bot, wallet_mgr)         — /link <address>
    handle_unlink(update, bot, wallet_mgr)       — /unlink
    handle_balance(update, bot, wallet_mgr)      — /balance → STRK balance
    handle_models(update, bot, relayer)          — /models → list nodes
    handle_set_model(update, bot, relayer)       — /model <name>
    handle_avail_nodes(update, bot, relayer)     — /availNodes
    handle_inference(update, bot, wallet_mgr, payment_mgr, relayer) — text → pay gate
    handle_webapp_data(update, bot, wallet_mgr, payment_mgr, relayer) — MiniApp sendData
    handle_one_tap_inference(...)                — one-tap flow (no wallet gate)
    infer_tier(model_name) -> ModelTier          — heuristic tier detection
    escape_md(text) -> str                       — Telegram MarkdownV1 escaping
    with_error_handling(handler_name)            — decorator: timeout + error catch

  wallet.py
    WalletManager.link_wallet(user_id, address)  — HMAC-keyed KV set, Fernet encrypt
    WalletManager.unlink_wallet(user_id)         — KV delete (new + legacy key)
    WalletManager.get_linked_address(user_id)    — KV get with legacy migration
    WalletManager.get_strk_balance(address)      — Starknet RPC via starknet_py
    WalletManager.has_sufficient_balance(address) — balance >= min_strk_balance
    WalletManager._normalize_address(address)    — lowercase 0x + zfill(64)

  wallet_crypto.py
    derive_wallet_key(user_id) -> str            — HMAC-SHA256 key derivation
    encrypt_address(address) -> str              — optional Fernet encryption
    decrypt_address(stored) -> str               — decrypt or return plaintext

  callback_auth.py
    verify_callback_signature(raw_body, timestamp, sig_header) -> bool
                                                 — HMAC-SHA256, 300 s replay window

  payment_verifier.py
    PaymentVerifier.verify_escrow(on_chain_task_id, expected_address) -> (bool, Optional[str])
    PaymentVerifier._rpc_verify(...)             — single Starknet RPC call
    normalize_address(address)                   — delegates to WalletManager._normalize_address

  relayer_client.py
    RelayerClient.__init__(callback_base_url)    — sets _complete_callback_url
    RelayerClient.submit_inference(req, on_chain_task_id) -> SubmitResult
    RelayerClient.get_task_status(task_id)       — poll task status
    RelayerClient.list_available_models()        — GET /api/v1/ai/capable-nodes
    RelayerClient.kv_get(key) / kv_set(key, val) — bot KV API (wallet, prefs)

  models.py
    InferenceRequest                             — prompt, model, tier, chat routing
    ModelTier (enum)                             — SMALL / MEDIUM / LARGE
    MODEL_TIER_REQUIREMENTS                      — tier → ram_gb, gpu_required, gpu_vram_gb
    SubmitResult                                 — ok, task_id, error_code, http_status
    TaskCallback                                 — callback body schema
    TaskSubmissionPayload                        — body for POST /api/v1/tasks

  config.py (Pydantic Settings)
    telegram_bot_token, webhook_secret
    relayer_api_url, relayer_api_key
    callback_signing_secret, callback_dev_bypass
    starknet_rpc_url, strk_token_address, smainer_contract_address
    min_strk_balance, prompt_cost_strk
    default_model, affiliate_address
    wallet_hmac_key, wallet_encryption_key
    one_tap_flow_enabled, wallet_flow_direct
    get_miniapp_connect_url()                    — builds MiniApp URL with params

  session.py
    touch_session(user_id)                       — update in-process TTL dict
    check_session_active(user_id) -> bool        — check 15-min idle
    invalidate_session(user_id)                  — remove session
```

### Relayer (`backend/relayer/src/relayer/`)

```
main.py                                          — FastAPI app, lifespan, router registration
config.py (Settings)                             — task_timeout_seconds, node_heartbeat_timeout,
                                                   callback_signing_secret, callback_allowed_hosts_list,
                                                   node_capability_ttl_seconds, enable_batch_submission

api/
  routes.py
    submit_task(task, _, redis, scheduler)       — POST /api/v1/tasks
    get_task(task_id, _, redis)                  — GET /api/v1/tasks/{task_id}
    list_tasks(_, redis)                         — GET /api/v1/tasks
    get_node_pool_summary(redis)                 — GET /api/v1/nodes/summary
    get_node_pool_status(redis)                  — GET /api/v1/nodes
    health(uptime)                               — GET /api/v1/health
    get_scheduler / get_node_pool / get_aggregator — FastAPI dependency providers

  ai_inference.py
    evaluate_node_ai_eligibility(node, model, privacy_mode) -> NodeCapabilityEligibility
    is_allowed_callback_url(url) -> bool         — SSRF-safe allowlist validation
    _host_resolves_to_private_ip(hostname)       — DNS + ipaddress check
    store_callback_url(redis, task_id, url)      — SET task_callback:{task_id}
    deliver_result_callback(redis, task_id, payload, *, final)  — HMAC POST to bot
    deliver_stream_chunk(redis, task_id, chunk, done)  — streaming chunk delivery
    _build_callback_headers(payload) -> dict     — X-Smainer-Signature + Timestamp
    _serialize_callback_payload(payload) -> bytes — deterministic sorted JSON
    list_capable_nodes(...)                      — GET /api/v1/ai/capable-nodes
    _parse_vram_gb(gpu_info) -> int              — regex VRAM extraction
    _nodes_for_vram(nodes, min_vram_gb)          — VRAM filter

  websocket.py
    WebSocketManager.connect_node(ws, node_id)
    WebSocketManager.send_task_to_node(node_id, task_event) -> bool
    WebSocketManager._handle_node_messages(ws, node_id)  — main WS receive loop
    WebSocketManager._process_node_event(ws, node_id, event)
    WebSocketManager._handle_node_register(...)  — verifies Starknet auth sig
    WebSocketManager._handle_node_heartbeat(...)
    WebSocketManager._handle_task_completed(...) — calls scheduler.complete_task + deliver_result_callback
    WebSocketManager._handle_task_failed(...)
    WebSocketManager._cleanup_connection(node_id, ws)

  dependencies.py
    AuthenticatedUser                            — Bearer token dependency
    RedisDB                                      — async Redis pool dependency
    WebhookVerified                              — HMAC webhook verification

core/
  scheduler.py
    JobScheduler.__init__(redis, node_pool, websocket_manager, starknet_client, cost_estimator)
    JobScheduler.start_background_tasks()        — starts _timeout_monitor + _pending_task_scheduler
    JobScheduler.submit_task(submission, verified_escrow) -> str  — assign UUID, store in Redis
    JobScheduler.assign_task_to_node(task_id, node_id) -> bool
    JobScheduler.complete_task(task_id, result_data, execution_time, effort_metrics)
    JobScheduler.fail_task(task_id, error_message)
    JobScheduler.get_task_status(task_id) -> Optional[dict]
    JobScheduler._schedule_pending_tasks()       — batch=10, loops over pending queue
    JobScheduler._schedule_single_task(task_id) — evaluates capability, calls assign_task_to_node
    JobScheduler._timeout_monitor()              — background loop, calls fail_task on expired tasks
    JobScheduler._pending_task_scheduler()       — background loop, periodically retries unscheduled tasks
    _normalize_model_id(model) -> Optional[str]  — lowercase, max 64 chars, regex validation
    TIER_REWARD_MULTIPLIERS                      — {BASIC: 1.0, PRO: 2.2, PREMIUM: 3.5}

  node_pool.py
    NodePool.register_node(node_id, address, hw_spec, pubkey, capability_contract)
    NodePool.update_heartbeat(node_id, cpu, memory)
    NodePool.disconnect_node(node_id)
    NodePool.get_node_info(node_id) -> Optional[NodeInfo]
    NodePool.list_active_nodes() -> List[NodeInfo]
    NodePool.increment_node_tasks(node_id) / decrement_node_tasks(node_id)
    calculate_tier_from_specs(gpu_vram_gb) -> NodeTier  — authoritative server-side tier

  event_bus.py
    EventBus.start() / stop()
    EventBus.subscribe(event_type, handler)
    EventBus.publish(event: BaseEvent) -> str    — redis.xadd
    EventBus._consume_stream(stream, group, consumer)  — redis.xreadgroup loop
    EventBus._cleanup_old_events()               — trim streams

  aggregator.py
    ResultAggregator                             — collects partial results from multi-node tasks

settlement/
  settler.py
    SettlementManager.settle_task(...)           — compute cost, refund, on-chain settle_with_effort()

  refund.py
    RefundCalculator                             — BPS split: 8800 provider, 1200 treasury

chain/
  verifier.py
    SignatureVerifier.verify_node_authentication_signature(...)  — Pedersen + ECDSA

verification/
  __init__.py
    PaymentVerifier                              — on-chain escrow pre-check (Phase 8)

pricing/
  cost_estimator.py
    CostEstimator.estimate_max_cost(input_tokens, model_id, tier) -> CostEstimate
```

### Provider (`backend/provider/src/provider/`)

```
main.py
  ProviderDaemon.__init__(config)               — initialises executor, signer, api_client
  ProviderDaemon.start()                        — starts api_client + system_monitor tasks
  ProviderDaemon._handle_task(task) -> SignedResult — calls executor.execute_task + signer.sign
  ProviderDaemon._setup_signal_handlers()       — SIGTERM/SIGINT → graceful shutdown

enhanced_api_client.py
  EnhancedRelayerAPIClient.__init__(config, task_handler)
  EnhancedRelayerAPIClient.start()              — WS connect loop with circuit breakers
  EnhancedRelayerAPIClient._send_register()     — sends NodeRegisterEvent with Starknet auth sig
  EnhancedRelayerAPIClient._handle_messages()   — WS receive loop; TaskAssignedEvent → task_handler
  EnhancedRelayerAPIClient._send_heartbeat()    — periodic NodeHeartbeatEvent
  validate_wallet_file_permissions(path)        — checks 0600, owner UID
  load_wallet_file_secure(wallet_path)          — permission check before json.load

enhanced_executor.py
  EnhancedSandboxedExecutor.__init__(config)
  EnhancedSandboxedExecutor.execute_task(task) -> TaskResult
  EnhancedSandboxedExecutor._execute_task_with_monitoring(task, execution_dir)
    → _execute_ai_inference_task(task)           — Ollama path (AI_INFERENCE type)
    → _execute_hash_task_enhanced(task, dir)     — subprocess Python script
    → _execute_matrix_task_enhanced(task, dir)   — subprocess numpy script
    → _execute_custom_task_enhanced(task, dir)   — requires ENABLE_CUSTOM_TASKS=true
  EnhancedSandboxedExecutor.cancel_task(task_id) — SIGTERM → SIGKILL, 5 s guarantee
  ProcessTracker.register_process / force_terminate_task(task_id, timeout)

signer.py
  StarknetSigner.sign_task_result(result) -> SignedResult
    — pedersen_hash(result_hash) + message_signature(hash, priv_key)

config.py (ProviderConfig)
  NODE_ID, OLLAMA_BASE_URL, OLLAMA_DEFAULT_MODEL
  MAX_CONCURRENT_TASKS, SANDBOX_TEMP_DIR
  ENABLE_CUSTOM_TASKS (default False)
  RESOURCE_MONITORING_INTERVAL
  get_ws_url_with_node_id() -> str             — wss://api.smainer.io/ws/{NODE_ID}

circuit_breaker.py
  resilience_manager                           — global CircuitBreakerManager
  CircuitBreakerManager.create_circuit_breaker(name, failure_threshold, recovery_timeout, ...)
  CircuitBreakerManager.create_backoff_policy(name, base_delay, max_delay, multiplier, jitter)
```

---

## 5. Relayer Scheduling and Redis/PubSub Internals

### Task State Machine

```
                         submit_task()
                              │
                         [PENDING] ──── lpush pending_tasks
                              │
                    _schedule_single_task()
                              │
            evaluate_node_ai_eligibility()
             ┌────────────────┴────────────────────┐
           ELIGIBLE                          INELIGIBLE (wait)
             │
        assign_task_to_node()
             │
         [ASSIGNED] ──── assigned_tasks (set)
                    ──── task_timeouts (zset, score=expiry)
                    ──── TaskAssignedEvent → WebSocket → Provider
             │
       Provider executes, sends TaskCompletedEvent
             │
        complete_task()
             │
        [COMPLETED] ──── result stored in task:{id}.result (JSON)
                    ──── removed from assigned_tasks, task_timeouts
             │
        deliver_result_callback()
             │
         Relayer POSTs to bot callback URL
                                          ── OR ──
       Provider sends TaskFailedEvent
             │
        fail_task()
             │
         [FAILED] ──── error_message stored
             │
        deliver_result_callback()
                                          ── OR ──
       _timeout_monitor() sees expiry
             │
        fail_task() with "Task timed out"
```

### Scheduling Algorithm Detail

**`_schedule_pending_tasks()`** (`scheduler.py:_schedule_pending_tasks`):

```python
pending_count = await redis.llen("pending_tasks")
batch_size = min(10, pending_count)
task_ids = await redis.lrange("pending_tasks", 0, batch_size - 1)
for task_id in task_ids:
    await _schedule_single_task(task_id)
```

**`_schedule_single_task(task_id)`** (`scheduler.py:_schedule_single_task`):

1. Reads `task:{task_id}` hash from Redis.
2. Checks `routing_is_ai_task`, `routing_model`, `routing_privacy_mode`, `routing_reason_code`.
3. Calls `node_pool.list_active_nodes()` — filters by `heartbeat:{node_id}` TTL presence + grace period.
4. For each active node, calls `evaluate_node_ai_eligibility(node, model, privacy_mode)`:
   - Returns `CapabilityEligibilityReason.ELIGIBLE` if:
     - `node.capability_contract` exists and is not stale (`declared_at` within TTL).
     - `requested_model in contract.supported_models`.
     - `requested_privacy_mode in contract.supported_privacy_modes`.
   - Returns specific denial codes otherwise (`MODEL_NOT_SUPPORTED`, `CAPABILITY_CONTRACT_STALE`, etc.).
5. Picks first eligible node with fewest `current_tasks` (load balance).
6. Calls `assign_task_to_node(task_id, node_id)` (atomic pipeline).

### Background Scheduler Loops

**`_timeout_monitor()`**: runs every 30 s. Reads `task_timeouts` sorted set, finds tasks with score ≤ `time.time()`, calls `fail_task(task_id, "Task timed out")`.

**`_pending_task_scheduler()`**: runs every 5 s. Calls `_schedule_pending_tasks()` so tasks that couldn't be scheduled immediately (no eligible node) are retried.

### Event Bus (Redis Streams)

`EventBus` (`event_bus.py`) uses `XADD` / `XREADGROUP` for fan-out between scheduler, monitor, and analytics consumer groups:

- **`publish(event)`**: `redis.xadd(stream, {"event_id": ..., "event_type": ..., "timestamp": ..., "data": json}, maxlen=10000)`.
- **Consumers** call `redis.xreadgroup(group, consumer_name, {stream: ">"}, count=10, block=1000)` in a while loop.
- On successful processing: `redis.xack(stream, group, message_id)`.
- Consumer groups created at startup with `xgroup_create(..., mkstream=True)`.
- Old events cleaned up by `_cleanup_old_events()` via periodic `xdel`.

---

## 6. Provider WebSocket Execution and Ollama Inference

### WebSocket Connection Lifecycle

**Provider side** (`enhanced_api_client.py`):

1. `start()` enters reconnect loop (circuit breaker: 3 failures → 30 s recovery).
2. `websockets.connect(wss://api.smainer.io/ws/{NODE_ID}, extra_headers={"Authorization": ...})`.
3. Sends `NodeRegisterEvent`:
   ```json
   {
     "event_type": "node_register",
     "event_id": "<uuid>",
     "node_id": "<NODE_ID>",
     "starknet_address": "<0x...>",
     "starknet_public_key": "<0x...>",
     "timestamp": "<ISO>",
     "auth_signature": {"r": "0x...", "s": "0x..."},
     "hardware_spec": { "gpu_info": "...", "gpu_vram_gb": 24, "ram_gb": 64, "cpu_threads": 16, ... },
     "capability_contract": { "contract_version": "1.0", "supported_models": [...], "supported_privacy_modes": [...], "declared_at": "..." }
   }
   ```
4. Awaits `AckEvent` (timeout: `REGISTRATION_ACK_TIMEOUT = 30 s`).
5. After ack: starts heartbeat loop (periodic `NodeHeartbeatEvent`) and message receive loop.

**Relayer side** (`websocket.py`):

`_handle_node_register` verifies the Starknet ECDSA signature via `SignatureVerifier.verify_node_authentication_signature`. On success, calls `node_pool.register_node(...)` (server-side tier calculation is authoritative — provider-reported tier is logged but not trusted).

### Ollama Inference Path

**`_execute_ai_inference_task(task)`** (`enhanced_executor.py`):

```python
ollama_url = f"{config.OLLAMA_BASE_URL}/api/generate"
# default: http://localhost:11434/api/generate

body = {
    "model": model,         # e.g. "llama3.1:8b"
    "prompt": prompt,
    "stream": False,
    "options": {"num_predict": 512},
}

async with httpx.AsyncClient(timeout=httpx.Timeout(120.0)) as client:
    resp = await client.post(ollama_url, json=body)
    resp.raise_for_status()
    data = resp.json()

response_text = data["response"]
```

On `httpx.ConnectError`: returns `TaskResult(status=FAILED, stderr="AI inference engine not available -- Ollama is not running")`. This is the most common failure mode — Ollama must be running before the provider daemon.

**Phase 8 effort metrics**: `MetricsCollector` wraps `start(model_id)` / `finish(ollama_response_json)` to extract `eval_count` (output tokens) and `prompt_eval_count` (input tokens) from Ollama's response. Used for effort-based settlement.

### Task Signing

**`StarknetSigner.sign_task_result(result)`** (`signer.py`):

1. Computes `SHA-256(result.result or result.stdout)` → result hash.
2. Computes Pedersen hash over `(node_id_felt, result_hash_felt)`.
3. Signs with `message_signature(msg_hash=pedersen_hash, priv_key=int(private_key, 16))` (starknet_py).
4. Returns `SignedResult` with `signature_r`, `signature_s`.

The provider's wallet private key is loaded from `~/.smainer/wallet.json` (permission check: must be `0600`, owned by current user).

---

## 7. Payment and Wallet — Outside-Telegram Design

Wallet charging happens entirely **outside Telegram**. The bot never sees private keys, never initiates transactions, and never holds user funds.

### Wallet Linking Flow

```
User runs /link 0x...  (or MiniApp wallet_connect action)
  │
  ▼ WalletManager.link_wallet(user_id, address)
  │  1. _normalize_address(address): lowercase 0x + zfill(64), rejects non-hex
  │  2. derive_wallet_key(user_id):
  │       if WALLET_HMAC_KEY set → HMAC-SHA256(WALLET_HMAC_KEY, str(user_id)) → "wallet:hmac:{hex}"
  │       else → "wallet:{user_id}"
  │  3. encrypt_address(normalized):
  │       if WALLET_ENCRYPTION_KEY set → Fernet(key).encrypt(address.encode())
  │       else → plaintext
  │  4. await kv_client.kv_set(kv_key, encrypted_value)
  │       → PUT https://api.smainer.io/api/v1/bot/kv/{key}
  │         (backed by Relayer's Redis)
  ▼
Wallet address stored: HMAC-keyed key + optional ciphertext value
```

### Balance Check

`WalletManager.get_strk_balance(starknet_address)`:

```python
from starknet_py.contract import Contract
from starknet_py.net.full_node_client import FullNodeClient

client = FullNodeClient(node_url=settings.starknet_rpc_url)
token_addr = int(settings.strk_token_address, 16)
# 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
contract = await Contract.from_address(address=token_addr, provider=client)
(balance,) = await contract.functions["balance_of"].call(int(address, 16))
# Returns wei (1 STRK = 1e18)
```

On RPC failure → raises `BalanceUnavailableError`.

### On-Chain Escrow Verification

`PaymentVerifier._rpc_verify(on_chain_task_id, normalized_expected)`:

```python
from starknet_py.net.client_models import Call
from starknet_py.hash.selector import get_selector_from_name

result = await client.call_contract(
    Call(
        to_addr=int(settings.smainer_contract_address, 16),
        selector=get_selector_from_name("get_task"),
        calldata=[on_chain_task_id],
    )
)
# result[0] = task creator address (felt252)
task_creator = hex(result[0])
# Verify normalized_expected == normalize_address(task_creator)
```

- 3 retries with `0.5 s * 2^attempt` backoff.
- Fail-closed: if all retries exhausted, returns `(False, "Payment verification failed: ...")`.
- Address validation before any RPC call: `normalize_address(expected_address)` (SEC-002).

### MiniApp Payment Flow (Outside Telegram)

The React MiniApp (`telegram/miniapp/src/`) opens in `WebApp.openWebApp()`:

1. **Wallet detection:** `connectors.filter(c => c.available())` — if empty (Telegram WebView has no extensions), shows "Open in Browser" via `Telegram.WebApp.openLink(url)`.
2. **If browser:** user connects ArgentX/Braavos, approves `$STRK` allowance.
3. **Contract call:** `create_task(token_address, base_amount, required_tier, task_hash)` on the escrow contract. Returns `on_chain_task_id`.
4. **Sends result to bot:** `Telegram.WebApp.sendData(JSON.stringify({ action: "payment_complete", on_chain_task_id, prompt }))`.

The MiniApp **never sends** private keys to the bot. The bot never holds user funds. The only on-chain action the bot takes is reading (via `call_contract`) to verify the task exists and was created by the expected address.

### Settlement (Post-Inference)

After result delivery, `SettlementManager.settle_task()` calls `settle_with_effort()` on the escrow contract:

- **Provider:** 8800 BPS (88%) of the escrowed amount.
- **Treasury:** 1200 BPS (12%) — split into `TREASURY_FEE_BPS=1200`, `GAS_SUBSIDY_BPS=300` internally.

The settlement transaction is submitted by the Relayer's own Starknet account, not the user's wallet.

---

## 8. Debugging Checklist

### 1. Webhook not receiving updates

```bash
# Verify webhook is registered
curl "https://api.telegram.org/bot{TOKEN}/getWebhookInfo"
# Expected: "url": "https://bot.smainer.io/api/webhook", "pending_update_count": 0

# Check Vercel function logs
vercel logs --app smainer-bot --since 1h

# Re-register webhook if needed
curl -X POST "https://api.smainer.io/api/v1/bot/setup-webhook" \
  -H "Authorization: Bearer {RELAYER_API_KEY}"
```

**`WEBHOOK_SECRET` mismatch** → `handler.do_POST` returns 403. Check Vercel env var matches `setWebhook` call's `secret_token`.

### 2. Task never appears in relayer

```bash
# Check bot can reach relayer
curl https://api.smainer.io/api/v1/health

# Verify bearer token is set in Vercel env
# Look for "Relayer rejected task" in bot function logs

# Check relayer logs on DO
ssh root@138.197.11.147
journalctl -u smainer-relayer -f
```

Key log lines to look for:
- `"Task submitted" task_id=...` — relayer accepted
- `"Failed to submit task"` — check `status_code` in log

### 3. Task stuck in PENDING (no nodes)

```bash
# List active nodes
curl https://api.smainer.io/api/v1/ai/capable-nodes

# Check node pool directly in Redis on DO
redis-cli SMEMBERS active_nodes
redis-cli EXISTS heartbeat:{node_id}   # should have TTL
redis-cli LLEN pending_tasks           # how many waiting
redis-cli HGETALL task:{task_id}       # check routing_reason_code
```

If `routing_reason_code` is non-empty, the task has a capability mismatch. Common values:
- `REQUEST_PRIVACY_MODE_MISSING` — payload missing `privacy_mode`
- `MODEL_NOT_SUPPORTED` — node's `capability_contract.supported_models` doesn't include requested model
- `CAPABILITY_CONTRACT_STALE` — node's contract TTL expired (provider must re-register)

### 4. Task assigned but no result callback

```bash
# Check if callback URL is still in Redis
redis-cli GET "task_callback:{task_id}"

# Check WebSocket logs on provider (Runpod)
ssh -i ~/.ssh/runpod_smainer hhh3ywqmbc978g-64410d45@ssh.runpod.io
tail -f /root/smainer-backend/provider/provider.log

# Check Ollama is running
curl http://localhost:11434/api/tags
```

If `task_callback:{task_id}` is empty, the callback URL was never stored (check `store_callback_url` was called in `submit_task`).

### 5. Callback arrives but HMAC fails

Check in bot function logs: `"SEC-001: CALLBACK_SIGNING_SECRET not set"` or `"Timestamp too old/future"`.

- `CALLBACK_SIGNING_SECRET` must match between Relayer (`backend/relayer/.env`) and Bot (Vercel env var).
- Clock skew > 300 s between DO and Vercel → timestamp rejected. Check NTP on DO: `timedatectl show`.

```python
# Reproduce HMAC locally
import hmac, hashlib, time, json

secret = "your_secret"
payload = {"task_id": "...", "status": "completed", ...}
body = json.dumps(payload, separators=(",",":"), sort_keys=True).encode()
timestamp = str(int(time.time()))
sig = hmac.new(secret.encode(), timestamp.encode() + b"." + body, hashlib.sha256).hexdigest()
```

### 6. Payment verification fails

```bash
# In bot logs look for:
# "metric.verification-failed user=... task=... reason=..."
# "Escrow verification failed after 3 retries"

# Confirm contract address is set in Vercel env
# SMAINER_CONTRACT_ADDRESS=0x...

# Manual RPC check (starknet-py)
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.client_models import Call
from starknet_py.hash.selector import get_selector_from_name

client = FullNodeClient(node_url="https://starknet-mainnet.infura.io/...")
result = await client.call_contract(Call(
    to_addr=int("0x...", 16),
    selector=get_selector_from_name("get_task"),
    calldata=[on_chain_task_id],
))
print(hex(result[0]))  # should match user's wallet address
```

### 7. Ollama connection error

Provider log shows: `"AI inference engine not available -- Ollama is not running"`.

```bash
# On Runpod
curl http://localhost:11434/api/tags  # should list models
# If not running:
ollama serve &
# Check OLLAMA_BASE_URL in provider .env
cat /root/smainer-backend/provider/.env | grep OLLAMA
```

### 8. Provider WebSocket disconnect loop

Look for repeated `"Starting Enhanced Relayer API client"` in provider logs — indicates circuit breaker tripping.

```bash
# Check WS endpoint is reachable
curl -v https://api.smainer.io/api/v1/health

# Check nginx WS upgrade headers on DO
nginx -T | grep -A3 "location /ws"

# Check auth signature — wallet.json permissions
ls -la ~/.smainer/wallet.json  # must be 0600
```

---

## 9. Common Failure Modes

| Symptom | Root Cause | Where to Look | Fix |
|---------|-----------|---------------|-----|
| Bot ignores all messages | Webhook not registered or secret mismatch | `getWebhookInfo`, Vercel function logs | Re-register webhook, fix `WEBHOOK_SECRET` |
| "No compute nodes online" | No provider connected or heartbeat expired | `GET /api/v1/ai/capable-nodes`, Redis `active_nodes` | Restart provider daemon on Runpod |
| "Payment verification failed" | On-chain tx not indexed yet | Bot logs `metric.verification-failed` | Wait 30 s, retry; check `SMAINER_CONTRACT_ADDRESS` |
| Task stuck in PENDING forever | Capability mismatch (model/privacy_mode) | Redis `HGET task:{id} routing_reason_code` | Update node `capability_contract` with correct models |
| Callback never arrives | Relayer can't reach bot URL | Relayer logs `Callback delivery failed` | Verify `bot.smainer.io` DNS, Vercel deployment live |
| Callback rejected (403) | HMAC secret mismatch or clock skew | Bot logs `SEC-001`, `Timestamp too old` | Sync secrets, check NTP on DO |
| AI response is empty | Ollama model not loaded | Provider logs `httpx.ConnectError` or empty `response` | `ollama pull llama3.1:8b`, check `OLLAMA_DEFAULT_MODEL` |
| Node registers but tasks never sent | WS manager not wired to scheduler | Relayer startup logs, `global_scheduler` check | Ensure `main.py` sets `scheduler.websocket_manager` |
| `BalanceUnavailableError` | Starknet RPC unreachable | Bot logs `Balance check failed` | Check `STARKNET_RPC_URL` in Vercel env |
| `WalletSecurityError` on provider | wallet.json permissions not 0600 | Provider startup logs | `chmod 600 ~/.smainer/wallet.json` |
| Vercel returns stale response | Build failed, Vercel serving cached | Compare asset hash vs previous deploy | Check Vercel build logs for Python import errors |
| NFT mint silent failure | Relayer `/api/v1/nft/mint` not implemented or error | Bot logs `NFT badge mint skipped` | Non-blocking — user still gets result; fix relayer endpoint separately |
| Provider sends task but result never appears | `task_callback:{task_id}` already deleted | Redis `GET task_callback:{id}` empty | Investigate if `deliver_result_callback` ran twice (duplicate completion) |

---

*Document generated from source code inspection of `telegram/smainer-bot/`, `backend/relayer/`, and `backend/provider/`. All file paths are relative to the monorepo root.*
