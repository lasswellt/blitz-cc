# Quality Metrics — Reference Material

Schemas, templates, thresholds, and calculation details used by the quality-metrics skill.

---

## Collector Agent Prompt Template

<!-- import: /_shared/agent-orchestration.md -->
Canonical boilerplate (Generic Agent Preamble, Light BUDGET, WRITE-AS-YOU-GO implicit via single JSON Write, CONFIRMATION) is documented in [/_shared/agent-orchestration.md](/_shared/agent-orchestration.md). The inline template below remains the byte-stable spawn source — OUTPUT STYLE inline preservation is required by sprint-review Invariant 5.

Used in Phase 1 when spawning metric collectors. The main skill fills in `{{…}}` placeholders.

```
You are a quality-metrics collector agent for the {{TOOL}} metric.

You are a general-purpose agent with Write access. Your task is INCOMPLETE
if {{OUTPUT_PATH}} does not exist when you finish.

BUDGET (Light class — see skills/_shared/agent-orchestration.md):
- Max bash commands: 1 (the tool invocation itself)
- Max file reads: 5 (for parsing output if needed)
- Max tool calls: 8
- Max output: JSON (see schema below)
- Wall-clock: 3 minutes ({{EXTENDED_TIMEOUT_NOTE}})

TASK:
1. Run: {{TOOL_COMMAND}}
2. Parse the output per these rules: {{PARSE_RULES}}
3. Apply the score formula: {{SCORE_FORMULA}}
4. Write {{OUTPUT_PATH}} with the JSON result below.

OUTPUT JSON SCHEMA:
{
  "tool": "{{TOOL}}",
  "score": <number 0-100 or null>,
  "details": {
    // Tool-specific fields — see PARSE_RULES
  },
  "error": "<only if tool failed; describe the failure>"
}

FALLBACK: If the tool is not installed OR the command fails with non-zero exit:
  Write the file with `"score": null` and an `"error"` string describing what
  happened. Do NOT treat tool absence as a task failure.

CONFIRMATION: Emit one line: "{{TOOL}}: score=<N or null>"

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

**Per-collector parameter fills:**

- `collect-typescript`: TOOL=typescript, COMMAND=`npx tsc --noEmit 2>&1 | tail -5`, PARSE=`extract error count from compiler output`, FORMULA=`0 errors → 100; N errors → max(0, 100 - N * 2)`, EXTENDED_TIMEOUT=5 min.
- `collect-lint`: TOOL=lint, COMMAND=`npx eslint . --format json 2>&1`, PARSE=`sum errors and warnings from JSON`, FORMULA=`max(0, 100 - errors*5 - warnings)`, EXTENDED_TIMEOUT=3 min.
- `collect-tests`: TOOL=tests, COMMAND=`npx vitest run --reporter=json 2>&1` (fallback `npx jest --json`), PARSE=`extract total/passed/failed/skipped`, FORMULA=`(passed / total) * 100; null if total == 0`, EXTENDED_TIMEOUT=5 min.
- `collect-build`: TOOL=build, COMMAND=`npm run build 2>&1`, PARSE=`check exit code`, FORMULA=`exit 0 → 100; else → 0`, EXTENDED_TIMEOUT=5 min.
- `collect-completeness`: TOOL=completeness, COMMAND=`ls -t docs/metrics/*.json 2>/dev/null | head -1 | xargs jq -r '.scores.completeness // "null"'`, PARSE=`parse JSON score field`, FORMULA=`pass-through from existing snapshot; null if none`, EXTENDED_TIMEOUT=3 min.

---

## JSON Schema for Metric Snapshots

Every snapshot written to `docs/metrics/YYYY-MM-DD.json` must conform to this schema.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["date", "timestamp", "scores", "details", "overall_score"],
  "properties": {
    "date": {
      "type": "string",
      "pattern": "^\\d{4}-\\d{2}-\\d{2}$",
      "description": "ISO date string (YYYY-MM-DD)"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "Full ISO-8601 timestamp of when the snapshot was taken"
    },
    "scores": {
      "type": "object",
      "required": ["typescript", "lint", "tests", "build", "completeness"],
      "properties": {
        "typescript": { "type": ["number", "null"], "minimum": 0, "maximum": 100 },
        "lint": { "type": ["number", "null"], "minimum": 0, "maximum": 100 },
        "tests": { "type": ["number", "null"], "minimum": 0, "maximum": 100 },
        "build": { "type": ["number", "null"], "enum": [0, 100, null] },
        "completeness": { "type": ["number", "null"], "minimum": 0, "maximum": 100 }
      }
    },
    "details": {
      "type": "object",
      "required": ["typescript", "lint", "tests", "build", "codebase", "dependencies"],
      "properties": {
        "typescript": {
          "type": "object",
          "properties": {
            "errors": { "type": "integer", "minimum": 0 },
            "tsconfig_found": { "type": "boolean" }
          },
          "required": ["errors"]
        },
        "lint": {
          "type": "object",
          "properties": {
            "errors": { "type": "integer", "minimum": 0 },
            "warnings": { "type": "integer", "minimum": 0 },
            "files_linted": { "type": "integer", "minimum": 0 }
          },
          "required": ["errors", "warnings"]
        },
        "tests": {
          "type": "object",
          "properties": {
            "total": { "type": "integer", "minimum": 0 },
            "passed": { "type": "integer", "minimum": 0 },
            "failed": { "type": "integer", "minimum": 0 },
            "skipped": { "type": "integer", "minimum": 0 },
            "runner": { "type": "string", "enum": ["vitest", "jest", "unknown"] }
          },
          "required": ["total", "passed", "failed", "skipped"]
        },
        "build": {
          "type": "object",
          "properties": {
            "success": { "type": "boolean" },
            "exit_code": { "type": "integer" },
            "error_summary": { "type": ["string", "null"] }
          },
          "required": ["success"]
        },
        "codebase": {
          "type": "object",
          "properties": {
            "source_files": { "type": "integer", "minimum": 0 },
            "source_lines": { "type": "integer", "minimum": 0 },
            "test_files": { "type": "integer", "minimum": 0 },
            "test_lines": { "type": "integer", "minimum": 0 },
            "test_ratio": { "type": "number", "minimum": 0.0 }
          },
          "required": ["source_files", "source_lines", "test_files", "test_lines", "test_ratio"]
        },
        "dependencies": {
          "type": "object",
          "properties": {
            "production": { "type": "integer", "minimum": 0 },
            "dev": { "type": "integer", "minimum": 0 }
          },
          "required": ["production", "dev"]
        }
      }
    },
    "overall_score": {
      "type": ["number", "null"],
      "minimum": 0,
      "maximum": 100,
      "description": "Average of all non-null scores"
    }
  }
}
```

---

## Dashboard Markdown Template

Use this template when generating `docs/metrics/dashboard.md`.

```markdown
# Quality Dashboard

**Date**: {{date}}
**Overall Score**: {{overall_score}}/100

---

## Scorecard

| Metric | Score | Status | Delta |
|--------|-------|--------|-------|
| TypeScript | {{scores.typescript}} | {{status_typescript}} | {{delta_typescript}} |
| Lint | {{scores.lint}} | {{status_lint}} | {{delta_lint}} |
| Tests | {{scores.tests}} | {{status_tests}} | {{delta_tests}} |
| Build | {{scores.build}} | {{status_build}} | {{delta_build}} |
| Completeness | {{scores.completeness}} | {{status_completeness}} | {{delta_completeness}} |
| **Overall** | **{{overall_score}}** | **{{status_overall}}** | **{{delta_overall}}** |

### Status Key

| Status | Condition |
|--------|-----------|
| PASS | score >= 80 |
| WARN | 50 <= score < 80 |
| FAIL | score < 50 |
| N/A | score is null (metric unavailable) |

### Delta Key

| Symbol | Meaning |
|--------|---------|
| +N | Improved by N points since last snapshot |
| -N | Declined by N points since last snapshot |
| = | No change |
| — | No previous snapshot for comparison |

---

## Details

### TypeScript Strictness
- **Errors**: {{details.typescript.errors}}
- **Score Formula**: 0 errors = 100, else max(0, 100 - errors * 2)

### Lint
- **Errors**: {{details.lint.errors}}
- **Warnings**: {{details.lint.warnings}}
- **Score Formula**: max(0, 100 - errors * 5 - warnings * 1)

### Tests
- **Total**: {{details.tests.total}}
- **Passed**: {{details.tests.passed}}
- **Failed**: {{details.tests.failed}}
- **Skipped**: {{details.tests.skipped}}
- **Runner**: {{details.tests.runner}}
- **Score Formula**: (passed / total) * 100

### Build
- **Status**: {{details.build.success ? "Success" : "Failure"}}
- **Score**: 100 if success, 0 if failure

### Codebase Size
- **Source Files**: {{details.codebase.source_files}} ({{details.codebase.source_lines}} lines)
- **Test Files**: {{details.codebase.test_files}} ({{details.codebase.test_lines}} lines)
- **Test-to-Code Ratio**: {{details.codebase.test_ratio}}

### Dependencies
- **Production**: {{details.dependencies.production}}
- **Dev**: {{details.dependencies.dev}}

---

*Generated by quality-metrics on {{timestamp}}*
```

---

## Trend Analysis Thresholds

Use these thresholds when evaluating metric direction and generating alerts.

### Direction Thresholds

| Direction | Condition | Description |
|-----------|-----------|-------------|
| Improving | latest > avg(prior) | Score is trending upward |
| Declining | latest < avg(prior) - 5 | Score is trending downward by more than noise |
| Stable | abs(latest - avg(prior)) <= 5 | Score is within normal variance |

### Alert Thresholds

| Alert Type | Condition | Severity |
|------------|-----------|----------|
| Sharp Decline | Score dropped > 10 points between consecutive snapshots | High |
| Below Fail | Score < 50 | High |
| Crossed Threshold | Score moved from PASS (>= 80) to WARN (< 80) | Medium |
| Test Regression | Test pass rate declined while test count remained the same or increased | Medium |
| Build Broke | Build score went from 100 to 0 | High |
| Dependency Bloat | Production dependencies increased by > 5 since last snapshot | Low |

### Velocity Calculation

```
velocity = (latest_score - earliest_score) / (number_of_snapshots - 1)
```

Interpretation:
- velocity > 2: Rapidly improving
- velocity > 0: Gradually improving
- velocity = 0: Flat
- velocity < 0: Gradually declining
- velocity < -2: Rapidly declining

---

## Metric Collection Commands

Commands for different package managers and test frameworks. The skill should detect the project setup and use the appropriate command.

### TypeScript Compilation

| Package Manager | Command |
|----------------|---------|
| npm | `npx tsc --noEmit 2>&1 \| tail -5` |
| pnpm | `pnpm exec tsc --noEmit 2>&1 \| tail -5` |
| yarn | `yarn tsc --noEmit 2>&1 \| tail -5` |

**Prerequisite check**: `[ -f tsconfig.json ] && echo "FOUND" || echo "NOT FOUND"`

### Linting

| Package Manager | Command |
|----------------|---------|
| npm | `npx eslint . --format json 2>&1` |
| pnpm | `pnpm exec eslint . --format json 2>&1` |
| yarn | `yarn eslint . --format json 2>&1` |

**Prerequisite check**: `[ -f .eslintrc* ] || [ -f eslint.config.* ] && echo "FOUND" || echo "NOT FOUND"`

### Test Runners

| Runner | Command | JSON Output Flag |
|--------|---------|-----------------|
| Vitest | `npx vitest run --reporter=json 2>&1` | Built-in JSON reporter |
| Jest | `npx jest --json 2>&1` | Built-in JSON output |
| Vitest (pnpm) | `pnpm exec vitest run --reporter=json 2>&1` | Same |
| Jest (pnpm) | `pnpm exec jest --json 2>&1` | Same |

**Detection**:
```bash
if grep -q '"vitest"' package.json 2>/dev/null; then echo "vitest"
elif grep -q '"jest"' package.json 2>/dev/null; then echo "jest"
else echo "unknown"
fi
```

### Build

| Package Manager | Command |
|----------------|---------|
| npm | `npm run build 2>&1` |
| pnpm | `pnpm run build 2>&1` |
| yarn | `yarn build 2>&1` |

**Prerequisite check**: `node -e "const p=require('./package.json'); console.log(p.scripts?.build ? 'FOUND' : 'NOT FOUND')"`

---

## Score Calculation Details

### Per-Metric Scores

| Metric | Formula | Range | Notes |
|--------|---------|-------|-------|
| TypeScript | `max(0, 100 - errors * 2)` | 0-100 | Each error costs 2 points |
| Lint | `max(0, 100 - errors * 5 - warnings * 1)` | 0-100 | Errors penalized 5x, warnings 1x |
| Tests | `(passed / total) * 100` | 0-100 | Skipped tests excluded from total |
| Build | `exit_code === 0 ? 100 : 0` | 0 or 100 | Binary pass/fail |
| Completeness | Imported from `/blitz:review --only completeness` skill | 0-100 | null if not available |

### Overall Score

```
non_null_scores = [s for s in scores.values() if s is not null]
overall_score = sum(non_null_scores) / len(non_null_scores) if non_null_scores else null
```

Round to one decimal place.

### Weighted Overall Score (Optional)

If the user requests weighted scoring, apply these default weights:

| Metric | Weight | Rationale |
|--------|--------|-----------|
| TypeScript | 1.5 | Type safety is foundational |
| Lint | 1.0 | Code style and common errors |
| Tests | 2.0 | Test coverage is critical |
| Build | 1.5 | Build must always pass |
| Completeness | 1.0 | Feature completeness tracking |

```
weighted_score = sum(score * weight for score, weight in pairs if score is not null) / sum(weight for score, weight in pairs if score is not null)
```

---

## Snapshot Filename Conventions

| Pattern | Usage |
|---------|-------|
| `docs/metrics/YYYY-MM-DD.json` | Primary snapshot for the date |
| `docs/metrics/YYYY-MM-DD-N.json` | Nth additional snapshot on the same date |
| `docs/metrics/dashboard.md` | Latest dashboard (overwritten each time) |
| `docs/metrics/trend-report.md` | Latest trend report (overwritten each time) |

### Filename Collision Handling

If `docs/metrics/YYYY-MM-DD.json` already exists:
1. Check if it was created in the current session (same SESSION_ID in metadata).
2. If same session, overwrite (re-run scenario).
3. If different session, append counter: `YYYY-MM-DD-2.json`, `YYYY-MM-DD-3.json`, etc.
