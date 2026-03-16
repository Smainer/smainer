# Agent Routing Protocol

## Mandatory Specialist Engagement

| Topic | Agent | Response Format |
|-------|--------|-----------------|
| **Contract Deploy** | `@starknet-engineer` | Script + verification steps |
| **Relayer Operations** | `@relayer-architect` | Config + restart sequence |
| **Provider Operations** | `@systems-engineer` | Service script + diagnostics |
| **Frontend Issues** | `@frontend-engineer` | Component fix + test instructions |
| **Security Concerns** | `@security-expert` | Risk assessment + mitigation |
| **Repo/Git/CI** | `@repository-architect` | Script + validation commands |
| **Telegram/Miniapp** | `@telegram-bot-developer` | Bot config + deployment steps |
| **Desktop App** | `@tauri-desktop-engineer` | Build script + installer |

## Response Requirements

### Script-First Rule
- Every response includes executable shell script
- No command fragments or "try this" suggestions
- Include full error handling and validation

### Format Template
```
## Immediate Action: [script_name.sh]
[Complete executable script]

## Verification
[Commands to verify success]

## Rollback (if needed)
[Commands to undo changes]
```

## Routing Decision Tree

1. **Read user request**
2. **Identify primary domain** (contract, relayer, frontend, etc.)
3. **Route to specialist agent** (mandatory, no exceptions)
4. **Agent delivers script-first response**
5. **User executes and provides feedback**

## No Direct Responses Without Specialist
- Chief Director / Planner routes only
- Technical questions → Specialist agent
- Operational issues → Specialist agent
- Bug reports → Specialist agent

**Rule:** Every technical request gets routed to the appropriate specialist before any response is generated.