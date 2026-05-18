---
name: sprint-review
description: "Reviews sprint quality with automated gates (type-check, lint, tests, build) and parallel reviewer agents (security, backend, frontend, patterns). Auto-fixes safe categories (types, lint, imports). Enforces the carry-forward registry hard gate (Phase 3.6 Invariants 1-8 — including ratchet, critic, and worktree branch hygiene). Use when the user says 'review sprint', 'check quality', 'run review', 'sprint quality gate', or 'audit sprint'."
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
- For story YAML schema (canonical, producer/consumer matrix), see [story-frontmatter.md](/_shared/story-frontmatter.md)
- For pipeline state contracts (which artifacts this skill produces and requires), see [state-handoff.md](/_shared/state-handoff.md)
- For review report template, reviewer checklists, and auto-fix strategies, see [references/main.md](references/main.md)
- For context window hygiene (reviewer agents), see [context-management.md](/_shared/context-management.md)
- For checkpoint awareness, see [checkpoint-protocol.md](/_shared/checkpoint-protocol.md)
- For handling reviewer agent escalations, see [deviation-protocol.md](/_shared/deviation-protocol.md)
- For the carry-forward registry (canonical Reader Algorithm enforced by Phase 3.6), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For subagent spawning, agent output contract (success/failure/partial thresholds), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, canonical exemptions), see [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

All auto-fix code must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations.

---

# Sprint Review Skill

Review sprint quality through automated checks and parallel reviewer agents. Run type-check, lint, tests, and build verification. Spawn specialized reviewers for security, backend, frontend, and patterns. Auto-fix common failures. Execute every phase in order. Do NOT skip phases.

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Hard-fail if required upstream artifacts missing per [state-handoff.md](/_shared/state-handoff.md): `sprint-registry.json`, `${SPRINT_DIR}/manifest.json`, `${SPRINT_DIR}/stories/S*.md`. Override (not recommended): `BLITZ_REVIEW_NO_MANIFEST=1`. Bash block in `references/main.md` §**Phase 0.0 Input Gate**.

## Phase 0: CONTEXT — Load Sprint State

0. **Register session.** Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch (agent spawn, wave completion, etc.) per verbose-progress.md.
1. **Find the sprint to review.** Read `sprint-registry.json` and find the sprint with `status: review` or `status: in-progress`. If the user specified a sprint number, use that. If no sprint is ready for review, inform the user and STOP.

1b. **Check for STATE.md.** If the sprint has a `STATE.md` checkpoint file, read it for context on blocked stories and their reasons. Include blocked story details in the review report. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).

2. **Load incomplete stories.** Read all story files in `${SPRINT_DIR}/stories/`. Categorize:
   - `done` — Implemented, ready for review.
   - `incomplete` — Partially done, flag for attention.
   - `blocked` — Skipped during implementation, note in report.

3. **Build codebase inventory.** `find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30`.

4. **Detect changed files + packages.**
   ```bash
   SPRINT_BASE=$(git log --oneline --all | grep -i "sprint-${SPRINT_NUMBER}" | tail -1 | cut -d' ' -f1)
   git diff --name-only ${SPRINT_BASE}..HEAD 2>/dev/null || git diff --name-only HEAD~20..HEAD
   ```
   From the changed files, determine which packages/workspaces were modified (see references/main.md for detection rules). Registry metadata already loaded in Phase 0.0.

**Gate:** At least one story must have `status: done` and changed files must be detectable.

---

## Phase 1: AUTOMATED CHECKS — Quality Gates

Run all automated checks. Record pass/fail for each. Do NOT stop on first failure — run all checks and collect all results.

### 1.1 Type-Check

```bash
# Detect type-check command from package.json scripts
npm run type-check 2>&1 || npx tsc --noEmit 2>&1
```

Record:
- Pass/Fail
- Error count
- Error list (file, line, message) for auto-fix phase

### 1.2 Lint

```bash
# Detect lint command from package.json scripts
npm run lint 2>&1 || npx eslint . 2>&1
```

Record:
- Pass/Fail
- Warning count, error count
- Error list for auto-fix phase

