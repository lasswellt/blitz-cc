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

**Verbose progress is mandatory.** Follow [terse-output.md](/_shared/terse-output.md) throughout. Print `[ask]` prefixed status lines showing classification decisions, clarification steps, and dispatch targets. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

**Ephemeral session ID.** Since `ask` does not use the full session protocol, generate a one-time session ID (`cli-<8-char-hex>`) at the start of each invocation for activity-feed entries only. Do not create a session directory or register in `.cc-sessions/`. This ID is used solely for the `session` field in activity-feed JSONL lines.

## Phase 1: Classify

**Canonical routing map: [`agents/orchestrator.md`](../../agents/orchestrator.md) §2.** That table is the single source of truth for intent→skill routing. Read it at runtime and match the user's request against it:

```bash
sed -n '/## 2. Skill routing matrix/,/## 3\./p' agents/orchestrator.md
```

Do NOT maintain a divergent copy here — the prior mirror drifted (stale slugs, malformed rows). Orchestrator §2 carries the full grouped matrix (greenfield, sprint pipeline, research/audit/quality, dev/maintenance, diagnostics) plus the Vue-conditional and HARD_SPEC ask-before-code routing rules. Honor those when present.

**Fallback (only if `agents/orchestrator.md` is unreadable/missing).** Route the highest-frequency intents from this minimal table, then proceed:

| Intent Keywords                          | Primary Skill | Follow-up Chain            |
| ---------------------------------------- | ------------- | -------------------------- |
| "fix bug", "broken", "issue #N"          | fix-issue     | → test-gen                 |
| "new page", "new feature", "add X"       | sprint-plan   | → sprint-dev → review      |
| "implement sprint", "develop stories"    | sprint-dev    | → review                   |
| "review", "quality gate", "mergeable?"   | review        | —                          |
| "audit codebase", "tech debt"            | audit         | → roadmap                  |
| "research", "compare", "how should we"   | research      | —                          |

If the request matches neither the canonical map nor the fallback, ask the user
to clarify before proceeding.

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
