---
name: audit
description: "Runs a 5-pillar recall audit (architecture, performance, security, maintainability, robustness) with paired agents plus registry checks, then writes docs/plans/audit-<date>/ as a paused task plan. Use for 'audit codebase', 'find tech debt', 'security audit', 'full code review', or before a release."
argument-hint: "[scope] [--pillar architecture|performance|security|maintainability|robustness|design] [--min-confidence low|high] [--dual] [--plan]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent
model: inherit
compatibility: ">=2.1.271"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort high. Set once (`claude --model opus --effort high` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.

<!-- import: from _shared/sessions.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For agent prompt templates, pillar checklists, severity schema, and report templates, see [references/main.md](references/main.md)
- For context window hygiene (10 parallel agents), see [sessions.md](/_shared/sessions.md)
- For the opt-in `Workflow` (dynamic-workflows) dispatch path + capability gate, see [agents.reference.md](/_shared/agents.reference.md) §7
- For the plan artifacts Phase 3 writes (`spec.md` frontmatter, `tasks.json`, `scripts/tasks.sh`), see [loop.md](/_shared/loop.md)
- For the check registry the deterministic lane and the security pillar select from, see [quality.reference.md](/_shared/quality.reference.md) §Shared check registry
<!-- import: from _shared/loop.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agents.md](/_shared/agents.md)
- For output style (terse-technical, preservation rules), see [/_shared/output.md](/_shared/output.md)

---

**Terse exemptions (LITE intensity):** security-pillar risk narratives. Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Codebase Audit Skill

Run a comprehensive 5-pillar code quality audit by spawning 10 parallel agents (8 when claude-security covers the security pillar, §1.2) and emit the findings as a paused plan under `docs/plans/audit-<date>/`. Execute every phase in order. Do NOT skip phases. ultrathink across pillar synthesis — the value of this audit is cross-pillar reasoning (e.g., security × performance trade-offs, maintainability × robustness tension) that single-pillar tools miss.

**Pillars**: Architecture, Performance, Security, Maintainability, Robustness

---

## Phase 0: SETUP — Prepare Audit Environment

### 0.0 Register Session

