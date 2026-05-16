# Smainer Privacy AI - End-to-End Data Flow

> Scope: Full request lifecycle from Telegram user message to AI result delivery, including
> wallet/payment gating, relayer scheduling, Redis internals, provider WebSocket execution,
> Ollama inference, and result callbacks. Wallet charging happens outside Telegram.
> Audience: Developers who want to follow the code and debug production issues.
> Last updated: 2026-05-05

---

## Table of Contents

1. System Overview
2. Request Lifecycle (step by step)
3. Protocols, Endpoints, and Events Reference
4. File and Function Map
5. Relayer Scheduling and Redis Internals
6. Provider WebSocket Execution and Ollama Inference
7. Payment and Wallet - Outside Telegram Design
8. Debugging Checklist
9. Common Failure Modes

---

## 1. System Overview

```
User (Telegram client)
  -> Telegram webhook POST
  -> Bot (Vercel) telegram/smainer-bot/api/webhook.py
      -> handlers.py
      -> Relayer KV API for wallet + session + prefs
  -> Payment gate
      - Direct flow (URL button) or MiniApp (WebApp)
  -> MiniApp (telegram/miniapp)
      - create_tiered_task on Starknet
      - notify bot via sendData or POST /api/payment-complete
  -> Relayer (FastAPI + Redis) backend/relayer/src/relayer
      - POST /api/v1/tasks
      - JobScheduler + NodePool + Redis
  -> Provider (Runpod) backend/provider/src/provider
      - WebSocket task execution + Ollama
  -> Relayer callback delivery
      - POST https://bot.smainer.io/api/callback/complete
  -> Bot edits Telegram message with result
```

---

## 2. Request Lifecycle (step by step)

### Step 1 - Telegram update arrives at the bot webhook

File: telegram/smainer-bot/api/webhook.py

1. handler.do_POST verifies X-Telegram-Bot-Api-Secret-Token via _verify_webhook_secret() using hmac.compare_digest.
2. Parses JSON and calls asyncio.run(_process_update(update)).
3. _process_update instantiates Bot, RelayerClient, WalletManager, PaymentManager per invocation.
4. Routes message.web_app_data to handle_webapp_data() or text to handle_inference() or handle_one_tap_inference() depending on settings.one_tap_flow_enabled.

### Step 2 - Standard Pay and Compute gate (text prompt)

File: telegram/smainer-bot/src/handlers.py

handle_inference(update, bot, wallet_mgr, payment_mgr, relayer):

1. touch_session(user_id) writes a KV-backed session timestamp (sess: prefix; TTL = 15 min + 60 s).
2. Resolves model from relayer.kv_get(prefs:{user_id}:model) or settings.default_model.
3. infer_tier(model_name) maps model name to ModelTier.{SMALL, MEDIUM, LARGE}.
4. list_available_models() calls relayer /api/v1/nodes (Bearer) first, falls back to /api/v1/ai/capable-nodes.
5. If wallet linked, WalletManager.has_sufficient_balance() checks STRK balance via Starknet RPC.
6. Sends a placeholder message with a temporary callback button (payment_preparing).
7. generate_nonce(user_id, chat_id) stores a pay_nonce:{nonce} key in relayer KV with two-phase TTL.
8. Builds pay URL:
   - settings.wallet_flow_direct = True: URL button via settings.get_direct_pay_url(...)
   - settings.wallet_flow_direct = False: WebApp button via settings.get_miniapp_pay_url(...)
9. Edits the placeholder keyboard to show the final Pay and Compute button and stops.

### Step 2b - One-tap approve flow (session API)

Files:
- telegram/smainer-bot/src/handlers.py (handle_one_tap_inference)
- backend/relayer/src/relayer/api/routes.py (sessions endpoints)
- backend/relayer/src/relayer/listeners/approval_listener.py

1. handle_one_tap_inference registers the prompt via POST /api/v1/sessions/prompt.
2. MiniApp connects wallet and posts to /api/v1/sessions/wallet.
3. ApprovalListener polls STRK Approval events and maps dust nonces to sessions.
4. Session keys are stored under session:prompt, session:wallet, session:dust_lookup, session:status.

### Step 3 - MiniApp payment (outside Telegram)

