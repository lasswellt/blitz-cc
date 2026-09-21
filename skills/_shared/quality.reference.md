# quality reference

Detail split out of [quality.md](quality.md) so the contract every skill loads stays small. What "done" means structurally, why tests alone do not establish it, and the three verdicts lives there; everything below is loaded on demand.

---

## Shared check registry

[check-registry.json](/_shared/check-registry.json) (schema `blitz-check-registry/2.0`) is the single source of truth for every check that `check` and `audit` run. Consumers **select rows**; `agents/critic.md` and `agents/research-critic.md` **enforce rows**. No grep pattern lives in a skill or agent body; cite ids (`det-NN`, `sem-*`, `o2-*`, `o3-*`, `fw-*`, `design-*`, `sec-*`, `tia-*`) and run `detection.command`. `hooks/scripts/check-registry-validate.sh` asserts the schema and the derivation invariant below at commit time.

### Axes

| Axis | Values | Meaning |
|---|---|---|
| `lane` | `deterministic` \| `semantic` | detection mechanism (below) |
| `pillar` | completeness, wiring, framework, design, security, architecture, perf, maintainability, robustness | grouping for `--only <pillar>` and audit fan-out |
| `severity` | P0–P3 | triage and ratchet importance; **not** verdict authority |
| `verdict_authority` | `reject` \| `advisory` | derived, never set per run |
| `consolidated_target` | `check` \| `audit` \| `both` \| `orthogonal` | which entry point selects the row |

| Lane | Mechanism | FP rate | `base_confidence` | Verification |
|---|---|---|---|---|
| `deterministic` | grep / AST / tsc / git / import-graph / npm-audit | ~0 | 0.6–1.0 | the mechanism is the verification (a `tsc` error reproduces by definition) |
| `semantic` | LLM reasoning about behavior or intent | high, sporadic | 0.45–0.55 single-pass | needs **aggregation** (≥2 agreers) and **FP-verification** (re-read, reproduce) |

The lanes catch disjoint bug classes; a skill that runs only one lane ships errors.

### Exit-code contract

A deterministic row's verdict comes from its `detection.exit`, never from "non-zero means fail". A `grep` detector **passes** when it finds nothing, which is exit 1; a build command passes on exit 0; and a row ending in `wc -l` always exits 0, so its verdict is the number it prints. Reading every row the same way either over-reports or under-reports, depending on the tool.

| Shape | `detection.exit` | Reading |
|---|---|---|
| Command (`git diff`, `cargo check`, a script) | `{"pass":[0],"finding":[1],"error":[2]}` | Exit 0 passes; 1 is a finding; anything else is a broken detector, reported as `error`, never as a pass |
| Grep-family tail (`grep`, `git grep`, `rg`) | `{"pass":[1],"finding":[0],"error":[2]}` | Exit 1 (no match) passes; exit 0 (matched) is the finding |
| impeccable (`npx impeccable detect --json`) | `{"pass":[0],"finding":[2],"error":[1]}` | Exit 0 prints `[]`; exit 2 prints the findings JSON, a result rather than a failure. It inverts the Command shape, which is why these rows carry their own contract and `check-registry-validate.sh` rejects one that does not |
| Counter (`… \| wc -l`, `jq` of a metric) | `{"verdict":"stdout", "note":"…"}` | Ignore the exit code entirely; the number on stdout is the verdict, compared against the ratchet |

A row with no `exit` key is not evaluated by running it: `det-17` and `det-18` describe operational signals a hook raises, not commands to execute.

Report `error` distinctly from `finding`. A detector that cannot run is unknown, not clean, and silently scoring it as a pass is how a check lane reports green on a machine where the tool is missing.

### Verdict authority

`reject iff (lane == deterministic ∧ severity ∈ {P0, P1, P2}); else advisory`

- `reject`: ground-truth-anchored. May flip a critic or check verdict to REJECT / FAIL. **Bypasses the min-confidence gate** (`confidence_gate.reject_bypass`): facts are not confidence-triaged.
- `advisory`: opinion-anchored (any semantic row, or a P3 deterministic row). Appends to `issues[]` only; **never flips a verdict**; subject to min-confidence suppression.