### 1.3 Unit Tests (Changed Packages Only)

Run tests only for changed packages to save time:

```bash
# For monorepo with workspaces
# Run tests in each changed package
for pkg in ${CHANGED_PACKAGES}; do
  (cd "$pkg" && npm run test 2>&1) || true
done

# For single-package projects
npm run test -- --changed 2>&1 || npm run test 2>&1
```

Record:
- Total tests, passed, failed, skipped
- Failure details (test name, file, assertion message)

### 1.4 Build Verification

```bash
npm run build 2>&1
```

Record:
- Pass/Fail
- Error details if failed

### 1.5 Quality Gate Summary

Write intermediate results to `${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-quality-gates.json`:
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

Scan all changed files for placeholder/mock code:
```bash
git diff --name-only ${SPRINT_BASE}..HEAD | xargs grep -n -E \
  '(TODO|FIXME|PLACEHOLDER|STUB|Not implemented|throw new Error.*implement|return \{\}|return \[\])' 2>/dev/null
```

Any matches are **Critical findings** — code is not production-ready. Record each match with file, line, and pattern.

### 1.5.2 Convention Compliance

Check changed files against project conventions:
- **Backend files**: Have auth/validation patterns? Use project's error format?
- **Frontend files**: Handle loading, empty, and error states (three-state pattern)?
- **Store actions**: Call real APIs (not returning hardcoded data)?
- **Test files**: Assert meaningfully (not just `toBeDefined()` or `expect(true).toBe(true)`)?

### 1.5.3 Architectural Compliance

Check for improper cross-layer imports:
- Frontend files should not import directly from server/functions directories
- Backend files should not import Vue components
- Test files should not import from other test files' internals

### 1.5.4 Completeness Check

- Verify all files listed in done stories actually exist
- Check for silently dropped circuit-breaker stories (stories that were blocked but not documented)

### 1.6 Integration Check (Conditional)

If the sprint introduced new modules, routes, stores, or API endpoints, run integration-check to validate cross-module wiring:

```bash
# Detect if sprint introduced new modules
NEW_MODULES=$(git diff --name-only ${SPRINT_BASE}..HEAD | grep -E 'stores/|composables/|pages/|server/api/' | head -20)
if [ -n "$NEW_MODULES" ]; then
  echo "New modules detected — running integration check"
fi
```

If new modules are detected, invoke `/blitz:integration-check all` and map findings to review severity levels:
- Integration-check **high** → Review **Major**
- Integration-check **medium** → Review **Minor**
- Integration-check **low** → Review **Info**

Include integration-check findings in the Phase 2 review context so reviewer agents are aware of wiring gaps.

---

## Phase 2: CODE REVIEW — Parallel Reviewer Agents

### 2.1 Prepare Review Context

Collect the diff for reviewers:
```bash
git diff ${SPRINT_BASE}..HEAD > ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-full-diff.patch
```

Also list all new and modified files with their sizes for assignment:
```bash
git diff --stat ${SPRINT_BASE}..HEAD
```

### 2.2 Spawn Reviewer Agents via Agent Tool

#### 2.2.0 Strategy selection — Parallel (default) or Sequential

Default parallel. Switch to sequential when `BLITZ_REVIEW_SEQUENTIAL=1` or `git diff --shortstat` LOC > 2000. Rationale: per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P2, sequential reviewers passing prior findings catch cross-cutting issues better on token-heavy reviews. Selection script + sequential-mode injection contract in `references/main.md` section **"Reviewer Spawn Strategy"**.

#### 2.2.1 Parallel Spawn (default mode)

Spawn 3-4 specialized reviewers using the `Agent` tool, all in **a single assistant message** so they run concurrently. Each writes findings to session-scoped temp files.

Per-spawn: `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: true`. Prompt from `references/main.md` "Reviewer Prompt Templates" with diff slice (max 500 lines), ACs, Phase 1 gate results. Weight class: Medium — max 15 reads, 25 tool calls, 300-line output, 5-min budget per reviewer.

