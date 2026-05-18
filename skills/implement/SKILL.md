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

## Flag Parsing

Parse the following flags from the user's arguments:

- `--sprint NNN`: Implement all stories for the specified sprint number.
- `--stories STORY-XXX-001,STORY-XXX-002`: Implement only the specified stories.
- `--resume`: Resume an interrupted sprint from its last checkpoint (STATE.md). Equivalent to `--sprint NNN` where NNN is the in-progress sprint, but sprint-dev will skip to Phase 3 using STATE.md data. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).
- `--mode <autonomous|checkpoint|interactive>`: Execution mode passed through to sprint-dev. `autonomous` (default) runs everything; `checkpoint` pauses after each wave for user review; `interactive` confirms each story before starting.

At least one flag must be provided. If neither is given, check for an in-progress sprint with a STATE.md and offer to resume. Otherwise, ask the user which stories or sprint to implement.

## Pre-Flight Validation

Before invoking sprint-dev, verify:

1. **Sprint exists**: Read `sprint-registry.json` and confirm the target sprint has `status: planned` or `status: in-progress`. If not found, inform the user and stop.
2. **Stories exist**: Verify story files exist in `sprints/sprint-${N}/stories/`. If `--stories` was specified, confirm each story ID maps to an existing file.
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active `sprint-dev` sessions on the same sprint. If a conflict exists, warn the user and stop.
4. **Build baseline**: Confirm the project builds cleanly (or note pre-existing errors) before spawning agents.

All code produced must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations, no empty handlers, no stub returns.

## Execution

Invoke the **sprint-dev** skill with the parsed context:

- If `--sprint` was specified, pass the sprint number so the skill can look up
  the sprint backlog.
- If `--stories` was specified, pass the story IDs directly.

The sprint-dev skill will handle the actual implementation work: reading story
definitions, writing code, running tests, and verifying each story.

## Progress Reporting

- Report which story is being worked on as implementation proceeds.
- After all stories are complete, provide a summary of what was implemented and
  any issues encountered.
