---
name: refactor
description: "Performs safe, incremental refactoring with test verification after every step. Snapshots test results, refactors one piece at a time, and reverts if any test that was passing starts failing. Use when the user says 'refactor', 'extract', 'simplify', 'decompose', 'rename', 'restructure', or 'clean up'. NOT for behavior changes — those go through sprint-dev or fix-issue."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<target-file-or-module> <refactoring-goal>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Refactor Skill

Safe, incremental refactoring of a target file or module. Every step is verified with type-checks and tests. Regressions are caught immediately and reverted. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER modify tests to make them pass.** If tests fail after a refactoring step, the step introduced a regression. Revert the code change, not the test.

2. **NEVER skip verification.** Every refactoring step must be followed by type-check + test run. No exceptions.

3. **NEVER combine multiple refactoring steps into one.** Each step is atomic and independently verifiable. If step 3 breaks, you can revert to the state after step 2.

4. **NEVER change public API signatures** unless that is the explicit refactoring goal. Consumers must not break.

5. **NEVER delete code that is referenced elsewhere** without updating all references first.

6. **ALWAYS preserve existing behavior.** Refactoring changes structure, not behavior. If behavior changes are needed, that is a separate task.

7. **ABORT on regression.** If a step introduces test failures that you cannot resolve by reverting the step, stop and report the issue to the user.

8. **NEVER leave placeholder code behind.** Refactored code must remain fully implemented. See [Definition of Done](/_shared/sprint-contracts.md). No `TODO`, `FIXME`, `STUB`, or empty function bodies in the output.

---

## Phase 0: PARSE ARGUMENTS — Understand the Target

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Invocation

Extract from `$ARGUMENTS`:
- **Target**: File path or module name to refactor
- **Goal**: What refactoring to perform (extract, simplify, decompose, rename, restructure, etc.)

If target is ambiguous, search:
```bash
find . -name "<target>*" -not -path '*/node_modules/*' -not -path '*/.git/*' | head -20
```

Read the target file. If it does not exist, inform the user and stop.

### 0.2 Classify Refactoring Type

| Type | Description | Risk Level |
|------|-------------|------------|
| **Extract** | Pull code into a new function, composable, component, or module | Low |
| **Simplify** | Reduce complexity without changing structure | Low |
| **Decompose** | Split a large file into smaller files | Medium |
| **Rename** | Rename symbols across the codebase | Medium |
| **Restructure** | Move files, change module boundaries | High |
| **Consolidate** | Merge duplicated code into shared utilities | Medium |

---

## Phase 1: SNAPSHOT — Capture Baseline State

### 1.1 Detect Verification Commands

```bash
cat package.json | grep -E '"(test|type-check|typecheck|tsc|lint)"'
```

Determine:
- **Type-check command**: `npm run type-check`, `npx tsc --noEmit`, `pnpm type-check`, etc.
- **Test command**: `npm test`, `npx vitest run`, `npx jest`, `pnpm test`, etc.
- **Lint command** (optional): `npm run lint`, etc.

If no test command found, warn: "No test runner detected. Refactoring will be verified by type-check only. Consider running `test-gen` first."

### 1.2 Run Baseline Tests

```bash
<TYPE_CHECK_CMD> 2>&1 | tail -30
<TEST_CMD> 2>&1 | tail -50
```

Record: baseline type errors, test results (total/passed/failed/skipped), and pre-existing failures (excluded from regression detection).

### 1.3 Snapshot File State

```bash
git diff HEAD --stat
git stash list
```

If uncommitted changes in the target file, warn: "Target file has uncommitted changes. Consider committing first so refactoring changes are isolated."

### 1.4 Identify Target File Metrics

Read the target file and record: line count, export count, cyclomatic complexity estimate, import count. Used for before/after comparison.

---

## Phase 2: ANALYZE — Map Dependencies

### 2.1 Find All Dependents

```bash
grep -r "from.*<target-module>" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" --include="*.jsx" -l .
```

### 2.2 Find All Dependencies

Read the target's imports and categorize:
- **External packages**: Third-party libraries (low risk)
- **Internal shared**: Shared utilities, types, constants
- **Internal siblings**: Files in the same module

### 2.3 Map Public API Surface

List all exports: functions (with signatures), types/interfaces, constants, default export, re-exports. This is the contract that must be preserved.

### 2.4 Identify Test Files

```bash
find . -name "<target-name>.test.*" -o -name "<target-name>.spec.*" -o -name "<target-name>_test.*" | grep -v node_modules
grep -r "<target-module>" --include="*.test.*" --include="*.spec.*" -l . | grep -v node_modules
```

Read test files to understand: behaviors tested, mocking patterns, and assertions (the behavioral contract).

---

## Phase 2.5: RESEARCH PATTERNS — Study Similar Code

### 2.5.1 Find Similar Files

```bash
find . -path '*/$(dirname <target>)/*' -name '*.ts' -o -name '*.vue' | grep -v node_modules | head -15
```

