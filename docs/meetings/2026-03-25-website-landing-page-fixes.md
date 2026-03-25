# Meeting: Website Landing Page Fixes

**Date:** 2026-03-25
**Facilitator:** Chief Director
**Attendees:** frontend-engineer, brand-designer, marketing-copywriter, fee-economist
**Goal:** Produce concrete fixes + final copy for 7 reported landing page issues, ready to implement.

---

## Agent Perspectives

### Frontend Engineer
**Summary:** The current landing page has solid technical foundations with glass morphism and Inter already implemented, but suffers from copy clarity, mobile layout issues, and weak GitHub link visibility. The hero messaging is confusing and the pay-per-task value prop is buried.

**Improvements:**
1. GitHub link → Add to navigation bar (right side, before ConnectButton) in `navigation.tsx`
2. Copy fixes → Direct text updates in `page.tsx` (hero headline + subtitle + metadata)
3. Font → Inter is loaded but may need `font-display: swap` and JetBrains Mono integration. Review `globals.css` variable usage
4. Mobile → Audit grid breakpoints in hero section and 3-column cards. Add proper spacing tokens
5. Pay-per-Task → New `GlassSection` between hero and value props

**Risks:** Breaking mobile layouts during responsive fixes; typography changes cascading; copy changes without brand approval creating inconsistent voice.
**Dependencies:** Final copy from marketing-copywriter, mobile layout approval from brand-designer.

---

### Brand Designer
**Summary:** Visual foundation is sound but execution gaps are killing conversion. Inter is the right font — the problem is weight distribution and mobile rendering, not the font family itself. Mobile breakage loses 60%+ of traffic. Missing GitHub icon signals "vapor project."

**Improvements:**
1. **Font Fix** — Keep Inter, hero weight to 800 (not 700), body to 500 (not 400), add `letter-spacing: -0.02em` on headings, enable `font-display: swap`
2. **Mobile-First Grid** — 16px container padding, vertical card stacking with 24px gaps, hamburger nav at <768px
3. **GitHub Icon** — SVG 24x24px in header, left of primary CTA, colored #A1A1AA (muted hierarchy)
4. **Pay-per-Task Visual** — Three-column comparison: "Traditional Cloud" vs "Per-Task" vs "Smainer Cost"

**Risks:** Mobile conversion loss every day it stays broken; missing GitHub icon = credibility gap for developer audience.
**Dependencies:** Tailwind breakpoint implementation from frontend-engineer, six-word-max headlines from copywriter.

---

### Marketing Copywriter
**Summary:** Current copy suffers from unclear positioning and Web3 jargon. "Privacy by architecture / Not Policy" is conceptually strong but wordy. Hero subtitle fails to immediately communicate what Smainer does. "Decentralized Physical Infrastructure" doesn't communicate user benefits.

**Improvements:**

**1. Privacy Headline**
- **Final:** "Privacy. Not Policy."
- **Subtitle:** "Zero data retention. Verified computation on Starknet."

**2. Main Headline (3 options)**
- A: "Verified GPU Compute Network"
- B: "Open Source AI Infrastructure"
- C: "Decentralized Compute Layer"

**3. Hero Subtitle (3 options)**
- A: "Run AI workloads on distributed GPU nodes. Pay in STRK tokens. Results verified on-chain with zero data retention."
- B: "Distributed GPU marketplace for AI compute tasks. Privacy-first architecture, transparent pricing, cryptographic proof of execution."
- C: "Submit compute jobs to verified GPU providers. Transparent costs, on-chain verification, complete data privacy."

**4. Pay-per-Task Section**
- **Headline:** "Usage-Based Pricing"
- **Body:** "Pay only for compute time used, not idle capacity. Transparent STRK token pricing with on-chain settlement. No subscriptions, no minimums, no surprise fees."

**Risks:** Overly technical language alienating non-Starknet users; "Privacy. Not Policy." misunderstood without context.
**Dependencies:** Brand hierarchy constraints, fee accuracy validation.

---

### Fee Economist
**Summary:** Pay-per-task messaging is mostly accurate but incomplete. "Usage-based pricing" correctly reflects the model. "No surprise fees" is accurate since users see full breakdown before committing. However, omitting the 15% protocol fee contradicts our transparency-first principle.

**Improvements:**
1. Add fee transparency: "15% platform fee included in upfront pricing" builds trust
2. Include tier differentiation: "Pricing tiers based on compute complexity"
3. Comparative positioning: "Up to 60% less than AWS spot pricing"

