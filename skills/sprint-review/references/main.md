# Sprint Review Reference

Templates, checklists, rules for sprint-review skill.

---

## Review Report Template

```markdown
# Sprint ${SPRINT_NUMBER} Review Report

**Date:** ${DATE}
**Status:** ${PASS | CONDITIONAL | FAIL}
**Reviewer:** Automated + Agent Team

---

## Executive Summary

Sprint ${SPRINT_NUMBER} implemented ${STORIES_DONE}/${STORIES_TOTAL} stories across
${EPIC_COUNT} epics. ${SUMMARY_SENTENCE}.

---

## Quality Gates

| Gate | Before Auto-Fix | After Auto-Fix | Status |
|------|----------------|----------------|--------|
| Type-check | ${N} errors | ${N} errors | PASS/FAIL |
| Lint | ${N} errors, ${N} warnings | ${N} errors, ${N} warnings | PASS/FAIL |
| Unit Tests | ${N}/${N} passed | ${N}/${N} passed | PASS/FAIL |
| Build | PASS/FAIL | PASS/FAIL | PASS/FAIL |

---

## Review Findings

### Critical (Must Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 42 | Description of critical issue | security-reviewer |

### Major (Should Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 88 | Description of major issue | backend-reviewer |

### Minor (Optional Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 15 | Description of minor issue | pattern-reviewer |

### Info (Suggestions)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 30 | Suggestion for improvement | frontend-reviewer |

---

## Auto-Fix Summary

| Category | Found | Fixed | Remaining | Skipped |
|----------|-------|-------|-----------|---------|
| Type errors | ${N} | ${N} | ${N} | ${N} |
| Lint errors | ${N} | ${N} | ${N} | ${N} |
| Import fixes | ${N} | ${N} | ${N} | ${N} |
| Missing exports | ${N} | ${N} | ${N} | ${N} |
| Naming issues | ${N} | ${N} | ${N} | ${N} |
| **Total** | **${N}** | **${N}** | **${N}** | **${N}** |

---

## Story Status

| Story ID | Title | Agent | Status | Notes |
|----------|-------|-------|--------|-------|
| S${N}-001 | Story title | backend-dev | done | — |
| S${N}-002 | Story title | frontend-dev | done | Minor lint issue |
| S${N}-003 | Story title | test-writer | incomplete | 2 tests failing |

---

## Automation Coverage

**Deterministic gates passed:** ${DETERMINISTIC_PASSED}/${DETERMINISTIC_TOTAL}
(type-check, lint, tests, build, ratchet, shortcut-taxonomy, critic)

**Browser smoke (Phase 2.5):** ${full | partial | skipped_unavailable}

**NOT auto-verified — human-judgment review required:**
- Architectural fitness (right abstraction for the domain)
- UX correctness (does this make sense to a real user)
- Business-logic intent (does this do the right business thing)
- Cross-feature regressions in untested code paths

**Recommendation:** ${auto-merge-safe | needs-human-review}

> Deterministic gates passing does NOT verify architectural fit, UX, or business-logic intent. Human review owns those dimensions.

---

## Recommendations

### Before Merge (Required)
1. ${ACTION_ITEM}

### Before Next Sprint (Recommended)
1. ${ACTION_ITEM}

### Future Improvements (Optional)
1. ${ACTION_ITEM}
```

---

## Quality Gate Checklist

All automated quality gates with pass/fail criteria.

### Type-Check Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| TypeScript compilation | Zero errors (`tsc --noEmit` exits 0) | Any type error |
| Strict mode compliance | No `any` types introduced in new code | New `any` types without justification |
| Missing type exports | All public types exported from barrel files | Type used externally but not exported |

### Lint Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| ESLint errors | Zero errors | Any error (warnings are acceptable) |
| Auto-fixable issues | All auto-fixable issues resolved | Auto-fixable issues left unresolved |
| Custom rules | Project-specific rules pass | Project-specific rule violations |

### Test Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| Test execution | All tests run without crashes | Test runner crashes or hangs |
| Test pass rate | 100% pass (for changed packages) | Any test failure |
| Coverage (if configured) | No decrease in coverage | Coverage decreased |
| New code coverage | New files have at least one test | New files with zero tests |

### Build Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| Build completion | Build exits 0 | Build error |
| Bundle size (if configured) | Within configured limits | Exceeds limits |
| No runtime errors | Build output has no error markers | Build output contains errors |

---

## Auto-Fix Strategies by Error Category

