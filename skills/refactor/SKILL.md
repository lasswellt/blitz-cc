---
name: refactor
description: "Performs safe, incremental refactoring with test verification after every step. Snapshots test results, refactors one piece at a time, and reverts if any test that was passing starts failing. Use when the user says 'refactor', 'extract', 'simplify', 'decompose', 'rename', 'restructure', or 'clean up'. NOT for behavior changes — those go through sprint-dev or fix-issue."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<target-file-or-module> <refactoring-goal>"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Refactor Skill

Perform safe, incremental refactoring of a target file or module. Every step is verified with type-checks and tests. Regressions are caught immediately and reverted. Execute every phase in order. Do NOT skip phases.

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

8. **NEVER leave placeholder code behind.** Refactored code must remain fully implemented. See [Definition of Done](/_shared/definition-of-done.md). No `TODO`, `FIXME`, `STUB`, or empty function bodies in the output.

---

## Phase 0: PARSE ARGUMENTS — Understand the Target

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Invocation

Extract from `$ARGUMENTS`:
- **Target**: File path or module name to refactor
- **Goal**: What refactoring to perform (extract, simplify, decompose, rename, restructure, etc.)

If the target is ambiguous, search for it:
```bash
# Search for the target file
find . -name "<target>*" -not -path '*/node_modules/*' -not -path '*/.git/*' | head -20
```

### 0.2 Validate Target Exists

Read the target file. If it does not exist, inform the user and stop.

### 0.3 Classify Refactoring Type

Determine the refactoring category:

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

### 1.1 Detect Test and Type-Check Commands

Find the project's verification commands:
```bash
# Check package.json for scripts
cat package.json | grep -E '"(test|type-check|typecheck|tsc|lint)"'
```

Determine:
- **Type-check command**: `npm run type-check`, `npx tsc --noEmit`, `pnpm type-check`, etc.
- **Test command**: `npm test`, `npx vitest run`, `npx jest`, `pnpm test`, etc.
- **Lint command** (optional): `npm run lint`, etc.

If no test command is found, warn the user: "No test runner detected. Refactoring will be verified by type-check only. Consider running `test-gen` first."

### 1.2 Run Baseline Tests

```bash
# Run type-check
<TYPE_CHECK_CMD> 2>&1 | tail -30

# Run tests (if available)
<TEST_CMD> 2>&1 | tail -50
```

Record:
- **Baseline type errors**: Count and list (some may be pre-existing)
- **Baseline test results**: Total, passed, failed, skipped
- **Pre-existing failures**: Any tests that fail BEFORE refactoring (these are excluded from regression detection)

### 1.3 Snapshot File State

Record the current state of the target file and its immediate dependents:
```bash
git diff HEAD --stat  # Check for uncommitted changes
git stash list        # Check for stashes
```

If there are uncommitted changes in the target file, warn the user: "Target file has uncommitted changes. Consider committing first so refactoring changes are isolated."

### 1.4 Identify Target File Metrics

Read the target file and record:
- **Line count**: Total lines
- **Export count**: Number of exported functions/types/classes
- **Cyclomatic complexity estimate**: Nesting depth, branch count
- **Import count**: Number of imports

These metrics guide the refactoring plan and serve as before/after comparison.

---

## Phase 2: ANALYZE — Map Dependencies

### 2.1 Find All Dependents

Search for files that import from the target:
```bash
# Search for imports of the target file (adapt to project path conventions)
grep -r "from.*<target-module>" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" --include="*.jsx" -l .
```

Record every file that imports from the target. These are the files that could break.

### 2.2 Find All Dependencies

Read the target file's imports. Categorize:
- **External packages**: Third-party libraries (low risk to refactoring)
- **Internal shared**: Shared utilities, types, constants (may need updates)
- **Internal siblings**: Files in the same module (likely need coordinated changes)

### 2.3 Map Public API Surface

List everything the target exports:
- Functions (with signatures)
- Types/interfaces
- Constants
- Default export
- Re-exports

This is the contract that must be preserved (unless the goal is specifically to change it).

### 2.4 Identify Test Files

Find tests that cover the target:
```bash
# Common test file patterns
find . -name "<target-name>.test.*" -o -name "<target-name>.spec.*" -o -name "<target-name>_test.*" | grep -v node_modules
# Also search test directories
grep -r "<target-module>" --include="*.test.*" --include="*.spec.*" -l . | grep -v node_modules
```

Read the test files to understand:
- What behaviors are tested
- What mocking patterns are used
- What assertions exist (these define the behavioral contract)

---

## Phase 2.5: RESEARCH PATTERNS — Study Similar Code

Before planning the refactoring, research how similar code is structured elsewhere in the project.

### 2.5.1 Find Similar Files

Search for files with similar responsibilities to the target:
```bash
# Files in the same directory or with similar names/patterns
find . -path '*/$(dirname <target>)/*' -name '*.ts' -o -name '*.vue' | grep -v node_modules | head -15
```

### 2.5.2 Read Exemplar Files

