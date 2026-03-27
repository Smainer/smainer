---
name: api-contract-alignment
description: "Use when designing, modifying, or integrating with the Smainer Relayer API (REST or WebSockets)."
argument-hint: "API endpoints, WebSocket events, payloads schemas..."
user-invocable: true
disable-model-invocation: false
---

# API Contract Alignment

## 1. Pydantic is Canonical
- The Python FastAPI Relayer (`models/schemas.py`, `models/events.py`) holds the ultimate source of truth. 
- Any time you instruct `@frontend-engineer`, `@telegram-bot-developer`, or `@tauri-desktop-engineer` to change an API call, you must cross-verify the Python schemas. 

## 2. Route Conventions
- **Versioning**: All REST endpoints must fall under `/api/v1/`.
- **Standardized Error Bodies**: `{ "error": "Descriptive message", "detail": "Granular debugging hints", "code": "ERR_CODE_01" }`. 
- **Graceful Parsing**: Do not let Next.js, Desktop, or Telegram clients crash on an unexpected HTTP 500 HTML response. Parse gracefully based on status codes.

## 3. Websocket & Auth Mandates
- **Stateless REST Auth**: Depend on `Authorization: Bearer <API_KEY>` or JWT tokens. Never trust raw User-IDs.
- **WebSocket Handshake**: Never push operational status until the socket validates its handshake payload token sequence over the open socket connection.

## Input Contract
- **Trigger**: Called when designing, modifying, or integrating with the Smainer Relayer API (REST or WebSockets)
- **Required context**: The endpoint or WebSocket event being designed/modified; the caller (frontend, Telegram bot, desktop, or provider daemon)
- **Optional**: Existing Pydantic schema file paths for reference

## Output Contract
- One of:
  1. **API Specification**: Endpoint path + method + Pydantic request/response schema + auth requirement + error codes
  2. **WebSocket Event Spec**: Event `type` name + payload schema + expected `ack` or response event
  3. **Conflict Report**: Identified schema mismatch + resolution recommendation