# Agents — roster, spawn contract, execution policy

Canonical protocol for every `Agent()` spawn and `Workflow` dispatch in blitz. Skills that spawn agents follow this file; agent definitions in `agents/*.md` implement it. Siblings: [loop.md](/_shared/loop.md) (tasks.json, `next`, gate), [sessions.md](/_shared/sessions.md) (session records, messaging, feed), [quality.md](/_shared/quality.md) (checks, ratchet, structural done), [security.md](/_shared/security.md) (trust boundaries TB-1…TB-5), [output.md](/_shared/output.md) (OUTPUT STYLE line, feed schema).

Platform facts cite code.claude.com and the Claude Code changelog at 2.1.296 (Oct 2026).

---


> **Reference:** [agents.reference.md](agents.reference.md) carries the rest of this protocol: The 11-item spawn spec, prompt boilerplate, the reply contract and status enum, `--parallel` preconditions and wave execution, worktree platform facts, the Workflow dispatch contract, the fix loop, deviations, and anti-patterns. Load it when you need one of those; this file is the contract every consumer obeys.

## 1. Roster and model routing

### 1.1 Blitz plugin agents

| Agent | Model · effort | Tools | Purpose | Notes |
|---|---|---|---|---|
| `blitz:dev` | sonnet · medium; opus · high on fix rounds 4–5 | Read, Write, Edit, Bash, Glob, Grep, ToolSearch | Implements one task from `tasks.json` | Role passed in the prompt as `ROLE: backend\|frontend\|infra\|test`, with `skills/build/references/<role>.md` inlined below it. `experimental.cacheTtl: 1h`. |
| `blitz:test-writer` | sonnet · medium | Read, Write, Edit, Bash, Glob, Grep | Writes or fixes tests for one task | Verification-first oracle ([agents.reference.md](agents.reference.md) §3.6); `ESCALATE: oracle-underivable` maps to `blocked_reason`. Anti-mock guidance from [quality.md](/_shared/quality.md). `experimental.cacheTtl: 1h`. |
| `blitz:critic` | `--mode reject`: opus · high (medium on small green diffs); `--mode survey`: sonnet · medium | Read, Grep, Glob, Bash (read subset) | Fresh-context evaluator | No Write/Edit. `omitClaudeMd: true`, `memory: project`. Runs `tasks[].verify[]` through `scripts/tasks.sh verify`. Reject must emit `LGTM` before `check` reports PASS. Prompted to flag only correctness and requirement gaps; style findings are parked. |
| `blitz:research-critic` | sonnet · medium | Read, Grep, Glob, Bash, WebFetch | Refutes research claims against sources | The only blitz agent with WebFetch. Every reply is `source_trust: untrusted`. |
| `blitz:design-critic` | sonnet · medium | Read, Grep, Glob, Bash, Playwright MCP | Evaluates rendered UI against `design-criteria.md` | Browser via Playwright MCP only; no source edits. |

Consumer-project `CLAUDE.md` loads for `dev` and `test-writer` (they must follow project conventions) and is omitted for every critic (the reviewed project must not steer the verdict). Plugin agents ignore `permissionMode`, `hooks`, and `mcpServers` frontmatter; a user who needs those fields copies the agent file to `~/.claude/agents/`.

### 1.2 Built-in subagent types

| Type | Tools | Model | Use for |
|---|---|---|---|
| `Explore` | Read, Grep, Glob, read-only Bash | haiku | Codebase search whose result is returned as text |
| `Plan` | Read, Grep, Glob, read-only Bash | inherits | Plan-mode pre-flight research |
| `general-purpose` | all | inherits | Read + write work that fits no blitz role (research notes, doc drafts) |

`statusline-setup` and `claude-code-guide` are harness-invoked; never select them from a skill.

### 1.3 Model routing matrix

Every `agents/*.md` and every dynamic `Agent({model})` sets `model:` explicitly, so routing and cost stay deterministic whatever the main thread runs. Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env > per-invocation `model` > agent frontmatter `model:` > main-conversation model. Workflow agents read `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` first (≥2.1.296); blitz never sets it, and an operator who does overrides every per-agent choice below.

Family aliases resolve to the newest model in the family:

| Alias | Resolves to | Context | $/Mtok in · out · cache read | Since |
|---|---|---|---|---|
| `haiku` | Claude Haiku 5.5 (`claude-haiku-5-5`) | 1M | 0.10 · 0.50 · — (prompts over 100K: 0.50 · 2.50) | 2.1.293 |
| `sonnet` | Claude Sonnet 5.5 (`claude-sonnet-5-5`) | 1M | 2 · 10 · 0.10 | 2.1.284; cache-read price cut in 2.1.296 |
| `opus` | Claude Opus 5.5 (`claude-opus-5-5`) | 1M | 4 · 20 · 0.20 | 2.1.280 |

