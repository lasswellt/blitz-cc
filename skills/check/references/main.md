# Check — references

Overflow for [SKILL.md](../SKILL.md). Sections: report template, auto-fix strategies, changed-package detection, framework rule table, mutation-testing recipe. Registry ids are the contract: this file names rows, it never re-implements their grep.

---

## Report template

Plan scope writes this to `docs/plans/<slug>/check-report.md`; diff and repo scope print it. `next-state.sh` reads only the frontmatter (`result`, `ts`, `ref`) to decide row 3 vs 4, so the frontmatter is the contract and the body is for humans and `learn`.

```markdown
---
result: PASS | CONDITIONAL | FAIL
ts: 2026-09-19T14:02:11Z
ref: <git rev-parse HEAD>
scope: plan | diff | repo
plan: <slug>            # plan scope only
---

# Check — <slug | diff @ ref | repo>

**Result:** PASS | CONDITIONAL | FAIL · **Base:** <base sha> · **Files:** <n> · **LOC:** <n>

## Summary

<2–3 fragments: what the change does, what blocked or nearly blocked, what a human still owns.>

## Gates

| Gate | Before fix | After fix | Status |
|---|---|---|---|
| tsc | <n> errors | <n> errors | PASS/FAIL |
| lint | <n> errors, <n> warnings | <n> errors, <n> warnings | PASS/FAIL |
| tests (selected) | <p>/<t> passed · ratio <r> | — | calibration |
| tests (full) | <p>/<t> passed · escaped <n> | <p>/<t> passed | PASS/FAIL/SKIPPED |
| build | PASS/FAIL | PASS/FAIL | PASS/FAIL |

## Tasks (plan scope)

| Task | passes | last_verify.ok | failed | tail |
|---|---|---|---|---|
| T-001 | true | true | — | — |
| T-002 | false | false | `npx vitest run src/x.test.ts` | <≤200 chars> |

## Findings

### Critical (blocks)

| # | Where | Finding | Source | Confidence |
|---|---|---|---|---|
| 1 | src/a.ts:42 | L42: 🔴 <problem>. <fix>. | det-11 / o2-anti-mock / survey:security | 1.0 |

### Major

| # | Where | Finding | Source | Confidence |
|---|---|---|---|---|

### Minor

| # | Where | Finding | Source | Confidence |
|---|---|---|---|---|

### Info

| # | Where | Finding | Source | Confidence |
|---|---|---|---|---|

An empty bucket reads `LGTM`. `Source` is a registry id, `survey:<focus>`, `critic`, `e2e`, or `mutation`.

## Auto-fix (`--fix`)

| Category | Found | Fixed | Remaining | Skipped |
|---|---|---|---|---|
| Imports / exports | <n> | <n> | <n> | <n> |
| Type errors | <n> | <n> | <n> | <n> |
| Lint | <n> | <n> | <n> | <n> |
| Framework (F5/V3/P2) | <n> | <n> | <n> | <n> |
| Naming / return types | <n> | <n> | <n> | <n> |
| Unused | <n> | <n> | <n> | <n> |

Commits: `<sha> fix(check): …` (one line each). Manual fixes: listed under Before merge.

## Ratchet

| Metric | Baseline | Current | Threshold | Δ | Action |
|---|---|---|---|---|---|
| type_errors | 0 | 0 | 0 (absolute) | 0 | — |
| as_any_count | 7 | 5 | 5 | ↓ tightened | history appended |
| test_count | 120 | 118 | 120 | ↓ regression | T-014 blocked `ratchet:test_count` |

## Critic

`--mode reject` verdict: LGTM | REJECT · mode: in-Claude | gemini | dual · findings: <n>

## Security posture

registry-validate: ok · startup-validate --strict: ok | non-zero (<reason>) · pre-trust execution: none

## Automation coverage

Deterministic gates: <passed>/<total> (tsc, lint, tests, build, ratchet, registry rows, critic) · e2e: full | partial | skipped_unavailable
Not auto-verified (human owns): architectural fit, UX correctness, business-logic intent, regressions in untested paths.
**Recommendation:** auto-merge-safe | needs-human-review

## Before merge

1. <imperative action, file, line>

## Later

1. <imperative action>
```

