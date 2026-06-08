---
name: quality-metrics
description: "Collects, stores, and visualizes code-quality metrics over time (test counts, lint debt, cyclomatic complexity, dependency health, type-error trends). Modes: collect, dashboard, trend, compare. Use when the user says 'quality metrics', 'metrics dashboard', 'show trends', 'compare sprints', 'quality over time', or as a post-sprint observability snapshot in /blitz:ship."
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<collect|dashboard|trend|compare <date1> <date2>>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For metric snapshot schema, dashboard templates, trend thresholds, and score calculation details, see:
!cat skills/quality-metrics/references/main.md
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Continuous Quality Metrics

Collect code quality signals, store snapshots over time, and produce dashboards with trend analysis. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode

Extract mode from `$ARGUMENTS`. Default to `collect` if not specified.

| Mode | Description | Requirements |
|------|-------------|--------------|
| `collect` | Gather all metrics and store snapshot | None |
| `dashboard` | Generate markdown dashboard from latest snapshot | At least 1 snapshot |
| `trend` | Analyze metrics over time | At least 2 snapshots |
| `compare <date1> <date2>` | Side-by-side comparison of two snapshots | Both dates must have snapshots |

---

## Phase 1: COLLECT — Parallel Metric Collectors

Metric collection is delegated to 5 parallel collector agents, each running one independent tool. Spawn all 5 in **a single assistant message** so they execute concurrently. Wall-clock drops from 2-3 min sequential to ~45 sec parallel.

### 1.1 Agent Roster

| Agent | Tool | Output File | Score Formula |
|---|---|---|---|
| `collect-typescript` | `npx tsc --noEmit` | `${SESSION_TMP_DIR}/metric-typescript.json` | `max(0, 100 - errors * 2)` |
| `collect-lint` | `npx eslint . --format json` | `${SESSION_TMP_DIR}/metric-lint.json` | `max(0, 100 - errors * 5 - warnings)` |
| `collect-tests` | `npx vitest run --reporter=json` (fallback: jest) | `${SESSION_TMP_DIR}/metric-tests.json` | `(passed / total) * 100`; null if no runner |
| `collect-build` | `npm run build` | `${SESSION_TMP_DIR}/metric-build.json` | 100 on exit 0, else 0 |
| `collect-completeness` | inline `/blitz:review --only completeness` lookup | `${SESSION_TMP_DIR}/metric-completeness.json` | from latest completeness snapshot; null if none |

The 2 lightweight metrics (codebase size, dependency count) stay in the orchestrator — they're simple file reads that don't warrant agent overhead.

### 1.2 Spawn Parameters

For each collector, call the `Agent` tool with:

- `subagent_type: general-purpose` (must Write JSON output — never `Explore`)
- `model: sonnet` (explicit)
- `description: quality-metrics <tool> collector`
- `prompt`: the collector prompt template from `references/main.md`
- `run_in_background: false`

**Weight class**: Light (per [agent-orchestration.md](/_shared/agent-orchestration.md)). Each collector prompt declares: max 1 bash command, max 5 file reads (for parsing output), max 8 tool calls, 3-min wall-clock (typescript/tests/build may be slow on large projects — bump to 5 min for those specifically), output-file existence check.

### 1.3 Inputs Each Collector Receives

1. Tool command to run.
2. Parse instructions for the tool's output format.
3. Score formula.
4. Output JSON path.
5. Fallback policy: on tool missing or error, write `{"score": null, "error": "..."}`.

### 1.4 Validate Outputs

**Before Phase 2, verify all collector outputs**:

```bash
MISSING_COUNT=0
for tool in typescript lint tests build completeness; do
  f="${SESSION_TMP_DIR}/metric-${tool}.json"
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
  fi
done
```

A missing collector file is treated as `score: null` in Phase 2 (not an abort condition — we want the snapshot written even with partial coverage). Log each missing collector to the activity feed for user visibility.

### 1.5 Orchestrator-Side Lightweight Metrics