### 2.5.2 Read Exemplar Files

Read 2-3 of the cleanest/smallest similar files. Note: organization, dependency injection, public API structure, function size, error handling.

### 2.5.3 Document Refactoring Target Pattern

```
TARGET PATTERN:
- Organization: <how to order functions and sections>
- Dependencies: <how to handle external deps>
- Public API: <what to export and how>
- Function size: <target max lines>
- Error handling: <pattern to follow>
```

---

## Phase 3: PLAN — Design Incremental Steps

### 3.1 Break Down the Refactoring

Each step must be: independent (verifiable on its own), reversible, small (1-3 files), behavior-preserving.

### 3.2 Order Steps by Risk

| Priority | Step Type | Risk |
|----------|-----------|------|
| 1 | Add new code (no changes to existing) | Lowest |
| 2 | Move code + re-export from original | Low |
| 3 | Update internal references | Low |
| 4 | Update external references (dependents) | Medium |
| 5 | Remove old code / re-exports | Medium |
| 6 | Rename public API symbols | Highest |

### 3.3 Write and Announce Refactoring Plan

```
Refactoring Plan for: <target>
Goal: <goal>
Steps: <N>
Estimated risk: <Low | Medium | High>

Step 1: <description>
  Files: <list>
  Risk: <Low | Medium | High>
...
```

Present the plan to the user before changes begin.

---

## Phase 4: EXECUTE — Incremental Refactoring with Verification

For each step in the plan:

1. **Execute the step** — minimal change only.
2. **Type-check**:
   ```bash
   <TYPE_CHECK_CMD> 2>&1 | tail -30
   ```
   No new type errors → proceed. New errors → fix mechanical ones (missing imports, paths); revert if logic problem.
3. **Run tests**:
   ```bash
   <TEST_CMD> 2>&1 | tail -50
   ```
   Same or better → proceed. New failures → Regression Protocol.
4. **Record step**:
   ```
   Step <N>/<total>: <description>
     Type-check: PASS (same as baseline) / PASS (N pre-existing errors)
     Tests: PASS (<passed>/<total>, same as baseline)
     Files changed: <list>
   ```
5. **Git checkpoint**:
   ```bash
   git add -A
   git stash push -m "refactor-checkpoint-step-<N>"
   git stash pop
   ```

### Regression Protocol

If a step introduces test failures:

1. **Identify failing tests.** Testing refactored code or unrelated?
2. **If testing refactored code:** refactoring changed behavior. Revert the step. Re-run tests to confirm fix. Re-plan with alternative approach. If unreachable without regression, skip and note in report.
3. **If unrelated:** confirm against baseline. If passing in baseline, treat as regression and revert.

**Hard abort**: 3 consecutive verification failures → stop and report to user.

---

## Phase 5: VERIFY — Full Verification Pass

### 5.1 Final Type-Check

```bash
<TYPE_CHECK_CMD> 2>&1
```

New errors vs. baseline = regressions.

### 5.2 Final Test Run

```bash
<TEST_CMD> 2>&1
```

Results must equal or improve baseline.

### 5.3 Final Lint (if available)

```bash
<LINT_CMD> 2>&1 | tail -30
```

Fix any lint errors introduced.

### 5.4 Metrics Comparison

```
Refactoring Metrics:
                    Before    After    Delta
  Line count:       <N>       <N>      <+/-N>
  Export count:     <N>       <N>      <+/-N>
  Complexity:       <N>       <N>      <+/-N>
  Import count:     <N>       <N>      <+/-N>
  Files affected:   —         <N>      —
```

---

## Phase 6: REPORT — Summarize Results

### 6.1 Output Summary

```
Refactoring Complete: <target>
==============================
Goal: <goal>
Steps completed: <N>/<total>
Steps skipped: <N> (regressions)
Type-check: PASS / FAIL
Tests: <passed>/<total> (baseline: <passed>/<total>)

Changes:
  - <file1>: <description of change>
  - <file2>: <description of change>
  ...

Metrics:
  Lines: <before> -> <after> (<delta>)
  Complexity: <before> -> <after> (<delta>)
```

### 6.2 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Refactored code has low test coverage | `test-gen` | Generate tests for the refactored module |
| Refactored a UI component | `browse` | Verify the component still renders correctly |
| Large structural change | `audit` | Check for architectural issues introduced |

---

## Error Recovery

- **No test runner found**: Proceed with type-check-only. Warn that behavioral regressions may go undetected.
- **Baseline tests already failing**: Record pre-existing failures. Only new failures count as regressions.
- **Target file has no tests**: Warn the user. Suggest running `test-gen` first, then re-running refactoring.
- **Circular dependency detected**: Report the cycle. Suggest breaking it as a prerequisite step.
- **Refactoring goal too broad**: Break into multiple runs. Suggest first sub-goal now, rest as follow-ups.
