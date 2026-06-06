---
name: fix-issue
description: "Resolves GitHub issues end-to-end: fetches issue context via gh CLI, researches root cause, implements fix with regression tests, and updates the issue with a closing comment. Use when the user says 'fix issue #N', 'resolve issue', 'work on issue', 'pick up issue', or pastes a GitHub issue URL. Independent of sprint-dev — for one-off bugs not in the sprint plan."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<issue-number>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Fix Issue Skill

Resolve a GitHub issue end-to-end: fetch context, identify root cause, implement a minimal fix, verify, and update the issue. Execute every phase in order. Do NOT skip phases.

---

All code produced must satisfy the [Definition of Done](/_shared/sprint-contracts.md). No placeholder implementations.

## SAFETY RULES (NON-NEGOTIABLE)

1. **NEVER introduce unrelated changes.** Fix only what the issue describes. No drive-by refactoring.
2. **NEVER modify tests to make them pass.** If tests fail, the fix is wrong.
3. **ALWAYS verify with type-check, tests, and build** before committing.
4. **NEVER push to main/master directly.** Work on a feature branch.
5. **ALWAYS use conventional commit format** for the fix commit.

---

## Phase 0: FETCH ISSUE — Load Context from GitHub

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Arguments

Extract the issue number from `$ARGUMENTS`. If not provided, ask the user.

### 0.2 Detect Repository

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
  echo "ERROR: Not in a GitHub repository or gh CLI not authenticated."
  echo "Run 'gh auth login' first."
fi
echo "Repository: ${REPO}"
```

### 0.3 Fetch Issue Details

```bash
gh issue view $ISSUE_NUMBER --json title,body,labels,assignees,comments,state,milestone
```

Extract and record:
- **Title**: The issue title
- **Body**: Full description
- **Labels**: Issue labels (bug, feature, priority, etc.)
- **Comments**: Any discussion with additional context
- **State**: Should be `open` (warn if closed)
- **Milestone**: Sprint or version context

### 0.4 Classify Issue

Determine the issue type from labels and content:

| Type | Indicators | Approach |
|------|-----------|----------|
| **Bug** | `bug` label, "error", "crash", "broken", "not working" | Find and fix the defect |
| **Regression** | "used to work", "after update", "since version" | Find what changed |
| **Performance** | `performance` label, "slow", "timeout", "memory" | Profile and optimize |
| **Feature gap** | `enhancement` label, "should support", "add ability" | Implement minimal feature |
| **Configuration** | "config", "environment", "setup" | Fix configuration |

### 0.5 Extract Reproduction Steps

From the issue body and comments, extract:
- Steps to reproduce (if provided)
- Expected behavior
- Actual behavior
- Error messages or stack traces
- Affected files or components (if mentioned)

---

## Phase 1: INVESTIGATE — Find Root Cause

### 1.1 Search for Affected Code

Based on the issue description, search the codebase:

```bash
# Search for error messages mentioned in the issue
grep -r "<error-message-fragment>" --include="*.ts" --include="*.vue" --include="*.js" -l .

# Search for component/module names mentioned
grep -r "<component-name>" --include="*.ts" --include="*.vue" --include="*.js" -l .

# Search for related files
find . -name "*<keyword>*" -not -path '*/node_modules/*' -not -path '*/.git/*' | head -20
```

### 1.2 Read Affected Files

Read each potentially affected file. For each, note:
- What it does
- How it relates to the issue
- Potential causes of the reported behavior

### 1.3 Trace the Problem

Follow the execution path:
1. Identify the entry point (route, event handler, API call)
2. Trace data flow through the affected code
3. Identify where behavior diverges from expected

### 1.4 Research (Mandatory or Optional Based on Conditions)

Research is **MANDATORY** when ANY of these are true:
- Issue involves third-party library behavior or API changes
- Error message is not directly traceable to project code
- Issue mentions a version update/migration as trigger
- Root cause confidence after Phase 1.3 is Medium or Low
- Issue has been open for more than 7 days

Research is **OPTIONAL** only when ALL are true:
- Root cause confidence is High
- Fix is a clear few-line change in project code
- No third-party behavior involved

When skipping research, document **WHY** it was skipped.

When research is needed, spawn a research subagent with `subagent_type: general-purpose` (the agent MUST Write the findings file — never use `Explore`). Weight class: Light.
```
You are a general-purpose research subagent investigating a bug. You have
Write access; your task is INCOMPLETE if the output file does not exist.

