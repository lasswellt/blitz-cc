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

Per [agents.md](/_shared/agents.md). Two dispatch paths produce identical findings files under `${AUDIT_RUN}/findings/`; only the orchestration mechanism differs. The 10-agent flat pool is the canonical `Workflow` pilot (no DAG, no worktree, no cross-session resume).

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

**Dispatch:** invoke the plugin workflow `/blitz:audit-sweep` (`workflows/audit-sweep.js`) with
`args: { roster: [{ name, prompt }, …], findingsSchema }` — the roster is the 10-agent table below with each
`prompt` filled from the pillar template (agent name, pillar, scope, file cap, output path, checklist, stack,
inventory inline). It returns `{ agents: [{ name, ok, result }] }`. **On any failure** (tool absent, no
`Workflow(<name>)` allow rule in a `-p` run, script error, abort) **fall back to §1.1 (`Agent()`)** — never
hard-fail. Resume semantics + concurrency cap: [agents.md](/_shared/agents.md)
§Workflow Dispatch Contract.

- Each `a.prompt` is the pillar template from `references/main.md` — it MUST embed the OUTPUT STYLE snippet (Invariant 5) and the write-as-you-go rule (§1.3 step 8).
- `model: 'sonnet'` per token-budget routing (explicit — prevents `[1m]` inheritance).
- `schema` replaces the `classify_output()` gate; `null` entries = failed agents (handled by Phase 2.2).
- After the workflow returns, proceed to Phase 1.4 / Phase 1.5 / Phase 2 unchanged.

### 1.1 Spawn 10 Pillar Agents via Agent Tool (default path)

Spawn all 10 agents using the `Agent` tool, all in **a single assistant message** so they execute concurrently.

Per-spawn parameters:
- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from an Opus main thread)
- `description: audit <agent-name>`
- `prompt`: the pillar prompt template from `references/main.md`, filled per the roster below
- `run_in_background: true`

Cross-pillar findings synthesized on the main thread in Phase 2 from output files (not peer-to-peer, per [agents.md](/_shared/agents.md)).

**Weight class**: Medium (per [agents.md](/_shared/agents.md)). File caps per pillar are specified in the roster below. Each agent prompt must also include: max 250-line output per pillar, 5-minute wall-clock budget, mandatory write-as-you-go (step 8 of prompt construction below).

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

### 1.2 Security pillar: registry rows first, claude-security when installed

The pillar's authoritative checks are the registry `sec-*` rows ([`/_shared/check-registry.json`](/_shared/check-registry.json), `pillar == security`); they run in the deterministic lane (§1.5) on every audit and keep reject authority. Deep semantic scanning is delegated when the `claude-security` plugin is present:

```bash
SEC_PLUGIN=0
{ claude plugin list 2>/dev/null | grep -q 'claude-security'; } \
  || grep -qs 'claude-security' "${HOME}/.claude/plugins/installed_plugins.json" && SEC_PLUGIN=1
echo "[audit] security: registry sec-* rows$( [ "$SEC_PLUGIN" = 1 ] && echo ' + claude-security scan' || echo ' + sec-a/sec-b passes')" >&2
```

- **`SEC_PLUGIN=1`** → do not spawn `sec-a`/`sec-b` (roster shrinks to 8). Invoke the plugin's scan skill on the audit scope, write its verified findings (SARIF → severity schema, one `FINDING:` per result, `Confidence: 90`) to `findings/05-sec-external.md` tagged `lane: external`. External findings skip §2.1.4 aggregation and §2.3.5 refutation (already verified by the plugin) and stay `advisory`.
- **`SEC_PLUGIN=0`** → spawn `sec-a`/`sec-b` as listed; the report's Security section and the Phase 3 spec carry one line: `Recommendation: install the claude-security plugin (verified SARIF findings) or run /security-review before release; blitz audit covers registry sec-* rows only.`
- `--dual` applies only when `SEC_PLUGIN=0` (cross-model agreers for the two passes).

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

