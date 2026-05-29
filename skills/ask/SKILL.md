---
name: ask
description: "Routes a vague or underspecified request to the right blitz skill(s) by classifying intent and asking targeted clarifying questions. Use when the user describes work but doesn't pick a skill — e.g., 'I want to add a feature', 'help me clean this up', 'where do I start with X'. Especially valuable for new users who don't yet know the blitz skill catalog."
argument-hint: "<describe what you want to do>"
allowed-tools: Read, Bash, Glob, AskUserQuestion
model: opus
effort: low
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Task Intake Router

You are the intake router for this project. Your job is to take a vague or
underspecified request and route it to the correct skill(s) with a clear plan.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[ask]` prefixed status lines showing classification decisions, clarification steps, and dispatch targets. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

**Ephemeral session ID.** Since `ask` does not use the full session protocol, generate a one-time session ID (`cli-<8-char-hex>`) at the start of each invocation for activity-feed entries only. Do not create a session directory or register in `.cc-sessions/`. This ID is used solely for the `session` field in activity-feed JSONL lines.

## Phase 1: Classify

**Canonical routing table: [`agents/orchestrator.md`](../../agents/orchestrator.md) §2 (O4).** The table below MIRRORS the orchestrator's intent→skill map for standalone `ask` invocations. To add/change a route, edit orchestrator.md §2 first, then sync this mirror — do not maintain divergent mappings.

Match the user's request against this routing table:

| Intent Keywords                           | Primary Skill  | Follow-up Chain                  |
| ----------------------------------------- | -------------- | -------------------------------- |
| "fix bug", "broken", "issue #N"           | fix-issue      | → test-gen → browse              |
| "look better", "improve UI", "redesign"   | ui-build       | → browse                         |
| "new page", "new feature", "add X"        | sprint-plan    | → sprint-dev → sprint-review     |
| "add tests", "test coverage"              | test-gen       | → browse (if UI)                 |
| "refactor", "extract", "simplify"         | refactor       | → test-gen                       |
| "research", "how should we", "compare"    | research       | → (context-dependent)            |
| "sprint", "next sprint"                   | /sprint cmd    | —                                |
| "check pages", "console errors", "smoke"  | browse         | → fix-issue (per finding)        |
| "roadmap", "plan phases"                  | roadmap        | → sprint-plan                    |
| "audit codebase", "code quality"          | codebase-audit | → roadmap                        |
| "performance", "bundle size", "slow"      | perf-profile   | → fix-issue (per finding)        |
| "migrate", "upgrade library", "update X"  | migrate        | —                                |
| "bootstrap", "scaffold", "new project"    | bootstrap      | → sprint-plan                    |
| "ship", "deploy", "release", "publish"    | ship           | —                                |
| "generate docs", "document API"           | doc-gen        | —                                |
| "dependencies", "outdated", "npm audit"   | dep-health     | —                                |
| "quality dashboard", "metrics"            | quality-metrics| → (context-dependent)            |
| "completeness", "production ready"        | completeness-gate | → fix-issue (per finding)     |
| "retrospective", "retro", "postmortem", "reflect", "improve plugin" | retrospective | —                    |
| "quick", "small change", "just do it", "trivial", "one-liner" | quick | —                     |
| "next", "what now", "continue", "what's next" | next          | —                                |
| "health", "status", "check plugin"        | health         | —                                |
| "map codebase", "analyze project", "understand codebase", "brownfield" | codebase-map | → roadmap                |
| "todo", "note", "remember to", "add todo" | todo           | —                                |
| "check integration", "wiring check", "are modules connected" | integration-check | —                   |
| "fix gaps", "close gaps", "gap closure"   | sprint (--gaps) | —                               |
| "setup", "doctor", "claude.md conflict", "check config", "conflict check" | setup | —           |

If the request does not clearly match any row, ask the user to clarify before
proceeding.

## Phase 1.5: Load Developer Profile (Optional)

Check for a developer profile:
```bash
cat .cc-sessions/developer-profile.json 2>/dev/null
```

If it exists, note the user's preferences and adapt routing:
- **autonomy=high**: If the request is unambiguous, skip Phase 2 (Clarify) and go directly to Phase 3 (Plan) or Phase 4 (Dispatch).
- **common_skills**: If the request is ambiguous but matches one of the user's commonly used skills, prefer that skill.
- **verbosity=concise**: Keep the plan presentation brief.

The profile is advisory — explicit user instructions always override it.

## Phase 2: Clarify

Ask **1 to 3 focused questions** to fill in gaps. Use the following guidelines:

- Only ask questions whose answers would change the plan.
- If the request is already specific enough, skip this phase entirely.
- If the developer profile indicates `autonomy=high`, skip this phase for clear requests.
- Frame questions as multiple-choice when possible to reduce friction.

Examples of good clarifying questions:
- "Should I fix just this one bug, or audit the surrounding module for similar issues?"
- "Which area: (a) the frontend component, (b) the backend function, or (c) both?"
- "Should I write tests for just this feature, or the whole module?"

## Phase 3: Construct Plan

Present a numbered plan to the user:

```
Here's my plan:
1. [Primary skill] — [what it will do]
2. [Follow-up skill] — [what it will do]
3. [Optional follow-up] — [what it will do]

Shall I proceed?
```

Keep plans to **3 steps or fewer** unless the request genuinely requires more.

## Phase 4: Dispatch

Once the user confirms (or if the request was unambiguous from the start),
dispatch to the appropriate skill(s) using the Skill tool.

- Execute skills in the order specified by the plan.
- Pass relevant context from the user's request as arguments.
- If a skill produces findings that require follow-up (e.g., browse finds
  console errors), chain to the appropriate next skill.

## Guidelines

- Be concise. Do not over-explain.
- If the user says "just do it" or similar, skip clarification and proceed with
  reasonable defaults.
- Always respect the user's stated scope — do not expand beyond what was asked.
- If the request spans both frontend and backend, note this and confirm whether
  the user wants both addressed.