### Type Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| `Type 'X' is not assignable to type 'Y'` | Add type assertion or fix the source type | `value as ExpectedType` or fix producer |
| `Property 'X' does not exist on type 'Y'` | Add property to interface or fix property name | Add to type definition |
| `Object is possibly 'undefined'` | Add null check or optional chaining | `obj?.property` or `if (obj) {}` |
| `Cannot find name 'X'` | Add missing import | `import { X } from './source'` |
| `Type 'X' is missing properties` | Add missing required properties | Add defaults or make optional |
| `Argument of type 'X' is not assignable` | Fix argument type or update parameter type | Match types at call site |
| `Cannot find module 'X'` | Fix import path or install package | Correct relative/absolute path |

### Lint Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| `no-unused-vars` | Remove or prefix with underscore | `_unusedVar` or delete |
| `no-unused-imports` | Remove the import statement | Delete line |
| `prefer-const` | Change `let` to `const` | `const x = ...` |
| `no-explicit-any` | Replace `any` with specific type | Infer type from usage |
| `eqeqeq` | Replace `==` with `===` | Strict equality |
| `no-console` | Remove console.log or wrap in debug check | Delete or `if (DEBUG)` |
| `quotes` / `semi` | Apply auto-fix | `eslint --fix` |
| `indent` / `max-len` | Apply auto-fix | `eslint --fix` |

### Import/Export Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| Missing export | Add to barrel file (index.ts) | `export { Thing } from './thing'` |
| Wrong import path | Fix relative or alias path | Correct to project convention |
| Circular import | Restructure — extract shared types to separate file | Move shared types to `types/` |
| Missing package | Check if it should be installed or is a typo | `npm install <pkg>` or fix name |
| Default vs named | Match export style | `import X` vs `import { X }` |

### Naming Inconsistencies

| Pattern | Detection | Fix |
|---|---|---|
| Component naming | Component file name != component name | Rename to match file |
| Variable casing | camelCase violation in JS/TS | Rename to camelCase |
| File naming | Inconsistent with sibling files | Rename to match convention |
| Type naming | PascalCase violation | Rename to PascalCase |
| Constant naming | UPPER_SNAKE_CASE violation for true constants | Rename appropriately |

---

## Changed Package Detection Rules

### Monorepo (Workspaces)

```bash
# 1. Get all changed files relative to sprint base
CHANGED_FILES=$(git diff --name-only ${SPRINT_BASE}..HEAD)

# 2. Read workspace config to get package paths
# For pnpm: pnpm-workspace.yaml -> packages field
# For npm: package.json -> workspaces field
# For nx: nx.json -> projects or workspace.json

# 3. Match changed files to packages
for file in $CHANGED_FILES; do
  for pkg in $WORKSPACE_PACKAGES; do
    if [[ "$file" == "$pkg/"* ]]; then
      CHANGED_PACKAGES+=("$pkg")
    fi
  done
done

# 4. Deduplicate
CHANGED_PACKAGES=($(echo "${CHANGED_PACKAGES[@]}" | tr ' ' '\n' | sort -u))
```

### Single Package

Non-monorepo: entire project is changed package. Run all checks at root.

### Detection Heuristics

| Config File | Workspace Detection Method |
|---|---|
| `pnpm-workspace.yaml` | Parse `packages:` array, expand globs |
| `package.json` (workspaces) | Parse `workspaces` array, expand globs |
| `nx.json` | Use `nx affected --plain` or parse `workspace.json` |
| `turbo.json` | Use `turbo run test --filter=...[${BASE}]` |
| `lerna.json` | Use `lerna changed --json` |
| None of above | Single package — check entire project |

### Scope Optimization

Run tests only for changed packages to save time:
```bash
# pnpm
pnpm --filter ...[$SPRINT_BASE] run test

# nx
nx affected --target=test --base=$SPRINT_BASE

# turbo
turbo run test --filter=...[${SPRINT_BASE}]

# fallback: run all tests
npm run test
```

---

## Review Finding Format

Reviewer agents must format findings consistently.

### Finding Schema

```markdown
### FINDING: <short-title>

- **File:** `<file-path>:<line-number>`
- **Severity:** critical | major | minor | info
- **Category:** security | correctness | performance | accessibility | style | architecture
- **Reviewer:** <agent-name>

**Description:**
<2-4 sentences explaining the issue, why it matters, and the potential impact.>

**Evidence:**
\`\`\`typescript
// The problematic code
<code snippet from the diff>
\`\`\`

**Recommendation:**
\`\`\`typescript
// Suggested fix
<corrected code>
\`\`\`

**Auto-fixable:** yes | no
**References:** <link to docs, OWASP rule, etc.>
```

