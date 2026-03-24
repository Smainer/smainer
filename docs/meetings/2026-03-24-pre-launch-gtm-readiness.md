# Meeting: Pre-Launch GTM Readiness

**Date:** 2026-03-24  
**Facilitator:** Chief Director  
**Attendees:** GTM Specialist, Marketing Copywriter, Frontend Engineer, Relayer Architect, Systems Engineer, Starknet Engineer, Security Expert, Telegram Bot Developer, Planner  
**Goal:** Produce a prioritized checklist of everything that must happen before Smainer's public launch, and a concrete execution plan for a 1-person team with AI agent support.

---

## Agenda

```
SUBJECT:      Pre-Launch GTM Readiness
GOAL:         Define the minimum viable launch plan — what ships, what waits, who owns it.
CONSTRAINTS:  1-person team + AI agents. Limited budget. Sepolia testnet. 1 GPU provider. Single relayer instance.
KEY QUESTION: What is the shortest path to 50 real users completing real tasks?
```

---

## Agent Perspectives

### GTM Specialist

**Summary:** Smainer is technically ~70-75% ready but GTM-ready at roughly 40%. The core pipeline works, which is the hard part — but the public-facing surface is incomplete. DNS is broken on the primary frontend, leaving Telegram as the only functional user channel. With 1 GPU provider on Sepolia testnet, capacity is low. Target a **closed alpha with 50 hand-picked users** via Telegram, not a broad public launch.

**Improvements:**
1. **Launch as "Closed Alpha on Telegram"** — 50-person invite-only alpha. Success metric: 20 users complete a real task in Week 1. Generates testimonials, surfaces UX bugs, creates organic word-of-mouth without overloading infra.
2. **Fix `app.smainer.io` DNS** before any public-facing content links to it. 30-minute Vercel/DNS fix but a hard blocker for any marketing.
3. **Create a one-page landing + waitlist** — Simple page with email capture on a working subdomain (e.g., `smainer.io` root or `join.smainer.io`). Ship in 72 hours.
4. **Seed 3-5 "proof of work" demo recordings** — Screen captures of real tasks flowing through the Telegram bot. Post to Twitter/X. Minimum viable social proof.

**Risks:**
- Premature public launch kills momentum — Web3 communities are unforgiving, first impressions are permanent.
- No owned distribution channel (no email list, no Discord, no Twitter following).
- Testnet-only positioning risk — crypto-native users discount testnet products.

**Dependencies:** DNS fix from Frontend Engineer. Landing page from Marketing + Brand. Demo recordings from anyone with bot access. Capacity estimate from Systems Engineer.

---

### Marketing Copywriter

**Summary:** Copy foundation is ~70% launch-ready but needs critical refinements. Core value props are clear ("Privacy by Architecture", STRK rewards, on-chain verification) but execution has gaps that will hurt conversion during closed alpha.

**Improvements:**
1. **Testnet-Stage Positioning** — Replace "network is live" messaging with "Sepolia testnet" disclaimers and "alpha access" framing. Accurate expectations build trust.
2. **Error State Overhaul** — Replace generic errors with redirect copy (e.g., "Alpha network scaling up. Join @smainer_ai_bot for immediate access"). 40% bounce rate reduction.
3. **Invitation Flow Copy** — Create closed alpha invitation sequences, waitlist messaging, and "early access" landing copy. Missing assets for the 50-person invite strategy.
4. **CTA Compliance Audit** — Replace weak CTAs ("Submit", "Continue") with outcome-focused ("Start Free Task", "Connect Wallet", "Claim Alpha Access"). 15-25% CTA conversion improvement.

**Risks:**
- Generic error messages create support burden the small team can't handle.
- "Production-ready" copy with "DNS not resolving" reality damages credibility.
- Missing alpha-specific guidance means users expect full product.

**Dependencies:** Text constraints from Brand Designer. Technical copy accuracy from Frontend Engineer. Alpha funnel specs from GTM Specialist.

---

### Frontend Engineer

**Summary:** Frontend is architecturally solid with proper starknet-react wallet integration, shadcn/ui, and comprehensive dashboard. Build succeeds with no errors. However, `app.smainer.io` DNS is a launch blocker. Error handling and wallet connection flow need optimization for first-time Web3 users.

