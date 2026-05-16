---
name: codebase-audit
description: "Comprehensive 5-pillar code-quality audit (Architecture, Performance, Security, Maintainability, Robustness). Spawns 10 parallel agents (2 per pillar) for thorough analysis. Produces findings formatted for /blitz:roadmap and /blitz:sprint-plan ingestion. Use when the user says 'audit codebase', 'full code review', 'comprehensive quality audit', 'health of this codebase', 'find tech debt', 'security audit', or before a major release."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent
model: opus
effort: high
compatibility: ">=2.1.71"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For agent prompt templates, pillar checklists, severity schema, and report templates, see [references/main.md](references/main.md)
- For context window hygiene (10 parallel agents), see [context-management.md](/_shared/context-management.md)
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** security-pillar risk narratives. Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Codebase Audit Skill

Run a comprehensive 5-pillar code quality audit by spawning 10 parallel agents. Execute every phase in order. Do NOT skip phases.

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

### 1.1 Spawn 10 Pillar Agents via Agent Tool

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

### 3.4 Write Epic Proposals

Write all proposed epics to:
```
${REPORT_DIR}/audit-$(date +%Y%m%d)-epics.md
```

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
      "theme": "<theme-name>",
      "pillar": "<pillar>",
      "priority": 0,
      "impact": 0,
      "effort": "<Small|Medium|Large>",
      "finding_count": 0,
      "severity_breakdown": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
      "proposed_stories": ["<story descriptions>"],
      "success_criteria": ["<criteria>"]
    }
  ]
}
```

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
