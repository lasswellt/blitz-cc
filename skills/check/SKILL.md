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

`--scope diff|plan <slug>|repo` (default `diff`) · `--only completeness|wiring|framework|design|security` · `--fix` · `--comment` · `--mutation` · `--dual` · `--min-confidence high|low` · `--baseline <metric>` · `--force`.

What each one changes, and the scope/confidence defaults that follow from it: [references/main.md](references/main.md) §Flags.

## Phase 0: SCOPE

Resolve `BASE`, the changed-file set, and the changed packages in a monorepo; record `[check] scope=<s> base=<sha> files=<n> loc=<n>`. Above 2000 LOC the Phase 2 fan-out goes sequential (`BLITZ_REVIEW_SEQUENTIAL=1` forces it). Commands and the prior-PASS short-circuit: [references/main.md](references/main.md) §Phase 0 SCOPE.

## Phase 1: DETERMINISTIC LANE

**Dispatch:** running a row's `detection.command` and reporting `{id, exit_code, stderr_head}` is bookkeeping, not judgement, so collect this lane in one `Agent({subagent_type: "Explore", model: "haiku"})` given the selected rows and a JSON reply schema ([agents.md](/_shared/agents.md) §1.3). Keep the semantic lane and the PASS/FAIL verdict on the session model. Fall back to running them inline when the lane has ≤5 rows, where the spawn costs more than it saves.

Run everything; collect, do not stop at the first failure. No grep pattern lives in this file: every row is cited by id and its `detection.command` runs from [check-registry.json](/_shared/check-registry.json). **Query that file with `jq`; never read it into context** — it is ~98 KB of data and the selector in [quality.reference.md](/_shared/quality.reference.md) §Selection contract returns only the ids and commands this run needs. The selector also drops rows whose `stacks[]` does not match `scripts/toolchain.sh stacks`, so a Go or Python repository never runs the Vue/Firestore packs or `npx impeccable`. Read each row's verdict through its `detection.exit` contract ([quality.reference.md](/_shared/quality.reference.md) §Exit-code contract): a grep row **passes on exit 1**, and a row that could not run is `error`, never a pass.

### 1.1 Gates → `${SESSION_TMP_DIR}/check-gates.json`

Gate commands resolve per detected stack from the toolchain table; a lane with no row is recorded `skipped` with its reason, never as a pass. Commands, the record shape, and the two-run TIA split: [references/main.md](references/main.md) §1.1 Gates.

### 1.2 Registry rows

Select `consolidated_target ∈ {check, both}` and `lane == deterministic`; run each row's `detection.command` over `$CHANGED` (`repo` scope: over everything). Reject-authority hits (`severity ∈ {P0, P1, P2}`) go straight to the blocker list and bypass the confidence gate; P3 hits are advisory. The shortcut detectors without a hook (det-05…10, 14, 15, 16, 20) run here; det-01/02/13 also re-scan the diff in case a hook was bypassed.

### 1.3 Anti-mock scan (`o2-anti-mock`, `o2-artifact-l1l2`, det-09, det-10)

Run the `o2-*` rows over the diff. Any hit in non-test code is a **Critical** finding (registry P3 with reject-lane evidence, surfaced as blocker per the Definition of Done in [quality.md](/_shared/quality.md) §Anti-mock rules). Record `file:line pattern`.

### 1.4 Wiring (`o3-wiring`, `o3-orphan-route`, det-16)

Conditional: run when the diff adds files under `stores/|composables/|pages/|server/api/|routes/|functions/` or new exports. Findings map high → Major, medium → Minor, low → Info and feed the Phase 2 reviewer context.

### 1.5 Framework rules (`fw-firestore-vue-pinia`)

Gated by the stack banner (`HAS_FIRESTORE`, `HAS_VUEFIRE`, `HAS_VUE`, `HAS_PINIA` from `package.json`); only detected rule sets run. Rule table with ids F1–F10, V1–V5, G1–G5, P1–P4, D1, DUP1: `references/main.md` §Framework rules. Context rules (F2 `onSnapshot` without `onUnmounted`, F6 `getDocs(collection(` without `query(`) check the whole file. Skip lines carrying `// code-doctor-ignore: <ruleId>`. `--fix` applies only `auto_fix: true` rows (F5, V3, P2) with the recipes in `references/main.md`, then re-greps the fixed rule ids; a remaining hit is `fix_partial`.

### 1.6 Design lane (`pillar == design`)

Runs only when the design adapter is detected. Lane selection and row set: [references/main.md](references/main.md) §1.6 Design lane.

### 1.7 Task verification (plan scope)

Plan scope runs `tasks.sh verify` on every task and records `last_verify.runs[]` as the evidence a verdict rests on. Commands: [references/main.md](references/main.md) §1.7 Task verification.

### 1.8 Escape-comment spot check

Pick three random `blitz:any-allowed` / `blitz:skip-pinned` comments in scope; read each rationale. One that does not survive reading is a P2 finding (det-04 / det-13 escape abuse).

## Phase 2: SEMANTIC LANE

One `critic --mode survey` per lens over the diff, read-only, findings collected and gated per [agents.reference.md](/_shared/agents.reference.md) §4.4. Lens roster, collection, app-level verification and `--mutation`: [references/main.md](references/main.md) §Phase 2 SEMANTIC LANE.

## Phase 3: `--fix`