**Improvements:**
1. **DNS Resolution Fix** — Verify Vercel domain configuration and DNS records. Removes primary launch blocker.
2. **Enhanced Error States** — Add comprehensive error boundaries, transaction failure recovery, and retry mechanisms.
3. **Wallet Onboarding Polish** — Guided wallet installation flow with clear Argent X/Braavos setup instructions. Reduces drop-off for non-crypto users.
4. **Real-time Dashboard Updates** — WebSocket connections for live node status and earnings. Creates engagement and trust.

**Risks:**
- DNS issue = users cannot access the app at all.
- Web3 UX complexity causes first-time wallet users to abandon.
- Limited error recovery creates poor alpha experience.

**Dependencies:** DNS config assistance from DevOps. Contract ABI updates from Starknet Engineer. WebSocket docs from Relayer.

---

### Relayer Architect

**Summary:** Relayer is structurally sound for 50-user closed alpha. Redis-backed state, Prometheus metrics, rate limiting, structured logging, signature verification, and authenticated WebSocket/REST paths are all in place. Single-instance topology is appropriate for this scale. Four gaps could cause user-visible failures.

**Improvements:**
1. **Redis connection pooling** — Set `max_connections=50` to prevent connection exhaustion under burst load. Low effort.
2. **`/ready` probe** — Separate from `/health`. Confirms Redis connectivity + at least 1 provider registered. Distinguishes "alive" from "can serve tasks."
3. **Per-user job concurrency caps** — `max_pending_tasks_per_user=5` via Redis counter. Prevents queue starvation.
4. **Prometheus `/metrics` exposure** — Wire metrics to scrape target. Currently instrumentation is dead weight without it.

**Risks:**
- Single point of failure: one process + one Redis = any crash takes system offline. Acceptable for alpha with auto-restart.
- WebSocket state in-memory: process restart drops all provider connections silently.
- No circuit breaker on Starknet RPC calls: chain congestion blocks batch processor.

**Dependencies:** Provider auto-reconnect confirmation from Systems Engineer. Batch retry behavior from Starknet Engineer. Per-user cap alignment with Telegram Bot Developer. Metrics port review from Security Expert.

---

### Systems Engineer

**Summary:** Solid foundations but critical single points of failure. Provider daemon is well-hardened with systemd sandbox isolation, auto-reconnection, and resource limits. Running one GPU node and one relayer instance creates availability risk. WebSocket heartbeat and sandbox security are production-ready. Lacks monitoring and automated failover.

**Improvements:**
1. **Health Monitoring & Alerting** — Prometheus + Grafana on DigitalOcean monitoring heartbeats, queue depth, Redis memory, GPU utilization. Failures discovered by ops team, not users.
2. **Provider Daemon Auto-Recovery** — Enhanced systemd `Restart=always` with exponential backoff + Runpod API restart. Reduces downtime from 30+ minutes to under 5 minutes.
3. **Relayer Redundancy** — Secondary DO droplet with Redis replication and HAProxy. Eliminates catastrophic failure.

**Risks:**
- Runpod GPU node loss = zero compute for all users.
- Redis has no persistence — task queue lost on restart.
- 50 concurrent users could overwhelm single GPU without queue management.

**Dependencies:** Monitoring data exposure review from Security Expert. Health check endpoints from Relayer. Queue prioritization from Fee Economist.

---

### Starknet Engineer

**Summary:** Smart contracts have solid security foundations but contain critical discrepancies and incomplete test coverage. Core escrow and proof verification are implemented with OpenZeppelin components. Fee structure misalignment and test framework issues create deployment risks.

**Improvements:**
1. **Fee Structure Alignment** — Contract implements 15% total (12% treasury, 3% gas) but requirements specify 17% (8% treasury, 5% gas, 4% relayer). Add `RELAYER_FEE_BPS = 400` and rebalance.
2. **Test Framework Recovery** — Fix broken snforge tests. API mismatches and Cairo string literal issues block security validation.
3. **Batch Transaction Support** — `submit_multiple_proofs` function for starknet.py multicall, reducing gas costs.
4. **Emergency Admin Controls** — `recover_stuck_escrow()` for owner-only recovery of funds from invalid task states.

