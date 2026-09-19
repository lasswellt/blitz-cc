---
name: implement
description: "Runs the implementation phase of a sprint by routing to sprint-dev. Use when the user says 'implement sprint N', 'develop these stories', or 'resume sprint'. Skip planning and review — those are separate skills. Thin router: identical effect to /blitz:sprint-dev; unlike /blitz:sprint it does not plan or review."
argument-hint: "--sprint NNN | --stories STORY-XXX-001,STORY-XXX-002 | --resume | --mode <autonomous|checkpoint|interactive>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
disable-model-invocation: false
model: inherit
compatibility: ">=2.1.71"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort low. Set once (`claude --model opus --effort low` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.



# Sprint Implementation

You run the implementation phase of a sprint.

**Session registration**: follow [session-lifecycle.md](/_shared/sessions.md) §Session Registration before any other work.

**Verbose progress is mandatory.** Follow [terse-output.md](/_shared/output.md) throughout. Print `[implement]` prefixed status lines at every phase transition, decision point, and when dispatching to sprint-dev. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Dispatch

`implement` is a thin ergonomic verb. It owns no flags or validation of its own — it forwards verbatim to **sprint-dev**, which is the single source of truth for flag semantics (`--sprint`, `--stories`, `--resume`, `--mode`), pre-flight (its Phase 0.0 hard-fails on a missing manifest/stories), and the [Definition of Done](/_shared/quality.md).

1. If no args are given, check for an in-progress sprint with a `STATE.md` and offer `--resume`; otherwise ask which sprint/stories to implement.
2. Invoke the **sprint-dev** skill, passing the user's arguments through unchanged.

sprint-dev handles everything downstream — story reading, agent waves, tests, verification, progress reporting. Do not duplicate its logic here; if a flag changes, it changes in sprint-dev only.
