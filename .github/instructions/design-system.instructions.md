---
description: Enforce Smainer design system standards for spacing, colors, typography, and component patterns across all frontend code
applyTo:
  - "frontend/tailwind.config.ts"
  - "frontend/src/**/*.tsx"
  - "frontend/src/**/*.css"
  - "frontend/src/app/globals.css"
---

# Smainer Design System Standards

Enforce these design standards across all frontend code. Question any deviation from these rules.

## Color System

### Brand Colors (Tailwind Config via HSL CSS Variables)
```typescript
// Primary Brand — Professional champagne for compute marketplace
primary: '#B5A082',    // Champagne — Sophisticated, warm, professional
primary-hover: '#A18F6E', // Champagne-hover — Interaction state
primary-light: '#C4B396', // Champagne-light — Backgrounds

// Accent
accent: '#06B6D4',     // Cyan-500 — Energy, technology (unchanged)
accent-hover: '#0891B2', // Cyan-600

// Secondary
secondary: '#0F172A',  // Slate-900 — Depth, professionalism
```

### Semantic Colors
```typescript
success: '#22C55E',  // Green-500
warning: '#F59E0B',  // Amber-500
error: '#EF4444',    // Red-500
info: '#B5A082',     // Champagne — Brand consistency
```

### Grays (Use Tailwind Slate Scale)
- Use `slate-50` through `slate-950` — NO custom grays
- Default text: `slate-900` (dark mode: `slate-50`)
- Muted text: `slate-600` (dark mode: `slate-400`)
- Borders: `slate-200` (dark mode: `slate-700`)

### Rules
- **NO gradients inside components** — Use solid colors only for cards, badges, buttons
- **Hero/CTA gradient exception**: ONE `bg-gradient-to-r from-[#B5A082] to-cyan-500` gradient allowed per page, only in hero sections or final CTA banners
- **Contrast Minimum**: WCAG AA (4.5:1 text, 3:1 UI components)
- **Maximum 3 brand colors** in any single component
- **Semantic colors** for states only (success/warning/error/info)

## Spacing Scale

Use Tailwind's default spacing scale (multiples of 0.25rem = 4px):

```
1  = 0.25rem = 4px
2  = 0.5rem  = 8px
3  = 0.75rem = 12px
4  = 1rem    = 16px
6  = 1.5rem  = 24px
8  = 2rem    = 32px
12 = 3rem    = 48px
16 = 4rem    = 64px
24 = 6rem    = 96px
```

### Component Spacing Standards
- **Card padding**: `p-6` or `p-8` (never `p-5` or `p-7`)
- **Section spacing**: `space-y-8` or `space-y-12`
- **Button padding**: `px-4 py-2` (small), `px-6 py-3` (default), `px-8 py-4` (large)
- **Input padding**: `px-4 py-2`
- **Gap in flex/grid**: `gap-4`, `gap-6`, or `gap-8` (no odd numbers)

### Rules
- **NO arbitrary values** like `p-[13px]` or `mt-[22px]`
- **Consistent rhythm**: Use same spacing value within a component section
- **Mobile consideration**: Reduce spacing by one step on `sm:` breakpoint

## Typography

### Font Family
```typescript
fontFamily: {
  sans: ['Inter', 'system-ui', 'sans-serif'],
  mono: ['JetBrains Mono', 'monospace'],
}
```

### Type Scale
```
text-xs   = 0.75rem = 12px  (use sparingly — tiny labels only)
text-sm   = 0.875rem = 14px (body small, captions)
text-base = 1rem = 16px     (default body text)
text-lg   = 1.125rem = 18px (large body, subheadings)
text-xl   = 1.25rem = 20px  (small headings)
text-2xl  = 1.5rem = 24px   (section headings)
text-3xl  = 1.875rem = 30px (page headings)
text-4xl  = 2.25rem = 36px  (hero headings)
text-5xl  = 3rem = 48px     (large hero headings)
text-6xl  = 3.75rem = 60px  (main hero headline — landing page only)
```

### Font Weights
```
font-normal = 400 (body text)
font-medium = 500 (emphasis, labels)
font-semibold = 600 (headings, buttons)
font-bold = 700 (use rarely — major headings only)
```

### Line Heights
```
leading-tight = 1.25   (large headings only)
leading-snug = 1.375   (small headings)
leading-normal = 1.5   (DEFAULT for body text)
leading-relaxed = 1.625 (long-form content)
```

### Rules
- **NO more than 2 font weights** per component
- **Hierarchy through size and weight**, not font family changes
- **Line height**: Always `leading-normal` (1.5) or greater for body text
- **Letter spacing**: Default only, no custom tracking unless logo/brand