Severity ≠ authority: `sem-sec` is P2 yet advisory. This codifies the self-critique paradox (arxiv 2402.08115): opinion-anchored verification is structurally barred from rejection; `tsc`, reflog and ratchet arithmetic keep full reject authority.

### Confidence model

```
effective_confidence = base_confidence × fp_verification_factor
```

| Term | Values |
|---|---|
| `base_confidence` | inverse-FP prior; deterministic ≈ 0.6–1.0, semantic single-pass ≈ 0.5, semantic ≈ 0.85 only when ≥2 independent agents flag the same finding |
| `fp_verification_factor` | `reproduced → 1.0`, `not_reproduced → 0.0` (dropped), `inaccessible/unverifiable → 0.5`. Max 1.0: **FP-verification can only preserve or drop, never raise**; only aggregation raises |
| Gate (advisory rows only) | `check` → `--min-confidence high` (≥0.8, precision, runs often); `audit` → `--min-confidence low` (≥0.0, recall, runs rarely) |
| Downgrade rule | a semantic finding with no reproducing evidence is capped at `advisory`, `fp_verification_factor` defaults to 0 until evidence is attached; counts are never findings without a sampled excerpt (det-20) |

### Selection contract

`check-registry.json` is ~98 KB of data. **Query it; never read it into context.** Reading the file costs ~24K tokens to obtain the handful of rows an invocation runs.

```
check_checks   = checks.filter(c => c.consolidated_target in {check, both})
audit_checks   = checks.filter(c => c.consolidated_target in {audit, both})
deterministic  = checks.filter(c => c.lane == 'deterministic')   # both skills, run first, fast, zero-FP
semantic       = checks.filter(c => c.lane == 'semantic')        # check: single-pass; audit: aggregated
reject_only    = checks.filter(c => c.verdict_authority == 'reject')   # may flip verdict; bypass min-confidence
stack_scoped   = checks.filter(c => c.stacks includes '*' or the project's stack)
```

Every row carries `stacks[]`: `["*"]` for a row that applies anywhere, or a list of stack ids (`node`, `python`, `rust`, …) matching `scripts/toolchain.sh stacks`. A row scoped to a stack the project does not have is skipped, not failed: running the Vue/Firestore packs or `npx impeccable` in a Go repository produces noise, not findings.

The canonical selector, one row per line, ids and commands only:

```bash
STACKS=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/toolchain.sh" stacks | jq -R . | jq -sc .)
jq -r --argjson stacks "${STACKS:-[]}" --arg target check --arg lane deterministic '
  .checks[]
  | . as $c
  | select(($c.consolidated_target // "both") | IN($target, "both"))
  | select($c.lane == $lane)
  | select((($c.stacks // ["*"]) | index("*")) != null
           or (($c.stacks // []) | any(. as $s | $stacks | index($s) != null)))
  | "\($c.id)\t\($c.severity)\t\($c.detection.command // "")"
' "${CLAUDE_PLUGIN_ROOT}/skills/_shared/check-registry.json"
```

Swap `--arg lane semantic` for the semantic lane, and `--arg target audit` for `audit`. To pull one row by id: `jq -r --arg id det-11 '.checks[] | select(.id==$id)'`.

`check` suppresses what `audit` re-surfaces: a single-pass semantic finding `check` drops as low-confidence is what `audit`'s aggregation lifts to high confidence. Orthogonal domains stay out of the registry: `dep-health`, `perf-profile`, `ui-audit`, `browse`.

### Which entry point

| Symptom | Run |
|---|---|
| Is this change or plan mergeable? | `/blitz:check` (`--scope plan <slug>` \| `--scope diff`) |
| Pre-release deep audit; find all debt | `/blitz:audit` |
| Just the placeholder / stub scan | `/blitz:check --only completeness` |
| Just wiring / orphan routes / auth | `/blitz:check --only wiring` |
| Vue / Firestore / Pinia framework misuse (with `--fix`) | `/blitz:check --only framework [--fix]` |
| Design slop / design-system conformance | `/blitz:check --only design` (precision) · `/blitz:audit --pillar design` (recall) |
| Security rows + pointer to `/security-review`, claude-security | `/blitz:check --security` |
| Mutation score on changed files | `/blitz:check --mutation` |

