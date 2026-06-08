---
name: sprint-review
description: "Reviews sprint quality: automated gates (type-check, lint, tests, build) + parallel reviewer agents, auto-fixes safe categories. Enforces the carry-forward registry hard gate (Phase 3.6 Invariants 1-8: ratchet, critic, branch hygiene). Full end-of-sprint gate engine — use for 'review sprint', 'sprint quality gate', 'audit sprint'. For per-change/pre-commit review of a diff use /blitz:review instead."
argument-hint: "[--sprint N]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, Agent
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For story YAML schema (canonical, producer/consumer matrix), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For pipeline state contracts (which artifacts this skill produces and requires), see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For review report template, reviewer checklists, and auto-fix strategies, see [references/main.md](references/main.md)
- For context window hygiene (reviewer agents), see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For checkpoint awareness, see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For handling reviewer agent escalations, see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For the carry-forward registry (canonical Reader Algorithm enforced by Phase 3.6), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For subagent spawning, agent output contract (success/failure/partial thresholds), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, canonical exemptions), see [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

All auto-fix code must satisfy the [Definition of Done](/_shared/sprint-contracts.md). No placeholder implementations.

---

# Sprint Review Skill

Review sprint quality through automated checks and parallel reviewer agents. Run type-check, lint, tests, and build verification. Spawn specialized reviewers for security, backend, frontend, and patterns. Auto-fix common failures. Execute every phase in order. Do NOT skip phases.

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Hard-fail if required upstream artifacts missing per [session-lifecycle.md](/_shared/session-lifecycle.md): `sprint-registry.json`, `${SPRINT_DIR}/manifest.json`, `${SPRINT_DIR}/stories/S*.md`. Override (not recommended): `BLITZ_REVIEW_NO_MANIFEST=1`. Bash block in `references/main.md` §**Phase 0.0 Input Gate**.

## Phase 0: CONTEXT — Load Sprint State

1. **Register session.** Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch per terse-output.md.
2. **Find the sprint to review.** Read `sprint-registry.json`; find sprint with `status: review` or `status: in-progress`. Use user-specified number if given. If none ready, inform and STOP.
3. **Check for STATE.md.** If present, read for blocked-story context. Include in review report.
4. **Load stories.** Read all `${SPRINT_DIR}/stories/` files. Categorize: `done` (ready for review), `incomplete` (flag), `blocked` (note in report).
5. **Build codebase inventory.** `find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30`.
6. **Detect changed files + packages.**
   ```bash
   SPRINT_BASE=$(git log --oneline --all | grep -i "sprint-${SPRINT_NUMBER}" | tail -1 | cut -d' ' -f1)
   git diff --name-only ${SPRINT_BASE}..HEAD 2>/dev/null || git diff --name-only HEAD~20..HEAD
   ```
   Determine which packages/workspaces were modified (see references/main.md for detection rules).

**Gate:** At least one story must have `status: done` and changed files must be detectable.

---

## Phase 1: AUTOMATED CHECKS — Quality Gates

Run all checks. Record pass/fail for each. Do NOT stop on first failure — collect all results.

### 1.1 Type-Check
```bash
npm run type-check 2>&1 || npx tsc --noEmit 2>&1
```
Record: Pass/Fail, error count, error list (file, line, message) for auto-fix.

### 1.2 Lint
```bash
npm run lint 2>&1 || npx eslint . 2>&1
```
Record: Pass/Fail, warning count, error count, error list for auto-fix.

### 1.3 Unit Tests (Changed Packages Only)

Monorepo: `for pkg in ${CHANGED_PACKAGES}; do (cd "$pkg" && npm run test); done`. Single-package: `npm run test -- --changed`. Record: total tests, passed/failed/skipped, failure details (test name + file + assertion).

### 1.4 Build Verification
```bash
npm run build 2>&1
```
Record: Pass/Fail, error details if failed.

### 1.5 Quality Gate Summary

Write to `${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-quality-gates.json`:
```json
{
  "type_check": { "pass": true, "errors": 0, "details": [] },
  "lint": { "pass": false, "errors": 3, "warnings": 12, "details": [] },
  "tests": { "pass": true, "total": 45, "passed": 45, "failed": 0 },
  "build": { "pass": true, "errors": 0 }
}
```

---

## Phase 1.5: PATTERN ANALYSIS — Anti-Mock Scan and Convention Check

### 1.5.1 Anti-Mock Scan

Pattern source: canonical anti-mock set in `/_shared/check-registry.json` (o2-*). Inline pattern mirrors it for diff scan — keep in sync with registry's `o2-*` grep patterns.

```bash
git diff --name-only ${SPRINT_BASE}..HEAD | xargs grep -n -E \
  '(TODO|FIXME|PLACEHOLDER|STUB|Not implemented|throw new Error.*implement|return \{\}|return \[\])' 2>/dev/null
```

Any match = **Critical finding**. Record file, line, pattern.

### 1.5.2–1.5.4 Convention, Architecture, Completeness

- **Convention**: backend files have auth/validation patterns + project error format? Frontend handles loading/empty/error states? Store actions call real APIs? Tests assert meaningfully (not just `toBeDefined()` / `expect(true).toBe(true)`)?
- **Architecture**: no improper cross-layer imports (frontend→server/functions, backend→Vue components, test→other test internals).
- **Completeness**: all files listed in done stories exist; no silently dropped circuit-breaker stories.

### 1.6 Integration Check (Conditional)

If sprint introduced new modules, routes, stores, or API endpoints:
```bash
NEW_MODULES=$(git diff --name-only ${SPRINT_BASE}..HEAD | grep -E 'stores/|composables/|pages/|server/api/' | head -20)
if [ -n "$NEW_MODULES" ]; then
  echo "New modules detected — running integration check"
fi
```
If detected, invoke `/blitz:review --only wiring all`. Map findings: wiring **high** → Review **Major**; **medium** → **Minor**; **low** → **Info**. Include in Phase 2 reviewer context.

---

## Phase 2: CODE REVIEW — Parallel Reviewer Agents

### 2.1 Prepare Review Context
```bash
git diff ${SPRINT_BASE}..HEAD > ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-full-diff.patch
git diff --stat ${SPRINT_BASE}..HEAD
```

### 2.2 Spawn Reviewer Agents via Agent Tool

#### 2.2.0 Strategy Selection

Default: parallel. Switch to sequential when `BLITZ_REVIEW_SEQUENTIAL=1` or `git diff --shortstat` LOC > 2000. Selection script + sequential-mode injection contract in `references/main.md` §"Reviewer Spawn Strategy".

#### 2.2.0-W Dispatch via Workflow (opt-in path)

Per [agent-orchestration.md](/_shared/agent-orchestration.md) capability gate (`BLITZ_DISPATCH`: `auto`/`workflow`/`agent`). When `USE_WORKFLOW` truthy AND `Workflow` tool available, dispatch reviewers + critic via native primitives; on ANY failure fall back to §2.2.1 (`Agent()`). Never hard-fail. Findings files + report synthesis stay in main-thread Bash (hybrid wrapper boundary); the script touches no filesystem.

```js
export const meta = { name: 'sprint-review', description: 'Parallel/sequential reviewers + adversarial critic', phases: [{ title: 'Review' }, { title: 'Critic' }] }
// args: { roster:[{name,prompt}], sequential:bool, criticPrompt, reviewerSchema, criticSchema }
let reviews
if (args.sequential) {
  // sequential: each reviewer receives all prior reviewers' findings (true chain, sequential accumulator)
  reviews = []
  let prior = []
  for (const a of args.roster) {
    const f = await agent(`${a.prompt}\n\nPrior findings:\n${JSON.stringify(prior)}`,
      { label: a.name, phase: 'Review', model: 'sonnet', schema: args.reviewerSchema })
    reviews.push(f)
    if (f) prior = [...prior, f]
  }
} else {
  // parallel (default): all reviewers concurrent
  reviews = await parallel(args.roster.map(a => () =>
    agent(a.prompt, { label: a.name, phase: 'Review', model: 'sonnet', schema: args.reviewerSchema })))
}
// Invariant 7: adversarial critic, schema-validated (replaces jq parse of LGTM|REJECT)
const critic = await agent(args.criticPrompt, { label: 'critic', phase: 'Critic', agentType: 'blitz:critic', schema: args.criticSchema })
return { reviews: reviews.map((f, i) => ({ name: args.roster[i]?.name, ok: f !== null, result: f })), critic }
```

- `model: 'sonnet'` per token-budget (explicit — prevents `[1m]` inheritance). Critic uses `agentType: 'blitz:critic'` so its system prompt loads; `schema` forces canonical `{verdict: LGTM|REJECT, ...}` and removes inline jq parsing.
- Each `a.prompt`/`criticPrompt` MUST embed the OUTPUT STYLE snippet (Invariant 5) + write-as-you-go rule.
- `null` reviewer entries = failures; apply the §2.4 N=4 gate (ABORT at `MISSING_COUNT >= 2`) against non-`null` count. A `null` critic → fall back to the §2.2.1 + Phase 3.6 Invariant 7 `Agent()` critic spawn (critic verdict is load-bearing; never silently skip).
- After the workflow returns, proceed to §2.4 (collect) → Phase 3 unchanged.

#### 2.2.1 Parallel Spawn (default)

Spawn 3-4 specialized reviewers in **a single assistant message** (concurrent). Each writes findings to session-scoped temp files. Per-spawn: `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: true`. Prompt from `references/main.md` "Reviewer Prompt Templates" with diff slice (max 500 lines), ACs, Phase 1 results. Weight class: Medium — max 15 reads, 25 tool calls, 300-line output, 5-min budget.

| Agent Name | Focus | Output File |
|---|---|---|
| `security-reviewer` | Auth, injection, XSS, CSRF, secrets | `${SESSION_TMP_DIR}/sprint-${N}-review-security.md` |
| `backend-reviewer` | API, error handling, validation, performance | `${SESSION_TMP_DIR}/sprint-${N}-review-backend.md` |
| `frontend-reviewer` | Components, accessibility, UX, state mgmt | `${SESSION_TMP_DIR}/sprint-${N}-review-frontend.md` |
| `pattern-reviewer` | Consistency, naming, DRY, architecture, test coverage | `${SESSION_TMP_DIR}/sprint-${N}-review-patterns.md` |

### 2.5 Cross-Cutting Findings

Orchestrator synthesizes during Phase 3: security `unvalidated input` → Backend; pattern component findings → Frontend; backend error-handling gaps → Frontend.

### 2.6 Collect Review Findings

Wait for all reviewers. **Run canonical Agent Output Contract validator** from [agent-orchestration.md](/_shared/agent-orchestration.md) §8 — classifies SUCCESS/PARTIAL/MALFORMED/EMPTY/MISSING/TIMEOUT, applies N=4 gate (ABORT at MISSING_COUNT ≥ 2). Do NOT redefine thresholds inline.

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-security.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-backend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-frontend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-patterns.md"
)
# Run validator from /_shared/agent-orchestration.md §8.
# A security-domain MISSING is particularly dangerous — if classify_output → MISSING for the
# security reviewer specifically, escalate the abort message: "SECURITY DOMAIN UNREVIEWED — sprint cannot close."
```

On SUCCESS: read output files, merge cross-findings (deduplicate by file+line). On PARTIAL: carry `PARTIAL` annotations into "Review Coverage Gaps" report section.

Severity categories:
- **Critical**: Security vulnerabilities, data loss risks, auth bypasses. MUST fix before merge.
- **Major**: Broken functionality, missing error handling, accessibility violations. Should fix.
- **Minor**: Code style, naming, minor performance. Fix if time permits.
- **Info**: Suggestions, alternatives, future improvements. Document only.

---

## Phase 2.5: BROWSER VERIFICATION (Required When Playwright Available)

Probe Playwright MCP availability. If unavailable: write `phase_2_5_coverage: skipped_unavailable` and proceed. If available: navigate changed routes; console errors → Critical/Error; placeholder data → Warning; broken layouts → Minor. Write `phase_2_5_coverage: full` on success. Probe script + smoke procedure in `references/main.md` §"Phase 2.5 Browser Verification".

---

## Phase 3: AUTO-FIX — Resolve Common Failures

### 3.1 Auto-Fix Scope

Auto-fix ONLY these categories. **Never auto-fix security issues** — those require human review.

| Category | Auto-Fix Strategy | Max Attempts |
|---|---|---|
| Type errors | Add missing types, fix type mismatches, add null checks | 3 |
| Lint errors | Apply lint auto-fix, then manual fixes for remaining | 3 |
| Missing exports | Add exports to barrel files (index.ts) | 3 |
| Import errors | Fix import paths, add missing imports | 3 |
| Naming inconsistencies | Rename to match project conventions | 2 |
| Missing return types | Add explicit return types to functions | 2 |
| Unused imports | Remove unused imports | 1 |
| Unused variables | Prefix with underscore or remove if safe | 1 |

### 3.2 Auto-Fix Loop

```
attempt = 0
while issue not resolved AND attempt < max_attempts:
    attempt += 1
    apply fix
    run relevant check (type-check, lint, or test)
    if check passes:
        commit: "fix(sprint-${N}/review): auto-fix <category> in <file>"
        mark resolved
    else:
        revert fix if it made things worse
        try alternative fix strategy
