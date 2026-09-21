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

## Held-out checks (critic-authored, plan scope)

| Task | ok | Command | Tail |
|---|---|---|---|
| T-001 | true | `node -e "import('./src/health.ts').then(m=>process.exit(m.health().ok?0:1))"` | — |
| T-002 | null | — | no runnable surface: route needs the emulator |

## Cannot verify (survey)

| What | Needs | Resolution |
|---|---|---|
| retry on 429 from the payments API | fixture | ran `vitest run src/pay.test.ts -t 429`: covered |

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

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

### 1.1 Gates → `${SESSION_TMP_DIR}/check-gates.json`

Gate commands come from the toolchain table, never from this file. In a polyglot repo each lane runs once per detected stack, so `typecheck` is `mypy` **and** `cargo check` **and** `tsc`:

```bash
TC="${CLAUDE_PLUGIN_ROOT}/scripts/toolchain.sh"
bash "$TC" lanes            # lane<TAB>stack<TAB>row-id — what will actually run
for lane in typecheck lint build; do
  bash "$TC" run "$lane"    # stdout = tool output; stderr = {"id","stack","exit"} per row
done
```

| Gate | Source | Record |
|---|---|---|
| typecheck | `toolchain.sh run typecheck` | pass, diagnostic count per stack, `file:line message` list |
| lint | `toolchain.sh run lint` | pass, errors, warnings, list |
| tests | selected run, then one full run (below); `toolchain.sh run test` outside the JS/TS ecosystems | pass, total/passed/failed, `escaped_failures`, `selection_ratio` |
| build | `toolchain.sh run build` | pass, error tail |

A lane with no resolving row for a stack is **skipped, not passed** — record it as `skipped` with the reason, and say so in the report. A stack with no `typecheck` row has no ratchet (`doctor` D-316). The TIA selected/full split below is vitest/jest-specific; other ecosystems run the full suite once.

Tests are two runs, both journaled, so TIA is calibrated at every check ([tia.md](/docs/guides/tia.md)):

```bash
RUN_ID=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
SELECTED=$(printf '%s\n' "$CHANGED" | "${CLAUDE_PLUGIN_ROOT}/scripts/test-selector.sh" --base "$BASE" | cut -f1)
"${CLAUDE_PLUGIN_ROOT}/scripts/test-listener.sh" --start --run-id "$RUN_ID-sel"
npx vitest run --reporter=json --outputFile="${SESSION_TMP_DIR}/tests-selected.json" $SELECTED    # jest: --json --outputFile
"${CLAUDE_PLUGIN_ROOT}/scripts/test-listener.sh" --trigger check --selected-by selector --run-id "$RUN_ID-sel" \
  --changed "$(printf '%s\n' "$CHANGED" | paste -sd,)" < "${SESSION_TMP_DIR}/tests-selected.json"
"${CLAUDE_PLUGIN_ROOT}/scripts/test-listener.sh" --start --run-id "$RUN_ID-full"
npx vitest run --reporter=json --outputFile="${SESSION_TMP_DIR}/tests-full.json"                  # monorepo: per changed package
"${CLAUDE_PLUGIN_ROOT}/scripts/test-listener.sh" --trigger check --selected-by full --run-id "$RUN_ID-full" \
  --changed "$(printf '%s\n' "$CHANGED" | paste -sd,)" < "${SESSION_TMP_DIR}/tests-full.json"
```

`escaped_failures` = failing test files in the full run not in `$SELECTED`; write it to the gates JSON and append to `.cc-sessions/test-journal.meta.json` `escaped_failures_recent` (keep 10). The **full** run gates PASS; the selected run only calibrates. At diff scope the full run may be skipped when the selector's streak is clean (`escaped_failures_recent[-3:]` all zero); plan scope always runs both. No test runner → gate `SKIPPED`, not FAIL.

