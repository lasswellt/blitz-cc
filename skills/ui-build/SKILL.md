---
name: ui-build
description: "Researches the codebase's design patterns (component library, layout system, design tokens, accessibility conventions) then generates production-grade Vue 3 UI that feels native to the project. Runs a 5-phase workflow (Discover → Analyze → Design → Implement → Refine). Use when the user says 'build a page', 'create UI', 'add a form', 'design component', 'build UI for X', 'add a screen for Y'."
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, ToolSearch, AskUserQuestion
model: opus
effort: high
compatibility: ">=2.1.71"
paths:
  - "**/*.vue"
  - "**/*.nuxt.{ts,js}"
  - "**/components/**/*.{vue,ts,js}"
  - "**/pages/**/*.{vue,ts,js}"
  - "**/layouts/**/*.{vue,ts,js}"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

Build production-grade Vue 3 UI native to the project. Follow the 5-phase workflow strictly in order. Never skip phases. Each phase feeds the next.

## Additional Resources
- UX principles, wireframe templates, accessibility checklist: [references/main.md](references/main.md)
- Output style: [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

## Phase 0: SESSION — Register and Check for Conflicts

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

---

## Phase 1: DISCOVER

**Goal**: Build a mental model of how this project constructs UI.

1. **Design Tokens** — Find theme/token source (CSS vars, Tailwind config, Quasar variables, Vuetify theme). Glob: `**/*.css`, `**/tailwind.config.*`, `**/quasar.config.*`, `**/vuetify.*`, `**/variables.scss`, `**/variables.sass`. Document: color palette, spacing scale, typography, border-radius, shadows, z-index.
2. **Component Inventory** — Identify shared/base components. Search: `**/components/{base,shared,common,ui}/**`. Note: name, props, slots, emits.
3. **Page Anatomy** — Read 2-3 representative pages. Document: layout wrapper, section structure, spacing, data flow.
4. **Data Patterns** — Find Pinia stores, composables, API clients. Document: TypeScript interfaces, loading/error conventions.
5. **Output** — Write discovery summary: token map, reusable components + signatures, layout wrapper(s), data layer conventions, naming conventions (files, components, CSS).

---

## Phase 2: ANALYZE

**Goal**: Synthesize discovery into a machine-readable design profile.

Produce a mental design profile:

```
Framework: [Vue 3 + Vite | Nuxt 3 | ...]
UI Framework: [Tailwind CSS | Quasar | Vuetify | None]
Component Pattern: [SFC Composition API | SFC Options API | ...]
State Management: [Pinia | Vuex | Composables | ...]
CSS Strategy: [Utility-first | Scoped CSS | CSS Modules | ...]
Color Token Format: [CSS vars | Tailwind classes | Framework theme | ...]
Layout Wrapper: [component name or "none"]
Loading Pattern: [skeleton | spinner | overlay | ...]
Error Pattern: [inline | toast | error boundary | ...]
Empty State Pattern: [illustration + text | simple text | ...]
Naming - Files: [kebab-case | PascalCase | ...]
Naming - Components: [PascalCase with prefix | ...]
Naming - CSS: [BEM | utility | scoped | ...]
```

Cross-check every field against actual code. Re-read source to resolve uncertainty.

---

## Phase 3: DESIGN

**Goal**: Pick aesthetic direction, clarify requirements, produce component specs before writing code.

### 3.0 Aesthetic Direction (mandatory; precedes wireframe)

**Brownfield (existing tokens detected in Phase 1.1):** stay native. Reuse project typography, palette, spacing. Skip to §3.0.2.

**Greenfield / no design system:** invoke `frontend-design:frontend-design` if available. Otherwise execute §3.0.1.

#### 3.0.1 Inline tone selection (when frontend-design unavailable)

Pick exactly ONE tone (do not blend):

`brutalist/minimal`, `maximalist`, `retro-futuristic`, `organic/natural`, `luxury/refined`, `playful/toy-like`, `editorial/magazine`, `art-deco`, `soft/pastel`, `industrial`, `dark/moody`, `lo-fi/zine`, `handcrafted/artisanal`

Commit to:
- **TYPOGRAPHY PAIR**: distinctive display + refined body. **BANNED**: Inter, Roboto, Arial, system-ui as primary, Space Grotesk.
- **ACCENT COLOR**: one accent unless multi-color system required. **BANNED**: purple-gradient-on-white. Use CSS variables.
- **MOTION PRINCIPLE** (pick one): `one orchestrated reveal (staggered animation-delay)`, `scattered micro-interactions`, or `none/static`.
- **COMPOSITION** (pick one): `generous whitespace` or `controlled density`. Asymmetry, overlap, diagonal flow encouraged when serving the tone.

#### 3.0.1.1 Generation rubric — steer with the criteria the evaluator will grade (E1)

Carry the **same 5 dimensions `agents/design-critic.md` §2 scores against** as forward steering. Canonical single source: [`/_shared/design-criteria.md`](/_shared/design-criteria.md). Internalize before wireframing:

> The best designs are museum quality. Build to that bar from the first pass.
> Prompt Adherence · Aesthetic Fit · Visual Polish · UX · **Creative Distinction** (the hardest
> bar — if it could come from any AI tool circa 2025, it fails). Grade-hardest emphasis:
> Creative Distinction + Aesthetic Fit.

#### 3.0.2 Document choices to DESIGN.md

Write/update `DESIGN.md` (Google Labs Apache-2.0 spec — see `skills/design-extract/SKILL.md`) with tone, typography, palette, motion. The aesthetic NEVER-list + 13-tone palette are the **design pillar** ([references-regrounded.md §8.1](../../docs/integrations/impeccable/references-regrounded.md)); inline aesthetic greps in the Implementation Gate are superseded by `/blitz:review --only design`.

For brownfield without DESIGN.md, run `/blitz:design-extract` first.

### 3.1 Requirements Clarification

If ambiguous, use `AskUserQuestion`:
- What data does this page/component display?
- What actions can the user take?
- Role-based visibility rules?
- Empty/zero-data state?
- Navigation entry point?

### 3.2 Wireframe

ASCII wireframe showing: layout grid, component placement + names, responsive breakpoint behavior (sm/md/lg). Use the wireframe template format from references/main.md.

### 3.3 Component Specs

For each new component:
- **Name**: PascalCase per project conventions
- **Props**: TypeScript interface with defaults
- **Emits**: event names + payload types
- **Slots**: named slots with expected content
- **States**: Loading, Empty, Error, Populated
- **Composition**: child components used
- **Estimated lines**: under 300

### 3.4 Data Flow

Document: owning store/composable, fetch trigger (route guard / onMounted / watch), mutation flow (optimistic vs pessimistic), cache/invalidation strategy.

---

## Phase 4: IMPLEMENT

**Goal**: Build bottom-up, smallest pieces first.

Build order (strict):
1. TypeScript types — interfaces, enums, type guards
2. Composable / Store — data fetching, state, actions
3. Atom components — badges, chips, status indicators
4. Composite components — cards, list items, form sections
5. Page component — orchestrates composites, handles layout
6. Router entry — add route definition
7. Navigation entry — add menu/nav item

### Implementation Gate

Before entering Phase 5, verify:

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Type-check | 0 new errors | Fix before proceeding |
| Lint | 0 errors (warnings OK) | Fix before proceeding |
| Component size | No file > 300 lines | Extract sub-components |
| Three-state coverage | All data views have loading, error, and empty states | Add missing states |
| Hardcoded colors | None — design tokens only | Replace with tokens |
| **Banned fonts** | None of `Inter`, `Roboto`, `Arial`, `Space Grotesk` as primary in CSS/Tailwind | Replace with project DESIGN.md typography pair |
| **`prefers-reduced-motion`** | Required if any `animate-`, `transition-`, or motion library used | Add `@media (prefers-reduced-motion: reduce) { ... }` override |
| **`console.log`** | Zero in `.vue`/`.ts` source | Remove or replace with structured logger |
| **Inline `style="..."`** | Forbidden except for dynamic dimensions (e.g., calc'd widths) | Move to scoped styles or design tokens |

```bash
npm run type-check 2>&1 | tail -20
npx eslint <new-files> 2>&1 | tail -20
wc -l <new-vue-files> | sort -n | tail -5

# Aesthetic gates
CHANGED=$(git diff --name-only HEAD -- '*.vue' '*.css' '*.ts' '*.tsx')
[ -z "$CHANGED" ] || {
  # Banned-font check (allow as fallback after a custom font-family token, but not as primary)
  grep -lE "font-family:\s*['\"]?(Inter|Roboto|Arial|Space Grotesk)" $CHANGED 2>/dev/null \
    && echo "FAIL: banned font detected in primary position; use DESIGN.md typography pair"
  # Hardcoded color check
  grep -lE "#[0-9a-fA-F]{3,6}|rgb\(|hsl\(" $CHANGED 2>/dev/null \
    && echo "WARN: hardcoded color detected; prefer CSS var / design token"
  # prefers-reduced-motion required if animate-/transition- used
  for f in $CHANGED; do
    grep -qE "(animate-|transition-|@keyframes|motion\.|useMotion)" "$f" 2>/dev/null \
      && ! grep -qE "prefers-reduced-motion" "$f" "$(dirname "$f")"/*.css 2>/dev/null \
      && echo "FAIL: $f uses motion but no prefers-reduced-motion override"
  done
  # console.log
  grep -lE "console\.(log|debug|info)\(" $CHANGED 2>/dev/null \
    && echo "FAIL: console.log present"
}
```

Fix all failures before Phase 5. Maximum 3 fix iterations.

### Implementation Rules

Every data-displaying component MUST handle three states:
```vue
<template>
  <!-- LOADING STATE -->
  <LoadingSkeleton v-if="loading" />

  <!-- EMPTY STATE -->
  <EmptyState v-else-if="!items?.length" />

  <!-- ERROR STATE -->
  <ErrorDisplay v-else-if="error" :error="error" />

  <!-- POPULATED STATE -->
  <div v-else>
    <!-- actual content -->
  </div>
</template>
```

Code quality gates:
- No component over 300 lines — extract sub-components
- No `any` types — use proper interfaces
- No hardcoded colors — use design tokens only
- No new layout wrappers if project has existing ones
- No `!important` overrides
- All user-facing strings extractable (no buried literals in template logic)
- Props must have TypeScript types and sensible defaults; emits must be typed

File creation pattern: create `.vue` file → add TypeScript types → export from barrel if used → add to router if a page.

---

## Phase 5: REFINE

**Goal**: Polish, verify, harden.

### 5.1 Quality Checklist

- [ ] Three states (loading, empty, error) on every data view
- [ ] No hardcoded colors or magic numbers
- [ ] No component exceeds 300 lines
- [ ] Props typed with defaults; emits typed
- [ ] Naming follows project conventions
- [ ] Responsive behavior defined (not just desktop)

### 5.1.5 Completeness Gate

```bash
CHANGED_FILES=$(git diff --name-only HEAD~1 -- '*.vue' '*.ts')
```
Invoke: `/blitz:review --only completeness` scoped to changed files. Three-state coverage (check 2.10) must pass for all new data views. Critical/high findings must be resolved before proceeding.

### 5.2 Accessibility Audit

- [ ] Buttons have accessible names
- [ ] Form inputs have labels
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for text)
- [ ] Focus order is logical
- [ ] ARIA attributes where needed (roles, labels, live regions)
- [ ] Keyboard navigation works (no mouse-only interactions)

### 5.3 Performance Check

- [ ] No N+1 data fetching
- [ ] Large lists use virtual scrolling or pagination
- [ ] Images have dimensions set (no layout shift)
- [ ] Heavy below-fold components use `defineAsyncComponent`

### 5.4 Visual Validation + Design-Quality Critique

Use ToolSearch to check for Playwright MCP tools. Design-critic **navigates the live page** before scoring (E2); needs dev server running + Playwright MCP. If Playwright unavailable, fall back to static-screenshot path and warn user that interaction/responsive/console coverage is incomplete (never silently pass interaction-dependent dimensions).

#### 5.4.1 Layout sanity

Navigate to new page/component. Screenshot at 375 / 768 / 1440 widths. Verify: no overflow, no overlapping elements, correct spacing, readable text.

#### 5.4.2 Design-quality critique (vision agent)

**Capability-relative trigger (E4).** Story frontmatter `design_quality:` is the coarse tier, but the evaluator is worth its cost only when the page sits beyond what the model does reliably solo. Trigger:

- `skip` (internal admin pages) — never evaluate.
- `high` (marketing, landing, customer-facing) — **always** evaluate. Run the bounded refine-vs-pivot loop below.
- `standard` (most user-facing UI) — evaluate **only if** an edge-of-solo-capability signal fires: (a) **novel aesthetic** — committed tone absent from DESIGN.md/run history; (b) **interaction complexity** — forms, multi-step flows, stateful widgets; (c) **low generator self-confidence** — generator self-reports uncertainty after Phase 4; (d) **deterministic-lane hits** — `npx impeccable detect` returned findings. If none fire, ship solo.

When triggered, spawn `agents/design-critic.md`:

```
Agent({
  subagent_type: "blitz:design-critic",
  description: "Design-quality critique (live nav)",
  prompt: "Navigate the live page at <dev-server URL> (fallback: screenshots /tmp/ui-build-screenshots/*.png). Exercise primary actions, interactive states, and responsive breakpoints before scoring. Grade against /_shared/design-criteria.md + DESIGN.md. Score 5 dimensions 0–10: Prompt Adherence, Aesthetic Fit, Visual Polish, UX, Creative Distinction. Pass ≥7 on all five. If static fallback, note coverage_boundary; never silently pass interaction dims. Output style: terse-technical per /_shared/terse-output.md. Return ONLY the canonical JSON — no prose, no preamble."
})
```

**Bounded refine-vs-pivot loop (E2/E3, `design_quality: high`).** After each evaluation, decide strategically — refine if scores trend up, **pivot** to a different tone if stuck. Pivot space is the 13-tone menu (§3.0.1).

```
ceiling = min(MAX_DESIGN_ITERS_HIGH, budget_remaining_iters)   # MAX_DESIGN_ITERS_HIGH default 10
                                                               # (article ran 5–15; cost-aware midpoint)
                                                               # budget bound per /_shared/agent-orchestration.md
after evaluation N (scores S_N), trend = mean(S_N) - mean(S_{N-1}):   # first iter has no trend → REFINE
  PASS (all dims ≥7)                          → STOP (ship)
  trend > +0.5                                → REFINE: feed critique to Phase 4 IMPLEMENT, one
                                                 revision of the CURRENT tone (surface to user first)
  N ≥ PIVOT_AFTER (default 4) and trend ≤ +0.5 → PIVOT: abandon current tone, re-enter §3.0.1 and
                                                 commit to a DIFFERENT untried tone; regenerate
                                                 carrying forward structure/content, not the failed
                                                 aesthetic; log the pivot (tone→tone, why) to the feed
  else                                        → REFINE
exit: PASS | ceiling reached | all reasonable tones tried → escalate to user (accept / rework / skip)
```

Track tried tones so each PIVOT picks an untried tone. The escalate exit is the **bound**, not a flat 3.

For `design_quality: standard` (when trigger fires): report scores; run at most one revision; do not auto-pivot. User decides.

---

## UI Framework Variants

Full framework-specific recipe detail (Tailwind / Quasar / Vuetify): [references/main.md](references/main.md#ui-framework-variants).

---

## Critical Anti-Patterns (NEVER DO THESE)

1. **Never hardcode hex/rgb colors** — use design tokens (CSS vars, Tailwind classes, framework theme).
2. **Never ship fewer than three states on data views** — loading skeleton, empty, error, populated. No exceptions.
3. **Never use `any` type** — use proper interfaces; `unknown` + type guards; `Record<string, unknown>` for truly dynamic objects.
4. **Never invent new layout wrappers** — use `<AppLayout>`, `<PageContainer>`, `<q-page>`, or whatever the project provides.
5. **Never ship a component over 300 lines** — extract sub-components.
6. **Never fight the UI framework** — no `!important`, no CSS counteracting framework defaults. Use the correct prop, slot, or theme config.
7. **Never skip the discovery phase** — building without understanding existing patterns guarantees inconsistency.
8. **Never assume desktop-only** — every layout decision must account for mobile from the start.

---

## Production Readiness (NON-NEGOTIABLE)

Every component and function must be fully implemented. See [Definition of Done](/_shared/sprint-contracts.md).

**BANNED PATTERNS** — if any appear, the work is not done:

- `return {}` / `return []` / `return null` as placeholder returns
- `throw new Error('Not implemented')` / `throw new Error('TODO')`
- Empty event handlers (`() => {}`, `@click=""`)
- Store actions returning hardcoded data instead of calling real APIs
- `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code should be
- Components rendering static text where dynamic data should be

**SELF-CHECK:** *"If this page went live right now, would every button, form, and data display actually work?"*