Only with `--fix`. Arms the gate, applies the fixable findings, re-runs the lanes that produced them, and disarms. Full procedure: [references/main.md](references/main.md) §Phase 3 `--fix`.

## Phase 4: RATCHET, SECURITY POSTURE, CRITIC

### 4.1 Ratchet (`docs/sweeps/ratchet.json`)

Every metric must be at or below its baseline; a regression is a FAIL the verdict cannot override. Metric list, tighten-on-improvement and auto-revert: [quality.reference.md](/_shared/quality.reference.md) §Ratchet, procedure in [references/main.md](references/main.md) §4.1 Ratchet.

### 4.2 Security posture gate (every run)

Runs the `sec-*` registry rows on every check, not only with `--security`. Row set and the `/security-review` handoff: [references/main.md](references/main.md) §4.2 Security posture gate.

### 4.3 Critic `--mode reject`

Skipped at `repo` scope and under `--only`. Spawn one `blitz:critic` (opus, fresh context, never resumed, no Write/Edit, `omitClaudeMd: true`) whose prompt opens with `MODE: reject`, `PLAN: <slug|none>`, `TASKS: <ids in scope>`, `BASE: <sha>`, on `check.patch` plus `spec.md`/`plan.md` at plan scope, the gates JSON, the ratchet delta and the FP-verified survey findings. It runs `tasks[].verify[]` through `tasks.sh` itself and authors one held-out check per task (`held_out[]`, [critic.md](../../agents/critic.md) §2.5); a failing held-out check is a REJECT. Reply: `{verdict: "LGTM"|"REJECT", findings[], held_out[]}`, validated with `jq`; a `held_out[]` shorter than the task list at plan scope is MALFORMED; a MALFORMED or MISSING critic is a REJECT (the verdict is load-bearing, never skipped). Cross-model: `BLITZ_CRITIC_PROVIDER=agy|copilot|codex|gemini` routes through `hooks/scripts/critic-external.sh --mode pre-pass --plan <slug|none> --tasks <ids> --base <sha>`, run from the repo root (it builds the `MODE: reject` header, lifts the critic body and inlines `git diff <base>`) (`BLITZ_USE_GEMINI_CRITIC=1` is the legacy alias for `gemini`); `BLITZ_CRITIC_PANEL=agy,copilot` fans out to several families and any REJECT blocks; `BLITZ_DUAL_CRITIC=1` (`--dual`) pairs the in-Claude critic with the external one and requires both `LGTM`. A missing provider binary under `--dual` degrades to in-Claude only with a printed warning; it never silently passes.

## Phase 5: VERDICT AND REPORT

| Verdict | Criteria ([quality.md](/_shared/quality.md) §PASS / CONDITIONAL / FAIL) |
|---|---|
| **PASS** | tsc, lint, full tests, build pass; every task in scope `passes: true`; every held-out check `ok: true` or explained; no P0/P1 finding; no unresolved `cannot_verify`; no ratchet regression; critic `LGTM`; security posture clean |
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

and a machine-readable sibling `docs/plans/<slug>/check-report.json`, so CI, evals and `next` assert on the run without parsing prose:

```json
{ "$schema": "blitz-check-report/1.0",
  "result": "PASS|CONDITIONAL|FAIL", "ts": "<ISO-8601>", "ref": "<sha>",
  "scope": "plan|diff|repo", "plan": "<slug>",
  "stacks": ["node","python"],
  "lanes": { "deterministic": {"selected": 41, "ran": 41, "pass": 39, "finding": 2, "error": 0},
             "semantic":      {"selected": 9,  "ran": 9,  "pass": 9,  "finding": 0, "error": 0} },
  "findings": [{"id": "det-04", "severity": "P1", "where": "src/x.ts:42", "what": "<≤200 chars>"}],
  "cannot_verify": [],
  "critic": {"mode": "reject", "verdict": "LGTM|REJECT"},
  "tasks": {"verified": 7, "failed": 0} }
```

`selected` counts the rows the [selection contract](/_shared/quality.reference.md) returned for this project's `stacks`; `ran` counts those whose detector actually executed. **`error` is never folded into `pass`**: a detector that could not run is unknown, and reporting it clean is how a lane goes green on a machine that is missing the tool. `result` is `FAIL` when any `error` is present and the run claimed to be complete.

The skill then appends `## <ts> check <result> check-report.md` to `progress.md`. **Diff and repo scope** print the same report to stdout (`scope: diff|repo`, no `plan` key) and write nothing under `docs/plans/`. Terse-technical: tables, `L<line>: <severity> <problem>. <fix>.`, `LGTM` for an empty severity bucket. `--comment`: `ToolSearch "inline_comment"`; when `mcp__github_inline_comment__create_inline_comment` is present post one comment per Critical/Major finding (`path`, `line`, `body` = the finding line), else print them under `## Inline comments (not posted)`.

Final block: `[check] <result> scope=<s> ref=<sha> gates=<n>/<n> findings=C<n>/M<n>/m<n> critic=<LGTM|REJECT|skipped> e2e=<coverage>`, then `Next: /blitz:ship --plan <slug>` on PASS, `/blitz:build <slug>` on a task-attributable failure, `/blitz:check … --fix` otherwise. Disarm the gate, patch `working_on`, log `skill_end`.

## Only

`--only <lane>` scopes the run to one lane and skips the verdict pipeline. Lane names and what each runs: [references/main.md](references/main.md) §Only.

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