### Reviewer Output Schema — Optional Instruction Gaps Section

At the **end** of every reviewer output file (after the last finding), append the optional section below. Empty entries are filtered by the orchestrator and never reach KNOWLEDGE.md — only non-empty Instruction Gaps survive. This creates a feedback channel from reviewer agents back to skill authors (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P7).

```markdown
## Instruction Gaps (optional)

Did any skill instruction in your prompt cause you to produce a suboptimal
finding, miss a real issue, or waste effort? Quote the instruction verbatim
and propose a rewording. Format (one per line):

`<verbatim instruction quote>` | <how it failed you> | <suggested rewording>

Leave empty if no gap. Do NOT pad with "no gaps to report."
```

Orchestrator post-processing (sprint-review Phase 4 after reading all reviewer files): for each non-empty Instruction Gaps line, append an entry to `.cc-sessions/KNOWLEDGE.md` under heading `## <DATE> · Skill Instruction Drift — <reviewer-role>` following the format in [knowledge-protocol.md](/_shared/knowledge-protocol.md) §1. Entries with empty `<suggested rewording>` are dropped (no value).

### Severity Guidelines

| Severity | Definition | Examples |
|---|---|---|
| **Critical** | Security vulnerability, data loss risk, auth bypass. Blocks merge. | SQL injection, exposed secrets, missing auth check, XSS |
| **Major** | Broken functionality, missing error handling, accessibility violation. | Unhandled promise rejection, missing form validation, no keyboard nav |
| **Minor** | Code quality, style, minor performance. Does not affect functionality. | Unnecessary re-renders, slightly wrong naming, missing JSDoc |
| **Info** | Suggestions for improvement. No current issue. | Alternative pattern suggestion, future optimization opportunity |

### Finding Format (mandatory terse line-level shape)

Each finding under the `### Critical`, `### Major`, `### Minor`, `### Info` sections MUST use caveman-review shape:

- **Single file:** `L<line>: <severity-prefix> <problem>. <fix>.`
- **Multi-file:** `<file>:L<line>: <severity-prefix> <problem>. <fix>.`

**Severity prefixes (one per finding):**

| Prefix | Severity | Meaning |
|---|---|---|
| `🔴 bug:` | Critical | Broken / incident-class / security-breach-class |
| `🟡 risk:` | Major | Fragile but works; likely-future-bug |
| `🔵 nit:` | Minor | Style / naming / small improvement |
| `❓ q:` | Info | Genuine question to author |

**LGTM rule:** If a severity bucket has zero findings, write `LGTM` under that heading and stop. Do NOT pad with "nothing to report", "no issues found", or similar filler.

**Auto-clarity exemption:** for security/CVE-class findings, architectural disagreements, or onboarding contexts, drop the terse one-liner and write full prose explanation with references (OWASP, RFCs, docs links). Resume terse format on the next finding.

**Drop from findings:** "I noticed", "It seems like", "You might want to consider", per-comment praise, restating what the line already does, general hedging.

**Keep:** exact line numbers, identifiers in backticks, concrete fix, "why" only when non-obvious.

Example:

```markdown
### Critical
L42: 🔴 bug: `verifyToken` never checks `exp` claim. Add `if (payload.exp < Date.now()/1000) throw`.

### Major
src/api/user.ts:L88: 🟡 risk: missing `await` on `saveUser()` loses write on error path. Add `await`.

### Minor
LGTM

### Info
L30: ❓ q: why `Map` over `Record<string, X>` here? Hot path?
```

### Reviewer-Specific Checklists

#### Security Reviewer

- [ ] No hardcoded secrets, API keys, or credentials in code
- [ ] All user input is validated and sanitized before use
- [ ] Authentication checks on all protected routes/endpoints
- [ ] Authorization checks (user can only access their own data)
- [ ] No SQL/NoSQL injection vectors
- [ ] No XSS vectors (user content is escaped before rendering)
- [ ] CSRF protection on state-changing endpoints
- [ ] Sensitive data not logged or exposed in error messages
- [ ] Dependencies have no known critical vulnerabilities
- [ ] File uploads validated (type, size, content)

#### Backend Reviewer