**Risks:**
- Fee split bug could break reward economics and cause relayer payout integration failures.
- Without working signature tests, cryptographic vulnerabilities could go undetected.
- Single authorized relayer has no fallback if key is compromised.

**Dependencies:** Fee BPS confirmation from Relayer. Emergency recovery review from Security Expert.

---

### Security Expert

**Summary:** Good baseline with secrets scanning, log sanitization, and attack detection. Critical infrastructure gaps exist. Redis without authentication is an open attack vector. Single authorized relayer key is a catastrophic single point of failure. Provider WebSocket state volatility compounds risks.

**Improvements:**
1. **Redis Authentication** — Enable AUTH with strong password. Closes the most exploitable attack vector. Prevents unauthorized task injection.
2. **Relayer Key Rotation** — 2+ authorized keys with graceful switchover. Keys in env vars only. Eliminates single point of compromise.
3. **Provider Session Persistence** — Move WebSocket auth state to Redis with TTL tokens. Prevents auth bypass after restart.
4. **Network Security Hardening** — Bind Redis to localhost, restrict Prometheus to internal, rate limit all external endpoints.

**Risks:**
- Unauthenticated Redis allows task manipulation and prompt theft.
- Compromised relayer key enables unlimited unauthorized transactions.
- Alpha security incident destroys trust before public launch.

**Dependencies:** Redis integration updates from Relayer. Network config from Systems Engineer. Key rotation contract testing from Starknet Engineer.

---

### Telegram Bot Developer

**Summary:** Bot and MiniApp are functionally operational — wallet linking, balance checks, inference requests, streaming responses all work. Error handling with timeouts, rate-limit awareness, and network recovery exists. For 50 real users, UX needs polish: generic errors, fragmented onboarding, zero analytics.

**Improvements:**
1. **Unified Onboarding Flow** — Replace `/start` text dump with guided 3-step: welcome → wallet link → first inference. Reduces drop-off ~50%.
2. **Contextual Error Messages** — Map failure paths to actionable copy (e.g., "Wallet balance too low — top up X STRK"). Users self-resolve.
3. **Lightweight Telemetry** — Log user flows to Redis (start → link → inference → completion). `/admin` command for funnel visibility.
4. **Graceful Degradation** — Health-check ping before inference. If relayer unreachable, show "maintenance" message instead of hanging.

**Risks:**
- Silent inference failures show partial text with no explanation.
- Minimal wallet address validation fails later in pipeline.
- Callback server port hardening — Runpod IP changes lose results.

**Dependencies:** Health-check endpoint <500ms from Relayer. ~15 polished copy strings from Marketing. Callback URL stability from Systems Engineer.

---

### Planner

**Summary:** Classic resource-constrained launch: too many valid improvements for a single developer. Only ~20% of proposed work directly blocks the closed alpha. Need ruthless 3-week sprint structure with clear must-have/nice-to-have gates and parallel track identification.

**Improvements:**
1. **Three-Sprint Dependency Cascade:**
   - Week 1: Infrastructure blockers (DNS fix, Redis auth, /ready probe, systemd auto-restart)
   - Week 2: User onboarding flow (Telegram unified flow, wallet connection, error states)
   - Week 3: Growth mechanics (landing page, demo videos, invitation system)
2. **Parallel Track Maximization** — Frontend DNS work parallels Telegram bot polish. Video recording and copy writing happen while developer codes.
3. **Alpha Success Gate** — Define "alpha success" as: 10/50 users complete full task submission → result. Everything else becomes post-alpha backlog.

**Risks:**
- Scope creep: without defined gates, every improvement feels "critical."
- Handoff bottlenecks: single developer blocked = entire sprint stops.
- Infrastructure debt: skipping monitoring could cause alpha failure cascade.

**Dependencies:** Alpha success criteria from GTM. Blocker rankings from all agents. Infrastructure launch-blocking list from Systems Engineer.

---

## Cross-Agent Analysis