```

### 3.3 Fix Ordering

(1) missing imports/exports, (2) type errors, (3) lint errors (auto-fix first), (4) naming inconsistencies, (5) unused imports/variables.

### 3.4 Auto-Fix Boundaries

**DO NOT auto-fix:** security findings, logic errors, architecture issues, test assertion failures, performance issues. Document for human review.

### 3.5 Post-Fix Verification

Re-run full quality gate suite (type-check + lint + test + build). Record `type-errors=N, lint-errors=M, test-failures=P` before and after.

---

## Phase 3.6: REGISTRY INVARIANTS — Carry-Forward Hard Gate

**Hard gate**: failing any invariant fails the sprint close. Prevents silent scope drops by auditing the carry-forward registry against current sprint state.

Full invariant procedures (Invariants 1-4, hard-gate decision, report schema, escalation rules) in `references/main.md` §"Registry Invariants — Phase 3.6 Detailed Procedures". See also [sprint-contracts.md](/_shared/sprint-contracts.md) and `docs/_research/2026-04-08_sprint-carryforward-registry.md`.

1. Run canonical Reader Algorithm from [/_shared/sprint-contracts.md](/_shared/sprint-contracts.md) §Reader Algorithm with `MODE=review`. Consolidates Invariants 1, 2, 4 + rollover-ceiling escalation — exit 2 = INVARIANT FAILURE; exit 3 = ESCALATION; both block sprint close.
2. Run skill-local Invariants 3 and 5:
   - **Invariant 3**: every epic with `status: done|complete` has all registry entries at `status: complete`.
   - **Invariant 5**: every `skills/*/SKILL.md` AND every `skills/*/references/main.md` containing an Agent-prompt template contains the canonical `OUTPUT STYLE: … per /_shared/terse-output.md` snippet from `agent-orchestration.md` §7. Missing snippet → Critical finding → sprint FAILs (BLOCKER).
3. **Invariant 6** (ratchet — see [/_shared/quality-engine.md](/_shared/quality-engine.md)): read `docs/sweeps/ratchet.json`. Recompute each metric; verify direction. Regression without covering carry-forward → sprint cannot reach PASS. On improvement, tighten thresholds and append history snapshot.
4. **Invariant 7** (critic — see [/_shared/quality-engine.md](/_shared/quality-engine.md) and `agents/critic.md`): spawn `blitz:critic`. Returns `{verdict: "LGTM" | "REJECT", issues: [...]}`. REJECT blocks PASS.
5. **Invariant 8** (worktree branch hygiene — see [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md)): assert sprint-dev Phase 4.4 deleted every `sprint-${SPRINT_NUMBER}/{backend,frontend,tests,infra,integration}` branch. Any surviving match → FAIL. Resolution: `/blitz:worktree-prune --apply --merged-only`. Full procedure: `references/main.md` §Invariant 8 — Branch Hygiene.
5b. **Security-posture gate** (see [/_shared/security.md](/_shared/security.md)):
   ```bash
   bash hooks/scripts/check-registry-validate.sh          # security-pillar rows schema-valid
   bash hooks/scripts/startup-validate.sh --strict --quiet # persistent-state clean (TB-2); exit 2 = injection in .cc-sessions/
   # Capability grants (TB-4): every read-only agent's tool grant is justified
   grep -REn '^[[:space:]]*(eval|source|\.)[[:space:]]+' hooks/scripts/*.sh | grep -v '_lib/common.sh' \
     && echo "FAIL: pre-trust execution of project content" || true   # security.md invariant
   ```
   Any non-zero (injection in persistent state, hook executing project content) → CONDITIONAL at best. Semantic checks (`sec-content-inspection`) are advisory. Registry: `sec-startup-*`, `sec-content-inspection`, `sec-capability-grant`. Permanent security gate ([SYNTHESIS.md](../../docs/security/containment/SYNTHESIS.md) Epic 6).
6. Write Invariants Report section to review report.
7. **Hard gate**: Reader Algorithm exit 0 + Invariants 3, 5, 6, 7, 8 + security-posture gate pass → proceed to Phase 4. Any fail → `CONDITIONAL` at best; ESCALATION (exit 3), Invariant 5 fail, Invariant 8 fail, ratchet regression with no carry-forward, critic REJECT, or security-posture injection/pre-trust-execution → FAIL.

### Invariants 6 and 7 — Ratchet + Critic (BLOCKERs)

- **Invariant 6 (ratchet)**: see [`/_shared/quality-engine.md`](/_shared/quality-engine.md). Compute 8 monotonic metrics, compare to `docs/sweeps/ratchet.json`, tighten on improvement, block PASS on regression without covering carry-forward. `type_errors > 0` is an absolute floor. The 8th metric `stale_worktree_branch_count` (added 2026-05-17 per [worktree-lifecycle.md](/_shared/worktree-lifecycle.md)) requires existing projects to run `code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix debt. Full procedure: `references/main.md` §Invariant 6 — Ratchet Procedures.
- **Invariant 7 (critic)**: spawn `blitz:critic` (read-only adversarial — see `agents/critic.md`). Runs 20-detector shortcut scan + ratchet + hallucinated-symbol spot-check; returns canonical JSON `{verdict: LGTM | REJECT, ...}`. REJECT blocks PASS. Spawn template: `references/main.md` §Invariant 7 — Critic Spawn.

### Invariant 5 — Agent-Prompt Output Style Snippet (BLOCKER)

Pair enforcement for `agent-orchestration.md` §7. Canonical snippet:

```
OUTPUT STYLE: <intensity> per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

MUST appear in every `skills/*/references/main.md` containing an agent-prompt template (7 files: audit, codebase-map, code-sweep, quality-metrics, research, sprint-dev, sprint-plan). Missing snippet = Critical finding; sprint → **FAIL**.

Full Invariant 5 audit command detail: [references/main.md](references/main.md#invariant-5--audit-command).

---

## Phase 3.7: AUTOMATION COVERAGE — Declare Boundary

Per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P8/F4, declare deterministic-vs-human-judgment boundary in the report. Computes `DETERMINISTIC_PASSED/_TOTAL` from gates JSON, sets `REVIEW_RECOMMENDATION` to `auto-merge-safe` (all gates + Phase 2.5 `full` + zero critical/major) or `needs-human-review` otherwise. Full bash + heredoc + recommendation rules in `references/main.md` §"Automation Coverage Block".

---

## Phase 4: REPORT — Write Review Report and Update Registry

### 4.1 Write Review Report

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Tables preferred over prose. Executive Summary: 2-3 fragments. Recommendations: imperative bullets. Preserve verbatim: quality-gate table structure, severity prefixes, file paths, grep patterns, JSON invariant records. **LITE intensity** for: critical/major findings explanations, security/CVE details, root-cause sections, registry-invariant mismatch deltas. `full` intensity for info-level and cosmetic findings. Finding format: `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes (see S3-003 review-format absorption). If no findings in a severity bucket, write `LGTM` and stop.