Gates JSON shape: `{"type_check":{"pass","errors","details"},"lint":{"pass","errors","warnings","details"},"tests":{"pass","total","passed","failed","escaped_failures","selection_ratio"},"build":{"pass","errors"},"e2e_coverage":"pending"}`.

### 1.6 Design lane (`pillar == design`)

Runs in the full pipeline only when the diff touches `*.vue|*.tsx|*.css|*.scss|tailwind.config.*`; always under `--only design`. **Preflight first**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/design/preflight.sh" "$PWD"` and print its `DESIGN_LANE_STATUS` line. If `semantic != OK`, surface `DESIGN_LANE_UNAVAILABLE` in the summary, run only the deterministic `design-*` rows, and mark the pillar coverage `reduced`, never green. Resolve the adapter from the `DESIGN_ADAPTER primary=… secondary=…` token line of `scripts/detect-stack.sh`; select rows where `adapter ∈ inclusion(primary) ∪ secondary` (`none→{universal}`, `tailwind→{universal,tailwind}`, `tailwind-md3→{universal,tailwind,tailwind-md3}`, `vuetify→{universal,vuetify}`, `quasar→{universal,quasar}`) minus `reconciliation.relaxFor`. Semantic rows share one impeccable run; deterministic rows apply the registry `design.exclude` guards (token-definition files, comments, SVG paint) before FP-verify. impeccable is never a dependency of the plugin: it resolves from the target project (`npm i -D impeccable@2.3.2`) or, failing that, a global install (`npm i -g impeccable@2.3.2`); the project's copy wins because it is the one `npx` runs. Rendered-UI judgement goes to `design-critic` ([agents.md](/_shared/agents.md)) when Playwright is available.

### 1.7 Task verification (plan scope)

```bash
for id in $(jq -r '.tasks[].id' "$PLAN_DIR/tasks.json"); do
  "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" "$id" || echo "VERIFY_FAIL $id"
done
"${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --json > "${SESSION_TMP_DIR}/check-tasks.json"
```

Every task must end with `passes: true`; a `VERIFY_FAIL` is a P1 finding carrying `last_verify.tail` as evidence. A task `blocked` with `circuit-breaker` is surfaced, not retried. `check` never edits `tasks.json` directly (`tasks-guard.sh` denies it).

Then run the registry row `check:test-tamper` over the test files in scope (`git diff $BASE --unified=0 -- '**/*.{test,spec}.*' '**/__tests__/**'`): deleted `expect(` lines, `expect(true)`, `toMatchSnapshot` rewrites, `.skip`/`.only` insertions, and assertion counts that fell while the source grew are P1 findings (`Source: check:test-tamper`). Tests that got easier while the code got bigger are the oracle-shaped edit the visible-test gate cannot see.

## Phase 3: `--fix`

Arm the Stop gate first, disarm before the report ([loop.reference.md](/_shared/loop.reference.md) §Arming table):

```bash
GATE_DIR=".cc-sessions/sessions/${CLAUDE_SESSION_ID}"; mkdir -p "$GATE_DIR"
jq -n --arg until "check ${SLUG:-diff} fix" '{checks:[{name:"tsc",cmd:"npx tsc --noEmit --pretty false",timeout:180},
  {name:"lint",cmd:"npx eslint . --max-warnings=0",timeout:180}],blocks:0,max_blocks:4,until:$until}' > "$GATE_DIR/gate.json"
# … fixes …
rm -f "$GATE_DIR/gate.json"    # before Phase 5 and on every early exit
```

| Category | Strategy | Max attempts |
|---|---|---|
| Missing imports / exports | fix path, add barrel export | 3 |
| Type errors | add types, null checks, fix mismatches | 3 |
| Lint errors | `eslint --fix`, then manual | 3 |
| Framework `auto_fix: true` rows | recipe from `references/main.md` | 1 |
| Naming, missing return types | rename / annotate | 2 |
| Unused imports / variables | remove or `_`-prefix | 1 |