| Agent Name | Focus | Output File |
|---|---|---|
| `security-reviewer` | Auth, injection, XSS, CSRF, secrets | `${SESSION_TMP_DIR}/sprint-${N}-review-security.md` |
| `backend-reviewer` | API, error handling, validation, performance | `${SESSION_TMP_DIR}/sprint-${N}-review-backend.md` |
| `frontend-reviewer` | Components, accessibility, UX, state mgmt | `${SESSION_TMP_DIR}/sprint-${N}-review-frontend.md` |
| `pattern-reviewer` | Consistency, naming, DRY, architecture, test coverage | `${SESSION_TMP_DIR}/sprint-${N}-review-patterns.md` |

### 2.5 Cross-Cutting Findings

Orchestrator synthesizes cross-cutting findings during Phase 3: security `unvalidated input` → Backend section; pattern component findings → Frontend section; backend error-handling gaps → Frontend section.

### 2.6 Collect Review Findings

Wait for all reviewers to complete. **Run the canonical Agent Output Contract validator** from [spawn-protocol.md](/_shared/spawn-protocol.md) §8 — it classifies SUCCESS / PARTIAL / MALFORMED / EMPTY / MISSING / TIMEOUT and applies the N=4 standard gate (ABORT at MISSING_COUNT ≥ 2). Do NOT redefine thresholds inline.

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-security.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-backend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-frontend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-patterns.md"
)
# Run validator from /_shared/spawn-protocol.md §8.
# A security-domain MISSING is particularly dangerous — if classify_output → MISSING for the
# security reviewer specifically, escalate the abort message: "SECURITY DOMAIN UNREVIEWED — sprint cannot close."
```

If all classifications resolve to SUCCESS (post any narrow retries per §8 PARTIAL retry policy), proceed. Carry forward `PARTIAL` annotations into the report's "Review Coverage Gaps" section.

If all files are present and non-empty: read their output files. Merge cross-findings (deduplicate by file+line).

Categorize all findings:
- **Critical**: Security vulnerabilities, data loss risks, auth bypasses. MUST fix before merge.
- **Major**: Broken functionality, missing error handling, accessibility violations. Should fix.
- **Minor**: Code style, naming, minor performance. Fix if time permits.
- **Info**: Suggestions, alternative approaches, future improvements. Document only.

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

For each fixable issue:

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

Fix in this order: (1) missing imports/exports, (2) type errors, (3) lint errors (auto-fix first), (4) naming inconsistencies, (5) unused imports/variables.

### 3.4 Auto-Fix Boundaries

**DO NOT auto-fix:** security findings, logic errors, architecture issues, test assertion failures, performance issues. Document for human review.

### 3.5 Post-Fix Verification

Re-run full quality gate suite (type-check + lint + test + build). Record `type-errors=N, lint-errors=M, test-failures=P` before and after.

---

## Phase 3.6: REGISTRY INVARIANTS — Carry-Forward Hard Gate

This phase is a **hard gate**: failing any invariant fails the sprint close. Its purpose is to make silent scope drops impossible by auditing the carry-forward registry against the current sprint's state.

Full invariant procedures (Invariants 1-4, the hard-gate decision, report schema, and escalation rules) are in `references/main.md` section **"Registry Invariants — Phase 3.6 Detailed Procedures"**. See also [carry-forward-registry.md](/_shared/carry-forward-registry.md) and `docs/_research/2026-04-08_sprint-carryforward-registry.md`.

**Outline**:
1. Run the canonical Reader Algorithm from [/_shared/carry-forward-registry.md](/_shared/carry-forward-registry.md) §Reader Algorithm with `MODE=review`. The algorithm consolidates Invariants 1, 2, 4 + rollover-ceiling escalation into one executable script — exit 2 = INVARIANT FAILURE; exit 3 = ESCALATION; both block sprint close.
2. Run skill-local Invariants 3 and 5 (not yet in the canonical algorithm):
   - **Invariant 3**: every epic claiming `status: done|complete` has all its registry entries at `status: complete`.
   - **Invariant 5**: every SKILL.md under `skills/*/SKILL.md` AND every `skills/*/references/main.md` containing an Agent-prompt template contains the canonical `OUTPUT STYLE: … per /_shared/terse-output.md` snippet from `spawn-protocol.md` §7. Missing snippet → Critical finding → sprint FAILs (BLOCKER).
3. Run **Invariant 6** (ratchet — see [/_shared/ratchet-protocol.md](/_shared/ratchet-protocol.md)): read `docs/sweeps/ratchet.json`. For each metric, recompute `current` and verify direction. If any metric regresses without a covering carry-forward entry, the sprint cannot reach PASS. On improvements, tighten thresholds and append a history snapshot.
4. Run **Invariant 7** (critic adversarial review — see [/_shared/shortcut-taxonomy.md](/_shared/shortcut-taxonomy.md) and `agents/critic.md`): spawn the `blitz:critic` agent. It returns `{verdict: "LGTM" | "REJECT", issues: [...]}`. REJECT verdict blocks PASS; the issues array describes the single reject reason.
5. Run **Invariant 8** (worktree branch hygiene — see [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md)): assert sprint-dev Phase 4.4 deleted every `sprint-${SPRINT_NUMBER}/{backend,frontend,tests,infra,integration}` branch. Any surviving match → FAIL. Resolution: `/blitz:worktree-prune --apply --merged-only`. Full procedure: `references/main.md` §Invariant 8 — Branch Hygiene.
6. Write the Invariants Report section to the review report.
7. **Hard gate**: Reader Algorithm exit 0 + Invariants 3, 5, 6, 7, 8 pass → proceed to Phase 4. Any fail → `CONDITIONAL` at best; ESCALATION (exit 3), Invariant 5 fail, Invariant 8 fail, ratchet regression with no carry-forward, or critic REJECT → FAIL.

### Invariants 6 and 7 — Ratchet + Critic (BLOCKERs)

- **Invariant 6 (ratchet)**: see [`/_shared/ratchet-protocol.md`](/_shared/ratchet-protocol.md). Compute the 8 monotonic metrics, compare to `docs/sweeps/ratchet.json`, tighten on improvement, block PASS on regression without covering carry-forward. `type_errors > 0` is an absolute floor. The 8th metric `stale_worktree_branch_count` (added 2026-05-17 per [worktree-lifecycle.md](/_shared/worktree-lifecycle.md)) requires existing projects to run `code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix debt. Full procedure: `references/main.md` §Invariant 6 — Ratchet Procedures.
- **Invariant 7 (critic)**: spawn `blitz:critic` (read-only adversarial — see `agents/critic.md`). It runs the 19-detector shortcut scan + ratchet + hallucinated-symbol spot-check and returns canonical JSON `{verdict: LGTM | REJECT, ...}`. REJECT blocks PASS. Spawn template: `references/main.md` §Invariant 7 — Critic Spawn.