Write `${SPRINT_DIR}/review-report.md` using template from references/main.md. Include:

1. **Executive Summary** — Sprint number, date, overall status (PASS/CONDITIONAL/FAIL).
2. **Quality Gates** — Pass/fail table for all automated checks (before and after auto-fix).
3. **Review Findings** — All findings from reviewer agents, grouped by severity.
4. **Auto-Fix Summary** — What was fixed, what remains, what was skipped.
5. **Story Status** — Table of all stories with final status.
6. **Recommendations** — Prioritized list of manual fixes needed before merge.

### 4.2 Determine Overall Status

| Status | Criteria |
|---|---|
| **PASS** | All quality gates pass. No critical or major findings. **All Phase 3.6 invariants 1–7 pass (registry, snippet, ratchet, critic LGTM).** |
| **CONDITIONAL** | Quality gates pass but major findings exist. Or: minor gate failures with no critical findings. Or: **any Phase 3.6 invariant fails** — sprint cannot reach PASS while registry, ratchet, or critic state is inconsistent. |
| **FAIL** | Any quality gate fails after auto-fix. Or: critical findings exist. Or: **a Phase 3.6 invariant failure escalates to `rollover_count >= 3`** on any entry and operator has not resolved it. Or: **critic verdict REJECT**. Or: **type_errors > 0 (absolute floor)**. |