ISSUE: <issue title and description>
ERROR: <error message if available>
STACK: <detected stack profile>

TASKS:
1. Search for known issues with the library/API involved.
2. Check if there are documented workarounds.
3. Check for recent version changes that could cause this.
4. Write findings to ${SESSION_TMP_DIR}/issue-research.md — stub the file
   at start, append findings as you discover them.

LIMITS (Light class, per agent-orchestration.md):
- Max 5 web searches
- Max 8 file reads
- Max 150-line output
- 3-minute wall-clock budget

Focus on the specific error, not general background.
```

**Before reading issue-research.md for root cause analysis, validate output**:

```bash
RESEARCH_FILE="${SESSION_TMP_DIR}/issue-research.md"
if [ ! -s "$RESEARCH_FILE" ]; then
  echo "WARNING: research subagent did not produce output" >&2
  # Log to .cc-sessions/activity-feed.jsonl
  # Downgrade root cause confidence to Low and request user confirmation
  # before proceeding to Phase 2 implementation.
  CONFIDENCE="Low"
  RESEARCH_SKIPPED=true
fi
```

Do NOT proceed to Phase 2 implementation based on missing/empty research output. Either retry with narrower scope (one specific error), or ask the user to confirm the next step with reduced confidence.

### 1.5 Identify Root Cause

Produce a root cause analysis:
```
Root Cause Analysis
===================
Issue: #<number> — <title>
Cause: <1-2 sentence explanation of why the bug occurs>
Location: <file:line>
Mechanism: <how the bug manifests — data flow, timing, etc.>
Confidence: <High | Medium | Low>
```

If confidence is Low, note what additional information would help and ask the user.

---

## Phase 2: IMPLEMENT — Apply Minimal Fix

### 2.1 Create Feature Branch

```bash
git checkout -b fix/<issue-number>-<short-description>
```

If the branch already exists:
```bash
git checkout fix/<issue-number>-<short-description>
```

### 2.2 Plan the Fix

Before writing code, plan:
- **What to change**: Specific files and specific changes
- **What NOT to change**: Related code that is not part of this fix
- **Edge cases**: Does the fix handle all variants of the reported issue?
- **Backward compatibility**: Does the fix break any existing behavior?

### 2.3 Implement the Fix

Apply the minimal set of changes to resolve the issue. Follow these principles:
- **Smallest possible change.** If a one-line fix works, do not restructure the function.
- **Follow existing patterns.** Match the coding style, naming conventions, and error handling patterns of the surrounding code.
- **Add defensive guards** where appropriate (null checks, type guards, bounds checks).
- **Do not add unrelated improvements.** Even if you notice other issues, they are separate tasks.

### 2.4 Add Inline Comment (if non-obvious)

If the fix is not self-explanatory, add a brief comment:
```typescript
// Fix: Guard against undefined when X is not yet loaded (fixes #<number>)
```

---

## Phase 3: VERIFY — Confirm the Fix

### 3.1 Type-Check

```bash
# Detect and run the project's type-check command
<TYPE_CHECK_CMD> 2>&1 | tail -30
```

If there are new type errors, fix them before proceeding.

### 3.2 Run Tests

```bash
# Run the full test suite or relevant subset
<TEST_CMD> 2>&1 | tail -50
```

- **All tests pass** — Proceed.
- **Pre-existing failures** — Note them but proceed.
- **New failures** — The fix introduced a regression. Revise the fix.

### 3.3 Build Check

```bash
# Run the project's build command
<BUILD_CMD> 2>&1 | tail -30
```

If the build fails with new errors, fix them.

### 3.3.5 Completeness Check

Run the completeness gate on all files modified by the fix:
```bash
CHANGED_FILES=$(git diff --name-only HEAD~1 -- '*.ts' '*.tsx' '*.vue')
```
Invoke: `/blitz:review --only completeness` scoped to the changed files.
If any **critical** findings exist in the changed files, fix them before proceeding. Medium/low findings are acceptable for a targeted bug fix.

### 3.4 Manual Verification (if reproduction steps are available)

If the issue included clear reproduction steps, describe how the fix addresses each step:
```
Verification:
  Step 1: <original step> — Now: <expected result confirmed because X>
  Step 2: <original step> — Now: <expected result confirmed because Y>