Before adding a quality skill, ask: distinct scope (change vs repo)? distinct tempo (per-change vs pre-release)? distinct downstream (check-report vs ratchet vs tasks.json)? Would a `--only` or `--mode` flag on `check` or `audit` do? It usually would: add a registry row or a flag, not a skill.

## Detectors

20 catalogued autonomous-coder shortcuts, `det-01…det-20`. 13 carry reject authority; 7 are advisory (det-05, 08, 09, 10, 16, 17, 20). Executable form is the registry row; this table is the readable view.

| Id | Failure | Signal | Hook | Else |
|---|---|---|---|---|
| det-01 | Deleted failing tests | `git diff --diff-filter=D -- '*.test.*' '*.spec.*'` | `block-test-deletion.sh` | critic |
| det-02 | `--no-verify` bypass | Bash command or reflog contains standalone `--no-verify` | `block-no-verify.sh` | critic |
| det-03 | Mock count grows in `src/` | `vi.mock\|jest.mock\|sinon.stub` delta > 0 outside `__tests__` | — | ratchet `mocks_in_src` |
| det-04 | `as any` / `@ts-ignore` proliferation | added lines in non-test `src/` | `block-as-any-insertion.sh` (partial: insertions only) | ratchet `as_any_count`, critic |
| det-05 | Swallow-and-continue catch | empty catch or log-only catch, no rethrow | — | `check --only completeness` |
| det-06 | Env fallbacks hiding config errors | `\|\| '…'` / `?? '…'` near secret/key/token/host/port | — | `check --only completeness` |
| det-07 | Hardcoded credentials | `password = '…'` + entropy | `pre-edit-guard.sh` (.env) | `check --only completeness` |
| det-08 | Commented-out assertions | `^+\s*//.*expect\|assert\|should` in diff | — | `check` (advisory) |
| det-09 | `throw new Error('Not implemented')` | grep | — | `check --only completeness` |
| det-10 | `return {}` / `return []` stubs | grep in business logic | — | `check --only completeness` |
| det-11 | Hallucinated APIs / symbols | `tsc --noEmit` + import resolution | `post-edit-typecheck-block.sh` | critic |
| det-12 | Claiming done on a broken build | tsc error count rose after a write | `post-edit-typecheck-block.sh` (blocking) | — |
| det-13 | `.skip` / `.only` / `xit` / `xdescribe` | grep on test files | `block-test-disabling.sh` (partial: insertions only) | critic |
| det-14 | Test file renamed away | `git log --diff-filter=R` to a non-test path | — | critic |
| det-15 | Hardcoded localhost / ports / URLs | grep in `src/` | — | `check --only completeness` |
| det-16 | Orphaned files never imported | import-graph traversal | — | `check --only wiring` |
| det-17 | Infinite correction loop | consecutive fix failures ≥ 2 | — | `build` circuit breaker (`attempts`) |
| det-18 | Destructive SQL outside a migration | DROP/DELETE/TRUNCATE in a DB CLI command | `block-destructive-sql.sh` | — |
| det-19 | `git reset --hard` on a dirty tree | git command + non-empty working tree | `block-destructive-git.sh` | — |
| det-20 | Unverified pattern-match claim | finding cites a count with no sampled excerpt or no `Confidence:` | — | critic (advisory) |

Hooks are PreToolUse unless noted (det-11/12 are PostToolUse); every hook `exit 2`s on a hit. Everything without a hook is a check-time grep or a critic checklist item.

### Severity tiers

| Tier | Detectors | Consequence |
|---|---|---|
| P0 | det-01, 02, 12, 18, 19 | hook hard-block; blast radius too large to defer to `check` |
| P1 | det-04, 11, 13, 14 | `check` BLOCKER; a plan cannot reach PASS while present |
| P2 | det-03, 06, 07, 15 | ratchet metric; deterministic regression triggers auto-revert |
| P3 | det-05, 08, 09, 10, 16, 17, 20 | advisory; surfaced, never blocks |

### Escape hatches