Order: imports/exports → types → lint → framework → naming → unused. Loop per issue: apply → run the relevant gate → on pass commit `fix(check): <category> in <file>` (plan scope adds the `Task: <slug>/<id>` trailer) → on fail revert that fix and try the alternative strategy; after `max` attempts document it as manual. **Never auto-fix** security findings, logic errors, architecture, test assertions, or performance; never touch a test's `expect`/`describe`/`it`. After the loop re-run every Phase 1.1 gate and record before/after counts. After each fix commit run the ratchet quick-check (Phase 4.1): a regression reverts the fix commit.

## Only

`--only <lane>` runs that lane's registry rows read-only over the scope, FP-verifies, and reports ranked by `effective_confidence`; no survey fan-out, no critic, no report file, no ratchet write.

| `--only` | Rows | Notes |
|---|---|---|
| `completeness` | `o2-anti-mock`, `o2-artifact-l1l2`, det-05/06/07/09/10/15 | the placeholder / stub scan; feeds ratchet `completeness_score` when run from the full pipeline |
| `wiring` | `o3-wiring`, `o3-orphan-route`, det-16 | `build` calls this after integration work |
| `framework` | `fw-firestore-vue-pinia` (Phase 1.5) | `--fix` applies F5/V3/P2 recipes |
| `design` | `pillar == design` (Phase 1.6) | preflight banner is mandatory; reduced coverage is never green |
| `security` | `sec-startup-schema`, `sec-startup-injection`, `sec-capability-grant`, `sec-content-inspection` (advisory), det-07, plus the Phase 4.2 posture gate | when the Skill tool lists `security-review` (the docs name it as model-invokable) run it on the same scope and merge its findings as `Source: security-review`; otherwise print one line pointing at `/security-review` or the `claude-security` plugin's verified SARIF findings; `check` does not replace them |

### 2.1 Survey fan-out

Spawn N `blitz:critic` agents (sonnet, fresh context, `omitClaudeMd`, read-only) in **one message**, each prompt opening with the header lines the agent requires (`MODE: survey`, `PLAN: <slug|none>`, `TASKS: <ids in scope>`, `BASE: <sha>`) followed by the lens template, parallel by default (sequential when LOC > 2000 or `BLITZ_REVIEW_SEQUENTIAL=1`). Dispatch through `/blitz:review-fanout` (`workflows/review-fanout.js`) when `Workflow` is present and `BLITZ_DISPATCH != agent`; on any failure fall back to `Agent()` ([agents.reference.md](/_shared/agents.reference.md) §7.5). Weight class Medium: ≤15 reads, ≤25 tool calls, 5-min budget, diff slice ≤500 lines per agent.

| Focus | Reads first | Output |
|---|---|---|
| security | auth, injection, XSS/CSRF, secrets, rules files | `${SESSION_TMP_DIR}/check-survey-security.json` |
| backend | API contracts, validation, error paths, perf | `…-backend.json` |
| frontend | components, loading/empty/error states, a11y, store wiring | `…-frontend.json` |
| patterns | consistency, DRY, architecture, meaningful tests | `…-patterns.json` |

