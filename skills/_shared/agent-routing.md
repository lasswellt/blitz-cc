# Agent Routing Protocol

How the blitz orchestrator agent (`agents/orchestrator.md`) decides between (a) doing work inline, (b) spawning a specialist subagent, or (c) routing the user to a slash command. Authoritative reference for orchestrator behavior + the constraint that prevents naive skills→agents migration.

**Why this doc exists**: research/2026-05-01_skills-to-agents-architecture.md identified the hard constraint that **subagents cannot spawn subagents**. Several blitz skills are super-orchestrators that spawn parallel agent waves; they cannot become subagents themselves. This doc specifies the resulting Hybrid Pattern A: orchestrator at the top, slash commands preserved, specialist subagents handle leaf work only.

---

## 1. The hard constraint

A subagent (anything spawned via `Agent()`, including the blitz orchestrator activated via plugin `settings.json {"agent": "orchestrator"}`) does NOT have access to the `Agent` tool. It cannot itself spawn a subagent.

Source: `code.claude.com/docs/en/sub-agents`. Confirmed in research doc 2026-05-01_skills-to-agents-architecture.md §3.4.

**Practical consequence**: any skill whose body contains `Agent({...})` calls — to spawn parallel reviewers, parallel research agents, parallel sprint workers — CANNOT itself be invoked as a subagent. It must remain a slash-invoked skill (which runs in the main thread and DOES have Agent() access).

The same boundary applies to the `Workflow` tool (dynamic workflows): it is main-thread-only, so only the 11 super-orchestrators may dispatch via it, and only as a capability-gated opt-in path with the `Agent()` path retained as fallback. See [workflow-dispatch.md](workflow-dispatch.md).

---

## 2. Skill classification (37 skills)

| Class | Count | Examples | Routing rule |
|---|---|---|---|
| **Super-orchestrator** (spawns ≥2 agents in parallel) | 11 | sprint-dev, sprint-plan, sprint-review, research, codebase-audit, integration-check, quality-metrics, code-sweep, sprint, code-doctor, ui-audit | **Slash-only**. Orchestrator routes user to `/blitz:<name>`. Never tries to invoke directly. |
| **Single-spawn orchestrator** (spawns ≤1 agent or invokes one downstream skill) | 9 | codebase-map, doc-gen, health, implement, migrate, retrospective, roadmap, design-extract | Future: could become subagents (out of scope for v1.11). Today: slash-only. |
| **Router / chainer** (invokes other skills sequentially via slash) | 10 | ship, fix-issue, ui-build, review, bootstrap, conform, setup, browse, perf-profile, next | **Slash-only**. Chains slash invocations the orchestrator can't replicate. |
| **Pure worker** (no spawning, no chaining) | 7 | quick, ask, todo, dep-health, refactor, test-gen, perf-profile | **Slash-only by default**. Migration to agent costs ~15× tokens with no parallelism gain — keep as cheap slash invocations. |

Total: orchestrator routes everything to slash commands. The "agent ecosystem" lives below the slash boundary, where each orchestrator-tier skill spawns its own specialist agents.

---

## 3. What the orchestrator CAN do without spawning

Orchestrator has Read, Grep, Glob, Bash, TaskCreate/Update/List, Monitor (no Write/Edit, no Agent).

It can:

- **Answer factual questions** by reading files and grep results. "What does the auth store do?" → read + cite. "Where is X defined?" → grep + cite.
- **Surface state** from `.cc-sessions/{HANDOFF.json,activity-feed.jsonl,carry-forward.jsonl}`, `docs/sweeps/ratchet.json`, `sprint-registry.json`, etc. "Where are we?" → ≤3-line state summary.
- **Update tasks** via TaskCreate / TaskUpdate / TaskList. The orchestrator IS the task list manager for cross-turn coordination.
- **Run read-only Bash** for diagnostics (git log, ls, jq queries, npm list).
- **Watch background processes** via Monitor.

It must NOT:

