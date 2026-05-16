---
name: bootstrap
description: "Scaffolds new projects, features, or packages with project conventions auto-detected. Distinguishes greenfield (creates package.json, src/, docs/, empty roadmap stubs) from existing projects (adds to existing structure). Use when the user says 'bootstrap', 'scaffold', 'init a new project', 'set up a Vue/Nuxt/Firebase project', 'create a new package'. Required first step in the greenfield pipeline before /blitz:research and /blitz:roadmap."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<type: project|feature|package> <name>"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For pipeline artifact contracts (what bootstrap produces for sprint-plan/sprint-dev), see [/_shared/state-handoff.md](/_shared/state-handoff.md)
- For package install policy (always resolve to registry latest, never invent versions from training memory), see [/_shared/package-install-policy.md](/_shared/package-install-policy.md). Applies to every `pnpm add` / `npm install` issued during scaffold.
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** destructive-op confirmations (rm, drop-table, force-push warnings). Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Project Bootstrap

Scaffold new projects, features, or packages following established conventions. Detect existing project patterns; match new code to them. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER overwrite existing files without explicit user confirmation.** If a file already exists at a planned path, ask the user whether to skip or overwrite.

2. **NEVER generate placeholder/stub code.** All generated code must be functional. No `TODO`, `FIXME`, empty function bodies, or `throw new Error('not implemented')`. See [Definition of Done](/_shared/definition-of-done.md).

3. **NEVER install packages without user confirmation for major additions.** Minor dev dependencies (types, test utils) are acceptable; new frameworks or large libraries require explicit consent.

4. **ALWAYS follow existing project conventions** (naming, structure, patterns). When conventions conflict with best practices, existing conventions win.

5. **ALWAYS generate TypeScript** (never plain JS) unless the project exclusively uses JavaScript.

6. **NEVER leave placeholder code behind.** All generated files must be complete and functional.

---

## Phase 0: PARSE — Understand Request

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Bootstrap Type

Extract the bootstrap type from `$ARGUMENTS`:

| Type | Description |
|------|-------------|
| `project` | Create a new project from scratch (greenfield) |
| `feature` | Add a new feature to existing project (component + store + route + tests) |
| `package` | Add a new package to a monorepo workspace |

If no type is provided, ask the user.

### 0.2 Parse Name

Extract the name/identifier for what is being created. If not provided, ask the user.

---

## Phase 1: DISCOVER — Analyze Conventions

### 1.1 For Existing Projects (feature/package mode)

Scan the existing codebase for conventions:

```bash
# File naming convention
find . -path '*/components/*' -name '*.vue' -o -path '*/stores/*' -name '*.ts' | grep -v node_modules | head -20

# Test file location
find . -name '*.test.*' -o -name '*.spec.*' | grep -v node_modules | head -20
```

Extract:
- **File naming**: kebab-case, PascalCase, or camelCase
- **Directory structure**: flat, domain-grouped, or feature-grouped
- **Component patterns**: `<script setup>`, options API, or composition API
- **Store patterns**: Pinia setup syntax vs options syntax
- **Test file location**: co-located, `__tests__/`, or `tests/`
- **Route structure**: file-based (Nuxt pages/) or config (Vue Router)
- **Import style**: absolute paths, aliases (`@/`, `~/`)

Read 2-3 exemplar files from each category to confirm patterns.

### 1.2 For Greenfield (project mode)

Ask user to confirm stack choices:

```
Project Setup:
  Framework:  Vue 3 + Vite  |  Nuxt 3
  UI:         Tailwind CSS  |  Quasar  |  Vuetify  |  None
  Backend:    Firebase/GCP  |  None
  Testing:    Vitest
  Pkg mgr:    pnpm (preferred)  |  npm  |  yarn

  Confirm choices? [y/n]
```

---

## Phase 2: DESIGN — Plan Scaffold

### 2.1 Feature Scaffold

For a feature named `<name>`, plan files based on detected conventions:

| File | Path Pattern |
|------|-------------|
| Component | `<convention>/Name.vue` or `<convention>/name.vue` |
| Store | `stores/<name>.ts` |
| Composable (if needed) | `composables/use<Name>.ts` |
| Route (if page) | `pages/<name>.vue` (Nuxt) or router entry (Vite) |
| Test file | Based on detected convention |
| Type file (if complex) | `types/<name>.ts` |

### 2.2 Package Scaffold

For a monorepo package named `<name>`:

| File | Path |
|------|------|
| Package manifest | `packages/<name>/package.json` |
| Entry point | `packages/<name>/src/index.ts` |
| TypeScript config | `packages/<name>/tsconfig.json` |
| Test config (if Vitest) | `packages/<name>/vitest.config.ts` |

