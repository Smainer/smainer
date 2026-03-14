# 🚨 SMAINER WAR ROOM: CRITICAL EXECUTION BOARD
**Target Date: March 15, 2026 (Tomorrow)**  
**Objective: Get core user flow working - user with 50 STRK can check balance and execute tasks**

## 🔴 ROOT CAUSE IDENTIFIED
**CRITICAL NETWORK MISMATCH**: Telegram bot and relayer configured for Sepolia testnet, user has 50 STRK on mainnet.

**Immediate Fix Required**: Update `STARKNET_RPC_URL` in production `.env` files:
- ❌ Current: `https://starknet-sepolia.public.blastapi.io`  
- ✅ Required: `https://starknet-mainnet.public.blastapi.io`

**Affected Files**:
- `/home/smainer/Smainer/telegram/telegram-bot/.env` ← **URGENT**: Change RPC URL
- `/home/smainer/Smainer/backend/relayer/.env` ← **URGENT**: Add missing RPC URL
- Vercel environment variables for frontend/miniapp ← **HIGH**: Align with mainnet

---

## 📋 WAR ROOM MEETING AGENDA (30 minutes)

### Opening (5 mins)
- **Status Check**: Each owner confirms current deployment state
- **Blocker Review**: Surface any unknown dependencies or access issues
- **Resource Allocation**: Confirm who has access to production servers/keys

### Critical Path Review (10 mins)  
- **T-001**: Network configuration fix (BLOCKS EVERYTHING)
- **T-002**: Cross-component environment sync verification
- **T-003**: End-to-end user flow test

### Parallel Work Assignment (10 mins)
- **Track A**: Infrastructure (relayer + telegram bot + redis)  
- **Track B**: Frontend + contracts validation
- **Track C**: Provider daemon + desktop app readiness

### Execution Kickoff (5 mins)
- **Go/No-Go**: Confirm all owners ready to execute
- **Communication**: Slack/Discord channel for real-time coordination
- **Next Check**: Status update in 4 hours

---

## 🎯 DEPENDENCY-ORDERED EXECUTION BOARD

### **CRITICAL PATH** ⚡
```
T-001 → T-003 → T-007
```
*Must complete in strict sequence*

### **PARALLEL TRACKS** 
**Track A (Infrastructure)**: T-002, T-004, T-005  
**Track B (Frontend)**: T-006, T-008  
**Track C (Node Ecosystem)**: T-009, T-010

---

## 📝 TASK ASSIGNMENTS