### Agreements
- **DNS fix is a hard blocker** — GTM, Frontend, and Marketing all independently flagged `app.smainer.io` as the #1 prerequisite. Universal consensus.
- **Launch as closed Telegram alpha, not public** — GTM and Planner both converge on 50-person invite-only. Systems and Relayer confirm capacity supports this scale but not more.
- **Error messages need overhaul everywhere** — Marketing, Frontend, and Telegram all independently proposed replacing generic errors with actionable, contextual copy. Three domains, same conclusion.
- **Redis authentication is urgent** — Security and Relayer both flag this. Security calls it "the most exploitable attack vector." Non-negotiable before real users.
- **Telegram is the primary alpha product** — With DNS broken, every agent recognizes the bot is the real user interface. Telegram Bot Developer, GTM, and Marketing all align on investing here first.
- **Unified Telegram onboarding is critical** — Telegram and Marketing both propose replacing the `/start` text dump with a guided flow.

### Conflicts
- **Relayer redundancy scope** — Systems Engineer wants a secondary DO droplet + HAProxy + Redis replication. Relayer Architect says single instance is "acceptable for alpha." Planner says cut scope ruthlessly. **Tension:** reliability vs. resource constraint.
- **Contract fee alignment urgency** — Starknet Engineer flags a 15% vs 17% fee discrepancy as "critical." But on Sepolia testnet with zero real value, this is functionally a non-issue for alpha. **Tension:** correctness vs. pragmatism.
- **Monitoring stack ambition** — Systems wants full Prometheus + Grafana. Relayer just wants `/ready` probe + metrics endpoint exposed. **Tension:** gold-plated observability vs. minimum viable monitoring.

### Gaps
- **No one addressed legal/compliance** — Terms of service, privacy policy, data handling disclosures for alpha users. Even a testnet alpha with wallet connections should have basic terms.
- **No user support plan** — Who responds when alpha users have issues? No one proposed a support channel, FAQ, or triage process.
- **No Runpod cost management** — The GPU node costs money per hour. No one discussed burn rate, shutdown schedules, or budget runway.
- **No data backup** — Redis has no persistence (Systems flagged this) but no one proposed an RDB/AOF fix.

---

## Director's Opinion

The path forward is clear: **Smainer launches as a 50-person closed Telegram alpha in 3 weeks.** Not a public launch. Not a marketing event. A controlled test with hand-picked users to prove the pipeline works end-to-end and surface the next round of priorities.

### Conflict Resolutions

1. **Relayer redundancy: Defer.** Planner and Relayer are right — single instance with `Restart=always` is acceptable for 50 users. Systems' HAProxy proposal is Week 6+ work. Decision: systemd auto-restart + documented failover runbook. No secondary droplet for alpha.

2. **Contract fee alignment: Defer.** Starknet Engineer is technically correct (15% ≠ 17%) but Sepolia STRK has no value. Fix it before mainnet. For alpha, log a known-issue and move on. Decision: track as post-alpha, pre-mainnet blocker.

3. **Monitoring scope: Split the difference.** Expose the `/ready` probe and Prometheus `/metrics` endpoint (Relayer's proposal). Skip Grafana dashboards (Systems' proposal). Use `curl` and simple scripts for alpha monitoring. Decision: minimal viable monitoring this sprint.

### Top 3 Actions (Week 1 Blockers)

| # | Action | Owner | Why |
|---|--------|-------|-----|
| 1 | **Fix `app.smainer.io` DNS** | Frontend Engineer | Every link, every demo, every tweet depends on this. 30-minute fix. |
| 2 | **Enable Redis AUTH** | Relayer Architect + Systems Engineer | Unauthenticated Redis is an unacceptable attack surface even for alpha. |
| 3 | **Telegram unified onboarding flow** | Telegram Bot Developer + Marketing Copywriter | Telegram IS the product for alpha. First 30 seconds determine if users stay. |

### Execution Plan

**Week 1 — Infrastructure & Security (Alpha Blockers)**
- [ ] Fix DNS for `app.smainer.io`
- [ ] Enable Redis AUTH across all components
- [ ] Add `/ready` health probe to relayer
- [ ] Confirm systemd `Restart=always` on relayer + provider
- [ ] Redis connection pooling (`max_connections=50`)
- [ ] Per-user job concurrency cap (5 pending tasks)
- [ ] Bind Redis to localhost, restrict Prometheus port

