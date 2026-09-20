# Onboard — Reference Material

Scaffold trees, convention detection, file templates (greenfield and package mode), and the map-mode dimension prompt, checklists, rubric and grep patterns. `SKILL.md` names the section it needs at each phase.

---

## Scaffold Trees

### Nuxt 3 + Tailwind (+ Firebase)

```
<project>/
├── app.vue
├── nuxt.config.ts
├── tailwind.config.ts
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── pages/
│   └── index.vue
├── components/
├── composables/
│   └── useAsync.ts
├── stores/
│   └── app.ts
├── server/
│   └── api/
├── types/
│   └── index.ts
├── tests/
│   └── app.test.ts
├── docs/
│   ├── plans/.gitkeep
│   └── solutions/.gitkeep
├── .claude/settings.json
├── .gitignore
├── README.md
└── (Backend=Firebase) firebase.json, .firebaserc, firestore.rules, firestore.indexes.json,
    functions/{package.json, tsconfig.json, src/index.ts}, tests/rules.test.ts
```

### Vue 3 + Vite + Tailwind

```
<project>/
├── src/
│   ├── App.vue
│   ├── main.ts
│   ├── router/index.ts
│   ├── components/
│   ├── composables/useAsync.ts
│   ├── stores/app.ts
│   ├── types/index.ts
│   └── assets/
├── vite.config.ts
├── tailwind.config.ts
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── tests/app.test.ts
├── docs/{plans,solutions}/.gitkeep
├── .claude/settings.json
├── .gitignore
└── README.md
```

### Package (monorepo)

```
packages/<name>/
├── package.json        # "name": "@<scope>/<name>", "type": "module", "exports": {".": "./src/index.ts"}
├── tsconfig.json       # extends the workspace base
├── vitest.config.ts    # only when the workspace uses Vitest
├── src/
│   └── index.ts
└── tests/
    └── index.test.ts
```

Copy `package.json` and `tsconfig.json` shape from a sibling package; only `name`, `description` and `exports` change.

---

## Convention Detection

Package mode reads these before planning; greenfield mode uses the fallback column.

| Convention | Detection | Fallback |
|---|---|---|
| File naming | case pattern of files under `components/` | kebab-case files, PascalCase components |
| Directory grouping | flat vs `components/<domain>/` vs `features/<name>/` | domain-grouped |
| Component style | `<script setup>` vs `<script>` (options API) | `<script setup lang="ts">` |
| Store syntax | `defineStore('x', () => …)` vs `defineStore('x', { … })` | setup syntax |
| Test location | where `*.test.*` / `*.spec.*` live | co-located |
| Test naming | `*.test.ts` vs `*.spec.ts` | `*.test.ts` |
| Import aliases | `compilerOptions.paths` in `tsconfig.json` | `@/` → `src/`, `~/` (Nuxt) |
| Routing | `pages/` directory (Nuxt file-based) vs `router/` config | file-based on Nuxt, config on Vite |
| CSS approach | `tailwind.config.*`, `quasar`, `vuetify` in `package.json` | scoped CSS |
| Package manager | `pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` / `bun.lockb` | pnpm |
| Workspace | `pnpm-workspace.yaml`, `workspaces` in `package.json`, `nx.json`, `turbo.json`, `lerna.json` | none (package mode stops) |

Existing-file check before every Write:

```bash
[ -f "<planned-path>" ] && echo "EXISTS — ask" || echo "SAFE — create"
[ -f "<dir>/index.ts" ] && echo "APPEND export" || echo "CREATE barrel"
```

---

## File Templates

Every template ships complete: no `TODO`, no empty bodies. Fill the domain nouns from `<name>`.

### `.claude/settings.json`

```json
{
  "worktree": { "baseRef": "head" },
  "subagentPromptCacheTtl": "1h"
}
```

If the file exists, print this as a merge suggestion and leave the file alone.

### `.gitignore` additions

```
node_modules/
dist/
.output/
.nuxt/
coverage/
.env
.env.*
!.env.example
.cc-sessions/
.claude/worktrees/
```