- [ ] API endpoints follow REST conventions (or project's convention)
- [ ] All async operations have error handling (try/catch or .catch())
- [ ] Input validation on all public functions and API handlers
- [ ] Consistent error response format
- [ ] Database queries are efficient (no N+1, proper indexing hints)
- [ ] Rate limiting considered for public endpoints
- [ ] Proper HTTP status codes used
- [ ] Transactions used for multi-step mutations
- [ ] Environment-specific config not hardcoded

#### Frontend Reviewer

- [ ] Components follow single-responsibility principle
- [ ] Proper loading and error states for async operations
- [ ] Forms have validation feedback visible to users
- [ ] Interactive elements are keyboard accessible
- [ ] ARIA attributes on dynamic content
- [ ] Responsive design works at standard breakpoints
- [ ] No layout shifts during loading
- [ ] Images have alt text
- [ ] Color contrast meets WCAG AA
- [ ] State management follows project patterns

#### Pattern Reviewer

- [ ] New code follows existing project naming conventions
- [ ] No code duplication (DRY) — reuses existing utilities
- [ ] Proper separation of concerns (business logic vs presentation)
- [ ] File organization matches project structure conventions
- [ ] Imports follow project conventions (aliases, barrel files)
- [ ] No TODO/FIXME/HACK without linked issue
- [ ] Test coverage exists for new public APIs
- [ ] Types are specific (no unnecessary `any` or `unknown`)
- [ ] Functions are reasonably sized (< 50 lines preferred)
- [ ] Comments explain "why" not "what"
- [ ] No placeholder/mock/stub implementations in production code
- [ ] No functions that return hardcoded data instead of calling services
- [ ] No empty function bodies that should have logic
- [ ] All features wired end-to-end (not just frontend or just backend)
- [ ] Circuit-breaker blocked stories are explicitly documented

---

## Registry Invariants — Phase 3.6 Detailed Procedures

**Hard gate**: failing any invariant fails sprint close. Makes silent scope drops impossible by auditing carry-forward registry against current sprint state. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for full protocol and `docs/_research/2026-04-08_sprint-carryforward-registry.md` for motivating incident.

### 3.6.1 Load the Registry

Reduce `.cc-sessions/carry-forward.jsonl` to latest-wins state:

```bash
REGISTRY=$(jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo '[]')
```

Load current sprint's manifest (`sprints/sprint-${SPRINT_NUMBER}/manifest.json`) and `sprint-registry.json`. Load `docs/roadmap/epic-registry.json` if exists. Identify every research doc referenced (directly or transitively) by any story, epic, or capability in this sprint — call this `SPRINT_RESEARCH_DOCS`.

### 3.6.2 Invariant 1 — Quantified Scope Has a Registry Entry

For every doc in `SPRINT_RESEARCH_DOCS`:

1. Scan doc's Summary, Findings, Recommendation sections for quantified language — regex `\d+\s+(files|components|modals|routes|tests|endpoints|pages|views|tables|migrations|fields|records)`.

2. If match found:
   - **Acceptable case A:** doc has `scope:` YAML frontmatter block covering the match, AND block's `id` exists in registry → pass.
   - **Acceptable case B:** match inside HTML comment `<!-- no-registry: <reason> -->` → pass.
   - **Failure case:** neither — **FAIL** this invariant. Print offending file and line range. Require author to either (a) add `scope:` block and re-run `/blitz:roadmap extend` before sprint close or (b) annotate line with `no-registry` comment and reason.

Record results as `invariant_1: {pass|fail, violations: [...]}` in report.

### 3.6.3 Invariant 2 — Active Entries Are Touched or Explicitly Deferred

For every registry entry with `status ∈ {active, partial}`:

- **Touched:** `last_touched.sprint == sprint-${SPRINT_NUMBER}` → pass.
- **Explicitly deferred:** latest line has `event: "deferred"` with non-empty `notes` AND written during this sprint → pass.
- **Waivered this sprint:** entry id in current manifest's `registry_entries_touched`, AND registry has matching `event: "auto_waived"` line dated within sprint → pass. Catches sprint-plan Phase 4.1 auto-waivers.
- **Otherwise:** **FAIL**. Increment `rollover_count` in new registry line:
  ```jsonl
  {"id":"<entry-id>","ts":"<ISO-8601>","event":"correction","rollover_count":<prev+1>,"notes":"sprint-review Invariant 2: entry not touched in sprint-${SPRINT_NUMBER}"}
  ```
  Require operator to (a) link story in this sprint that advanced the entry, (b) write `deferred` event with reason, or (c) write `dropped` event with `drop_reason` + `revival_candidate`.

**Waiver accounting sub-check:** cross-reference manifest `waived_ac_count > 0` against registry. For every sprint with waivers, MUST be at least one `event: "auto_waived"` line written during sprint for entry whose `parent.epic` appears in sprint manifest's `epics` array. Missing mirror → Invariant 2 failure.

**Rollover escalation:** if any entry crosses `rollover_count >= 3`, print loud escalation banner to stdout AND record entry as `blocker: rollover-escalation` in report. Entries no longer eligible for auto-inject in Invariant 4 — require mandatory human review before next sprint can plan around them. Prevents infinite `/loop` bouncing on stuck work.

### 3.6.4 Invariant 3 — Roadmap Completion Claims Match Registry Coverage

Read `docs/roadmap/roadmap-registry.json` and `docs/roadmap/tracker.md` (if exist); extract completion claims — typically "N/N epics complete" in registry JSON or completion column in tracker.

For every epic marked `status: done|complete` with non-empty `registry_entries` in epic registry:

- Every referenced registry id MUST have `status == complete` in latest-wins registry.
- Any mismatch → **FAIL** with precise delta:
  ```
  MISMATCH: Epic EPIC-105 claims status=done, but registry entry
    cf-2026-04-02-modal-consistency is status=partial at coverage=0.646
    (delivered 84/130 files). Registry is authoritative — either close
    the gap or revert the epic to status=in-progress.
  ```

Fix path: roll epic status back to `in-progress` OR write `dropped`/`deferred` event on offending entry with reason. Do NOT silently change registry entry to `complete` — that's the drop this mechanism prevents.

### 3.6.5 Invariant 4 — Auto-Inject Uncompleted Active Entries Into Next Sprint

For every registry entry with `status == active` AND `coverage < 1.0` AND `rollover_count < 3` (3+ escalated, see 3.6.3):

Write entry's id to `sprints/sprint-$((SPRINT_NUMBER + 1))-planning-inputs.json`:

```json
{
  "source_sprint": "sprint-${SPRINT_NUMBER}",
  "auto_injected": "<ISO-8601>",
  "reason": "Invariant 4 auto-inject from sprint-review",
  "mandatory_entries": [
    {
      "id": "cf-...",
      "parent": { "capability": "CAP-...", "epic": "EPIC-..." },
      "remaining_scope": { "unit": "files", "target": 130, "actual": 84 },
      "rollover_count": 1
    }
  ]
}
```

Next `sprint-plan` invocation reads this file in Phase 0 step 8 and must either (a) generate stories against each `mandatory_entries` item or (b) operator must explicitly `defer`/`drop` entry before planning runs. **Linear cycle semantics**: nothing silently falls out of view. See [carry-forward-registry.md](/_shared/carry-forward-registry.md).

Partial entries (`status == partial`) not auto-injected here — carry state forward via normal reader path (sprint-plan Phase 0 step 8 reads both active and partial entries). Only `active` with `coverage < 1.0` needs explicit file marker for visibility.

### 3.6.6 Invariants Report

Write invariants results to sprint review report under `## Registry Invariants` section. Include:

- Per-invariant pass/fail status
- Violations with file/entry references
- `rollover_count` updates
- Entries auto-injected into next sprint
- Escalations at `rollover_count >= 3`

**Hard gate decision:**

- **All four invariants pass** → Phase 3.6 passes, proceed to Phase 4 (Report) with `review_status` unchanged.
- **Any invariant fails** → Phase 3.6 fails. Sprint close transitions to `CONDITIONAL` at best (see Phase 4.2 overall status table); failing invariants listed under `Critical` findings. Sprint CANNOT be marked `PASS` while registry invariants failing. In `autonomy=full`, failures logged to activity feed and sprint marked `CONDITIONAL` — next `/loop` tick must address failures before proceeding.

---

## Final Output Template

Print summary to user:

```
Sprint ${SPRINT_NUMBER} Review Complete: ${STATUS}

Quality Gates:
  Type-check: PASS/FAIL (N errors)
  Lint:       PASS/FAIL (N errors, N warnings)
  Tests:      PASS/FAIL (N passed, N failed)
  Build:      PASS/FAIL

Findings:
  Critical: N (MUST fix before merge)
  Major:    N (should fix)
  Minor:    N (optional)
  Info:     N (suggestions)

Auto-Fixes Applied: N
  Type errors fixed: N
  Lint errors fixed: N
  Import fixes: N

Stories: N done, N incomplete, N blocked

Report: ${SPRINT_DIR}/review-report.md
Next: ${RECOMMENDED_ACTION}
```

`RECOMMENDED_ACTION`:
- PASS: "Ready to merge. Run `git merge sprint-${N}/merged` into main."
- CONDITIONAL: "Review major findings in report before merging."
- FAIL: "Fix critical issues before merging. See report for details."

---

## Error Recovery

- **Quality gate command not found**: Try alternatives (e.g., `npx tsc --noEmit` if `npm run type-check` fails). Skip gracefully if no equivalent, note in report.
- **Reviewer agent failure**: Retry once. If still failing, proceed with available reviews and note gap.
- **Auto-fix makes things worse**: Revert immediately via `git checkout -- <file>`. Move to next issue.
- **Git diff base not found**: Fall back to `HEAD~20` or ask user for base commit. *(If autonomy is `high` or `full`, use `HEAD~20` without prompting.)*

---

## Invariant 6 — Ratchet Procedures

Authoritative protocol: [`/_shared/ratchet-protocol.md`](/_shared/ratchet-protocol.md).

### Compute current values

```bash
RATCHET="docs/sweeps/ratchet.json"
[ -f "$RATCHET" ] || { echo "Invariant 6 SKIP: no ratchet.json (greenfield); bootstrap on first PASS"; exit 0; }

TEST_COUNT=$(grep -rcE '\b(it|test)\(' --include='*.test.*' --include='*.spec.*' . 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
TYPE_ERRORS=$(npx --no-install tsc --noEmit 2>&1 | grep -cE 'error TS' || echo 0)
AS_ANY=$(grep -rEn '\bas any\b' src/ --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ 2>/dev/null | wc -l)
LINT_VIOLATIONS=$(npx --no-install eslint --format=json . 2>/dev/null | jq '[.[].errorCount] | add // 0')
MOCKS_IN_SRC=$(grep -rEn '\b(vi\.mock|jest\.mock|sinon\.stub)\b' src/ --exclude-dir=__tests__ 2>/dev/null | wc -l)
TODO_COUNT=$(grep -rEn '\b(TODO|FIXME)\b' src/ 2>/dev/null | wc -l)
```

### Compare and act

For each metric:
- direction `down`, `current > max_allowed` AND no carry-forward entry covering it → REGRESSION → BLOCKER
- direction `up`, `current < min_allowed` AND no carry-forward entry → REGRESSION → BLOCKER
- direction `down`, `current < max_allowed` → IMPROVEMENT → tighten `max_allowed` to `current`, append history snapshot
- direction `up`, `current > min_allowed` → IMPROVEMENT → tighten `min_allowed` to `current`, append history snapshot

`type_errors > 0` is an absolute floor regardless of baseline — sprint FAILs.

### History snapshot format

Append to `docs/sweeps/ratchet.json -> history[]`. Never rewrite prior entries:

```json
{"sprint": "sprint-N", "ts": "2026-05-01T00:00:00Z", "metrics": {"test_count": 158, "type_errors": 0, "as_any_count": 2, "lint_violations": 5, "completeness_score": 94, "mocks_in_src": 3, "todo_count": 7}}
```

### Multi-agent worktree merge

When two parallel sprint-dev waves modify the ratchet, merge takes `min(max_allowed)` for ↓ metrics and `max(min_allowed)` for ↑ metrics. See [`/_shared/ratchet-protocol.md`](/_shared/ratchet-protocol.md) §4 for the canonical jq merge.

---

## Invariant 7 — Critic Spawn

Three execution modes, selected by env var:

| Env | Mode | Critic | Behaviour |
|---|---|---|---|
| (unset, default) | in-Claude | `blitz:critic` agent | Spawn Sonnet subagent. Cheapest. |
| `BLITZ_USE_GEMINI_CRITIC=1` | cross-model | `gemini` CLI via wrapper | Replace in-Claude critic with Gemini. Different blindspots (Cross-Model Critic per arxiv 2604.19049). |
| `BLITZ_DUAL_CRITIC=1` | dual-CMC | both | Run both; both must LGTM. Catches the blindspots either model has on its own work. Highest signal, ~2× cost. |

### Mode-resolution algorithm (run BEFORE spawning anything)

```bash
# Step 1: derive intended mode from env vars (DUAL_CRITIC takes precedence)
if [ "${BLITZ_DUAL_CRITIC:-0}" = "1" ]; then INTENDED=dual
elif [ "${BLITZ_USE_GEMINI_CRITIC:-0}" = "1" ]; then INTENDED=gemini
else INTENDED=claude; fi

# Step 2: probe whether critic-gemini.sh is reachable
GEMINI_SCRIPT="${CLAUDE_PLUGIN_ROOT}/hooks/scripts/critic-gemini.sh"
if [ "$INTENDED" != "claude" ] && [ ! -x "$GEMINI_SCRIPT" ]; then
  GEMINI_AVAILABLE=0
else
  GEMINI_AVAILABLE=1
fi

# Step 3: probe whether the gemini binary is reachable (if script is)
if [ "$GEMINI_AVAILABLE" = "1" ] && [ "$INTENDED" != "claude" ]; then
  command -v "${BLITZ_GEMINI_BIN:-gemini}" >/dev/null 2>&1 || GEMINI_AVAILABLE=0
fi

# Step 4: resolve the actual mode and emit ONE canonical line to stdout
case "$INTENDED:$GEMINI_AVAILABLE" in
  claude:*)         MODE=claude; echo "[critic] mode=claude (default in-Claude critic)" ;;
  gemini:1)         MODE=gemini; echo "[critic] mode=gemini-only (BLITZ_USE_GEMINI_CRITIC=1)" ;;
  dual:1)           MODE=dual;   echo "[critic] mode=dual-CMC (BLITZ_DUAL_CRITIC=1; in-Claude + Gemini, both must LGTM)" ;;
  gemini:0|dual:0)  MODE=claude; echo "[critic] mode=claude (FALLBACK: BLITZ_${INTENDED^^}_CRITIC=1 set but $([ -x \"$GEMINI_SCRIPT\" ] && echo 'gemini binary missing' || echo 'critic-gemini.sh missing — plugin <v1.11.0?'))" ;;
esac
```

**The orchestrator MUST emit exactly that bracketed `[critic] mode=...` line before spawning.** Do not improvise the message — earlier sessions hallucinated "critic-gemini.sh not installed in this plugin version" when both the script and the binary were present. The probe above is the source of truth.

### Default (in-Claude)

```
Agent({
  subagent_type: "blitz:critic",
  description: "Adversarial pre-PASS review",
  prompt: "Review sprint-${SPRINT_NUMBER}. Run the 8-checklist from agents/critic.md against the changes since ${SPRINT_BASE_SHA}. Reject if ANY of the 19 shortcut signals (skills/_shared/shortcut-taxonomy.md), ratchet regressions, type-error regressions, test deletions, or hallucinated-symbol findings are present. Return canonical JSON reply with verdict (LGTM | REJECT). Output style: terse-technical per /_shared/terse-output.md."
})
```

### Cross-model (Gemini)

```bash
# critic-gemini.sh lifts agents/critic.md body verbatim, appends a JSON-only
# directive, pipes to `gemini` CLI, validates and emits canonical JSON.
REPLY=$(${CLAUDE_PLUGIN_ROOT}/hooks/scripts/critic-gemini.sh \
          --mode pre-pass \
          --target "${SPRINT_BASE_SHA}")
GEMINI_RC=$?
```

Tunable via `BLITZ_GEMINI_BIN` (default `gemini`), `BLITZ_GEMINI_MODEL` (default `gemini-2.5-pro`), `BLITZ_GEMINI_FLAGS`. Requires `@google/gemini-cli` installed and authenticated.

### Dual-CMC (paired)

```bash
# Run both; require both LGTM. The first REJECT short-circuits to FAIL.
REPLY_CLAUDE=$(... Agent invocation as default ...)
REPLY_GEMINI=$(${CLAUDE_PLUGIN_ROOT}/hooks/scripts/critic-gemini.sh --mode pre-pass --target "$SPRINT_BASE_SHA")

VERDICT_CLAUDE=$(echo "$REPLY_CLAUDE" | jq -r '.verdict')
VERDICT_GEMINI=$(echo "$REPLY_GEMINI" | jq -r '.verdict')

if [ "$VERDICT_CLAUDE" = "LGTM" ] && [ "$VERDICT_GEMINI" = "LGTM" ]; then
  echo "Dual-CMC: both LGTM. Proceeding to PASS."
else
  echo "Dual-CMC: REJECT (claude=$VERDICT_CLAUDE, gemini=$VERDICT_GEMINI)"
  echo "$REPLY_CLAUDE" "$REPLY_GEMINI" | jq -s '.[].issues'
  exit 1
fi
```

### Reply parsing (single-critic modes)

```bash
VERDICT=$(echo "$REPLY" | jq -r '.verdict')
case "$VERDICT" in
  LGTM)   echo "Critic: LGTM. Proceeding to PASS." ;;
  REJECT) echo "Critic: REJECT. Issues:"; echo "$REPLY" | jq '.issues'; exit 1 ;;
  *)      echo "Critic: malformed reply (no verdict). Treating as REJECT."; exit 1 ;;
esac
```

REJECT verdict transitions sprint to FAIL. Re-run sprint-review after the issue is addressed by sprint-dev or the user.

---

## Reviewer Spawn Strategy

Phase 2.2.0 of `SKILL.md`. Selects parallel (default) vs sequential reviewer dispatch (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P2).

```bash
DIFF_LOC=$(git diff --shortstat ${SPRINT_BASE}..HEAD 2>/dev/null \
  | awk '{print ($4+0)+($6+0)}')
SEQUENTIAL_REVIEW=false
if [ "${BLITZ_REVIEW_SEQUENTIAL:-0}" = "1" ] || [ "${DIFF_LOC:-0}" -gt 2000 ]; then
  SEQUENTIAL_REVIEW=true
  echo "[sprint-review] sequential reviewer mode (diff=${DIFF_LOC} LOC, env=${BLITZ_REVIEW_SEQUENTIAL:-0})"
fi
```

**Sequential mode contract**: spawn reviewers one at a time in order (security → backend → frontend → patterns). After each reviewer completes, append findings to `${SESSION_TMP_DIR}/sprint-${N}-prior-findings.md`. Inject that file's contents into the NEXT reviewer's prompt under `## Prior Reviewer Findings (for cross-cutting awareness)`. Later reviewers may dedupe against prior findings.

**Parallel mode (default)**: continue with the existing single-message multi-spawn flow in Phase 2.2.1.

---

## Phase 2.5 Browser Verification

Phase 2.5.0 of `SKILL.md`. Required when Playwright MCP available; silent skip otherwise (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` F4).

```bash
PLAYWRIGHT_AVAILABLE=false
if grep -q 'mcp__plugin_playwright_playwright__browser_navigate' "${SESSION_TMP_DIR}/available-tools.txt" 2>/dev/null \
   || which playwright >/dev/null 2>&1; then
  PLAYWRIGHT_AVAILABLE=true
fi
echo "[sprint-review] playwright_available=${PLAYWRIGHT_AVAILABLE}"
```

Coverage tag values (write to gates JSON `phase_2_5_coverage`):

| Value | Condition |
|---|---|
| `skipped_unavailable` | `PLAYWRIGHT_AVAILABLE=false`. Not a failure. |
| `partial` | `PLAYWRIGHT_AVAILABLE=true` but smoke test skipped (other than "no changed routes"). Surface in Phase 4 Recommendations → Before Merge. |
| `full` | Smoke test completed across all changed routes. |

Smoke procedure: identify changed routes from changed page files. Navigate each via `mcp__plugin_playwright_playwright__browser_navigate`. For each page, check console errors (Critical/Error), placeholder/sample data visible (Warning), broken layouts (Minor). Add findings to review report.

---

## Automation Coverage Block

Phase 3.7 of `SKILL.md`. Declares deterministic-vs-human-judgment boundary (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P8/F4).

```bash
DETERMINISTIC_PASSED=0
DETERMINISTIC_TOTAL=0
for gate in type_check lint tests build ratchet shortcut_taxonomy critic; do
  DETERMINISTIC_TOTAL=$((DETERMINISTIC_TOTAL + 1))
  PASS=$(jq -r ".gates.${gate}.pass // false" "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-quality-gates.json")
  [ "$PASS" = "true" ] && DETERMINISTIC_PASSED=$((DETERMINISTIC_PASSED + 1))
done

cat <<EOF
Automation Coverage
===================
Deterministic gates: ${DETERMINISTIC_PASSED}/${DETERMINISTIC_TOTAL} passed
  - type-check, lint, tests, build, ratchet, shortcut-taxonomy, critic (LGTM)
Browser smoke (Phase 2.5): ${PHASE_2_5_COVERAGE:-skipped_unavailable}
Human-judgment review required (NOT auto-verified):
  - Architectural fitness (right abstraction for the domain)
  - UX correctness (does this make sense to a real user)
  - Business-logic intent (does this do the right business thing)
  - Cross-feature regressions in untested code paths
Recommendation: ${REVIEW_RECOMMENDATION}
EOF
```

`REVIEW_RECOMMENDATION` rules:

| Value | Triggered when |
|---|---|
| `auto-merge-safe` | ALL deterministic gates pass AND Phase 2.5 coverage = `full` AND zero critical/major findings. |
| `needs-human-review` | Any deterministic gate fails OR Phase 2.5 coverage = `partial` OR any critical/major findings exist. |

The PR may merge under `auto-merge-safe` for behavior correctness, but human reviewer still owns architecture/UX/business-intent judgment. Frame in the report as honest limitation, not a coverage claim.

The block is written into the review report under the `## Automation Coverage` section between `## Story Status` and `## Recommendations` (template above).

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