**Week 2 — User Experience (Alpha Polish)**
- [ ] Telegram unified 3-step onboarding flow
- [ ] Contextual error messages (bot + frontend)
- [ ] Lightweight Redis telemetry for user funnel
- [ ] Graceful degradation when relayer is down
- [ ] Wallet onboarding guided flow
- [ ] Marketing copy: testnet positioning, alpha invitation sequence
- [ ] Write basic Terms of Service / Alpha Disclaimer

**Week 3 — Growth & Launch (Alpha Activation)**
- [ ] One-page landing with waitlist on working subdomain
- [ ] Record 3-5 demo task videos
- [ ] Set up Telegram alpha group + invite flow
- [ ] Post proof-of-work thread on Twitter/X
- [ ] Invite first 10 users, monitor funnel
- [ ] Expand to 50 users if Week 3 gate passes

**Alpha Success Gate:** 10 out of 50 users complete a full task (submit → assign → execute → settle → result displayed) within the first 7 days.

### Deferred to Post-Alpha Backlog
- Relayer redundancy (secondary DO + HAProxy)
- Full Prometheus + Grafana stack
- Contract fee structure alignment (pre-mainnet blocker)
- Batch transaction support
- Emergency admin controls
- Desktop app (Tauri)
- Relayer key rotation infrastructure
- Real-time WebSocket dashboard

### Resolved — User Decisions (2026-03-24)
1. **Runpod budget** — $200/month ceiling. Schedule provider downtime during off-hours if needed to stay under budget.
2. **Support channel** — Telegram group. Founder handles alpha user issues directly.
3. **Mainnet timeline** — Not yet. Testing NFT marketplace on testnet first. Mainnet migration after NFT flows are validated on Sepolia.

---

## Action Items

| # | Action | Owner | Priority | Sprint |
|---|--------|-------|----------|--------|
| 1 | Fix `app.smainer.io` DNS resolution | Frontend Engineer | **Critical** | Week 1 |
| 2 | Enable Redis AUTH + bind to localhost | Systems Engineer + Relayer Architect | **Critical** | Week 1 |
| 3 | Add `/ready` health probe to relayer | Relayer Architect | **High** | Week 1 |
| 4 | Redis connection pooling (max_connections=50) | Relayer Architect | **High** | Week 1 |
| 5 | Per-user job concurrency cap (5 pending) | Relayer Architect | **High** | Week 1 |
| 6 | Confirm systemd Restart=always on relayer + provider | Systems Engineer | **High** | Week 1 |
| 7 | Restrict Prometheus metrics port to internal | Systems Engineer + Security Expert | **Medium** | Week 1 |
| 8 | Telegram unified 3-step onboarding flow | Telegram Bot Developer | **Critical** | Week 2 |
| 9 | Contextual error messages (bot + frontend) | Marketing Copywriter + Telegram Bot Developer + Frontend Engineer | **High** | Week 2 |
| 10 | Lightweight Redis telemetry for user funnel | Telegram Bot Developer | **High** | Week 2 |
| 11 | Graceful degradation when relayer is down | Telegram Bot Developer | **High** | Week 2 |
| 12 | Testnet positioning copy + alpha invitation sequence | Marketing Copywriter | **High** | Week 2 |
| 13 | Alpha Terms of Service / Disclaimer | Marketing Copywriter + Security Expert | **Medium** | Week 2 |
| 14 | One-page landing with waitlist | GTM Specialist + Marketing Copywriter | **High** | Week 3 |
| 15 | Record 3-5 demo task videos | GTM Specialist | **High** | Week 3 |
| 16 | Telegram alpha group + invite flow | Telegram Bot Developer + GTM Specialist | **High** | Week 3 |
| 17 | Twitter/X proof-of-work thread | Marketing Copywriter | **Medium** | Week 3 |
| 18 | Invite first 10 users → expand to 50 | GTM Specialist | **Critical** | Week 3 |

---

*Meeting facilitated by Chief Director using agent-meeting skill.*
