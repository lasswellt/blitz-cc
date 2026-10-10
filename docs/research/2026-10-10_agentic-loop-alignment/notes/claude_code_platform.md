# Claude Code platform changes 2.1.278 → 2.1.296 (Sept–Oct 2026) and current agent-orchestration docs

Scope note: "CL" below means the official CHANGELOG ([raw](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)), cited by version. Docs pages were fetched 2026-10-10 from code.claude.com/docs. Facts from versions before 2.1.278 are marked "(older)". blitz's own floor file (`.claude-plugin/compat.json`, read locally) declares `cc_min 2.1.271` and `docs_verified_against 2.1.296`.

## 1. Agent tool: `effort`, `name`, background default, forks, `autoCompactWindow`, skills preload cap, resume

### Takeaway
In this window the Agent tool gained a per-call `effort` parameter (2.1.292). Subagent definitions gained `autoCompactWindow` (2.1.296). The `skills` preload is now capped at 32 skills (2.1.295). Background-by-default, forks, `name` addressing and SendMessage-resume are older features, but their semantics are now precisely documented. One of them is a trap for blitz: when agent teams are enabled, naming a subagent turns it into a teammate.

### Cited Findings
- **`effort` param (2.1.292)**: "Added an `effort` parameter to the Agent tool, so Claude runs a sub-agent at the effort level you ask for" — [CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md). The docs add: it works only for non-fork subagents, "overrides the `effort` field and stays in effect when the subagent is resumed. The `CLAUDE_CODE_EFFORT_LEVEL` environment variable takes precedence over both" — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **Effort precedence**: frontmatter effort "overrid[es] the session level but not the environment variable"; `maxEffortLevel` and org caps still limit it — [model-config](https://code.claude.com/docs/en/model-config)
- **Per-call `model`** also survives resume and follow-up messages — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **`name`**: "Claude can give a subagent a name by passing a `name` parameter on the Agent tool call, and may do so on its own, without asking you first. The name makes the subagent addressable." — [sub-agents](https://code.claude.com/docs/en/sub-agents). Agent names are capped at 256 characters, and a longer skill or plugin-file `name` is ignored — [CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Name plus agent teams**: "Claude launches a teammate when it calls the Agent tool with a `name` while agent teams are enabled, unless the call is a fork or passes `isolation` on the call itself" — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Background default (older, 2.1.232 per blitz compat)**: "Where fork mode is off, Claude runs the subagent in the background by default and in the foreground when it needs the result before continuing." Where fork mode is on, Claude Code runs every spawned subagent in the background (fork and non-fork) "and removes the Agent tool's `run_in_background` parameter, so Claude can't ask for the foreground." The `background: true` frontmatter keeps an agent in the background even when Claude asks for the foreground — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **Forks**:
  - A fork "inherits the entire conversation so far instead of starting fresh" and receives "the main conversation's exact tool pool" — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - "A fork can't spawn further forks", and a fork reuses the parent's prompt cache — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - Fork mode is on by default in interactive sessions and off in `-p` and the SDK; `CLAUDE_CODE_FORK_SUBAGENT=1/0` overrides this, and an `Agent(fork)` deny rule stops forks — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - Forks keep the parent's plan and `dontAsk` modes ([CL 2.1.285](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Under `-p` with `FORK_SUBAGENT=1`, a subagent's own Agent call runs in the foreground (CL 2.1.285)
- **`isolation: "worktree"`** on a call writes the agent's edits to a separate git worktree. As frontmatter, `isolation: worktree` uses a temp worktree that is "auto-cleaned if no changes" — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - Subagents in their own worktree were shown the parent's git branch and status until the fix in [CL 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - Background subagents lost write access when the main session switched worktrees until the fix in CL 2.1.290
  - Worktree subagents double-loaded CLAUDE.md until the fix in CL 2.1.286
- **`autoCompactWindow` (2.1.296)**: "Added `autoCompactWindow` to subagent frontmatter and `--agents` definitions, so a subagent can auto-compact earlier than the main conversation's window" — [CL 2.1.296](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - The sub-agents page I fetched does not yet document this field; it mentions only `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` applying to subagents — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - The session-level `autoCompactWindow` setting and `/autocompact` (saved per model since 2.1.288) must fall between 100K and 1M tokens, and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` beats everything — [model-config](https://code.claude.com/docs/en/model-config); [CL 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Skills preload cap (2.1.295)**: "Changed subagents to preload at most 32 skills from the `skills` field, each once; a subagent with the Skill tool can still invoke the rest" — [CL 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - The docs say: "up to the first 32 distinct names", the field "controls which skills are preloaded, not which skills the subagent can access", skills with `disable-model-invocation: true` can't be preloaded, and missing skills are skipped with a debug-log warning — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **Resume**: "Claude uses the `SendMessage` tool with the agent's ID or name as the `to` field to resume it. `SendMessage` doesn't require agent teams to be enabled." A completed subagent that gets a message "resumes in the background without a new `Agent` invocation" — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - A subagent you stopped yourself with `x` in `/tasks` doesn't auto-resume, and Explore and Plan are one-shot and can't be resumed — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - Resume fixes in this window:
    - Resumed subagents lost their thinking and prompt cache after a mid-run message ([CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
    - Resumed subagents were told the user rejected a tool call that a shutdown had interrupted (CL 2.1.296)
    - Claude wasn't told it could resume background subagents after a double kill and resume (CL 2.1.295)
    - Cloud sessions now tell Claude which stopped background agents it can resume by id (CL 2.1.292)
- **Nesting and concurrency**: subagents can spawn subagents "up to three layers below the main conversation" (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`; `1` disables nesting). The concurrent limit is `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, default 20 — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **Frontmatter set (current)**:
  - Fields: `name`, `description`, `tools`, `disallowedTools` ("A tool listed in both is removed"), `model` (`sonnet`/`opus`/`haiku`/`fable`/full ID/`inherit`), `effort` (`low`…`max`), `permissionMode`, `maxTurns` (stops the agent, output marked partial, resumable), `skills`, `memory` (auto-enables Read/Write/Edit), `background`, `isolation`, `hooks` (Stop→SubagentStop), `mcpServers`, `color`, `initialPrompt`, `omitClaudeMd` (2.1.271+), `experimental.cacheTtl` — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - **For plugin subagents, `permissionMode`, `hooks`, `mcpServers` and `initialPrompt` are ignored** — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  - `--debug` now names unrecognized frontmatter fields in agent files, with typo hints — [CL 2.1.296](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **`SubagentHandback` (older, 2.1.271)**: on v2.1.271+, a subagent using `SubagentHandback` delivers its report through that tool. SubagentStop's `last_assistant_message` then "holds only the closing text"; the report is in `tool_input.message` — [hooks](https://code.claude.com/docs/en/hooks)
  - In auto mode a subagent's run "now ends as soon as it hands its report back" ([CL 2.1.285](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
- **Other subagent fixes in this window**:
  - Mid-response API timeouts: "subagents now continue from the partial response" ([CL 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Subagent definitions with `permissionMode: auto` no longer enter auto mode when it is unavailable (CL 2.1.292)
  - `CLAUDE_AUTO_BACKGROUND_TASKS` no longer backgrounds a subagent while an edit queued behind it starts early (CL 2.1.295)
  - Foreground subagents no longer miss TaskCreate/Update tools (CL 2.1.286)
- **Task tools are model-gated**: TaskCreate/Get/Update/List and TodoWrite are on by default "only on Claude 3.x models, Opus 4 through 4.7, Sonnet 4 through 4.6, and Haiku 4.5", and a subagent gets them only when the session has them — [tools-reference](https://code.claude.com/docs/en/tools-reference)

### Inferences
- blitz `dev`, `critic` and other agents defined in the plugin cannot rely on frontmatter `hooks`, `permissionMode` or `mcpServers`, because plugin subagents ignore them. Guards must live in plugin `hooks/hooks.json`, with matchers on `agent_type`.
- If a blitz skill names Agent calls (for example "dev-T3") so SendMessage can address them, and the user has `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, those calls launch as teammates. Teammates can't run in the background, ignore `skills`, and stop TaskCompleted gating from behaving the same way. Passing `isolation` on the call avoids this, as does not naming the agent.
- Using `autoCompactWindow` (2.1.296) on long-running `dev` agents keeps their context lean, but the plugin floor would have to rise to 2.1.296 or the field must tolerate older versions. `--debug` will flag it as unknown on older builds.
- With the 32-skill preload cap, an agent that lists blitz shared-protocol skills should stay well under 32. Skills with `disable-model-invocation: true` can't be preloaded at all.
- The Opus 5.5, Sonnet 5.5 and Haiku 5.5 sessions now default for Anthropic API users (2.1.280, 2.1.284, 2.1.293) are not in the list of models that get the Task tools by default. A blitz design that assumes TaskCreate/TaskUpdate exist in `dev` agents may silently degrade on 5.5 models unless `CLAUDE_CODE_ENABLE_TASKS` is opted in. This relates to blitz's `tasks.json`-via-script design, which avoids the dependency anyway.
- A SubagentStop gate that parses `last_assistant_message` misses the report when the subagent uses SubagentHandback. Read `agent_transcript_path`, or match a hook on the `SubagentHandback` tool.

### Gaps
- The exact docs text for `autoCompactWindow` in agent frontmatter (value form, interaction with `/autocompact`) wasn't found on the sub-agents page as fetched; only the changelog line confirms it.
- No full Agent tool input schema is published on the pages fetched. The SDK TypeScript page shows only `AgentDefinition`, which has `effort` but no `autoCompactWindow`.

## 2. Agent teams: status, enabling, teammates, costs, when to use vs subagents

### Takeaway
Agent teams are still **experimental and disabled by default** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). The docs steer users to subagents, cross-session messaging or workflows first. Teams roughly cost per-teammate full sessions (about 7x tokens in plan mode). Changes in this window were mostly fixes for plugin-defined teammates and `agent.spawn` coverage.

### Cited Findings
- **Status and enabling**: "Agent teams are experimental and disabled by default. Enable them by setting `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`." There are known limitations around resume, task coordination and shutdown. Spawning teammates also needs an interactive session: with `-p`/SDK "a subagent that Claude names runs as an ordinary subagent even with agent teams enabled" — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Guidance**: "Before you set up a team, check whether a lighter option does the job." Teams suit research and review, new modules, competing hypotheses and cross-layer work. "For sequential tasks, same-file edits, or work with many dependencies, a single session or subagents are more effective." Start with 3–5 teammates and 5–6 tasks per teammate — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Costs**: "Agent teams use approximately 7x more tokens than standard sessions when teammates run in plan mode." Use Sonnet for teammates, keep teams small, shut teammates down when done — [costs](https://code.claude.com/docs/en/costs)
  - An in-process teammate's cache TTL is 5 min by default; `subagentPromptCacheTtl: "1h"` extends it — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Teammate model order**: spawn prompt, then definition `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the lead's model. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` skips the first two, and a mod's `agent.spawn` hook can set the model — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Subagent definitions as teammates**:
  - `tools`, `model`, `disallowedTools` (in-process) and `effort` (in-process) apply
  - "`skills`: Claude Code doesn't apply the definition's `skills` to a teammate in either display mode"
  - `mcpServers` applies only to split-pane teammates
  - [agent-teams](https://code.claude.com/docs/en/agent-teams)
  - Fix: "a plugin-defined agent spawned by name now runs with its own prompt, tools, disallowedTools and effort instead of the defaults" — [CL 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Limitations**:
  - No resume of in-process teammates
  - Task status can lag
  - One team per session, and no nested teams
  - In-process teammates can't run background subagents: `background: true` definitions error, and `run_in_background` fails or runs in the foreground
  - Permissions are set at spawn, and teammate prompts surface in the lead
  - Plan approvals are auto-granted by the lead
  - [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Hooks for gates**: `TeammateIdle`, `TaskCreated` and `TaskCompleted` (exit 2 blocks) — [agent-teams](https://code.claude.com/docs/en/agent-teams)
  - An in-process teammate's `agent_id` became its agent ID, with `name@team` moved to `teammate_id`, and "TeammateIdle hooks no longer fire from its subagents or forks" — [CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - `TaskCreated` input gained `agent_id` (2.1.290) — [hooks](https://code.claude.com/docs/en/hooks)
- **Other window fixes**:
  - In-process teammates' first SendMessage failed until tool search loaded the tool ([CL 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `--setting-sources` is forwarded to teammates (CL 2.1.281)
  - `agent.spawn` mod hook covers teammates (CL 2.1.289)
- **Messaging trust**: a teammate "can't approve a permission prompt or supply consent on your behalf". In auto mode the classifier reviews each inter-agent message before delivery — [agent-teams](https://code.claude.com/docs/en/agent-teams)

### Inferences
- blitz's design (an orchestrator skill plus fresh `dev` subagents and a JSON DAG) matches the docs' recommendation for dependency-heavy, sequential-ish work. Agent teams add cost and lose `skills` preload. blitz should document that it does not want teams, and could detect `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` at SessionStart and warn, because named subagents silently become teammates.
- blitz's `tasks.json` DAG is a stronger, auditable equivalent of the team task list. Team task-list hooks (`TaskCompleted`) don't apply to it.

### Gaps
- No documented roadmap for agent teams leaving experimental status.

## 3. Workflow tool and plugin workflows

### Takeaway
Plugin workflows (`workflows/*.js`, namespaced `/plugin:name`) are a stable documented component. Changes in this window:
- `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` (2.1.296) can override every workflow agent's model.
- The `agent.spawn` mod hook now covers workflow agents (2.1.292).
- Fixes cover stalls, CRLF scripts, forked skills in workflow agents and deep nesting.

Runtime limits are: 16 concurrent agents by default (max 256 via env), 4,096 items per `parallel()`/`pipeline()`, and 1,000 agents per run. On a subscription, a run pauses at the usage limit (2.1.271+) and does not fail.

### Cited Findings
- **Plugin distribution**: "Place the script in a `workflows/` directory at the plugin root, or point to a different location with the `workflows` manifest field … A plugin called `acme-tools` containing a script whose `meta.name` is `release-audit` runs as `/acme-tools:release-audit`." — [workflows](https://code.claude.com/docs/en/workflows). The manifest `workflows` key "Replaces the default `workflows/` scan" — [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- **Script rules**:
  - `export const meta` must be the first statement and a plain literal with `name` and `description`, otherwise the `/name` command is dropped from autocomplete
  - Script functions: `agent()`, `pipeline()`, `parallel()`, `phase()`, `log()`, `args` global; `meta.phases` titles must match `phase()` titles
  - `Date.now()`, `Math.random()` and no-arg `new Date()` throw, so replay is deterministic
  - `import()` fails, and there is no direct filesystem or shell access
  - [workflows](https://code.claude.com/docs/en/workflows)
- **agent() options documented**:
  - `schema`: JSON output, validated, with the schema contradiction pre-check and 5 attempts (`MAX_STRUCTURED_OUTPUT_RETRIES`)
  - `label`
  - `stallMs`: per-agent stall window; global `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`
  - "A model the script names for a stage counts as the per-invocation model"
  - An `agent()` call resolves to `null` if stopped or on an unrecoverable API error, and `pipeline()` keeps nulls
  - [workflows](https://code.claude.com/docs/en/workflows)
  - Prompt-cache sharing needs agents with the "same model, effort level, agent type, tools, output schema, and working directory", which implies per-agent effort and agent-type options exist — [workflows](https://code.claude.com/docs/en/workflows)
  - The mods type file's `AgentSpec` declares `isolation?: 'worktree' | 'remote'` and `effort?: string | number` — [claude-code.d.ts](https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts)
- **`CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` (2.1.296)**: "run every workflow agent on one model while other subagents keep theirs" — [CL 2.1.296](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md). Separately, `CLAUDE_CODE_SUBAGENT_MODEL` is the default for "workflow agents that aren't assigned a model another way" — [model-config](https://code.claude.com/docs/en/model-config)
  - A blocked model under `availableModels` is substituted, and `/workflows` shows a warning — [workflows](https://code.claude.com/docs/en/workflows)
  - A 2.1.283 fix: workflows started during a model fallback ran every agent on the fallback model — [CL 2.1.283](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Concurrency and limits**:
  - "Up to 16 concurrent agents by default, fewer when Claude Code has fewer CPUs … `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` … 1 to 256 (v2.1.269+)"
  - Fan-out prefix stagger up to 5 s (`CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS`)
  - 4,096 items per call, 1,000 agents total per run
  - [workflows](https://code.claude.com/docs/en/workflows)
- **Usage limits**: "When an agent hits your claude.ai usage limit, the run pauses rather than failing … Requires Claude Code v2.1.271 or later". The pause applies only when:
  - the session is interactive with a claude.ai subscription (not `-p`/SDK, background sessions, Remote Control or teammates)
  - `autoContinueAtUsageLimit` is on
  - the reset is within 24 h
  - the run has waited at most twice
  - [workflows](https://code.claude.com/docs/en/workflows)
- **Resume**: completed agents return saved results. The first agent whose prompt differs, a failed agent, and every agent started after it run again. The same holds after backgrounding; resume works within a session or via `claude --resume` — [workflows](https://code.claude.com/docs/en/workflows)
- **Stalls**: an agent restarts at most 5 times, then the run fails with `agent stalled on all 6 attempts` and similar errors — [workflows](https://code.claude.com/docs/en/workflows)
  - Mac wake-from-sleep restarted workflow subagents from their prompt until the fix in [CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - Connection stalls did the same until the fix in CL 2.1.286
- **Approvals**:
  - Auto mode prompts on first launch only, and manual mode prompts every run unless "don't ask again" is chosen for a named bundled, saved or plugin workflow
  - In `-p`/SDK, a `Workflow` or `Workflow(<name>)` allow rule, auto mode, bypass mode, or a PreToolUse hook allows the launch
  - "In auto mode, the prompt your script passes to `agent()` doesn't count as a request from you"
  - [workflows](https://code.claude.com/docs/en/workflows)
- **UI**: in `/workflows`, `p` pauses, `x` stops, `r` restarts an agent, `s` saves, and `f` filters. The background row shows name, progress, agent count, tokens and a large-workflow warning above 25 agents or 1.5M projected tokens — [workflows](https://code.claude.com/docs/en/workflows); [CL 2.1.281](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - The size guideline `workflowSizeGuideline` defaults to `medium` (<10 agents), or `small` on Pro, and is advisory — [workflows](https://code.claude.com/docs/en/workflows)
- **Window fixes**:
  - Forked skills invoked from workflow subagents delivered results to the main conversation ([CL 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `scriptPath` refusal now advises an inline `script` (CL 2.1.295)
  - CRLF scripts were refused (CL 2.1.296)
  - Values nested past ~20,000 levels were truncated (CL 2.1.296)
  - An unawaited failed `agent()`/`parallel()`/`pipeline()` could crash a background session (CL 2.1.285)
- **Disable switches**: `disableWorkflows`, `CLAUDE_CODE_DISABLE_WORKFLOWS=1`, and the `/config` toggle remove `/workflows`, workflow commands and ultracode. Code Review and `/ultrareview` still run under user-level `disableWorkflows` (CL 2.1.285) — [workflows](https://code.claude.com/docs/en/workflows)

### Inferences
- blitz's `workflows/build-wave.js`, `review-fanout.js` and `audit-sweep.js` hard-code `model: 'sonnet'` and `'opus'`. Under `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL`, the adversarial `critic` stage (opus/high) may silently run on a cheaper model. Consider surfacing the effective model in the critic's JSON reply, or documenting the env var as a supported cost knob.
- blitz's `build-wave` relies on `isolation: 'worktree'` and `agentType: 'blitz:dev'` in `agent()`. These names are consistent with the `AgentSpec` typings and the docs' "agent type" cache key, but the public workflows page doesn't enumerate them. The authoritative source is the bundled `/workflow-authoring` skill (2.1.248+).
- Usage-limit pause doesn't apply in background sessions or `-p`. A blitz `build` run dispatched via `claude --bg`, or invoked headless, will fail agents at the limit, and blitz's retry/resume logic must handle `null` results.
- A failed mid-wave agent reruns all later-started agents on relaunch. Ordering expensive agents first, or splitting waves into separate workflow runs, limits rework.

### Gaps
- The full documented `agent()` option list (`agentType`, `isolation`, `phase`, `effort`) wasn't retrievable from public pages; the SDK TypeScript page fetched didn't include the Workflow tool schema.
- I found no documented per-plugin control over workflow concurrency.

## 4. Agents view (`claude agents`), `/tasks`, Monitor, background Bash limits, send-now, `--bg`, cloud sessions

### Takeaway
Agent view is still a research preview. `claude agents --json` is the stable scripting interface, and `~/.claude/jobs/` is explicitly not one. In this window, background Bash got a 30-min/2-h time limit (2.1.285), narrowed to unattended sessions only (2.1.288). Monitor watches carry deadlines (5 min default, 30 max, 10 in `-p`) and do not survive backgrounding. Send-now backgrounds running tools and does not cancel.

### Cited Findings
- **`claude agents --json`**: "prints active sessions as a JSON array and exits". Fields:
  - `cwd`, `kind`, `startedAt`
  - `id`, plus `state` (`working|blocked|done|failed|stopped`) for background sessions
  - `pid` and `status` (`busy|waiting|idle`)
  - `waitingFor` (`permission prompt`, `input needed`, `sandbox request`, `worker request`, `dialog open`)
  - `sessionId`, `name`
  - `--all` adds completed sessions and `--cwd` filters
  - "The files under `~/.claude/jobs/<id>/` are not a stable interface."
  - [agent-view](https://code.claude.com/docs/en/agent-view)
- **`--bg` and management**: `claude --bg [--name] "<prompt>"`, `claude --bg --exec 'pytest -x'` (no model), plus `claude attach|logs|stop|respawn|rm`. `--bg` with `-p` is rejected — [agent-view](https://code.claude.com/docs/en/agent-view)
  - `claude attach <name>` and `logs <name>` accept part of a name ([CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `n:<text>` filter (CL 2.1.287) and Ctrl+F search (CL 2.1.288)
  - Replies from `claude agents` arrive as queued messages (CL 2.1.287)
  - `/model`, `/effort` and `/rename` sent to a busy session apply right away (CL 2.1.290)
  - Agent view stopped with its service now stops running sessions in about a minute (CL 2.1.295)
- **Worktree isolation for dispatched sessions**: before editing, Claude moves the session into `.claude/worktrees/`. This is skipped for sessions backgrounded with `←` or `/bg`, sessions already in a linked worktree, and non-git directories without a `WorktreeCreate` hook. Disable with `worktree.bgIsolation: "none"` — [agent-view](https://code.claude.com/docs/en/agent-view)
- **What carries over when backgrounding**: "running background shell commands, backgrounded subagents, dynamic workflows, scheduled tasks you created with `/loop`…". But "Claude Code stops work that can't carry over, such as a running monitor, and stops a backgrounded subagent that owns a monitor along with it." — [agent-view](https://code.claude.com/docs/en/agent-view)
- **Background command time limit**: "In a session that runs unattended, such as a run with the `-p` flag, an Agent SDK application, a CI job, or a cloud session, background Bash and PowerShell commands have a time limit … 30 minutes, or the `timeout` Claude passes with `run_in_background`, up to a maximum of 2 hours". It was introduced in 2.1.285 and, "Before v2.1.288, it applied in every session" — [tools-reference](https://code.claude.com/docs/en/tools-reference); [CL 2.1.285, 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - `claude -p` and the SDK now wait for background commands and scheduled wakeups after the final result (CL 2.1.292)
- **Monitor**:
  - "Every watch Claude starts has a deadline: 5 minutes by default, at most 30 minutes, and at most 10 minutes in a non-interactive run"
  - Uses Bash permission rules
  - Stopping a subagent stops its monitors
  - Plugins can declare `experimental.monitors` (`when: "always"` or `"on-skill-invoke:<skill>"`, interactive only, not on Bedrock/Vertex/Foundry)
  - [tools-reference](https://code.claude.com/docs/en/tools-reference); [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
  - Sandboxed Monitor commands now follow permission rules ([CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Monitor event rows show printed output (CL 2.1.284)
- **`/tasks`**: background work Claude Code runs for itself is folded under one "System tasks" row ([CL 2.1.285](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)). Rows show a status icon with paging and mouse support (CL 2.1.283)
  - `TaskStop` also stops teammates and named background agents by ID or name — [tools-reference](https://code.claude.com/docs/en/tools-reference)
- **Send-now**:
  - "Changed send now (ctrl+enter or ctrl+x ctrl+s) to move running tools to the background instead of cancelling the turn" ([CL 2.1.281](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - In a subagent's view it backgrounds the subagent's running command (CL 2.1.286)
  - It backgrounds a skill's own shell command (CL 2.1.286)
  - Desktop send-now no longer ends a waiting subagent (CL 2.1.292)
- **Cross-session messaging** (older, 2.1.224+):
  - `ListAgents` and `SendMessage` reach local sessions over a per-session socket and cloud or other-machine sessions via Remote Control
  - Inbound messages are treated as peer data ("can't approve anything", "can't change configuration")
  - `crossSessionInbound` takes `accept|hold|refuse`
  - `SendMessage`'s `notify_when_idle` sends one notice (2.1.236+)
  - Limits: about 1M-char messages and 50 queued messages
  - [cross-session-messaging](https://code.claude.com/docs/en/cross-session-messaging)
- **Background-agent idle notification bug**: issue [#93672](https://github.com/anthropics/claude-code/issues/93672) (opened 2026-09-11 on 2.1.268) reported that `idle_prompt` fires while background subagents run. It was marked fixed in 2.1.288 ([CL 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)), but a commenter reported it still reproduced on 2.1.288 (one run). The workaround is to gate on the Stop payload's `background_tasks[].status`.
- **Cloud sessions**: fixes in this window include restarted cloud sessions telling Claude which background agents are resumable (CL 2.1.292) and the `/loop` wakeup-loss fix (CL 2.1.290), which was **reverted** in 2.1.294 ("the session stays asleep") — [CL 2.1.290, 2.1.292, 2.1.294](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)

### Inferences
- A blitz Monitor-based watcher (for example, tailing test output during `build`) must be restartable: it dies on `←`/`/bg`, and its deadline caps at 30 min. For long waves, a background Bash command with an explicit `timeout`, or plugin `experimental.monitors` with `on-skill-invoke`, is more durable.
- Headless or CI blitz runs face the 30-min default background-command cap, so long test suites need an explicit `timeout` (≤2 h).
- blitz should poll with `claude agents --json [--all] --cwd`, not read `~/.claude/jobs/`.

### Gaps
- I found no documented per-session concurrency cap for background sessions beyond rate-limit guidance ("ten agents in parallel uses quota roughly ten times as fast").

## 5. Claude Mods (2.1.287)

### Takeaway
Mods arrived in 2.1.287 ("plugins may now modify deeper behavior"). A mod is a plugin whose `hooks/hooks.json` names a JS/TS hooks module (`modules: [...]`) that registers in-process middleware handlers. Unlike settings hooks, a mod can:
- draw panes, bands and a status line
- rewrite or answer tool calls
- set a subagent's or workflow agent's model, or deny it, via `agent.spawn`
- call models with `$.model.complete`

Mods are unsandboxed and run with the user's permissions.

### Cited Findings
- **Launch**: "Added Claude Mods: plugins may now modify deeper behavior" — [CL 2.1.287](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - "Mods are on by default. In the terminal, use Claude Code v2.1.287 or later"
  - `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` is now ignored
  - [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
- **Difference from hooks**: a settings hook is "A shell command, HTTP request, or prompt that Claude Code runs on a lifecycle event". A mod is "Functions in a plugin that Claude Code calls in its own process", which can change "Tool calls, prompts, commands, turns, and what the interface draws" and can draw UI — [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
- **Packaging**: the mod needs `.claude-plugin/plugin.json`, a `hooks/hooks.json` with `"modules": ["./register.js"]` (which can also hold settings hooks), and the module exporting `register(on, options)`. Tests are `*.test.ts` files run by `claude plugin test` — [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- **Events relevant to orchestration**:
  - `tool.call` (`next(e)`, `{deny}`, `{result}`)
  - `tool.check` (`{decision}` allow/ask/deny, after PreToolUse; `e.agentId` set for subagents and teammates, `e.ceiling`, v2.1.290+)
  - `agent.spawn` ("A subagent or an agent team teammate is about to start … `next({ ...e, model })` to choose its model, or `{ deny: reason }`")
  - `agent.offer` (withhold a subagent type)
  - `prompt.submit`, `turn.step` (change model or effort per request), `turn.complete`, `session.append`, `session.receive`/`send`, `classic.<Event>` (wrapping settings hooks), `skill.prompt`
  - [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
  - Workflow agents were added to `agent.spawn` "with their run and index, so a mod can refuse them" ([CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)), teammates in CL 2.1.289, and `agentId` on `tool.check` in CL 2.1.290
- **API**: `$.agent.register|spawn|list` (status includes idle and waiting since 2.1.289), `$.model.complete|fork|classify`, `$.tool.register` (`isDeferred` 2.1.293), `$.ui.status` ("Pins `text` as this plugin's status line under the prompt"), `$.ui.notify` (2.1.295), `$.store` (cross-session KV, 4 MiB), `$.state` — [mods reference](https://code.claude.com/docs/en/plugins/mods/reference); [claude-code.d.ts](https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts); [CL 2.1.293, 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - `$.model.complete` prompt caching (`cache: true` on blocks) arrived in CL 2.1.292
  - Its `maxTokens` defaults to 1024 — [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- **Limits**: a hook gets 10 s of its own execution per event; `$.process.run` 30 s default, 10 min max; `$.fs` 4 MiB — [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- **Where they run**: hooks run in the terminal, Desktop, VS Code, `claude -p`/SDK and cloud sessions (when the plugin reaches them). Drawing works only in terminal and Desktop — [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
- **Trust and controls**:
  - "Mods aren't sandboxed", and a mod that approves tool calls can override `ask` rules and user PreToolUse blocks
  - Off switches: `--safe-mode`, `disableAllHooks`, managed `allowManagedModsOnly`, `prependPlugins`/`appendPlugins` ordering, the `sec-default@builtin` guard
  - `claude plugin validate` prints `hooks:`/`calls:` lines and `gatingHooks` ([CL 2.1.290](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - [mods overview](https://code.claude.com/docs/en/plugins/mods/overview); [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- **Built-in mods**: `cc-plugin-agents-md`, `cc-plugin-diff`, `cc-plugin-sec-default`, `cc-plugin-telemetry`, `cc-plugin-you-should-know` (a side agent, off by default) — [mods overview](https://code.claude.com/docs/en/plugins/mods/overview); [CL 2.1.287](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Docs pages**: [overview](https://code.claude.com/docs/en/plugins/mods/overview), [reference](https://code.claude.com/docs/en/plugins/mods/reference), plus create, interface, events, api, test, troubleshoot and admin under `/docs/en/plugins/mods/`. The bundled `plugin-authoring` skill writes mods.

### Inferences
- A blitz mod could replace or strengthen several shell hooks:
  - `agent.spawn` could enforce model and effort per `blitz:*` agent type, including workflow agents, and deny out-of-plan spawns.
  - `tool.check` with `agentId` could make the `critic` truly read-only per agent, with no `agent_type` string parsing.
  - `$.ui.status` or a band could show the DAG/wave status.
- Costs of a mod: JS rather than bash, the higher-trust model (users must trust unsandboxed code), interplay with org `allowManagedModsOnly`/`sec-default`, and a floor of 2.1.287+ (2.1.292 for workflow-agent coverage).
- Keep the shell hooks as the portable baseline. Installed mods are stopped by `disableAllHooks`, `--bare` and `--safe-mode` ("The settings and flags that stop installed mods, such as `disableAllHooks`, `--bare`, and `--safe-mode`" — [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)), and by org `allowManagedModsOnly`. A mod is therefore an add-on, not a replacement for a safety-critical guard. I did not verify whether settings hooks also stop under `--bare`.

### Gaps
- The full `AgentSpawnInput` shape (whether `agentType`, `isolation` or workflow `run`/`index` fields are exposed) wasn't visible in the truncated d.ts fetch.

## 6. Hooks changes in this window

### Takeaway
Key changes for guard and gate hooks:
- `onFailure: "block"` (2.1.295) makes command and HTTP guards fail closed.
- Prompt and agent hooks written as instructions now block correctly (2.1.294).
- Stop and SubagentStop prompt hooks are judged better (2.1.294).
- Managed `continue:false` now ends the turn (2.1.296).
- `subagentStatusLine` gets `agentType` (2.1.293).
- Hook output is sanitized (`<system-reminder>` escaped in 2.1.292).
- A PreToolUse `updatedInput` is re-checked against permission rules (2.1.290).

### Cited Findings
- **`onFailure: "block"` (2.1.295)**: "a hook that can't start, times out, or exits with an unexpected code blocks the action instead of letting it through" ([CL 2.1.295](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)). The default is `"continue"`; "With `"block"`, a failure behaves like exit code 2 … The field has no effect on `Stop`, `SubagentStop`, `TaskCompleted`, `TeammateIdle`, or background hooks." — [hooks](https://code.claude.com/docs/en/hooks)
- **Prompt and agent hooks**: "Fixed `prompt` and `agent` hooks written as instructions (such as "Block commands that...") allowing what they should block" and "Improved how `prompt` hooks on Stop and SubagentStop written as instructions … are judged, so Claude is less likely to stop early" — [CL 2.1.294](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - Prompt hook defaults: 30 s timeout, `$ARGUMENTS` holds the input. Agent hooks are "Experimental", 60 s — [hooks](https://code.claude.com/docs/en/hooks)
  - Stop prompt hooks no longer resend the whole prompt on repeat blocks (older) — [CL 2.1.274](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - Agent-type hooks no longer run on `PermissionRequest` ([CL 2.1.280](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Prompt hooks fail behind gateways rejecting structured outputs; `CLAUDE_CODE_DISABLE_STRUCTURED_OUTPUTS` was added (CL 2.1.288)
- **Managed hooks (2.1.296)**: "Fixed managed-settings `PreToolUse` hooks that deny a tool call with `"continue": false`, and managed `prompt` hooks that block one, refusing the call but not ending the turn". Also fixed: managed PostToolUse not applying `updatedMCPToolOutput` — [CL 2.1.296](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
  - `allowManagedHooksOnly` blocks plugin hooks unless the plugin is force-enabled in managed `enabledPlugins` — [hooks](https://code.claude.com/docs/en/hooks)
- **PostToolUse output replacement**: "`updatedToolOutput` replaces the tool's output before Claude sees it. It works for all tools … a mismatched value is ignored". `updatedMCPToolOutput` is MCP-only, and the docs say to prefer `updatedToolOutput` — [hooks](https://code.claude.com/docs/en/hooks)
- **`subagentStatusLine`**: "Added `agentType` to the `subagentStatusLine` payload, so scripts can tell custom subagent types apart" — [CL 2.1.293](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md). Plugins may set `subagentStatusLine` and `agent` defaults via `settings` — [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- **SubagentStart**: `additionalContext` "is added to the subagent's context before its first prompt". On re-runs, it is injected again "only if the earlier copy is gone", which preserves the cache. Plugin agent matchers use the scoped name (`^my-plugin:reviewer$`) — [hooks](https://code.claude.com/docs/en/hooks)
- **Stop**: `stop_hook_active` is in the input; "After eight consecutive stop-hook continuations, Claude Code ends the turn … `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`". `additionalContext` continues the turn as "Stop hook feedback" without showing an error. The Stop input includes `last_assistant_message` and `background_tasks` — [hooks](https://code.claude.com/docs/en/hooks); [issue #93672](https://github.com/anthropics/claude-code/issues/93672)
- **Safety and correctness fixes**:
  - "`<system-reminder>` tags written in a hook's output are escaped" ([CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Hook output was altered when it resembled a plugin hint tag (CL 2.1.296)
  - Permission rules weren't re-applied after a PreToolUse rewrite (CL 2.1.290)
  - PreToolUse and PermissionRequest hooks were skipped when matching or serialization failed; such calls are now blocked (CL 2.1.288)
  - PreToolUse hook approvals bypassed prompts for UNC reads (CL 2.1.292, security)
  - An async Stop hook with an unquoted path containing a space caused an endless loop (CL 2.1.290)
  - Async hook multi-line JSON was ignored (CL 2.1.295)
  - InstructionsLoaded now carries `agent_id`/`agent_type` (CL 2.1.288)
  - `--debug` logs each command hook's command, plugin, outcome and duration (CL 2.1.296)
  - Late-loading plugin SessionStart hooks were skipped on name clash (CL 2.1.296)
  - Async SessionStart context was re-added on every resume (CL 2.1.295)
  - `CLAUDE_ENV_FILE` didn't reach Bash after `/resume` or `/branch` (CL 2.1.295)
- **Plugin hook conflict note**: `/plugin` now notes a plugin "whose hooks are left out because another enabled plugin has the same name" — [CL 2.1.296](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Hook event inventory (current)**: SessionStart, Setup, SessionEnd, UserPromptSubmit, UserPromptExpansion, Stop, StopFailure, PreToolUse, PermissionRequest, PermissionDenied, PostToolUse, PostToolUseFailure, PostToolBatch, SubagentStart, SubagentStop, TaskCreated, TaskCompleted, TeammateIdle, PreCompact, PostCompact, PreModelSwitch, PostModelSwitch, Notification, MessageDisplay, InstructionsLoaded, ConfigChange, CwdChanged, DirectoryAdded, FileChanged, WorktreeCreate, WorktreeRemove, Elicitation, ElicitationResult. Hook types are `command`, `http`, `mcp_tool`, `prompt` and `agent` — [hooks](https://code.claude.com/docs/en/hooks)

### Inferences
- blitz's PreToolUse guards (`block-destructive-git.sh`, `tasks-guard.sh`, `pre-edit-guard.sh` and others) fail open today if the script crashes or times out. Adding `"onFailure": "block"` makes them fail closed, but needs a 2.1.295 floor; older versions ignore or strip the unknown key, which is unverified.
- `onFailure` has no effect on Stop or SubagentStop, so blitz's `stop-gate.sh` must handle its own errors. Its loop protection should respect `stop_hook_active` and the 8-continuation cap.
- If blitz's Stop gate is or could become a `prompt` hook, 2.1.294's judging change makes instruction-style prompts more reliable.
- Because SubagentStart context is injected once per subagent (re-injected only after compaction), blitz's `subagent-context.sh` should not depend on re-injection on each SendMessage resume.

### Gaps
- I could not read the hooks docs section on `prompt`-hook response format for Stop and SubagentStop (truncated past 200K chars).

## 7. Plugin system changes: eval, test, validate, `/skill-doctor`, `/doctor prompt-audit`, configure, marketplace

### Takeaway
In-window additions:
- `/doctor prompt-audit` (2.1.283)
- `claude plugin configure` and `--config server.key=value` (2.1.285)
- `plugin install --marketplace` (2.1.292)
- Many new `claude plugin validate` checks: MCP entries, unquoted `${CLAUDE_PLUGIN_ROOT}`, missing component paths, `gatingHooks`, README install advice
- `claude plugin test` for mods

`claude plugin eval .` (2.1.269) and `/skill-doctor` (2.1.261) predate the window.

### Cited Findings
- **`/doctor prompt-audit`**: "Added `/doctor prompt-audit` (also `/checkup prompt-audit`) to audit your CLAUDE.md files, skills, agents and commands for prompting patterns written for older models" ([CL 2.1.283](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)). On Claude Code configuration it reports "stale paths, stale commands and contradicting instruction files" first (CL 2.1.283)
- **`/skill-doctor`**: "show which loaded skills go unused and what they cost in context" — [CL 2.1.261](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md). Note that blitz `compat.json` lists `skill_doctor: 2.1.252`, which conflicts with the changelog's 2.1.261.
- **`claude plugin eval .`**:
  - Added in [CL 2.1.269](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) (older); git 2.31+ required since CL 2.1.283
  - Cases live in `evals/` (`prompt.md`, `case.yaml`, `graders/`); each case runs 3× with the plugin and 3× without it (a no-plugin baseline); `--threshold` defaults to 1.0
  - Six grader types (`regex`, `tool_used`, `tool_order`, `file_exists`, `llm`, `baseline`), and "There are no custom-code graders"
  - `claude plugin eval init` scaffolds a suite; JSON and HTML reports; `experimental.evals` relocates the directory
  - [plugin-evals](https://code.claude.com/docs/en/plugin-evals); [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- **`claude plugin test`** (mods): runs `*.test.ts(x)` files
  - Failed `expect` and refused stubs now fail the test ([CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `mock.session` added (CL 2.1.293)
  - [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- **`claude plugin validate` new checks**:
  - MCP entries, undeclared `${user_config.*}` references and insecure URLs, plus a warning when `${CLAUDE_PLUGIN_ROOT}` is unquoted in shell-form hooks ([CL 2.1.281](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - Missing or escaping `outputStyles`/`themes`/`monitors`/`lspServers` paths, and uninstallable names (CL 2.1.283)
  - `gatingHooks` with `.catch` status (CL 2.1.290)
  - Mods' `$.state` var rules (CL 2.1.292)
  - README install-line advice that "never changes the exit code, even with `--strict`" (CL 2.1.295)
  - Rebound top-level `var` errors (CL 2.1.295)
  - Reserved-name checks: names starting `claude-`, `anthropic-` or `cc-plugin-` are errors — [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
  - Top-level `themes`/`monitors` keys now warn; use `experimental.*` — [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- **Configure**: "Added `claude plugin configure <plugin>` to show a plugin's options and which are unset, or save new values read from stdin with `--values-stdin`" and "`<server>.<key>=<value>` to `claude plugin install --config`" ([CL 2.1.285](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `userConfig.options` pickers need 2.1.271+ (plugins using them fail to load on older versions)
  - `/config` rows appear for plugin options (2.1.269+)
  - [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- **Marketplace**:
  - `claude plugin install --marketplace <source>` (CL 2.1.292)
  - `install`/`enable`/`disable`/`marketplace add` warn when the target settings file doesn't load (CL 2.1.295)
  - Names imitating reserved marketplaces are refused (CL 2.1.280)
  - npm sources that are git repos or folders are refused, and dependencies install only from registry packages (CL 2.1.286)
  - HTTPS fallback for GitHub sources without SSH keys (CL 2.1.288; Windows CL 2.1.296)
  - Large-submodule marketplaces now fetch only plugin submodules (CL 2.1.295)
  - [CL](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Plugin LSP and manifest**:
  - `${user_config.*}` and `${CLAUDE_PLUGIN_ROOT}` are substituted in LSP `initializationOptions` (CL 2.1.288)
  - Shell-form hooks and monitor commands reject `${user_config.*}`; use exec form or `CLAUDE_PLUGIN_OPTION_<KEY>`
  - A plugin-root `CLAUDE.md` isn't loaded, and validate warns
  - `bin/` blocks claude.ai and Cowork installs
  - [plugins-reference](https://code.claude.com/docs/en/plugins-reference)

### Inferences
- blitz could add `evals/` cases (for example, "does `/blitz:build` invoke the build-wave workflow", or "does the critic return the schema") using `tool_used` and `file_exists` graders. The eval runner already uses `claude plugin eval .` (blitz has an `evals/` dir), so the window's fixes (Docker Desktop link refusal fixed in 2.1.293, stale local-folder copies fixed in 2.1.289) matter.
- Running `/doctor prompt-audit` against blitz `skills/` and `agents/` is a cheap check for prompting patterns tuned for older models.
- If blitz uses shell-form hooks with unquoted `${CLAUDE_PLUGIN_ROOT}`, the 2.1.281 validate warning would flag them; quoting or exec form is required for paths with spaces.
- Reconcile the `compat.json` `skill_doctor` floor (2.1.252) with the changelog (2.1.261).

### Gaps
- No docs page found for `/skill-doctor` or `prompt-audit` output formats.

## 8. Deprecated, removed or changed behaviors a 2.1.271–2.1.277 plugin should stop relying on

### Takeaway
There were few hard removals. The biggest semantic shifts are:
- auto mode is now the default permission mode (2.1.283–2.1.285)
- the background-command time limit (unattended only)
- subagent results arrive framed as "subagent output" (2.1.277)
- TaskOutput was removed (2.1.277)
- names in the `anthropic-skills`/`claude-ai` namespaces (2.1.282, partly reverted in 2.1.283)
- agent names capped at 256 characters

### Cited Findings
- **TaskOutput removed (2.1.277, at the old floor's edge)**: "Removed the deprecated TaskOutput tool; Claude reads a background task's output file with Read instead, and the `taskOutputMaxChars` setting and `TASK_MAX_OUTPUT_LENGTH` no longer have any effect" — [CL 2.1.277](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Subagent result framing (2.1.277)**: subagent results reach the main agent "under a header marking them as subagent output, with the result indented". Workflow `agent()` prompts are framed as script-authored on Bedrock, Vertex and Foundry — [CL 2.1.277](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Auto mode is the default permission mode**:
  - interactive sessions on third-party providers or with telemetry off ([CL 2.1.283](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - every interactive terminal and VS Code session (CL 2.1.284)
  - `claude -p` and Python SDK on third-party providers or telemetry off (CL 2.1.285)
  - in each case "`permissions.defaultMode` still overrides it"
  - Server-side classifier default ([CL 2.1.278](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md), 2.1.282)
  - The dangerous `rm` prompt waits 2 min, then denies with a rewrite hint in auto and bypass modes (CL 2.1.281)
- **Background command limit**: introduced for all sessions in 2.1.285, then limited to unattended sessions in 2.1.288 — [tools-reference](https://code.claude.com/docs/en/tools-reference)
- **Namespaces**: skill folders, commands and workflow commands in the `anthropic-skills` or `claude-ai` namespace stopped loading ([CL 2.1.282](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)); the `claude-ai` reservation was reverted in CL 2.1.283
- **Agent names**: "at most 256 characters: a longer one is rejected" ([CL 2.1.292](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)). Agent `name` must not contain `:` — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- **Env var no longer read**: `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` (mods early access) is ignored from 2.1.287 — [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
- **`teammateDefaultModel`** was removed in 2.1.234 (older) and is now ignored — [agent-teams](https://code.claude.com/docs/en/agent-teams)
- **Self-hosted runner hooks**: wrappers or `command` hooks appending `--system-prompt`/`--append-system-prompt` must switch to the `-file` forms ([CL 2.1.281](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
- **Other behavior changes**:
  - `claude project purge` became `claude purge` (old name still works; [CL 2.1.288](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md))
  - `--bare` connects only the named MCP servers, sends no system reminders and starts no background tasks (CL 2.1.286)
  - `"type": "sdk"` MCP entries in plugin or agent files are skipped (CL 2.1.274, older)
  - Monitor allow rules are set aside in auto mode — [tools-reference](https://code.claude.com/docs/en/tools-reference)
  - Path-scoped rules and nested CLAUDE.md files now load on Write and Edit (CL 2.1.288) and on single-file `cat`/`head`/`sed -n` (CL 2.1.293)
  - MCP tool description cap raised from 2,048 to 4,096 (CL 2.1.296)
  - Models: Opus 5.5 default (CL 2.1.280), Sonnet 5.5 (CL 2.1.284), Haiku 5.5 (CL 2.1.293); Sonnet 5.5 cache reads priced at $0.10/M (CL 2.1.296)
- **Doc trend**: the docs now frame workflows as the scalable path for "dozens to hundreds of agents per run" and Claude-orchestrated turn-by-turn subagents for "a few delegated tasks per turn" — [workflows](https://code.claude.com/docs/en/workflows); [agents](https://code.claude.com/docs/en/agents)

### Inferences
- blitz should not reference TaskOutput, and can read background output files with Read. blitz guards must assume auto mode by default: a PreToolUse `allow` from blitz plus the auto classifier interplay. Workflow `agent()` prompts don't count as user intent in the classifier, so destructive actions in `dev` agents may be denied more often under auto mode.
- Since the default mode moved to auto, blitz's permission-related hooks (`permission-denied.sh`) will see classifier denials. Their "Not run" rows (CL 2.1.296) are not errors.
- Bumping `cc_min` from 2.1.271 to at least 2.1.288 would remove the window of all-session background limits and pick up the 2.1.288 hook-matching fail-closed fix and plugin-agent-as-teammate fix. A floor of 2.1.295 adds `onFailure: "block"` and the skills preload cap; 2.1.296 adds `autoCompactWindow` and `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL`.

### Gaps
- GitHub issue search for this window was blocked (the session's GitHub API is repo-scoped), so I reviewed only one issue (#93672). I found no other community reports on plugin workflows or mods regressions.
- The 2.1.279 changelog entry doesn't exist (the CHANGELOG goes from 2.1.280 to 2.1.278).

### Sources consulted
- https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md (local copy read in full for 2.1.278–2.1.296, plus greps of 2.1.261–2.1.277)
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/agent-teams
- https://code.claude.com/docs/en/workflows
- https://code.claude.com/docs/en/plugins/mods/overview
- https://code.claude.com/docs/en/plugins/mods/reference
- https://code.claude.com/docs/en/agent-view
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/costs
- https://code.claude.com/docs/en/plugin-evals
- https://code.claude.com/docs/en/tools-reference
- https://code.claude.com/docs/en/cross-session-messaging
- https://code.claude.com/docs/en/model-config
- https://code.claude.com/docs/en/agents
- https://code.claude.com/docs/en/agent-sdk/typescript
- https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts
- https://github.com/anthropics/claude-code/issues/93672
- Web search (no relevant hits): gitea.com/Enoch2090/claude-code-gitea-action, fast.io claude-code-github-action guide, jannikreinhard.com claude-code-github-actions, vibeindex.ai, tomevault.io
- Local: /home/user/blitz-cc/.claude-plugin/compat.json, /home/user/blitz-cc/workflows/*.js, /home/user/blitz-cc/hooks/hooks.json
