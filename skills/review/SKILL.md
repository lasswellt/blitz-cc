---
name: review
description: "Runs the review phase of a sprint by routing to sprint-review. Use when the user says 'review sprint N', 'run quality gates', 'check the sprint', or asks to validate a completed sprint before shipping."
argument-hint: "[--sprint NNN] [--auto-fix] -- runs sprint-review quality gate (parallel reviewer agents + 7 invariants); --sprint targets a specific sprint number (defaults to current); --auto-fix dispatches sprint-dev to repair findings"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: low
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Sprint Review

You run the review phase of a sprint.

**Session registration**: follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration before any other work.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[review]` prefixed status lines at every phase transition, decision point, and when dispatching to sprint-review. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Flag Parsing

Parse the following flags from the user's arguments:

- `--sprint NNN`: Review the specified sprint number.
- `--auto-fix`: Automatically fix issues that the review identifies (when safe
  to do so).

If no sprint number is provided, review the most recent sprint or the current
set of uncommitted changes.

## Pre-Flight Validation

Before invoking sprint-review, verify:

1. **Sprint exists**: Read `sprint-registry.json` and confirm the target sprint has `status: review` or `status: in-progress`. If not found, inform the user and stop.
2. **Stories exist**: Verify story files exist in `sprints/sprint-${N}/stories/` with at least one having `status: done`.
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active `sprint-review` sessions on the same sprint. If a conflict exists, warn the user and stop.

## Execution

Invoke the **sprint-review** skill with the parsed context:

- If `--sprint` was specified, pass the sprint number so the skill can identify
  which files and stories to review.
- If `--auto-fix` was specified, pass this flag so the review skill can apply
  safe fixes automatically.

The sprint-review skill will handle the actual review work: running quality
gates, checking for pattern violations, and producing a review report.

## Output

- Present the review findings organized by severity (Critical, Warning,
  Suggestion).
- If `--auto-fix` was used, report which issues were automatically fixed and
  which require manual attention.
- Provide a summary with pass/fail status for each quality gate.
