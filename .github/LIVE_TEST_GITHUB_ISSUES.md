# Smainer Live Test Issue Board (Copy to GitHub Issues)

> Use CANONICAL_LIVE_TEST_GUIDE.md as source of truth

## How To Use

1. Create each issue in order.
2. Keep dependencies linked.
3. Do not start Week 2 launch issues before Week 1 technical gates pass.
4. Close issue only when acceptance criteria is fully met.

---

## Issue #1: [W1] Contract final validation on Sepolia

**Owner:** Engineering  
**Labels:** `contracts`, `week-1`, `sepolia`, `validation`  
**Dependencies:** None  
**Due Date:** 2026-03-14  
**Objective:** Complete final smart contract validation on Sepolia testnet before mainnet deployment

**Acceptance Criteria:**
- [ ] All contract functions tested and verified on Sepolia
- [ ] Gas optimization review completed
- [ ] Security audit findings addressed
- [ ] Contract verification on Sepolia block explorer successful
- [ ] Integration tests with test tokens passing

---

## Issue #2: [W1] Relayer + Redis integration validation

**Owner:** Engineering  
**Labels:** `backend`, `relayer`, `redis`, `week-1`  
**Dependencies:** #1  
**Due Date:** 2026-03-12  
**Objective:** Validate relayer service with Redis for task queue management and caching

**Acceptance Criteria:**
- [ ] Redis connection and failover handling tested
- [ ] Task queue processing validated under load
- [ ] WebSocket coordination working with Redis pub/sub
- [ ] Performance metrics within acceptable thresholds
- [ ] Error handling and recovery mechanisms verified

---

## Issue #3: [W1] Provider daemon/seamon integration validation

**Owner:** Engineering  
**Labels:** `backend`, `provider`, `daemon`, `week-1`  
**Dependencies:** #2  
**Due Date:** 2026-03-13  
**Objective:** Ensure provider daemon integrates properly with relayer and executes AI tasks

**Acceptance Criteria:**
- [ ] Provider daemon connects to relayer successfully
- [ ] AI task execution pipeline validated
- [ ] Resource monitoring and reporting functional
- [ ] Provider registration and health checks working
- [ ] Logging and debugging capabilities verified

---

## Issue #4: [W1] First end-to-end task execution proof

**Owner:** Engineering  
**Labels:** `integration`, `e2e`, `week-1`, `milestone`  
**Dependencies:** #3  
**Due Date:** 2026-03-13  
**Objective:** Demonstrate complete task flow from frontend request to provider execution and reward distribution

**Acceptance Criteria:**
- [ ] Full task submission through frontend works
- [ ] Provider picks up and executes task successfully
- [ ] Results returned to user correctly
- [ ] Smart contract reward distribution verified
- [ ] Transaction fees and gas usage tracked
- [ ] End-to-end latency measured and acceptable

---

## Issue #5: [W1] Frontend and mini app build + SSL production readiness

**Owner:** Engineering  
**Labels:** `frontend`, `miniapp`, `ssl`, `production`, `week-1`  
**Dependencies:** #4  
**Due Date:** 2026-03-12  
**Objective:** Prepare frontend and Telegram mini app for production deployment with SSL certificates

**Acceptance Criteria:**
- [ ] Frontend build optimized for production
- [ ] SSL certificates configured and tested
- [ ] Telegram mini app deployed and functional
- [ ] Mobile responsiveness verified
- [ ] Performance metrics meet production standards
- [ ] Security headers and HTTPS enforcement active

---

## Issue #6: [W1] benco creative assets draft for 2x campaign

**Owner:** benco team  
**Labels:** `marketing`, `creative`, `2x-rewards`, `week-1`  
**Dependencies:** #5  
**Due Date:** 2026-03-13  
**Objective:** Create initial creative assets for 2x rewards launch campaign

**Acceptance Criteria:**
- [ ] Visual assets for 2x rewards campaign created
- [ ] Social media graphics designed (Twitter/X, Discord, Telegram)
- [ ] Website banner and promotional materials ready
- [ ] Campaign messaging and copy finalized
- [ ] Asset review and approval process completed

---

## Issue #7: [W1] benco announcement schedule draft (Discord/Telegram/X)

**Owner:** benco team  
**Labels:** `marketing`, `social`, `announcements`, `week-1`  
**Dependencies:** #5  
**Due Date:** 2026-03-14  
**Objective:** Plan and schedule announcement timeline across all social channels

**Acceptance Criteria:**
- [ ] Launch announcement timeline created
- [ ] Discord announcement strategy planned
- [ ] Telegram community engagement plan ready
- [ ] Twitter/X content calendar prepared
- [ ] Cross-platform coordination schedule finalized

---

## Issue #8: [W2] Mainnet contract deployment and verification

**Owner:** Engineering  
**Labels:** `contracts`, `mainnet`, `deployment`, `week-2`  
**Dependencies:** #5  
**Due Date:** 2026-03-19  
**Objective:** Deploy validated smart contracts to Starknet mainnet and verify functionality

**Acceptance Criteria:**
- [ ] Smart contracts deployed to Starknet mainnet
- [ ] Contract verification on mainnet explorer successful
- [ ] Initial liquidity and token allocations configured
- [ ] Contract permissions and access controls verified
- [ ] Mainnet integration tests passing
- [ ] Emergency procedures and pause mechanisms tested

---

## Issue #9: [W2] 2x rewards activation and frontend verification

**Owner:** Engineering  
**Labels:** `rewards`, `frontend`, `2x-campaign`, `week-2`  
**Dependencies:** #8  
**Due Date:** 2026-03-19  
**Objective:** Activate 2x rewards mechanism and verify frontend displays correct multipliers

**Acceptance Criteria:**
- [ ] 2x rewards smart contract functionality activated
- [ ] Frontend displays 2x multiplier correctly
- [ ] Reward calculation logic verified
- [ ] User balance updates reflect 2x rewards
- [ ] Analytics and tracking for campaign metrics implemented

---

## Issue #10: [W2] benco launch blitz and first-week 2x campaign execution

**Owner:** benco team  
**Labels:** `marketing`, `launch`, `campaign`, `week-2`, `milestone`  
**Dependencies:** #9  
**Due Date:** 2026-03-19 to 2026-03-21  
**Objective:** Execute coordinated launch campaign across all channels with 2x rewards promotion

**Acceptance Criteria:**
- [ ] Launch announcements posted across Discord, Telegram, Twitter/X
- [ ] 2x rewards campaign messaging deployed
- [ ] Community engagement and support responses active
- [ ] First user onboarding and task completions tracked
- [ ] @smainer_ai_bot deployment verified for Telegram support
- [ ] Campaign performance metrics monitored and reported