### 4.3 Update Sprint Registry

**Registry Lock — `sprint-registry.json`**: Before writing, acquire file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md):
1. CHECK `sprint-registry.json.lock` — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, write registry.
5. RELEASE — delete `sprint-registry.json.lock`, append `lock_released` to operation log.

Update `sprint-registry.json`:
```json
{
  "number": <N>,
  "status": "reviewed",
  "review_date": "<ISO-8601>",
  "review_status": "PASS|CONDITIONAL|FAIL",
  "quality_gates": {
    "type_check": true,
    "lint": true,
    "tests": true,
    "build": true
  },
  "findings": {
    "critical": 0,
    "major": 2,
    "minor": 5,
    "info": 8
  },
  "auto_fixes_applied": 7,
  "stories_reviewed": 12,
  "stories_done": 10,
  "stories_incomplete": 1,
  "stories_blocked": 1
}
```

### 4.4 Shutdown Review Team

Send completion message to all reviewer agents and shutdown the team.

### 4.5 Git Commit
```bash
git add ${SPRINT_DIR}/review-report.md
git add sprint-registry.json
git commit -m "review(sprint-${N}): ${STATUS} — ${FINDINGS_CRITICAL}c/${FINDINGS_MAJOR}M/${FINDINGS_MINOR}m findings, ${AUTO_FIXES} auto-fixes"
```