Files:
- telegram/miniapp/src/hooks/usePayment.ts
- telegram/miniapp/src/payment/factory.ts
- telegram/miniapp/src/payment/strategies/AbstractPaymentStrategy.ts
- telegram/miniapp/src/payment/strategies/StarknetWalletStrategy.ts
- telegram/miniapp/src/payment/strategies/TelegramWebViewStrategy.ts
- telegram/miniapp/src/payment/strategies/BotLinkedStrategy.ts
- telegram/miniapp/src/lib/starknet.ts

Flow details:

1. usePayment resolves environment (factory.resolveEnvironment):
   - starknet-wallet: not Telegram WebView and account connected
   - bot-linked-readonly: botLinkedWallet present
   - telegram-webview: Telegram WebView without bot linked
2. StarknetWalletStrategy:
   - checkAllowance() calls STRK allowance via RPC
   - builds multicall: optional approve + create_tiered_task
   - hashPrompt(prompt) uses Web Crypto SHA-256 and reduces to felt252
   - waits for transaction receipt and parses TaskCreated event to extract on_chain_task_id
   - fallback: call task_count if TaskCreated not found
3. TelegramWebViewStrategy opens external browser for wallet signing.
4. BotLinkedStrategy posts to /api/payment-request on the bot API (note: endpoint not implemented in telegram/smainer-bot).
5. AbstractPaymentStrategy.notifyBot:
   - inside Telegram WebView: Telegram.WebApp.sendData(JSON payload)
   - outside: POST {botApiUrl}/api/payment-complete with init_data and nonce

Notification payload fields:

```json
{
  "action": "payment_complete",
  "on_chain_task_id": "<u256-as-string>",
  "prompt": "...",
  "tier": "BASIC|PRO|PREMIUM",
  "chat_id": "<telegram chat id>",
  "message_id": "<telegram message id>",
  "starknet_address": "<0x...>"
}
```

### Step 4 - Bot handles payment completion

Files:
- telegram/smainer-bot/src/handlers.py (handle_webapp_data)
- telegram/smainer-bot/api/payment_complete.py (POST /api/payment-complete)

WebApp path (sendData):

1. handle_webapp_data enforces ALLOWED_WEBAPP_ACTIONS and touch_session().
2. For payment_complete:
   - check_session_active(user_id) with 15-minute idle timeout
   - resolve wallet address (payload or KV)
   - PaymentVerifier.verify_escrow(on_chain_task_id, expected_address) with retry (2 s, 4 s) on not found
   - send placeholder, then relayer.submit_inference(..., on_chain_task_id=...)
   - payment_mgr.reserve_payment(...) then edit placeholder with task id

Standalone browser path:

1. payment_complete.py verifies Telegram initData HMAC or a bot-issued nonce (verify_and_consume_nonce).
2. Reuses the same escrow verification and relayer submission flow.

### Step 5 - Relayer task submission

File: backend/relayer/src/relayer/api/routes.py

POST /api/v1/tasks (submit_task):

1. Requires Authorization: Bearer $RELAYER_API_KEY.
2. Validates TaskSubmission schema.
3. PaymentVerifier.verify_escrow is required when settings.require_payment_verification is true.
4. Dedup: escrow:task:{on_chain_task_id}:submitted (SET NX, 24h TTL).
5. scheduler.submit_task(...) writes task data and enqueues pending_tasks.
6. onchain_task_map:{on_chain_task_id} -> task_id (TTL 48h).
7. Stores callback URL:
   - payload.complete_callback_url (exact URL) or payload.callback_url (base)
   - task_callback:{task_id} with prefix complete: for full URLs

### Step 6 - Scheduling and assignment

File: backend/relayer/src/relayer/core/scheduler.py

1. submit_task writes task:{task_id} hash and LPUSH pending_tasks.
2. _schedule_pending_tasks processes up to 10 tasks per sweep.
3. _schedule_single_task:
   - reads routing_model and routing_privacy_mode from task hash
   - validates privacy_mode immutability against payload
   - evaluates AI eligibility via evaluate_node_ai_eligibility (capability contract required)
   - chooses best node by tier priority then low current_tasks