While collectors run, the orchestrator computes these in parallel (they're pure file reads):

**Codebase size:**
```bash
# Source files and lines
find src/ \( -name '*.ts' -o -name '*.vue' \) -not -name '*.test.*' -not -name '*.spec.*' \
  > "${SESSION_TMP_DIR}/source-files.txt"
wc -l $(cat "${SESSION_TMP_DIR}/source-files.txt") 2>/dev/null | tail -1 > "${SESSION_TMP_DIR}/source-lines.txt"

# Test files and lines
find src/ \( -name '*.test.*' -o -name '*.spec.*' \) \
  > "${SESSION_TMP_DIR}/test-files.txt"
wc -l $(cat "${SESSION_TMP_DIR}/test-files.txt") 2>/dev/null | tail -1 > "${SESSION_TMP_DIR}/test-lines.txt"
```

Calculate test-to-code ratio = test_lines / source_lines.

**Dependency count:**
Read `package.json` and count keys in `dependencies` (production) and `devDependencies` (dev).

---

## Phase 2: STORE — Save Snapshot

### 2.1 Create Metrics Directory

```bash
mkdir -p docs/metrics
```

### 2.2 Write Snapshot

Write to `docs/metrics/YYYY-MM-DD.json` using today's date:

```json
{
  "date": "YYYY-MM-DD",
  "timestamp": "<ISO-8601>",
  "scores": {
    "typescript": null,
    "lint": null,
    "tests": null,
    "build": null,
    "completeness": null
  },
  "details": {
    "typescript": { "errors": 0 },
    "lint": { "errors": 0, "warnings": 0 },
    "tests": { "total": 0, "passed": 0, "failed": 0, "skipped": 0 },
    "build": { "success": true },
    "codebase": {
      "source_files": 0,
      "source_lines": 0,
      "test_files": 0,
      "test_lines": 0,
      "test_ratio": 0.0
    },
    "dependencies": { "production": 0, "dev": 0 }
  },
  "overall_score": null
}
```

**Overall score** = average of all non-null scores. If all scores are null, overall_score = null.

### 2.3 Verify Snapshot

Re-read the written file and validate it parses as valid JSON:
```bash
python3 -m json.tool docs/metrics/YYYY-MM-DD.json > /dev/null 2>&1 && echo "VALID" || echo "INVALID"
```

---

## Phase 3: DASHBOARD — Generate Report

**Trigger:** Run this phase if mode is `dashboard` or `collect`.

### 3.1 Load Latest Snapshot

Read the most recent `docs/metrics/*.json` by sorting filenames lexicographically (they are date-based):

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort | tail -1
```

### 3.2 Load Previous Snapshot (if available)

If more than one snapshot exists, load the second-most-recent to compute deltas:

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort | tail -2 | head -1
```

### 3.3 Generate Dashboard

Write `docs/metrics/dashboard.md` with the following structure:

```markdown
# Quality Dashboard

**Date**: YYYY-MM-DD
**Overall Score**: XX/100

## Scorecard

| Metric | Score | Status | Delta |
|--------|-------|--------|-------|
| TypeScript | XX | PASS/WARN/FAIL | +N/-N/= |
| Lint | XX | PASS/WARN/FAIL | +N/-N/= |
| Tests | XX | PASS/WARN/FAIL | +N/-N/= |
| Build | XX | PASS/WARN/FAIL | +N/-N/= |
| Completeness | XX | PASS/WARN/FAIL | +N/-N/= |

## Status Key

- PASS: score >= 80
- WARN: score >= 50 and < 80
- FAIL: score < 50

## Details

### TypeScript
- Errors: N

### Lint
- Errors: N
- Warnings: N

### Tests
- Total: N | Passed: N | Failed: N | Skipped: N

### Build
- Status: Success/Failure

### Codebase
- Source files: N (N lines)
- Test files: N (N lines)
- Test-to-code ratio: X.XX

### Dependencies
- Production: N
- Dev: N
```

**Status thresholds:**
- PASS: score >= 80
- WARN: score >= 50 and < 80
- FAIL: score < 50
- N/A: score is null

**Delta column:**
- If previous snapshot exists, show the numeric difference (e.g., +5, -3, =)
- If no previous snapshot, show "—"

**Opt-in HTML twin (additive — `.md` stays canonical):** after the canonical `docs/metrics/dashboard.md` Write completes, emit a styled HTML twin via the `/_shared/html-template-helper.md` `emit_html()` helper. The `.json` snapshot path is untouched.

```bash
[ "${BLITZ_OUTPUT_FORMAT:-md}" = html ] && emit_html docs/metrics/dashboard.md
```

---

## Phase 4: TREND — Analyze Over Time

**Trigger:** Run this phase if mode is `trend` or `compare`.

### 4.1 Load All Snapshots

Read all `docs/metrics/*.json` files, sorted by date ascending:

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort
```

Parse each file and collect into a time series.

### 4.2 Validate Snapshot Count

- For `trend` mode: require at least 2 snapshots. If fewer, report "Insufficient data — need at least 2 snapshots for trend analysis."
- For `compare` mode: require snapshots matching both requested dates. If an exact match is not found, use the nearest available date and note the substitution.

### 4.3 Analyze Trends

For each metric, compare the last 3 snapshots (or all available if fewer than 3):

| Direction | Condition |
|-----------|-----------|
| Improving | Latest score > average of prior scores |
| Declining | Latest score < average of prior scores by > 5 points |
| Stable | Change is within 5 points |

Calculate velocity = (latest - earliest) / number_of_intervals.

### 4.4 Detect Alerts

Flag any metric where:
- Score declined by more than 10 points between any two consecutive snapshots
- Score is below 50 (FAIL threshold)
- Score was previously PASS (>= 80) and is now WARN (< 80)

### 4.5 Write Trend Report

Write `docs/metrics/trend-report.md`:

```markdown
# Quality Trend Report

**Period**: YYYY-MM-DD to YYYY-MM-DD
**Snapshots**: N

## Trend Summary

| Metric | Current | Direction | Velocity | Alert |
|--------|---------|-----------|----------|-------|
| TypeScript | XX | Improving/Declining/Stable | +X.X/snapshot | — or ALERT |
| Lint | XX | ... | ... | ... |
| Tests | XX | ... | ... | ... |
| Build | XX | ... | ... | ... |
| Completeness | XX | ... | ... | ... |
| Overall | XX | ... | ... | ... |

## Alerts

- [ALERT] <metric> declined by N points between YYYY-MM-DD and YYYY-MM-DD
- ...

## Recommendations

- <Prioritized suggestions based on trends>
```

### 4.6 Compare Mode Output

If mode is `compare <date1> <date2>`, write a side-by-side comparison:

```markdown
# Quality Comparison: YYYY-MM-DD vs YYYY-MM-DD

| Metric | Date 1 | Date 2 | Delta | Direction |
|--------|--------|--------|-------|-----------|
| TypeScript | XX | XX | +/-N | Improved/Declined/Same |
| ... | ... | ... | ... | ... |
| Overall | XX | XX | +/-N | Improved/Declined/Same |

## Notable Changes
- <List of metrics with significant movement>
```

---

## Phase 5: REPORT — Present to User

Print a summary to the user based on the mode that was run:

### 5.1 Collect Summary

```
Quality Metrics Collected
=========================
Date: YYYY-MM-DD
Overall Score: XX/100

  TypeScript:   XX/100  PASS/WARN/FAIL
  Lint:         XX/100  PASS/WARN/FAIL
  Tests:        XX/100  PASS/WARN/FAIL
  Build:        XX/100  PASS/WARN/FAIL
  Completeness: XX/100  PASS/WARN/FAIL

Snapshot: docs/metrics/YYYY-MM-DD.json
Dashboard: docs/metrics/dashboard.md
```

### 5.2 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`.
2. Append `session_end` to the operation log.
3. Optionally remove session temp directory if no artifacts need preservation.

---

## Safety Rules

- **Read-only on source code.** This skill only reads source files; it never modifies application code.
- **Non-destructive metrics.** Commands like `tsc --noEmit` and `eslint` are read-only analysis. The `npm run build` command may produce build artifacts; this is expected.
- **Snapshot immutability.** Never overwrite an existing snapshot file. If `docs/metrics/YYYY-MM-DD.json` already exists, append a counter suffix (e.g., `YYYY-MM-DD-2.json`).
- **No credential exposure.** Do not log or store environment variable values, API keys, or tokens in snapshots.

---

## Error Recovery

- **Metric command fails**: Set that metric's score to `null`, record the error in `details`, and continue with the remaining collectors.
- **No previous snapshots for trend mode**: Report "Insufficient data — need at least 2 snapshots. Run `collect` mode first."
- **docs/metrics/ directory missing**: Create it automatically in Phase 2.
- **Compare dates do not match any snapshot**: Find the nearest available date for each requested date. Note the substitution in the comparison output.
- **JSON parse failure on existing snapshot**: Skip the malformed file and note it in the trend report. Do not delete or overwrite it.
- **No test runner detected**: Set tests score to `null`. Note "No test runner found (checked Vitest, Jest)."
- **No TypeScript configured**: Set typescript score to `null`. Note "No tsconfig.json found."
- **Build script missing**: Set build score to `null`. Note "No `build` script in package.json."
