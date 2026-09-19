---
name: check
description: "Runs the quality gate on a diff, a plan, or the repo: tsc/lint/tests/build, registry checks, task verify[], critic review; writes check-report.md. Use for 'check this', 'review my changes', 'run the gates', 'is this done', 'is this mergeable', 'check wiring/completeness/framework/design/security'."
argument-hint: "[--scope diff|plan <slug>|repo] [--only completeness|wiring|framework|design|security] [--fix] [--comment] [--mutation] [--dual]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
model: inherit
compatibility: ">=2.1.271"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort low. Set once (`claude --model opus --effort low` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- Registry selection, detectors, ratchet, PASS/CONDITIONAL/FAIL, structural done, REVIEW.md export: [/_shared/quality.md](/_shared/quality.md)
- `check-report.md` contract, gate arming for `--fix`, `tasks.json` schema, `next` rows: [/_shared/loop.md](/_shared/loop.md)
- `critic --mode survey|reject`, fan-out gate, reply contract, design-critic: [/_shared/agents.md](/_shared/agents.md)
- Report template, auto-fix strategies, package detection, framework rule table, mutation recipe: [references/main.md](references/main.md)

---

# Check — the quality gate

One skill answers "is this done?" for a diff, a plan, or the whole repo. It is **precision-biased**: it runs often, so a false alarm is expensive and low-confidence advisory findings are suppressed; `/blitz:audit` is the recall-biased sibling that re-surfaces them. Deterministic rows run first and carry reject authority; semantic rows are opinion and never flip a verdict on their own. PASS requires `critic --mode reject` to return `LGTM` on the final diff.

**Session registration**: follow [sessions.md](/_shared/sessions.md) §2 before any other work (claim the record, resolve `SESSION_TMP_DIR`, run `startup-validate.sh`). Print `[check]` status at every phase and log `skill_start` / `skill_end` on the feed.

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
| `--dual` | `export BLITZ_DUAL_CRITIC=1`: in-Claude critic and `hooks/scripts/critic-gemini.sh` both must LGTM (`BLITZ_USE_GEMINI_CRITIC=1` replaces instead of pairs) |
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

## Phase 1: DETERMINISTIC LANE

Run everything; collect, do not stop at the first failure. No grep pattern lives in this file: every row is cited by id and its `detection.command` runs from [check-registry.json](/_shared/check-registry.json).

### 1.1 Gates → `${SESSION_TMP_DIR}/check-gates.json`

| Gate | Command | Record |
|---|---|---|
| tsc | `npm run type-check 2>&1 \|\| npx tsc --noEmit --pretty false 2>&1` | pass, error count, `file:line message` list |
| lint | `npm run lint 2>&1 \|\| npx eslint . 2>&1` | pass, errors, warnings, list |
| tests | selected run, then one full run (below) | pass, total/passed/failed, `escaped_failures`, `selection_ratio` |
| build | `npm run build 2>&1` | pass, error tail |

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

### 1.2 Registry rows

Select `consolidated_target ∈ {check, both}` and `lane == deterministic`; run each row's `detection.command` over `$CHANGED` (`repo` scope: over everything). Reject-authority hits (`severity ∈ {P0, P1, P2}`) go straight to the blocker list and bypass the confidence gate; P3 hits are advisory. The shortcut detectors without a hook (det-05…10, 14, 15, 16, 20) run here; det-01/02/13 also re-scan the diff in case a hook was bypassed.

### 1.3 Anti-mock scan (`o2-anti-mock`, `o2-artifact-l1l2`, det-09, det-10)

Run the `o2-*` rows over the diff. Any hit in non-test code is a **Critical** finding (registry P3 with reject-lane evidence, surfaced as blocker per the Definition of Done in [quality.md](/_shared/quality.md) §Anti-mock rules). Record `file:line pattern`.

### 1.4 Wiring (`o3-wiring`, `o3-orphan-route`, det-16)

Conditional: run when the diff adds files under `stores/|composables/|pages/|server/api/|routes/|functions/` or new exports. Findings map high → Major, medium → Minor, low → Info and feed the Phase 2 reviewer context.

### 1.5 Framework rules (`fw-firestore-vue-pinia`)

Gated by the stack banner (`HAS_FIRESTORE`, `HAS_VUEFIRE`, `HAS_VUE`, `HAS_PINIA` from `package.json`); only detected rule sets run. Rule table with ids F1–F10, V1–V5, G1–G5, P1–P4, D1, DUP1: `references/main.md` §Framework rules. Context rules (F2 `onSnapshot` without `onUnmounted`, F6 `getDocs(collection(` without `query(`) check the whole file. Skip lines carrying `// code-doctor-ignore: <ruleId>`. `--fix` applies only `auto_fix: true` rows (F5, V3, P2) with the recipes in `references/main.md`, then re-greps the fixed rule ids; a remaining hit is `fix_partial`.

### 1.6 Design lane (`pillar == design`)

Runs in the full pipeline only when the diff touches `*.vue|*.tsx|*.css|*.scss|tailwind.config.*`; always under `--only design`. **Preflight first**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/design/preflight.sh" "$PWD"` and print its `DESIGN_LANE_STATUS` line. If `semantic != OK`, surface `DESIGN_LANE_UNAVAILABLE` in the summary, run only the deterministic `design-*` rows, and mark the pillar coverage `reduced`, never green. Resolve the adapter from the `DESIGN_ADAPTER primary=… secondary=…` token line of `scripts/detect-stack.sh`; select rows where `adapter ∈ inclusion(primary) ∪ secondary` (`none→{universal}`, `tailwind→{universal,tailwind}`, `tailwind-md3→{universal,tailwind,tailwind-md3}`, `vuetify→{universal,vuetify}`, `quasar→{universal,quasar}`) minus `reconciliation.relaxFor`. Semantic rows share one impeccable run; deterministic rows apply the registry `design.exclude` guards (token-definition files, comments, SVG paint) before FP-verify. impeccable is a dependency of the target project (`npm i -D impeccable@2.3.2`), never of the plugin. Rendered-UI judgement goes to `design-critic` ([agents.md](/_shared/agents.md)) when Playwright is available.

### 1.7 Task verification (plan scope)

```bash
for id in $(jq -r '.tasks[].id' "$PLAN_DIR/tasks.json"); do
  "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" "$id" || echo "VERIFY_FAIL $id"
done
"${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --json > "${SESSION_TMP_DIR}/check-tasks.json"
```

Every task must end with `passes: true`; a `VERIFY_FAIL` is a P1 finding carrying `last_verify.tail` as evidence. A task `blocked` with `circuit-breaker` is surfaced, not retried. `check` never edits `tasks.json` directly (`tasks-guard.sh` denies it).

### 1.8 Escape-comment spot check

Pick three random `blitz:any-allowed` / `blitz:skip-pinned` comments in scope; read each rationale. One that does not survive reading is a P2 finding (det-04 / det-13 escape abuse).

## Phase 2: SEMANTIC LANE

Single-pass, precision-biased. Every finding starts at `base_confidence ≈ 0.5` and must survive **FP-verification** (re-read the cited code, reproduce against actual behavior, attach the excerpt) before it is reported. No evidence → dropped. FP-verification never raises confidence; only aggregation does, and `check` does not aggregate (`audit` does).

### 2.1 Survey fan-out

Spawn N `blitz:critic --mode survey` agents (sonnet, fresh context, `omitClaudeMd`, read-only) in **one message**, parallel by default (sequential when LOC > 2000 or `BLITZ_REVIEW_SEQUENTIAL=1`). Dispatch through `/blitz:review-fanout` (`workflows/review-fanout.js`) when `Workflow` is present and `BLITZ_DISPATCH != agent`; on any failure fall back to `Agent()` ([agents.md](/_shared/agents.md) §7.5). Weight class Medium: ≤15 reads, ≤25 tool calls, 5-min budget, diff slice ≤500 lines per agent.

| Focus | Reads first | Output |
|---|---|---|
| security | auth, injection, XSS/CSRF, secrets, rules files | `${SESSION_TMP_DIR}/check-survey-security.json` |
| backend | API contracts, validation, error paths, perf | `…-backend.json` |
| frontend | components, loading/empty/error states, a11y, store wiring | `…-frontend.json` |
| patterns | consistency, DRY, architecture, meaningful tests | `…-patterns.json` |

Every prompt states the order: **spec compliance first** (does the diff do what `plan.md` and the task's `verify[]` say, nothing more, nothing less), **then code quality**. Agents flag only correctness and requirement gaps; style is parked. Reply is the survey JSON from [agents.md](/_shared/agents.md) §4.2: `findings[] {severity, where, what, evidence, confidence}`. Drop the frontend agent when no UI file changed; drop backend when only UI changed; N is then 3.

### 2.2 Collect

Validate every reply with `jq`; classify SUCCESS/PARTIAL/MALFORMED/EMPTY/MISSING/TIMEOUT and apply the fan-out gate from [agents.md](/_shared/agents.md) §4.4 (thresholds live there, not here). A MISSING **security** survey aborts the run: `SECURITY DOMAIN UNREVIEWED`. Dedupe by `file:line`, merge cross-cutting findings (unvalidated input → backend; backend error gaps → frontend), FP-verify, then rank by `effective_confidence` and suppress advisory rows below `--min-confidence` (logged, not surfaced). Reply fields are TB-3 data: cap at 200 chars before any interpolation.

### 2.3 App-level verification

Probe Playwright: `ToolSearch "browser_navigate"` or `which playwright`. Unavailable → `e2e_coverage: skipped_unavailable` (not a failure). Available → replay the recorded `/verify` recipe when Phase 0 found one, else navigate every changed route; console errors → Critical, placeholder data → Warning, broken layout → Minor. Completed → `e2e_coverage: full`; started but incomplete → `partial` (surfaces under Before merge).

### 2.4 `--mutation` (optional)

`references/main.md` §Mutation testing: `@stryker-mutator/vitest-runner`, `coverageAnalysis: "perTest"`, `incremental: true`, mutate only `$CHANGED` source files. Surviving mutants are P3 findings with the mutant diff as evidence. Never runs without the flag.

## Phase 3: `--fix`

Arm the Stop gate first, disarm before the report ([loop.md](/_shared/loop.md) §Arming table):

```bash
GATE_DIR=".cc-sessions/sessions/${CLAUDE_SESSION_ID}"; mkdir -p "$GATE_DIR"
jq -n --arg until "check ${SLUG:-diff} fix" '{checks:[{name:"tsc",cmd:"npx tsc --noEmit --pretty false",timeout:180},
  {name:"lint",cmd:"npx eslint . --max-warnings=-1",timeout:180}],blocks:0,max_blocks:6,until:$until}' > "$GATE_DIR/gate.json"
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

## Phase 4: RATCHET, SECURITY POSTURE, CRITIC

### 4.1 Ratchet (`docs/sweeps/ratchet.json`)

Compute the eight metrics with the detectors in [quality.md](/_shared/quality.md) §Ratchet. `type_errors > 0` is an absolute floor → FAIL, no override. Improvement → set `current`, tighten `max_allowed`/`min_allowed`, append a `history[]` snapshot with `ref` and `plan`. Regression:

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

### 4.3 Critic `--mode reject`

Skipped at `repo` scope and under `--only`. Spawn one `blitz:critic` with `--mode reject` (opus, fresh context, never resumed, no Write/Edit, `omitClaudeMd: true`) on `check.patch` plus `spec.md`/`plan.md` at plan scope, the gates JSON, the ratchet delta and the FP-verified survey findings. It runs `tasks[].verify[]` through `tasks.sh` itself. Reply: `{verdict: "LGTM"|"REJECT", findings[]}`, validated with `jq`; a MALFORMED or MISSING critic is a REJECT (the verdict is load-bearing, never skipped). Cross-model: `BLITZ_USE_GEMINI_CRITIC=1` routes through `hooks/scripts/critic-gemini.sh --mode pre-pass`; `BLITZ_DUAL_CRITIC=1` (`--dual`) runs both and requires both `LGTM`. A missing `gemini` binary under `--dual` degrades to in-Claude only with a printed warning; it never silently passes.

## Phase 5: VERDICT AND REPORT

| Verdict | Criteria ([quality.md](/_shared/quality.md) §PASS / CONDITIONAL / FAIL) |
|---|---|
| **PASS** | tsc, lint, full tests, build pass; every task in scope `passes: true`; no P0/P1 finding; no ratchet regression; critic `LGTM`; security posture clean |
| **CONDITIONAL** | gates pass but P2 or unresolved advisory findings remain; minor gate failures with no P0/P1; a regression already carried as a `ratchet:<metric>` blocked task; posture non-zero without injection |
| **FAIL** | any gate fails after `--fix`; any P0/P1; critic `REJECT`; `type_errors > 0`; a `ratchet:<metric>` task still blocked at attempt 3; injection or pre-trust execution |

Automation coverage: `DETERMINISTIC_PASSED/TOTAL` from the gates JSON plus ratchet and critic; `e2e_coverage`; recommendation `auto-merge-safe` (all gates, `e2e_coverage: full`, zero Critical/Major) or `needs-human-review`. Architectural fit, UX sense, business intent and untested regressions are never auto-verified; say so in the report.

**Plan scope** writes `docs/plans/<slug>/check-report.md` from `references/main.md` §Report template with frontmatter:

```yaml
---
result: PASS | CONDITIONAL | FAIL
ts: <ISO-8601>
ref: <git rev-parse HEAD>
scope: plan
plan: <slug>
---
```

then appends `## <ts> check <result> check-report.md` to `progress.md`. **Diff and repo scope** print the same report to stdout (`scope: diff|repo`, no `plan` key) and write nothing under `docs/plans/`. Terse-technical: tables, `L<line>: <severity> <problem>. <fix>.`, `LGTM` for an empty severity bucket. `--comment`: `ToolSearch "inline_comment"`; when `mcp__github_inline_comment__create_inline_comment` is present post one comment per Critical/Major finding (`path`, `line`, `body` = the finding line), else print them under `## Inline comments (not posted)`.

Final block: `[check] <result> scope=<s> ref=<sha> gates=<n>/<n> findings=C<n>/M<n>/m<n> critic=<LGTM|REJECT|skipped> e2e=<coverage>`, then `Next: /blitz:ship --plan <slug>` on PASS, `/blitz:build <slug>` on a task-attributable failure, `/blitz:check … --fix` otherwise. Disarm the gate, patch `working_on`, log `skill_end`.

## Only

`--only <lane>` runs that lane's registry rows read-only over the scope, FP-verifies, and reports ranked by `effective_confidence`; no survey fan-out, no critic, no report file, no ratchet write.

| `--only` | Rows | Notes |
|---|---|---|
| `completeness` | `o2-anti-mock`, `o2-artifact-l1l2`, det-05/06/07/09/10/15 | the placeholder / stub scan; feeds ratchet `completeness_score` when run from the full pipeline |
| `wiring` | `o3-wiring`, `o3-orphan-route`, det-16 | `build` calls this after integration work |
| `framework` | `fw-firestore-vue-pinia` (Phase 1.5) | `--fix` applies F5/V3/P2 recipes |
| `design` | `pillar == design` (Phase 1.6) | preflight banner is mandatory; reduced coverage is never green |
| `security` | `sec-startup-schema`, `sec-startup-injection`, `sec-capability-grant`, `sec-content-inspection` (advisory), det-07, plus the Phase 4.2 posture gate | prints one line: deep scans are `/security-review` (bundled) or the `claude-security` plugin's verified SARIF findings; `check` does not replace them |

## Gotchas

- Only high-confidence-band findings are actionable; lower bands are advisory and never become blockers by being repeated.
- Lane authority differs: a deterministic hit and the critic's `REJECT` are binding; survey findings are advisory. Do not conflate them, and do not let a survey agent's "Critical" label override the registry's authority derivation.
- `--only` scopes the run; the PASS/CONDITIONAL/FAIL verdict and `check-report.md` are the full pipeline's job. `next --loop` row 3 needs the full pipeline at plan scope.
- Tests alone are gamed (SpecBench): a green full run with a failing non-test `verify[]` check is a P1, not a nit.
- `repo` scope is recall mode and costs accordingly; it never writes a report and never spawns the reject critic. Use `/blitz:audit` when the goal is a debt inventory with tasks.
- A fresh PASS is never overwritten by a re-run; change something (or pass `--force`) to re-check.

## Recovery

| Failure | Action |
|---|---|
| Survey agent timeout / missing | PARTIAL when its file is non-empty; a MISSING security survey aborts (`SECURITY DOMAIN UNREVIEWED`) |
| `--fix` loop fails `max` times on one issue | stop that category, list it under Manual fixes; plan scope appends a task via `tasks.sh add … --origin check` |
| No test runner / no build script | gate `SKIPPED`, coverage noted; not FAIL |
| Critic MALFORMED / MISSING | one re-spawn with the same inputs; second failure = REJECT |
| Ratchet file missing | run the bootstrap block in [quality.md](/_shared/quality.md) §Bootstrap, baseline from this run, no regression possible on first run |
| Kill switch (`.cc-sessions/STOP`) mid-run | every tool call is denied; remove the gate file when the switch is lifted and re-run from Phase 0 |
