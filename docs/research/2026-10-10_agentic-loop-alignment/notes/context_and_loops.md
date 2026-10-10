# Context engineering, prompt-caching economics, and long-running agent loop design (as of 2026-10-10)

Scope: what the evidence says about context and cost management and about long-horizon or unattended loop design for coding agents, applied to blitz (github.com/lasswellt/blitz-cc). Every source carries its publication date, or "undated" when the page shows none. Claude Code docs pages are living documents with no visible date. I read them on 2026-10-10. Lines marked **[estimate]** are my arithmetic from published prices. They are not measurements.

Repo facts checked locally:
- 5 agent files in `agents/` set `cacheTtl`.
- `skills/_shared/agents.md:63` documents `subagentPromptCacheTtl: 1h` together with `experimental.cacheTtl: 1h`.
- `skills/_shared/agents.md:68` leaves `autoCompactWindow` unset on agents.
- `hooks/scripts/subagent-context.sh` and `hooks/scripts/pre-compact-snapshot.sh` exist.

---

## 1. Prompt caching: mechanics, pricing, cache busting, and Claude Code behavior

### Takeaway
On Claude 5.5 models, cache reads cost 0.05x base input. A 1h write costs 2x and a 5m write 1.25x. The 1h TTL pays for itself whenever a prefix is reused after an idle gap of 5 to 60 minutes. That gap is typical of blitz's critic and dev re-spawns and of loop ticks. The bigger risk for blitz is cache scope, not TTL. Claude Code's cached prefix includes the working directory, the auto-memory paths, and a git-status snapshot. Subagents never read the parent's cache, and sessions in different directories or worktrees miss each other's caches.