Rules: tables over prose; findings as `L<line>: <prefix> <problem>. <fix>.` with 🔴 Critical / 🟡 Major / 🔵 Minor / ❓ unverified; verbatim paths, registry ids and commands; LITE intensity for Critical/Major, security details and root causes; full intensity only for Info. `progress.md` gets one line: `## <ts> check <result> check-report.md`.

---

## Auto-fix strategies

Phase 3 applies these in order (imports/exports → types → lint → framework → naming → unused). Every fix is followed by the relevant gate; a fix that makes the gate worse is reverted before the next strategy. Security findings, logic errors, architecture, test assertions and performance are never auto-fixed.

### Type errors

| Error pattern | Strategy |
|---|---|
| `Type 'X' is not assignable to type 'Y'` | fix the producer's type; a cast is the last resort and never `as any` (det-04) |
| `Property 'X' does not exist on type 'Y'` | add the property to the interface, or fix the property name |
| `Object is possibly 'undefined'` | optional chaining or a guard: `obj?.x`, `if (obj) {}` |
| `Cannot find name 'X'` | add the missing import |
| `Type 'X' is missing properties` | add the required properties or make them optional at the source |
| `Argument of type 'X' is not assignable` | match the types at the call site |
| `Cannot find module 'X'` | fix the path; install only when `package.json` already lists it |

### Lint errors

| Rule | Strategy |
|---|---|
| `no-unused-vars` | remove, or `_`-prefix when the signature is fixed |
| `no-unused-imports` / `unused-imports/*` | delete the line |
| `prefer-const` | `let` → `const` |
| `no-explicit-any` | infer the type from usage; `unknown` + guard when it cannot be inferred |
| `eqeqeq` | `==` → `===` |
| `no-console` | delete; `console.error` inside a catch stays if it rethrows |
| `quotes` / `semi` / `indent` / `max-len` | `eslint --fix` |

### Imports and exports

| Error | Strategy |
|---|---|
| Missing export | add to the barrel (`index.ts`): `export { Thing } from './thing'` |
| Wrong import path | correct to the project's alias convention |
| Circular import | extract the shared types to `types/`; never suppress |
| Default vs named | match the export style |

### Naming and return types

| Pattern | Detection | Fix |
|---|---|---|
| Component name ≠ file name | `defineComponent({ name })` / `<script setup>` file | rename to match the file |
| camelCase / PascalCase violation | identifier casing in new code | rename, update references |
| Missing return type on an exported function | `export function f(` without `):` | annotate with the inferred type |

### Gate checklist per category

| Gate | Pass | Fail |
|---|---|---|
| tsc | `tsc --noEmit` exits 0; no new `any` | any error; new `any` without `blitz:any-allowed` |
| lint | zero errors (warnings tolerated); auto-fixables resolved | any error |
| tests | full run 100 % on changed packages; new files have ≥1 test | any failure; new source file with zero tests (Minor) |
| build | exits 0; no error markers | build error |

---

## Changed package detection

```bash
CHANGED_FILES=$(cat "${SESSION_TMP_DIR}/check-changed.txt")
if   [ -f pnpm-workspace.yaml ]; then PKGS=$(yq -r '.packages[]' pnpm-workspace.yaml 2>/dev/null || grep -E '^\s*-' pnpm-workspace.yaml | sed 's/^\s*-\s*//;s/"//g')
elif jq -e '.workspaces' package.json >/dev/null 2>&1; then PKGS=$(jq -r '.workspaces[]? // .workspaces.packages[]?' package.json)
else PKGS=""; fi
CHANGED_PACKAGES=$(for f in $CHANGED_FILES; do for g in $PKGS; do for d in $g; do [ -d "$d" ] && case "$f" in "$d"/*) echo "$d";; esac; done; done; done | sort -u)
[ -n "$CHANGED_PACKAGES" ] || CHANGED_PACKAGES=.
```

