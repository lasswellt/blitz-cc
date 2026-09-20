---
name: ui-build
description: "Use when the user says 'build a page', 'create UI', 'add a form', 'build UI for X', 'add a screen', or 'extract design system' / 'build DESIGN.md'. Discovers the project's components, tokens, and conventions (extracting DESIGN.md when absent), then builds production-grade Vue 3 UI native to it."
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, ToolSearch, AskUserQuestion
model: inherit
compatibility: ">=2.1.271"
paths:
  - "**/*.vue"
  - "**/*.nuxt.{ts,js}"
  - "**/components/**/*.{vue,ts,js}"
  - "**/pages/**/*.{vue,ts,js}"
  - "**/layouts/**/*.{vue,ts,js}"
---
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

Build production-grade Vue 3 UI native to the project. Follow the 5-phase workflow strictly in order. Never skip phases. Each phase feeds the next.

## Additional Resources
- UX principles, wireframe templates, accessibility checklist: [references/main.md](references/main.md)
- Design-system extraction → `DESIGN.md` (run when none exists): [references/design-extract.md](references/design-extract.md)
- Output style: [/_shared/output.md](/_shared/output.md)

---

## Phase 0: SESSION — Register and Check for Conflicts

Follow [sessions.md](/_shared/sessions.md) §2 (claim the hook-created record, run the conflict matrix) and [output.md](/_shared/output.md). Print progress at every phase transition, decision point, and agent dispatch.

---

## Phase 1: DISCOVER

**Goal**: Build a mental model of how this project constructs UI.

**Rule: when no `DESIGN.md` exists at the repo root, run the extraction in [references/design-extract.md](references/design-extract.md) first** (also when the user asks to "extract design system"). It emits `DESIGN.md` from the project's tokens, fonts, and palette; steps 1–5 below then read it instead of re-discovering. With an existing `DESIGN.md`, read it and only note drift.

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

Mandatory and before any markup: pick the direction, then build to it. Prompts and the adapter-gated token rules: [references/main.md](references/main.md) §3.0 Aesthetic Direction.

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
Invoke: `/blitz:check --only completeness` scoped to changed files. Three-state coverage (check 2.10) must pass for all new data views. Critical/high findings must be resolved before proceeding.

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

Screenshots the rendered page and scores it with the `design-critic` agent against `DESIGN.md`, iterating on the weak dimensions. Loop, rubric and stop condition: [references/main.md](references/main.md) §5.4 Visual Validation.

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

Every component and function must be fully implemented. See [Definition of Done](/_shared/quality.md).

**BANNED PATTERNS** — if any appear, the work is not done:

- `return {}` / `return []` / `return null` as placeholder returns
- `throw new Error('Not implemented')` / `throw new Error('TODO')`
- Empty event handlers (`() => {}`, `@click=""`)
- Store actions returning hardcoded data instead of calling real APIs
- `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code should be
- Components rendering static text where dynamic data should be

**SELF-CHECK:** *"If this page went live right now, would every button, form, and data display actually work?"*