### 4.5.5 Record Quality Metrics

```
Invoke: /blitz:quality-metrics collect
```
Stores timestamped JSON snapshot in `docs/metrics/` for trend tracking. Informational — does not gate the review.

### 4.6 Final Output and Error Recovery

Print summary block per `references/main.md` §"Final Output Template".

Next on PASS: `/blitz:ship` (or `/blitz:release` to cut a version).

**Inline recovery rules**:
- **Reviewer timeout/missing**: PARTIAL counts if ≥1 finding-file non-empty; escalate security-MISSING as blocker.
- **Auto-fix loop fails 3×**: abort auto-fix, document issues, fallback to manual-fix note in report. Append carry-forward `active` entry per [sprint-contracts.md](/_shared/sprint-contracts.md) (prevents CAP-133-class silent drop).
- **Lock conflict**: retry 3× with 20s backoff; abort with `BLOCK:` if unresolved.
- **No test runner found**: fallback to "SKIPPED" gate marker (not "FAIL").
- **Corrupt sprint artifacts**: recover with `/blitz:conform --fix`; retry review gate after.
- **Prior PASS re-run**: abort early ("already reviewed PASS — nothing to do"); do not overwrite.

## Gotchas

- Ratchet regression on any of the 8 monotonic metrics without a carry-forward entry → FAIL (Invariant 6; `type_errors > 0` is an absolute floor).
- Critic must emit LGTM (20-detector shortcut taxonomy) before PASS (Invariant 7).
- Undeleted per-sprint `sprint-N/{role}` branches → FAIL (Invariant 8).
- OUTPUT STYLE snippet must stay byte-identical (SHA-256) across every SKILL.md + agent template (Invariant 5) — never hand-edit the snippet block.
- Carry-forward Reader Algorithm inconsistency → FAIL (Invariant 1).
