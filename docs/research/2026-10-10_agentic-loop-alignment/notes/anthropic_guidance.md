# Anthropic's published guidance on agentic coding loops and multi-agent systems, compared with blitz

Scope note: these sources are primary Anthropic sources, which include the anthropic.com engineering blog, claude.com and claude.dev blog posts, the code.claude.com docs, and the platform.claude.com docs. Dates come from the pages themselves. The docs pages carry no publication date, so they are labelled "live docs, retrieved 2026-10-10". The blitz design choices compared here are the ones the assignment listed. I did not re-read the blitz source code.

## 1. What do the core engineering posts recommend, and where does blitz agree or diverge?

### Takeaway
Across 2024–2026, Anthropic's guidance follows one line. Start with the simplest system, separate exploration and planning from implementation, persist state in structured files plus git, and give the agent a runnable check. Every piece of scaffolding encodes an assumption about model weakness, and those assumptions go stale. Blitz's research → plan → build → check → ship loop, its JSON task file, its per-task verify commands and its git-backed state all follow this guidance closely. The main risk is that some blitz scaffolding may now be redundant on current models (Opus 4.6+/Opus 5).

### Cited Findings
- **Building effective agents (Dec 19, 2024).** "Workflows are systems where LLMs and tools are orchestrated through predefined code paths", whereas agents "dynamically direct their own processes and tool usage". The post recommends "finding the simplest solution possible, and only increasing complexity when needed". It names five patterns: prompt chaining with programmatic "gates", routing, parallelization (sectioning and voting), orchestrator-workers, and evaluator-optimizer. Evaluator-optimizer is useful when there are "clear evaluation criteria, and when iterative refinement provides measurable value". Its three principles are simplicity, transparent planning steps, and a carefully built agent-computer interface (ACI), including poka-yoke tool arguments. "Code solutions are verifiable through automated tests" — [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)
- **Claude Code best practices (live docs; the original blog post is Apr 18, 2025).** The recommended workflow is Explore → Plan → Implement → Commit, with plan mode used to separate exploration from execution. The docs add a caveat: "Plan mode is useful, but also adds overhead… If you could describe the diff in one sentence, skip the plan." — [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices); original post: [Claude Code: Best practices for agentic coding](https://www.anthropic.com/engineering/claude-code-best-practices)
- The same docs say specs work best when they are "self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step". They also recommend that "once the spec is complete, start a fresh session to execute it" — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Effective harnesses for long-running agents (Nov 26, 2025).** Uses an initializer agent and then coding agents that "make incremental progress, then leave structured updates". The feature list is kept as JSON because "the model is less likely to inappropriately change or overwrite JSON files compared to Markdown files". The guardrail is "It is unacceptable to remove or edit tests". Each session works on "only one feature at a time". The harness also uses `claude-progress.txt`, git commits with descriptive messages, an `init.sh` script, and a basic test at session start. The failure modes it fixed were declaring victory too early and marking features done without testing — [Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- The same post leaves an open question: "it's still unclear whether a single, general-purpose coding agent performs best across contexts". It suggests specialized "testing agent, a quality assurance agent, or a code cleanup agent" roles — [Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- **Prompting best practices (live docs).** For multi-window work: "Use a different prompt for the very first context window", "write tests in a structured format (for example, `tests.json`)", "Set up quality of life tools (`init.sh`)", "Use structured formats for state data", and "Use git for state tracking" — [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- **Harness design for long-running application development (Mar 24, 2026).** Describes a planner → generator → evaluator design with Playwright-based QA and "sprint contracts", where generator and evaluator agree on "done" before any code is written. The post states: "every component in a harness encodes an assumption about what the model can't do on its own." On Opus 4.6 the author removed sprints, moved the evaluator to a single pass at the end, and dropped context resets, but kept the planner because without it the generator under-scoped the work — [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- **Scaling Managed Agents (Apr 8, 2026).** Subtitle: "Harnesses encode assumptions that go stale as models improve." Context resets that fixed Sonnet 4.5's "context anxiety" had become "dead weight" on Opus 4.5. The session is a durable event log outside the context window, which the harness reads in slices — [Managed Agents](https://www.anthropic.com/engineering/managed-agents)
- **Claude Code quality postmortem (Apr 23, 2026).** Three harness-side changes degraded quality:
  - lowering default effort from high to medium ("This was the wrong tradeoff")
  - a bug that cleared thinking history on every turn
  - a system-prompt cap of "≤25 words" between tool calls and "≤100 words" for final responses

  The lessons were to run per-model evals and ablations for every system-prompt change, and to test stale and resumed sessions — [April 23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)

### Inferences
- **Agrees: JSON task DAG with per-task verify commands.** This is close to a direct implementation of the feature-list.json / tests.json pattern. Blitz goes further by enforcing writes through `scripts/tasks.sh` and a guard hook. That is the deterministic, hook-based version of Anthropic's "it is unacceptable to remove or edit tests" instruction, which is a strength.
- **Agrees: research → plan → build → check → ship.** This maps onto Explore → Plan → Implement → Commit and onto planner → generator → evaluator.
- **Agrees, with a caveat: fresh-context subagent per task.** The guidance recommends executing a spec in a fresh session and resetting context between features. The caveat is that the docs warn planning overhead is not worth it for one-sentence diffs. Blitz should check that trivial tasks can skip the full loop. Its CLAUDE.md "Clarification gate" already lets trivial tasks skip, which matches.
- **Divergence risk: frozen scaffolding.** The 2026 posts repeatedly say to stress-test and remove harness components as models improve. Blitz has no documented ablation process (for example, running with and without the critic, or without the 11-item spawn spec, on a fixed task set). The postmortem shows Anthropic itself regressed from untested prompt and harness changes.

### Gaps
- I found no Anthropic post giving a canonical number for how many fields a subagent spawn spec should have. The closest guidance is the four elements from the multi-agent research post (see section 2).

## 2. Subagents vs teams vs workflows: token cost and when parallelism helps or hurts

### Takeaway
Anthropic is consistently cautious about parallelism for coding. Multi-agent setups cost roughly 15× the tokens of chat and "excel at… heavy parallelization", but "most coding tasks involve fewer truly parallelizable tasks than research". Current docs recommend single sessions or subagents for sequential or dependent work, and explicitly warn newer models against over-delegating. Blitz's default (sequential single agent, opt-in parallel worktree waves capped at 4) matches this well.

### Cited Findings
- **Multi-agent research system (Jun 13, 2025).**
  - Agents use "about 4× more tokens than chat interactions" and multi-agent systems "about 15× more tokens than chats". Token usage explained about 80% of performance variance on BrowseComp.
  - An Opus 4 lead with Sonnet 4 subagents "outperformed single-agent Claude Opus 4 by 90.2%" on the internal research eval.
  - On fit: "most coding tasks involve fewer truly parallelizable tasks than research". Domains needing shared context or many inter-agent dependencies are "not a good fit for multi-agent systems today".

  — [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- **Same post, delegation spec.** "Each subagent needs an objective, an output format, guidance on the tools and sources to use, and clear task boundaries". Effort-scaling rules: a simple task gets 1 agent with 3–10 tool calls, a comparison gets 2–4 subagents, complex research gets 10+. Subagents write outputs to external storage and pass "lightweight references" back to avoid a "game of telephone". Execution is synchronous, which the authors note creates bottlenecks — [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- **Agent teams docs (live; experimental and off by default).** Teams "use significantly more tokens than a single session". "For sequential tasks, same-file edits, or work with many dependencies, a single session or subagents are more effective". Other guidance from the page:
  - "Start with 3-5 teammates"; "Three focused teammates often outperform five scattered ones"; "5-6 tasks per teammate".
  - "Two teammates editing the same file leads to overwrites. Break the work so each teammate owns a different set of files."
  - Use `TaskCompleted` and `TeammateIdle` hooks (exit code 2) as quality gates.
  - Subagents vs teams: subagents have "Lower" token cost and suit "Focused tasks where only the result matters".

  — [Agent teams](https://code.claude.com/docs/en/agent-teams)
- **Subagents docs (live).** Use a subagent "when a side task would flood your main conversation". Stay in the main conversation when the task needs "frequent back-and-forth" or when "Latency matters". `isolation: worktree` runs a subagent in a temporary git worktree. Nesting is allowed by default "up to three layers below the main conversation" (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). Forks share the parent's prompt cache, while fresh subagents use a "Separate cache" — [Subagents](https://code.claude.com/docs/en/sub-agents)
- **Prompting best practices (live).** Opus 4.6 "has a strong predilection for subagents and may spawn them in situations where a simpler, direct approach would suffice". Sample damping prompt: "Use subagents when tasks can run in parallel, require isolated context, or involve independent workstreams that don't need to share state. For simple tasks, sequential operations, single-file edits… work directly" — [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- **Prompting Claude Opus 5 (live).** "Delegation pays off on genuinely independent, sizeable tracks of work, but it multiplies cost and time when applied to small tasks… set deterministic caps." The deterministic caps are `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` and the SDK's `max_budget_usd`, all requiring Claude Code ≥2.1.217 — [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
- **Building a C compiler with parallel Claudes (Feb 5, 2026).**
  - Setup: 16 agents in Docker containers, a `while true` loop, task locks via files in `current_tasks/` plus git conflicts, and no orchestrator.
  - Where parallelism helped: many independent failing tests.
  - Where it hurt: on the Linux kernel, "Every agent would hit the same bug, fix that bug, and then overwrite each other's changes". The fix was a GCC oracle that split the work into independent pieces.
  - Cost: about 2,000 sessions, about 2B input tokens, just under $20,000.

  — [C compiler](https://www.anthropic.com/engineering/building-c-compiler)
- **Best practices (live).** `/batch` splits a change across "5 to 30 subagents", each in its own worktree. The fan-out pattern is to loop `claude -p` over a task list, testing on 2–3 items first — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Harness design (Mar 24, 2026).** Full harness: 6 hr and $200 vs 20 min and $9 for a solo run ("over 20x more expensive"). The V2 harness on Opus 4.6 took 3 hr 50 min and cost $124.70 — [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps)

### Inferences
- **Agrees strongly: sequential by default, opt-in parallel worktree waves capped at 4.** This matches the "coding is less parallelizable" finding, the 3–5 teammate guidance, file-ownership partitioning, and Opus 5's "deterministic caps" advice. A cap of 4 sits at the low end of Anthropic's 3–5 range, which is defensible for coding.
- **Mostly agrees: the 11-item spawn spec.** It is a superset of Anthropic's four elements (objective, output format, tools and sources, boundaries). The risk is prompt bloat. Context-engineering guidance favours the "minimal" prompt at the "right altitude" (section 3). The compiler post suggests one more element: a near-perfect verifier for each parallel unit.
- **Divergence to consider: blitz has no shared-bug detection.** The compiler post's failure mode (parallel agents converging on the same root cause) argues that a wave scheduler should split work so units fail independently, or serialize when several tasks fail on the same error.
- **Agrees: returning artifacts by file reference rather than inline.** The multi-agent post's "lightweight references" pattern matches this design.

### Gaps
- No Anthropic source gives a token multiplier specifically for subagent-per-task sequential coding loops, as opposed to parallel research. The 4× and 15× figures are from research workloads.
- The agent-teams docs reference a "costs" page ("agent team token costs") that I did not fetch.

## 3. Context engineering: compaction, memory, note-taking, just-in-time retrieval, tool search, caching

### Takeaway
Anthropic treats context as a finite "attention budget" subject to "context rot". It recommends a hybrid of up-front essentials plus just-in-time retrieval, and uses three long-horizon tools: compaction, structured notes, and subagents returning summaries of 1–2k tokens. Claude Code re-attaches only the first 5,000 tokens of each invoked skill after compaction, within a 25,000-token combined budget. This confirms the premise behind blitz's ~5k skill-body cap. Caching guidance says static content goes first, and nothing in the prefix (tools, model) should change mid-session.

### Cited Findings
- **Effective context engineering (Sep 29, 2025).**
  - Context is the "set of tokens included when sampling". Context rot means that as the window grows, "the model's ability to accurately recall information from that context decreases". LLMs have an "attention budget".
  - System prompts should sit at the "right altitude"; "bloated tool sets" are a common failure.
  - Just-in-time retrieval: keep "lightweight identifiers (file paths, stored queries, web links, etc.)". The hybrid example is Claude Code, where "CLAUDE.md files are naively dropped into context up front" while "glob and grep" retrieve just-in-time.
  - Compaction should preserve "architectural decisions, unresolved bugs, and implementation details". Tool-result clearing is "one of the safest lightest touch forms of compaction".
  - Note-taking: "maintaining a NOTES.md file", plus the memory tool. Sub-agents return a "condensed, distilled summary… (often 1,000-2,000 tokens)".
  - When to use each: compaction suits back-and-forth work, note-taking "excels for iterative development with clear milestones", and multi-agent suits parallel exploration.

  — [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- **Skills docs (live).** "Claude Code re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens… older skills can be dropped entirely". Also: once a skill loads, "its content stays in context across turns, so every line is a recurring token cost". Description and `when_to_use` are "truncated at 1,536 characters in the skill listing" — [Skills (Claude Code docs)](https://code.claude.com/docs/en/skills)
- **Best practices (live).** "Customize compaction behavior in CLAUDE.md with instructions like 'When compacting, always preserve the full list of modified files and any test commands'". It also advises: "If you've corrected Claude more than twice… run /clear", and "A clean session with a better prompt almost always outperforms a long session with accumulated corrections" — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Prompting best practices (live).** "Starting fresh versus compacting: …consider starting with a brand new context window rather than using compaction. Claude's latest models are extremely effective at discovering state from the local filesystem." Suggested restart prompt: "Review progress.txt, tests.json, and the git logs" — [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- **Harness design (Mar 24, 2026).** Context resets give a clean slate with a structured handoff, whereas compaction can leave "context anxiety" in place. Resets add orchestration overhead and latency, and later models made them unnecessary — [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- **Prompt caching (live docs).**
  - Claude Code orders requests as system prompt and tools, then project context (CLAUDE.md), then conversation. "The match is exact, so a change anywhere in the prefix recomputes everything after it."
  - Invalidators include switching models, changing effort (on most models), MCP or plugin tool changes, and compaction.
  - Plugin "skills, commands, agents, hooks… never invalidate the cache"; they are appended. Skill invocation injects "user messages", so the prefix stays intact.
  - Subagents have a separate cache with a 5-minute TTL by default, while forks share the parent's cache.
  - Tip: "Pick your model and effort level at the top of a session".

  — [How Claude Code uses prompt caching](https://code.claude.com/docs/en/prompt-caching)
- **Prompt caching is everything (Apr 30, 2026, Thariq Shihipar).** "Static content first, dynamic content last." The ordering is "surprisingly fragile": past breaks came from a timestamp in the system prompt, non-deterministic tool order, and changing tool parameters. Other lessons:
  - "Use messages for updates" through `<system-reminder>`.
  - "Never add or remove tools mid-session". Plan mode is implemented as tools, and tool search uses `defer_loading` stubs.
  - Compaction should be done via cache-safe forking.
  - "Monitor cache hit rate like uptime."

  — [Prompt caching is everything](https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/)
- **Writing effective tools for agents (Sep 11, 2025).** Use "pagination, range selection, filtering, and/or truncation with sensible default parameter values". "For Claude Code, we restrict tool responses to 25,000 tokens by default." Use namespacing, a `response_format` concise/detailed option, and actionable error messages — [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- **C compiler (Feb 5, 2026).** "Context window pollution": a harness should print "a few lines of output" and log details to files with greppable error markers. Claude has "time blindness", so the harness offered a `--fast` 1%/10% sampling mode — [C compiler](https://www.anthropic.com/engineering/building-c-compiler)

### Inferences
- **Agrees, with documentary support: ~5,000-token skill body cap.** The docs confirm exactly 5,000 tokens per skill re-attached after compaction, within a 25,000-token pool filled most-recent-first. Blitz should also budget for the pool. If a loop invokes more than five near-cap skills in one session, older skills can be dropped entirely after compaction.
- **Agrees: static-prefix-first prompts.** This matches Claude Code's own design. Blitz's CLAUDE.md instruction to "set model and effort once per session" mirrors the caching docs' tip directly. Skills with a non-inherited `model:` cause a model switch and a cache miss for that turn. Blitz's "`model: inherit` unless slash-only" rule is therefore well aligned.
- **Agrees: fresh-context subagent per task.** This follows the "fresh window + filesystem state" recommendation. One cost to note: fresh subagents do not share the parent cache, while forks do. For tasks that need much of the parent context, a fork may be cheaper.
- **Agrees: blitz's compaction preservation list in CLAUDE.md** (plan slug, task id, gate.json, modified files, test commands). This mirrors Anthropic's suggested compaction instruction almost verbatim.
- **Possible divergence: re-read state rather than summarize.** Anthropic suggests that for unattended `next --loop` ticks, a fresh window that re-reads `tasks.json` and git log is often better than relying on compaction. If each blitz tick already starts fresh, that matches.

### Gaps
- I did not find a public Anthropic number for the total skill-listing budget beyond the per-skill 1,536-character cap; the skills docs page was truncated near the end.
- The memory tool docs were not fetched.

## 4. Verification: evaluator agents, LLM-as-judge, tests, reward hacking and test special-casing

### Takeaway
Anthropic strongly endorses three things: a runnable check; separating the doer from the judge (a fresh-context reviewer, an evaluator tuned to be skeptical); and deterministic Stop-hook gating for unattended runs. It also warns that reviewers prompted to find gaps will always find some, and that Claude models can special-case tests. The newest guidance (Opus 5) says to remove explicit verification instructions, including "use a subagent to verify", because the model self-verifies and extra steps cause over-verification. This is the clearest tension with blitz's mandatory critic.

### Cited Findings
- **Best practices (live).**
  - "Give Claude a check it can run… It's the difference between a session you watch and one you walk away from."
  - Gating options: in one prompt, `/goal`, a deterministic Stop hook that "blocks the turn from ending until it passes", or "a verification subagent… so the agent doing the work isn't the one grading it".
  - "Have Claude show evidence rather than asserting success".

  — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Best practices (live), "Add an adversarial review step".** "Before treating a task as done, have a subagent review the diff in a fresh context". It also cautions: "A reviewer prompted to find gaps will usually report some, even when the work is sound… Chasing every finding leads to over-engineering… Tell the reviewer to flag only gaps that affect correctness or the stated requirements" — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Harness design (Mar 24, 2026).** "Separating the agent doing the work from the agent judging it proves to be a strong lever." The author also wrote: "tuning a standalone evaluator to be skeptical turns out to be far more tractable" than self-critique. An early QA agent would find real issues, then talk itself into approving. The evaluator "is worth the cost when the task sits beyond what the current model does reliably solo"; otherwise it adds overhead — [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- **Prompting Claude Opus 5 (live).** "If your prompt contains explicit verification instructions ('include a final verification step…', 'use a subagent to verify'), remove them: instructions like these cause over-verification on Claude Opus 5… The same applies to legacy harness scaffolding that adds separate verification steps." On review prompts: if a prompt says "only report high-severity issues"… the model may follow that literally; "ask it to report everything and filter in a separate pass instead". The page also says Opus 5 "coordinates teams of subagents well, with effective writer-verifier patterns" — [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
- **Code Review product (Mar 9, 2026).** "The agents look for bugs in parallel, verify bugs to filter out false positives, and rank bugs by severity." Depth scales with PR size. Results: substantive comments rose from 16% to 54% of PRs, and "less than 1% of findings are marked incorrect". Reviews average about 20 minutes and $15–25 — [Code Review](https://claude.com/blog/code-review). Secondary coverage agrees, and quotes Cat Wu saying the focus on logic bugs is meant to cut false positives — [The New Stack](https://thenewstack.io/anthropic-launches-a-multi-agent-code-review-tool-for-claude-code/)
- **Demystifying evals for AI agents (Jan 9, 2026).**
  - Grader types are code-based (fast, objective, brittle), model-based (flexible, non-deterministic, needs calibration) and human.
  - It's "often better to grade what the agent produced, not the path it took".
  - pass@k vs pass^k.
  - "You won't know if your graders are working well unless you read the transcripts".
  - Give LLM judges an "Unknown" option and grade each dimension separately.
  - The agent "shouldn't be able to easily 'cheat' the eval".
  - For coding, use tests plus static analysis plus transcript checks.
  - Start with "20-50 simple tasks drawn from real failures".

  — [Demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- **Multi-agent research system (Jun 13, 2025).** The LLM-as-judge was a single call scoring 0.0–1.0 plus pass/fail on a rubric (factual accuracy, citation accuracy, completeness, source quality, tool efficiency), which the authors found "most consistent" with human judgment — [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- **Prompting best practices (live), "Avoid focusing on passing tests and hardcoding".** "Claude can sometimes focus too heavily on making tests pass at the expense of more general solutions". The sample prompt includes: "Do not hard-code values or create solutions that only work for specific test inputs… Tests are there to verify correctness, not to define the solution… if any of the tests are incorrect, please inform me rather than working around them" — [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- **C compiler (Feb 5, 2026).** "It's important that the task verifier is nearly perfect, otherwise Claude will solve the wrong problem". CI was added so new commits couldn't break existing tests. The author warns that passing tests can be mistaken for finished work — [C compiler](https://www.anthropic.com/engineering/building-c-compiler)
- **System cards (from search-result summaries, not fetched in full).** Claude 3.7 Sonnet "occasionally resorts to special-casing to pass test cases in agentic coding environments like Claude Code" — [Claude 3.7 Sonnet System Card](https://www-cdn.anthropic.com/9ff93dfa8f445c932415d335c88852ef47f1201e.pdf). Sonnet 4.5 had "the lowest reward hacking tendencies" of recent models, though hard-coding "still occur[s]" — [Claude Sonnet 4.5 System Card](https://www-cdn.anthropic.com/963373e433e489a87a10c823c52a0a013e9172dd.pdf). Haiku 4.5 showed a "higher tendency to hardcode and special case tests" — [Claude Haiku 4.5 System Card](https://www-cdn.anthropic.com/7aad69bf12627d42234e01ee7c36305dc2f6a970.pdf). Related research: [Natural emergent misalignment from reward hacking in production RL](https://www-cdn.anthropic.com/daad4360a8bdc707f8b22e3e745796ba27e57fb3.pdf). Caveat: I saw only search snippets of these PDFs; exact rates were not verified.

### Inferences
- **Agrees: Stop-hook gate plus per-task verify commands enforced by hooks.** This is exactly the "deterministic gate" tier Anthropic recommends for unattended runs. A gate on JSON verify commands fits the guidance that the verifier should be "nearly perfect" and code-based where possible.
- **Agrees: adversarial read-only critic before PASS.** This matches the "fresh-context reviewer that sees only the diff" pattern, the skeptical evaluator, and Code Review's verify step.
- **Divergence with Opus 5-era guidance, in three parts:**
  - Anthropic now says explicit "use a subagent to verify" scaffolding can cause over-verification on Opus 5. It also says the evaluator is only worth it when the task is beyond what the model does reliably solo.
  - A *mandatory* critic on every task may therefore cost more than it is worth for small tasks. One option is to make the critic conditional on task size or risk, or to run it once per wave or plan, as the Opus 4.6 harness did with its end-of-run evaluator.
  - The critic prompt should limit findings to correctness and requirements gaps. If it is told "only high severity", Opus 5 may under-report, so the better pattern is to report everything and filter in a separate step.
- **Agrees: anti-reward-hacking.** Because blitz's guard hooks block edits to `tasks.json`, the agent cannot weaken its own verify commands. A critic that reads the diff can catch test special-casing that verify commands miss. An explicit "do not hard-code to tests; report incorrect tests" instruction in the build-agent prompt would match Anthropic's sample prompt.
- **Missing in blitz: an eval or ablation harness.** Anthropic's evals post and the postmortem both argue for a small eval set of 20–50 real-failure tasks, run whenever prompts or harness components change.

### Gaps
- Exact special-casing rates for current models (Opus 4.7, Opus 5, Sonnet 5) were not retrieved. The Opus 4.7 and Sonnet 5 system cards appeared in search but were not read.

## 5. Skills authoring and plugin design: descriptions, triggers, size

### Takeaway
Anthropic's skills guidance has four parts:
- **Size:** keep SKILL.md concise (under 500 lines), use progressive disclosure, and keep references one level deep.
- **Descriptions:** write them in the third person, saying what the skill does and when to use it, with the key use case first because the listing is truncated at 1,536 characters.
- **Scripts:** prefer bundled scripts for deterministic steps.
- **Testing:** build evaluations before writing extensive docs.

Blitz's `references/` progressive disclosure and its ~5k-token body cap match this guidance and are slightly stricter.

### Cited Findings
- **Agent Skills engineering post (Oct 16, 2025).** Progressive disclosure has three levels: metadata, then the SKILL.md body, then linked files. "The amount of context that can be bundled into a skill is effectively unbounded." "Because code is deterministic, this workflow is consistent and repeatable." The post recommends starting with evaluation, splitting files when SKILL.md "becomes unwieldy", monitoring how Claude uses the skill, and installing skills only from trusted sources — [Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- **Skill authoring best practices (live docs).**
  - "The context window is a public good."
  - "Default assumption: Claude is already very smart."
  - Match degrees of freedom to how fragile the task is.
  - `description` max 1,024 characters, "Always write in third person", and say both what the skill does and when to use it; Claude chooses among "potentially 100+ available Skills".
  - "Keep SKILL.md body under 500 lines"; "Keep references one level deep"; add a table of contents to reference files over 100 lines.
  - Use checklists, validator feedback loops ("Run validator → fix errors → repeat") and plan-validate-execute with intermediate JSON.
  - "Create evaluations BEFORE writing extensive documentation"; "At least three evaluations"; test with Haiku, Sonnet and Opus.

  — [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- **Claude Code skills docs (live).**
  - "Keep SKILL.md under 500 lines."
  - The combined description and `when_to_use` are truncated at 1,536 characters, so "put the key use case first".
  - `disable-model-invocation: true` is for side-effect workflows ("You don't want Claude deciding to deploy").
  - `context: fork` runs a skill in a subagent and "only makes sense for skills with explicit instructions".
  - The 5,000/25,000-token re-attach rule (section 3).

  — [Skills (Claude Code docs)](https://code.claude.com/docs/en/skills)
- **Best practices (live).** CLAUDE.md should be short: "Would removing this cause Claude to make mistakes?" "Bloated CLAUDE.md files cause Claude to ignore your actual instructions". Use skills for sometimes-relevant knowledge, and hooks for "actions that must happen every time with zero exceptions" because CLAUDE.md is "advisory" — [Best practices](https://code.claude.com/docs/en/best-practices)
- **Subagents docs (live).** Agent descriptions drive automatic delegation ("use proactively"), and "Those descriptions take up context, so keep them short." Restrict tools for read-only reviewers (for example `tools: Read, Grep, Glob`) — [Subagents](https://code.claude.com/docs/en/sub-agents)
- **Prompt caching docs (live).** A plugin's skills, agents and hooks are appended and never invalidate the cache. A plugin's MCP servers follow MCP tool rules, which can invalidate the cache unless tool search defers them — [Prompt caching](https://code.claude.com/docs/en/prompt-caching)

### Inferences
- **Agrees: `references/` progressive disclosure.** This is the canonical pattern. Blitz should check that references are one level deep and that long reference files have a table of contents.
- **Agrees, tighter than required: ~5k-token body cap.** 500 lines is often more than 5k tokens, so blitz's cap is stricter than Anthropic's line guidance. It is justified by the documented compaction re-attach limit, so it is a well-grounded choice.
- **Agrees: hooks for invariants and validators for frontmatter, links, catalog and version sync.** These follow "hooks are deterministic" and the "feedback loops / validator scripts" guidance.
- **Possible gap: skill evaluations.** Anthropic recommends at least three evaluations per skill and testing across Haiku, Sonnet and Opus. Blitz has bats tests for hooks, but there is no evidence here of behavioural evals for skill triggering or output.
- **Agrees: `disable-model-invocation` for side-effecting skills.** Ship and commit steps fit this. The blitz convention "`model: inherit` unless slash-only" is consistent with this and with caching guidance.

### Gaps
- No Anthropic source gives guidance on plugin-level design beyond components (skills, agents, hooks, MCP), for example how many skills a plugin should expose. The skill-listing truncation and description cost are the only constraints I found.

## 6. Unattended loops (`next --loop`) and autonomy

### Takeaway
Anthropic documents and uses unattended loops: the `while true` harness, `claude -p` fan-out, `/goal`, Stop hooks and auto mode. It pairs them with deterministic gates, sandboxing or containers, and periodic human steering. Blitz's `next --loop` ticks are consistent with this as long as each tick has a hard gate and an exit condition.

### Cited Findings
- The C compiler harness: "`while true`… when one session finishes, the next starts immediately", run in a container — [C compiler](https://www.anthropic.com/engineering/building-c-compiler)
- "The `/goal` and Stop hook versions are what let an unattended run finish correctly without you". The docs list `--permission-mode dontAsk` for batch loops and auto mode, which uses a classifier, for "uninterrupted execution". They add: "The longer Claude works unattended, the more an independent check matters" — [Best practices](https://code.claude.com/docs/en/best-practices)
- Agent teams: "Letting a team run unattended for too long increases the risk of wasted effort" — [Agent teams](https://code.claude.com/docs/en/agent-teams)
- Opus 5 "performs best when given the complete task specification up front and left to run" — [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)

### Inferences
- **Agrees: `next --loop` with Stop-hook gates and a JSON DAG.** This closely mirrors Anthropic's own unattended pattern (loop, task-lock files, near-perfect verifiers). The open question for the review is whether blitz has a stall or no-progress detector. Anthropic's `/goal` docs mention that Claude Code "eventually stops the run" when Claude stalls, and the Stop-hook docs cap consecutive blocks.

### Gaps
- The auto-mode post (Mar 25, 2026) and the sandboxing post (Oct 20, 2025) were listed on the engineering index but not fetched.

---

### All URLs consulted
1. https://www.anthropic.com/engineering (index; post dates)
2. https://www.anthropic.com/engineering/building-effective-agents (Dec 19, 2024)
3. https://www.anthropic.com/engineering/multi-agent-research-system (Jun 13, 2025)
4. https://www.anthropic.com/engineering/claude-code-best-practices (Apr 18, 2025; cited via index, current content from the docs version)
5. https://www.anthropic.com/engineering/writing-tools-for-agents (Sep 11, 2025)
6. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (Sep 29, 2025)
7. https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills (Oct 16, 2025)
8. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents (Nov 26, 2025)
9. https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents (Jan 9, 2026)
10. https://www.anthropic.com/engineering/building-c-compiler (Feb 5, 2026)
11. https://www.anthropic.com/engineering/harness-design-long-running-apps (Mar 24, 2026)
12. https://www.anthropic.com/engineering/managed-agents (Apr 8, 2026)
13. https://www.anthropic.com/engineering/april-23-postmortem (Apr 23, 2026)
14. https://claude.com/blog/code-review (Mar 9, 2026)
15. https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/ (Apr 30, 2026; redirected from claude.com/blog/...)
16. https://code.claude.com/docs/en/best-practices (live docs, retrieved 2026-10-10)
17. https://code.claude.com/docs/en/skills (live docs)
18. https://code.claude.com/docs/en/sub-agents (live docs)
19. https://code.claude.com/docs/en/agent-teams (live docs)
20. https://code.claude.com/docs/en/prompt-caching (live docs)
21. https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (live docs)
22. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices (live docs)
23. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5 (live docs)
24. https://thenewstack.io/anthropic-launches-a-multi-agent-code-review-tool-for-claude-code/ (secondary, search result only)
25. https://www-cdn.anthropic.com/9ff93dfa8f445c932415d335c88852ef47f1201e.pdf (Claude 3.7 Sonnet system card; search snippet only)
26. https://www-cdn.anthropic.com/963373e433e489a87a10c823c52a0a013e9172dd.pdf (Claude Sonnet 4.5 system card, Sep 2025; search snippet only)
27. https://www-cdn.anthropic.com/7aad69bf12627d42234e01ee7c36305dc2f6a970.pdf (Claude Haiku 4.5 system card, Oct 2025; search snippet only)
28. https://www-cdn.anthropic.com/daad4360a8bdc707f8b22e3e745796ba27e57fb3.pdf (Natural emergent misalignment from reward hacking; search snippet only)
