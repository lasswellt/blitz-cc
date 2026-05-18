---
name: code-sweep
description: "Iterative code-quality improvement with /loop support. Runs 30 checks across 7 categories with a ratchet ensuring quality only improves. Use when the user says 'sweep', 'code quality pass', 'find TODOs', 'remove dead code', or wants a continuous improvement loop."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
model: opus
effort: high
compatibility: ">=2.1.71"
argument-hint: "<scope> | --fix | --scan-only | --fix-all | --deep | --loop | --discover | --standards-report | --category <list>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Reference Material
All grep patterns, auto-fix strategies, severity rules, state schemas, and convention discovery details are in `references/main.md` (same directory as this file). **Read it on-demand** — only load the specific section you need for the current phase. Do NOT read the entire file at once.

## Additional Resources
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Code Sweep Skill

Iterative code improvement using **Observe-Diff-Act-Report**. 30 static checks + dynamic standards across 7 categories. Designed for `/loop` compatibility.

**Categories**: Cleanup | Correctness | Optimization | Convention | Security | Reduction | Robustness

**Loop lifecycle**: DISCOVER → SCAN → FIX → SCAN → FIX → ... RE-DISCOVER (every 10th run)

**Loop tick budget: < 2 minutes total.**

---

## SAFETY RULES (NON-NEGOTIABLE)

1. `--scan-only` (default) is **READ-ONLY** — never modify source files.
2. `--fix`: fix exactly **ONE** finding per invocation, then verify and commit.
3. `--fix-all`: fix one **CATEGORY** at a time, verify after each.
4. Never auto-fix findings marked `fixable: false` in references/main.md.
5. Always verify after fixing (typecheck + lint). If verification fails, revert ALL changes and mark `needs-human`.
6. Never delete files. Never modify test files.
7. **Circuit breaker**: 2 consecutive fix failures → switch to `--scan-only`.

---

## Phase 0: SETUP

### 0.0 Register Session
Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration and [verbose-progress.md](/_shared/verbose-progress.md). Generate SESSION_ID, create `.cc-sessions/${SESSION_ID}/tmp/`, check for conflicts, log `skill_start`.

### 0.1 Parse Arguments

| Flag | Behavior |
|------|----------|
| `--scan-only` (default) | Read-only scan, update ledger + snapshot |
| `--fix` | Scan + fix top auto-fixable finding |
| `--fix-all` | Batch fix all auto-fixable by category |
| `--deep` | Include Tier 3 analysis |
| `--loop` | `--fix` with full autonomy, auto-commit |
| `--discover` | Force convention discovery |
| `--standards-report` | Print compliance dashboard and exit |
| `--category <list>` | Comma-separated category filter |
| `--checks <list>` | Comma-separated check ID filter |
| `<scope>` | Directory/file to scan |

When `--loop`: auto-approve all, auto-commit+push, exit after one fix cycle. Tick type: first run → DISCOVERY; `run % 10 == 0` → RE-DISCOVERY; fixable findings → FIX; else → SCAN.

### 0.2 Load Configuration
Read `.code-sweep.json` (if exists). Schema in references/main.md. Defaults: scope = whichever of `src/, functions/, server/, pages/, components/, composables/, stores/, lib/, utils/, api/, middleware/` exist. Exclude `node_modules, dist, .nuxt, .output, coverage, .cc-sessions, __snapshots__, generated, vendor`.

### 0.3 Validate Scope
Verify at least one scope directory exists. Stop if none found.

---

## Phase 1: OBSERVE

1. **Load snapshot**: most recent from `docs/sweeps/*.json`. If none, this is first run.
2. **Load ledger**: `docs/sweeps/sweep-ledger.jsonl` → map by finding ID.
3. **Load state files**: `.code-sweep-standards.json`, `docs/sweeps/file-queue.json`, `docs/sweeps/ratchet.json`. Set `needs_discovery = true` if standards file missing.
4. **Detect changed files** (incremental): `git log --since=<last_sweep_date> --name-only`. Changed files always scanned. First run or `--deep` scans ALL files.
5. **Build file list**: Glob `*.ts, *.tsx, *.js, *.jsx, *.vue` in scope. Separate source vs test files. In batch mode: changed files get all checks, queued batch (`files_per_tick`) gets standards checks only.

