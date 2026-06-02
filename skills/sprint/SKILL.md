---
name: sprint
description: "Orchestrates the full sprint cycle (plan → implement → review). Use when the user says 'run a sprint', 'do a full sprint'. Since v1.13.0, --loop is a backwards-compat alias that dispatches /blitz:next --loop (the canonical autonomous reconciliation engine, which handles the full project lifecycle, not just sprints). Use only for the full plan→implement→review cycle; for implementation-only of an already-planned sprint use /blitz:implement or /blitz:sprint-dev."
argument-hint: "[--epics EP-001,EP-002] [--plan-only] [--skip-review] [--loop]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: low
compatibility: ">=2.1.71"
---

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Sprint Cycle Orchestrator

You orchestrate a full sprint cycle: **plan → implement → review**.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[sprint]` prefixed status lines at every phase transition, decision point, and when dispatching to sub-skills. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

**Carry-forward awareness is mandatory in `--loop` mode.** Now lives in `/blitz:next --loop` (see `skills/next/SKILL.md` §Loop Mode rows 6a-6d). The reconciliation engine reads `.cc-sessions/carry-forward.jsonl` every tick and treats active/partial entries as load-bearing state — silent scope drops are prevented by the decision-tree split. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the full protocol.

## Flag Parsing

Parse the following flags from the user's arguments:

- `--plan-only`: Run only the planning phase, then stop.
- `--skip-review`: Run planning and implementation, but skip the review phase.
- `--epics EP-001,EP-002`: Limit the sprint scope to the specified epic IDs.
- `--resume`: Resume an interrupted sprint. Skips planning, goes directly to sprint-dev which will detect STATE.md and resume from the last checkpoint. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).
- `--gaps`: Gap closure mode. Chains: sprint-review → sprint-plan --gaps → sprint-dev. Finds quality gaps and generates fix stories automatically.
- `--mode <autonomous|checkpoint|interactive>`: Execution mode passed through to sprint-dev. `autonomous` (default) runs everything; `checkpoint` pauses after each wave for user review; `interactive` confirms each story before starting.
- `--loop`: **Backwards-compat alias since v1.13.0** — routes to `/blitz:next --loop`. The canonical autonomous reconciliation engine moved to the `next` skill because it handles the full project lifecycle (bootstrap, roadmap creation, ship) in addition to the sprint cycle. Behavior unchanged from the user's perspective: each tick reads state, executes one phase, commits/pushes, exits. See `skills/next/SKILL.md` §Loop Mode for the full reconciliation spec including scheduling tiers, self-scheduling via `ScheduleWakeup`, the 8-row decision tree, and stop signals. `/loop /blitz:sprint --loop` continues to work — each tick alias-routes to `/blitz:next --loop` which executes one phase.

If no flags are provided, run all three phases in sequence.

---

## Loop Mode (--loop) — Alias for /blitz:next --loop since v1.13.0

When `--loop` is specified, this skill immediately dispatches `/blitz:next --loop` and exits. The reconciliation engine, scheduling tiers, decision tree, self-scheduling, and stop signals all live in the `next` skill now.

```
# Pseudo-code for the alias:
if "--loop" in args:
    Skill({ skill: "blitz:next", args: "--loop" })
    exit 0
```

**Why the move:** the reconciliation loop is a project-lifecycle engine, not a sprint-cycle engine. It handles bootstrap, roadmap creation, ship orchestration, and carry-forward gap closure in addition to the sprint plan → implement → review cycle. The `next` skill was already the canonical "what should I do next?" advisor; consolidating the autonomous loop there is the cleaner home.

**Backwards compatibility:** `/loop /blitz:sprint --loop` continues to work — each tick alias-routes to `/blitz:next --loop` which executes one phase. Scripted invocations need not change. Direct callers benefit from migrating to `/blitz:next --loop` to skip the alias hop.

**Reference**: full reconciliation spec in `skills/next/SKILL.md` §Loop Mode (Phases 3 + 4).

Skip the rest of this skill's normal phases below when `--loop` is set — the alias dispatch is the entire behavior.

---

## Pre-Flight Validation

Before starting any phase (in both normal and loop mode), verify:

1. **Roadmap exists**: Check for `roadmap-registry.json` or `epic-registry.json`. If neither exists, inform the user that a roadmap is needed first and stop.
1b. **Uningested research check**: Run the UNINGESTED detection from Loop Step 1. If any files found, print:
    ```
    [sprint] Uningested research detected:
      docs/_research/YYYY-MM-DD_<slug>.md
    [sprint] Auto-invoking /blitz:roadmap extend before sprint cycle…
    ```
    Invoke `/blitz:roadmap extend`, then re-read `roadmap-registry.json` / `epic-registry.json` and continue to step 2.
    If `roadmap extend` fails (e.g., malformed `scope:` block), surface the error with the doc path and stop — do not silently continue to sprint.
    *(In `--loop` mode: alias-routes to /blitz:next --loop, which handles ingestion in its Phase 0.8 + decision-tree row 0.)*
2. **Epics available**: If `--epics` was specified, confirm each epic ID exists and is unblocked. If no epics are specified, confirm at least one epic has unmet dependencies resolved. *(In loop mode, skip this check — the reconciliation tree handles it.)*
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active sprint-plan, sprint-dev, or sprint-review sessions. If a conflict exists, warn the user and stop. *(In loop mode, defer gracefully instead of stopping — see above.)*
4. **Clean working tree**: Run `git status --porcelain`. If there are uncommitted changes, warn the user. *(In loop mode, warn but do not stop.)*

All phases enforce the [Definition of Done](/_shared/definition-of-done.md). No phase is complete if delivered code contains placeholder implementations.

## Phase 1: Sprint Planning

If `--resume` was specified, skip this phase entirely and proceed to Phase 2.

Invoke the **sprint-plan** skill.

- If `--epics` was specified, pass the epic IDs as context.
- The planning skill will produce a sprint backlog with prioritized stories.
- Present the plan to the user and ask for confirmation before proceeding. *(In loop mode, auto-confirm.)*
- If `--plan-only` was specified, stop here after presenting the plan.

## Phase 1.5: Gap Closure (if --gaps)

If `--gaps` was specified:
1. First invoke **sprint-review** to identify quality issues in the current sprint.
2. Then invoke **sprint-plan --gaps** to generate fix stories from the review findings.
3. Present the gap-closure plan to the user and ask for confirmation. *(In loop mode, auto-confirm.)*
4. Proceed to Phase 2 with the gap-closure stories.

## Phase 2: Sprint Implementation

Invoke the **sprint-dev** skill.

- Pass the confirmed sprint backlog from Phase 1 (or gap-closure stories from Phase 1.5).
- If `--mode` was specified, pass it through to sprint-dev.
- The implementation skill will work through stories in priority order.
- Each story should be implemented and verified before moving to the next.

## Phase 3: Sprint Review

If `--skip-review` was NOT specified, invoke the **sprint-review** skill.

- Pass the list of completed stories and changed files from Phase 2.
- The review skill will run quality gates and produce a review report.
- Present the review findings to the user.

## Error Handling

- If any phase fails, report the failure clearly and ask the user how to proceed. *(In loop mode, log the failure to the activity feed and exit cleanly. The next /loop tick will re-evaluate.)*
- Do not silently skip phases.
- If implementation gets stuck on a story, report progress so far and ask for guidance. *(In loop mode, the sprint-dev circuit breaker handles stuck stories automatically.)*