4. assign_task_to_node updates task status, sets task_assignments, task_timeouts, and sends TaskAssignedEvent.
5. deliver_result_callback sends an intermediate assigned status with final=False.
6. _pending_task_scheduler runs every 10 s; _timeout_monitor runs every 30 s and marks TIMEOUT.

### Step 7 - Provider executes task

Files:
- backend/provider/src/provider/enhanced_api_client.py
- backend/provider/src/provider/enhanced_executor.py
- backend/provider/src/provider/metrics/collector.py

1. WebSocket receives task_assigned and maps payload -> TaskPayload args.
2. EnhancedSandboxedExecutor._execute_ai_inference_task:
   - POST $OLLAMA_BASE_URL/api/generate
   - body: model, prompt, stream=false, options.num_predict=512
   - httpx timeout = 120 s
3. MetricsCollector.start/finish collects input_tokens, output_tokens, gpu_seconds, execution_time_seconds.
4. _send_task_result_enhanced creates task_completed event with result_data, execution_time, signature, result_hash, effort_metrics.

### Step 8 - Relayer validates result and delivers callback

File: backend/relayer/src/relayer/api/websocket.py

1. _handle_task_completed verifies result signature with SignatureVerifier.verify_node_result_signature.
2. scheduler.complete_task updates task status and clears timeout tracking.
3. ResultAggregator.add_verified_result stores result:{task_id} and pushes to verified_results list.
4. deliver_result_callback posts to the bot callback URL (HMAC signed).

Callback signing details:

- Headers: X-Smainer-Signature and X-Smainer-Timestamp
- Signature: HMAC-SHA256(timestamp + "." + raw request body)

### Step 9 - Bot callback edits the message

File: telegram/smainer-bot/api/callback/complete.py

1. Rate limit by IP (60/min).
2. verify_callback_signature validates HMAC and replay window.
3. TaskCallback model is parsed; chat_id and message_id are required in the body.
4. On success: edit message text, call payment_mgr.settle_payment, and fire-and-forget NFT mint.
5. On failure: edit message with error and mark payment failed.

### Step 10 - Settlement (post inference)

Files:
- backend/relayer/src/relayer/settlement/settler.py
- backend/relayer/src/relayer/settlement/refund.py
- backend/relayer/src/relayer/pricing/constants.py

1. SettlementManager.settle_task computes actual cost from EffortMetrics.
2. Reads adjusted_reward and affiliate_address from task:{task_id}.
3. RefundCalculator.compute_refund applies BPS split (no algorithm details here).
4. StarknetClient.settle_with_effort submits the on-chain settlement (or settle_with_effort_and_affiliate when affiliate_address is present).
5. Settlement dedup key: settlement:{on_chain_task_id}:complete (24h).

---

## 3. Protocols, Endpoints, and Events Reference

### REST Endpoints

| Direction | Method | URL | Auth | Purpose |
|-----------|--------|-----|------|---------|
| Telegram -> Bot | POST | https://bot.smainer.io/api/webhook | X-Telegram-Bot-Api-Secret-Token | Telegram updates |
| MiniApp -> Bot | POST | https://bot.smainer.io/api/payment-complete | initData HMAC or nonce | Browser payment completion |
| Bot -> Relayer | POST | https://api.smainer.io/api/v1/tasks | Authorization: Bearer $RELAYER_API_KEY | Submit task |
| Bot -> Relayer | GET | https://api.smainer.io/api/v1/nodes | Bearer | Node inventory |
| Bot -> Relayer | GET | https://api.smainer.io/api/v1/ai/capable-nodes | None | AI eligible nodes |
| Bot -> Relayer | GET | https://api.smainer.io/api/v1/nodes/summary | Bearer | Node summary |
| Bot -> Relayer | GET/PUT/DELETE | https://api.smainer.io/api/v1/bot/kv/{key} | Bearer | Wallets, prefs, sessions, nonces |
| Bot -> Relayer | POST | https://api.smainer.io/api/v1/sessions/prompt | Bearer | One-tap session start |
| MiniApp -> Relayer | POST | https://api.smainer.io/api/v1/sessions/wallet | Bearer | One-tap session wallet registration |
| Bot -> Relayer | GET | https://api.smainer.io/api/v1/sessions/{chat_id}/status | Bearer | One-tap session status |
| Relayer -> Bot | POST | https://bot.smainer.io/api/callback/complete | X-Smainer-Signature + X-Smainer-Timestamp | Task result callback |
| Bot -> Relayer | POST | https://api.smainer.io/api/v1/nft/mint | X-API-Key | Mint completion badge |
| Relayer health | GET | https://api.smainer.io/api/v1/health | None | Health check |