Append only lines not already present (`grep -qxF '<line>' .gitignore || echo '<line>' >> .gitignore`).

### `package.json` scripts

```json
{
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "type-check": "nuxt typecheck",
    "lint": "eslint .",
    "test": "vitest run",
    "test:rules": "firebase emulators:exec --only firestore \"vitest run tests/rules.test.ts\""
  }
}
```

Vite variant: `"dev": "vite"`, `"build": "vue-tsc --noEmit && vite build"`, `"type-check": "vue-tsc --noEmit"`. Drop `test:rules` when Backend=None. Dependencies are installed with the package manager, never hand-written with versions ([/_shared/security.md](/_shared/security.md) §Package Install Policy).

### Vue component

```vue
<script setup lang="ts">
import type { Item } from '@/types'

interface Props {
  items: Item[]
  loading?: boolean
  error?: string | null
}

const props = withDefaults(defineProps<Props>(), { loading: false, error: null })
const emit = defineEmits<{ select: [item: Item] }>()
</script>

<template>
  <section>
    <p v-if="props.loading">Loading…</p>
    <p v-else-if="props.error" role="alert">{{ props.error }}</p>
    <ul v-else-if="props.items.length">
      <li v-for="item in props.items" :key="item.id">
        <button type="button" @click="emit('select', item)">{{ item.name }}</button>
      </li>
    </ul>
    <p v-else>No items yet.</p>
  </section>
</template>
```

### Pinia store (setup syntax)

```typescript
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import type { Item } from '@/types'
import { listItems } from '@/services/items'

export const useItemsStore = defineStore('items', () => {
  const items = ref<Item[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const count = computed(() => items.value.length)

  async function fetchItems() {
    loading.value = true
    error.value = null
    try {
      items.value = await listItems()
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch items'
    } finally {
      loading.value = false
    }
  }

  return { items, loading, error, count, fetchItems }
})
```

`services/items.ts` exports `listItems(): Promise<Item[]>` — in greenfield it returns a typed in-memory list; with Firebase it wraps `getDocs(collection(db, 'items'))`.

### Composable

```typescript
import { ref, shallowRef } from 'vue'

export function useAsync<T>(fn: () => Promise<T>) {
  const data = shallowRef<T | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function execute() {
    loading.value = true
    error.value = null
    try {
      data.value = await fn()
    } catch (e) {
      error.value = e instanceof Error ? e.message : String(e)
    } finally {
      loading.value = false
    }
    return data.value
  }

  return { data, loading, error, execute }
}
```

### Test (AAA, factory)

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useItemsStore } from '@/stores/app'
import type { Item } from '@/types'

const makeItem = (over: Partial<Item> = {}): Item => ({ id: 'i-1', name: 'One', ...over })

describe('useItemsStore', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('counts items after a fetch', async () => {
    const store = useItemsStore()
    await store.fetchItems()
    expect(store.count).toBe(store.items.length)
    expect(store.error).toBeNull()
  })

  it('exposes a typed factory shape', () => {
    expect(makeItem({ name: 'Two' })).toEqual({ id: 'i-1', name: 'Two' })
  })
})
```

### Firestore rules test (Backend=Firebase)

```typescript
import { describe, it, beforeAll, afterAll } from 'vitest'
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { doc, getDoc, setDoc } from 'firebase/firestore'

let env: RulesTestEnvironment
beforeAll(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-<name>', firestore: { rules: readFileSync('firestore.rules', 'utf8') } })
})
afterAll(() => env.cleanup())

describe('firestore.rules', () => {
  it('denies anonymous writes', async () => {
    const db = env.unauthenticatedContext().firestore()
    await assertFails(setDoc(doc(db, 'items/i-1'), { name: 'x' }))
  })
  it('allows an owner to read their item', async () => {
    const db = env.authenticatedContext('u1').firestore()
    await assertSucceeds(getDoc(doc(db, 'items/i-1')))
  })
})
```

Runs under `pnpm test:rules` (emulator started by `firebase emulators:exec`).

---

## Dimension Agent Prompt

Used by `SKILL.md` §M2 for each of the four `Explore` agents. Variables: `{{DIMENSION}}`, `{{INVENTORY_DIR}}`, `{{FILE_CAP}}`, `{{STACK_PROFILE}}`, `{{CHECKLIST}}`. The agent is read-only and returns text; the main thread writes the file.

```
You are the onboard {{DIMENSION}} analyst for this repository. Read-only.