Follow [sessions.md](/_shared/sessions.md) §Session Registration (steps 1-9) and [output.md](/_shared/output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Create Working Directories

```bash
AUDIT_DIR="${SESSION_TMP_DIR}/audit"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
AUDIT_RUN="${AUDIT_DIR}/${TIMESTAMP}"
rm -rf "${AUDIT_DIR}"
mkdir -p "${AUDIT_RUN}/findings"
mkdir -p "${AUDIT_RUN}/reports"
```

### 0.2 Build Codebase Inventory

Writes the file/dir inventory every pillar agent reads instead of re-globbing. Commands and caps: [references/main.md](references/main.md) §0.2 Build Codebase Inventory.

### 0.3 Check for Previous Audits

Search the repo for existing audit reports:
```
Glob: **/audit-report*.md, **/audit/**/*.md
```
If found, note the date and key findings for comparison.

**Gate:** Inventory must contain at least 5 source files to audit. If the project is too small, inform user and suggest a manual review instead.

---

## Phase 1: SPAWN AUDIT AGENTS — Parallel Analysis

### 1.0 Select Dispatch Mode (capability gate)

`Agent()` pool by default; the `Workflow` path only when the capability gate passes. Gate: [references/main.md](references/main.md) §1.0 Select Dispatch Mode.

### 1.1-W Dispatch via Workflow (opt-in path)

Opt-in only; §1.1 is the default. Script contract: [references/main.md](references/main.md) §1.1-W Dispatch via Workflow.

### 1.1 Spawn 10 Pillar Agents via Agent Tool (default path)

Two independent same-scope agents per pillar, one `parallel()` barrier, findings written per agent to `${AUDIT_RUN}/findings/`. Roster, prompts and budgets: [references/main.md](references/main.md) §1.1 Spawn 10 Pillar Agents.

### 1.2 Security pillar: registry rows first, claude-security when installed

The `sec-*` registry rows run before any external scanner, and a scanner finding never overrides a row's verdict authority. Procedure: [references/main.md](references/main.md) §1.2 Security pillar.

### 1.3 Agent Prompt Construction

For each agent, construct the prompt using the template from `references/main.md`. The prompt MUST include:

1. **Role statement**: "You are a senior code auditor specializing in {PILLAR}."
2. **Scope definition**: "{SCOPE} — examine up to {FILE_CAP} files."
3. **Stack context**: The detected stack profile.
4. **Entry points**: Both passes in a pillar get the **full** pillar entry-point set from inventory (independent passes — the overlap is the basis for Phase 2.0 aggregation). Do NOT tell the two passes about each other.
5. **Checklist**: The pillar-specific audit checklist from `references/main.md`.
6. **Output format**: Findings must use the severity schema from `references/main.md`.
7. **Output path**: Absolute path to the agent's findings file.
8. **Write-as-you-go rule**: "Write each finding to your output file as you discover it. Do NOT accumulate findings in memory and write once at the end."

### 1.4 Wait for Completion

Poll for agent completion. Check each agent's output file:
```bash
for f in ${AUDIT_RUN}/findings/*.md; do
  [ -s "$f" ] && echo "DONE: $f" || echo "PENDING: $f"
done
```

**Timeout:** If any agent has not produced output after 5 minutes, mark it as failed and proceed.

---

### 1.5 Deterministic lane (run alongside the semantic passes)

The `det-*` and `check:*` rows the selection contract returns for this project's `stacks`, run alongside the pillar agents and read through each row's `detection.exit` contract. Selection and dispatch: [references/main.md](references/main.md) §1.5 Deterministic lane.

## Phase 2: COMPILE RESULTS — Consolidate Findings

### 2.1 Read All Findings

Read every file in `${AUDIT_RUN}/findings/`. For each file:
- Parse the findings (each finding has: severity, title, description, file, line, recommendation, **Confidence: 0-100**).
- If a file is empty or malformed, note the agent as failed.

### 2.1.4 Multi-Review aggregation (Phase 2.0)

Group semantic findings by (file, line-range, claim). A finding flagged by **≥2 independent same-scope passes → `confidence: high` (base 0.85)**; flagged once → `low` (0.50). This is the agreement signal the §1.1 roster (2 independent passes/pillar) exists to produce (SWRBench 2509.01494, +43.67% F1 — consistency across independent runs separates real issues from sporadic hallucinations). Deterministic-lane findings (`00-deterministic.md`) keep their own base_confidence (mechanism = verification). Detail: [references/main.md](references/main.md) §Recall hardening.

### 2.1.5 Confidence Threshold Filter

**Recall default (`--min-confidence low`): rank, do not drop.** The threshold only suppresses when precision is explicitly requested. Per `docs/research/2026-05-16_audit-agent-fp-prevention.md`.

```bash
THRESHOLD="${BLITZ_AUDIT_CONFIDENCE_THRESHOLD:-0}"   # 0 = recall (report all, ranked); raise (e.g. 80) for precision
# Rank findings by effective_confidence; drop only if Confidence < THRESHOLD.
# Refuted findings (fp_factor 0, §2.3.5) are ALWAYS dropped regardless of THRESHOLD.
# Findings missing Confidence: <0-100> field trigger detector #20 at critic stage
# (advisory; not auto-dropped — surface to user as "unscored finding" in the report).
```

Report shows: total findings parsed, findings filtered below threshold, findings missing confidence score (detector #20 trigger).

### 2.2 Handle Agent Failures

For each failed agent:
1. Log the failure in `${AUDIT_RUN}/reports/agent-failures.md`.
2. If fewer than 7 of 10 agents succeeded, warn the user that coverage is incomplete.
3. Do NOT retry — proceed with available findings.

### 2.3 Deduplicate Findings

Cross-agent deduplication:
- If two findings reference the same file and same line range, merge them.
- Keep the higher severity.
- Combine recommendations.

### 2.3.5 Adversarial FP-verify panel (Phase 2.5)

A read-only panel tries to falsify each surviving finding; one that cannot be reproduced is dropped, not downgraded. Panel contract: [references/main.md](references/main.md) §2.3.5 Adversarial FP-verify panel.

### 2.4 Classify and Sort

Group findings by pillar, then sort by severity within each pillar:
1. **Critical** — Security vulnerabilities, data loss risks, production blockers
2. **High** — Significant quality issues, performance bottlenecks
3. **Medium** — Code quality concerns, maintainability issues
4. **Low** — Suggestions, style improvements, minor optimizations

### 2.5 Generate Statistics

Calculate:
- Total findings per pillar
- Total findings per severity
- Files with most findings (top 10)
- Pillar health scores (0-100, based on finding density and severity)

### 2.6 Write Consolidated Report

Write `${AUDIT_RUN}/reports/audit-report.md` using the report template. Full report template detail: [references/main.md](references/main.md#consolidated-report-template-phase-26).

### 2.7 Copy Report to Project

Copies the run's report out of `${AUDIT_RUN}` into the project. Paths and naming: [references/main.md](references/main.md) §2.7 Copy Report to Project.

### 2.8 Coverage boundary (recall instrumentation, Phase 3.5)

Emit a required `coverage_boundary` block in the report — agents failed/timed-out, registry checks skipped (by `det-NN`/`sem-*` id), files over cap unread, lanes not run. A clean PASS with a large boundary is labeled "passed what we checked," never "passed everything." Detail: [references/main.md](references/main.md) §Recall hardening.

## Phase 3: EMIT TASKS — Findings Become a Paused Plan

Audit output the loop can execute: `docs/plans/audit-<YYYY-MM-DD>/{spec.md, tasks.json}` ([loop.md](/_shared/loop.md) §Artifacts). No separate index or registry file. `tasks.json` is written only through `scripts/tasks.sh` (a PreToolUse hook denies `Edit`/`Write` on it). Never arm `gate.json` here: `rm -f ".cc-sessions/sessions/${CLAUDE_SESSION_ID}/gate.json"`. Flag: `--plan` sets `AUDIT_PLAN_FLAG=1` (the plan is written `status: active` and `next --loop` picks it up on the next tick); default is `paused`.

### 3.1 Group Findings into Themes

Cluster surviving findings (post §2.3.5) into themes = one task each:
- Group by pillar + affected domain (e.g. "Security: auth middleware", "Performance: Firestore queries in `stores/`").
- A theme needs ≥2 findings, or 1 Critical finding.
- Order themes by impact = Σ(Critical 10, High 5, Medium 2, Low 1) descending; that order becomes `T-001…T-00N`.
- `files` = the union of every finding's cited paths in the theme (≤12; split the theme when larger).
- `role` from the files: `**/functions/**|**/server/**|**/api/**` → `backend`; `**/pages/**|**/components/**|**/stores/**` → `frontend`; rules/config/CI → `infra`; test-only → `test`.

### 3.2 Derive the Executable Check per Theme

Every task carries a `verify[]` check the loop can run without a human (tasks.sh refuses a task without one):

| Finding source | `--verify-cmd` |
|---|---|
| Deterministic lane (`det-NN`, `sec-*`, `fw-*`, `design-*`) | the registry row's `detection.command`, scoped to `files` |
| Semantic finding whose fix is the absence of a pattern | `grep_absent`: `! grep -rnE '<pattern>' <files>` |
| Semantic finding whose fix is the presence of a pattern | `grep -qE '<pattern>' <file>` (add `--test-only-ok` only when a test is the sole check) |
| Semantic finding with no pattern (design smell, "consider splitting", naming) | **no task** → note in `spec.md` §Out of scope |

Timeout suffix `::60` (`::300` for `tsc`/import-graph rows). Run each candidate command once before emitting: a check that already passes on the unfixed tree is not a check — pick another pattern or demote the theme to a note.

### 3.3 Write the Plan

Findings become a **paused** plan: `spec.md` + `tasks.json` written through `tasks.sh add`, every task carrying an executable `verify[]` derived in §3.2. Nothing is marked open for work until a human unpauses it. Field mapping and the paused-state contract: [references/main.md](references/main.md) §3.3 Write the Plan.

### 3.4 Final Output

Append `task_complete` to the activity feed (`skill: audit`, `detail.summary`), then print:

```
Codebase Audit Complete.
========================
Agents: <succeeded>/<N> succeeded (security: registry | claude-security)
Findings: <total> (Critical: N, High: N, Medium: N, Low: N) · unscored: N · below threshold: N
Coverage boundary: <one line>

Health Scorecard:
  Architecture:    XX/100
  Performance:     XX/100
  Security:        XX/100
  Maintainability: XX/100
  Robustness:      XX/100

Report: docs/audits/audit-YYYYMMDD.md
Plan:   docs/plans/audit-YYYY-MM-DD/  (spec.md status: paused|active, tasks.json: N tasks, M findings kept as notes)
Activate with: edit status: active in spec.md, then /blitz:next
```

With `--plan` the last line reads `Activated: /blitz:next` instead.

---

## Error Recovery

A failed pillar is retried once with the file cap halved; a second failure records the pillar as `cannot_verify` rather than dropping it silently. Full matrix: [references/main.md](references/main.md) §Error Recovery.

## Gotchas

- Spawns 10 parallel agents (8 when claude-security handles the security pillar); MISSING_COUNT ≥ threshold aborts (spawn-protocol §8 gate) — don't pass blank outputs as SUCCESS.
- Findings without 2-pass Multi-Review agreement are FP-prone; require convergence before reporting.
- Object-noun routing for "audit X": code→audit, deps/CVEs→`/blitz:dep-health`, Vue/Firestore/Pinia misuse→`/blitz:check --only framework`, cross-page UI→`/blitz:ui-audit`, a change or plan→`/blitz:check`. Registry entry-point table: [quality.md](/_shared/quality.md) §Which entry point.
- The plan is `paused` by default: `next --loop` ignores it until a human flips `status: active` (or the run used `--plan`). A finding without an executable check is a note, never a task — `tasks.sh` enforces it.