---

## Phase 1.5: DISCOVER

**When**: first run, `--discover`, or every `revalidate_every_n_runs` runs. **Budget**: ~60s.

1. **Sample files**: stratified sampling (40% recent, 30% most-imported, 20% random, 10% hotspots). Cap at 200.
2. **Extract patterns** across 8 dimensions (file-naming, import-ordering, error-handling, async-pattern, component-style, export-style, indentation, quote-style). See references/main.md for detection methods.
3. **Decide**: ≥70% adoption → `enforced`; 30-70% → `needs-review`; <30% → `no-consensus`.
4. **Write** `.code-sweep-standards.json` (schema in references/main.md).
5. **Initialize file queue** with priority scoring (schema in references/main.md).
6. **Initialize ratchet** for each enforced standard (schema in references/main.md).

---

## Phase 2: SCAN — Parallel Tier Agents

Scanning is delegated to worker agents so the skill itself stays lightweight and each tier runs in its own independent context. Spawn one agent per **active** tier; run all spawns in a single message so they execute in parallel.

### Check Summary Table

| Tier | ID | Category | Fixable |
|------|----|----------|---------|
| 1 | `todo-fixme` | Cleanup | No |
| 1 | `console-log` | Cleanup | Yes |
| 1 | `empty-catch` | Cleanup | Yes |
| 1 | `placeholder-throw` | Correctness | No |
| 1 | `empty-function` | Correctness | No |
| 1 | `noop-handler` | Correctness | No |
| 1 | `placeholder-returns` | Correctness | No |
| 1 | `hardcoded-secret` | Security | No |
| 1 | `typescript-any` | Convention | Semi |
| 1 | `skipped-test` | Correctness | Yes |
| 1 | `loose-equality` | Correctness | Yes |
| 1 | `return-await` | Optimization | Yes |
| 1 | `optional-chaining` | Reduction | Yes |
| 1 | `redundant-else` | Reduction | Yes |
| 1 | `nullish-coalescing` | Reduction | Yes |
| 1 | `immediate-return-var` | Reduction | Yes |
| 2 | `unused-import` | Cleanup | Yes |
| 2 | `commented-code` | Cleanup | Yes |
| 2 | `todo-age` | Cleanup | No |
| 2 | `log-and-return` | Correctness | No |
| 2 | `three-state-ui` | Robustness | No |
| 2 | `file-length` | Convention | No |
| 2 | `missing-v-for-key` | Correctness | No |
| 2 | `missing-subagent-type` | Correctness | No |
| 3 | `orphaned-file` | Cleanup | No |
| 3 | `dead-export` | Cleanup | No |
| 3 | `unused-dep` | Cleanup | Semi |
| 3 | `sample-data` | Correctness | No |
| 3 | `unwired-store-actions` | Correctness | No |
| 3 | `sequential-await` | Optimization | No |
| 3 | `n-plus-one` | Optimization | No |
| 3 | `v-html-xss` | Security | No |
| 3 | `nesting-depth` | Convention | No |

### 2.1 Determine Active Tiers

- Tier 1: every tick (always active).
- Tier 2: active on first run of session, on `--deep`, or when no Tier 2 results exist in latest snapshot.
- Tier 3: only on `--deep`.
- Standards checks: merged into Tier 2 agent (both operate on the batch file set).

### 2.2 Spawn Tier Agents (Parallel)

For each active tier, call the `Agent` tool with:

- `subagent_type`: `general-purpose`
- `model`: `sonnet` (explicit — prevents `[1m]` inheritance from parent)
- `description`: `code-sweep tier <N> scan`
- `prompt`: the tier-agent prompt — see "Tier Agent Prompt Template" in references/main.md. The prompt contains the tier number, the file list (separated source vs test), the scope, and the absolute path of the findings file the agent must write.

**Inputs each agent receives:**
1. Tier number (1/2/3).
2. Source file list and test file list (as JSON arrays passed inline).
3. Repo root absolute path.
4. Path to write findings JSON: `.cc-sessions/${SESSION_ID}/tmp/scan-tier-${N}.json`.
5. For Tier 2: also the `.code-sweep-standards.json` content (so the agent can run standards checks).