BUDGET (Medium — skills/_shared/agents.reference.md §3.3):
- Max file reads: {{FILE_CAP}}
- Max web searches: 0
- Max tool calls: 25 (at 20, finish the current item and reply)
- Max output: 250 lines
- Wall-clock: 5 minutes

INPUTS (read these first; do not re-scan the tree):
- Source file list:  {{INVENTORY_DIR}}/source-files.txt
- Directory tree:    {{INVENTORY_DIR}}/dir-tree.txt
- Config copies:     {{INVENTORY_DIR}}/config-*  (package.json, tsconfig.json, workspace files)

STACK PROFILE:
{{STACK_PROFILE}}

CHECKLIST — one `### <item>` section per line, in order; write `unknown` with the
path you looked at when an item cannot be determined:
{{CHECKLIST}}

EVIDENCE: every claim names a path (and a line for greps). Count-based claims
show the command (`grep -rl … | wc -l` for files, `grep -rn … | wc -l` for hits).
If the budget runs out, emit `PARTIAL: true` and a `MISSING:` line per unvisited item.

REPLY FORMAT: markdown sections only, no top-level heading (the main thread
adds `## {{DIMENSION}}`). End with exactly two lines:
  SCORE: <1-5>/5 — <one-line reason>
  CONFIRMATION: {{DIMENSION}}: <N sections>
Output: terse-technical per output.md; fragments OK; preserve code, paths, commands, JSON verbatim.
```

---

## Dimension Checklists

### Technology
- Framework and version (`package.json` deps, `nuxt.config.*`, `vite.config.*`)
- Package manager and lockfile; workspace tool (pnpm/nx/turbo/lerna) and package list
- Build tool and output target
- Test runner and coverage tooling
- CSS approach (Tailwind, Quasar, Vuetify, scoped)
- State management (Pinia, Vuex, composables only)
- Backend/API approach (Nitro `server/`, Firebase, external API)
- TypeScript configuration (`strict`, `paths`, target)
- Dependency health: outdated count, `pnpm audit` / `npm audit` summary if a lockfile exists

### Architecture
- Directory structure, 2–3 levels, with the role of each top-level directory
- Layer separation: pages / components / stores / services / types
- Routing approach and route count
- State flow: who writes stores, who reads them
- API integration pattern (fetch wrapper, SDK, generated client)
- Shared code location and how packages import each other
- Circular dependency check (`madge` if present, else import greps on stores/services)
- Entry points (`main.ts`, `app.vue`, `server/`, `functions/`)
- Build output structure

### Quality
- TypeScript strictness (`strict`, `noImplicitAny`, `noUncheckedIndexedAccess`)
- Test-to-source ratio (test file count / source file count) and which layers have tests
- Lint config present and enforced (script, CI step, pre-commit)
- Naming consistency across components, stores, composables
- Error handling patterns (try/catch coverage, error boundaries, `role="alert"`)
- Loading / empty / error state coverage in data-display components
- Duplication hotspots (name at most three, with paths)
- Documentation: README, JSDoc on exports, ADRs, `docs/`
- Git hygiene: commit message format, branch names, `.gitignore` covers build output
- CI/CD pipeline present and what it runs

### Concerns
- Authentication / authorization (middleware, `requireAuth`, `verifyIdToken`, Firestore rules)
- Input validation (Zod, valibot, manual) at API and form boundaries
- Secrets: any hardcoded keys, `.env` committed, `.env.example` present
- CORS and security headers (`nitro` routeRules, `helmet`, hosting headers)
- Performance: lazy routes, pagination, caching, image handling
- Accessibility: semantic markup, labels, focus handling, `eslint-plugin-vuejs-accessibility`
- Internationalization readiness (`@nuxtjs/i18n`, string extraction)
- Logging and monitoring (structured logs, Sentry or equivalent)
- Environment configuration (`runtimeConfig`, per-env files, defaults)
- Dependency risk: unmaintained or duplicated packages, major-version drift

---

## Quality Scoring Rubric

| Score | Label | Meaning |
|---|---|---|
| 5 | Excellent | Best practices, documented, consistent |
| 4 | Good | Minor gaps, mostly consistent, functional |
| 3 | Adequate | Some issues, inconsistent in places, works but fragile |
| 2 | Poor | Significant issues, inconsistent, visible debt |
| 1 | Critical | Broken or missing critical patterns; blocks development |

```
Overall = Technology × 0.2 + Architecture × 0.3 + Quality × 0.3 + Concerns × 0.2
```

Architecture and Quality weigh more because they set the cost of every later `build`.

---

## Grep Patterns

| What | Pattern | Files |
|---|---|---|
| Framework | `"nuxt"`, `"vue"`, `"react"`, `"next"`, `"svelte"` | `package.json` |
| Workspace | `pnpm-workspace.yaml`, `"workspaces"`, `nx.json`, `turbo.json`, `lerna.json` | repo root |
| TypeScript strict | `"strict": true` | `tsconfig.json` |
| Test files | `*.test.*`, `*.spec.*` | tree |
| Stores | `defineStore`, `createStore` | `*.ts` |
| Composables | `export function use` | `*.ts` |
| API routes | `defineEventHandler` | `server/**/*.ts` |
| Firebase | `initializeApp`, `getFirestore`, `onCall`, `firestore.rules` | `*.ts`, root |
| Auth | `middleware/auth`, `requireAuth`, `verifyIdToken`, `request.auth` | `*.ts`, `*.rules` |
| Validation | `z.object`, `z.string`, `v.object` | `*.ts` |
| Secrets | `AKIA[0-9A-Z]{16}`, `AIza[0-9A-Za-z_-]{35}`, `-----BEGIN` | tree minus `node_modules` |
| Placeholders | `TODO`, `FIXME`, `not implemented` | new files (greenfield gate) |

---

## Example Map (abridged)

```markdown
# Codebase Map — acme-portal