- Read 30 files speculatively (token waste).
- Pre-explain skill catalogs (lazy load — grep when needed).
- Re-state the user's request before answering.
- Speculate about what to do next; route or ask.

---

## 4. Routing decision tree

```
User input arrives.
├─ Slash command (/blitz:<skill>)? → orchestrator does NOT see this; it bypasses to the skill directly.
└─ Freeform request? → orchestrator handles.
   ├─ Factual / read-only question?
   │  └─ Answer inline. ≤5 lines + file:line citations.
   ├─ Maps unambiguously to a skill in §2 routing matrix?
   │  └─ Route: "→ /blitz:<skill> <args>. Why: ...". User invokes next turn.
   ├─ Ambiguous between 2+ skills?
   │  └─ Surface candidates, ask 1 clarifying question.
   └─ Outside blitz scope (general code question, doc lookup)?
      └─ Answer inline if read-only; otherwise tell user.
```

The orchestrator never silently writes files. The orchestrator never spawns subagents. Both are physically impossible (no Write, no Agent tool); the rule above just makes the constraint legible.

---

## 5. Disabling the orchestrator

Two paths:

1. **Per-project**: project-level `.claude/settings.json` overrides plugin settings. Set `{"agent": null}` to disable.
2. **Per-session**: env var `BLITZ_DISABLE_ORCHESTRATOR=1`. Hooks honor this and skip orchestrator initialization.

Disabling falls back to direct user-typed slash commands as the sole entry point — the pre-v1.11 behavior.

---

## 6. UX: what the user sees

**Before v1.11** (orchestrator absent):
- User types `/blitz:sprint-dev`. Skill runs.
- User types "implement the sprint." Claude Code main thread interprets; may or may not pick the right skill.

**After v1.11** (orchestrator activated):
- User types `/blitz:sprint-dev`. Slash invocation bypasses orchestrator; skill runs as before.
- User types "implement the sprint." Orchestrator subagent receives the request, replies: "→ /blitz:sprint-dev. Why: matches 'implement sprint' intent. State: sprint-3 phase 4, 8 stories pending."
- User invokes `/blitz:sprint-dev` next turn. Skill runs.

The orchestrator is a routing layer, not a wrapper. It doesn't change what slash commands do; it makes freeform input land on the right one.

---

## 7. State injection vs UserPromptExpansion

`hooks/scripts/blitz-prompt-expansion.sh` fires only on `/blitz:.*` slash invocations (UserPromptExpansion). Freeform prompts that route through the orchestrator do NOT fire this hook.

To preserve the activity-feed-injection behavior on freeform turns, the orchestrator's `initialPrompt:` reads `.cc-sessions/activity-feed.jsonl` directly. The hook still fires for slash invocations; the orchestrator covers freeform invocations. Together, both paths surface state.

---

## 8. Future: single-spawn orchestrator migration

The 9 "single-spawn orchestrator" skills (codebase-map, doc-gen, health, implement, migrate, retrospective, roadmap, design-extract) are candidates for promotion into specialist agents that the orchestrator CAN spawn directly. Out of scope for v1.11. When migrating, follow:

- Lift the SKILL.md body into `agents/<name>.md` with explicit `model:` per token-budget routing matrix.
- Reduce the SKILL.md to a thin shim (≤80 lines) that re-targets the agent for slash-invocation users.
- Verify the agent does not call `Agent()` (it cannot, it's a subagent).
- Bump `compatibility:` if any new fields are used.

The 11 super-orchestrators stay as skills permanently (the constraint is structural, not migratable).

---

## Related

- [`token-budget.md`](./token-budget.md) — model routing for orchestrator (sonnet) vs workers
- [`spawn-protocol.md`](./spawn-protocol.md) — agent spawn rules from inside a skill (the level above the orchestrator)
- [`session-protocol.md`](./session-protocol.md) — session lifecycle
- `agents/orchestrator.md` — the implementation
- `.claude-plugin/settings.json` — activation
- `docs/_research/2026-05-01_skills-to-agents-architecture.md` — research basis (Hybrid Pattern A)
