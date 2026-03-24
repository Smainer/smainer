# Meeting: Website-MiniApp Visual Language Alignment

**Date:** 2026-03-24
**Facilitator:** Chief Director
**Attendees:** brand-designer, frontend-engineer, Telegram Bot Developer
**Goal:** Define a unified visual direction for the website that inherits the MiniApp's premium dark luxury aesthetic but elevates it — edgier, cleaner, classier — and produces concrete implementation tasks.

---

## Agent Perspectives

### Brand Designer
**Summary:** Website should be the "sophisticated older sibling" of the MiniApp — Bloomberg Terminal meets Apple developer tools. Edgy through negative space and stark contrast, clean by eliminating decorative animations, classy through disciplined typography and architectural glass morphism.

**Improvements:**
1. **Hero Discipline** — Single-focus heroes: large white type (48-64px) on void, one glass card, one CTA. No starfields or floating elements.
2. **Glass Architecture** — Expand glass morphism to full-width sections on desktop. Use 40px backdrop-blur with layered depth. "Floating workspace" aesthetic.
3. **Color Hierarchy Lock** — #3B82F6 ONLY for CTAs and active states. All other blues eliminated. Gray scale: #27272A, #202024, #141416, #71717A. No exceptions.
4. **Typography for Long-Form** — 40px headers, 24px subheads, 18px body at 1.7 line-height. JetBrains Mono code blocks with glass background.
5. **Component Unification** — All badges, tables, cards inherit glass morphism + Inter typography.
6. **Animation Restraint** — Only hover lifts (2px) and entrance fades (0.3s). Zero rotating/floating/pulsing.

**Risks:** Glass overuse confusion, void fatigue on long pages, contrast accessibility failures.
**Dependencies:** Tailwind config updates from frontend-engineer, exact CSS values from Telegram Bot Developer.

---

### Frontend Engineer
**Summary:** ~60% of UI components need rebuilding. Routing/wallet integration preserved. MiniApp's Tailwind config is the implementation blueprint. Significant overhaul, not incremental.

**Improvements:**
1. **Design Token Standardization** — Unify tailwind.config.ts with MiniApp palette. CSS custom properties for consistent theming.
2. **Glass Morphism Component Library** — Rebuild cards, modals, nav with backdrop-filter blur(20px). Glass variants for code blocks, tables, pricing.
3. **Navigation Architecture** — Responsive dropdowns for Products/Technology. Mobile slide-out panels.
4. **Content Components** — Code blocks with syntax highlighting on dark backgrounds. Comparison tables, feature grids, step guides.
5. **Page Structure/Routing** — Next.js middleware for redirects. Template system for hero/content/CTA patterns. SEO metadata.
6. **Performance** — will-change: backdrop-filter optimization. Lazy loading. CSS containment.

**Risks:** Glass morphism scroll perf on low-end devices, wallet flow breakage during migration, design system drift without shared tokens.
**Dependencies:** Finalized spacing/color specs from brand-designer, shared component patterns from Telegram Bot Developer.

---

### Telegram Bot Developer (MiniApp Owner)
**Summary:** Core design language (void, glass, blue accent, 8px grid) translates excellently to desktop. What doesn't: mobile-first density, bottom tabs, compact cards. Desktop needs more whitespace, horizontal hierarchy, multi-level nav.

