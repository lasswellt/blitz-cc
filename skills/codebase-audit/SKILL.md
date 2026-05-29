---
name: codebase-audit
description: "Comprehensive 5-pillar code-quality audit (Architecture, Performance, Security, Maintainability, Robustness). Spawns 10 parallel agents (2 per pillar) for thorough analysis. Produces findings formatted for /blitz:roadmap and /blitz:sprint-plan ingestion. Use when the user says 'audit codebase', 'full code review', 'comprehensive quality audit', 'health of this codebase', 'find tech debt', 'security audit', or before a major release."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent
model: opus
effort: high
compatibility: ">=2.1.71"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For agent prompt templates, pillar checklists, severity schema, and report templates, see [references/main.md](references/main.md)
- For context window hygiene (10 parallel agents), see [context-management.md](/_shared/context-management.md)
- For the opt-in `Workflow` (dynamic-workflows) dispatch path + capability gate, see [workflow-dispatch.md](/_shared/workflow-dispatch.md)
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** security-pillar risk narratives. Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Codebase Audit Skill

Run a comprehensive 5-pillar code quality audit by spawning 10 parallel agents. Execute every phase in order. Do NOT skip phases. ultrathink across pillar synthesis — the value of this audit is cross-pillar reasoning (e.g., security × performance trade-offs, maintainability × robustness tension) that single-pillar tools miss.

**Pillars**: Architecture, Performance, Security, Maintainability, Robustness

---

## Phase 0: SETUP — Prepare Audit Environment

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Create Working Directories

```bash
AUDIT_DIR="${SESSION_TMP_DIR}/codebase-audit"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
AUDIT_RUN="${AUDIT_DIR}/${TIMESTAMP}"
rm -rf "${AUDIT_DIR}"
mkdir -p "${AUDIT_RUN}/findings"
mkdir -p "${AUDIT_RUN}/reports"
```

### 0.2 Build Codebase Inventory

