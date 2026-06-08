# Agent Orchestration

How blitz agents fan out, route, dispatch, budget, and report — the full subagent lifecycle in one document.

**Consolidates** (2026-06-06 `_shared` consolidation) six former files; each appears below as a top-level section with its original sub-headings preserved as anchor targets (inbound `oldfile.md#anchor` links were mechanically rewritten to `agent-orchestration.md#anchor`):

| Former file | Section | Concern |
|---|---|---|
| `spawn-protocol.md` | [Spawn Protocol](#subagent-spawn-protocol) | subagent type/weight, HEARTBEAT/PARTIAL/WRAP_UP, timeouts, output contract |
| `agent-prompt-boilerplate.md` | [Agent Prompt Boilerplate](#agent-prompt-boilerplate) | author-time dedup target for recurring Agent() prompt blocks |
| `agent-routing.md` | [Agent Routing](#agent-routing-protocol) | orchestrator routing decision tree + spawn-depth constraint |
| `agent-view-dispatch.md` | [Agent View Dispatch](#agent-view-dispatch-and-background-session-interop) | agent-view rendering/dispatch |
| `workflow-dispatch.md` | [Workflow Dispatch](#workflow-dispatch-contract) | opt-in Workflow dispatch contract + Agent() fallback |
| `token-budget.md` | [Token Budget](#token-budget-protocol) | model routing matrix, cache TTL, JSON reply contract, lazy load |


---

<!-- ===== Absorbed from spawn-protocol.md ===== -->

## Subagent Spawn Protocol

Authoritative guidance for blitz skills that spawn subagents. Covers subagent type selection, workload sizing, defensive patterns (HEARTBEAT / PARTIAL), and wave-based dependency execution. Every skill that spawns agents MUST follow this protocol.

**Why this doc exists**: Three separate docs (subagent-types.md, agent-workload-sizing.md, waves.md) were consolidated here in v1.4.0. They addressed overlapping concerns and were always linked together. This single file is the one stop for skill authors.

---

### Contents

1. [Subagent Type Selection](#1-subagent-type-selection) — which built-in type or blitz:<role> to pick, foot-guns, decision matrix
2. [Workload Sizing](#2-workload-sizing) — Light/Medium/Heavy weight classes, caps, mandatory patterns, banned patterns
3. [HEARTBEAT and PARTIAL Protocols](#3-heartbeat-and-partial-protocols) — prompt snippets for Medium/Heavy agents
4. [Wave Execution](#4-wave-execution) — topological DAG scheduling, opt-in rules, when NOT to use waves
5. [Model and Context Inheritance](#5-model-and-context-inheritance) — the `[1m]` trap, resolution order, env override
6. [Reviewer Checklist Summary](#6-reviewer-checklist-summary) — what sprint-review flags as BLOCKERs
7. [Token Budget & Reply Contract](#9-token-budget-and-reply-contract) — model routing, caching, JSON return shape (see [token-budget.md](#token-budget-protocol))

---

### 1. Subagent Type Selection

Source: [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) — verified 2026-04-16.

#### Built-in Claude Code Subagent Types

| Name | Purpose | Tools (CAN use) | Tools (CANNOT use) | Default Model |
|---|---|---|---|---|
| **Explore** | Fast, read-only codebase search | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Haiku |
| **Plan** | Plan-mode pre-flight research | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Inherits |
| **general-purpose** | Complex multi-step tasks requiring read + write | All tools (`*`) | None | Inherits |
| **statusline-setup** | Configure status line via `/statusline` | Read, Edit only | N/A | Sonnet |
| **claude-code-guide** | Answer Claude Code meta-questions | Read, Grep, Glob, WebFetch, WebSearch | Write, Edit, Agent | Haiku |

**Anthropic's guidance**:
> *Explore*: "A fast, read-only agent optimized for searching and analyzing codebases."
> *general-purpose*: "Claude delegates to general-purpose when the task requires both exploration and modification, complex reasoning to interpret results, or multiple dependent steps."

`statusline-setup` and `claude-code-guide` are auto-invoked by the harness. Do not select them directly in skill spawns.

#### Blitz Plugin Agents

Source: `agents/` directory. Verified 2026-04-16.

| Agent | Tools | Read-Only? | Default Model | Specialty |
|---|---|---|---|---|
| `blitz:architect` | Read, Glob, Grep, Bash | **YES (strictly)** | sonnet | Structural analysis, dependency graphs |
| `blitz:reviewer` | Read, **Write**, Bash, Glob, Grep | No (Write for findings only) | sonnet | Code quality/security review with written findings |
| `blitz:doc-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | haiku | Documentation generation |
| `blitz:backend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Cloud Functions, Zod, Firestore |
| `blitz:frontend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Vue 3 / Pinia implementation |
| `blitz:test-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Unit / integration / E2E tests |

**Foot-gun**: `blitz:architect` is strictly read-only. If a spawn site expects `architect` to write findings files, the orchestrator must write them from the agent's text return — same failure mode as Explore.

**Plugin-agent caveat**: `permissionMode`, `hooks`, and `mcpServers` frontmatter are silently ignored for plugin agents. If you need those fields, copy the agent file to `~/.claude/agents/`.

#### Decision Matrix

| Task type | Recommended subagent_type | Rationale |
|---|---|---|
| Read-only codebase search, findings returned as text | `Explore` | Fast Haiku, no write needed |
| **Research that MUST write findings to a file** | **`general-purpose`** | **Explore cannot Write. Never rely on heuristic defaults for write-required work.** |
| Focused grep/glob for a specific pattern | `Explore` | Fast, single-purpose |
| Web research + file writing | `general-purpose` | Has WebSearch + Write |
| Implementation (edit source files) | `blitz:backend-dev` / `blitz:frontend-dev` / `blitz:test-writer` | Role-specific conventions baked into the agent |
| Documentation writing | `blitz:doc-writer` | Designed for docs output |
| Code review with written findings | `blitz:reviewer` | Write for findings; cannot modify source |
| Architecture analysis with written report | `general-purpose` | `blitz:architect` is read-only — orchestrator must write report from agent text, OR spawn a `general-purpose` agent instead |

**Rule of thumb**: if the agent needs to call `Write` or `Edit`, it MUST be `general-purpose` or a `blitz:<role>` agent with Write in its tool list. Anything else will silently fail.

#### Foot-Guns

1. **Explore picked for write-required work** — the bug that motivated v1.2.0. Always specify `subagent_type` explicitly when writes are required.
2. **`blitz:architect` is read-only despite its name** — use `general-purpose` if analysis must produce a file.
3. **Plugin-agent `permissionMode` is silently ignored** — use `.claude/agents/` (not plugin dirs) if you need that field.
4. **Haiku quality ceiling on Explore** — complex reasoning tasks may produce poor results. Use `general-purpose` with `model: sonnet` for nuanced analysis.
5. **`TeamCreate`+`SendMessage` does not accept `subagent_type`** — the SDK picks by heuristic. Use the `Agent` tool instead (v1.4.0 migrated all spawning skills to this).
6. **Model inheritance propagates `[1m]`** — v1.1.3 crashed a Sonnet-declared skill invoked from a 1M parent. Declare explicit `model:` without `[1m]`.

---

### 2. Workload Sizing

**Why**: In April 2026, a reliability audit found that blitz skills lost tokens repeatedly because several spawn sites declared zero caps on file reads, web searches, output length, or turns. Since Claude Code now caps server-side tool calls at ~20 per turn (Feb 2026 regression) and all tokens are billed regardless of outcome, unbounded agents routinely failed silently mid-work. Weight classes and mandatory patterns follow.

#### Weight Class Table

| Class | Use case | Max file reads | Max web searches | Max tool calls | Max output | Wall-clock | Model |
|---|---|---|---|---|---|---|---|
| **Light** | Single-focus analysis; pattern check; library summary; grep/glob query | 8 | 5 | 15 | 150 ln | 3 min | sonnet |
| **Medium** | Multi-file synthesis; cross-cutting research; feature review; epic analysis | 15 | 8 | 25 | 250 ln | 5 min | sonnet |
| **Heavy** | Implementation; multi-story worktree; full-pillar audit | 25 | 0 | 40 | 400 ln | 8 min | opus orchestrator / sonnet workers |

**Rules**:
1. Every agent spawn MUST be in one of these three classes. If the task doesn't fit, split it into smaller agents by domain or file prefix.
2. Caps are defaults. Skills may override with documented rationale in their SKILL.md if the project scale demands it.
3. Turn budget (max tool calls) is not directly controllable via SDK today; bound it indirectly via file-read caps + output caps.
4. Heavy class requires the orchestrator to be `model: opus` and workers to be `model: sonnet` (explicit) to control cost.

#### Mandatory Patterns by Class

**Light class**
- Output-file existence check: the orchestrator MUST validate that the agent's expected output file exists and is non-empty before consuming the result.

**Medium class** — Light + these:
- Write-as-you-go: agent prompt must instruct the agent to write findings to the output file incrementally, not accumulate in memory. Stub the file at start.
- Wall-clock timeout in prompt: state the 5-minute budget explicitly so the agent self-paces.
- HEARTBEAT markers (see section 3) — recommended, not strict requirement.

**Heavy class** — Medium + these:
- HEARTBEAT markers: agent writes `HEARTBEAT: <phase-name> at <ISO-timestamp>` at the start of each phase (at least 3 phases).
- PARTIAL return format: agent emits a PARTIAL block when approaching the turn limit.
- Turn-budget declaration: agent prompt explicitly states `You have a budget of 40 tool calls. After 35, stop and write PARTIAL.`

#### Output Size and Single-Write Budget

Empirically observed per-call output budget (2026-05-16, this repo):

| Model | Safe single Write | Hard ceiling (timeout risk) |
|---|---|---|
| sonnet | ≤ 32 KB / ~8K tokens | > 40 KB |
| opus   | ≤ 48 KB / ~12K tokens | > 64 KB |
| haiku  | ≤ 16 KB / ~4K tokens | > 24 KB |

**Anchor incident**: a single-Write compress on `skills/ui-audit/references/main.md` (70 KB / 1570 lines) ran 7m36s with 4 tool calls and produced zero output before timing out. A sectioned-Edit pass on `skills/sprint-review/references/main.md` (35 KB) completed via 20 Edits across 14 sections.

**Rules**:
1. If the agent's expected output exceeds the safe single-Write budget for its model, dispatch as sectioned Edits, not one Write — Edit calls scoped to discrete file sections fit individual budget windows and persist incrementally.
2. If the target file is larger than the hard ceiling, split the source into sections first (or address one section per agent) instead of issuing the agent a single all-in-one prompt.
3. Write-as-you-go is the universal mitigation: stubbing the output file before the first tool call + appending findings prevents the zero-output failure mode regardless of total size.
4. Per-tool-call output is bounded by the model's per-call token budget — large file rewrites are NOT bounded by the agent's "Max output: 150/250/400 ln" caps (those are aggregate). The single-Write ceiling above is the per-call boundary.

#### Banned Patterns

These produce zero-output failures with full token cost. They are BLOCKERs in sprint-review.

1. **Unbounded file set** — prompts saying "read all files", "scan the entire codebase", or passing an unlimited file list.
2. **Unbounded diff / input** — passing "the entire sprint diff" or "the whole PR" to reviewer agents without size caps.
3. **"Write the full document at the end, not incrementally"** — guarantees zero output on timeout. (Exception: code-sweep tier agents writing a single JSON array are a structural exception where the array IS the incremental payload; scope already capped by tier.)
4. **Orchestrator reads agent output with no existence check** — proceeds on missing/empty files and silently produces degraded results.
5. **Retry without narrowing scope** — retrying the exact same prompt after `error_max_turns` burns tokens identically. Narrow the scope, or do not retry.
6. **Single Write of >40 KB output (sonnet) / >64 KB (opus)** — exceeds per-call output budget; agent times out with zero file written. Use sectioned Edits instead.

#### Fail-Fast Rationale

All tokens are billed regardless of task outcome. No refunds for `error_max_turns`, `error_max_budget_usd`, `error_during_execution`, or context-exhaustion. Documented incidents: one auto-compact loop burned 695M cache-read tokens (anthropics/claude-code#22758); one output-file loop wrote 359 GB (#29557). Subagent overhead is ~7× vs single-session for equivalent work.

**Therefore**: prefer hard caps that fail fast over permissive caps that try to salvage. Set `max_turns` and `max_budget_usd` in the SDK when available. Never retry without narrowing scope. HEARTBEAT and PARTIAL are secondary safety — the first-order fix is bounding the workload so it fits in a single agent's budget.

#### Orchestrator-Side Validation

Every skill that spawns agents MUST include this check before consuming agent output:

```bash
for f in ${SESSION_TMP_DIR}/<expected-outputs>.md; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # Log to .cc-sessions/activity-feed.jsonl
  fi
done

# Skill-specific threshold (e.g., abort if MISSING_COUNT >= 2 of 4)
if [ "$MISSING_COUNT" -ge "$FAIL_THRESHOLD" ]; then
  echo "Aborting: too many agents failed to produce output"
  exit 1
fi
```

---

### 3. HEARTBEAT and PARTIAL Protocols

#### HEARTBEAT — mid-run liveness signal

Add this block verbatim to Medium (optional) and Heavy (required) agent prompts:

```
HEARTBEAT PROTOCOL:
At the start of each phase, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats across your task. Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ`
to produce the timestamp.
```

**Orchestrator consumption**: count HEARTBEAT lines during polling. A file with 2+ heartbeats but no final result is partially-alive; a file with 0 heartbeats after wall-clock expiry is presumed dead.

#### PARTIAL — graceful degradation on budget exhaustion

Add this block verbatim to Heavy (required) agent prompts:

```
PARTIAL DEGRADATION:
If you have 3 or fewer tool calls remaining (or detect approaching the turn
limit, output-token limit, or wall-clock budget), STOP and append this block
to the output file:
  ---
  PARTIAL: true
  COMPLETED: [list of sections finished]
  MISSING: [list of sections skipped]
  CONFIDENCE: low|medium|high
  ---
Then write a one-line confirmation to the caller: "PARTIAL: <N> sections
complete, <M> missing" and end.
```

**Orchestrator consumption**:
- If `PARTIAL: true` is present, treat as partial success. Warn the user.
- Cross-reference `MISSING` against the expected deliverable list. Flag known-required sections that landed in MISSING.
- For narrow retry: re-spawn ONLY on items in the MISSING list, not the full task.

#### WRAP_UP — 70% context-ceiling signal (autonomous loops)

Add this block verbatim to agent prompts running inside an autonomous loop (sprint --loop, code-sweep --loop, etc.):

```
WRAP_UP PROTOCOL (autonomous-loop subagents):
If the orchestrator sends WRAP_UP via SendMessage, OR you detect your own
context utilization >70% (estimate: tool-output tokens consumed >140K of 200K
budget), do the following IMMEDIATELY:
  1. Stop further exploration. Do not start new tool chains.
  2. Write what you have so far to your output file.
  3. Append a WRAP_UP marker block:
     ---
     WRAP_UP: true
     REACHED_VIA: <self-detect|orchestrator-signal>
     COMPLETED: [...]
     SAFE_TO_RESUME_FROM: <one-line description of next action>
     ---
  4. Return the canonical JSON reply with status: "partial".

The orchestrator interprets WRAP_UP as: "this agent is healthy but nearly out
of context; spawn a fresh agent from SAFE_TO_RESUME_FROM rather than retrying."
```

**Why pattern-match on WRAP_UP rather than only PARTIAL**: PARTIAL fires on budget exhaustion (failure-adjacent). WRAP_UP fires preemptively on context pressure (healthy). They route to different orchestrator paths — WRAP_UP triggers a fresh-context handoff; PARTIAL triggers narrow retry.

#### Resume Protocol — SendMessage to a budget-exhausted agent

When an agent returns PARTIAL (budget exhaustion) and the orchestrator decides to resume via `SendMessage` rather than spawn fresh, the resume prompt MUST include an explicit "remaining work" block. Without it, the resumed agent burns half its budget re-discovering state it already had.

**Anti-pattern (sprint-276 root cause):**

```
SendMessage({to: "<agent-id>", body: "continue"})
# Agent re-reads transcript, re-greps the worktree, re-checks git log,
# spends 60% of fresh budget rebuilding context, exhausts again.
```

**Canonical resume payload:**

```
SendMessage({
  to: "<agent-id>",
  body: `RESUME PROTOCOL
COMPLETED (do not redo):
  - <bullet list of finished items, verbatim from prior PARTIAL output>
REMAINING (do these in order):
  - <story-id-or-file-path>: <one-sentence what to do>
  - ...
WORKTREE: <path>
HEAD: <sha>  # so you can rebase if main moved
DO NOT:
  - re-read files you already touched
  - re-run tests for completed items
  - explore — go straight to remaining[0]
EXIT WHEN: remaining is empty OR budget exhausted (then PARTIAL again).`
})
```

The orchestrator constructs this from the agent's prior PARTIAL reply: `completed` from its `summary` + `files_changed`, `remaining` from the original task list minus `completed`. If the prior reply was malformed (no PARTIAL marker), spawn fresh instead of resuming — a stateless restart is cheaper than a confused continuation.

#### Three-tier timeout (autonomous spawns)

| Tier | Duration | Signal | Orchestrator action |
|---|---|---|---|
| `soft` | 20 min | warning only | Log to activity-feed `event: soft_timeout`. Continue. |
| `idle` | 10 min without HEARTBEAT update | warning + nudge | SendMessage `STATUS?` to agent. If no reply within 90s, classify as stuck. |
| `hard` | 30 min total wall-clock | terminate + classify | Kill the agent; classify output per §8 (typically PARTIAL or FAILURE). Do not auto-retry. |

These are defaults for autonomous-loop spawns; one-shot interactive spawns inherit Claude Code's native timeouts and need no application-level enforcement.

#### Stuck-loop detection

Track the last 8 dispatch task IDs in the orchestrator state. Detect:

- **Pattern A→B→A→B**: 4 consecutive dispatches alternating between two task IDs. Likely an oscillation between two incomplete fixes that reintroduce each other's bugs.
- **Pattern A→A→A**: 3 consecutive identical dispatches with no progress signal in activity-feed. The agent is retrying without state change.

On detection:
1. Inject a diagnostic prompt addendum: "Prior dispatches: <history>. Why is this not converging? Identify the contradiction before retrying."
2. Dispatch ONE more time with the diagnostic addendum.
3. If the next dispatch fails the same pattern, **PAUSE and surface to user**. Do not infinite-retry. Also fire a remote push so a user monitoring via `claude agents` is alerted off-screen (no-op if Remote Control unconfigured; see [agent-view-dispatch.md](#agent-view-dispatch-and-background-session-interop) §Remote alerts):
   ```
   PushNotification(title: "Session needs input", message: "<skill> stuck-loop on <unit> — paused, awaiting direction")
   ```
   Gate on developer-profile `notify` preference (skip when `notify: off`).

Do NOT use a simple counter. A→B→A→B is correct sometimes (refactor A then test then refactor A); the disambiguation comes from "no progress signal in activity-feed."

---

### 4. Wave Execution

A **wave** is a topological layer of a dependency DAG: maximal set of work units whose declared prerequisites are satisfied by prior waves, enabling parallelism within each wave.

#### Gate: Do You Actually Have a DAG?

**Waves deliver value only when there is a directed dependency graph between units of work.** Before adopting:

- Do your work units have declared `depends_on: [<id>...]` fields?
- Are any of those dependencies non-trivial (i.e., unit B actually cannot start until unit A finishes)?

**If no**: your work is a flat pool of independent units. Do NOT adopt waves. Run a simple parallel spawn with a polling completion check. Examples of flat pools in blitz: `audit` (10 independent pillars), `research` (2-4 independent investigators), `sprint-plan` (parallel researchers), `codebase-map` (4 independent dimensions).

**If yes**: waves are appropriate.

**Current adopters**: `sprint-dev` (story DAG from `depends_on` fields).

**Potential future adopters**: `roadmap` Phase 7 (foundation epics before feature epics — weak case; optional).

#### Dependency Resolution Algorithm

**Input**: work units with optional `depends_on: [<id>...]` field.

**Algorithm** (Kahn's topological sort layered):
1. Compute in-degree for each unit from the `depends_on` edges.
2. **Wave 0**: all units with in-degree 0.
3. **Wave N**: all units whose dependencies are ALL in Waves 0..N-1.
4. Continue until all units are assigned to a wave.

**Invalid**: a cycle causes some units to never reach in-degree 0. Hard-fail with a cycle report. Do not attempt partial execution.

**Critical path**: the longest dependency chain determines the minimum wave count.

#### Size Caps

**No built-in size cap.** The calling skill decides how many parallel agents are available per wave. If a single wave exceeds available slots, sub-batch within the wave using a caller-specified priority ordering. `sprint-dev` uses: `schema/type > server > store > component > test`.

#### Worker Pool Semantics

- **Within a wave**: all units may execute in parallel.
- **Between waves**: no unit in Wave N may start until all units in Wave N-1 are complete (or explicitly skipped with documented reason).
- **Completion polling**: orchestrator polls completion via `TaskList`, not sleep-wait. Output-file existence checks (Section 2) confirm each unit actually wrote its deliverable.

#### Progress Reporting Hooks

- **Wave start**: print wave number, size, unit ids starting.
- **Unit completion**: update tracker; check wave-complete condition.
- **Wave completion**: emit Wave Progress per [terse-output.md](terse-output.md); write checkpoint per [session-lifecycle.md](session-lifecycle.md); commit + push (`<type>(<skill>): wave N complete`).

#### Checkpoint Behavior

Wave boundaries are the natural pause points:
- **`autonomous`**: no user pause; commit + push only.
- **`checkpoint`**: pause after wave completion; present results; await confirmation.
- **`interactive`**: per-unit confirmation; waves still computed but control at unit granularity.

STATE.md must include a Wave Progress table when a skill uses waves (schema in [session-lifecycle.md](session-lifecycle.md)).

#### Opting In

1. Declare a dependency graph on your work units.
2. Compute waves via the algorithm above.
3. Reference this doc's Wave section in your Additional Resources.
4. Implement the progress hooks above.
5. Add a Wave Progress table to your STATE.md schema if you use checkpointing.

#### Risks (do not use waves if)

- **Cargo-cult adoption**: future authors reach for waves as a "standard pattern" without a real DAG. The Gate section is the guard.
- **Soft dependencies**: if dependencies are informational (e.g., "it would be nice if backend review saw security first"), the bookkeeping cost exceeds the scheduling benefit. Leave such cases as flat pools.

---

### 5. Model and Context Inheritance

Resolution order (highest priority first):
1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
2. Per-invocation `model` parameter (Agent tool argument)
3. Subagent definition's `model:` frontmatter
4. Main conversation's model (inheritance default)

**Default is `inherit`** — including `[1m]` flags. A Sonnet-declared subagent invoked from an Opus `[1m]` parent inherits `[1m]` too, then crashes at load because Sonnet 4.6 requires `/extra-usage` for 1M.

**To force a specific model without `[1m]`**: set explicit `model: sonnet` / `model: opus` (no `[1m]`) in the subagent frontmatter or the Agent tool call.

**To override globally**: `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` forces all subagents regardless of frontmatter.

**Subagents cannot spawn subagents**: the harness prevents infinite nesting. Chain from the main conversation, not from within another subagent.

**Subagents do not inherit skills**: list any required skills explicitly in the subagent definition's `skills:` frontmatter field.

---

### 6. Reviewer Checklist Summary

Sprint-review (`/blitz:sprint-review`) must flag these as BLOCKERs on any new or modified agent-spawn site:

- [ ] `subagent_type` declared explicitly at every spawn (no heuristic fallback)
- [ ] Weight class declared (Light / Medium / Heavy) in the prompt template
- [ ] Mandatory patterns present for the declared class:
  - Light: output-file existence check
  - Medium: + write-as-you-go + wall-clock timeout in prompt
  - Heavy: + HEARTBEAT + PARTIAL + turn-budget declaration
- [ ] None of the banned patterns used (unbounded files, unbounded diff, write-at-end)
- [ ] Orchestrator validates output file exists and is non-empty before consuming
- [ ] Model declared explicitly (not relying on inheritance) if the skill is invokable from `[1m]` parents
- [ ] No files modified outside assigned story scope without a DEVIATION report per [/_shared/sprint-contracts.md](sprint-contracts.md) Tier 2 or Tier 3

Absence of any item is a BLOCKER, not a suggestion.

---

### 7. Output Style (Terse Output Protocol)

Every agent spawn MUST inject the terse-output directive. Reduces cumulative output-token cost 20–40% per sprint without affecting structured artifacts.

**Mandatory prompt snippet** — append to every Agent() prompt template:

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

Full protocol (intensity levels, auto-pause, examples): [/_shared/terse-output.md](terse-output.md).

**Active-intensity interpolation.** The literal `terse-technical` resolves at spawn time per precedence: (1) `BLITZ_OUTPUT_INTENSITY` env, (2) `.cc-sessions/developer-profile.json` `output_intensity`, (3) SKILL.md frontmatter `output_intensity`/legacy `output_style`, (4) default `lite`. Orchestrators SHOULD substitute the resolved intensity explicitly.

**Auto-drop exceptions:** security/credential warnings, irreversible-action confirmations, root-cause explanations (reasoning chain must survive).

Enforced as Invariant 5 in sprint-review Phase 3.6 (BLOCKER) — any SKILL.md or references/main.md (with agent-prompt template) missing the snippet fails the sprint.

---

### 8. Agent Output Contract (success / failure / partial)

Unified definition of what counts as a successful agent return, what counts as failure, and what counts as PARTIAL. Every orchestrator that spawns agents and consumes their output MUST use these definitions — no per-skill drift on thresholds.

#### 8.0 Trust boundary (TB-3) — sub-agent output is not higher-trust than the content it processed

**Rule:** a sub-agent reply is **not** trusted because it "came from us." An agent that fetched a URL or read an untrusted file is a *conduit* for that content; treating its output as higher-trust than raw tool results opens a new prompt-injection vector (the article's multi-agent trust escalation, AP-6). Canonical posture: [threat-model.md](security.md) §3 TB-3.

**Blitz already implements the structural mitigation — name it.** Blitz's orchestrator + sub-agent split is the **dual-LLM / information-flow-control** pattern (Willison 2023; "Design Patterns for Securing LLM Agents," arXiv 2506.08837): the orchestrator is the privileged planner that *cannot* call `Agent()` (§5, subagents-cannot-spawn-subagents), and sub-agents are quarantined readers that return **structured JSON only** (§9) = "a schema-validated channel carrying only structured extractions, never raw untrusted content." The missing piece this clause adds is the **provenance label**.

**Two requirements:**
1. **`source_trust` label.** Agents that process untrusted input (`research-critic` — WebFetch; `reviewer` — diffs; `backend/frontend-dev` — read arbitrary files) MUST set `"source_trust": "untrusted"` in their §9 reply. This is a CaMeL-style source-of-data capability tag (arXiv 2503.18813). Default when absent: `"trusted"` (pure-reasoning agents that touched no external content).
2. **Cap + scan on interpolation.** Regardless of `source_trust`, the orchestrator MUST `[0:200]`-cap and injection-scan **any reply field it interpolates into a downstream prompt or shell command** — exactly as it caps raw tool output (orchestrator.md §4). The interpolation-risk fields are `summary` and `issues[].what`. `files_changed[]` entries are validated as worktree paths, never executed as instructions.

**Honest scope:** this is defense-in-depth provenance tagging *in the spirit of* CaMeL capabilities — Blitz has no mediating interpreter and claims **no** provable-security guarantee (threat-model.md §6). The dual-LLM structural split is the load-bearing part; the tag is the label on it.

#### Output classifications

| Outcome | Definition | Orchestrator action |
|---|---|---|
| **SUCCESS** | Output file exists, is non-empty (≥ 1 line), parses as the declared format (JSON/YAML/Markdown), and does NOT contain a `PARTIAL: true` marker block. | Consume normally. |
| **PARTIAL** | Output file exists, is non-empty, parses, AND contains a `PARTIAL: true` marker block (Section 3) with `COMPLETED:` and `MISSING:` lists. | Use the COMPLETED sections; queue MISSING items for narrow retry. Warn the user. |
| **MALFORMED** | Output file exists but does not parse as the declared format, OR contains the `PARTIAL: true` token but lacks `COMPLETED:`/`MISSING:` fields. | Treat as FAILURE. Do not retry the same prompt. |
| **EMPTY** | Output file exists but is zero-byte. | Treat as FAILURE. Common cause: agent crashed mid-write or budget-exhausted before first write. |
| **MISSING** | Output file does not exist after wall-clock + 30s grace. | Treat as FAILURE. |
| **TIMEOUT** | Wall-clock budget exceeded; output file may exist with partial content but no PARTIAL marker. | If file exists and is non-empty, treat as PARTIAL with implicit `COMPLETED: <best-effort>, MISSING: <unknown>, CONFIDENCE: low`. Otherwise, FAILURE. |

#### Standard gate thresholds

`MISSING_COUNT` = count of agents that returned MISSING / EMPTY / MALFORMED (i.e., NOT SUCCESS and NOT PARTIAL).

| Spawn fan-out (N agents) | MISSING_COUNT >= | Action |
|---|---|---|
| N = 1 | 1 | ABORT the orchestrator phase. The single agent failed; no degraded path is acceptable. |
| N = 2 | 1 | WARN. Proceed only if the surviving agent's domain covers the failed one. |
| N = 2 | 2 | ABORT. |
| N = 3 | 2 | ABORT. |
| N = 4+ | ⌈N / 2⌉ | ABORT. (Half-or-more failure means degraded synthesis, not partial loss.) |

These thresholds are hard rules. Skills MUST NOT define their own. If a skill genuinely needs a different threshold (e.g., 10-agent audit pillars), it MUST document the deviation in its SKILL.md with rationale, and sprint-review Phase 3.6 flags undocumented deviations as BLOCKERs.

#### PARTIAL retry policy

When PARTIAL is detected:
1. Extract the `MISSING` list from the marker block.
2. Spawn ONE narrow-scope retry agent per MISSING item, with the same `subagent_type`, `model`, and weight class as the original.
3. The retry prompt must explicitly cite the prior PARTIAL output and scope down to ONE missing item per agent.
4. Retry budget per item: 1 attempt only. A second PARTIAL on the same item escalates to operator (do not infinite-retry).
5. Merge retry outputs into the original output file and mark `PARTIAL: false` if all MISSING items resolved.

#### Validator script (orchestrator-side)

Every spawn site MUST run this check before consuming output:

```bash
classify_output() {
  local f="$1"
  if [ ! -f "$f" ]; then echo MISSING; return; fi
  if [ ! -s "$f" ]; then echo EMPTY; return; fi
  # Check declared format parses
  case "$f" in
    *.json) jq empty "$f" 2>/dev/null || { echo MALFORMED; return; } ;;
    *.yaml|*.yml) yq -e . "$f" >/dev/null 2>&1 || { echo MALFORMED; return; } ;;
  esac
  # Check PARTIAL marker
  if grep -q '^PARTIAL: true' "$f"; then
    if grep -q '^COMPLETED:' "$f" && grep -q '^MISSING:' "$f"; then
      echo PARTIAL
    else
      echo MALFORMED
    fi
    return
  fi
  echo SUCCESS
}

# Tally outcomes
declare -A COUNTS=()
for f in "${EXPECTED_OUTPUTS[@]}"; do
  c=$(classify_output "$f")
  COUNTS[$c]=$((${COUNTS[$c]:-0} + 1))
  echo "$f → $c"
done

MISSING_COUNT=$(( ${COUNTS[MISSING]:-0} + ${COUNTS[EMPTY]:-0} + ${COUNTS[MALFORMED]:-0} ))
N=${#EXPECTED_OUTPUTS[@]}

# Apply standard gate
case $N in
  1) THRESHOLD=1 ;;
  2|3) THRESHOLD=2 ;;
  *) THRESHOLD=$(( (N + 1) / 2 )) ;;
esac

[ "$MISSING_COUNT" -ge "$THRESHOLD" ] && { echo "ABORT: $MISSING_COUNT/$N agents failed"; exit 1; }
```

---

### 9. Token Budget and Reply Contract

Cost-control rules for every spawn. Authoritative protocol is [`token-budget.md`](#token-budget-protocol). Every Agent() spawn MUST satisfy:

1. **Explicit `model:`** — never inherit. Default Haiku; promote to Sonnet for impl/review; reserve Opus for heavy reasoning. ≈60/35/5 distribution target.
2. **Canonical JSON reply** — return ONLY `{status, summary≤50w, files_changed, issues, next_blocked_by, metrics}`. Prose forbidden. Files referenced by path; never inlined.
3. **Cache-friendly system prompts** — structure long agent bodies (≥1024 tokens) static-prefix-first (role/roster/protocols/output-style), dynamic content (sprint context, story args, feed slice) after. The platform/SDK applies prompt caching to the stable prefix; the 1h ephemeral TTL is a platform/SDK concern, not settable from skill/agent markdown.
4. **Lazy MCP / skill loading** — never bulk-enable; ToolSearch + on-demand grep only.
5. **PostToolUse output summarization** — verbose tool output (test/build logs) MUST be summarized before reaching the orchestrator.

**Required spawn-prompt boilerplate** (paste verbatim near end of every Agent() prompt):

```
Return ONLY this JSON, nothing else (no markdown fence, no preamble):
{
  "status": "complete|partial|failed",
  "summary": "<one sentence ≤50 words>",
  "files_changed": ["..."],
  "issues": [{"severity": "...", "where": "...", "what": "..."}],
  "next_blocked_by": [],
  "source_trust": "trusted|untrusted"
}
Any deviation breaks orchestrator parsing.

`source_trust` (§8.0, TB-3): set `"untrusted"` if this agent fetched a URL, read an
untrusted/external file, or ingested a diff/README from outside the repo; else omit (defaults
`"trusted"`). The orchestrator caps + injection-scans interpolated fields (`summary`,
`issues[].what`) regardless — the tag raises scrutiny, it is not a substitute for the cap.
```

Skills that produce rich artifacts (research docs, audit reports) write to a file and reference it in `files_changed[]`.

The orchestrator validates each reply with `jq` per [token-budget.md §3](#token-budget-protocol). MALFORMED replies are classified per §8 and trigger the standard gate.

---

### How to Reference This Doc

Every blitz skill that spawns subagents should add to its Additional Resources block:

```markdown
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves, output style), see [spawn-protocol.md](#subagent-spawn-protocol)
```

---

### Related Protocols

- [session-lifecycle.md](session-lifecycle.md) — session IDs, locking, activity feed
- [session-lifecycle.md](session-lifecycle.md) — STATE.md schema for resumable orchestrators
- [terse-output.md](terse-output.md) — progress reporting conventions
- [session-lifecycle.md](session-lifecycle.md) — context window hygiene
- [sprint-contracts.md](sprint-contracts.md) — agent escalation handling
- [sprint-contracts.md](sprint-contracts.md) — quality gate standards



---

<!-- ===== Absorbed from agent-prompt-boilerplate.md ===== -->

## Agent Prompt Boilerplate

Canonical text for prompt sections that recur across blitz orchestrator skills (audit, codebase-map, code-sweep, quality-metrics, sprint-dev, sprint-plan).

**Purpose:** author-time deduplication of the ~12 K tokens/sprint of recurring Agent() prompt boilerplate. Skills currently inline these sections in their own `references/main.md` for byte-stable spawn behavior. Future orchestrators may Read this fragment plus the per-skill `references/main.md` and splice the relevant section into the Agent() prompt at spawn time, replacing the inline copy. Until that splice machinery exists in every orchestrator, the inline copies in `skills/<skill>/references/main.md` remain authoritative; this fragment is the canonical reference + extraction target.

**Important:** the `OUTPUT STYLE: terse-technical …` snippet is NOT extracted here. Sprint-review Invariant 5 (per S5-003) requires that snippet to be present verbatim in every references/main.md — deduping it would break the invariant. The canonical OUTPUT STYLE text lives in [spawn-protocol.md §7](#7-output-style-terse-output-protocol).

**Companion docs:**
- [spawn-protocol.md](#subagent-spawn-protocol) — weight classes (Light/Medium/Heavy), HEARTBEAT/PARTIAL canonical specs, banned patterns
- [terse-output.md](terse-output.md) — the OUTPUT STYLE protocol referenced by every Agent() prompt
- [terse-output.md](terse-output.md) — activity-feed log format

---

### Generic Agent Preamble

Used by orchestrators that spawn `general-purpose` Agents and require a written output file. Present in: `codebase-map`, `quality-metrics`, `sprint-plan`.

```
You are a general-purpose agent with Write access. Your task is INCOMPLETE
if {{OUTPUT_PATH}} does not exist when you finish.
```

**When to use:** any Agent() spawn whose deliverable is a file the orchestrator will Read after the agent returns. Combine with the orchestrator-side existence check (see `spawn-protocol.md` §2 "Orchestrator-Side Validation"). Replace `{{OUTPUT_PATH}}` with the absolute path the agent must write.

---

### Weight-Class Budget Block

Every Medium/Heavy Agent() spawn declares its budget in the prompt. Caps per `spawn-protocol.md` §2.

#### Medium class

Used by: `codebase-map` (per-dimension agents), `sprint-plan` (research agents).

```
BUDGET (Medium class — see skills/_shared/agent-orchestration.md):
- Max file reads: 15
- Max web searches: 8 (0 for codebase-only analysis)
- Max tool calls: 25
- Max output: 250 lines
- Wall-clock: 5 minutes
```

#### Light class

Used by: `quality-metrics` (per-tool collectors).

```
BUDGET (Light class — see skills/_shared/agent-orchestration.md):
- Max bash commands: 1 (the tool invocation itself)
- Max file reads: 5
- Max tool calls: 8
- Max output: JSON (per per-tool schema)
- Wall-clock: 3 minutes
```

#### Heavy class

Used by: `sprint-dev` dev agents (multi-story implementation in worktree).

```
BUDGET:
- Max stories this wave: 4 (already enforced by orchestrator)
- Max file reads per story: 6
- Max tool calls total: 40 (if you hit 30, finish current story and stop)
- Wall-clock: 8 min
```

**When to use:** include the matching block verbatim near the top of every Medium/Heavy Agent() prompt. Override caps with documented rationale only — defaults exist to bound silent-failure cost.

---

### Write-As-You-Go Preamble

Mandatory for Medium and Heavy agents. Prevents zero-output failure on timeout or turn-budget exhaustion. Present in: `codebase-map`, `quality-metrics` (implied by JSON-stub start), `sprint-plan`.

```
WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the output file with a header line.
2. After each checklist item / phase / finding, append to the file.
3. Do NOT accumulate findings in memory and write at the end.
```

**Variant for JSON outputs** (used by `code-sweep` tier agents):

```
WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the output file with an empty findings array.
2. After each check category completes, rewrite the file with the appended findings array.
```

**When to use:** every Medium/Heavy spawn whose output is a file. The orchestrator should still run the existence check from `spawn-protocol.md` §2 — write-as-you-go is the agent-side complement.

---

### HEARTBEAT Protocol

Mid-run liveness signal. Canonical spec in [spawn-protocol.md §3](#3-heartbeat-and-partial-protocols). Present in: `codebase-map`, `sprint-dev` (Item 12).

#### File-append form (default)

Canonical block in [§3](#3-heartbeat-and-partial-protocols) — paste it verbatim.

#### JSON-finding variant (for agents whose output is a JSON array)

```
HEARTBEAT (recommended):
At the start of each check category, append this line to your output file
as a special finding with `"check": "_heartbeat"`:
  {"check": "_heartbeat", "phase": "<category>", "ts": "<ISO-timestamp>"}
Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamp.
```

#### Story-completion variant (sprint-dev dev agents)

```
HEARTBEAT: After each story DONE, write a file ${SESSION_TMP_DIR}/agent-<role>-progress.md
appending: HEARTBEAT: S${N}-XXX done at <ISO-timestamp>. Use date -u +%Y-%m-%dT%H:%M:%SZ.
```

**When to use:** required for Heavy agents; recommended for Medium. Pick the variant matching your output schema.

---

### PARTIAL Transcript Protocol

Graceful degradation on budget exhaustion. Canonical spec in [spawn-protocol.md §3](#3-heartbeat-and-partial-protocols). Required for Heavy class. Present in: `sprint-dev` (Item 12).

#### Heavy-class canonical form

Canonical block in [§3](#3-heartbeat-and-partial-protocols) — paste it verbatim.

#### Sprint-dev variant (story-id granularity)

```
PARTIAL: If you have fewer than 3 tool calls remaining, STOP before starting
a new story. Append to your progress file:
  PARTIAL: true
  COMPLETED: [list of story ids finished]
  REMAINING: [list of story ids unstarted]
  CONFIDENCE: low|medium|high
Send PARTIAL: <N> done, <M> remaining to orchestrator via the DONE/BLOCKED
protocol and end.
```

**When to use:** mandatory for Heavy agents; orchestrator must check for `PARTIAL: true` before consuming output and re-spawn narrowly on items in MISSING/REMAINING.

---

### Confirmation Line

Used by Medium agents to signal completion to the orchestrator without echoing findings. Present in: `codebase-map`, `quality-metrics`, `code-sweep` (tier agents).

```
CONFIRMATION: Emit one line: "<scope-id>: <N items written>"
Do NOT echo findings in your response.
```

**When to use:** any agent whose output is a file the orchestrator will read. Prevents stdout from re-transmitting payload that the file already contains (saves tokens, keeps logs clean).

---

### Self-Falsification (audit-style agents)

Before recording any count-based, negative, or pattern-duplication finding, construct a falsification artifact (Bash, AST query, file Read) and include the artifact + output in the Evidence field. Add `Confidence: <0-100>` to every finding.

```
SELF-FALSIFICATION (audit-style only):
- Count-based ("N hits of X"): grep -n 'pattern' file | head -3; verify hits are
  content, not path/filename substrings.
- Negative ("X is absent from Y"): grep -in '<4-char-partial-of-X>' Y; any hit
  means re-evaluate.
- Pattern-duplication ("X duplicated across N files"): require N ≥ 35% of
  in-scope files AND Read 2 alleged duplicates for structural equivalence
  (not keyword overlap).
- Confidence: 0=false-positive, 25=might-be-real, 50=real-but-minor,
  75=real-and-important, 100=definitely-real. Orchestrator filters below 80.
- If Confidence < 50 after falsification: DO NOT record as a finding. Log a
  one-line entry to a separate `## Discarded Drafts` section at the bottom
  of the output file: `- <one-line claim> (Confidence N, refuted by <artifact>)`.
  Reserves finding-slots for actionable items.
- "No violations found" reports go in a separate `## Verified Clean` section,
  NOT in findings. Findings are for things to fix; clean checks are for the
  reader to see what was inspected and passed.
- Count discipline: claiming "N files match X" requires `grep -l X <files> | wc -l`
  (file count), NOT `grep -rn X <files> | wc -l` (hit count). The two differ
  when any file has multiple matches. If the claim is about hits, name it
  ("30 occurrences across 29 files"). When in doubt, run both and report
  both. Failure mode observed 2026-05-16 blind retest: "30/38 files" claim
  was actually 29 files / 30 hits (one file had 2 mentions).
- Also distinguish WHICH thing you're counting before falsifying. "Files with
  block X" ≠ "files with heading of X" ≠ "files with one line of X". Sample
  2-3 alleged hits with Read before reporting the count.

This is artifact construction, NOT self-judgment. Shell decides.
Per docs/_research/2026-05-16_audit-agent-fp-prevention.md.
```

**Output-path resolution.** When the spawning orchestrator gives you an output file path containing `${VAR}` or a `${SESSION_TMP_DIR}` placeholder, resolve it via Bash (e.g., `ls /tmp/blitz-*` or `echo "$SESSION_TMP_DIR"`) BEFORE writing your stub. Do NOT take literal placeholder text (`OUTPUT`, `<dir>`, `$VAR`) as the actual path — find the real one. Failure mode observed 2026-05-16: agent wrote to `/tmp/blitz-audit-test-OUTPUT/findings.md` literally instead of resolving the session dir.

**When to use:** every audit-style spawn (audit, code-sweep, conventions audit, flow-consistency audit, the meta-audit agents in `/blitz:research` on internal topics). NOT for sprint-dev workers (they generate code, not claims) or sprint-review reviewers (they synthesize cross-cutting findings rather than count occurrences).

**Why required:** count-as-claim with no falsification is the documented FP pattern (3 false positives in the 2026-05-16 self-audit). Literature (CHIIR 2026, EMNLP 2025) shows "ask the agent again" amplifies bias; artifact construction routes the verification through the shell, which is deterministic.

---

### Verification-First Oracle (spec-fix agents)

Used by `test-writer` and any agent invoked to fix a failing test/spec. Forces structured oracle construction BEFORE editing — empirically correlated with reduced implementation-shifting (modifying tests instead of code).

```
VERIFICATION-FIRST ORACLE (spec-fix only):
Before editing any file, write this oracle to your scratchpad:

  Spec file:    <absolute path>
  Test name(s): <ids of failing it()/test() blocks>
  Test source:
    ```<lang>
    <verbatim test code from the failing block(s)>
    ```
  Current actual output:
    <captured from `npx vitest run <spec>` or `npx jest <spec>`>
  Expected output:
    <derived from spec assertions; if not derivable, state UNKNOWN and STOP —
     emit ESCALATE: oracle-underivable instead of guessing>
  Constraint:   Fix the IMPLEMENTATION. Do NOT modify test assertions,
                describe/it block names, or expect(...) lines. If the test
                itself looks wrong, emit ESCALATE: test-assertion-suspect
                and STOP.
  After fix:    Run the test, paste runner output showing it passes, stop.

Per docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md F1.
```

**When to use:** every spec-fix dispatch (test-writer in fix mode, sprint-dev wave that targets failing specs, fix-issue when the issue is a failing test). NOT for new test generation (use the Spec Fix Prompt Template only when fixing existing failures).

**Why required:** Anthropic Claude Code best practices: "Claude performs dramatically better when it can verify its own work." The oracle artifact converts implicit goal-inference into explicit derived-state, removing the room for the agent to drift from "make the test pass" to "modify the test to pass."

---

### Output-Style Reference (NOT extracted — invariant)

The canonical OUTPUT STYLE snippet that closes every Agent() prompt template lives in [spawn-protocol.md §7](#7-output-style-terse-output-protocol). It is **deliberately not extracted into this fragment.** Sprint-review Invariant 5 enforces verbatim presence of that snippet in every `skills/*/references/main.md` agent-prompt template. Deduping it would break the invariant. Each references/main.md must continue to carry the snippet inline.

For the resolved active-intensity behavior at spawn time, see `spawn-protocol.md` §7 "Active-intensity interpolation".

---

### How Orchestrators Use This Fragment

Two integration patterns:

#### Pattern A — author-time reference only (current default)

Skills inline the relevant boilerplate sections in their own `references/main.md`. This fragment serves as the canonical source for what the inline text should say. When updating a recurring section, edit here first, then propagate to the affected references/main.md files. The orchestrator does NOT Read this fragment at spawn time.

#### Pattern B — runtime splice (future)

The orchestrator Reads both `skills/<skill>/references/main.md` and `skills/_shared/agent-orchestration.md` at spawn time, then splices the relevant section into the Agent() prompt where the import marker appears in references/main.md. Once every orchestrator that spawns from a given references/main.md has migrated to Pattern B, the inline copy in that references/main.md may be removed.

**Migration safety:** Pattern B requires byte-identical resolved-prompt parity (see S5-001 AC3). Until parity is verified for a specific orchestrator+skill pair, the inline copy must remain — Invariant 5 (OUTPUT STYLE) and exact-match TASKS lists in agent prompts depend on per-byte stability.

---

### Per-Skill Section Index

| references/main.md | Sections currently inlined (mirror these from this fragment when updating) |
|---|---|
| `audit/references/main.md` | OUTPUT STYLE only — no HEARTBEAT/PARTIAL/BUDGET (audit pillars use their own pillar-checklist budget) |
| `codebase-map/references/main.md` | Generic agent preamble · Medium BUDGET · WRITE-AS-YOU-GO · HEARTBEAT (file-append) · CONFIRMATION |
| `code-sweep/references/main.md` | OUTPUT STYLE only — tier agents have a 90-second budget inline; JSON write-as-you-go implicit in single-array Write |
| `quality-metrics/references/main.md` | Generic agent preamble · Light BUDGET · WRITE-AS-YOU-GO (implicit) · CONFIRMATION |
| `sprint-dev/references/main.md` | Heavy BUDGET (Item 3) · HEARTBEAT (story-completion variant) + PARTIAL (sprint-dev variant) (Item 12) |
| `sprint-plan/references/main.md` | Generic agent preamble · Medium BUDGET · WRITE-AS-YOU-GO |

When extending boilerplate or fixing a bug in a recurring section, update this fragment first, then propagate to the affected references/main.md files.


---

<!-- ===== Absorbed from agent-routing.md ===== -->

## Agent Routing Protocol

How the blitz orchestrator agent (`agents/orchestrator.md`) decides between (a) doing work inline, (b) spawning a specialist subagent, or (c) routing the user to a slash command. Authoritative reference for orchestrator behavior + the constraint that prevents naive skills→agents migration.

**Why this doc exists**: research/2026-05-01_skills-to-agents-architecture.md identified the hard constraint that **subagents cannot spawn subagents**. Several blitz skills are super-orchestrators that spawn parallel agent waves; they cannot become subagents themselves. This doc specifies the resulting Hybrid Pattern A: orchestrator at the top, slash commands preserved, specialist subagents handle leaf work only.

---

### 1. The hard constraint

A subagent (anything spawned via `Agent()`, including the blitz orchestrator activated via plugin `settings.json {"agent": "orchestrator"}`) does NOT have access to the `Agent` tool. It cannot itself spawn a subagent.

Source: `code.claude.com/docs/en/sub-agents`. Confirmed in research doc 2026-05-01_skills-to-agents-architecture.md §3.4.

**Practical consequence**: any skill whose body contains `Agent({...})` calls — to spawn parallel reviewers, parallel research agents, parallel sprint workers — CANNOT itself be invoked as a subagent. It must remain a slash-invoked skill (which runs in the main thread and DOES have Agent() access).

The same boundary applies to the `Workflow` tool (dynamic workflows): it is main-thread-only, so only the 11 super-orchestrators may dispatch via it, and only as a capability-gated opt-in path with the `Agent()` path retained as fallback. See [workflow-dispatch.md](#workflow-dispatch-contract).

---

### 2. Skill classification (37 skills)

| Class | Count | Examples | Routing rule |
|---|---|---|---|
| **Super-orchestrator** (spawns ≥2 agents in parallel) | 10 | sprint-dev, sprint-plan, sprint-review, research, audit, quality-metrics, code-sweep, sprint, code-doctor, ui-audit | **Slash-only**. Orchestrator routes user to `/blitz:<name>`. Never tries to invoke directly. |
| **Single-spawn orchestrator** (spawns ≤1 agent or invokes one downstream skill) | 9 | codebase-map, doc-gen, health, implement, migrate, retrospective, roadmap, design-extract | Future: could become subagents (out of scope for v1.11). Today: slash-only. |
| **Router / chainer** (invokes other skills sequentially via slash) | 10 | ship, fix-issue, ui-build, review, bootstrap, conform, setup, browse, perf-profile, next | **Slash-only**. Chains slash invocations the orchestrator can't replicate. |
| **Pure worker** (no spawning, no chaining) | 7 | quick, ask, todo, dep-health, refactor, test-gen, perf-profile | **Slash-only by default**. Migration to agent costs ~15× tokens with no parallelism gain — keep as cheap slash invocations. |

Total: orchestrator routes everything to slash commands. The "agent ecosystem" lives below the slash boundary, where each orchestrator-tier skill spawns its own specialist agents.

---

### 3. What the orchestrator CAN do without spawning

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

### 4. Routing decision tree

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

### 5. Disabling the orchestrator

Two paths:

1. **Per-project**: project-level `.claude/settings.json` overrides plugin settings. Set `{"agent": null}` to disable.
2. **Per-session**: env var `BLITZ_DISABLE_ORCHESTRATOR=1`. Hooks honor this and skip orchestrator initialization.

Disabling falls back to direct user-typed slash commands as the sole entry point — the pre-v1.11 behavior.

---

### 6. UX: what the user sees

**Before v1.11** (orchestrator absent):
- User types `/blitz:sprint-dev`. Skill runs.
- User types "implement the sprint." Claude Code main thread interprets; may or may not pick the right skill.

**After v1.11** (orchestrator activated):
- User types `/blitz:sprint-dev`. Slash invocation bypasses orchestrator; skill runs as before.
- User types "implement the sprint." Orchestrator subagent receives the request, replies: "→ /blitz:sprint-dev. Why: matches 'implement sprint' intent. State: sprint-3 phase 4, 8 stories pending."
- User invokes `/blitz:sprint-dev` next turn. Skill runs.

The orchestrator is a routing layer, not a wrapper. It doesn't change what slash commands do; it makes freeform input land on the right one.

---

### 7. State injection vs UserPromptExpansion

`hooks/scripts/blitz-prompt-expansion.sh` fires only on `/blitz:.*` slash invocations (UserPromptExpansion). Freeform prompts that route through the orchestrator do NOT fire this hook.

To preserve the activity-feed-injection behavior on freeform turns, the orchestrator's `initialPrompt:` reads `.cc-sessions/activity-feed.jsonl` directly. The hook still fires for slash invocations; the orchestrator covers freeform invocations. Together, both paths surface state.

---

### 8. Future: single-spawn orchestrator migration

The 9 "single-spawn orchestrator" skills (codebase-map, doc-gen, health, implement, migrate, retrospective, roadmap, design-extract) are candidates for promotion into specialist agents that the orchestrator CAN spawn directly. Out of scope for v1.11. When migrating, follow:

- Lift the SKILL.md body into `agents/<name>.md` with explicit `model:` per token-budget routing matrix.
- Reduce the SKILL.md to a thin shim (≤80 lines) that re-targets the agent for slash-invocation users.
- Verify the agent does not call `Agent()` (it cannot, it's a subagent).
- Bump `compatibility:` if any new fields are used.

The 11 super-orchestrators stay as skills permanently (the constraint is structural, not migratable).

---

### Related

- [`token-budget.md`](#token-budget-protocol) — model routing for orchestrator (sonnet) vs workers
- [`spawn-protocol.md`](#subagent-spawn-protocol) — agent spawn rules from inside a skill (the level above the orchestrator)
- [`session-lifecycle.md`](./session-lifecycle.md) — session lifecycle
- `agents/orchestrator.md` — the implementation
- `.claude-plugin/settings.json` — activation
- `docs/_research/2026-05-01_skills-to-agents-architecture.md` — research basis (Hybrid Pattern A)


---

<!-- ===== Absorbed from agent-view-dispatch.md ===== -->

## Agent-View Dispatch and Background-Session Interop

How blitz skills run as **background sessions** under Claude Code's native agent view (`claude agents`, CC >=2.1.139, research preview), and how blitz's parallel-session machinery interops with the platform. Provenance: `docs/_research/2026-05-30_parallel-claude-sessions.md` (deliverables A/C/D).

Blitz does **not** reimplement the agents view, recaps, or terminal multiplexing — the platform owns those. This doc covers the interop blitz does own: dispatch ergonomics, row-summary quality, worktree reconciliation, the conflict overlay, and remote alerts.

### Dispatching a blitz skill as a background agent

blitz skills (`/blitz:*`) and agents (`@backend-dev` etc.) are valid agent-view dispatch targets with zero extra code:

```bash
claude --bg "/blitz:audit"                       # dispatch a skill to the background
claude --bg --name "audit-q2" "/blitz:audit"     # named row in agent view
claude --agent backend-dev --bg "implement CAP-12"   # run a blitz agent as the main session agent
```
Or interactively: open `claude agents`, type `/blitz:audit` in the dispatch input, press Enter. From inside a running session: `/bg` (alias `/background`) to background the current conversation.

Manage from the shell: `claude attach <id>`, `claude logs <id>`, `claude stop <id>`, `claude respawn <id>`, `claude rm <id>`, `claude daemon status`.

**Version floor:** agent view v2.1.139+; `claude agents --json` / `--cwd` v2.1.141+; `worktree.bgIsolation` v2.1.143+; `--agent` dispatch honoring blitz agent defs v2.1.157+. All blitz interop degrades silently below these floors.

### Row-summary quality (orchestrators show as ONE row)

Agent view shows each background session as one row whose one-line summary is **Haiku-generated from recent output** (refresh ≤15s + at each turn end). Subagents and Workflow agents a session spawns are **not** separate rows — a blitz orchestrator (sprint-dev, audit, research) appears as a single row.

Implication: the orchestrator's row can look idle while its fan-out agents work. Mitigation — the [terse-output.md](terse-output.md) current-phase one-liner is what the Haiku summarizer reads. Emit it frequently and make it carry fan-out state (e.g. `sprint-dev wave 2/3 · 4/7 stories done`) so the row reads true. This is already the verbose-progress contract; background dispatch makes it load-bearing.

### Worktree isolation interop

Background sessions auto-isolate into `.claude/worktrees/<id>` before editing — the same dir blitz `Agent({isolation:"worktree"})` worktrees use. The reconciliation (live-session prune guard, collision-guard scope, `worktree.bgIsolation: "none"` escape hatch) is specified in [worktree-lifecycle.md](worktree-lifecycle.md) §Interop. Never prune a live background session's worktree — it holds uncommitted work.

### Cross-session conflict overlay

The platform manages session *processes* but does **not** do semantic conflict detection. blitz's conflict matrix still applies — and is extended to background sessions via [session-lifecycle.md](session-lifecycle.md) §5b-i (reads `claude agents --json`, infers skill from session name, WARNs on matrix hits). This is blitz's durable value-add over native.

### Remote alerts

Native agent view shows a *local* "Needs input" indicator + tab-title count. For **off-screen** alerts (phone), blitz fires `PushNotification` (no-op if Remote Control unconfigured) at genuine human-escalation points only — to avoid notification fatigue:
- Stuck-loop PAUSE — [spawn-protocol.md](#subagent-spawn-protocol) §Stuck-loop detection step 3.
- Deviation Tier-3 ESCALATE — [sprint-contracts.md](sprint-contracts.md) §Orchestrator Handling.

Both gate on the developer-profile `notify` preference (`.cc-sessions/developer-profile.json`; skip when `notify: off`). Completion pushes (sprint-dev, ship) are unchanged.

For an idle terminal bell (the article's "audio signal via hooks"), set `BLITZ_NOTIFY_ON_IDLE=1` — `hooks/scripts/teammate-idle.sh` emits `\a` on `TeammateIdle`. Default off. A hook cannot invoke `PushNotification` (agent-side only), so the bell is the hook-level mechanism.

### Disable

`disableAgentView` setting / `CLAUDE_CODE_DISABLE_AGENT_VIEW=1` turns agent view off. blitz interop (prune live-guard, conflict overlay) then degrades to `.cc-sessions/*.json`-only; `/blitz:health` Phase 2.5 warns when disabled.

### Cross-references

- [worktree-lifecycle.md](worktree-lifecycle.md) §Interop — worktree reconciliation + live-session guard
- [session-lifecycle.md](session-lifecycle.md) §5b-i — conflict overlay
- [spawn-protocol.md](#subagent-spawn-protocol), [sprint-contracts.md](sprint-contracts.md) — remote alert points
- [terse-output.md](terse-output.md) — row-summary source
- Research provenance: `docs/_research/2026-05-30_parallel-claude-sessions.md`


---

<!-- ===== Absorbed from workflow-dispatch.md ===== -->

## Workflow Dispatch Contract

Canonical contract for the Claude Code `Workflow` tool ("dynamic workflows", research preview 2026-05-28) inside the blitz plugin. Defines the **opt-in, capability-gated, additive** adoption pattern: `Workflow` may replace the `Agent()` spawn-poll-classify scaffolding in a super-orchestrator, but never as a hard dependency. Referenced from [spawn-protocol.md](#subagent-spawn-protocol), [agent-routing.md](#agent-routing-protocol), and [token-budget.md](#token-budget-protocol).

Research provenance: `docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md`.

### Why this exists

`Workflow` is a deterministic JS orchestration primitive: a script with `agent()` / `parallel()` / `pipeline()` / `phase()` / `log()` hooks dispatches ≤1000 subagents (min(16, cores-2) concurrent) in the background, with built-in `schema:` structured output, `null`-on-throw error handling, and `resumeFromRunId` resume. It maps ~1:1 onto blitz's hand-rolled spawn-protocol (single-message `run_in_background` pools, output-file polling, `classify_output()`, `jq` reply parsing) and removes ~80–150 lines of bash per adopting skill.

Blitz cannot adopt it naively. `Workflow` is a **research preview**, **disabled-by-default on Enterprise**, and **per-user opt-in gated**. blitz ships to arbitrary users — a skill that *requires* `Workflow` hard-fails for any user without it. Adoption is therefore additive: a capability-gated fast path with the existing `Agent()` path retained as the portable default.

### The hard constraints

1. **Main-thread only.** `Workflow` is callable only from the main thread, exactly like `Agent()`. A subagent cannot call it (subagents-cannot-spawn-subagents, [agent-routing.md](#agent-routing-protocol) §1). Only the 11 slash-only **super-orchestrators** may dispatch via `Workflow`. Pure workers / single-spawn skills MUST NOT.

2. **Script body is sandboxed.** The orchestration script is plain JS: **no filesystem, no `Date.now()` / `Math.random()` / argless `new Date()`**, no Node API. It cannot touch `.cc-sessions/activity-feed.jsonl`, session locks, `carry-forward.jsonl`, `ratchet.json`, or `SESSION_TMP_DIR` paths.

3. **Spawned agents are NOT sandboxed.** Each `agent()` call runs a normal subagent with full Read/Write/Bash/Grep. They still stub-and-append their own findings files exactly as under `Agent()`. The sandbox binds the *script*, not its agents.

4. **Opt-in is satisfied by skill instructions.** Per the `Workflow` tool contract, "the user invoked a skill or slash command whose instructions tell you to call Workflow" counts as opt-in. A blitz super-orchestrator MAY legitimately dispatch via `Workflow` when its SKILL.md instructs it to — no extra user keyword required. (First-trigger confirmation behavior is still platform-controlled — see Open risks.)

### Tool API reference (current)

Live limits/signatures for the `Workflow` runtime (supersedes any earlier fixed-16 wording):

- **Concurrency** — `min(16, cores-2)` simultaneous agents (host-derived; NOT a fixed 16).
- **Lifetime cap** — ≤1000 agents per workflow run.
- **Batch cap** — a single `parallel()` / `pipeline()` call takes ≤4096 items.
- **Budget object** — `{ total, spent(), remaining() }`. `spent()` is shared across the main loop + all workflows; `remaining()` = `max(0, total - spent())`, or `Infinity` when no `total` is set.
- **Nesting** — `workflow(name | {scriptPath}, args)` nests ONE level only; a `workflow()` call from inside a workflow throws.
- **Resume** — `resumeFromRunId` is same-session only (same script + same args ⇒ full cache hit; cross-session resume must re-derive from external state per the sprint-dev `STATE.md` journal pattern).

### Hybrid wrapper boundary

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

### Capability gate + fallback contract

Every `Workflow`-adopting skill MUST select dispatch mode at runtime and retain the `Agent()` path. Selection rule:

```
USE_WORKFLOW = (Workflow tool present)
            AND (BLITZ_DISPATCH != "agent")          # operator force-off
USE_WORKFLOW is forced ON  when BLITZ_DISPATCH == "workflow"
```

- `Workflow` tool present → discoverable in the deferred-tool list / callable. If unknown, attempt the call and on tool-unavailable error fall back to `Agent()`.
- `BLITZ_DISPATCH` (env): `auto` (default — gate as above), `workflow` (force, error if absent), `agent` (force legacy path).
- On ANY `Workflow` dispatch failure (tool absent, script error, abort), **fall back to the `Agent()` path** — never hard-fail the skill. Log the chosen path to the activity-feed (`detail.dispatch: "workflow"|"agent"`).
- The `Agent()` path in [spawn-protocol.md](#subagent-spawn-protocol) remains the canonical, always-present default while `Workflow` is preview.

### Mandatory prompt invariants (carried into `agent()`)

`Workflow`'s `agent()` prompts are subject to the SAME contract as `Agent()` prompts:

- **OUTPUT STYLE snippet** — every `agent()` prompt MUST embed the terse-output snippet ([terse-output.md](terse-output.md)). sprint-review **Invariant 5** blocks PASS if missing. Centralize prompt assembly so the snippet is structurally unavoidable.
- **JSON reply contract** — prefer the `schema:` option (SDK-level validation) over freeform text + `jq`. Schema replaces `parse_reply()` / `classify_output()` boilerplate; `null`-on-throw + `.filter(Boolean)` replaces the MISSING/EMPTY/MALFORMED gate.
- **Model routing** — set `opts.model` per the 60/35/5 Haiku/Sonnet/Opus matrix ([token-budget.md](#token-budget-protocol)). Omit only to inherit the main-loop model.
- **Token budget** — pass/honor `budget` ceilings; cap any loop-until-dry / adaptive-iteration loop with an explicit round limit. Unbounded iteration conflicts with the token-budget protocol.
- **Worktree isolation** — `agent(prompt, {isolation: "worktree"})` is supported and obeys [worktree-lifecycle.md](worktree-lifecycle.md). Same collision-guard + post-merge cleanup invariants apply; verify before using in sprint-dev.

### Pattern mapping (blitz → Workflow)

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

### Adoption status (per skill)

| Skill | Status | Notes |
|---|---|---|
| `audit` | **WIRED** | 10 flat agents → one `parallel()` + `schema` (Phase 1.0 gate + 1.1-W). Adversarial FP-verify refuter panel wired §2.3.5 (per-finding nested `parallel()`, pipeline-over-findings / barrier-over-lenses). |
| `research` | **WIRED** | 2-4 agent pool (`parallel()`) + conditional gap second-wave (`agent()`). §1.2.6 gate + §1.3-W. |
| `sprint-plan` | **WIRED** | 3-4 flat research pool → `parallel()` + `schema`. §2.0 gate + §2.1-W. Mirrors `research`/`audit`. |
| `codebase-map` | **WIRED** | 4 flat dimension agents → `parallel()` + `schema`. §1.0 gate + §1.0-W. |
| `sprint-review` | **WIRED** (narrow) | reviewers → `parallel()` (default) or `pipeline()` (sequential mode, prior findings threaded); critic → `agent({agentType:'blitz:critic', schema})`. §2.2.0-W. Critic `null` → `Agent()` fallback (load-bearing). |
| `sprint-dev` | **WIRED** | per-wave `parallel()` + `isolation: 'worktree'` + `schema` (§2.0 gate + §2.3-W). One wave per `Workflow` call; STATE.md/commit between waves stay main-thread. **Cross-session durable:** `STATE.md` is the durable journal — resume re-derives remaining waves (§1.4 `wave-plan.json`, pure Kahn sort) and dispatches each via `Workflow`. `resumeFromRunId` in-session-only. Resume Divergence Gate is the safety interlock before dispatch. |
| `code-sweep` | **DEFERRED** | flat finder pool; same `parallel()` + `schema` shape as `audit`. |
| `quality-metrics` | **DEFERRED** | flat collector pool; `parallel()` + `schema` candidate. |
| `code-doctor` | **DEFERRED** | Vue-gated framework audit; lower fan-out `parallel()` + `schema` candidate. |
| `ui-audit` | **DEFERRED** | already spawns per-category Agents (references/main.md §5.2) for >30-page runs; portable `Agent()` path sufficient; revisit post-GA. |
| pure workers / single-spawn | **forbidden** | constraint §1. |

### Escape hatches

| Env var | Default | Effect |
|---|---|---|
| `BLITZ_DISPATCH` | `auto` | `workflow` forces `Workflow` (error if absent); `agent` forces legacy `Agent()` path |

### Open risks (gate further adoption)

- **Portability** — `Workflow` preview + Enterprise-disabled. Never remove the `Agent()` fallback while preview. If runtime capability-detection proves unreliable, defer.
- **API churn** — preview hook signatures may shift before GA. Confine all `Workflow` calls behind this doc's gate so a fix is one-skill-shaped.
- **Autonomous loops** — **MITIGATED**: `next --loop` forces `BLITZ_DISPATCH=agent` for dispatched skills (see next/SKILL.md §3.1) so an unattended loop can't stall on a platform `Workflow` per-run confirmation; revisit when that confirmation is verified non-blocking under skill-instructed dispatch.
- **Resume divergence (sprint-dev)** — RESOLVED by treating `STATE.md` as the durable journal (durable-execution "re-derive from external state" pattern; `docs/_research/2026-06-07_cross-session-resume-plus-workflow.md`). Cross-session resume re-derives remaining waves (§1.4 `wave-plan.json`, pure Kahn sort — control flow serialized at plan time, never LLM-re-derived) and dispatches each via `Workflow`. `resumeFromRunId` is in-session-only. The Resume Divergence Gate runs before any resumed dispatch (guards double-execution + semantic rollback). Per-wave dispatch keeps STATE.md/carry-forward/commit at wave boundaries in main-thread Bash; carry-forward re-apply is idempotent (clamp-at-target + latest-wins).

### Cross-references

- Spawn protocol (canonical `Agent()` path): [spawn-protocol.md](#subagent-spawn-protocol)
- Routing constraint: [agent-routing.md](#agent-routing-protocol) §1
- Token budget + model routing: [token-budget.md](#token-budget-protocol)
- Output style (Invariant 5 snippet): [terse-output.md](terse-output.md)
- Worktree isolation contract: [worktree-lifecycle.md](worktree-lifecycle.md)
- Research provenance: `docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md`; `docs/_research/2026-06-06_dynamic-workflows-claude-code.md` (§5 adoption-table expansion: sprint-plan, codebase-map, sprint-review wired)


---

<!-- ===== Absorbed from token-budget.md ===== -->

## Token Budget Protocol

Authoritative cost-control protocol for blitz multi-agent workflows. Multi-agent ≈15× chat-token baseline; this protocol drives that down 50–70% via model routing, prompt caching, structured replies, and lazy loading. Every skill that spawns subagents MUST follow this protocol.

**Why this doc exists**: research/2026-05-01_autonomous-blitz-quality-efficiency.md identified concrete savings; this codifies them. Before editing, read that research doc.

---

### 1. Model Routing Matrix (mandatory)

Every agent definition (`agents/*.md`) and every dynamic spawn (`Agent({model: ...})`) MUST set `model:` explicitly. Default inheritance is forbidden because the orchestrator runs Sonnet/Opus and would otherwise burn premium tokens on mechanical work.

| Role | Model | Rationale |
|---|---|---|
| **Mechanical workers**: test-gen, lint-fix, file ops, doc-gen, formatting | `claude-haiku-4-5` | 5× cheaper than Opus; adequate for pattern-following work |
| **Standard workers**: backend-dev, frontend-dev, reviewer, refactorer, browser-agent | `claude-sonnet-4-6` | 40% cheaper than Opus; sufficient for impl + review |
| **Heavy reasoning**: architect, security audit, audit, research orchestrator | `claude-opus-4-8` | Reserve for genuinely hard multi-step decisions |
| **Subagent router** (`agents/orchestrator.md` — can't spawn subagents) | `claude-sonnet-4-6` | sonnet by design; routing not synthesis. See its header rationale |
| **Slash-invoked super-orchestrators** (sprint-dev / sprint-plan / sprint-review / next) | `claude-opus-4-8` | top-level skills; `model: opus` required for `[1m]`-inheritance safety. Heavy reasoning delegated to spawned sonnet workers |
| **Plan-check / critic** | `claude-sonnet-4-6` | Adversarial review needs reasoning, not depth |

Model IDs (2026-05-28): `claude-haiku-4-5` (alias of `claude-haiku-4-5-20251001`), `claude-sonnet-4-6`, `claude-opus-4-8`. Skill frontmatter MAY use the short `haiku`/`sonnet`/`opus` aliases; dynamic `Agent({model})` spawns SHOULD use the full IDs above.

**Target distribution**: ≈60% Haiku / 35% Sonnet / 5% Opus by output tokens. Re-affirmed for Opus 4.8 — orchestration stays Sonnet (routing, not synthesis); Opus floor stays ≤5% even though 4.8 fast mode is cheaper (fast mode is NOT cost-justified for routing — see §1.1).

#### 1.1 Opus 4.8 fast mode + effort routing

| Lane | Cost (per MTok) | When |
|---|---|---|
| Sonnet 4.6 (workhorse) | $3 in / $15 out | standard workers, orchestration |
| Opus 4.8 standard | premium | heavy reasoning / synthesis |
| Opus 4.8 **fast mode** | ~$10 in / $50 out, 2.5× tok/s (`speed:"fast"`, research preview, Claude-API only) | **latency-critical only** (e.g. wave-dispatch); NOT a default. 3× cheaper than prior Opus fast ($30/$150) but still > Sonnet — do not auto-switch. |

**Effort split** (governs `effort:` frontmatter, distinct from model):
- Routing orchestrators (`agents/orchestrator.md`, `blitz:next`) → `effort: low` (heavy reasoning lives in spawned workers).
- Multi-wave / multi-phase orchestrators (`sprint-dev`) → `effort: high` — the `effort: low` rule applies to routing-only skills, not multi-phase work. Do not "fix" sprint-dev to low.
- `/effort ultracode` sessions spawn multiple SEQUENTIAL workflows; budget per-workflow, not per-session.

---

### 2. Prompt Caching (cache-friendly prefix structure)

Default cache TTL was silently dropped 60min → 5min in early 2026. For a sprint-dev session that spawns 10 subagents over 30 min, the shorter TTL means every spawn after minute 5 pays full write cost on the shared prefix. The lever the markdown layer controls is *prompt structure*, not the TTL itself.

#### Rule (guidance)

Plugin agents whose system prompt is ≥1024 tokens (Sonnet) / ≥4096 tokens (Opus, Haiku 4.5) should be authored cache-friendly: place the **static prefix FIRST** — role definition, specialist roster, shared protocols, output style — and **dynamic content (sprint context, story args, activity-feed slice) AFTER** it, or the prefix match breaks and you pay full price.

`cache_control` (`{"type": "ephemeral", "ttl": "1h"}`) is an API/SDK request parameter, **not** something settable from a SKILL.md/agent.md system prompt. The platform/SDK applies prompt caching to the stable prefix and owns the 1h ephemeral TTL; the markdown layer's job is only to keep that prefix stable and front-loaded. The break-even table below is informational — it explains why a front-loaded prefix pays off, not a mechanism the markdown layer delivers.

#### Break-even

| TTL | Write cost | Read cost | Reads needed to break even |
|---|---|---|---|
| 5min (default) | 1.25× input | 0.10× input | ~1.3 |
| 1h (opt-in) | 2.00× input | 0.10× input | ~2.2 |

For a 10-spawn sprint-dev: 1h TTL → 1 write + 9 reads = ~2.9× write cost amortized. Default 5min TTL → potentially 10 writes = ~12.5× write cost. **Opt in to 1h.**

#### Verification

After every long session, eyeball the cache hit rate via the Anthropic SDK response (`usage.cache_read_input_tokens / (cache_creation_input_tokens + cache_read_input_tokens)`). Target ≥0.6 once the orchestrator has run a few times.

Source: [dev.to/whoffagents](https://dev.to/whoffagents/claude-prompt-caching-in-2026-the-5-minute-ttl-change-thats-costing-you-money-4363), [platform.claude.com/docs/prompt-caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

---

### 3. Subagent Reply Contract (canonical JSON, ≤50-word summary)

Every `Agent()` prompt MUST instruct the subagent to return ONLY the canonical JSON shown below. Prose replies are forbidden — they bloat orchestrator context by 430–1,930 tokens per return × N agents = 8–38 K tokens/sprint of pure waste.

#### Canonical schema

```json
{
  "status": "complete|partial|failed",
  "summary": "<one sentence, ≤50 words, ≤400 chars>",
  "files_changed": ["path/relative/to/repo"],
  "issues": [
    {"severity": "blocker|major|minor", "where": "path:line", "what": "≤30 words"}
  ],
  "next_blocked_by": ["e.g. needs-typecheck", "needs-user-input"],
  "metrics": {
    "test_count_delta": 0,
    "type_errors_delta": 0,
    "lines_changed": 0
  }
}
```

`metrics` keys are optional but encouraged for any agent that touches code (sprint-review aggregates these directly without re-grepping).

#### Exception: sprint-dev streaming prefixes (`DONE:`/`BLOCKED:`)

`sprint-dev`'s coordinated dev agents (backend-dev, frontend-dev, test-writer) are a documented exception to the JSON-only reply: during a multi-story wave they stream single prefixed status lines (`DONE:`/`BLOCKED:`/`DEVIATION:`/`ESCALATE:`/`HEARTBEAT:`) to the orchestrator's progress file for live monitoring (see [spawn-protocol.md](#subagent-spawn-protocol) §Communication Prefix Table). These are event-stream lines parsed by the Monitor tool, not final-reply bloat. The canonical JSON reply contract above still governs one-shot `Agent()` returns (reviewers, critics, researchers).

#### Embedding in spawn prompts

Every Agent() prompt MUST include this snippet near the end:

> Return ONLY this JSON, nothing else. No markdown fence, no preamble, no postamble. The orchestrator parses your reply with `jq`; any deviation breaks the run.

Skills that need richer output (research docs, audit findings, generated code) MUST write that to a file and reference its path in `files_changed[]`. Never inline file contents into the JSON.

#### Validator (orchestrator-side)

```bash
parse_reply() {
  local raw="$1"
  echo "$raw" | jq -e '.status,.summary' >/dev/null 2>&1 || {
    echo "BAD_REPLY: agent returned non-conforming output" >&2
    return 1
  }
  local len=$(echo "$raw" | jq -r '.summary | length')
  (( len > 400 )) && echo "WARN: summary $len chars > 400 budget" >&2
  return 0
}
```

A reply that fails the schema check is treated as MALFORMED per spawn-protocol §8.

---

### 4. Lazy Skill Loading (do not preload all 37)

The orchestrator agent MUST NOT inject all 37 skill descriptions at startup. Skill bodies load only on slash-invocation; for orchestrator routing, expose ONLY the wave-relevant skill names + descriptions.

**Pattern** (orchestrator agent body):

```
At session start, run:
  ls skills/ | head -40

When the user describes a goal, grep skill descriptions:
  grep -h '^description:' skills/*/SKILL.md | head -50

Spawn at most one specialist agent per turn. Do not preemptively pull skill bodies.
```

Don't load 25K tokens of skill content for every session — load 0 tokens until needed.

---

### 5. Deferred MCP Tool Loading

Default behavior in Claude Code: MCP tool **definitions** are deferred (only names in context). Tool **schemas** load on first call.

Skills MUST NOT eagerly enable all plugin MCP servers. Each active server pays ~18K tokens/turn baseline ([code.claude.com/docs/costs](https://code.claude.com/docs/en/costs)). One published workflow cut MCP overhead 51K→8.5K tokens (83% reduction) by lazy-loading via ToolSearch.

**Rule**: any skill that uses MCP tools MUST cite the tools by name in its `allowed-tools:` frontmatter or rely on `ToolSearch` for on-demand schema fetch. Bulk-enable is forbidden.

**Containment (TB-4).** An MCP tool **description** is untrusted external content read at load — the OWASP MCP *tool-poisoning* surface (instructions hidden in metadata "the model reads; the user does not"). On loading an MCP tool's schema via ToolSearch, run the content-inspection pre-pass (`agents/research-critic.md` §2.1.5 / `sec-content-inspection`) on its description, and **hash the description on first approval** so a later silent change (rug-pull) is flagged rather than trusted. Tool *returns* are inspected the same way before entering reasoning context. Canonical posture: [threat-model.md](security.md) §3 TB-4.

---

### 6. PostToolUse Output Replacement

Claude Code v2.1.121+ allows PostToolUse hooks to replace tool output via `hookSpecificOutput.updatedToolOutput`. Use this to summarize verbose outputs (test runs, build logs, large file reads) before they enter orchestrator context.

Pattern: any spawn site that runs `npm test` or `npm run build` and pipes to the orchestrator MUST route through a summarizing hook. Raw 10K-line test output → 100-line digest. Saves tens of thousands of tokens per spawn.

---

### 7. CLAUDE.md and Memory Hygiene

CLAUDE.md is loaded into every session — keep ≤200 lines. Workflow-specific instructions belong in `skills/*/SKILL.md` (lazy-loaded), not CLAUDE.md.

User memory at `~/.claude/projects/-home-tom-development-blitz/memory/MEMORY.md` is also loaded every session (truncated at 200 lines). Each entry should be one line, ≤150 chars.

---

### 8. Subagents vs Agent Teams (use subagents)

| Mode | Token overhead vs single chat | Use case |
|---|---|---|
| Subagents (current blitz) | 200–500% | Result-only return; orchestrator-worker pattern |
| Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | ~700% (plan mode) | Peer-to-peer debate, competing hypotheses |

For blitz Hybrid Pattern A's 20 specialist workers: **use subagents**. Reserve Agent Teams for genuinely peer-to-peer debugging where multiple hypotheses must run concurrently.

---

### 9. Anti-Patterns (banned)

| Anti-pattern | Token cost | Fix |
|---|---|---|
| Subagent Reads whole file instead of line range | 500–5K extra tokens | Use `offset`+`limit` on Read |
| Subagent pastes raw tool output verbatim into reply | Multiplies per agent | PostToolUse summarizer; reply contract caps |
| Subagent re-states task prompt in reply | ~200 tokens | Reply contract omits preamble |
| Verbose progress prose ("I am now analyzing…") | 50–300 tokens/step | terse-output protocol |
| Orchestrator accumulates raw subagent returns | Compounds across N | Reply contract `summary` only |
| Bulk-enable all MCP servers | 18K tokens/turn/server | ToolSearch lazy load |
| Preload all 37 skill bodies | 25K+ tokens | Lazy skill discovery |
| Default-inheritance Opus on Haiku-class work | 5× per token | Explicit `model:` in every spawn |

---

### 10. Per-Skill Budget Caps (advisory)

Skills SHOULD declare a token budget in frontmatter (informational; not enforced yet):

```yaml
---
token-budget:
  orchestrator-input: 50000   # parent context bytes consumed
  per-spawn-output: 800       # bytes returned to parent
  total-spawns: 20
---
```

When a skill exceeds its budget at runtime, log to activity-feed `event: budget_exceeded` and continue (advisory). A future hook may enforce hard caps.

---

### Related

- `skills/_shared/agent-orchestration.md` §8 — output contract / classification
- `skills/_shared/terse-output.md` — output style enforcement
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` — research basis
