---
name: implement
description: "Runs the implementation phase of a sprint by routing to sprint-dev. Use when the user says 'implement sprint N', 'develop these stories', or 'resume sprint'. Skip planning and review — those are separate skills."
argument-hint: "--sprint NNN | --stories STORY-XXX-001,STORY-XXX-002 | --resume | --mode <autonomous|checkpoint|interactive>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: low
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Sprint Implementation

You run the implementation phase of a sprint.

**Session registration**: follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration before any other work.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[implement]` prefixed status lines at every phase transition, decision point, and when dispatching to sprint-dev. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Dispatch

`implement` is a thin ergonomic verb. It owns no flags or validation of its own — it forwards verbatim to **sprint-dev**, which is the single source of truth for flag semantics (`--sprint`, `--stories`, `--resume`, `--mode`), pre-flight (its Phase 0.0 hard-fails on a missing manifest/stories), and the [Definition of Done](/_shared/definition-of-done.md).

1. If no args are given, check for an in-progress sprint with a `STATE.md` and offer `--resume`; otherwise ask which sprint/stories to implement.
2. Invoke the **sprint-dev** skill, passing the user's arguments through unchanged.

sprint-dev handles everything downstream — story reading, agent waves, tests, verification, progress reporting. Do not duplicate its logic here; if a flag changes, it changes in sprint-dev only.