**Design pillar (`--pillar design`):** also select `pillar == design` rows — Layer 0 (`adapter: universal`) always; Layer 1/2 gated by the `scripts/detect-stack.sh` adapter; `reconciliation.relaxFor` suppresses per stack (firing logic identical to `/blitz:check --only design`). Vendored rows share one **key-free** `npx impeccable detect --json` run (filter by `detection.filter`); the provider-gated tells route through `agents/design-critic.md`'s gemini CLI (`BLITZ_GEMINI_BIN`), the pillar's **semantic** aggregator over rendered screenshots (not the 10 code passes). Detail: [references/main.md](references/main.md) §Phase 1.D2.

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

Per surviving finding (post-dedup), spawn N perspective-diverse refuters (correctness / security / reproduces lenses) — `Workflow` `parallel()` or `Agent()` per [agents.md](/_shared/agents.md). Each re-reads the cited `file:line` and attempts to **REFUTE** against actual behavior (default refuted if not reproducible); **≥majority refute → drop** the finding. Survivors attach a reproducing excerpt — nothing is reported without it (registry downgrade rule; native `/code-review` validation parity, <1% FP). Semantic findings remain `advisory` regardless of confidence (rank ↑, never authority). Deterministic findings (base 1.0) skip the panel — the mechanism is the verification. Detail: [references/main.md](references/main.md) §Recall hardening.

When the §1.0 gate selected the `Workflow` path, dispatch the panel as a nested `parallel()` per finding — each finding's lenses verify concurrently while other findings are still being judged (pipeline over findings, barrier over lenses). On any `Workflow` failure, fall back to `Agent()`.

```js
// args: { findings:[{key,desc,fileLine}], lenses:['correctness','security','reproduces'], verdictSchema }
const OS = 'OUTPUT STYLE: terse-technical per /_shared/output.md. Drop articles/fillers/hedging; preserve code/paths/commands/JSON verbatim; no preamble.'
const judged = await parallel(args.findings.map(f => () =>
  parallel(args.lenses.map(lens => () =>
    agent(`${OS}\n\nRe-read ${f.fileLine}. REFUTE via the ${lens} lens: "${f.desc}". Default refuted=true if not reproducible.`,
      { label: `refute:${lens}:${f.key}`, phase: 'Audit', model: 'sonnet', schema: args.verdictSchema })))
    // full-lens denominator is deliberate (recall bias: refuter failure must NOT auto-drop a finding — see references/main.md §553)
    .then(votes => ({ f, refuted: votes.filter(Boolean).filter(v => v.refuted).length > args.lenses.length / 2 }))))
const survivors = judged.filter(j => !j.refuted).map(j => j.f)  // ≥majority refute → dropped
```

- `schema`-validated verdicts replace inline parsing; `.filter(Boolean)` drops `null` (failed) refuters before the majority count. Deterministic findings never enter `args.findings`.

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

**Opt-in HTML twin (additive — report `.md` only):** after the cp, emit an HTML twin of the human-facing report via the `emit_html()` helper (contract: `/_shared/sessions.md`; bash bodies: `hooks/scripts/_lib/html.sh` — source it, never inline). Audit reports may quote fetched/untrusted content → pass the `untrusted` trust arg (body HTML-escaped into `<pre>`, TB-4). Twin the report `.md` only; `docs/plans/audit-<date>/` (`spec.md`, `tasks.json`) is never twinned. Default (`BLITZ_OUTPUT_FORMAT` unset) is a no-op.

```bash
. "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/html.sh"   # canonical emit_html/sanitize_html bodies (never inline)
[ "${BLITZ_OUTPUT_FORMAT:-md}" = html ] && emit_html "${REPORT_DIR}/audit-$(date +%Y%m%d).md" untrusted
```

---

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

