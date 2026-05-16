---
name: completeness-gate
description: "Scans code for placeholder patterns (TODO/FIXME/STUB/PLACEHOLDER), incomplete implementations (`return {}`, `throw new Error('Not implemented')`), and other production-readiness issues. Returns structured findings with file:line refs. Use when the user says 'check completeness', 'scan for placeholders', 'find unfinished code', 'production readiness', or as an automatic gate before /blitz:ship."
allowed-tools: Read, Bash, Glob, Grep
model: sonnet
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<scope: path or 'all'>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For grep patterns, severity rules, and output schemas, see [references/main.md](references/main.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** severity:critical + category:security `message` field (security-finding prose). Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Production Completeness Gate

Scan code for placeholder patterns, incomplete implementations, and anti-mock violations. Produce a structured findings report. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

1. **This skill is READ-ONLY** — never modify source files, test files, or configuration files.
2. **Never skip checks or ignore findings** — run all 11 check categories against all files in scope.
3. **Report ALL violations** — even in test files (tagged with `"in_test": true` in findings).
4. **Never suppress findings** — unless an explicit override exists in `.completeness-gate.json`.
5. **Never execute source code** — only read and grep. No `node`, `tsx`, or `npx` execution of project code.

---

## Phase 0: PARSE — Understand Scope

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Arguments

Extract the scope argument from `$ARGUMENTS`:
- A file path (e.g., `src/stores/auth.ts`) — scan that single file
- A directory path (e.g., `src/stores/`) — scan all files in that directory recursively
- `all` or no argument — scan all standard source directories

When scope is `all`, scan these directories (whichever exist):
```
src/ pages/ components/ composables/ stores/ functions/ server/ lib/ utils/ api/ middleware/
```

### 0.2 Validate Scope

```bash
# Verify the scope path exists
[ -e "<scope-path>" ] && echo "SCOPE VALID" || echo "SCOPE NOT FOUND"
```

If scope is invalid, inform the user and stop.

---

## Phase 1: DISCOVER — Build File List

### 1.1 Collect Target Files

Use Glob to find all source files in scope:
```
*.ts, *.tsx, *.js, *.jsx, *.vue
```

Exclude these directories:
```
node_modules, dist, .nuxt, .output, coverage, .cc-sessions, __snapshots__
```

### 1.2 Separate Source and Test Files

Classify files into two groups:
- **Source files**: Files NOT matching `*.test.*`, `*.spec.*`, or located in `__tests__/`
- **Test files**: Files matching `*.test.*`, `*.spec.*`, or located in `__tests__/`

### 1.3 Report File Counts

Print: `"Scanning N source files + M test files in <scope>"`

---

## Phase 2: SCAN — Run All Checks

Run all 11 check categories against target files. For each violation, record a finding object:

```json
{
  "check_id": "<check-id>",
  "severity": "<critical|high|medium|low>",
  "file": "<relative-path>",
  "line": 0,
  "snippet": "<matching line trimmed>",
  "message": "<human-readable explanation>",
  "in_test": false
}
```

Use the exact grep patterns from [references/main.md](references/main.md) for each check.

### 2.1 Placeholder Returns

Grep for `return\s*\{\s*\}`, `return\s*\[\s*\]`, and `return\s*null` in non-utility source files. Filter out legitimate patterns (guard clauses, explicit null returns documented with comments).

**Check ID**: `placeholder-returns`

### 2.2 Not-Implemented Throws

Grep for throw statements containing placeholder messages:
```
throw new Error(['"](?:Not implemented|TODO|not yet|NYI|FIXME|PLACEHOLDER)
```
Case-insensitive match.

**Check ID**: `not-implemented-throws`

### 2.3 Empty Function Bodies

Grep for functions and methods with empty bodies — opening brace, optional whitespace or single-line comments only, closing brace. Exclude intentional no-ops (event handler type stubs in interfaces, abstract method declarations).

**Check ID**: `empty-function-bodies`

### 2.4 TODO/FIXME/STUB Comments

Grep for annotation comments in source files:
```
//\s*(TODO|FIXME|PLACEHOLDER|STUB|HACK|XXX):?\s
```

**Check ID**: `todo-fixme-comments`

### 2.5 Empty Catch Blocks

Grep for catch blocks with empty bodies:
```
catch\s*\([^)]*\)\s*\{\s*\}
```

**Check ID**: `empty-catch-blocks`

### 2.6 Log-and-Return Functions

Identify functions whose body consists solely of `console.log`/`console.warn`/`console.error` calls optionally followed by a return statement. These indicate stub implementations.

**Check ID**: `log-and-return`

### 2.7 No-Op Event Handlers

Grep for empty arrow functions used as event handlers:
```
\(\)\s*=>\s*\{\s*\}
() => {}
```
Exclude test files and mock setups.

**Check ID**: `noop-handlers`

### 2.8 Hardcoded Sample Data

Grep for large inline object arrays in non-test, non-fixture, non-seed files. Look for patterns like:
```
const\s+\w+\s*=\s*\[.*\{
```
Flag arrays of 3+ inline objects with property names like `name`, `title`, `id`, `label` that suggest sample/placeholder data.

**Check ID**: `hardcoded-sample-data`

### 2.9 Console.log Leftovers

Grep for `console\.log\(` in source files. Exclude files in `logger/`, `logging/`, or files named `logger.*`.

**Check ID**: `console-log-leftovers`

### 2.10 Three-State UI Coverage

For `.vue` files that contain data-fetching patterns (`useAsyncData`, `useFetch`, `useLazyFetch`, store action calls, `$fetch`), check that the template also contains:
- Loading state handling (e.g., `v-if` with `loading`, `pending`, `isLoading`)
- Error state handling (e.g., `v-if` with `error`, `isError`)

Flag files that fetch data but lack either loading or error states.

**Check ID**: `three-state-ui`

### 2.11 End-to-End Wiring

Scan store files (files in `stores/` or files using `defineStore`) for actions that do not call any API/service function. Look for action methods that lack `fetch`, `$fetch`, `axios`, `httpsCallable`, `api.`, or service function calls.

**Check ID**: `unwired-store-actions`

### 2.12 Artifact Verification (Three-Level)

When invoked with sprint context (sprint directory path or after sprint-dev), run three-level artifact verification on files listed in story frontmatter:

**Level 1 — Existence:** Verify every file listed in story `files` fields actually exists.
```bash
# For each file in story frontmatter 'files' list
[ -f "<file-path>" ] && echo "L1 PASS: <file>" || echo "L1 FAIL: <file> — missing"
```

**Level 2 — Substantive:** Verify files are not stubs. Each file must:
- Be longer than 5 lines
- Pass all existing completeness-gate checks (2.1–2.11)
- Not consist solely of type re-exports or empty class declarations

**Level 3 — Wired:** Verify files are imported/used by at least one other file. Exclude entry points (pages, route handlers, main files) from this requirement.
```bash
# For each non-entry-point file, check for at least one importer
IMPORTERS=$(grep -rl "from.*<module-name>" --include="*.ts" --include="*.vue" . | grep -v node_modules | grep -v "<file-itself>")
[ -n "$IMPORTERS" ] && echo "L3 PASS: <file>" || echo "L3 FAIL: <file> — no importers"
```

**Check ID**: `artifact-verification`

Level 1 failures are **Critical**. Level 2 failures follow existing severity rules. Level 3 failures are **Medium** (orphaned files may be intentional for new features not yet integrated).

### 2.13 Env-Var Fallbacks Hiding Config Errors

Scan source files for env-var dereferences with a string-literal fallback near credential-named identifiers. The pattern `process.env.X || ''` (or `??`) silently masks missing-config bugs at runtime — the app comes up "fine" with empty creds and fails confusingly later.

```bash
grep -rEn '(process\.env\.[A-Z_]+|import\.meta\.env\.[A-Z_]+)\s*(\|\||\?\?)\s*['\''"][^'\''"]*['\''"]' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' --include='*.js' \
  | grep -iE 'password|secret|key|token|credential|host|port|url|endpoint|database|db_|api_'
```

**Severity**: each match Major. **Escape hatch**: inline `// blitz:fallback-allowed: <reason>` on the same line (the user explicitly intends the fallback, e.g., dev defaults that are clearly non-production).

**Check ID**: `env-fallback`

### 2.14 Hardcoded localhost / Ports / URLs

Scan source files for hardcoded `localhost`, `127.0.0.1`, `0.0.0.0`, or 4–5-digit ports outside test fixtures. These leak from local dev into shipped code and break in any non-local environment.

```bash
grep -rEn '(https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)|:[0-9]{4,5}\b)' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' --include='*.js' \
  --exclude-dir=__tests__ --exclude='*.test.*' --exclude='*.spec.*'
```

Allow:
- Files that match `vite.config.*`, `*.dev.*`, `dev/*` (genuine dev config).
- Lines containing `// blitz:localhost-allowed: <reason>` (dev tooling hot-reload, etc.).

**Severity**: each match Major in `src/**`, Minor in `scripts/**` and `dev/**`.

**Check ID**: `hardcoded-localhost`

---

## Phase 3: ANALYZE — Classify and Score

### 3.1 Severity Classification

Apply these severity rules to all findings:

| Severity | Criteria |
|----------|----------|
| **Critical** | Not-implemented throws in non-test code, empty function bodies in business logic (stores, API handlers, middleware) |
| **High** | Placeholder returns in business logic, TODO/FIXME in store actions or API handlers, no-op handlers bound to user interactions, unwired store actions |
| **Medium** | Console.log leftovers, hardcoded sample data, missing three-state UI, empty catch blocks |
| **Low** | TODO comments in utilities or helpers, no-op handlers in non-critical paths |

Test file findings are always capped at **Low** severity regardless of the check.

### 3.2 Check for Overrides

Look for `.completeness-gate.json` in the project root. If found, parse it and apply overrides:

```json
{
  "ignore": {
    "files": ["path/to/legacy/**"],
    "checks": ["console-log-leftovers"],
    "inline": "completeness-ignore"
  }
}
```

- **files**: Glob patterns for files to exclude entirely
- **checks**: Check IDs to skip
- **inline**: Comment marker that suppresses the finding on that line

Remove any findings that match override rules. Record the count of suppressed findings.

If `.completeness-gate.json` is not found, proceed without overrides.
If it contains invalid JSON, warn and proceed without overrides.

### 3.3 Calculate Score

```
score = 100 - (critical_count * 10) - (high_count * 5) - (medium_count * 2) - (low_count * 0.5)
```

Clamp to range 0-100.

Assign grade:
| Score | Grade |
|-------|-------|
| 90-100 | A |
| 80-89 | B |
| 70-79 | C |
| 60-69 | D |
| < 60 | F |

---

## Phase 4: REPORT — Output Findings

### 4.1 Write JSON Report

Write the structured report to `${SESSION_TMP_DIR}/completeness-gate.json`:

```json
{
  "timestamp": "<ISO-8601>",
  "scope": "<scanned scope>",
  "files_scanned": { "source": 0, "test": 0 },
  "score": 0,
  "grade": "A",
  "summary": { "critical": 0, "high": 0, "medium": 0, "low": 0, "total": 0, "suppressed": 0 },
  "findings": [
    {
      "check_id": "placeholder-returns",
      "severity": "high",
      "file": "src/stores/auth.ts",
      "line": 42,
      "snippet": "return {}",
      "message": "Placeholder empty object return in store action",
      "in_test": false
    }
  ]
}
```

### 4.2 Print Summary

Print a concise summary to the user:

```
Completeness Gate: <GRADE> (<score>/100)
  Critical: N | High: N | Medium: N | Low: N
  Files scanned: N source + N test
  Suppressed by overrides: N

Top issues:
  1. [severity] file:line - message
  2. [severity] file:line - message
  3. [severity] file:line - message
  4. [severity] file:line - message
  5. [severity] file:line - message
```

Show up to 10 top issues, ordered by severity (critical first) then by file path.

If score is 100, print:
```
Completeness Gate: A (100/100)
  No issues found. Code is production-ready.
```

### 4.3 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Critical or high findings in stores | `implement` | Complete the stub implementations |
| Missing three-state UI | `ui-build` | Add loading/error state handling |
| TODO comments reference issues | `fix-issue` | Resolve the referenced issues |
| Low score (< 70) | `codebase-audit` | Full quality audit recommended |

### 4.4 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Append `session_end` to the operations log

---

## Error Recovery

- **No files found in scope**: Report "No files in scope" with score 100 and grade A. No findings.
- **Grep command fails**: Log the failed check, continue with remaining checks. Note incomplete coverage in report.
- **`.completeness-gate.json` is invalid JSON**: Warn `"Override file is invalid JSON — proceeding without overrides"` and continue.
- **`SESSION_TMP_DIR` is not available**: Fall back to printing the JSON report to stdout instead of writing to a file.
- **Scope directory does not exist**: Inform user `"Directory <path> does not exist"` and stop.
- **Permission denied on files**: Skip unreadable files, note them in the report summary.
