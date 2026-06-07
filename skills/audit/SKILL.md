---
name: audit
description: "Comprehensive 5-pillar code-quality audit (Architecture, Performance, Security, Maintainability, Robustness): 10 parallel agents (2 same-scope passes/pillar, Multi-Review). Findings feed /blitz:roadmap + /blitz:sprint-plan. Use for 'audit codebase', 'full code review', 'find tech debt', 'security audit', or before a release. Object-noun routing for 'audit X': code→audit, dependencies/CVEs→/blitz:dep-health, Firestore/Vue/Pinia→/blitz:code-doctor, cross-page UI→/blitz:ui-audit, sprint→/blitz:sprint-review. Bare 'audit'→/blitz:ask."
argument-hint: "[scope] [--pillar architecture|performance|security|maintainability|robustness|design] [--min-confidence low|high] [--dual]"
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
- For context window hygiene (10 parallel agents), see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For the opt-in `Workflow` (dynamic-workflows) dispatch path + capability gate, see [agent-orchestration.md](/_shared/agent-orchestration.md)
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agent-orchestration.md](/_shared/agent-orchestration.md)
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

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

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
Glob: **/audit-report*.md, **/audit/**/*.md
```
If found, note the date and key findings for comparison.

**Gate:** Inventory must contain at least 5 source files to audit. If the project is too small, inform user and suggest a manual review instead.

---

## Phase 1: SPAWN AUDIT AGENTS — Parallel Analysis

### 1.0 Select Dispatch Mode (capability gate)

Per [agent-orchestration.md](/_shared/agent-orchestration.md). Two dispatch paths produce identical findings files under `${AUDIT_RUN}/findings/`; only the orchestration mechanism differs. The 10-agent flat pool is the canonical `Workflow` pilot (no DAG, no worktree, no cross-session resume).

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;                 # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;                # auto: use Workflow iff tool present
esac
echo "[audit] dispatch=${BLITZ_DISPATCH:-auto} use_workflow=${USE_WORKFLOW}" >&2
```

- **`USE_WORKFLOW` truthy AND `Workflow` tool available** → §1.1-W (Workflow path).
- **else, or on ANY `Workflow` failure** → fall back to §1.1 (`Agent()` path). Never hard-fail.
- Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`.
- All filesystem I/O (Phase 0 inventory, Phase 2 report, ratchet.json, activity-feed) stays in this skill's main-thread Bash — the `Workflow` script touches none of it (hybrid wrapper boundary).

### 1.1-W Dispatch via Workflow (opt-in path)

Dispatch the 10 pillar agents as one `parallel()` with `schema:` validation. The script owns dispatch only; this skill collects the validated return + the agents' findings files in Phase 2 exactly as the `Agent()` path does.

```js
export const meta = { name: 'audit', description: '5-pillar audit, 2 independent same-scope agents/pillar (Multi-Review)', phases: [{ title: 'Audit' }] }
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
- `description: audit <agent-name>`
- `prompt`: the pillar prompt template from `references/main.md`, filled per the roster below
- `run_in_background: true`

Cross-pillar findings synthesized by orchestrator in Phase 2 from output files (not peer-to-peer, per [agent-orchestration.md](/_shared/agent-orchestration.md)).

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)). File caps per pillar are specified in the roster below. Each agent prompt must also include: max 250-line output per pillar, 5-minute wall-clock budget, mandatory write-as-you-go (step 8 of prompt construction below).

Every agent receives:
1. The inventory JSON (inline, not a file path).
2. The stack profile from Phase 0.
3. Its specific pillar, scope, and file cap.
4. Its output file path under `${AUDIT_RUN}/findings/`.
5. The pillar-specific checklist from `references/main.md`.
6. Instructions to write findings incrementally (not all at the end).

**Agent Roster:**

**2 independent same-scope passes per pillar** — both agents in a pillar audit the *full* pillar surface independently (not a frontend/backend split). Their overlap is the agreement signal Phase 2.0 aggregates: a finding both passes flag is high-confidence; one-pass findings are low-confidence. (Distinct breadth is recovered by aggregation across the two passes + the deterministic lane, §1.5.)