| Config | Method | Scoped test command |
|---|---|---|
| `pnpm-workspace.yaml` | expand `packages:` globs | `pnpm --filter "...[$BASE]" run test` |
| `package.json` `workspaces` | expand the array | per package `npm test -w <pkg>` |
| `nx.json` | `nx affected --plain` | `nx affected --target=test --base=$BASE` |
| `turbo.json` | `turbo` filter | `turbo run test --filter="...[$BASE]"` |
| `lerna.json` | `lerna changed --json` | `lerna run test --since $BASE` |
| none | single package | run everything at root |

Gates (tsc, lint, build) run per changed package; the selected test set comes from `scripts/test-selector.sh` regardless of package, and the one full run is package-scoped in a monorepo. `escaped_failures > 0` in any of the last three runs forces the selector to `--full` until the streak clears ([tia.md](/docs/guides/tia.md)).

---

## Framework rules (`fw-firestore-vue-pinia`, `--only framework`)

Rule sets load only when the stack banner detects the dependency (`grep -E '"firebase"|"firestore"|"vuefire"|"vue"|"pinia"' package.json`). `auto_fix: true` rows are the only ones `--fix` touches. Every finding goes through the Phase 2 FP-verify step before it is reported; critical rows (F2, F7, V1) get a read of the whole file first. Inline suppression: `// code-doctor-ignore: <ruleId>` on the same line.

### Firestore

| id | severity | auto_fix | signal | false-positive note |
|---|---|---|---|---|
| F1 | major | no | `await getDocs` inside a `for` loop | skip when the loop body batches itself |
| F2 | critical | no | `onSnapshot(` in a `.vue` file with no `onUnmounted` | cleanup may live in a composable called from the file; read before flagging |
| F3 | major | no | `serverTimestamp()` written and read from the same snapshot | only same-transaction reads |
| F5 | major | **yes** | `.docs.map(d => d.data())` drops `id` | none known |
| F6 | major | no | `getDocs(collection(` without `query(`/`.limit(` | allowed when wrapped in `query(collection(…), limit(…))` |
| F7 | critical | no | `tx.set/update/delete` before `tx.get` inside `runTransaction` | rare; confirm by reading |
| F8 | minor | no | `updateDoc(` without an existence check or `setDoc … merge: true` | high FP rate; advisory only |
| F9 | major | no | the same `doc(db, '<col>'` path under `onSnapshot` in >2 components | cross-file; manual review |
| F10 | minor | no | `import … firestore.rules` from `src/` | rules file imported at runtime |

### VueFire

| id | severity | auto_fix | signal | false-positive note |
|---|---|---|---|---|
| V1 | critical | no | `useDocument/useCollection/useObject(` outside `<script setup>` or `setup()` | composable-to-composable calls are fine |
| V2 | major | no | `useDocument/useCollection` result accessed without `.value` in script | templates auto-unwrap; script side only |
| V3 | minor | **yes** | `useFirestore()` called 2+ times in one file | none; hoist to one top-level const |
| V4 | major | no | `useCollection(collection(` without `query(` | unbounded reactive collection |
| V5 | major | no | `useDocument` with a dynamic id outside `computed()` | static ids are fine |

### Vue 3

| id | severity | auto_fix | signal | false-positive note |
|---|---|---|---|---|
| G1 | major | no | `v-if` and `v-for` on the same element | same opening tag only |
| G2 | minor | no | `:key="index"` on `v-for` | static, non-reordering lists are fine |
| G3 | minor | no | `ref({` object later mutated through `.value.x =` | prefer `reactive()` |
| G4 | minor | no | `this.$store` / `this.$router` inside `<script setup>` | Options-API leftover |
| G5 | minor | no | inline `:style` with `px` string interpolation | move to a computed |

### Pinia

| id | severity | auto_fix | signal | false-positive note |
|---|---|---|---|---|
| P1 | major | no | `store.x =` outside a `defineStore` action | high FP; confirm it is state, not a local |
| P2 | minor | **yes** | `watch(() => xStore.y` without `storeToRefs` in the file | fix: `const { y } = storeToRefs(xStore); watch(y, …)` |
| P3 | minor | no | `useStore()` inside a non-setup function | handlers and lifecycle hooks defined outside setup |
| P4 | minor | no | store state declared with `ref()` at the top of `defineStore` | low impact; advisory |