```bash
AUDIT_DATE=$(date +%Y-%m-%d); PLAN="audit-${AUDIT_DATE}"; PLAN_DIR="docs/plans/${PLAN}"
mkdir -p "$PLAN_DIR"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" init "$PLAN"
STATUS=paused; [ "${AUDIT_PLAN_FLAG:-0}" = 1 ] && STATUS=active     # --plan activates immediately
cat > "${PLAN_DIR}/spec.md" <<EOS
---
status: ${STATUS}
priority: P2
created: ${AUDIT_DATE}
ship: manual
---
# Audit ${AUDIT_DATE}

## Goal
Resolve the ${THEME_COUNT} themes found by /blitz:audit (${TOTAL} findings: ${C}C/${H}H/${M}M/${L}L; agents ${OK}/${N}). Report: docs/audits/audit-$(date +%Y%m%d).md (gitignored; this file is the tracked summary).

## Findings summary
| Task | Pillar | Impact | Findings (file:line) |
|---|---|---|---|
| T-001 | … | … | … |

Health: Architecture NN · Performance NN · Security NN · Maintainability NN · Robustness NN. Coverage boundary: <§2.8 block, one line>.
Security: <registry sec-* rows run; claude-security delegated | one-line recommendation from §1.2>.

## Out of scope
- Findings with no executable check (notes, not tasks): <finding — file:line — why no check>
- Pillars/lanes not run: <from coverage_boundary>
EOS
```

Then one `tasks.sh add` per theme, in impact order:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" add "$PLAN" --id T-001 \
  --title "Security: validate input in auth middleware" --role backend \
  --files "functions/src/middleware/auth.ts,functions/src/schemas/user.ts" --origin audit \
  --verify-cmd "! grep -rnE 'req\.body\.[a-zA-Z]+ *(as|!)' functions/src/middleware/auth.ts::60" \
  --notes "det-17 + sec-a/sec-b agreed; Critical; report §Security #3"
```

- `--depends` only for a real ordering (a schema task before the handler that consumes it); default none so `build --parallel` can fan out on disjoint `files`.
- Same-day rerun: `tasks.sh list "$PLAN"` first; skip a theme whose title already exists, continue ids from max+1, never rewrite `spec.md` frontmatter (a human may have flipped `status`).
- Append to `docs/plans/BACKLOG.md` nothing; the notes in `spec.md` are the parking lot.

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

- **Too few source files**: Inform user the codebase is too small for a full audit. Suggest manual review.
- **A pillar has little/no relevant surface** (e.g. no frontend, or no backend): still spawn both same-scope passes for that pillar — each auto-scopes to what exists from the inventory; sparse pillars simply yield few findings. Do NOT skip numbered agents (the roster is 2 independent passes per pillar, not a frontend/backend split). If an entire pillar is N/A (e.g. no UI at all), note it in the `coverage_boundary` (§2.8) rather than dropping the passes.
- **Agent timeout**: Mark as failed, proceed with available findings. Note gaps in report.
- **All agents failed**: Abort and report the failure. Suggest checking stack detection and file permissions.
- **Existing audit found**: Load previous findings for comparison. Include a "Delta" section in the report showing improvements and regressions.
- **`tasks.sh add` refuses a task** (no non-test check, bad role, duplicate id): fix the command, never hand-edit `tasks.json`; if no executable check exists, demote the theme to a note.
- **No theme has an executable check**: still write `spec.md` (findings + notes) and an empty `tasks.json`; say so in the final output.

## Gotchas

- Spawns 10 parallel agents (8 when claude-security handles the security pillar); MISSING_COUNT ≥ threshold aborts (spawn-protocol §8 gate) — don't pass blank outputs as SUCCESS.
- Findings without 2-pass Multi-Review agreement are FP-prone; require convergence before reporting.
- Object-noun routing for "audit X": code→audit, deps/CVEs→`/blitz:dep-health`, Vue/Firestore/Pinia misuse→`/blitz:check --only framework`, cross-page UI→`/blitz:ui-audit`, a change or plan→`/blitz:check`. Registry entry-point table: [quality.md](/_shared/quality.md) §Which entry point.
- The plan is `paused` by default: `next --loop` ignores it until a human flips `status: active` (or the run used `--plan`). A finding without an executable check is a note, never a task — `tasks.sh` enforces it.
