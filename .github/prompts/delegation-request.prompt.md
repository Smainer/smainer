---
description: "Route a user task to the single best Smainer specialist agent with a concise rationale and ready runSubagent call."
model: "Gemini 3 Flash (Preview)"
---

# Delegation Recommendation for Chief Director

Route to one best specialist. Keep output short.

## Allowed Agents
Use only: `relayer-architect`, `systems-engineer`, `starknet-engineer`, `frontend-engineer`, `telegram-bot-developer`, `repository-architect`, `security-expert`, `fee-economist`, `marketing-copywriter`, `brand-designer`, `planner`, `agent-runtime-engineer`, `ai-inference-benchmarker`, `gtm-specialist`, `tauri-desktop-engineer`.

## Routing Rules
1. If user names an agent, honor it.
2. If multi-domain or ambiguous planning, choose `planner` first.
3. If security-sensitive, choose `security-expert` first.
4. Else map by dominant domain:
   - Contracts/Cairo/Starknet -> `starknet-engineer`
   - Relayer/API/Redis/WebSocket coordination -> `relayer-architect`
   - Linux/systemd/provider/GPU daemon -> `systems-engineer`
   - Next.js/React/UI/wallet UX -> `frontend-engineer`
   - Telegram bot/MiniApp -> `telegram-bot-developer`
   - CI/CD/release/repo governance -> `repository-architect`
   - Fees/tokenomics/rewards -> `fee-economist`
   - Messaging/copy/positioning -> `marketing-copywriter`
   - Brand/visual direction -> `brand-designer`
   - Agent runtime policies/guardrails -> `agent-runtime-engineer`
   - Benchmarking/latency/throughput -> `ai-inference-benchmarker`
   - GTM launch planning -> `gtm-specialist`
   - Desktop app/Tauri/Windows installer -> `tauri-desktop-engineer`
5. If uncertain between two, ask one clarifying question.

## Output Format
1. `Component`: affected area
2. `Agent`: chosen agent name
3. `Why`: one sentence
4. `runSubagent` snippet:

```javascript
runSubagent({
  agentName: "exact-agent-name",
  description: "one-line objective",
  prompt: "Context, constraints, required output, and validation steps."
})
```