| Detector | Escape | Why it exists |
|---|---|---|
| det-01 test deletion | commit message contains `BREAKING:` and the user is the committer | intentional test removal in a breaking change |
| det-02 `--no-verify` | `BLITZ_OVERRIDE_NO_VERIFY=1` set by the user, not an agent; logged | hotfix over a documented flaky test |
| det-04 `as any` | same-line `// blitz:any-allowed: <reason>` | unavoidable interop; the comment is the documentation |
| det-13 `.skip` | same-line `// blitz:skip-pinned: #<issue>` | pinned awaiting an external fix |
| det-18 destructive SQL | path contains `migrations/`, or a `migrate up\|down\|run` invocation | migration tooling |
| det-19 `git reset --hard` | working tree clean, or the user typed it | nothing to lose |

Agents add an escape comment only with a defensible reason; `check` spot-checks three random escape comments per run and the rationale must survive.

## Ratchet

Monotonic metrics so work compounds: quality only improves across plans. Stored in `docs/sweeps/ratchet.json` (**tracked**, no longer gitignored); updated by `check` and `audit`.

| Metric | Direction | Floor | Detector |
|---|---|---|---|
| `test_count` | ↑ | baseline | `grep -rcE '\b(it\|test)\(' --include='*.test.*' --include='*.spec.*' . \| awk -F: '{s+=$2} END {print s}'` |
| `type_errors` | ↓ | **absolute 0** | `npx tsc --noEmit 2>&1 \| grep -cE 'error TS\d+'` |
| `as_any_count` | ↓ | baseline | `grep -rEn '\bas any\b' src/ --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ \| wc -l` |
| `lint_violations` | ↓ | baseline | `npx eslint --format=json . 2>/dev/null \| jq '[.[].errorCount] \| add // 0'` |
| `completeness_score` | ↑ | baseline | `/blitz:check --only completeness` |
| `mocks_in_src` | ↓ | baseline | `grep -rEn '\b(vi\.mock\|jest\.mock\|sinon\.stub)\b' src/ --exclude-dir=__tests__ \| wc -l` |
| `todo_count` | ↓ | baseline | `grep -rEn '\b(TODO\|FIXME)\b' src/ \| wc -l` |
| `stale_worktree_branch_count` | ↓ | baseline | `git worktree list --porcelain \| awk '/^worktree .*\/.claude\/worktrees\//{w=1} /^branch /{if(w){print $2}; w=0}' \| wc -l` — branches of `.claude/worktrees/*` checkouts the platform sweep has not removed |

`type_errors` has an absolute floor of 0 in addition to the ratchet: once a project is type-clean it cannot regress to 1, and there is no override. `stale_worktree_branch_count` counts `.claude/worktrees/*` left behind after the platform's periodic sweep; a live subagent worktree inflates it transiently, so never prune to drive the number down — let it settle, then `sessions worktrees` removes what the sweep missed. Existing projects baseline it once (`check --baseline stale_worktree_branch_count`).

Advisory (collected, not ratcheted): `tia_escaped_failures` (`jq '.escaped_failures_recent[-1] // 0' .cc-sessions/test-journal.meta.json`) and `tia_selection_ratio` (`scripts/test-selector.sh --json … \| jq .selection_ratio`); registry `tia-*`. A non-zero escape in any of the last 3 runs forces the selector to `--full` until the streak clears.

### Schema

```json
{
  "$schema": "blitz-ratchet/1.0",
  "ref": "<commit sha of the last check run>",
  "plan": "<slug>",
  "updated_at": "2026-09-19T00:00:00Z",
  "metrics": {
    "test_count":         {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "type_errors":        {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down", "absolute_floor": 0},
    "as_any_count":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "lint_violations":    {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "completeness_score": {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "mocks_in_src":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "todo_count":         {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "stale_worktree_branch_count": {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"}
  },
  "auto_revert": {"enabled": true, "needs_human_label": "ratchet-regression"},
  "history": [
    {"ref": "<sha>", "plan": "<slug>", "ts": "2026-09-01T00:00:00Z", "metrics": {"...": "..."}}
  ]
}
```

| Field | Rule |
|---|---|
| `ref`, `plan` | commit sha and plan slug of the run that wrote `current` (the v2 record carried a sprint id here) |
| `baseline` | value at the previous PASS; frozen reference |
| `current` | value at the last `check` run |
| `min_allowed` / `max_allowed` | enforcement threshold; = baseline by default, tightens when `current` beats it |
| `history[]` | append-only snapshots per PASS; never rewritten |