### WebSocket Protocol (Relayer <-> Provider)

URL: wss://api.smainer.io/ws/node/{node_id}

Relayer models: backend/relayer/src/relayer/models/events.py

| event_type | Direction | Fields |
|-----------|-----------|--------|
| node_register | Provider -> Relayer | node_id, starknet_address, hardware_spec, auth_signature, starknet_public_key, capabilities |
| node_heartbeat | Provider -> Relayer | node_id, cpu_usage, memory_usage, active_tasks, capabilities |
| task_assigned | Relayer -> Provider | task_id, payload, requirements, timeout_seconds, token_amount |
| task_completed | Provider -> Relayer | task_id, result_data, execution_time, signature, result_hash, effort_metrics |
| task_failed | Provider -> Relayer | task_id, error_code, error_message, partial_result |
| ack | Relayer -> Provider | ack_event_id, success, message |
| ping / pong | Both | timestamp or ping_timestamp |
| error | Relayer -> Provider | error_code, error_message |

Authentication signature (registration):

- Provider signs authenticate_node:{node_id}:{starknet_address}:{timestamp_iso}.
- Hash is SHA-256 reduced to Stark field prime; signature uses message_signature.
- Relayer verifies with SignatureVerifier.verify_node_authentication_signature.

Result signature (completion):

- Provider computes result_hash from canonical JSON of result_data.
- message_hash = pedersen(pedersen(task_id_felt, provider_address), result_hash).
- Relayer verifies with SignatureVerifier.verify_node_result_signature.

Implementation note:

- Provider sends capabilities in registration and heartbeat payloads.
- Relayer expects capability_contract in NodeRegisterEvent. Missing field means AI routing treats capabilities as absent.

### Redis Event Streams (EventBus)

File: backend/relayer/src/relayer/core/event_bus.py

- Streams: events:tasks, events:nodes, events:system
- Consumer groups: schedulers, monitors, analytics
- EventBus.publish() uses XADD with maxlen = settings.EVENT_STREAM_MAX_LENGTH (default 10000)
- Consumers read via XREADGROUP with count=10 and block=1000
- TTL cleanup runs every loop; EVENT_TTL_SECONDS = 7 days

### Redis Key Schema (exact keys)

Relayer core keys:

- task:{task_id} (hash)
- pending_tasks (list)
- assigned_tasks (set)
- task_assignments (hash task_id -> node_id)
- task_timeouts (zset task_id -> timeout epoch)
- task_callback:{task_id} (string, TTL 3600s)
- onchain_task_map:{on_chain_task_id} (string, TTL 48h)
- escrow:task:{on_chain_task_id}:submitted (string, TTL 24h)
- settlement:{on_chain_task_id}:complete (string, TTL 24h)
- node:{node_id} (hash)
- heartbeat:{node_id} (string, TTL node_heartbeat_timeout)
- tasks:{node_id} (string)
- active_nodes (set)
- result:{task_id} (hash)
- verified_results (list)
- batch_queue (list)
- batch:{batch_id} (hash)
- events:tasks, events:nodes, events:system (streams)

Bot KV keys (stored via /api/v1/bot/kv and prefixed with tgbot:kv: in Redis):

- wallet:{user_id} or wallet_h:{digest}
- prefs:{user_id}:model
- sess:{digest or user_id}
- rl:{endpoint}:{user_id}:{window}
- pay_nonce:{nonce}

One-tap approval session keys (relayer listener):

- session:prompt:{chat_id}
- session:wallet:{chat_id}
- session:dust_lookup:{dust_value}
- session:status:{chat_id}
- processed:approval:{tx_hash}:{log_index}
- listener:approval:last_block

---

## 4. File and Function Map

Telegram bot:

- telegram/smainer-bot/api/webhook.py
  - handler.do_POST
  - _verify_webhook_secret
  - _process_update
- telegram/smainer-bot/api/payment_complete.py
  - handler.do_POST
  - _verify_init_data
- telegram/smainer-bot/api/callback/complete.py
  - handler.do_POST
  - _handle_task_complete
- telegram/smainer-bot/src/handlers.py
  - handle_inference
  - handle_webapp_data
  - handle_one_tap_inference
- telegram/smainer-bot/src/relayer_client.py
  - submit_inference
  - list_available_models
  - kv_get, kv_set, kv_delete
- telegram/smainer-bot/src/wallet.py
  - link_wallet, unlink_wallet, get_linked_address
  - get_strk_balance, has_sufficient_balance
- telegram/smainer-bot/src/wallet_crypto.py
  - derive_wallet_key, encrypt_address, decrypt_address
- telegram/smainer-bot/src/nonce.py
  - generate_nonce, verify_and_consume_nonce
- telegram/smainer-bot/src/session.py
  - touch_session, check_session_active, invalidate_session

Relayer:

- backend/relayer/src/relayer/api/routes.py
  - submit_task
  - get_task_status
  - list_nodes, get_node_summary
  - sessions/prompt, sessions/wallet, sessions/{chat_id}/status
- backend/relayer/src/relayer/api/ai_inference.py
  - list_capable_nodes
  - evaluate_node_ai_eligibility
  - store_callback_url, deliver_result_callback
- backend/relayer/src/relayer/api/websocket.py
  - WebSocketManager.connect_node
  - WebSocketManager._handle_node_register
  - WebSocketManager._handle_task_completed
  - WebSocketManager._handle_task_failed
- backend/relayer/src/relayer/api/bot_kv_router.py
  - GET/PUT/DELETE /api/v1/bot/kv/{key}
- backend/relayer/src/relayer/core/scheduler.py
  - submit_task, assign_task_to_node, complete_task, fail_task
  - _pending_task_scheduler, _timeout_monitor
- backend/relayer/src/relayer/core/node_pool.py
  - register_node, update_heartbeat, list_active_nodes
- backend/relayer/src/relayer/core/event_bus.py
  - EventBus.publish, EventBus._consume_stream
- backend/relayer/src/relayer/core/aggregator.py
  - add_verified_result, create_batch
- backend/relayer/src/relayer/chain/verifier.py
  - SignatureVerifier.verify_node_authentication_signature
  - SignatureVerifier.verify_node_result_signature
- backend/relayer/src/relayer/settlement/settler.py
  - SettlementManager.settle_task
- backend/relayer/src/relayer/settlement/refund.py
  - RefundCalculator.compute_refund

Provider:

- backend/provider/src/provider/enhanced_api_client.py
  - _register_node_enhanced
  - _handle_task_assigned_event
  - _send_task_result_enhanced
  - _generate_auth_signature
- backend/provider/src/provider/enhanced_executor.py
  - _execute_ai_inference_task
- backend/provider/src/provider/metrics/collector.py
  - MetricsCollector.start, MetricsCollector.finish

MiniApp:

- telegram/miniapp/src/hooks/usePayment.ts
- telegram/miniapp/src/payment/strategies/StarknetWalletStrategy.ts
- telegram/miniapp/src/payment/strategies/TelegramWebViewStrategy.ts
- telegram/miniapp/src/payment/strategies/BotLinkedStrategy.ts

---

## 5. Relayer Scheduling and Redis Internals

Task state transitions:

```
submit_task
  -> task:{id} status=pending
  -> LPUSH pending_tasks

assign_task_to_node
  -> status=assigned, assigned_node_id
  -> task_assignments + task_timeouts
  -> TaskAssignedEvent to provider
  -> callback status=assigned (final=False)

complete_task
  -> status=completed, result stored
  -> callback status=completed

fail_task
  -> status=failed, error_message stored
  -> callback status=failed

_timeout_monitor
  -> status=timeout
  -> callback status=timeout
```

Scheduling behavior:

- _schedule_pending_tasks reads up to 10 pending tasks per sweep.
- _pending_task_scheduler sleeps 10 s between sweeps.
- _timeout_monitor sleeps 30 s and checks task_timeouts zset.
- Node selection: higher tier first, then lower current_tasks.
- AI routing requires capability_contract and supported models/privacy modes.