### Cited Findings
**Pricing (API, per MTok):**
- Multipliers: 5m write = 1.25x base, 1h write = 2x base, read = 0.1x in general. Opus 5.5 and Sonnet 5.5 are exceptions at 0.05x. — [Anthropic prompt caching docs, undated, read 2026-10-10](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- Opus 5.5: base $4, 5m write $5, 1h write $8, read **$0.20**, output $20. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- Sonnet 5.5: base $2, 5m write $2.50, 1h write $4, read **$0.10**, output $10. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
  - These match the brief's figures.
- Haiku 5.5: $0.10 base and $0.01 read at ≤100K prompt tokens; $0.50 base and $0.05 read above 100K. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- On Opus 4.7 and later, Sonnet 5 and later, and Haiku 5.5, the 1M window has "standard pricing with no premium beyond 200K tokens". Haiku 5.5 is the exception and costs more above 100K. — [Claude Code model config docs, undated](https://code.claude.com/docs/en/model-config)

**Mechanics:**
- Minimum cacheable prefix is 512 tokens on Opus 5.5, Sonnet 5.5, and Haiku 5.5. Shorter prompts silently don't cache. — [prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- Hierarchy is tools → system → messages. Each level builds on the ones before it. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- There are at most 4 explicit breakpoints. A request's lookback walks back at most 20 block positions to find a prior write. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- Invalidation matrix:
  - Changing tool definitions invalidates everything.
  - `tool_choice`, images, and some thinking or effort settings invalidate system and messages.
  - Setting effort to the model's default does not invalidate.
  - A `role: "system"` message inside `messages` can add instructions without invalidating. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- When mixing TTLs, longer-TTL entries must come before shorter ones. — [same](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)

**Claude Code specifics:**
- Layer order:
  1. System prompt and tool definitions
  2. Project context (CLAUDE.md, auto memory, unscoped rules), reloaded only at session start, `/clear`, or `/compact`
  3. Conversation

  Skills and plan mode append as messages, so they keep the cache. — [How Claude Code uses prompt caching, undated](https://code.claude.com/docs/en/prompt-caching)
- These actions invalidate the cache:
  - switching models
  - changing effort (except on Opus, Sonnet, and Haiku 5.5 and Fable 5.1 with an API key or subscription, where the cache stays intact)
  - turning on fast mode
  - adding or removing MCP servers when tools load upfront
  - enabling or disabling a plugin that provides MCP servers
  - denying a whole tool when tool search is off
  - compaction
  - image eviction
  - upgrading Claude Code

  — [same](https://code.claude.com/docs/en/prompt-caching)
- Plugin skills, commands, agents, hooks, and monitors "never invalidate the cache". Their content is appended. — [same](https://code.claude.com/docs/en/prompt-caching)
- A skill or command whose frontmatter names a `model` different from the session's is a model switch for that turn: a full uncached re-read. A `context: fork` skill sets the forked subagent's model instead. — [same](https://code.claude.com/docs/en/prompt-caching)
- Editing CLAUDE.md mid-session keeps the cache, but the edit does not apply until `/clear`, `/compact`, or a restart. — [same](https://code.claude.com/docs/en/prompt-caching)
- **TTL buckets.** The main conversation gets 1h by default only on a subscription within plan usage. "Everything else" gets 5m by default: subagents, workflows, teammates, forks, compaction, titles. On API keys, cloud providers, or usage credits, both buckets get 5m. — [same](https://code.claude.com/docs/en/prompt-caching)
- TTL controls, in precedence order:
  1. `FORCE_PROMPT_CACHING_5M`
  2. the bucket's env var (`CLAUDE_CODE_PROMPT_CACHE_TTL` / `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL`)
  3. the bucket's setting (`promptCacheTtl` / `subagentPromptCacheTtl`, ≥2.1.242)
  4. the subagent frontmatter `experimental.cacheTtl` (≥2.1.248; ignored while a subscription is on usage credits)
  5. `ENABLE_PROMPT_CACHING_1H`
  6. the bucket default

  — [same](https://code.claude.com/docs/en/prompt-caching)
- **Cache scope.** "In Claude Code, the cache is effectively scoped to one machine and directory." The system prompt embeds the auto-memory paths, and the conversation opens with the working directory and OS. Sequential sessions share a prefix "only when the git status snapshot taken at startup matches". — [same](https://code.claude.com/docs/en/prompt-caching)
- **Subagents.** A subagent's "first request doesn't read the parent's cache, because the two prefixes differ". Forks do inherit the parent's prefix. Resumed subagents can read their earlier cache. Workflow fan-outs hold all but the first same-prefix agent for up to 5 s so the others hit its cache. — [same](https://code.claude.com/docs/en/prompt-caching)
- Diagnosing misses: `/usage` shows a `Prompt cache (main)` line (≥2.1.251) with hit %, misses, the likely cause (≥2.1.260), expected rebuilds, and warm or cold state. It covers the main conversation only, not subagents. — [Manage costs docs, undated](https://code.claude.com/docs/en/costs); [prompt caching docs](https://code.claude.com/docs/en/prompt-caching)
- Usage climbs in long sessions for several reasons: long context re-read at the cached rate every request, misses after idle gaps, scheduled tasks firing the full context, goal check-ins, subagents, and compaction requests. — [Manage costs](https://code.claude.com/docs/en/costs)

**Design rationale from the Claude Code team (Thariq Shihipar, 2026-04-30):**
- The team "alerts on its cache hit rate and declares SEVs when it drops too low". No target % is given. — [Lessons from building Claude Code: prompt caching is everything](https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/)
- Past breakages:
  - a detailed timestamp in the static system prompt
  - non-deterministic tool ordering
  - changing the parameters of the Agent tool, such as its list of callable agents

  — [same](https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/)
- Rules:
  - pass updates via `<system-reminder>` in messages
  - never switch models mid-session; use a subagent with a hand-off instead
  - defer tools rather than removing them
  - compact with cache-safe forking, which costs about one-tenth of the uncached price and yields a summary of about 20k tokens

  — [same](https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/)

### Inferences
- **[estimate] When the 1h TTL pays off.**
  - 1h costs 0.75x base more than 5m per prefix write.
  - A cold miss under 5m costs a 1.25x rewrite.
  - So 1h pays off if, per write, the expected number of reuses that fall 5 to 60 minutes after the previous use is above 0.6.
  - Worked example, a blitz critic with a 30k-token stable prefix on Sonnet 5.5: the 1h write costs $0.12 vs $0.075 for 5m; each avoided miss saves $0.075; a cached read is $0.003. One re-spawn after a 6-to-59-minute gap covers the premium.
  - Blitz's critic fix rounds and loop ticks fit that profile, so `subagentPromptCacheTtl: 1h` is justified.
  - For back-to-back subagents spawned within 5 minutes of each other, 1h is a small pure loss (+60% on writes).
- **The SubagentStart invariant block helps only if the prefix before it is also byte-identical.**
  - That prefix is the agent system prompt, the tools, CLAUDE.md, and the environment block.
  - Because the environment block contains the working directory, a dev agent spawned in a git worktree gets a different prefix from one in the main checkout, and from one in a different worktree.
  - Per-worktree isolation therefore caps cross-spawn cache reuse to agents in the same directory.
  - Worth verifying with `ephemeral_1h_input_tokens` and `cache_read_input_tokens` in `claude -p --output-format json`, or with OTel cache metrics.
- **Skill model pinning.** Any blitz skill that pins a `model` in frontmatter, rather than using `model: inherit`, causes a full uncached re-read on that turn. CLAUDE.md's "`model: inherit` unless slash-only" policy is cache-correct, but each slash-only pinned skill costs one rebuild per invocation.
- **`/usage` blind spot.** The `/usage` cache line doesn't cover subagents. Blitz's cost claims for subagent caching need OTel or `-p` JSON evidence, not `/usage`.

### Gaps
- I found no published figure for the hit rate the Claude Code team targets.
- I found no doc saying where SubagentStart `additionalContext` lands in the subagent request (system prompt or first message). That affects whether the invariant block is the cached prefix or only extends it.
- I found no measurements of Claude Code cache hit rates across worktrees.

---

## 2. Context rot and long-context degradation; does 1M context change "fresh subagent per task"?

### Takeaway
Independent evidence from 2025 shows accuracy falling well before the advertised window across all model families. The 1M window removes the hard limit but not the degradation. It also raises per-request cost, because every turn re-reads the whole context. Fresh subagents per task remain the evidence-backed default. Use the 1M window as headroom, not as working memory.

### Cited Findings
- **Chroma "Context Rot" (2025-07-14):**
  - 18 models tested, including Claude Opus 4 and Sonnet 4, GPT-4.1, o3, Gemini 2.5, and Qwen3.
  - Performance degrades as input length grows "even on simple tasks", and models do not use context uniformly.
  - Distractors compound the decline.
  - Shuffled haystacks outperformed logically coherent ones.
  - On LongMemEval, focused ~300-token prompts significantly outperformed full ~113k-token prompts across all families. Claude showed the largest gap, largely from abstentions.

  — [Chroma research](https://www.trychroma.com/research/context-rot)
- **NoLiMa (arXiv 2502.05167, 2025-02-07; ICML 2025):**
  - At 32K tokens, 11 of 13 long-context models fall below 50% of their short-context baseline.
  - GPT-4o drops from 99.3% to 69.7%.

  — [arXiv](https://arxiv.org/abs/2502.05167)
- **Anthropic (2025-09-29):** context is "a finite resource with diminishing marginal returns" with an "attention budget". The guidance is "the smallest set of high-signal tokens". Sub-agents return condensed summaries "often 1,000–2,000 tokens". — [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- **Huntley:** roughly 170k tokens are usable, and "output quality drops as usage grows". Keep context use low. — [Ralph Wiggum as a software engineer, 2025-07-14](https://ghuntley.com/ralph/)
- **1M in Claude Code:**
  - Native 1M with no suffix on Sonnet 5 and later and Opus 4.7 and later (both include the 5.5 models).
  - These auto-compact at about **967K** tokens by default.
  - `autoCompactWindow` accepts 100K to 1M; the env var `CLAUDE_CODE_AUTO_COMPACT_WINDOW` overrides it.
  - `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` treats these models as 200K.

  — [Model config docs](https://code.claude.com/docs/en/model-config)
- In the context-window docs example, a subagent read 6,100 tokens of files and returned 420 tokens to the parent. — [Explore the context window, undated](https://code.claude.com/docs/en/context-window)

### Inferences
- **[estimate] Re-read cost at large context.** At 500K tokens of context, every request re-reads the context at the cache rate:
  - Opus 5.5: $0.10 per request
  - Sonnet 5.5: $0.05 per request
  - A 100-tool-call task therefore costs $5 to $10 in cache reads alone, before any degradation.
  - At 50K context, the same task costs $0.50 to $1.

  The default ~967K compaction point means that, left alone, a session can spend tens of dollars per task on reads while operating in the regime where degradation is documented.
- **Recommendations for blitz:**
  - Keep fresh-context subagents per task.
  - Consider setting `autoCompactWindow` (for example 200K to 300K) on the **main/orchestrator** thread, or on long-lived loop sessions, rather than relying on the ~967K default. Note that blitz deliberately leaves it unset on agents, whose budgets keep them small; that is reasonable.
- **Caveat on the evidence.** None of the cited degradation studies tested Claude 5.x. The direction is consistent across 2025 models, but the magnitude on 5.5 models is unmeasured in public sources.

### Gaps
- I found no public context-rot or NoLiMa-style results for Claude 5.5 models.
- I did not fetch RULER (arXiv 2404.06654) in this pass. Its often-cited finding that effective length falls short of claimed length should be verified before use.

---

## 3. Compaction and memory: auto-compact, skills after compaction, CLAUDE.md sizing, memory

### Takeaway
Blitz's "keep skill bodies under ~5,000 tokens" rule matches the documented re-attach cap. The cap is per skill, though, inside a **combined 25,000-token budget**, filled most-recent-first. Sessions that chain more than five large skills will lose older skills entirely after compaction. Pre-compaction snapshots such as HANDOFF.json align with Anthropic's structured note-taking guidance.

### Cited Findings
- After auto-compaction, Claude Code "re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens", filled starting from the most recently invoked skill. "Older skills can be dropped entirely." — [Skills docs, undated](https://code.claude.com/docs/en/skills)
- Keep `SKILL.md` under 500 lines. The skill body stays in context across turns, so "every line is a recurring token cost". The skill listing truncates `description` plus `when_to_use` at 1,536 characters. — [Skills docs](https://code.claude.com/docs/en/skills)
- What survives compaction:
  - Restored: system prompt, CLAUDE.md, memory, MCP tools, up to five of the most recently modified files, and the invoked skills.
  - Not restored: the skill listing.

  The summary keeps requests and intent, key concepts, files, errors and fixes, pending tasks, and current work. — [Explore the context window](https://code.claude.com/docs/en/context-window)
- Auto memory loads the first 200 lines or 25KB of MEMORY.md, whichever comes first. Subagents don't get the main session's auto memory. A custom agent with `memory:` frontmatter loads its own MEMORY.md. — [Explore the context window](https://code.claude.com/docs/en/context-window)
- "Aim to keep CLAUDE.md under 200 lines". Move workflow-specific instructions into skills. Compaction instructions can live in CLAUDE.md. — [Manage costs](https://code.claude.com/docs/en/costs)
- `/compact` reads the whole conversation to summarize it. While the cache is warm, that read is cheap because it shares the prefix. After the TTL it is fully uncached. "`/clear` costs nothing." `/rewind` hits the earlier cache entry. — [How Claude Code uses prompt caching](https://code.claude.com/docs/en/prompt-caching)
- Anthropic recommends structured note-taking to persistent files outside the window, tool-result clearing as the lightest compaction, and compaction tuned "for recall first, then precision". — [Effective context engineering, 2025-09-29](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- Cognition recommends a dedicated model to compress action history into "key details, events, and decisions", and notes it still eventually hits limits. — [Don't build multi-agents, 2025-06-12](https://cognition.com/blog/dont-build-multi-agents)

### Inferences
- **Blitz should state the 25K combined cap next to the 5K rule.** The real constraint for a long `next --loop` session is the sum across all skills invoked since the last compaction. Shared protocol files that skills load as references are file reads, not skill bodies, so they will not be re-attached either. Only the five most-recent-modified files return.
- **Write HANDOFF.json before compaction can strike.** PreCompact HANDOFF.json covers what the summary drops. Because auto-compaction triggers at ~967K by default, a loop that never compacts never writes HANDOFF.json. Writing progress at task boundaries in progress.md and tasks.json is the more reliable mechanism, and blitz already does it.

### Gaps
- I did not verify AGENTS.md support or precedence in Claude Code in this pass.
- I did not fetch the memory tool (API) docs. Claude Code auto-memory details come from the context-window page only.

---

## 4. Long-horizon agents: harnesses, progress files, git, init scripts, Ralph, Cursor, METR

### Takeaway
The converging design across Anthropic, Huntley, and Cursor (Nov 2025 to Jan 2026) is:
- fresh context per iteration
- one task per iteration
- external state in machine-edited JSON plus a progress log plus git commits
- an init script and smoke test at the start of every session
- a separate judge or evaluator deciding whether to continue

Blitz's tasks.json, progress.md, fresh subagents, and gates map almost one-to-one onto this design. The main documented failure modes to guard against are premature "victory" and marking work done without end-to-end tests.

### Cited Findings
- **Anthropic, "Effective harnesses for long-running agents" (2025-11-26).** The design:
  - An initializer agent creates `init.sh`, a progress log, and the first git commit.
  - The initializer also creates a feature list of over 200 items, all marked failing. JSON was chosen because the model is "less likely to inappropriately change or overwrite JSON files" than Markdown.
  - Coding agents do **one feature per session**.
  - Each session runs `init.sh` plus a basic end-to-end check first.
  - Agents use descriptive commits to revert bad changes.

  Failure modes observed:
  - one-shotting and running out of context mid-feature
  - "Claude declares victory on the entire project too early"
  - marking features complete without testing
  - re-learning how to run the app each session

  Browser automation (Puppeteer MCP) improved verification. — [Anthropic engineering](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- **Ralph loop (Huntley, 2025-07-14):**
  - `while :; do cat PROMPT.md | claude-code ; done`, with one item per loop.
  - `fix_plan.md` as a prioritized TODO list, plus specs/ files.
  - The main context acts as a scheduler and fans work to subagents, but uses only one subagent for build and test.
  - Backpressure comes from tests, typecheck, and lint.
  - An AGENT.md file records learnings.
  - Huntley recommends it for greenfield, not existing codebases.
  - Anecdotal cost claim: a $50k contract for $297 (unverified).

  — [ghuntley.com/ralph](https://ghuntley.com/ralph/)
- **Cursor, "Scaling long-running autonomous coding" (Wilson Lin, 2026-01-14):**
  - Flat peer coordination via a shared file and locks failed. Agents became risk-averse and churned.
  - Planners and sub-planners with workers, plus a judge at cycle end, worked. The "next iteration starts fresh".
  - Runs lasted about a week, and over 3 weeks for one migration. One project produced over 1M LOC.
  - Usage was "trillions of tokens" (no exact figure).
  - "The prompts matter more" than the harness or models.
  - In Cursor's runs, Opus 4.5 "tended to stop early and take shortcuts", while GPT-5.2 held focus longer.

  — [Cursor blog](https://cursor.com/blog/scaling-agents)
- **Cognition (2025-06-12):** "Share context, and share full agent traces". "Actions carry implicit decisions". Parallel subagents without shared context make conflicting assumptions. Claude Code is praised because its subagents answer well-defined questions rather than running in parallel with the main agent. — [Cognition](https://cognition.com/blog/dont-build-multi-agents)
- **METR (2025-03-19):**
  - The 50% time horizon doubled about every 7 months over 6 years. On 2024–2025 data it is faster, and under 3 months on SWE-bench Verified.
  - Near 100% success on tasks under ~4 minutes; under 10% on tasks over ~4 hours (2025 models).
  - The page itself flags that some figures are out of date.

  — [METR blog](https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/)
- **METR's time-horizons page (last updated 2026-09-08, "no longer actively updated"):**
  - GPT-5's 50% horizon is about 2h17m.
  - Claude Mythos Preview, Opus 4.6, and Opus 4.5 were added, but their values appear only in the chart and data file.
  - "Measurements above 16 hrs are unreliable".

  — [METR time horizons](https://metr.org/time-horizons/)

### Inferences
- **Blitz aligns with the consensus pattern.**
  - Blitz uses JSON task state written only through `scripts/tasks.sh`. That is stronger than Anthropic's "JSON is less likely to be overwritten", because it is enforced by a hook.
  - It writes progress.md and uses fresh subagents per task.
  - Gaps worth checking against the harness article:
    - an explicit init or smoke-test step at the start of every `next` tick (Anthropic's `init.sh` analogue)
    - an independent judge before a task or plan is marked done (Cursor's judge; `/goal`'s fresh evaluator)
- **Long-horizon claims need caution.** METR's own caveat that horizons above 16 h are unreliable, plus Cursor's model-specific early-stopping note, mean "unattended for days" claims should rest on per-tick gates, not on model stamina.

### Gaps
- I found no exact METR horizon values for Claude 5.x in text form. They are only in the linked data file.
- I did not fetch Factory, Amp/Sourcegraph, or OpenAI Codex long-task writeups in this pass, to stay within the tool budget.

---

## 5. Scheduling primitives in Claude Code: /loop, ScheduleWakeup, CronCreate, Routines, cloud sessions, /goal

### Takeaway
Each primitive has hard limits that shape blitz's unattended `next --loop` design:

| Primitive | Key limits |
|---|---|
| `/loop` and CronCreate | Session-scoped. Fire only while the session is open and idle. 50 tasks per session. 7-day expiry. Jitter of up to 30 minutes. No catch-up. |
| Self-paced `/loop` (ScheduleWakeup) | 1-minute to 1-hour delays. Not restored on `--resume`. |
| Routines | Cloud, fresh clone. Minimum 1h interval. 100 scheduled runs per hour per account. Push to `claude/` branches. |
| `/goal` | A Haiku-class evaluator after each turn. Cheap, but it can only judge what is in the transcript. |

Every interval fire re-sends the full session context, so long-lived loop sessions get more expensive per tick over time.

### Cited Findings
**Comparison of the three ways to schedule** — [Run prompts on a schedule, undated](https://code.claude.com/docs/en/scheduled-tasks):

| | Cloud | Desktop | `/loop` |
|---|---|---|---|
| Minimum interval | 1h | 1 minute | 1 minute |
| Needs machine on | No | Yes | Yes |
| Needs open session | No | No | Yes |
| Local files | No (fresh clone) | Yes | Yes |
| Permission prompts | No | Configurable | Inherited |

**`/loop`, ScheduleWakeup, and cron** — [same](https://code.claude.com/docs/en/scheduled-tasks):
- Self-paced `/loop` picks a delay between 1 minute and 1 hour each iteration.
- It ends via `ScheduleWakeup` with `stop: true`. If an iteration neither reschedules nor stops, a fallback wakeup fires about 20 minutes later.
- `.claude/loop.md` replaces the default prompt and is truncated beyond 25,000 bytes.
- Scheduled skills must be model-invocable: `disable-model-invocation: true` skills arrive as plain text.
- 50 tasks per session.
- The scheduler checks every second and enqueues at low priority between turns.
- Recurring jitter is fixed per task ID: up to 5 minutes for 10-minute tasks, up to 15 minutes for 30-minute tasks, and up to 30 minutes for hourly or daily tasks. One-shots at :00 or :30 fire up to 90 s early.
- Recurring tasks expire after 7 days.
- No catch-up: a missed fire runs once when the session goes idle.
- CronCreate tasks are restored on `--resume`. A self-paced `/loop` is **not** restored.
- Backgrounding the session carries `/loop` tasks over.
- `CLAUDE_CODE_DISABLE_CRON=1` disables the scheduler.
- The Monitor tool (streaming a background script) is "often more token-efficient" than polling.

**Cost of scheduled fires** — [Manage costs](https://code.claude.com/docs/en/costs):
- A scheduled task "fires on its interval even while the session is idle, sending your full context each time".
- `/usage` shows a Loops row with per-run tokens (≥2.1.242).

**Routines** (research preview) — [Routines docs, undated](https://code.claude.com/docs/en/routines):
- Triggers are schedule, API `/fire`, or GitHub PR and release events.
- Each run is a fresh cloud session with a fresh clone from the default branch and no permission-mode picker.
- Pushes go to `claude/` branches.
- Limits:
  - minimum interval 1h
  - 100 scheduled runs per hour per account
  - 30 per hour per routine for Run now and API fires
  - API fires capped at 100 per hour per account
- Runs draw on subscription usage.
- A green run status means "no infrastructure error", not task success.
- If GitHub auth is lost, runs are skipped for up to 72 h, then the routine turns off.
- Fire `text` arrives wrapped as untrusted `<routine-fire-payload>`.

**`/goal`** — [Keep Claude working toward a goal, undated](https://code.claude.com/docs/en/goal):
- `/goal` is a session-scoped prompt-based Stop hook.
- After each turn, the small fast model returns "not yet met", "met", or "impossible".
- The evaluator "doesn't run commands or read files", so the condition must be provable from transcript output.
- Conditions are capped at 4,000 characters.
- Include "or stop after N turns" to bound a goal.
- The loop stops if there is no tool use for several turns.
- These errors clear the goal: auth failure, exhausted credit, unresolvable context overflow, model unavailable.
- Transient errors retry 3 times; rate and usage limits pause the goal.
- Evaluation is deferred while subagents or background shells run.
- Check-ins come at 30 minutes, then back off to 1h and 2h, with at most 3 idle check-ins per goal.
- It works with `claude -p "/goal …"`; use `--output-format stream-json --verbose` to watch progress.
- Evaluator tokens are "typically negligible".
- It is unavailable when `disableAllHooks` is set or `allowManagedHooksOnly` is in force.

### Inferences
- **Recommended mapping for blitz:**
  - In-session `next --loop` → self-paced `/loop` or `/goal` inside a fresh session per plan.
  - Durable multi-day unattended runs → Routines (cloud; 1h minimum; fresh clone means tasks.json and progress.md must be committed to git each tick) or Desktop scheduled tasks (local, 1-minute minimum).
  - CronCreate → only for sub-week polling inside a live session.
- **Context growth in loop sessions.** A `/loop` that runs `next` in the *same* session accumulates context every tick, and each fire re-sends it all. **[estimate]** On Opus 5.5, a session at 300K tokens costs about $0.06 in cache reads per request and about $2.40 per uncached rebuild after a TTL lapse. Hourly ticks fall right on the 1h TTL boundary, and the per-task jitter of up to 30 minutes pushes some fires past it.
- **Keep ticks thin.** Each tick should be a thin dispatcher that spawns fresh subagents and returns summaries. Better still, use `claude -p` per tick or Routines, so each tick starts small, as in Ralph and Cursor.
- **Phrase /goal conditions as transcript-provable checks**, for example "`scripts/tasks.sh status` prints 0 open tasks and `bats hooks/tests/` exits 0". Add a turn cap.

### Gaps
- I did not fetch the Desktop scheduled tasks page, so its limits beyond the comparison table are unverified.
- I did not verify ScheduleWakeup's own parameter limits beyond the 1-minute to 1-hour range in the scheduled-tasks page.

---

## 6. Cost reports: real token spend, multi-agent and team multipliers, cost per task

### Takeaway
Measured anchors:
- Enterprise Claude Code averages about $13 per active developer-day ($150–250 per month), and 90% of users stay under $30 per active day.
- Agents use about 4x the tokens of chat; multi-agent systems about 15x.
- Agent teams use about 7x a standard session when teammates run in plan mode.

Token usage alone explained about 80% of performance variance in Anthropic's research eval. Spend buys quality, but coding parallelizes worse than research.

### Cited Findings
- About $13 per developer per active day and $150–250 per developer per month across enterprise deployments; under $30 per active day for 90% of users. — [Manage costs, undated](https://code.claude.com/docs/en/costs)
- "Agent teams use approximately 7x more tokens than standard sessions when teammates run in plan mode." Each teammate loads CLAUDE.md, MCP, and skills. Use Sonnet for teammates and shut them down when done. — [same](https://code.claude.com/docs/en/costs)
- Background usage: under $0.04 per session. Goal evaluation is "typically negligible". — [same](https://code.claude.com/docs/en/costs); [goal docs](https://code.claude.com/docs/en/goal)
- Hooks that filter output, for example grepping test failures, cut context "from tens of thousands of tokens to hundreds". — [Manage costs](https://code.claude.com/docs/en/costs)
- **Anthropic multi-agent research system (2025-06-13):**
  - Agents use about 4x the tokens of chat; multi-agent systems about 15x.
  - Token usage explained about 80% of BrowseComp variance (about 95% together with tool calls and model choice).
  - Opus 4 lead plus Sonnet 4 subagents beat single-agent Opus 4 by 90.2%.
  - Coding is a poorer fit: fewer parallelizable subtasks.
  - Subagents should write outputs to external storage and return references.

  — [Anthropic engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- Cursor's multi-week runs consumed "trillions of tokens" with no breakdown. — [Cursor](https://cursor.com/blog/scaling-agents)
- Huntley: $297 for a $50k contract (anecdote, unverified). — [ghuntley.com/ralph](https://ghuntley.com/ralph/)

### Inferences
- **[estimate] Tokens per fresh blitz dev subagent task**, assumed composition:
  - 30K stable prefix written once (1h)
  - about 40 requests at an average context of 60K, read from cache
  - about 60K uncached new input in total
  - about 25K output

  Cost on Sonnet 5.5: write $0.12 + reads 40×60K×$0.10/M = $0.24 + new input $0.12 + output $0.25 ≈ **$0.73 per task**.
  Cost on Opus 5.5 ≈ **$1.46**.

  Cache reads are a minority of the cost. Output and new input dominate. Context size growth is what changes the picture.
- **Measuring blitz's own costs.** Blitz's session records and activity feed could capture per-task `cache_read`, `cache_creation`, input, and output tokens from subagent metadata trailers or OTel. That would replace estimates like the one above with measurements.
- **Agent-team multiplier.** The 7x figure, combined with Cognition's and Anthropic's caveats on coding parallelism, supports blitz's preference for sequential fresh subagents over agent teams for implementation work.

### Gaps
- I found no public, itemized per-task cost study for Claude Code subagent pipelines on 5.5 models.
- The Anthropic 4x and 15x multipliers come from a 2025 research-task context and may not transfer to coding.

---

## URLs consulted
1. https://platform.claude.com/docs/en/build-with-claude/prompt-caching
2. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
3. https://research.trychroma.com/context-rot (redirect) → https://www.trychroma.com/research/context-rot
4. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
5. https://code.claude.com/docs/en/costs
6. https://code.claude.com/docs/en/scheduled-tasks
7. https://ghuntley.com/ralph/
8. https://code.claude.com/docs/en/prompt-caching
9. https://code.claude.com/docs/en/goal
10. https://code.claude.com/docs/en/model-config
11. https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/
12. https://www.anthropic.com/engineering/multi-agent-research-system
13. https://code.claude.com/docs/en/context-window
14. https://cognition.ai/blog/dont-build-multi-agents (redirect) → https://cognition.com/blog/dont-build-multi-agents
15. https://arxiv.org/abs/2502.05167
16. https://cursor.com/blog/scaling-agents
17. https://metr.org/time-horizons/
18. https://code.claude.com/docs/en/routines
19. https://claude.com/blog/lessons-from-building-claude-code-prompt-caching-is-everything (redirect) → https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/
20. https://code.claude.com/docs/en/skills