Sonnet 5.5 is half the price of Opus 5.5 on input and output and half again on cache reads. That is why every implementation and survey lane is sonnet, and opus is kept for the one call whose cost of being wrong is a shipped defect. All three default to a 1M window, so the old `[1m]`-inheritance load failure no longer bites on the 5.5 family; the explicit `model:` rule stays because inheritance would put every spawn on the operator's (usually opus) model and at the operator's effort.

| Work | Model | Effort | Why |
|---|---|---|---|
| Triage, classification, one-line summaries, `next` row selection | haiku | low | Single-shot pattern-following; cheapest lane |
| Deterministic check-lane collection (`det-*`, `check:*`) | haiku | low | Running a registry row's `detection.command` and reporting `{id, exit_code, stderr_head}` is bookkeeping, not judgement. Keep the semantic lane and the verdict on the session model. |
| Retrieval research (`library-docs`, `web-researcher`, `infra-analyst`), gap-fill | haiku | medium | Multi-step search. Anthropic documents Haiku 5.5 at `low` skipping searches and stopping early in long agent prompts; `medium` roughly halves early stopping. Put today's date in the prompt and keep it under 100K tokens (the price steps up 5×). |
| Build (`dev`), test-writer, `critic --mode survey`, research-critic, design-critic, `codebase-analyst` | sonnet | medium | Sufficient for implementation and survey-grade review |
| `critic --mode reject`, fix rounds 4–5 | opus | high; reject critic `medium` on a diff ≤200 lines with every deterministic gate green and no risky path (`check` references §Critic effort) | Adversarial verdict and stuck-loop recovery need depth. Escalate a stuck Sonnet to Opus rather than raising Sonnet to `xhigh`/`max`: Sonnet 5.5 at max used ~60% more output tokens than Opus 5.5 and cost more per task |
| Main thread running `build` / `check` / `next --loop` | operator's choice (`claude --model opus --effort high` recommended; `--model sonnet` for cost-bound loops) | — | Heavy reasoning is delegated; the main thread routes |

Effort is set per spawn: agent frontmatter `effort:`, the Agent tool's `effort` parameter (≥2.1.292), or `agent(..., {effort})` in a Workflow script. A spawn that omits it inherits the session effort, so an `--effort high` main thread would run every haiku collector at high. Fix rounds 4–5 pass `model: "opus", effort: "high"` together.

Cost controls that apply to every spawn:

- `subagentPromptCacheTtl: 1h` in project settings; `experimental.cacheTtl: 1h` on every blitz agent (≥2.1.248; the platform ignores `1h` while a subscription is on usage credits). The critics need it most: each re-spawns once per fix round, and the 5-minute subagent default guarantees a cold prefix from round 2 on.
- The invariant half of the `dev`/`test-writer` spawn spec (never-edit list, reply contract, commit format, output style, stop conditions, mock policy) is injected by `hooks/scripts/subagent-context.sh` through `SubagentStart.additionalContext`, not pasted into the prompt. It is byte-identical per spawn and the platform leaves the subagent's cache intact when it re-injects after auto-compaction. Anything that varies per call stays in the prompt: [spawn-invariant.md](spawn-invariant.md).
- Agent bodies ≥1024 tokens are static-prefix-first (role, protocol, output style) with dynamic content (task, files, feed slice) last, so the cached prefix survives across tasks.
- Lazy tool loading: `ToolSearch` on demand, never bulk-enable MCP servers in an agent.
- Effort: routing skills run `effort: low`; multi-phase orchestrators (`build --parallel`) keep the session effort; every spawn names its own (table above).
- `autoCompactWindow` (agent frontmatter, ≥2.1.296) lets a subagent compact earlier than the main thread. Blitz agents leave it unset: their budgets (§3.3 of the reference) keep them far below 1M, and an early compaction only buys a cache rewrite mid-task.
- `skills:` preload is capped at 32 per subagent (≥2.1.295); blitz preloads one.

### 1.4 What subagents never receive

Subagents never get `AskUserQuestion`, `Workflow`, `ScheduleWakeup`, the Task tools, or `TodoWrite`; `agent-frontmatter-validate.sh` rejects an agent file that lists one. The platform lets subagents spawn subagents up to three layers below the main conversation; blitz does not: no blitz agent lists `Agent`, so every fan-out originates on the main thread, which owns state and the §4.4 gate. An operator who wants the platform to enforce that for every agent sets `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`. Subagents do not inherit skills; one needed on every run goes in `skills:` frontmatter ([agents.reference.md](agents.reference.md) §3).