### **T-001: EMERGENCY NETWORK CONFIGURATION FIX** ⚡ *BLOCKS EVERYTHING*
**Owner**: `@systems-engineer`  
**Component**: telegram bot + relayer  
**Priority**: CRITICAL  
**Depends On**: none  
**Acceptance Criteria**:
- ✅ Telegram bot `.env` updated: `STARKNET_RPC_URL=https://starknet-mainnet.public.blastapi.io`
- ✅ Relayer `.env` completed: Add missing `STARKNET_RPC_URL=https://starknet-mainnet.public.blastapi.io`
- ✅ Both services restarted on DigitalOcean
- ✅ `/balance` command returns actual STRK balance for Braavos mainnet wallet (test with user's wallet)
**Notes**: Current files point to Sepolia. User has 50 STRK on mainnet. Fix files: `/home/smainer/Smainer/telegram/telegram-bot/.env` and `/home/smainer/Smainer/backend/relayer/.env`

### **T-002: PRODUCTION REDIS CONNECTION AUDIT**
**Owner**: `@systems-engineer`  
**Component**: relayer + telegram bot  
**Priority**: CRITICAL  
**Depends On**: none (parallel with T-001)  
**Acceptance Criteria**:
- ✅ Verify Redis URL points to DigitalOcean Redis instance (not localhost)
- ✅ Confirm bot uses Redis DB 1, relayer uses DB 0 (architecture requirement)
- ✅ Test Redis connectivity from both services
- ✅ Redis persistence verified (check if balance cache survives restart)
**Notes**: Current configs show `localhost:6379` - need production Redis URLs

### **T-003: CROSS-COMPONENT BALANCE VALIDATION**  
**Owner**: `@telegram-bot-developer`  
**Component**: telegram bot  
**Priority**: HIGH  
**Depends On**: T-001  
**Acceptance Criteria**:
- ✅ `/balance` command tested with known mainnet wallet addresses
- ✅ Balance matches Starkscan/Voyager for same addresses  
- ✅ $STRK token contract address confirmed for mainnet
- ✅ Error handling verified for non-existent wallets
**Notes**: Test with address: user's Braavos wallet with 50 STRK

### **T-004: RELAYER-BOT COORDINATION VERIFICATION**
**Owner**: `@relayer-architect`  
**Component**: relayer + telegram bot  
**Priority**: HIGH  
**Depends On**: T-001, T-002  
**Acceptance Criteria**:  
- ✅ WebSocket connection established between bot and relayer
- ✅ Task submission flows end-to-end from bot → relayer → blockchain
- ✅ Callback API responds correctly to relayer streaming results  
- ✅ API key authentication working between components
**Notes**: Check `RELAYER_API_URL` and `RELAYER_API_KEY` alignment across services

### **T-005: FRONTEND MAINNET ALIGNMENT**
**Owner**: `@frontend-engineer`  
**Component**: frontend  
**Priority**: HIGH  
**Depends On**: none (parallel track)  
**Acceptance Criteria**:
- ✅ Vercel environment variables updated to mainnet RPC
- ✅ Contract addresses point to mainnet deployments
- ✅ Wallet connection shows mainnet network in UI
- ✅ Balance display matches telegram bot results
**Notes**: Update Vercel env vars, frontend at `/home/smainer/Smainer/frontend/.env.local.example`

### **T-006: MINIAPP MAINNET CONFIGURATION**  
**Owner**: `@telegram-bot-developer`  
**Component**: telegram miniapp  
**Priority**: HIGH  
**Depends On**: none (parallel track)  
**Acceptance Criteria**:
- ✅ Miniapp Vercel deployment uses mainnet RPC endpoints
- ✅ Contract addresses synchronized with backend/frontend
- ✅ Starknet chain configuration set to mainnet  
- ✅ User wallets connect to mainnet when launched from Telegram
**Notes**: Update `/home/smainer/Smainer/telegram/miniapp/.env.local` and Vercel env settings

### **T-007: END-TO-END SMOKE TEST**
**Owner**: `@systems-engineer`  
**Component**: all  
**Priority**: CRITICAL  
**Depends On**: T-001, T-003, T-004  
**Acceptance Criteria**:
- ✅ User opens Telegram bot → `/balance` → sees 50 STRK 
- ✅ User submits AI task → bot processes → relayer executes → blockchain result
- ✅ Frontend wallet connection shows same 50 STRK balance
- ✅ Miniapp launched from Telegram operates on mainnet
**Notes**: Full user journey validation with the actual affected user account

### **T-008: PRODUCTION ENVIRONMENT HYGIENE AUDIT**
**Owner**: `@security-expert`  
**Component**: deployment  
**Priority**: MEDIUM  
**Depends On**: none (parallel track)  
**Acceptance Criteria**:
- ✅ All `.env` files use production endpoints (no localhost)
- ✅ Production secrets rotation completed (Redis password, API keys)
- ✅ Environment file templates updated to prevent future drift  
- ✅ Deploy script validates all required environment variables
**Notes**: Review all files with localhost, dev-api-key, sepolia references

### **T-009: CONFIGURATION DRIFT PREVENTION**
**Owner**: `@repository-architect`  
**Component**: deployment  
**Priority**: MEDIUM  
**Depends On**: T-008  
**Acceptance Criteria**:
- ✅ Deploy script validates network consistency across components
- ✅ Environment validation runs before service startup
- ✅ Monitoring alerts created for network/config mismatches
- ✅ Documentation updated with configuration management best practices
**Notes**: Add checks to prevent Sepolia/mainnet mismatches in future deployments 

### **T-010: DESKTOP APP READINESS VERIFICATION**
**Owner**: `@frontend-engineer`  
**Component**: desktop app  
**Priority**: LOW  
**Depends On**: none (parallel track)  
**Acceptance Criteria**:
- ✅ Desktop app compilation succeeds with mainnet configuration
- ✅ Tauri build points to production relayer and mainnet RPCs
- ✅ App package ready for distribution if needed during incident
- ✅ Desktop and web frontends show consistent data
**Notes**: Ensure desktop app doesn't fall back to development configuration

---

## ⏱️ **EXECUTION TIMELINE**

### **HOUR 0-1: CRITICAL PATH FOCUS**
- **T-001**: Fix network configuration (Immediate)  
- **T-002**: Redis audit (Parallel)
- **T-003**: Balance validation (After T-001)

### **HOUR 1-4: COMPONENT ALIGNMENT** 
- **T-004**: Relayer-bot coordination (After T-001, T-002)
- **T-005**: Frontend mainnet config (Parallel) 
- **T-006**: Miniapp mainnet config (Parallel)
- **T-007**: End-to-end smoke test (After critical dependencies)

### **HOUR 4-8: PRODUCTION HARDENING**
- **T-008**: Environment hygiene audit (Parallel)
- **T-009**: Drift prevention measures (After T-008)
- **T-010**: Desktop app verification (Parallel)

### **HOUR 8-24: VALIDATION & MONITORING**
- Full system stress testing with multiple user accounts
- Monitoring dashboard configuration 
- Incident retrospective and prevention measures

---

## ✅ **WAR ROOM SUCCESS CRITERIA**

### **Primary Mission Success** (End of Hour 4):
- ✅ User with 50 STRK on Braavos mainnet can check balance via Telegram `/balance`
- ✅ AI task submission flows end-to-end: Telegram → relayer → blockchain → results
- ✅ All user-facing components (bot, frontend, miniapp) operate on mainnet
- ✅ No configuration drift between services

### **Production Readiness Success** (End of Hour 24):
- ✅ Environment configuration consistency enforced by automated checks
- ✅ Production secret hygiene improved (no dev keys, localhost endpoints)  
- ✅ Monitoring alerts prevent future network mismatches
- ✅ Incident response documentation updated

### T-001: CRITICAL - Network Configuration Fix
**Owner**: @relayer-architect  
**Component**: relayer + telegram  
**Priority**: CRITICAL  
**Depends On**: none  

**Problem**: Telegram bot `.env` points to Sepolia but user has mainnet STRK
- File: [telegram/telegram-bot/.env](telegram/telegram-bot/.env#L10)
- Current: `STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io` 
- Needed: Switch to mainnet or create dual-mode support

**Acceptance Criteria**:
- [ ] Bot checks mainnet for STRK balances  
- [ ] `/balance` command returns correct value for test user (50 STRK)
- [ ] All environment files use consistent network configuration
- [ ] Relayer points to same network as bot

**Notes**: Also check [deployment/.env.prod.template](deployment/.env.prod.template#L10), [frontend/.env.example](frontend/.env.example#L5)

---

### T-002: Redis + Relayer Connectivity Audit  
**Owner**: @systems-engineer  
**Component**: relayer  
**Priority**: HIGH  
**Depends On**: none (parallel with T-001)

**Acceptance Criteria**:
- [ ] Redis container running on DO and accessible
- [ ] Relayer connects to Redis successfully (check logs)
- [ ] WebSocket endpoints respond correctly
- [ ] Health check endpoint returns 200

**Notes**: [deployment/docker-compose.prod.yml](deployment/docker-compose.prod.yml) shows Redis config

---

### T-003: End-to-End User Flow Test  
**Owner**: @telegram-bot-developer  
**Component**: telegram  
**Priority**: CRITICAL  
**Depends On**: T-001  

**Acceptance Criteria**:
- [ ] User can `/link` their mainnet wallet address
- [ ] `/balance` returns accurate STRK amount  
- [ ] `/images` or `/generate` command initiates task flow
- [ ] Payment escrow handles mainnet transactions
- [ ] User receives AI response within 60s

---

### T-004: Deployment Environment Sync
**Owner**: @repository-architect  
**Component**: infra  
**Priority**: HIGH  
**Depends On**: none (parallel)

**Acceptance Criteria**:
- [ ] All `.env` files point to same network (mainnet vs testnet decision)
- [ ] Contract addresses consistent across all components  
- [ ] API keys and endpoints properly configured for production
- [ ] Docker containers restart successfully with new config

**Notes**: Check [scripts/deploy-relayer.sh](scripts/deploy-relayer.sh), [deployment/](deployment/) folder

---

### T-005: Telegram Bot → Relayer Integration Test
**Owner**: @relayer-architect  
**Component**: relayer  
**Priority**: HIGH  
**Depends On**: T-002

**Acceptance Criteria**:
- [ ] Bot can successfully POST to relayer API
- [ ] Relayer receives and queues inference requests
- [ ] Callback flow works (relayer → bot when task completes)
- [ ] Error handling works (timeout, failed tasks)

**Notes**: [telegram/telegram-bot/src/telegram_bot/handlers.py](telegram/telegram-bot/src/telegram_bot/handlers.py#L280)

---

### T-006: Frontend + Miniapp Network Configuration  
**Owner**: @frontend-engineer  
**Component**: frontend + telegram miniapp  
**Priority**: MEDIUM  
**Depends On**: T-001 (network decision)

**Acceptance Criteria**:  
- [ ] Frontend `.env` matches backend network configuration
- [ ] Miniapp Starknet connection works with correct network
- [ ] Wallet connection flow functional
- [ ] Contract interactions use correct addresses

**Notes**: [frontend/.env.example](frontend/.env.example), [telegram/miniapp/.env.local](telegram/miniapp/.env.local)

---

### T-007: Payment Flow Validation  
**Owner**: @starknet-engineer  
**Component**: contracts  
**Priority**: CRITICAL  
**Depends On**: T-003

**Acceptance Criteria**:
- [ ] Smart contracts deployed on target network (mainnet/testnet decision)  
- [ ] STRK token approve/transfer/escrow flow works
- [ ] Gas fees reasonable for production
- [ ] Contract addresses match all environment configurations

**Notes**: [contracts/src/smainer.cairo](contracts/src/smainer.cairo#L501)

---

### T-008: Vercel Miniapp Deployment Update
**Owner**: @frontend-engineer  
**Component**: telegram miniapp  
**Priority**: MEDIUM  
**Depends On**: T-006

**Acceptance Criteria**:
- [ ] Vercel environment variables updated for correct network
- [ ] Miniapp deployed and accessible via Telegram
- [ ] Bot menu button links to correct URL
- [ ] HTTPS/security headers working properly

---

### T-009: Provider Daemon Connection Test
**Owner**: @systems-engineer  
**Component**: provider  
**Priority**: LOW  
**Depends On**: T-005

**Acceptance Criteria**:
- [ ] At least one provider daemon connects to relayer
- [ ] WebSocket connection stable
- [ ] Can receive and complete test hash task
- [ ] Results properly signed and submitted

**Notes**: [backend/provider/README.md](backend/provider/README.md)

---

### T-010: Desktop App Configuration Check  
**Owner**: @frontend-engineer  
**Component**: desktop  
**Priority**: LOW  
**Depends On**: none (nice-to-have)

**Acceptance Criteria**:
- [ ] Tauri app connects to correct relayer endpoint
- [ ] Node onboarding flow works with production config
- [ ] Can generate and link wallet with same network as other components

---

## 🚦 LAUNCH GATE CHECKLIST (Tomorrow Morning)

### ✅ Pre-Launch Validation (30 minutes)
- [ ] **Network Consistency**: All components use same Starknet network
- [ ] **Live Balance Check**: Test user `/balance` shows correct STRK amount  
- [ ] **Task Execution**: End-to-end inference request completes successfully
- [ ] **Payment Flow**: STRK escrow/release works correctly
- [ ] **Error Handling**: Graceful failures for insufficient balance, timeout cases

### ✅ Performance Gates  
- [ ] **Response Time**: Telegram commands respond within 3 seconds
- [ ] **Task Completion**: AI inference completes within 60 seconds
- [ ] **System Load**: DO servers running <80% CPU/memory
- [ ] **Error Rate**: <5% error rate on critical user flows

### ✅ Security Gates
- [ ] **No Private Keys**: No private keys in logs or environment dumps
- [ ] **API Security**: Rate limiting enabled on public endpoints
- [ ] **Input Validation**: Bot handles malformed addresses gracefully
- [ ] **CORS Configuration**: Frontend/miniapp CORS properly configured

### ⚠️ Rollback Plan
- [ ] **Config Backup**: Original environment configurations saved
- [ ] **Quick Revert**: Can switch back to previous network in <10 minutes
- [ ] **User Communication**: Ready to notify users of any downtime

---

## 🔄 COORDINATION PROTOCOL

### Real-Time Communication
- **Primary Channel**: Discord #war-room or equivalent
- **Status Updates**: Every 2 hours until resolved
- **Blocker Escalation**: Immediate ping to @all if task blocked >30 mins

### Status Reporting Format
```
T-XXX: [COMPLETE|IN_PROGRESS|BLOCKED]
Progress: X/Y acceptance criteria done  
ETA: [timestamp]
Blocker: [description if blocked]
```

### Success Metrics
- **User Success**: Test user completes full inference request for 0.1 STRK
- **System Stability**: All components stay running for 2+ hours without restart
- **Response Quality**: AI inference returns coherent response to test prompt

---

**Last Updated**: March 14, 2026  
**Next Review**: 4 hours post-kickoff