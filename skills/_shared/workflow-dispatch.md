# Workflow Dispatch Contract

Canonical contract for the Claude Code `Workflow` tool ("dynamic workflows", research preview 2026-05-28) inside the blitz plugin. Defines the **opt-in, capability-gated, additive** adoption pattern: `Workflow` may replace the `Agent()` spawn-poll-classify scaffolding in a super-orchestrator, but never as a hard dependency. Referenced from [spawn-protocol.md](spawn-protocol.md), [agent-routing.md](agent-routing.md), and [token-budget.md](token-budget.md).

Research provenance: [docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md](../../docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md).

## Why this exists

`Workflow` is a deterministic JS orchestration primitive: a script with `agent()` / `parallel()` / `pipeline()` / `phase()` / `log()` hooks dispatches ≤1000 subagents (16 concurrent) in the background, with built-in `schema:` structured output, `null`-on-throw error handling, and `resumeFromRunId` resume. It maps ~1:1 onto blitz's hand-rolled spawn-protocol (single-message `run_in_background` pools, output-file polling, `classify_output()`, `jq` reply parsing) and removes ~80–150 lines of bash per adopting skill.

Blitz cannot adopt it naively. `Workflow` is a **research preview**, **disabled-by-default on Enterprise**, and **per-user opt-in gated**. blitz ships to arbitrary users — a skill that *requires* `Workflow` hard-fails for any user without it. Adoption is therefore additive: a capability-gated fast path with the existing `Agent()` path retained as the portable default.

## The hard constraints

1. **Main-thread only.** `Workflow` is callable only from the main thread, exactly like `Agent()`. A subagent cannot call it (subagents-cannot-spawn-subagents, [agent-routing.md](agent-routing.md) §1). Only the 11 slash-only **super-orchestrators** may dispatch via `Workflow`. Pure workers / single-spawn skills MUST NOT.

2. **Script body is sandboxed.** The orchestration script is plain JS: **no filesystem, no `Date.now()` / `Math.random()` / argless `new Date()`**, no Node API. It cannot touch `.cc-sessions/activity-feed.jsonl`, session locks, `carry-forward.jsonl`, `ratchet.json`, or `SESSION_TMP_DIR` paths.

3. **Spawned agents are NOT sandboxed.** Each `agent()` call runs a normal subagent with full Read/Write/Bash/Grep. They still stub-and-append their own findings files exactly as under `Agent()`. The sandbox binds the *script*, not its agents.

4. **Opt-in is satisfied by skill instructions.** Per the `Workflow` tool contract, "the user invoked a skill or slash command whose instructions tell you to call Workflow" counts as opt-in. A blitz super-orchestrator MAY legitimately dispatch via `Workflow` when its SKILL.md instructs it to — no extra user keyword required. (First-trigger confirmation behavior is still platform-controlled — see Open risks.)

## Hybrid wrapper boundary

The skill (main thread, Bash/Read/Write) owns ALL filesystem + clock state. `Workflow` owns ONLY agent dispatch + schema validation. Spawned agents own their own findings I/O.

```
skill (main thread)
 ├─ Bash: session register, lock acquire, activity-feed session_start, build inventory   [pre]
 ├─ Workflow({script}): parallel()/pipeline() dispatch + schema validation               [dispatch]
 │    └─ agent() × N → real subagents → write findings files (full tools)
 ├─ Read: collect Workflow return value (validated objects) + agents' findings files       [post]
 └─ Bash/Write: synthesize report, ratchet.json, carry-forward, activity-feed task_complete [post]
```

Timestamps: the script cannot call `Date.now()`. Pass any needed timestamp in via `args`, or stamp after the workflow returns (the wrapper has the clock).

## Capability gate + fallback contract

Every `Workflow`-adopting skill MUST select dispatch mode at runtime and retain the `Agent()` path. Selection rule:

```
USE_WORKFLOW = (Workflow tool present)
            AND (BLITZ_DISPATCH != "agent")          # operator force-off
USE_WORKFLOW is forced ON  when BLITZ_DISPATCH == "workflow"
```

- `Workflow` tool present → discoverable in the deferred-tool list / callable. If unknown, attempt the call and on tool-unavailable error fall back to `Agent()`.
- `BLITZ_DISPATCH` (env): `auto` (default — gate as above), `workflow` (force, error if absent), `agent` (force legacy path).
- On ANY `Workflow` dispatch failure (tool absent, script error, abort), **fall back to the `Agent()` path** — never hard-fail the skill. Log the chosen path to the activity-feed (`detail.dispatch: "workflow"|"agent"`).
- The `Agent()` path in [spawn-protocol.md](spawn-protocol.md) remains the canonical, always-present default while `Workflow` is preview.