### 1.5 Visibility: background agents, workflows, teams

Blitz fan-outs run where the operator can watch them in Claude Code's own views instead of in blitz-specific polling. Every multi-agent dispatch follows this:

| Surface | What the operator sees | What blitz does to feed it |
|---|---|---|
| `/tasks`, VS Code agent map, agents view (`claude agents`) | One row per background agent: status icon, label, live token count, transcript on Enter | Every spawn passes a `description` of the form `<skill> <unit>` (`research web-researcher`, `build T-004`, `audit security`), ≤5 words, unique within the fan-out. With agent teams on, also `name: <skill>-<unit>` (lowercase, hyphens) so the row is addressable. |
| Background agents | Spawns return immediately and notify on completion; the main thread is free to talk | Fan-outs set `run_in_background: true` (the interactive default since 2.1.232; stated so `-p` and SDK runs behave the same). The main thread waits on completion notifications, then applies the §4.4 gate. It never sleeps or polls output files in a loop. |
| `/workflows` and the background workflow row (≥2.1.281) | Run name, progress bar, phase boxes, agent count, elapsed time, tokens | Workflow scripts name every `phase()` in `meta.phases`, give each `agent()` a `label` matching the Agent-path `description` unit, and `log()` one line per dropped or failed agent. |
| Monitor rows (≥2.1.284) | What each event printed | `build --parallel` greps the wave log for `DONE`/`BLOCKED`/`NEEDS_CONTEXT` lines that start with the task id, so each row reads `T-004 DONE`. |
| Phase one-liner | One status line per boundary in the transcript and the agents-view preview | Orchestrators print `<skill> <phase> N/M · k/n done` at each boundary (`build wave 2/3 · 3/4 done`). |

**Names are for resume and visibility, not teams.** `SendMessage(to: "<name>")` resumes a completed named subagent in the background with its context intact, and it does not need agent teams. `build` names every `dev` `dev-<ID>` so fix rounds 1–3 and `NEEDS_CONTEXT` answers go back to the same agent.

**Agent teams (opt-in, and a trap for named spawns).** With `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` an `Agent()` call that passes `name` launches a *teammate* instead of a subagent, unless it is a fork or passes `isolation`. A teammate does not get the agent definition's `skills` preload and an in-process teammate cannot be resumed. So:

- `build --parallel` passes `isolation: "worktree"` with `name`, which keeps every wave `dev` a subagent whether or not teams are on.
- Every other named spawn (sequential `build`, fix rounds) checks the flag: when it is `1`, omit `name` and address the agent by the agent id the `Agent()` result returns. `session-start.sh` prints a one-line notice when the flag is set.
- `research`, `audit`, `check` and `doc-gen` do not pass `name`; their `description` label carries the row.

Teams stay off by default and blitz never turns them on: the platform puts a team at about 7× the tokens of one session in plan mode and recommends subagents for sequential, dependency-heavy work like a task DAG (§2 rule 4).

---

## 2. When to spawn

| Situation | Do this | Not this |
|---|---|---|
| Diff describable in one sentence, ≤5 files | Inline on the main thread (`build` inline path) | Spawning `dev` for a one-liner |
| One open task with `files[]` and `verify[]` | One `dev` with fresh context, sequential | Batching several tasks into one agent |
| ≥3 open tasks, pairwise-disjoint `files[]`, `worktree.baseRef: head` | `build --parallel` → `build-wave.js` or `Agent()` fan-out, cap 4 | Parallel dispatch on overlapping files |
| Independent read-only surveys (audit pillars, review lenses, research refuters) | `Workflow` `parallel()` when present, else `Agent()` pool | Sequential single-agent scan of everything |
| Verdict before PASS | `critic --mode reject` (opus), fresh context | Main thread grading its own diff |
| Codebase lookup returned as text | `Explore` | `general-purpose` on haiku-class work |
| Findings that must land in a file | `general-purpose` or a blitz role with Write | `Explore` (cannot Write; fails silently) |

Rules of thumb:

1. The main thread owns state. Only it edits `docs/plans/*/tasks.json` (through `scripts/tasks.sh`) and `progress.md`; dev agents carry both in their never-edit list.
2. If the agent needs Write or Edit, it is `general-purpose` or a blitz role that lists Write. Anything else returns text and the main thread writes the file.
3. Never retry the same prompt after `error_max_turns`; narrow the scope or stop.
4. Multi-agent is the exception; sequential single-agent with fresh context is the default. The evidence, and the `--parallel` preconditions that override it, are in [agents.reference.md](agents.reference.md) §5.

---