**Risks:** "No minimums" claim could become false if minimum task sizes are implemented for gas efficiency; omitting 15% fee violates transparency principle.
**Dependencies:** Copywriter to revise with fee disclosure, frontend-engineer to verify CostEstimator reflects messaging.

---

## Previous Action Items

| # | Action (from 2026-03-24 meeting) | Status | Notes |
|---|------|--------|-------|
| 1 | Create shared design tokens file | Open | Still needed — today's font fixes depend on this |
| 2 | Build GlassCard / GlassTable / GlassCodeBlock / GlassHero | Open | Pay-per-task section will use these |
| 3 | Implement page templates | Open | |
| 4 | Restructure navigation with dropdowns | Open | GitHub icon goes here |
| 5 | Replace homepage (4 sections per new copy) | Open | Today's meeting defines the copy |
| 8 | Brand-designer review pass | Open | Deferred until implementation lands |

---

## Cross-Agent Analysis

### Agreements
- **Keep Inter** — All agree Inter is the right font; the issue is weight/rendering, not the family
- **GitHub icon in header** — Frontend and brand agree: header position, left of CTA, muted color
- **Mobile is critical priority** — Brand and frontend align on mobile-first grid with vertical stacking
- **"Privacy. Not Policy."** — Copywriter delivered exactly what user requested; all accept
- **Pay-per-task needs its own section** — Universal agreement, glass card treatment

### Conflicts
1. **"No minimums" claim** — Copywriter wrote "no minimums." Fee economist flags this could become false if minimum task sizes are implemented for gas efficiency.
   - **Director Resolution:** Remove "no minimums" — replace with "no subscriptions, no commitments." This is provably true and avoids future liability.

2. **15% fee disclosure on landing page** — Fee economist wants explicit mention. Copywriter omitted it for cleaner messaging.
   - **Director Resolution:** Don't put "15%" on the hero landing page — it's too granular for first impression. Do include it on a dedicated pricing section/page. Hero messaging stays clean.

3. **Hero headline options** — Three options without clear winner.
   - **Director Resolution:** Go with **"Open Decentralized Computing Network"** as user originally suggested. It's the most accurate and broad. "Verified GPU Compute Network" is too narrow (not just GPU). "Open Source AI Infrastructure" implies open-source code, not open participation.

### Gaps
- **No one addressed the "Submit compute tasks..." 2-3 sentence vision statement** deeply enough. Copywriter gave 3 subtitle options but none fully capture "who we are and our vision."
- **Responsive testing plan** — No agent specified how to verify mobile fixes work across devices.

---

## Director's Opinion

The landing page needs 7 tactical fixes, not a redesign. Here's the final call on each:

### Final Copy Decisions

**Main headline:** "Open Decentralized Computing Network"

**Hero subtitle (Director's pick — Option A, lightly edited):**
"Run AI workloads on distributed GPU nodes. Pay per task in STRK. Results verified on-chain, your data never stored."

**Privacy section:** "Privacy. Not Policy." + subtitle "Zero data retention. Verified computation on Starknet."

**Pay-per-task section:**
- Headline: "Pay Per Task"
- Body: "Pay only for the compute you use. Transparent STRK pricing with on-chain settlement. No subscriptions, no commitments."

### Font Fix
Keep Inter. Apply: hero weight 800, body weight 500, headings `letter-spacing: -0.02em`, `font-display: swap`. This is the cheapest fix with the biggest visual impact.

### Mobile
Mobile-first grid: 16px padding, single-column stacking, hamburger nav at <768px. This is priority #1 — fix before any copy changes.

### GitHub Link
24x24 SVG icon in header nav, #A1A1AA, left of primary CTA. Links to `https://github.com/Smainer`.

---

## Action Items

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | Fix mobile layout: hamburger nav, single-column stacking, 16px padding | frontend-engineer | Critical |
| 2 | Fix font weights: hero 800, body 500, -0.02em tracking, font-display swap | frontend-engineer | Critical |
| 3 | Add GitHub icon (24x24 SVG, #A1A1AA) to header nav | frontend-engineer | High |
| 4 | Update hero headline to "Open Decentralized Computing Network" | frontend-engineer | High |
| 5 | Update hero subtitle to Director-approved copy above | frontend-engineer | High |
| 6 | Update privacy section to "Privacy. Not Policy." + subtitle | frontend-engineer | High |
| 7 | Build pay-per-task GlassSection with approved copy | frontend-engineer | High |
| 8 | Create dedicated pricing page with 15% fee disclosure and tier breakdown | frontend-engineer + fee-economist | Medium |
| 9 | Brand review pass after items 1-7 land | brand-designer | Medium |

---

*Meeting facilitated by Chief Director using agent-meeting skill.*