Every prompt states the order: **spec compliance first** (does the diff do what `plan.md` and the task's `verify[]` say, nothing more, nothing less), **then code quality**. Agents flag only correctness and requirement gaps; style is parked. Reply is the survey JSON from [agents.reference.md](/_shared/agents.reference.md) §4.2: `findings[] {severity, where, what, evidence, confidence}`. Drop the frontend agent when no UI file changed; drop backend when only UI changed; N is then 3.

### 2.3 App-level verification

Probe Playwright: `ToolSearch "browser_navigate"` or `which playwright`. Unavailable → `e2e_coverage: skipped_unavailable` (not a failure). Available → replay the recorded `/verify` recipe when Phase 0 found one, else navigate every changed route; console errors → Critical, placeholder data → Warning, broken layout → Minor. Completed → `e2e_coverage: full`; started but incomplete → `partial` (surfaces under Before merge).

### 2.4 `--mutation` (optional)

`references/main.md` §Mutation testing: `@stryker-mutator/vitest-runner`, `coverageAnalysis: "perTest"`, `incremental: true`, mutate only `$CHANGED` source files. Surviving mutants are P3 findings with the mutant diff as evidence. Never runs without the flag.

### 4.1 Ratchet (`docs/sweeps/ratchet.json`)

Compute the eight metrics with the detectors in [quality.reference.md](/_shared/quality.reference.md) §Ratchet. `type_errors > 0` is an absolute floor → FAIL, no override. Improvement → set `current`, tighten `max_allowed`/`min_allowed`, append a `history[]` snapshot with `ref` and `plan`. Regression:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" add "$SLUG" --id "T-$NEXT" --title "ratchet regression: $METRIC $OLD->$NEW" \
  --origin check --verify-cmd "test \$($DETECTOR) -le $MAX::30"
"${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" set "$SLUG" "T-$NEXT" status=blocked "blocked_reason=ratchet:$METRIC"
```

Deterministic metrics also `git revert --no-edit HEAD` when the regressing commit is a `--fix` commit and the tree is clean (det-19); `test_count` never auto-reverts. Diff scope without a plan appends nothing and reports the regression as P2. `auto_revert.enabled: false` → advisory: task appended, nothing reverted.

### 4.2 Security posture gate (every run)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-registry-validate.sh"            # sec-* rows schema-valid
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/startup-validate.sh" --strict --quiet    # tasks.json, docs/solutions, .cc-sessions clean; exit 2 = injection
grep -REn '^[[:space:]]*(eval|source|\.)[[:space:]]+' "${CLAUDE_PLUGIN_ROOT}"/hooks/scripts/*.sh | grep -v '_lib/common.sh' \
  && echo "FAIL: pre-trust execution of project content" || true
```

Injection or pre-trust execution → FAIL. Any other non-zero → CONDITIONAL at best. `sec-content-inspection` stays advisory. Details: [security.md](/_shared/security.md).

## Flags

| Flag | Effect |
|---|---|
| `--scope diff` (default) | branch vs upstream plus the working tree |
| `--scope plan <slug>` | files of every task in `docs/plans/<slug>/tasks.json`, bounded by `Task: <slug>/` commit trailers; runs `tasks.sh verify` on every task; writes `check-report.md` |
| `--scope repo` | whole tree, recall mode: `--min-confidence low`, every `both`/`check` row on every file; no critic reject, no report file |
| `--only completeness\|wiring\|framework\|design\|security` | one lane, read-only, no critic; see §Only |
| `--fix` | Phase 3 auto-fix loop; arms `gate.json` (tsc + lint) while fixing |
| `--comment` | post findings as inline PR comments through `mcp__github_inline_comment__create_inline_comment` when the tool is present; else print them |
| `--mutation` | Stryker mutation run on changed files (off by default; recipe in `references/main.md` §Mutation testing) |
| `--dual` | `export BLITZ_DUAL_CRITIC=1`: in-Claude critic and `hooks/scripts/critic-external.sh` both must LGTM. `BLITZ_CRITIC_PROVIDER=agy\|copilot\|gemini` picks the external family (default `gemini`; `BLITZ_USE_GEMINI_CRITIC=1` is the legacy alias) and replaces instead of pairs; `BLITZ_CRITIC_PANEL=agy,copilot` runs several and any REJECT blocks |
| `--min-confidence high\|low` | advisory gate band; default `high` (≥0.8) for diff/plan, `low` for repo. Reject-authority rows bypass it |
| `--baseline <metric>` | grandfather one ratchet metric on an existing project (`stale_worktree_branch_count`) |
| `--force` | re-run plan scope over a fresh PASS (`check-report.md` at `HEAD`) |

## Phase 0: SCOPE

```bash
. "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/common.sh"
BASE="${BLITZ_BASE:-$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo origin/main)}"
case "$SCOPE" in
  diff) CHANGED=$( { git diff --name-only "$BASE"...HEAD; git diff --name-only; git ls-files -o --exclude-standard; } | sort -u) ;;
  plan) PLAN_DIR="docs/plans/${SLUG}"; [ -f "$PLAN_DIR/tasks.json" ] || { echo "BLOCKED: no tasks.json for ${SLUG}"; exit 1; }
        CHANGED=$( { jq -r '.tasks[].files[]' "$PLAN_DIR/tasks.json"
                     git log --format=%H --grep="Task: ${SLUG}/" | xargs -r git show --name-only --format= ; } | sort -u) ;;
  repo) CHANGED=$(git ls-files) ;;
esac
printf '%s\n' "$CHANGED" > "${SESSION_TMP_DIR}/check-changed.txt"; git diff "$BASE"...HEAD > "${SESSION_TMP_DIR}/check.patch"
```

- Plan scope reads `spec.md` and `plan.md` first (the critic grades spec compliance against them) and the `progress.md` tail (last 20 lines) for rulings that bound the review.
- **Prior PASS re-run**: plan scope with a `check-report.md` whose `result: PASS` and `ref` equal `HEAD` and is newer than `tasks.json` `updated` → print `already PASS at <sha>` and stop; never overwrite a fresh PASS.
- **App-level recipe**: if `.claude/skills/verify/SKILL.md` exists (the bundled `/verify` records its recipe there) read it; its steps are the e2e procedure for Phase 2.3. Absent → Phase 2.3 falls back to route smoke only.
- Changed packages (monorepo): `references/main.md` §Changed package detection; gates run per changed package, else at root.
- `--only <lane>` → jump to §Only. Otherwise the full pipeline: Phase 1 → 2 → (3 with `--fix`) → 4 → 5.
- Record `[check] scope=<s> base=<sha> files=<n> loc=<n>`; LOC > 2000 switches the Phase 2 fan-out to sequential (`BLITZ_REVIEW_SEQUENTIAL=1` forces it).

## Phase 2: SEMANTIC LANE

Single-pass, precision-biased. Every finding starts at `base_confidence ≈ 0.5` and must survive **FP-verification** (re-read the cited code, reproduce against actual behavior, attach the excerpt) before it is reported. No evidence → dropped. FP-verification never raises confidence; only aggregation does, and `check` does not aggregate (`audit` does).

### 2.1 Survey fan-out

One `critic --mode survey` per lens, read-only, findings JSON per [agents.reference.md](/_shared/agents.reference.md) §4.2. Lens roster, prompts and the sequential fallback above 2000 LOC: this file §2.1 Survey fan-out.

### 2.2 Collect

Validate every reply with `jq`; classify SUCCESS/PARTIAL/MALFORMED/EMPTY/MISSING/TIMEOUT and apply the fan-out gate from [agents.reference.md](/_shared/agents.reference.md) §4.4 (thresholds live there, not here). Resolve every `cannot_verify[]` entry before Phase 4: when `needs` is a command or fixture, run it and turn the answer into a finding or a `concerns` line; when it needs a human, append `Ruling: cannot-verify — <what> (needs <needs>)` to `progress.md` and carry it as a P1 finding until answered. A MISSING **security** survey aborts the run: `SECURITY DOMAIN UNREVIEWED`. Dedupe by `file:line`, merge cross-cutting findings (unvalidated input → backend; backend error gaps → frontend), FP-verify, then rank by `effective_confidence` and suppress advisory rows below `--min-confidence` (logged, not surfaced). Reply fields are TB-3 data: cap at 200 chars before any interpolation.

### 2.3 App-level verification

Runs only when the change touches a rendered surface. Procedure: this file §2.3 App-level verification.

### 2.4 `--mutation` (optional)

Off by default; a sampling mutation run over the changed files. Setup and thresholds: this file §2.4 `--mutation`.