### Tighten on improvement

When a `check` run computes `current` better than the threshold: set `current`; set `max_allowed = current` (↓ metrics) or `min_allowed = current` (↑ metrics); append a `history[]` snapshot. Thresholds never loosen: once `as_any_count` drops to 5 it stays ≤5.

### Auto-revert on regression

After each fix commit during `build` or `check --fix`:

```
current = compute_metrics()
for metric in direction-violations:
  if metric in {type_errors, as_any_count, lint_violations, completeness_score, mocks_in_src, todo_count, stale_worktree_branch_count}:
    require clean tree                       # never `git reset --hard` on a dirty tree (det-19)
    git revert --no-edit HEAD                # the fix commit only
    scripts/tasks.sh add <plan> --id T-<next> --title "ratchet regression: <metric> <old>-><new>" \
      --origin check --verify-cmd "test $(<metric detector>) -le <max_allowed>::30"
    scripts/tasks.sh set <plan> T-<next> status=blocked blocked_reason=ratchet:<metric>
    stop further auto-fixes for this metric this run
  elif metric == test_count:
    scripts/tasks.sh add <plan> --id T-<next> --title "test_count regression (possible flaky)" \
      --origin check --verify-cmd "test $(<test_count detector>) -ge <min_allowed>::30"
    scripts/tasks.sh set <plan> T-<next> status=blocked blocked_reason=ratchet:test_count   # never auto-revert
```

The appended task carries `{origin: "check", blocked_reason: "ratchet:<metric>"}`; `next --loop` row 1 escalates it and `progress.md` gets a `Ruling:` line when a human resolves it. `test_count` never auto-reverts (flaky removal is possible); every other metric is deterministic.

### Bootstrap and override

Run once per project (`onboard` does it):

```bash
mkdir -p docs/sweeps
jq -n --arg ref "$(git rev-parse HEAD)" '{"$schema":"blitz-ratchet/1.0", ref:$ref, plan:null, updated_at:(now|todate),
  metrics:{test_count:{baseline:0,current:0,min_allowed:0,direction:"up"},
           type_errors:{baseline:0,current:0,max_allowed:0,direction:"down",absolute_floor:0},
           as_any_count:{baseline:0,current:0,max_allowed:0,direction:"down"},
           lint_violations:{baseline:0,current:0,max_allowed:0,direction:"down"},
           completeness_score:{baseline:0,current:0,min_allowed:0,direction:"up"},
           mocks_in_src:{baseline:0,current:0,max_allowed:0,direction:"down"},
           todo_count:{baseline:0,current:0,max_allowed:0,direction:"down"},
           stale_worktree_branch_count:{baseline:0,current:0,max_allowed:0,direction:"down"}},
  auto_revert:{enabled:true,needs_human_label:"ratchet-regression"}, history:[]}' > docs/sweeps/ratchet.json
```

The first real `check` run computes baselines from the codebase and tightens. `auto_revert.enabled: false` switches to advisory mode (regressions still append a blocked task, nothing is reverted) for projects fighting flakiness. The `type_errors` absolute floor has no override.

## Definition of Done

Checklist every code-producing skill and agent verifies before `tasks.sh verify` is even worth running. Registry ids in parentheses are what `check` runs against the diff.

### Anti-mock rules (non-negotiable)

Banned in production code; any hit means the work is not done.