Generated: 2026-09-19T14:02:11Z · blitz onboard · Overall: 3.6/5

## Technology
| Attribute | Value |
|---|---|
| Framework | Nuxt 3.x |
| Language | TypeScript 5.x (strict) |
| Package manager | pnpm |
| Test runner | Vitest |
| CSS | Tailwind |
| State | Pinia |
| Backend | Nitro `server/` + Firebase Auth |
SCORE: 4/5 — modern stack, `noUncheckedIndexedAccess` off

## Architecture
… layer table, entry points, one circular import `stores/auth.ts ↔ stores/user.ts`
SCORE: 3/5

## Quality
… 41 tests / 118 sources; `stores/` untested; lint in CI
SCORE: 3/5

## Concerns
… auth middleware present; Zod at API boundary; `.env` not committed
SCORE: 4/5

## Recommendations
1. [High] Tests for `stores/` (0 of 6 files covered) — the layer every page depends on
2. [Medium] Break `stores/auth.ts ↔ stores/user.ts` by moving `currentUser` into `composables/useSession.ts`
3. [Low] JSDoc on exported composables in `composables/`
```

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

### M2 DIMENSIONS — Four `Explore` agents, one message

Spawn all four in **a single assistant message** so they run concurrently. `Explore` is read-only and returns text ([agents.md](/_shared/agents.md) §1.2), so each agent replies with its findings and the main thread writes `${SESSION_TMP_DIR}/map-<dimension>.md`.

| Agent | Dimension | Reads | File cap |
|---|---|---|---|
| `map-technology` | stack, frameworks, dependencies, runtime, monorepo layout | configs first | 12 |
| `map-architecture` | directory layers, routing, state, API integration, boundaries, entry points | `dir-tree.txt`, entry files | 15 |
| `map-quality` | `strict`, test-to-source ratio, lint config, naming, error/loading states, docs, CI | tests, configs, CI | 10 |
| `map-concerns` | auth, validation, secrets, headers, perf, a11y, i18n, logging, env config | middleware, server, env | 10 |

For each: `Agent({ subagent_type: "Explore", model: "haiku", description: "onboard map <dimension>", prompt })`. The prompt is the dimension template in this file §Dimension Agent Prompt, with `{{DIMENSION}}`, `{{INVENTORY_DIR}}`, `{{FILE_CAP}}`, `{{STACK_PROFILE}}` (the Project Context block above), and `{{CHECKLIST}}` (the matching list in §Dimension Checklists) filled in. Medium class: 25 tool calls, ≤250 output lines, 5 minutes. The reply ends with `SCORE: n/5` and one `CONFIRMATION:` line.

Each dimension prompt carries the navigation ladder: **`LSP` first** (workspace symbol search, `goToDefinition`, `findReferences`) for any named symbol, `Grep`/`Glob` + `Read --offset` as the fallback when the tool is inactive — no server for that language, a missing binary, or a cloud session, where Claude Code does not start plugin language servers. Mapping a codebase by grepping and reading whole files is the single largest avoidable context cost in this skill.

Write each reply verbatim to its `map-*.md` as it arrives. If a reply is empty or has no `SCORE:` line, retry that dimension once with the file cap halved.

### G3 IMPLEMENT — Generate real files

Create the files from G2 in order. Every file is complete (this file §File Templates):

- **Manifests**: `package.json` with `scripts` for `dev`, `build`, `test` (`vitest run`), `type-check` (`vue-tsc --noEmit` or `tsc --noEmit`), `lint`. Install with the package manager, no version pins (`pnpm add <pkg>`, `pnpm add -D <pkg>`), then verify the resolved versions per the package policy.
- **App shell**: `app.vue`/`App.vue` with real markup; `pages/index.vue` or a router with one route; a Pinia store in setup syntax with `loading`/`error` state; one `useAsync` composable returning `{ data, loading, error, execute }`; a `types/index.ts` exporting the domain model.
- **Tests**: AAA pattern, factory functions, at least one meaningful assertion per file. Firebase projects get an emulator-backed rules test (`@firebase/rules-unit-testing`) and `firebase emulators:exec "vitest run"` as the `test:rules` script.
- **Loop directories**: `mkdir -p docs/plans docs/solutions` with a `.gitkeep` in each. These are what `plan`, `build`, `learn` read and write ([loop.md](/_shared/loop.md) §Artifacts).
- **Settings**: write `.claude/settings.json` if absent, or print the merge suggestion if present:

```json
{ "worktree": { "baseRef": "head" }, "subagentPromptCacheTtl": "1h" }
```

`worktree.baseRef: "head"` is required for `/blitz:build --parallel`; the default `fresh` branches from `origin/<default>` and drops uncommitted state.

- **Project rules**: write `CLAUDE.md` (or append to `AGENTS.md` when the repo already uses one; Claude Code reads `AGENTS.md` when `CLAUDE.md` is absent) with the stack line, the three commands (`type-check`, `test`, `lint`), and this `## Testing` block verbatim. One sentence of mocking policy in the agent config file is what drove agent-authored mock additions to near zero in the field:

```markdown
## Testing
- Never mock modules under `src/`; mock only true externals (network, clock, randomness, third-party SaaS) at the wire.
- Firestore rules and functions run against the emulator (`firebase emulators:exec`), never a mock SDK.
- A change is done when `docs/plans/<slug>/tasks.json` says so (`scripts/tasks.sh verify`), not when a test passes.
```

- **`.gitignore`**: append (do not duplicate) `.cc-sessions/`, `.claude/worktrees/`, `node_modules/`, `dist/`, `.output/`, `.nuxt/`, `coverage/`, `.env*` (keep `.env.example`).
- **README.md**: name, stack line, the three scripts, and the blitz entry points (`/blitz:plan`, `/blitz:build`, `/blitz:check`).
- **Barrel exports** (package mode): if the workspace uses `index.ts` barrels, append the new package's exports rather than creating a second barrel.