---

## 6. Provider WebSocket Execution and Ollama Inference

Registration and heartbeat (provider side):

1. _register_node_enhanced builds NodeRegisterEvent.
2. auth_signature = _generate_auth_signature(timestamp_iso).
3. Sends event_type=node_register with node_id, starknet_address, starknet_public_key, hardware_spec, capabilities.
4. Waits for ack before starting heartbeat loop.
5. Heartbeat sends event_type=node_heartbeat with cpu_usage, memory_usage, active_tasks.

Task execution (AI inference):

- TaskAssignedEvent payload is mapped to TaskPayload args (prompt, model).
- _execute_ai_inference_task calls OLLAMA_BASE_URL/api/generate with stream=false.
- MetricsCollector captures tokens and GPU time from Ollama response.
- _send_task_result_enhanced sends task_completed with result_data, execution_time, signature, result_hash, effort_metrics.

---

## 7. Payment and Wallet - Outside Telegram Design

Wallet linking (bot):

- wallet_crypto.derive_wallet_key uses HMAC-SHA256 if WALLET_HMAC_KEY is set.
- wallet_crypto.encrypt_address uses Fernet if WALLET_ENCRYPTION_KEY is set.
- WalletManager stores values via relayer KV API (tgbot:kv: prefix in Redis).

Balance check:

- WalletManager.get_strk_balance uses Starknet RPC and STRK token contract from settings.

Escrow verification:

- relayer.verification.PaymentVerifier calls get_task(on_chain_task_id) via Starknet RPC.
- Verifies task creator address (does not validate escrow amount); fails closed on RPC errors.

Nonce-based browser fallback:

- Nonces are stored as pay_nonce:{nonce} with two-phase TTL (5 min untouched, 5 min active).

Settlement and fee split:

- Fee split constants are in pricing/constants.py (do not document cost model algorithm here).
- Provider total is 88 percent (85 percent base + 3 percent gas subsidy).
- Treasury total is 12 percent (6 percent treasury + 6 percent affiliate when present).

---

## 8. Debugging Checklist

Check webhook configuration:

```bash
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
```

Check relayer health and task status:

```bash
curl "$RELAYER_URL/api/v1/health"
curl -H "Authorization: Bearer $RELAYER_API_KEY" "$RELAYER_URL/api/v1/tasks/$TASK_ID"
```

Inspect Redis task state:

```bash
redis-cli -u $REDIS_URL HGETALL "task:$TASK_ID"
redis-cli -u $REDIS_URL LLEN pending_tasks
redis-cli -u $REDIS_URL ZRANGE task_timeouts 0 -1 WITHSCORES
```

Verify callback URL stored:

```bash
redis-cli -u $REDIS_URL GET "task_callback:$TASK_ID"
```

Provider logs:

```bash
journalctl -u smainer-provider -f
```

Ollama check:

```bash
curl http://127.0.0.1:11434/api/tags
```

Bot logs:

```bash
journalctl -u smainer-bot -f
```

---

## 9. Common Failure Modes

| Symptom | Root Cause | Where to Look | Fix |
|---------|-----------|---------------|-----|
| Bot ignores messages | Webhook secret mismatch | Bot logs, getWebhookInfo | Align WEBHOOK_SECRET with setWebhook secret_token |
| No compute nodes online | No active nodes | /api/v1/nodes, /api/v1/ai/capable-nodes | Restart provider daemon |
| Task stuck in pending | Missing or stale capability contract | task:{id} routing fields | Re-register node with capability_contract |
| Callback rejected | HMAC secret mismatch or clock skew | Bot logs | Sync CALLBACK_SIGNING_SECRET and system time |
| AI response empty | Ollama not running or model missing | Provider logs | Start Ollama and download model |
| Payment verification failed | On-chain task not indexed yet | Bot logs | Wait and retry prompt |
| Settlement duplicate blocked | Duplicate callback/worker | Relayer logs | Ensure single settlement path |

---

Document updated from source code inspection of telegram/smainer-bot, telegram/miniapp,
backend/relayer, and backend/provider.