### Dead exports and duplication

| id | severity | auto_fix | signal | false-positive note |
|---|---|---|---|---|
| D1 | minor | no | `export (const\|function\|class\|type\|interface) X` with zero imports of `X` across the repo | exclude `export * from`, `public/`, `@public` jsdoc |
| DUP1 | minor | no | identical normalized 5-line window in 2+ source files | trim whitespace, strip comments; cap 20 findings |

### Auto-fix recipes

**F5** — pattern `\.docs\.map\s*\(\s*(\w+)\s*=>\s*\1\.data\(\)\s*\)` → `.docs.map(($1) => ({ id: $1.id, ...$1.data() }))`.

**V3** — keep the first `const db = useFirestore()`, delete the others, rewrite downstream references to the surviving variable name.

**P2** — before: `const store = useMyStore(); watch(() => store.someValue, cb)`; after: `const store = useMyStore(); const { someValue } = storeToRefs(store); watch(someValue, cb)`; add `storeToRefs` to the `pinia` import.

After each recipe re-grep the fixed rule id in the file; a remaining hit is logged `fix_partial` and handed to the human.

---

## Mutation testing (`--mutation`)

Off by default: a mutation run costs minutes, not seconds, and its output is advisory (P3). Turn it on for a plan that touches core logic with a thin test suite, or before a release.

Dependency of the target project, never the plugin: `npm i -D @stryker-mutator/core @stryker-mutator/vitest-runner` (jest projects: `@stryker-mutator/jest-runner`, `testRunner: "jest"`).

```bash
mkdir -p .stryker-tmp && grep -q '^\.stryker-tmp' .gitignore 2>/dev/null || echo '.stryker-tmp/' >> .gitignore
MUTATE=$(grep -E '^src/.*\.(ts|tsx|vue)$' "${SESSION_TMP_DIR}/check-changed.txt" | grep -vE '\.(test|spec)\.' | jq -R . | jq -sc .)
jq -n --argjson mutate "$MUTATE" '{
  "$schema": "./node_modules/@stryker-mutator/core/schema/stryker-schema.json",
  testRunner: "vitest", coverageAnalysis: "perTest", incremental: true,
  incrementalFile: ".stryker-tmp/incremental.json", mutate: $mutate,
  reporters: ["json", "clear-text"], jsonReporter: {fileName: ".stryker-tmp/report.json"},
  thresholds: {high: 80, low: 60, break: null}, timeoutMS: 60000, concurrency: 2 }' > .stryker-tmp/stryker.conf.json
npx stryker run .stryker-tmp/stryker.conf.json 2>&1 | tail -20
jq -r '.files | to_entries[] | .key as $f | .value.mutants[] | select(.status=="Survived") | "\($f):\(.location.start.line) \(.mutatorName): \(.replacement // "")"' \
  .stryker-tmp/report.json > "${SESSION_TMP_DIR}/check-mutants.txt"
```

| Field | Why |
|---|---|
| `coverageAnalysis: "perTest"` | runs only the tests that cover each mutant; the difference between minutes and hours |
| `incremental: true` + `incrementalFile` | reuses results for unchanged mutants across runs; the file lives in `.stryker-tmp/` (gitignored) |
| `mutate: $CHANGED` | only files in scope; a repo-wide run is `audit`'s territory |
| `thresholds.break: null` | mutation score never fails `check`; survivors are findings, not a gate |

Each surviving mutant becomes one P3 finding: `L<line>: 🔵 survived <mutator> (<replacement>). Add an assertion that distinguishes it.` A mutant surviving in a file whose task has a test-only `verify[]` is the SpecBench signal in miniature: recommend a non-test check for that task under Before merge. Never let a mutation run change `tasks.json`; findings that deserve work go through `tasks.sh add … --origin check`.