| # | Agent Name | Pillar | Scope (full pillar — independent pass) | File Cap | Output File |
|---|-----------|--------|-------|----------|-------------|
| 1 | `arch-a` | Architecture | Components/stores/composables/router/layouts + functions/schemas/API/DB models | 14 | `findings/01-arch-a.md` |
| 2 | `arch-b` | Architecture | (same scope as `arch-a` — independent pass) | 14 | `findings/02-arch-b.md` |
| 3 | `perf-a` | Performance | Re-renders/memory/bundle/lazy + cold-starts/DB queries/batch/caching | 12 | `findings/03-perf-a.md` |
| 4 | `perf-b` | Performance | (same scope as `perf-a` — independent pass) | 12 | `findings/04-perf-b.md` |
| 5 | `sec-a` | Security | DB/storage rules, auth/CORS/CSP + XSS/middleware/input-validation/secrets | 12 | `findings/05-sec-a.md` |
| 6 | `sec-b` | Security | (same scope as `sec-a` — independent pass) | 12 | `findings/06-sec-b.md` |
| 7 | `maint-a` | Maintainability | Naming/complexity/duplication/dead-code + type-safety/consistency/error-types/reuse | 14 | `findings/07-maint-a.md` |
| 8 | `maint-b` | Maintainability | (same scope as `maint-a` — independent pass) | 14 | `findings/08-maint-b.md` |
| 9 | `robust-a` | Robustness | Error boundaries/feedback/edge/offline + error-handling/transactions/logging/retries | 12 | `findings/09-robust-a.md` |
| 10 | `robust-b` | Robustness | (same scope as `robust-a` — independent pass) | 12 | `findings/10-robust-b.md` |

`--dual` adds cross-model agreers for the Security pillar (highest-stakes; self-critique-paradox mitigation).

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

Run the registry deterministic checks ([`/_shared/check-registry.json`](/_shared/check-registry.json), `lane==deterministic ∧ consolidated_target∈{audit,both}`) across the codebase — grep/tsc/import-graph, zero-FP — and write to `${AUDIT_RUN}/findings/00-deterministic.md` tagged `lane: deterministic`. The deterministic and semantic lanes catch **disjoint** bug classes (ianlpaterson 38-task) — a deleted test has no semantic signature; a wrong answer-key has no structural one — so run both. Detail: [references/main.md](references/main.md) §Recall hardening.

**Design pillar (`--pillar design`):** also select `pillar == design` rows — Layer 0 (`adapter: universal`) always; Layer 1/2 gated by the `scripts/detect-stack.sh` adapter; `reconciliation.relaxFor` suppresses per stack (firing logic identical to `/blitz:review --only design`). Vendored rows share one **key-free** `npx impeccable detect --json` run (filter by `detection.filter`); the provider-gated tells route through `agents/design-critic.md`'s gemini CLI (`BLITZ_GEMINI_BIN`), the pillar's **semantic** aggregator over rendered screenshots (not the 10 code passes). Detail: [references/main.md](references/main.md) §Phase 1.D2.

## Phase 2: COMPILE RESULTS — Consolidate Findings

### 2.1 Read All Findings

Read every file in `${AUDIT_RUN}/findings/`. For each file:
- Parse the findings (each finding has: severity, title, description, file, line, recommendation, **Confidence: 0-100**).
- If a file is empty or malformed, note the agent as failed.

### 2.1.4 Multi-Review aggregation (Phase 2.0)

Group semantic findings by (file, line-range, claim). A finding flagged by **≥2 independent same-scope passes → `confidence: high` (base 0.85)**; flagged once → `low` (0.50). This is the agreement signal the §1.1 roster (2 independent passes/pillar) exists to produce (SWRBench 2509.01494, +43.67% F1 — consistency across independent runs separates real issues from sporadic hallucinations). Deterministic-lane findings (`00-deterministic.md`) keep their own base_confidence (mechanism = verification). Detail: [references/main.md](references/main.md) §Recall hardening.