## Component Patterns

### Buttons
```tsx
// Primary CTA (Indigo)
<button className="bg-primary hover:bg-primary/90 text-white font-semibold px-6 py-3 rounded-lg transition-colors">
  Start Earning
</button>

// Secondary
<button className="bg-secondary text-secondary-foreground font-semibold px-6 py-3 rounded-lg transition-colors hover:bg-secondary/80">
  View Details
</button>

// Outline
<button className="border border-input bg-background hover:bg-accent hover:text-accent-foreground font-semibold px-6 py-3 rounded-lg transition-colors">
  Learn More
</button>
```

**Rules**:
- Always include `:hover` and `:focus-visible` states
- Always `font-semibold` for button text
- Always `transition-colors` for smooth state changes
- NO icon-only buttons without `aria-label`

### Cards
```tsx
<div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-6 space-y-4">
  <h3 className="text-xl font-semibold text-slate-900 dark:text-slate-50">Card Title</h3>
  <p className="text-base text-slate-600 dark:text-slate-400">Card content...</p>
</div>
```

**Rules**:
- Always include dark mode variants
- Consistent `p-6` or `p-8` padding
- `space-y-4` or `space-y-6` for internal spacing
- Border for definition, NO drop shadows

### Forms
```tsx
<div className="space-y-2">
  <label htmlFor="input-id" className="block text-sm font-medium text-slate-700 dark:text-slate-300">
    Label Text
  </label>
  <input
    id="input-id"
    type="text"
    className="w-full px-4 py-2 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent"
  />
  <p className="text-sm text-slate-500">Helper text if needed</p>
</div>
```

**Rules**:
- Always associate `<label>` with `<input>` via `htmlFor`/`id`
- Always visible focus state (`focus:ring-2`)
- Error states: red border (`border-error`) + descriptive message
- NO placeholder-only inputs (always have label)

## Forbidden Patterns

### NEVER Use
- ❌ Gradients inside cards, badges, or buttons: `bg-gradient-to-r`
  - Exception: ONE hero/CTA gradient per page using `from-indigo-500 to-cyan-500`
- ❌ Drop shadows: `shadow-lg`, `shadow-xl`
- ❌ Emojis in UI text or headings
- ❌ Arbitrary spacing: `p-[13px]`, `mt-[22px]`
- ❌ Arbitrary colors: `text-[#FF5733]`
- ❌ Multiple font families in single view
- ❌ Excessive animation: `animate-bounce`, `animate-spin` (loading only)

### Use Sparingly
- ⚠️ `shadow-sm` — Only for subtle card elevation
- ⚠️ `text-xs` — Only for metadata, timestamps, tiny labels
- ⚠️ `font-bold` — Reserve for major headings only
- ⚠️ Colored backgrounds — Prefer white/slate with colored accents

## Dark Mode Standards

### Implementation
Always provide dark mode variants using `dark:` prefix:

```tsx
// Text
className="text-slate-900 dark:text-slate-50"

// Backgrounds
className="bg-white dark:bg-slate-900"

// Borders
className="border-slate-200 dark:border-slate-700"
```

### Contrast in Dark Mode
- Text on dark background must meet WCAG AA (4.5:1)
- Use `slate-50` or `slate-100` for primary text
- Use `slate-400` for muted text
- Borders: `slate-700` or `slate-600` for visibility

## Accessibility Checklist

Every component must:
- [ ] Meet WCAG AA contrast (4.5:1 text, 3:1 UI)
- [ ] Support keyboard navigation (Tab, Enter, Esc)
- [ ] Have visible focus states
- [ ] Use semantic HTML (`<button>` not `<div onclick>`)
- [ ] Include ARIA labels where needed
- [ ] Work in dark mode

## Responsive Breakpoints

Follow Tailwind defaults:
```
sm: 640px   (tablet)
md: 768px   (small desktop)
lg: 1024px  (desktop)
xl: 1280px  (large desktop)
```

### Mobile-First Approach
- Base styles = mobile
- Add `sm:`, `md:`, `lg:` prefixes for larger screens
- Reduce spacing on mobile (e.g., `p-4 md:p-6 lg:p-8`)

## Enforcement

When reviewing code:
1. **Flag violations immediately** with specific reference to this document
2. **Suggest exact fix** with corrected class names
3. **Explain impact** on brand consistency or accessibility
4. **Reject arbitrary values** unless explicitly justified for edge cases

This design system is non-negotiable. Every deviation weakens brand identity and user experience.