Read 2-3 of the cleanest/smallest files that do similar work. Note:
- **Organization**: How are functions ordered? Public API first or last?
- **Dependency injection**: How are external dependencies handled?
- **Public API structure**: What is exported and how?
- **Function size**: How large are individual functions?
- **Error handling**: How are errors caught and propagated?

### 2.5.3 Document Refactoring Target Pattern

Write a brief "REFACTORING TARGET PATTERN" that describes the ideal structure based on the exemplar files. This pattern guides every step in Phase 3.

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

Decompose the refactoring goal into atomic steps. Each step must be:
- **Independent**: Can be verified on its own
- **Reversible**: Can be reverted without affecting other steps
- **Small**: Changes 1-3 files at most
- **Behavior-preserving**: Does not change what the code does, only how it is structured

### 3.2 Order Steps by Risk

Order steps from lowest risk to highest risk:

| Priority | Step Type | Risk | Example |
|----------|-----------|------|---------|
| 1 | Add new code (no changes to existing) | Lowest | Create new utility file |
| 2 | Move code to new location + re-export from original | Low | Extract function, re-export |
| 3 | Update internal references | Low | Change internal imports |
| 4 | Update external references (dependents) | Medium | Update consumer imports |
| 5 | Remove old code / re-exports | Medium | Clean up original file |
| 6 | Rename public API symbols | Highest | Change function names |

### 3.3 Write Refactoring Plan

Produce a numbered plan:
```
Refactoring Plan for: <target>
Goal: <goal>
Steps: <N>
Estimated risk: <Low | Medium | High>

Step 1: <description>
  Files: <list>
  Risk: <Low | Medium | High>

Step 2: <description>
  Files: <list>
  Risk: <Low | Medium | High>

...
```

### 3.4 Announce Plan

Present the plan to the user in the output. This gives them visibility before changes begin.

---

## Phase 4: EXECUTE — Incremental Refactoring with Verification

### For Each Step in the Plan:

#### 4.1 Execute the Step

Make the code changes for this step only. Follow the principle of least change.

#### 4.2 Verify — Type-Check

```bash
<TYPE_CHECK_CMD> 2>&1 | tail -30
```

Compare against baseline:
- **No new type errors** — Proceed.
- **New type errors** — Fix them if they are mechanical (missing imports, updated paths). If they indicate a logic problem, revert the step.

#### 4.3 Verify — Tests

```bash
<TEST_CMD> 2>&1 | tail -50
```

Compare against baseline:
- **Same or better results** — Proceed.
- **New failures** — This is a regression. See "Regression Protocol" below.

#### 4.4 Record Step Completion

Log:
```
Step <N>/<total>: <description>
  Type-check: PASS (same as baseline) / PASS (N pre-existing errors)
  Tests: PASS (<passed>/<total>, same as baseline)
  Files changed: <list>
```

#### 4.5 Git Checkpoint (if in a git repo)

After each successful step, create a checkpoint:
```bash
git add -A
git stash push -m "refactor-checkpoint-step-<N>"
git stash pop
```

This allows reverting individual steps if a later step fails.

### Regression Protocol

If a step introduces test failures:

1. **Identify the failing tests.** Are they testing the refactored code or unrelated?
2. **If testing refactored code:**
   - The refactoring step changed behavior. This is a bug in the refactoring.
   - **Revert the step.** Restore files to their state before this step.
   - **Re-run tests** to confirm the revert fixed the regression.
   - **Re-plan the step.** Find an alternative approach that preserves behavior.
   - **If the step cannot be done without regression**, skip it and note it in the report.
3. **If unrelated:**
   - These are flaky tests or pre-existing issues. Confirm by checking baseline results.
   - If they were passing in the baseline, treat as a regression and revert.

**Hard abort**: If 3 consecutive steps fail verification, stop the refactoring and report to the user.

---

## Phase 5: VERIFY — Full Verification Pass

### 5.1 Final Type-Check

Run a full type-check from the project root:
```bash
<TYPE_CHECK_CMD> 2>&1
```

Compare error count against baseline. New errors are regressions.

### 5.2 Final Test Run

Run the full test suite:
```bash
<TEST_CMD> 2>&1
```

Compare against baseline. The results must be equal or better (no new failures).

### 5.3 Final Lint (if available)

```bash
<LINT_CMD> 2>&1 | tail -30
```

Fix any lint errors introduced by the refactoring.

### 5.4 Metrics Comparison

Compare before/after metrics for the target:

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
| Large structural change | `codebase-audit` | Check for architectural issues introduced |

---

## Error Recovery

- **No test runner found**: Proceed with type-check-only verification. Warn that behavioral regressions may go undetected.
- **Baseline tests already failing**: Record pre-existing failures. Only new failures count as regressions.
- **Target file has no tests**: Warn the user. Suggest running `test-gen` on the target first, then re-running the refactoring.
- **Circular dependency detected during analysis**: Report the cycle. Suggest breaking the cycle as a prerequisite step.
- **Refactoring goal is too broad**: Break it into multiple runs. Suggest doing the first sub-goal now and the rest as follow-ups.