### 2.1.5 Confidence Threshold Filter

**Recall default (`--min-confidence low`): rank, do not drop.** The threshold only suppresses when precision is explicitly requested. Per `docs/_research/2026-05-16_audit-agent-fp-prevention.md`.

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

Per surviving finding (post-dedup), spawn N perspective-diverse refuters (correctness / security / reproduces lenses) — `Workflow` `parallel()` or `Agent()` per [agent-orchestration.md](/_shared/agent-orchestration.md). Each re-reads the cited `file:line` and attempts to **REFUTE** against actual behavior (default refuted if not reproducible); **≥majority refute → drop** the finding. Survivors attach a reproducing excerpt — nothing is reported without it (registry downgrade rule; native `/code-review` validation parity, <1% FP). Semantic findings remain `advisory` regardless of confidence (rank ↑, never authority). Deterministic findings (base 1.0) skip the panel — the mechanism is the verification. Detail: [references/main.md](references/main.md) §Recall hardening.

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

Copy the consolidated report into the project:
```bash
REPORT_DIR="docs/audits"
mkdir -p "${REPORT_DIR}"
cp "${AUDIT_RUN}/reports/audit-report.md" "${REPORT_DIR}/audit-$(date +%Y%m%d).md"
```

---

### 2.8 Coverage boundary (recall instrumentation, Phase 3.5)

Emit a required `coverage_boundary` block in the report — agents failed/timed-out, registry checks skipped (by `det-NN`/`sem-*` id), files over cap unread, lanes not run. A clean PASS with a large boundary is labeled "passed what we checked," never "passed everything." Detail: [references/main.md](references/main.md) §Recall hardening.

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

Every `audit-YYYYMMDD-epics.md` file MUST open with a `scope:` YAML frontmatter block above the `# Proposed Epics` heading. One entry per non-`complete` `proposed_epics[]` item. This is the canonical contract for `/blitz:roadmap extend` ingestion — see [/_shared/sprint-contracts.md](/_shared/sprint-contracts.md) §Writers.

Skip emission for any epic whose `status: "complete"` (idempotent reruns of `audit` MUST NOT duplicate registry entries on already-shipped work).

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

Write a JSON index for consumption by the roadmap skill at `${REPORT_DIR}/audit-$(date +%Y%m%d)-index.json`. Full index schema + backward-compat defaults: [references/main.md](references/main.md#machine-readable-index-schema-phase-35).

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
- **A pillar has little/no relevant surface** (e.g. no frontend, or no backend): still spawn both same-scope passes for that pillar — each auto-scopes to what exists from the inventory; sparse pillars simply yield few findings. Do NOT skip numbered agents (the roster is 2 independent passes per pillar, not a frontend/backend split). If an entire pillar is N/A (e.g. no UI at all), note it in the `coverage_boundary` (§2.8) rather than dropping the passes.
- **Agent timeout**: Mark as failed, proceed with available findings. Note gaps in report.
- **All agents failed**: Abort and report the failure. Suggest checking stack detection and file permissions.
- **Existing audit found**: Load previous findings for comparison. Include a "Delta" section in the report showing improvements and regressions.

## Gotchas

- Spawns 10 parallel agents (2 same-scope passes/pillar); MISSING_COUNT ≥ threshold aborts (spawn-protocol §8 gate) — don't pass blank outputs as SUCCESS.
- Findings without 2-pass Multi-Review agreement are FP-prone; require convergence before reporting.
- Object-noun routing for "audit X": code→audit, deps→`/blitz:dep-health`, Firestore/Vue/Pinia→`/blitz:code-doctor`, cross-page UI→`/blitz:ui-audit`, sprint→`/blitz:sprint-review`. Bare "audit"→`/blitz:ask`.
- Quantified findings without a `scope:` block silently drop at `/blitz:roadmap` ingestion — emit `scope:` or a `<!-- no-registry -->` waiver.
