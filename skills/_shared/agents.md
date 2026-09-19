# Agents — roster, spawn contract, execution policy

Canonical protocol for every `Agent()` spawn and `Workflow` dispatch in blitz. Skills that spawn agents follow this file; agent definitions in `agents/*.md` implement it. Siblings: [loop.md](/_shared/loop.md) (tasks.json, `next`, gate), [sessions.md](/_shared/sessions.md) (session records, messaging, feed), [quality.md](/_shared/quality.md) (checks, ratchet, structural done), [security.md](/_shared/security.md) (trust boundaries TB-1…TB-5), [output.md](/_shared/output.md) (OUTPUT STYLE line, feed schema).

Platform facts cite code.claude.com at Claude Code 2.1.277 (Sept 2026).

---


> **Reference:** [agents.reference.md](agents.reference.md) carries the rest of this protocol: The 11-item spawn spec, prompt boilerplate, the reply contract and status enum, `--parallel` preconditions and wave execution, worktree platform facts, the Workflow dispatch contract, the fix loop, deviations, and anti-patterns. Load it when you need one of those; this file is the contract every consumer obeys.

## 1. Roster and model routing

### 1.1 Blitz plugin agents

| Agent | Model | Tools | Purpose | Notes |
|---|---|---|---|---|
| `blitz:dev` | sonnet; opus on fix rounds 4–5 | Read, Write, Edit, Bash, Glob, Grep, ToolSearch | Implements one task from `tasks.json` | Role passed in the prompt as `ROLE: backend\|frontend\|infra\|test`, with `skills/build/references/<role>.md` inlined below it. `experimental.cacheTtl: 1h`. |
| `blitz:test-writer` | sonnet | Read, Write, Edit, Bash, Glob, Grep | Writes or fixes tests for one task | Verification-first oracle (§3.6); `ESCALATE: oracle-underivable` maps to `blocked_reason`. Anti-mock guidance from [quality.md](/_shared/quality.md). `experimental.cacheTtl: 1h`. |
| `blitz:critic` | `--mode reject`: opus; `--mode survey`: sonnet | Read, Grep, Glob, Bash (read subset) | Fresh-context evaluator | No Write/Edit. `omitClaudeMd: true`, `memory: project`. Runs `tasks[].verify[]` through `scripts/tasks.sh verify`. Reject must emit `LGTM` before `check` reports PASS. Prompted to flag only correctness and requirement gaps; style findings are parked. |
| `blitz:research-critic` | sonnet | Read, Grep, Glob, Bash, WebFetch | Refutes research claims against sources | The only blitz agent with WebFetch. Every reply is `source_trust: untrusted`. |
| `blitz:design-critic` | sonnet | Read, Grep, Glob, Bash, Playwright MCP | Evaluates rendered UI against `design-criteria.md` | Browser via Playwright MCP only; no source edits. |

Consumer-project `CLAUDE.md` loads for `dev` and `test-writer` (they must follow project conventions) and is omitted for every critic (the reviewed project must not steer the verdict). Plugin agents ignore `permissionMode`, `hooks`, and `mcpServers` frontmatter; a user who needs those fields copies the agent file to `~/.claude/agents/`.

### 1.2 Built-in subagent types

| Type | Tools | Model | Use for |
|---|---|---|---|
| `Explore` | Read, Grep, Glob, read-only Bash | haiku | Codebase search whose result is returned as text |
| `Plan` | Read, Grep, Glob, read-only Bash | inherits | Plan-mode pre-flight research |
| `general-purpose` | all | inherits | Read + write work that fits no blitz role (research notes, doc drafts) |

`statusline-setup` and `claude-code-guide` are harness-invoked; never select them from a skill.

### 1.3 Model routing matrix

Every `agents/*.md` and every dynamic `Agent({model})` sets `model:` explicitly. Inheritance is forbidden: it propagates the parent's `[1m]` context flag, and a sonnet agent invoked from an opus `[1m]` parent fails at load. Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env > per-invocation `model` > agent frontmatter `model:` > main-conversation model.

| Work | Model | Why |
|---|---|---|
| Triage, classification, one-line summaries, `next` row selection | haiku | Pattern-following; cheapest lane |
| Deterministic check-lane collection (`det-*`, `check:*`) | haiku | Running a registry row's `detection.command` and reporting `{id, exit_code, stderr_head}` is bookkeeping, not judgement. Keep the semantic lane and the verdict on the session model. |
| Build (`dev`), test-writer, `critic --mode survey`, research-critic, design-critic | sonnet | Sufficient for implementation and survey-grade review |
| `critic --mode reject`, fix rounds 4–5 | opus | Adversarial verdict and stuck-loop recovery need depth |
| Main thread running `build` / `check` / `next --loop` | operator's choice (`claude --model opus --effort high` recommended) | Heavy reasoning is delegated; the main thread routes |

Cost controls that apply to every spawn:

- `subagentPromptCacheTtl: 1h` in project settings; `experimental.cacheTtl: 1h` on every blitz agent (≥2.1.248; the platform ignores `1h` while a subscription is on usage credits). The critics need it most: each re-spawns once per fix round, and the 5-minute subagent default guarantees a cold prefix from round 2 on.
- The invariant half of the `dev`/`test-writer` spawn spec (never-edit list, reply contract, commit format, output style, stop conditions, mock policy) is injected by `hooks/scripts/subagent-context.sh` through `SubagentStart.additionalContext`, not pasted into the prompt. It is byte-identical per spawn and the platform leaves the subagent's cache intact when it re-injects after auto-compaction. Anything that varies per call stays in the prompt: [spawn-invariant.md](spawn-invariant.md).
- Agent bodies ≥1024 tokens are static-prefix-first (role, protocol, output style) with dynamic content (task, files, feed slice) last, so the cached prefix survives across tasks.
- Lazy tool loading: `ToolSearch` on demand, never bulk-enable MCP servers in an agent.
- Effort: routing skills run `effort: low`; multi-phase orchestrators (`build --parallel`) keep the session effort.

### 1.4 What subagents never receive

Subagents never get `AskUserQuestion`, `Workflow`, `ScheduleWakeup`, `TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet`, or `TodoWrite`. `agent-frontmatter-validate.sh` rejects an agent file that lists any of them. Subagents cannot spawn subagents; every fan-out originates on the main thread. Subagents do not inherit skills; an agent that needs one on every run lists it in `skills:` frontmatter (cost: the full body per spawn — `test-writer` ← `test-gen` is the only default).

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
4. Multi-agent is the exception. The platform docs put agent teams at roughly 7× the tokens of a single session when teammates run in plan mode, and recommend a single session or subagents for sequential work, same-file edits, or many dependencies. Sequential single-agent with fresh context is the default (§5).

---