### 2.3 Project Scaffold

For a greenfield project, plan the full directory structure based on stack choices from Phase 1.2.

### 2.4 Present Plan

Show the planned files to the user before creating anything:

```
Bootstrap Plan: <type> "<name>"
  Files to create:
    1. src/components/feature/FeatureName.vue
    2. src/stores/featureName.ts
    3. src/composables/useFeatureName.ts
    4. src/components/feature/__tests__/FeatureName.test.ts
    5. (route entry if page)

  Proceed? [y/n]
```

Wait for user confirmation before proceeding.

---

## Phase 3: IMPLEMENT — Generate Files

### 3.1 Generate Files

For each planned file, generate REAL code (not stubs):

**Components**: Full `<script setup lang="ts">` with typed props and emits. For data-display components, use three-state pattern (loading, error, data). Template must contain real markup, not placeholder comments.

**Stores**: Pinia setup syntax with reactive state, loading/error tracking, and action functions that call service functions. Only the API endpoint URL may use a TODO comment.

**Composables**: `useXxx` pattern returning `{ data, loading, error, execute }` with proper TypeScript generics and reactive refs.

**Tests**: AAA pattern (Arrange, Act, Assert) with factory functions for test data. At least one meaningful test per file. Follow project test conventions discovered in Phase 1.

**Types**: TypeScript interfaces and types for the feature's domain model. Export all types.

### 3.2 Wire Up Routes (if page)

- **Nuxt**: Create the page file in `pages/` directory (file-based routing handles the rest).
- **Vue Router**: Add route entry to the router configuration file.

### 3.3 Update Barrel Exports

If the project uses `index.ts` barrel files, add exports for new files:
```bash
# Check for barrel files in target directories
find . -name 'index.ts' -path '*/components/*' -o -name 'index.ts' -path '*/stores/*' | grep -v node_modules | head -10
```

If barrel files exist, append exports for the new files.

---

## Phase 4: VERIFY — Check Generated Code

### 4.1 Type Check

```bash
npx tsc --noEmit 2>&1
```

Must produce no new type errors.

### 4.2 Lint

```bash
npx eslint <new-files> 2>&1
```

Fix any lint errors in the generated code.

### 4.3 Test

```bash
npx vitest run <test-files> 2>&1
```

All generated tests must pass.

### 4.4 Fix Issues

If any verification fails, fix the generated code. Maximum 3 fix iterations. If still failing after 3 attempts, report the issue to the user.

### 4.5 Exit Criteria (Gate)

All of the following must pass before proceeding to Phase 5:

| Criterion | Check | Required |
|-----------|-------|----------|
| All planned files created | Verify each file from Phase 2 exists | Yes |
| Type-check passes | `npm run type-check` exits 0 | Yes |
| Lint passes | `npm run lint` on new files exits 0 | Yes |
| Tests pass | Generated tests all pass | Yes |
| No placeholders | Run completeness-gate on new files — no critical/high findings | Yes |
| Routes accessible | If page was created, route is defined and reachable | Yes (if applicable) |

**Maximum 3 fix attempts per failing criterion.** After 3 attempts, report partial success:

```
Bootstrap Partial Success: <type> "<name>"
  Files created: N/M
  Passing criteria: X/Y

  Failed criteria:
    - Type-check: 2 errors remaining (see details)
    - Completeness: 1 high finding (empty handler in store)

  Manual fixes needed:
    1. <specific fix description>
    2. <specific fix description>
```

---

## Phase 5: REPORT

### 5.1 Output Summary

```
Bootstrap Complete: <type> "<name>"
  Files created: N
  Type-check: PASS/FAIL
  Lint: PASS/FAIL
  Tests: PASS/FAIL (N/N passed)

  Next steps:
    - Implement business logic in store actions
    - Add UI content to component template
    - Run /blitz:test-gen to add more tests
```

### 5.2 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Append `session_end` to the operations log

---

## Error Recovery

- **Naming convention cannot be determined**: Default to kebab-case files, PascalCase components.
- **Project type detection fails**: Ask user to specify framework explicitly.
- **File already exists**: Ask user whether to skip or overwrite. Never silently overwrite.
- **Type-check fails on generated code**: Fix imports and types, retry up to 3 times.
- **Monorepo workspace config cannot be detected**: Ask user for workspace root path and package manager.
- **No test runner detected**: Skip test generation and verification. Suggest setting up Vitest first.
- **Package manager unknown**: Default to pnpm. If pnpm is not installed, fall back to npm.