**Improvements:**
1. **Keep As-Is:** Color system verbatim, typography stack, border treatment, subtle animations.
2. **Modify for Desktop:** Increase whitespace between sections. Top bar nav replaces bottom tabs. Glass cards span wider. Text capped at 65ch line-length.
3. **Add for Website:** Comparison tables (glass + subtle row striping #141416/#161618). Code blocks (JetBrains Mono on #0d0d0f, brand palette colors only). Heroes (full-bleed void + floating glass card). Timeline (vertical #27272A line + glass nodes).
4. **Extract Shared:** `<GlassCard>` primitive with configurable blur/border/elevation as shared Tailwind component.

**Risks:** Color drift without shared tokens file, animation creep, density mismatch (MiniApp spacing too tight for desktop).
**Dependencies:** Shared CSS variables file from frontend-engineer. Champagne accent decision from brand-designer.

---

## Cross-Agent Analysis

### Agreements (All 3 Agents)
- **Core tokens shared verbatim:** void #09090B, card #141416, elevated #202024, glass #27272A, blue #3B82F6
- **Kill all decorative animations:** No starfield, no floating elements, no pulsing backgrounds
- **Glass morphism as primary surface:** Cards, code blocks, tables all get glass treatment  
- **Strict 8px grid + Inter/JetBrains Mono typography**
- **Animation restraint:** Only fade-in-up + 2px hover lift
- **Blue only for interactive elements** (CTAs, active states, focus rings)

### Conflicts
1. **Champagne accent (#B5A082):** Brand designer says "no champagne" (blue-only discipline). Telegram Bot Developer asks whether champagne enters the website. The design-system.instructions.md references champagne, but MiniApp doesn't use it.
   - **Director Resolution:** No champagne on the website. Follow the MiniApp precedent. Blue #3B82F6 is the sole accent. Champagne creates visual confusion between "premium" and "crypto" vibes. Decision: **Blue only.**

2. **Backdrop blur intensity:** Brand designer proposes 40px on desktop. MiniApp uses 20px.
   - **Director Resolution:** Use **24px on desktop** as a subtle uplift from 20px without over-blurring. 40px risks performance issues on content-heavy pages. Hero sections can use 32px for impact.

3. **Typography scale:** Brand designer says 48-64px heroes, 40px section headers. MiniApp uses max 30px.
   - **Director Resolution:** Desktop gets larger scale. Heroes: 56px. Section headers: 36px. Subheads: 24px. Body: 18px at 1.7 line-height. This is appropriate for desktop viewport widths.

### Gaps
- **Dark mode fatigue:** No agent addressed how to prevent visual fatigue on content-heavy pages (Technology, How It Works have 2000+ words). Need subtle section separators — possibly alternating between void (#09090B) and very slightly lighter (#0E0E10) sections.
- **Accessibility:** No one specified WCAG contrast ratios. White (#FFFFFF) on void (#09090B) is 19.5:1 — excellent. But #71717A on #09090B is only ~4.1:1 — borderline for body text. Use #A1A1AA (7.5:1) as minimum body text gray.
- **Responsive breakpoints:** No specification for tablet behavior between mobile (MiniApp) and desktop (website).

---

## Director's Opinion

The visual direction is clearly aligned: **premium dark luxury with glass morphism, inherited from the MiniApp, scaled for desktop**. All three agents agree on the foundation. The disagreements are minor (blur intensity, accent color) and resolved above.

### Top 3 Actions
1. **Create shared design tokens file** — Single source of truth for both website and MiniApp. CSS custom properties + Tailwind preset. Prevents the color/spacing drift all three agents flagged as a risk. Owner: **frontend-engineer**.
2. **Build glass morphism component library** — GlassCard, GlassTable, GlassCodeBlock, GlassHero primitives. These are reused across all 9 pages. Owner: **frontend-engineer**.
3. **Implement page templates** — Hero + content + CTA template for each page type (product page, technical page, landing page). Ensures consistency without per-page custom styling. Owner: **frontend-engineer** with brand-designer review.

### Design Specification Summary

| Token | Value | Notes |
|-------|-------|-------|
| Background (void) | #09090B | Never pure black |
| Surface (card) | #141416 | Primary card bg |
| Surface (elevated) | #202024 | Modals, overlays |
| Surface (glass) | #27272A | Glass morphism secondary |
| Surface (alt-section) | #0E0E10 | Alternating sections on long pages |
| Accent (blue) | #3B82F6 | CTAs + active states ONLY |
| Accent hover | #2563EB | Interactive hover |
| Focus glow | rgba(59,130,246,0.4) | Focus rings |
| Text primary | #FFFFFF | Headlines, important text |
| Text secondary | #E4E4E7 | Body text |
| Text muted | #A1A1AA | Secondary body (min contrast for readability) |
| Text hint | #71717A | Labels, hints only (not body) |
| Border subtle | #27272A | 1px borders |
| Radius card | 16px | Cards, glass panels |
| Radius button | 12px | Buttons, pills |
| Blur (standard) | 24px | Desktop glass morphism |
| Blur (hero) | 32px | Hero sections only |
| Font body | Inter | 400/500/600/700 |
| Font code | JetBrains Mono | Code blocks |
| Type hero | 56px / 700 | Hero headlines |
| Type h2 | 36px / 700 | Section headers |
| Type h3 | 24px / 600 | Subheads |
| Type body | 18px / 400 / 1.7 | Long-form content |
| Type code | 14px / 400 / 1.5 | Code blocks |
| Max content width | 65ch | Long-form text |
| Grid | 8px strict | All spacing multiples of 8 |
| Animation duration | 0.2-0.3s | All transitions |
| Hover lift | 2px translateY | Interactive cards |
| Entrance | fade-in-up 0.3s | Section entrances |

## Action Items

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | Create shared design tokens file (CSS vars + Tailwind preset) | frontend-engineer | Critical |
| 2 | Build GlassCard / GlassTable / GlassCodeBlock / GlassHero components | frontend-engineer | Critical |
| 3 | Implement page templates (product, technical, landing) | frontend-engineer | High |
| 4 | Restructure navigation with Products/Technology dropdowns | frontend-engineer | High |
| 5 | Implement route redirects for deprecated pages | frontend-engineer | Medium |
| 6 | Replace homepage (4 sections per new copy) | frontend-engineer | High |
| 7 | Build 8 new/restructured pages with content from docs/website-copy-v2.md | frontend-engineer | High |
| 8 | Brand-designer review pass on completed pages | brand-designer | Medium |
| 9 | Performance testing for glass morphism on low-end devices | frontend-engineer | Medium |
| 10 | Accessibility audit (contrast ratios, focus states) | frontend-engineer | Medium |

---

*Meeting facilitated by Chief Director using agent-meeting skill.*