### Invariant 5 — Agent-Prompt Output Style Snippet (BLOCKER)

Pair enforcement for `spawn-protocol.md` §7. The canonical snippet:

```
OUTPUT STYLE: <intensity> per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

MUST appear in every `skills/*/references/main.md` that contains an agent-prompt template (7 files as of Sprint 3: codebase-audit, codebase-map, code-sweep, integration-check, quality-metrics, sprint-dev, sprint-plan). Any missing snippet is a Critical finding; sprint status transitions to **FAIL**.

Audit command (sprint-review runs this in Phase 3.6 — covers SKILL.md AND references/main.md):

```bash
SNIPPET_RE='OUTPUT STYLE: (terse-technical|lite|full|ultra) per /_shared/terse-output.md'

# Every SKILL.md must include the snippet (Anthropic-canonical SKILL.md template requirement).
SKILL_TOTAL=$(ls skills/*/SKILL.md | wc -l)
SKILL_PRESENT=$(grep -lE "$SNIPPET_RE" skills/*/SKILL.md | wc -l)
[ "$SKILL_PRESENT" -eq "$SKILL_TOTAL" ] \
  || echo "Invariant 5 FAIL (SKILL.md): $SKILL_PRESENT / $SKILL_TOTAL contain canonical OUTPUT STYLE snippet"

# Every references/main.md that contains an Agent-prompt template must include the snippet.
REF_WITH_PROMPTS=$(grep -l "Agent Prompt Template\|prompt:" skills/*/references/main.md 2>/dev/null | wc -l)
REF_PRESENT=$(grep -lE "$SNIPPET_RE" skills/*/references/main.md 2>/dev/null | wc -l)
[ "$REF_PRESENT" -ge "$REF_WITH_PROMPTS" ] \
  || echo "Invariant 5 FAIL (references/main.md): $REF_PRESENT / $REF_WITH_PROMPTS contain canonical OUTPUT STYLE snippet"
```

The check is total-coverage on SKILL.md (no exemptions) and present-where-needed on references/main.md (only files with embedded agent prompts). Adding a new SKILL.md without the snippet auto-fails the next review.

---

## Phase 3.7: AUTOMATION COVERAGE — Declare Boundary

Per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P8/F4, declare the deterministic-vs-human-judgment boundary in the report. Prevents PASS-label over-confidence (F4 — passes checks but functionally unusable). Computes `DETERMINISTIC_PASSED/_TOTAL` from gates JSON, sets `REVIEW_RECOMMENDATION` to `auto-merge-safe` (all gates + Phase 2.5 `full` + zero critical/major) or `needs-human-review` otherwise. Full bash + heredoc + recommendation rules in `references/main.md` section **"Automation Coverage Block"**. Report template section in same file.

---

## Phase 4: REPORT — Write Review Report and Update Registry

### 4.1 Write Review Report

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Tables preferred over prose. Executive Summary: 2-3 fragments. Recommendations: imperative bullets. Preserve verbatim: quality-gate table structure, severity prefixes, file paths, grep patterns, JSON invariant records. **LITE intensity** (full sentences, reasoning-chain preserved) for: critical/major findings explanations, security/CVE details, root-cause sections, registry-invariant mismatch deltas. `full` intensity for info-level and cosmetic findings. Finding format: `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes (see S3-003 review-format absorption). If no findings in a severity bucket, write `LGTM` and stop — do not pad.

Write `${SPRINT_DIR}/review-report.md` using the template from references/main.md. Include:

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
| **CONDITIONAL** | Quality gates pass but major findings exist. Or: minor gate failures with no critical findings. Or: **any Phase 3.6 invariant fails** — the sprint cannot reach PASS while registry, ratchet, or critic state is inconsistent. |
| **FAIL** | Any quality gate fails after auto-fix. Or: critical findings exist. Or: **a Phase 3.6 invariant failure escalates to `rollover_count >= 3`** on any entry and the operator has not resolved it. Or: **critic verdict REJECT**. Or: **type_errors > 0 (absolute floor)**. |

### 4.3 Update Sprint Registry

**Registry Lock — `sprint-registry.json`**: Before writing, acquire a file-based lock per [session-protocol.md](/_shared/session-protocol.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `sprint-registry.json.lock` and append `lock_released` to the operation log.

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

After the review commit, collect a quality metrics snapshot for trend tracking:
```
Invoke: /blitz:quality-metrics collect
```
This stores a timestamped JSON snapshot in `docs/metrics/` that can be used for trend analysis across sprints. The metrics are informational and do not gate the review.

### 4.6 Final Output and Error Recovery

Print summary block per `references/main.md` §"Final Output Template".

**Inline recovery rules**:
- **Reviewer timeout/missing**: PARTIAL counts if ≥1 finding-file non-empty; escalate security-MISSING as blocker.
- **Auto-fix loop fails 3×**: abort auto-fix, document issues, fallback to manual-fix note in report. Append carry-forward `active` entry per [carry-forward-registry.md](/_shared/carry-forward-registry.md) so the issue is mandatory planning input next sprint (prevents CAP-133-class silent drop).
- **Lock conflict**: retry 3× with 20s backoff; abort with `BLOCK:` if unresolved.
- **No test runner found**: fallback to "SKIPPED" gate marker (not "FAIL").
- **Corrupt sprint artifacts**: recover with `/blitz:conform --fix`; retry review gate after.
- **Prior PASS re-run**: abort early ("already reviewed PASS — nothing to do"); do not overwrite.