```

---

## Phase 4: COMMIT AND REPORT — Finalize

### 4.1 Stage and Commit

Stage only the files related to the fix:
```bash
git add <specific-files>
git commit -m "$(cat <<'EOF'
fix(<scope>): <short description> (fixes #<issue-number>)

<1-2 sentence explanation of what was wrong and how the fix addresses it.>
EOF
)"
```

**Commit message format:**
- **Type**: `fix` (always for bug fixes)
- **Scope**: The module or area affected (e.g., `auth`, `api`, `ui`, `store`)
- **Description**: Imperative mood, lowercase, no period (e.g., `handle undefined user profile on dashboard`)
- **Footer**: `fixes #<issue-number>` to auto-close the issue when merged

### 4.2 Update GitHub Issue

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Field **labels** preserved verbatim (downstream parsers grep them). Field **values** compress to fragments. Preserve verbatim: file paths, branch names, verification-check pass/fail tokens. **LITE intensity** required for **Root Cause** — the reasoning chain must survive ("undefined because foo unset on cold start, caused by bar in baz.ts"). Drop the trailing "Ready for review and merge." line — filler.

Post a comment on the issue with the fix details:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BRANCH=$(git branch --show-current)

gh issue comment $ISSUE_NUMBER --body "$(cat <<'EOF'
## Fix Applied

**Branch**: `<branch-name>`
**Root Cause**: <1-fragment root cause with file:line ref; LITE intensity — reasoning must survive>
**Fix**: <1-fragment change + file:line refs>
**Files Changed**:
- `<file1>`: <what changed>
- `<file2>`: <what changed>

**Verification**:
- Type-check: PASS
- Tests: PASS (<N> passed)
- Build: PASS
EOF
)"
```

### 4.3 Output Summary

```
Issue #<number> Fixed
=====================
Title: <issue title>
Root Cause: <brief explanation>
Fix: <brief description>
Branch: fix/<issue-number>-<short-description>
Commit: <commit hash>
Files changed: <count>

Verification:
  Type-check: PASS
  Tests: PASS
  Build: PASS

GitHub issue updated with fix details.
```

### 4.4 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Fix touched code with low test coverage | `test-gen` | Generate tests for the fixed area |
| Fix involved UI changes | `browse` | Smoke test the affected pages |
| Fix was a workaround, not a proper solution | `refactor` | Refactor the area for a cleaner fix |
| Related issues exist | `fix-issue` | Fix related issues in sequence |

---

## Error Recovery

- **`gh` CLI not installed or not authenticated**: Skip GitHub integration (issue fetch, comment). Ask the user to describe the issue manually. Skip the issue comment at the end.
- **Issue is closed**: Warn the user. Ask if they want to proceed anyway (it may be a re-opened issue).
- **Issue has no reproduction steps**: Rely on code analysis to identify the root cause. Note lower confidence in the fix.
- **Root cause cannot be determined**: Report findings so far and ask the user for more context. Do NOT guess and apply a speculative fix.
- **Fix causes test regressions**: Revert and try an alternative approach. If no alternative works after 3 attempts, report the regression details to the user.
- **Build fails after fix**: Check if the build failure is pre-existing. If new, fix build errors before committing.
- **Multiple possible root causes**: Document all candidates, rank by likelihood, and fix the most likely one. Note alternatives in the issue comment.