| # | Banned pattern | Why | Registry |
|---|---|---|---|
| 1 | `return {}` / `return []` / `return null` as placeholder returns | silent wrong behavior in production | det-10, check:anti-mock |
| 2 | `throw new Error('Not implemented')` / `throw new Error('TODO')` | crash in production | det-09, check:anti-mock |
| 3 | Empty function bodies that should have logic | feature silently does nothing | check:anti-mock |
| 4 | Hardcoded sample data posing as real data | users see fake data | check:anti-mock |
| 5 | `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code belongs | incomplete delivery | check:anti-mock, ratchet `todo_count` |
| 6 | Empty catch blocks that swallow errors | hides failures | det-05 |
| 7 | Functions that only log and return | feature silently does nothing | check:anti-mock |
| 8 | No-op event handlers (`() => {}`) | interactions do nothing | check:anti-mock |
| 9 | Store actions returning hardcoded data instead of calling real APIs | stale or fake data | check:anti-mock, build:integration |
| 10 | `vi.mock` / `jest.mock` of a module under `src/` in a new test | test passes while the product fails | det-03, ratchet `mocks_in_src` |
| 11 | A test edit that removes or trivializes an assertion so the visible check passes | the oracle was changed, not the code | check:test-tamper |

Self-check for every function written: "if this ran in production right now, would it work?" No ⇒ not done.

### Scope discipline

- No abstraction the task did not require; no future-proofing (configurability, plugin hooks, generics) the task did not name.
- No error handling for scenarios the task does not mention.
- No files outside the task's `files[]`; every changed line traces to a `verify[]` entry or the spec.
- If the change grows past ~150% of the plan's estimate, reply `DONE_WITH_CONCERNS` and say why in `notes` before marking done.

### Code quality

- Type-check and lint pass with zero new errors (`post-edit-typecheck-block.sh`, `post-edit-format.sh`).
- No `any`; use `unknown` with type guards (det-04).
- No `console.log` left behind; no commented-out code blocks.
- No hardcoded secrets, keys or URLs (det-07, det-15); configuration comes from the environment without silent fallbacks (det-06).

### Security (backend)

- Every callable function has an auth check; every endpoint checks authorization, not only authentication.
- No user input reaches the database without validation.
- No PII in logs beyond a user id; error messages leak no stack traces or schema details.
- Firestore rules changes ship with a `@firebase/rules-unit-testing` assertion.

### Testing

- New public functions have at least one test that exercises real code, not mock return values.
- Error paths are tested, not only the happy path.
- No `it.skip`, `xit`, `describe.skip` or `.only` left in (det-13).
- Author guidance: [deterministic-tests.md](../test-gen/references/deterministic-tests.md).

### Build

- The project builds; no new build warnings.

## REVIEW.md export

Hosted Code Review reads `CLAUDE.md` (violations surface as nits) and `REVIEW.md` (severity, skip rules, verification bar). `scripts/gen-review-md.sh` renders the registry rows with severity P0 or P1 into `REVIEW.md` so the hosted reviewer and `check` block on the same facts; `doctor --review-md` runs it.

| Section in `REVIEW.md` | Source |
|---|---|
| Blocking findings | every row with `severity ∈ {P0, P1}`: id, name, `detection.command`, escape hatch |
| Skip rules | the escape-hatch table above, rendered per row |
| Verification bar | `tasks.sh verify` evidence for tasks in the PR; tsc, lint, full tests, build |
| Nits | not listed; `CLAUDE.md` conventions surface as nits on their own |

Regenerate after any registry edit (`check-registry-validate.sh` then `gen-review-md.sh`); commit the result. The file is derived: hand edits are overwritten.

## Verification stack

Four layers, one owner and one kind of verdict each. They compose; none replaces another. Contracts and the ladder live in [loop.md](/_shared/loop.md).

| Layer | Mechanism | Owner | Decides |
|---|---|---|---|
| Deterministic gate | `hooks/scripts/stop-gate.sh` + `.cc-sessions/sessions/<sid>/gate.json`; tests from `scripts/test-selector.sh` | blitz Stop hook | tsc / selected tests / ratchet quick-check pass |
| Goal evaluator | `/goal <plan DoD>` (bundled prompt-type Stop hook: a separate evaluator judges the transcript; counts against the platform's 5-block `stopHookBlockCap`) | user; `next --loop` prints the line once | condition met / not yet / impossible |
| Adversarial | `agents/critic.md --mode reject` on the diff, fresh context, no Write/Edit | `check` Phase 4.3 | LGTM / REJECT |
| App-level | `/verify` recipe recorded at `.claude/skills/verify/SKILL.md` (bundled, user-only); `check` reads and replays it | user | the app runs and behaves |

The gate is a no-op without `gate.json`; `max_blocks` (4) stays under the platform's 5-consecutive-block cap; the plugin never wires a prompt-type Stop hook (it would collide with a user `/goal`). "Selected tests pass" means the sibling + import-graph + journal-history set; the full suite runs once at `check` to measure what the selector missed.