1. **Identify project root and structure.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
2. **Read root config files.** Read `package.json`, workspace configs (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`), and framework configs (`nuxt.config.ts`, `vite.config.ts`, etc.).
3. **Map entry points.** Glob for:
   - Frontend: `**/pages/**/*.vue`, `**/views/**/*.vue`, `**/components/**/*.vue`, `**/composables/**/*.ts`, `**/stores/**/*.ts`, `**/router/**/*.ts`
   - Backend: `**/functions/**/*.ts`, `**/server/**/*.ts`, `**/api/**/*.ts`, `**/schemas/**/*.ts`
   - Config: `**/rules/**/*`, `**/*.rules`, `**/security*`, `**/middleware/**/*.ts`

4. **Count files per area.** Record approximate file counts for frontend, backend, config, and tests. This guides agent file caps.

5. **Write inventory file:**
   ```
   ${AUDIT_RUN}/inventory.json
   ```
   Schema:
   ```json
   {
     "timestamp": "<ISO-8601>",
     "root": "<project-root>",
     "stack": { "framework": "...", "ui": "...", "backend": "...", "build": "..." },
     "entry_points": {
       "frontend": ["<paths>"],
       "backend": ["<paths>"],
       "config": ["<paths>"]
     },
     "file_counts": { "frontend": 0, "backend": 0, "config": 0, "tests": 0 }
   }
   ```

### 0.3 Check for Previous Audits

Search the repo for existing audit reports:
```
Glob: **/audit-report*.md, **/codebase-audit/**/*.md
```
If found, note the date and key findings for comparison.

**Gate:** Inventory must contain at least 5 source files to audit. If the project is too small, inform user and suggest a manual review instead.

---

## Phase 1: SPAWN AUDIT AGENTS — Parallel Analysis

### 1.0 Select Dispatch Mode (capability gate)

Per [workflow-dispatch.md](/_shared/workflow-dispatch.md). Two dispatch paths produce identical findings files under `${AUDIT_RUN}/findings/`; only the orchestration mechanism differs. The 10-agent flat pool is the canonical `Workflow` pilot (no DAG, no worktree, no cross-session resume).

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;                 # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;                # auto: use Workflow iff tool present
esac
echo "[codebase-audit] dispatch=${BLITZ_DISPATCH:-auto} use_workflow=${USE_WORKFLOW}" >&2
```

- **`USE_WORKFLOW` truthy AND `Workflow` tool available** → §1.1-W (Workflow path).
- **else, or on ANY `Workflow` failure** → fall back to §1.1 (`Agent()` path). Never hard-fail.
- Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`.
- All filesystem I/O (Phase 0 inventory, Phase 2 report, ratchet.json, activity-feed) stays in this skill's main-thread Bash — the `Workflow` script touches none of it (hybrid wrapper boundary).

### 1.1-W Dispatch via Workflow (opt-in path)

Dispatch the 10 pillar agents as one `parallel()` with `schema:` validation. The script owns dispatch only; this skill collects the validated return + the agents' findings files in Phase 2 exactly as the `Agent()` path does.

```js
export const meta = { name: 'codebase-audit', description: '5-pillar audit, 2 agents/pillar', phases: [{ title: 'Audit' }] }
// ROSTER passed via args (agent name, pillar, scope, fileCap, outputPath, checklist, stack, inventory)
const findings = await parallel(args.roster.map(a => () =>
  agent(a.prompt, { label: a.name, phase: 'Audit', model: 'sonnet', schema: args.findingsSchema })))
return { agents: findings.map((f, i) => ({ name: args.roster[i].name, ok: f !== null, result: f })) }
```

- Each `a.prompt` is the pillar template from `references/main.md` — it MUST embed the OUTPUT STYLE snippet (Invariant 5) and the write-as-you-go rule (§1.3 step 8).
- `model: 'sonnet'` per token-budget routing (explicit — prevents `[1m]` inheritance).
- `schema` replaces the `classify_output()` gate; `null` entries = failed agents (handled by Phase 2.2).
- After the workflow returns, proceed to Phase 1.4 / Phase 2 unchanged.

### 1.1 Spawn 10 Pillar Agents via Agent Tool (default path)

Spawn all 10 agents using the `Agent` tool, all in **a single assistant message** so they execute concurrently.

Per-spawn parameters:
- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from Opus orchestrator)
- `description: codebase-audit <agent-name>`
- `prompt`: the pillar prompt template from `references/main.md`, filled per the roster below
- `run_in_background: true`

Cross-pillar findings synthesized by orchestrator in Phase 2 from output files (not peer-to-peer, per [spawn-protocol.md](/_shared/spawn-protocol.md)).

**Weight class**: Medium (per [spawn-protocol.md](/_shared/spawn-protocol.md)). File caps per pillar are specified in the roster below. Each agent prompt must also include: max 250-line output per pillar, 5-minute wall-clock budget, mandatory write-as-you-go (step 8 of prompt construction below).

Every agent receives:
1. The inventory JSON (inline, not a file path).
2. The stack profile from Phase 0.
3. Its specific pillar, scope, and file cap.
4. Its output file path under `${AUDIT_RUN}/findings/`.
5. The pillar-specific checklist from `references/main.md`.
6. Instructions to write findings incrementally (not all at the end).

**Agent Roster:**

| # | Agent Name | Pillar | Scope | File Cap | Output File |
|---|-----------|--------|-------|----------|-------------|
| 1 | `arch-frontend` | Architecture | Components, stores, composables, router, layouts | 12 | `findings/01-arch-frontend.md` |
| 2 | `arch-backend` | Architecture | Functions, schemas, packages, API routes, DB models | 12 | `findings/02-arch-backend.md` |
| 3 | `perf-frontend` | Performance | Re-renders, memory leaks, bundle size, lazy loading | 10 | `findings/03-perf-frontend.md` |
| 4 | `perf-backend` | Performance | Cold starts, DB queries, batch operations, caching | 10 | `findings/04-perf-backend.md` |
| 5 | `sec-rules` | Security | DB rules, storage rules, auth config, CORS, CSP | 8 | `findings/05-sec-rules.md` |
| 6 | `sec-code` | Security | XSS, auth middleware, input validation, secrets | 10 | `findings/06-sec-code.md` |
| 7 | `maint-frontend` | Maintainability | Naming, complexity, duplication, dead code | 12 | `findings/07-maint-frontend.md` |
| 8 | `maint-backend` | Maintainability | Type safety, consistency, error types, code reuse | 10 | `findings/08-maint-backend.md` |
| 9 | `robust-frontend` | Robustness | Error boundaries, user feedback, edge cases, offline | 10 | `findings/09-robust-frontend.md` |
| 10 | `robust-backend` | Robustness | Error handling, transactions, logging, retries | 10 | `findings/10-robust-backend.md` |

### 1.3 Agent Prompt Construction

For each agent, construct the prompt using the template from `references/main.md`. The prompt MUST include:

1. **Role statement**: "You are a senior code auditor specializing in {PILLAR}."
2. **Scope definition**: "{SCOPE} — examine up to {FILE_CAP} files."
3. **Stack context**: The detected stack profile.
4. **Entry points**: Relevant subset from inventory (frontend agents get frontend paths, backend agents get backend paths, security agents get both).
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

## Phase 2: COMPILE RESULTS — Consolidate Findings

### 2.1 Read All Findings

Read every file in `${AUDIT_RUN}/findings/`. For each file:
- Parse the findings (each finding has: severity, title, description, file, line, recommendation, **Confidence: 0-100**).
- If a file is empty or malformed, note the agent as failed.

### 2.1.5 Confidence Threshold Filter

Filter findings below confidence threshold (default 80) before deduplication. Mirrors Anthropic Code Review Plugin pattern; per `docs/_research/2026-05-16_audit-agent-fp-prevention.md`.

```bash
THRESHOLD="${BLITZ_AUDIT_CONFIDENCE_THRESHOLD:-80}"
# For each finding parsed, drop if Confidence < THRESHOLD.
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

Write `${AUDIT_RUN}/reports/audit-report.md` using the report template from `references/main.md`:

```markdown
# Codebase Audit Report
**Date**: <ISO-8601>
**Stack**: <detected stack>
**Files Analyzed**: <count>
**Agents Succeeded**: <N>/10

## Executive Summary
<2-3 sentence overview with overall health score>

## Health Scorecard
| Pillar | Score | Critical | High | Medium | Low |
|--------|-------|----------|------|--------|-----|
| Architecture | XX/100 | N | N | N | N |
| Performance | XX/100 | N | N | N | N |
| Security | XX/100 | N | N | N | N |
| Maintainability | XX/100 | N | N | N | N |
| Robustness | XX/100 | N | N | N | N |

## Critical Findings
<list all Critical severity findings>

## Findings by Pillar
### Architecture
<findings sorted by severity>

### Performance
...

### Security
...

### Maintainability
...

### Robustness
...

## Hotspot Files
<top 10 files with most findings>

## Recommended Actions
<prioritized list of what to fix first>
```

### 2.7 Copy Report to Project

Copy the consolidated report into the project:
```bash
REPORT_DIR="docs/audits"
mkdir -p "${REPORT_DIR}"
cp "${AUDIT_RUN}/reports/audit-report.md" "${REPORT_DIR}/audit-$(date +%Y%m%d).md"
```

---

## Phase 3: ROADMAP INTEGRATION — Convert Findings to Epics

### 3.1 Group Findings into Themes

Cluster related findings into themes. A theme maps to a potential epic:
- Group by: pillar + affected domain (e.g., "Security: Auth Middleware" or "Performance: Database Queries")
- A theme needs at least 2 findings to justify an epic.
- Singleton critical findings get their own theme.

### 3.2 Score and Prioritize Themes

For each theme, calculate:
- **Impact score** = sum of (Critical: 10, High: 5, Medium: 2, Low: 1) across findings
- **Effort estimate** = Small (1-3 files), Medium (4-8 files), Large (9+ files)
- **Priority** = Impact / Effort (higher = do first)

Sort themes by priority descending.

### 3.3 Generate Proposed Epics

For each theme, write a proposed epic using the format from `references/main.md`:

```markdown
## PROPOSED EPIC: <theme-name>

**Pillar**: <pillar>
**Priority**: <priority-score>
**Impact**: <impact-score>
**Effort**: <Small|Medium|Large>
**Findings**: <count> (<critical>C / <high>H / <medium>M / <low>L)

### Description
<2-3 sentences describing what this epic addresses>

### Key Findings
<bulleted list of the most important findings in this theme>

### Proposed Stories
<numbered list of implementation stories that would resolve the findings>

### Success Criteria
<measurable criteria for when this epic is "done">

### Dependencies
<other epics or external factors this depends on>
```

### 3.3a Emit `scope:` YAML frontmatter on `-epics.md`

Every `audit-YYYYMMDD-epics.md` file MUST open with a `scope:` YAML frontmatter block above the `# Proposed Epics` heading. One entry per non-`complete` `proposed_epics[]` item. This is the canonical contract for `/blitz:roadmap extend` ingestion — see [/_shared/carry-forward-registry.md](/_shared/carry-forward-registry.md) §Writers.

Skip emission for any epic whose `status: "complete"` (idempotent reruns of `codebase-audit` MUST NOT duplicate registry entries on already-shipped work).

Per-entry shape:
- `id`: `cf-${AUDIT_DATE}-${EPIC_ID_LOWER}` (e.g., `cf-2026-05-18-epic-a01`)
- `unit`: `epics`
- `target`: `1`
- `description`: theme + pillar + finding_count + effort. If `defer_reason` is set, prepend it. If `multi_sprint: true`, append "Multi-sprint (estimate: ${sprint_estimate})."
- `acceptance`: each entry in the epic's `success_criteria` becomes one `shell:` acceptance check, OR `grep_absent:` / `grep_present:` when the criterion clearly maps to a grep pattern.

Sample:

```yaml
---
scope:
  - id: cf-2026-05-18-epic-a01
    unit: epics
    target: 1
    description: |
      Hook performance — async + scope guards.
      Performance (primary), Robustness (secondary). 8 findings. Effort: Small.
    acceptance:
      - shell: "grep -q '\"async\": true' hooks/hooks.json"
      - shell: "test -x hooks/scripts/post-edit-typecheck-block.sh"
---
# Proposed Epics — Audit 2026-05-18

Source: `docs/audits/audit-2026-05-18.md`. ...
```

After ingestion via `/blitz:roadmap extend`, set each epic's `ingested_at` field in the companion `audit-YYYYMMDD-index.json` to the current ISO-8601. This signals to subsequent audit runs (and `/blitz:next` Phase 0.9b) that the epic has been registered.

### 3.4 Write Epic Proposals

Write all proposed epics to:
```
${REPORT_DIR}/audit-$(date +%Y%m%d)-epics.md
```

The emitter MUST populate every field documented in Phase 3.5 schema on EVERY epic, including the 6 backward-compat fields: `id` (carried verbatim from the epic generated in Phase 3.3), `status: "proposed"`, `defer_reason: null`, `multi_sprint: false`, `sprint_estimate: null`, `ingested_at: null`. The operator may hand-edit `status: "deferred"` + `defer_reason: "..."` post-emission to signal items not to sprintify; consumers (`/blitz:roadmap extend`, `/blitz:next` Phase 0.9b) MUST tolerate older index files missing these fields by defaulting to the values above.

### 3.5 Write Machine-Readable Index

Write a JSON index for consumption by the roadmap skill:
```
${REPORT_DIR}/audit-$(date +%Y%m%d)-index.json
```
Schema:
```json
{
  "audit_date": "<ISO-8601>",
  "proposed_epics": [
    {
      "id": "<EPIC-A...>",
      "theme": "<theme-name>",
      "pillar": "<pillar>",
      "priority": 0,
      "impact": 0,
      "effort": "<Small|Medium|Large>",
      "finding_count": 0,
      "severity_breakdown": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
      "proposed_stories": ["<story descriptions>"],
      "success_criteria": ["<criteria>"],
      "status": "proposed",
      "defer_reason": null,
      "multi_sprint": false,
      "sprint_estimate": null,
      "ingested_at": null
    }
  ]
}
```

**Backward-compat defaults** (consumers MUST tolerate omitted fields by defaulting):
- `id` — stable string key, format `EPIC-A<NN>`. Required for `/blitz:next` Phase 0.9b cross-reference.
- `status` — defaults to `"proposed"`. Enum: `proposed | deferred | active | complete`. Drives `/blitz:next` row 6e detection.
- `defer_reason` — defaults to `null`. Free-form string when `status: "deferred"`.
- `multi_sprint` — defaults to `false`. Operator-set boolean; signals work spans multiple sprints (orthogonal to `effort` — a 6-file refactor across 3 sprints sets `multi_sprint: true` + `sprint_estimate: 3` even when `effort: Medium`).
- `sprint_estimate` — defaults to `null`. Integer count of sprints the operator expects to complete this epic.
- `ingested_at` — defaults to `null`. ISO-8601 timestamp set by `/blitz:roadmap extend` after registry ingestion.

### 3.6 Final Output

Print a summary to the user:

```
Codebase Audit Complete.
========================
Agents: <succeeded>/10 succeeded
Findings: <total> (Critical: N, High: N, Medium: N, Low: N)
Proposed Epics: <count>

Health Scorecard:
  Architecture:    XX/100
  Performance:     XX/100
  Security:        XX/100
  Maintainability: XX/100
  Robustness:      XX/100

Report: docs/audits/audit-YYYYMMDD.md
Epics:  docs/audits/audit-YYYYMMDD-epics.md
Index:  docs/audits/audit-YYYYMMDD-index.json
```

---

## Error Recovery

- **Too few source files**: Inform user the codebase is too small for a full audit. Suggest manual review.
- **No frontend files found**: Skip frontend agents (1, 3, 7, 9). Spawn only backend/security agents.
- **No backend files found**: Skip backend agents (2, 4, 8, 10). Spawn only frontend/security agents.
- **Agent timeout**: Mark as failed, proceed with available findings. Note gaps in report.
- **All agents failed**: Abort and report the failure. Suggest checking stack detection and file permissions.
- **Existing audit found**: Load previous findings for comparison. Include a "Delta" section in the report showing improvements and regressions.