## Mandatory prompt invariants (carried into `agent()`)

`Workflow`'s `agent()` prompts are subject to the SAME contract as `Agent()` prompts:

- **OUTPUT STYLE snippet** — every `agent()` prompt MUST embed the terse-output snippet ([terse-output.md](terse-output.md)). sprint-review **Invariant 5** blocks PASS if missing. Centralize prompt assembly so the snippet is structurally unavoidable.
- **JSON reply contract** — prefer the `schema:` option (SDK-level validation) over freeform text + `jq`. Schema replaces `parse_reply()` / `classify_output()` boilerplate; `null`-on-throw + `.filter(Boolean)` replaces the MISSING/EMPTY/MALFORMED gate.
- **Model routing** — set `opts.model` per the 60/35/5 Haiku/Sonnet/Opus matrix ([token-budget.md](token-budget.md)). Omit only to inherit the main-loop model.
- **Token budget** — pass/honor `budget` ceilings; cap any loop-until-dry / adaptive-iteration loop with an explicit round limit. Unbounded iteration conflicts with the token-budget protocol.
- **Worktree isolation** — `agent(prompt, {isolation: "worktree"})` is supported and obeys [worktree-lifecycle.md](worktree-lifecycle.md). Same collision-guard + post-merge cleanup invariants apply; verify before using in sprint-dev.

## Pattern mapping (blitz → Workflow)

| Blitz `Agent()` pattern | `Workflow` primitive |
|---|---|
| single-message `run_in_background` pool + poll-until-all | `parallel([...thunks])` (barrier; `null` on throw) |
| Kahn wave layers (Wave 0 → barrier → Wave 1) | sequential `parallel()` per wave, OR `pipeline()` for independent chains |
| JSON reply + `jq` validate | `agent(prompt, {schema})` → validated object |
| `classify_output()` MISSING/EMPTY/MALFORMED gate | `null`-on-throw + `.filter(Boolean)` |
| HEARTBEAT markers + grep polling | `log()` streaming |
| PARTIAL → narrow retry | conditional `agent()` after barrier / bounded loop |
| gap second-wave (research Phase 2.4) | `if (gaps.length) await agent(...)` |
| (net-new) adversarial verify | `parallel([...refuters])` + majority vote per finding |

## Adoption status (per skill)

| Skill | Status | Notes |
|---|---|---|
| `codebase-audit` | **PILOT** | 10 flat agents → one `parallel()` + `schema`. No DAG, no worktree, no cross-session resume. Lowest risk. |
| `research` | candidate | 4-agent pool + conditional gap wave. Adopt after pilot proves out. |
| `sprint-review` | candidate (narrow) | single critic `agent()` + `schema`; net-new adversarial-verify panel. |
| `sprint-dev` | **deferred** | wave-DAG → `pipeline()` ideal, worktree supported, BUT `resumeFromRunId` (same-session) ≠ `STATE.md` (cross-session) resume — reconcile first. |
| pure workers / single-spawn | **forbidden** | constraint §1. |

## Escape hatches

| Env var | Default | Effect |
|---|---|---|
| `BLITZ_DISPATCH` | `auto` | `workflow` forces `Workflow` (error if absent); `agent` forces legacy `Agent()` path |

## Open risks (gate further adoption)

- **Portability** — `Workflow` preview + Enterprise-disabled. Never remove the `Agent()` fallback while preview. If runtime capability-detection proves unreliable, defer.
- **API churn** — preview hook signatures may shift before GA. Confine all `Workflow` calls behind this doc's gate so a fix is one-skill-shaped.
- **Autonomous loops** — if a skill-instructed `Workflow` call still triggers the platform per-run confirmation prompt, `/blitz:next --loop` flows could stall. Verify before any autonomous-loop skill adopts.
- **Resume divergence (sprint-dev)** — keep `STATE.md` authoritative; treat `resumeFromRunId` as in-session optimization only.

## Cross-references

- Spawn protocol (canonical `Agent()` path): [spawn-protocol.md](spawn-protocol.md)
- Routing constraint: [agent-routing.md](agent-routing.md) §1
- Token budget + model routing: [token-budget.md](token-budget.md)
- Output style (Invariant 5 snippet): [terse-output.md](terse-output.md)
- Worktree isolation contract: [worktree-lifecycle.md](worktree-lifecycle.md)
- Research provenance: [docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md](../../docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md)