**IMPORTANT:** emit all Agent tool calls in the same assistant message to run them concurrently. Do not chain them sequentially.

### 2.3 Merge Findings

After all agents return:

1. Read each `scan-tier-${N}.json` file.
2. Concatenate the findings arrays into a single in-memory list.
3. Deduplicate by finding `id`. On collision, prefer the entry with the lower tier (stronger signal).
4. Proceed to Phase 3 (DIFF) with the merged list.

If any agent failed or produced invalid JSON: log a warning, mark coverage as `incomplete` for that tier, and continue with the tiers that succeeded. Do not retry within the same tick — let the next sweep run cover it.

---

## Phase 3: DIFF

1. **Assign finding IDs**: `{check_id}-{file_path}-{line}-{hash}` (stable across runs).
2. **Compare against ledger**: existing / regression / suppressed / new / resolved.
3. **Priority queue**: sort by freshness (regressions → new → existing), then category priority (Convention → Reduction → Correctness → Optimization → Security → Cleanup → Robustness), then severity, fixable-first, age.
4. **Compute delta**: new_count, resolved_count, regressed_count, total_delta.
5. **Ratchet check**: compare violation counts against budgets. Tighten if improved, alert if regressed.
6. **Update file queue**: move compliant files to completed, update scores, add new files.

---

## Phase 4: ACT (skip if `--scan-only`)

1. **Auto-detect verify command**: check for `tsconfig.json` (tsc --noEmit) and eslint config.
2. **Select fix target**: pop highest-priority fixable finding.
3. **Apply fix**: read the "Auto-Fix Strategies" section of references/main.md for the specific check. Read file, confirm finding exists, apply edit.
4. **Verify**: run verify command. Pass → commit. Fail → revert, mark `needs-human`, increment circuit breaker.
5. **Commit**: `sweep(<check_id>): <description> in <file>`. In `--loop` mode, also push.
6. **`--fix-all`**: repeat per category, verify after each, revert failed categories.

---

## Phase 5: REPORT

1. **Update ledger**: append to `docs/sweeps/sweep-ledger.jsonl` (schema in references/main.md).
2. **Write snapshot**: `docs/sweeps/YYYY-MM-DD.json` + `latest.json` (schema in references/main.md).
3. **Score**: `100 - (critical*10) - (high*5) - (medium*2) - (low*0.5)`, clamped 0-100. Grade: A(90+), B(80+), C(70+), D(60+), F(<60).
4. **Print summary**:
```
Code Sweep: <GRADE> (<score>/100)  |  Standards: <pct>% aligned
======================================================================
Mode: <mode>  |  Scope: <scope>  |  Run: #<N>
Files: N source + K test  |  Previous: <prev_score>/100
Findings: <total> (Crit: N, High: N, Med: N, Low: N)
  New: +N | Resolved: -N | Regressed: N | Fixable: N
By category: Cleanup N | Correctness N | Optimization N | Convention N | Security N | Reduction N | Robustness N
Top issues:
  1. [sev] file:line — message
```
5. **Ratchet update**: log score trend, update standard budgets.
6. **Suggestions**: based on findings (see references/main.md for condition→suggestion mapping).
7. **Session cleanup**: complete session, release locks, log `skill_complete`.

---

## Error Recovery

- No source files → score 100, grade A
- Grep fails → skip check, note incomplete coverage
- Verify unavailable → warn; in `--loop`, refuse to fix
- Fix breaks verify → revert, mark `needs-human`
- All fixes fail → switch to `--scan-only`
- Standards corrupted → rename `.bak`, re-discover
- Queue exhausted → re-prioritize from beginning
- Concurrent fix sessions → BLOCK per conflict matrix

## Conflict Matrix

| A (this) | B (other) | Resolution |
|----------|-----------|------------|
| scan | scan | OK |
| fix | fix | BLOCK |
| fix | sprint-dev | WARN |
| fix | refactor | BLOCK |
| scan | any | OK |
