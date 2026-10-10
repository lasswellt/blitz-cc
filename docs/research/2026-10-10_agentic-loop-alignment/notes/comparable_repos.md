# Comparable open-source projects to blitz (Claude Code plugins, skill packs, subagent collections, agentic dev-loop frameworks), as of 2026-10-10

Method note: star and fork counts and `updated_at` timestamps come from one GitHub repository-search API call made on 2026-10-10. In the GitHub API, `updated_at` changes on any repository update, starring included, so it shows the repo is alive but does not give the last commit date. Every repo listed showed `updated_at` on 2026-10-09 or 2026-10-10. The `gh` CLI was blocked in this session for repos outside blitz, so last-commit dates could not be pulled separately. Architecture details come from each project's README, fetched raw from `main`. The WebFetch summarizer sometimes reported that a README omitted a detail. Such omissions are listed under Gaps and were not filled in from memory.

## Q1. Which projects are comparable, and what does each do (architecture, adoption)?

### Takeaway
At least 20 active projects overlap with blitz. They fall into five families:
- **Methodology skill packs:** superpowers, andrej-karpathy-skills, SuperClaude.
- **Spec-driven development (SDD) frameworks:** spec-kit, OpenSpec, BMAD, GSD, Kiro.
- **Orchestration and swarm harnesses:** oh-my-claudecode, ruflo/claude-flow, Archon.
- **Task-state tools and unattended loops:** Task Master, Ralph, the official ralph-wiggum plugin.
- **Parallel session managers:** claude-squad, ccmanager, Crystal/Nimbalyst.

Adoption is extremely skewed. superpowers has about 297k stars; blitz has 1.

### Cited Findings
**Adoption snapshot, 2026-10-10 (stars / forks / created)** — all from [GitHub search API results](https://github.com/search?q=superpowers):
- obra/superpowers: 297,104 / 26,525 / created 2025-10-09 — [repo](https://github.com/obra/superpowers)
- multica-ai/andrej-karpathy-skills: 217,926 / 21,966 / 2026-01-27 — [repo](https://github.com/multica-ai/andrej-karpathy-skills)
- anthropics/skills: 180,278 / 21,333 / 2025-09-22; 1,396 open issues — [repo](https://github.com/anthropics/skills)
- anthropics/claude-code: 149,995 / 26,044; 14,654 open issues — [repo](https://github.com/anthropics/claude-code)
- github/spec-kit: 140,674 / 12,597 / 2025-08-21 — [repo](https://github.com/github/spec-kit)
- openai/codex: 128,509 / 20,169 (Rust); 22,051 open issues — [repo](https://github.com/openai/codex)
- ruvnet/ruflo (formerly claude-flow): 74,243 / 8,827; 1,040 open issues — [repo](https://github.com/ruvnet/ruflo)
- Fission-AI/OpenSpec: 71,536 / 4,882 — [repo](https://github.com/Fission-AI/OpenSpec)
- gsd-build/get-shit-done: 64,327 / 5,428. **Archived**; development moved to open-gsd/gsd-core, and no reason is given — [repo](https://github.com/gsd-build/get-shit-done)
- hesreallyhim/awesome-claude-code: 55,355 — [repo](https://github.com/hesreallyhim/awesome-claude-code)
- bmad-code-org/BMAD-METHOD: 54,007 / 6,075 — [repo](https://github.com/bmad-code-org/BMAD-METHOD)
- Aider-AI/aider: 49,457 — [repo](https://github.com/Aider-AI/aider)
- wshobson/agents: 40,320 / 4,294 — [repo](https://github.com/wshobson/agents)
- Yeachan-Heo/oh-my-claudecode: 39,761 / 3,561 / 2026-01-09 — [repo](https://github.com/Yeachan-Heo/oh-my-claudecode)
- anthropics/claude-plugins-official: 37,612 / 4,236 / 2025-11-20 — [repo](https://github.com/anthropics/claude-plugins-official)
- eyaltoledano/claude-task-master: 28,189 / 2,615 — [repo](https://github.com/eyaltoledano/claude-task-master)
- SuperClaude-Org/SuperClaude_Framework: 23,907 — [repo](https://github.com/SuperClaude-Org/SuperClaude_Framework)
- coleam00/Archon ("harness builder… deterministic and repeatable", YAML workflow engine): 23,657 — [repo](https://github.com/coleam00/Archon)
- humanlayer/humanlayer: 11,684 — [repo](https://github.com/humanlayer/humanlayer)
- frankbria/ralph-claude-code: 9,675 — [repo](https://github.com/frankbria/ralph-claude-code)
- smtg-ai/claude-squad ("Manage multiple AI terminal agents like Claude Code, Codex, OpenCode, and Amp", Go): 8,588 — [repo](https://github.com/smtg-ai/claude-squad)
- stravu/crystal: 3,126. Description reads "(Crystal is now Nimbalyst) Run multiple Codex and Claude Code AI sessions in parallel git worktrees" — [repo](https://github.com/stravu/crystal)
- kbwo/ccmanager (session manager for Claude Code, Gemini CLI, Codex, Cursor Agent, Copilot CLI, Cline, OpenCode, Kimi): 1,261 — [repo](https://github.com/kbwo/ccmanager)
- lasswellt/blitz-cc: 1 star, pushed 2026-10-10 (from the gh API, which works for this repo) — [repo](https://github.com/lasswellt/blitz-cc)

**obra/superpowers**
- Skills by area:
  - Testing: test-driven-development.
  - Debugging: systematic-debugging, verification-before-completion, diagnosing-superpowers.
  - Collaboration: brainstorming, writing-plans, executing-plans, dispatching-parallel-agents, requesting-code-review, receiving-code-review, using-git-worktrees, finishing-a-development-branch, subagent-driven-development.
  - Meta: writing-skills, using-superpowers (the bootstrap).
  - [README](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
- Workflow:
  1. Brainstorm.
  2. Create a worktree and verify a clean test baseline.
  3. Write a plan of 2–5 minute tasks, each with exact file paths, complete code and verification steps.
  4. Run subagent-driven development: a fresh subagent per task, with review after each task.
  5. Enforce TDD; code written before its tests is deleted.
  6. Run code review between tasks; critical issues block progress.
  7. Finish the branch: merge, PR, keep or discard, and clean up the worktree.
  - [README](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
- The bootstrap is injected through a SessionStart hook, and supported harnesses include Claude Code, Codex, Cursor, Gemini and Pi. The README describes no hard technical gate beyond prompt-level instructions and hooks ("Mandatory workflows, not suggestions") — [README](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
- v6.0.0 shipped 2026-06-16. It collapsed the two per-task reviewers (spec compliance and code quality) into one task-reviewer prompt. Diffs now pass between controller and reviewer as files, and reviewers run read-only. The release notes claim the same quality at about 2x speed and about 50% fewer tokens — [ai-tldr.dev v6 summary](https://ai-tldr.dev/releases/obra-superpowers-v6/); [Towards AI](https://pub.towardsai.net/superpowers-6-0-unpacked-faster-ai-code-review-and-fewer-tokens-5ab40a6c564c)

**anthropics official plugins** (in anthropics/claude-code/plugins, plus the claude-plugins-official marketplace)
- code-review: five parallel Sonnet agents (CLAUDE.md compliance, bugs, history, PR history, code comments) with **confidence scoring to filter false positives**.
- feature-dev: a 7-phase workflow with code-explorer, code-architect and code-reviewer agents.
- pr-review-toolkit: six agents, including silent-failure-hunter.
- ralph-wiggum: `/ralph-loop`, built on a Stop hook.
- hookify: generates hooks from conversation analysis.
- security-guidance: a PreToolUse warning hook covering nine patterns.
- plugin-dev: plugin-validator and skill-reviewer agents.
- [plugins README](https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/README.md)
- Marketplace structure: `/plugins` for Anthropic's own plugins, `/external_plugins` for third parties; submission goes through a form with "quality and security standards." Anthropic warns that it cannot verify what plugins contain — [marketplace README](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/README.md)

**oh-my-claudecode (OMC)**
- Team mode is a staged pipeline: team-plan → team-prd → team-exec → team-verify → team-fix, with fix looping back.
- Other modes: autopilot; Execute/Verify loops (tests, build, lint, typecheck until passing); Ralph persistence; Ralplan consensus planning; deep-interview, which scores clarity across weighted dimensions before execution.
- 19 agents with tier variants.
- tmux workers can run claude, codex, gemini, antigravity, grok or cursor-agent.
- `/ask <provider>` saves a markdown artifact per advisor run.
- Smart routing sends simple work to Haiku and complex work to Opus; it claims 30–50% token savings, with no method given.
- State lives in `.omc/`: sessions/*.json and agent-replay-*.jsonl.
- Visibility: a statusline HUD, stop callbacks to Telegram, Discord or Slack, and `omc session friction report`.
- The docs advise "one primary loop authority per session."
- [README](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)

**ruflo / claude-flow**
- An MCP-server swarm harness with "adaptive memory, self-learning, federation, vector RAG" — [repo description](https://github.com/ruvnet/ruflo)
- The project's own May self-audit marked about 195 of about 240 tools as real code. Agent execution, hive-mind transport, workflow runtime and neural prediction were marked as stubs, and the hive-mind is single-process per ADR-095 — [AlphaSignal](https://alphasignalai.substack.com/p/how-ruflo-turns-claude-code-into)

**Task Master AI**
- Parses a PRD into tasks (`.taskmaster/docs/prd.txt`).
- Tools include expand_task, add_subtask, analyze_project_complexity and complexity_report.
- Three model roles: main, research (e.g. Perplexity) and fallback.
- Tags support workstreams.
- The MCP server has selectable tool tiers, with token costs per the README:

  | Tier | Tools | Tokens |
  |---|---|---|
  | all | 36 | ~21k |
  | standard | 15 | ~10k |
  | core | 7 | ~5k |

- Can use `claude-code/opus` without an API key.
- [README](https://raw.githubusercontent.com/eyaltoledano/claude-task-master/main/README.md)

**spec-kit**
- Commands: `/speckit-constitution`, `-specify`, `-plan`, `-tasks`, `-implement`, and `-converge`, which repeats with implement until it reports "Converged."
- Optional extensions: `bug` (assess, fix, test, with a verdict of verified, partial or failed) and `assess` (go, needs-clarification or kill).
- Extension, preset and bundle system.
- [README](https://raw.githubusercontent.com/github/spec-kit/main/README.md)

**BMAD-METHOD**
- Delivery loop: Clarify → Plan → Build and verify → Learn and adjust; "Small changes go straight to build."
- Modules include **BMad Loop**, which "builds, verifies, and retros a whole epic unattended", plus Test Architect and BMad Builder.
- Installs through the Claude Code and Codex plugin marketplaces.
- [README](https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/README.md)

**wshobson/agents**
- 94 plugins, 202 agents, 184 skills and 105 commands.
- One Markdown source feeds 7 harnesses: Claude Code, Codex, Cursor, OpenCode, Antigravity, Copilot and Pi.
- Model aliases (opus, sonnet, haiku, inherit) are mapped per harness.
- plugin-eval scores skills statically; the LLM-judge layer is "experimental… not validated against human labels."
- [README](https://raw.githubusercontent.com/wshobson/agents/main/README.md)

**frankbria/ralph-claude-code**
- A bash loop over `.ralph/PROMPT.md`, `fix_plan.md` (a checkbox list) and `AGENT.md` (build and test commands).
- **Dual-condition exit:** at least 2 heuristic completion indicators **and** an explicit `EXIT_SIGNAL: true`.
- **Circuit breaker:** opens after 3 loops with no file changes or commits, 5 loops with the same error, or an output decline above 70%. It then moves OPEN → HALF_OPEN → CLOSED after a 30-minute cooldown.
- Limits: `MAX_CALLS_PER_HOUR`=100, plus an optional `MAX_TOKENS_PER_HOUR`.
- Sessions resume with `--resume <id>` and expire after 24h.
- Monitoring: a tmux dashboard plus status.json.
- Runs in Docker or E2B sandboxes.
- 784 BATS tests.
- [README](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md)

**andrej-karpathy-skills**
- A single CLAUDE.md (also shipped as a plugin) with four principles: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution — [README](https://raw.githubusercontent.com/multica-ai/andrej-karpathy-skills/main/README.md). blitz's CLAUDE.md already adapts it.

**humanlayer**
- The public repo now says "the code here is pretty much all deprecated" and points to a rebuild at humanlayer.com — [README](https://raw.githubusercontent.com/humanlayer/humanlayer/main/README.md)

**Kiro, spec-kit and Tessl**, as compared by Thoughtworks
- Kiro runs Requirements (GIVEN/WHEN/THEN) → Design → Tasks, with "steering" memory files (product.md, structure.md, tech.md).
- Tessl maps specs 1:1 to code files and marks generated files "GENERATED FROM SPEC - DO NOT EDIT."
- [Böckeler, martinfowler.com, 2025-10-15](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)

### Inferences
- blitz's closest structural peers are **superpowers**, **oh-my-claudecode** and **Ralph**. Each combines a plan/execute/verify loop, subagents and hooks. GSD and BMAD's "BMad Loop" are the closest in "loop over an epic unattended."
- The parallel session managers (claude-squad, ccmanager, Crystal) complement blitz rather than compete with it: they manage several sessions in worktrees from outside, while blitz runs inside one session.
- Adoption is not proof of effectiveness. Several of the top projects (karpathy-skills, superpowers) are prompt-level and publish no benchmarks.

### Gaps
- Last-commit dates could not be retrieved; only `updated_at` was available, because gh was blocked for non-blitz repos.
- Not retrieved: details for OpenHands (its repo did not match All-Hands-AI/OpenHands; it may have been renamed), Aider's architect/editor mode, Codex AGENTS.md and cloud tasks, SuperClaude internals, OpenSpec internals, Archon internals, the claude-squad and ccmanager feature sets beyond their repo descriptions, steveyegge/beads (not matched by the search), and GSD Core's current architecture (the archived README only redirects).
- HumanLayer's research/plan/implement workflow and "thoughts/" convention could not be confirmed from a current primary source.

## Q2. How do they handle decomposition and state, gates, parallelism, critics, memory, hooks, cost, unattended runs, and visibility?

### Takeaway
Most peers keep state in markdown (plans, checkboxes, PRD and spec files) and enforce gates mostly through prompts. Exceptions:
- Task Master and blitz use structured JSON tasks.
- Ralph and OMC have the strongest runtime loop controls: circuit breakers, rate and token budgets, HUDs and notifications.
- Anthropic's code-review plugin is the clearest example of a confidence-filtered critic.

blitz's hook-enforced JSON DAG with per-task verify commands is stricter than nearly all of them.

### Cited Findings
- **Decomposition and state:**
  - superpowers: plans of 2–5 minute tasks, each with code and verification steps, in markdown — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
  - Task Master: a PRD becomes tasks and subtasks, with complexity analysis and tag workstreams — [Task Master](https://raw.githubusercontent.com/eyaltoledano/claude-task-master/main/README.md)
  - Ralph: `fix_plan.md` checkboxes, where "Optional/Future" sections do not block completion — [Ralph](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md)
  - spec-kit: about 8 markdown files per spec, on a per-spec branch — [Böckeler](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- **Verification gates:**
  - superpowers: TDD red-green, verification-before-completion, and critical review findings that block. All are prompt-level — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
  - OMC: Verify mode loops on tests, build, lint and typecheck "until goals pass" — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
  - spec-kit: `/speckit-converge` repeats until "Converged" — [spec-kit](https://raw.githubusercontent.com/github/spec-kit/main/README.md)
  - official ralph-wiggum: a Stop hook intercepts exit and checks a completion promise or max-iterations — [plugins README](https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/README.md); [kartit.net](https://www.kartit.net/blog/ralph-wiggum-technique)
- **Parallelism and worktrees:**
  - superpowers: using-git-worktrees and dispatching-parallel-agents — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
  - OMC: tmux multi-CLI workers; its native team worktree mode sits behind an opt-in gate. Its `.omc/` state is deleted along with a worktree unless OMC_STATE_DIR is set — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
  - Crystal/Nimbalyst: parallel worktree sessions in a desktop app — [crystal](https://github.com/stravu/crystal)
- **Critics and reviewers:**
  - Official code-review: five parallel agents plus confidence scoring — [plugins README](https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/README.md)
  - superpowers v6: one read-only task reviewer per task, which "cannot be told to suppress findings" — [ai-tldr.dev](https://ai-tldr.dev/releases/obra-superpowers-v6/)
  - OMC: critic and security-reviewer roles, with the lead keeping final approval, plus cross-provider `/ask` advisors — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
- **Memory and learning:**
  - Kiro: steering files — [Böckeler](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
  - ruflo: claims adaptive memory and self-learning, but the self-audit marks neural prediction as a stub — [AlphaSignal](https://alphasignalai.substack.com/p/how-ruflo-turns-claude-code-into)
  - BMAD: a "Learn and adjust" retro step — [BMAD](https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/README.md)
  - wshobson: optional Pensyve memory, whose cloud service closed 2026-10-01 — [wshobson](https://raw.githubusercontent.com/wshobson/agents/main/README.md)
  - superpowers: no memory mechanism — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
- **Hooks:**
  - superpowers: SessionStart bootstrap. On harnesses without a post-compaction hook (Hermes), "long sessions that compact can lose the bootstrap"; Pi re-injects after compaction — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
  - OMC: hooks on session-start, stop, keyword-detector, ask-user-question, pre-tool-use and post-tool-use — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
  - hookify: generates guard hooks from conversation analysis — [plugins README](https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/README.md)
- **Cost control:**
  - Ralph: calls-per-hour and tokens-per-hour budgets — [Ralph](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md)
  - OMC: Haiku/Opus routing and model presets — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
  - Task Master: MCP tool-tier sizing (21k / 10k / 5k tokens) — [Task Master](https://raw.githubusercontent.com/eyaltoledano/claude-task-master/main/README.md)
  - superpowers v6: passes diffs as files instead of inline — [ai-tldr.dev](https://ai-tldr.dev/releases/obra-superpowers-v6/)
- **Background and unattended runs:**
  - Ralph: auto-waits through the 5-hour limit, has `--auto-reset-circuit`, and runs in Docker or E2B sandboxes — [Ralph](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md)
  - BMad Loop: runs whole epics unattended — [BMAD](https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/README.md)
  - superpowers: "may work for hours without deviating from the plan" — [superpowers](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
- **Visibility:**
  - Ralph: tmux dashboard, status.json and ralph-stats — [Ralph](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md)
  - OMC: statusline HUD, replay JSONL, friction report, and Telegram/Discord/Slack callbacks — [OMC](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
  - Crystal: a desktop GUI — [crystal](https://github.com/stravu/crystal)

### Inferences
**Ideas blitz appears to lack** (to be checked against the blitz source by the synthesizer):
1. A Ralph-style **no-progress circuit breaker** that opens on no diff or commit, a repeated identical error, or output decline, with a half-open state.
2. **Dual-condition completion**: a heuristic plus an explicit signal.
3. **Per-hour call and token budgets** for unattended runs.
4. **Confidence-scored, multi-lens parallel review** that filters false positives (Anthropic code-review).
5. **Hookify-style** generation of guard hooks from observed mistakes.
6. **Clarity scoring before execution** (OMC deep-interview).
7. Push **notifications** and a **statusline HUD**.
8. **Model-tier routing** per task.
9. **One-source, multi-harness distribution** (superpowers, wshobson, BMAD install into Codex and Cursor).
10. A **skill-behavior eval harness**: superpowers-evals drill and wshobson plugin-eval.
11. Spec-kit's **converge** loop and explicit **kill/go assessment**.
12. **Re-injecting invariants after compaction**, as superpowers does on Pi. blitz injects at SubagentStart and has a PreCompact handoff.

**Ideas blitz has that most peers lack:**
- **Hook-enforced write guard** on tasks.json. Task Master has JSON tasks but, per its README, writes them through MCP tools with no deny-hook.
- **Per-task verify commands in a DAG.** superpowers has prose verification steps.
- A **Stop gate** tied to gate.json.
- **SubagentStart invariant injection.**
- **Anti-shortcut guards.**
- A **diagnostic ratchet.** No peer documents a monotonic quality ratchet.
- A **cross-model critic.** OMC is the only peer found with comparable Codex, Gemini, Antigravity and Grok advisors.

### Gaps
- OMC's hook internals (docs/HOOKS.md) were not read.
- Task Master's tasks.json schema (dependencies, testStrategy) is documented in separate docs that were not fetched.
- I could not confirm whether any peer has a ratchet-like regression gate.

## Q3. Which ideas have evidence of working, and what failure modes are documented?

### Takeaway
I found almost no independent benchmark evidence for any framework. The evidence that exists is vendor-reported token and speed savings (superpowers v6, OMC routing), test counts (Ralph), and qualitative expert reviews. The documented failure modes are consistent across projects:
- Process overhead on small tasks.
- Agents ignoring specs or skills.
- Skills lost after compaction.
- Overclaimed features (ruflo).
- Security exposure from network-facing MCP bridges.
- Loops that get stuck or exit early.

### Cited Findings
- **METR RCT, 2025:** experienced developers were 19% slower with AI while believing they were 20% faster. METR's February 2026 report says newer models cause "material acceleration," but calls its RCT method now unreliable because of selection effects and developers running agents in parallel — [METR Feb 2026 report](https://metr.org/february-2026-progress-report.pdf); [scienceblog summary](https://scienceblog.com/t-a-randomized-trial-by-metr-found-that-experienced-developers-completed-real-coding-tasks-19-slower-when-allowed-to-use-ai-tools-yet-afterwards-they-estimated-on-average-that-ai-had-made-them-20-fast/)
- **SDD failure modes** (Böckeler, Thoughtworks):
  - Kiro turned a small bug into 4 user stories with 16 acceptance criteria.
  - spec-kit was overkill for a 3–5 point feature, and its repetitive markdown was tedious to review.
  - The agent ignored notes about existing classes and duplicated them.
  - The agent over-applied constitution articles.
  - "False sense of control": many files and checklists did not ensure the agent complied.
  - Tessl regeneration was non-deterministic.
  - She calls this possible "Verschlimmbesserung."
  - [martinfowler.com](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- **superpowers:**
  - Its own README admits skills may fire when they should not or fail to fire, and the agent may ignore its plan, repeat work or consume excess tokens. The project ships a diagnosing-superpowers skill for this — [README](https://raw.githubusercontent.com/obra/superpowers/main/README.md)
  - Savings claims (~50% tokens, ~2x speed in v6; 50% tokens and 60% wall-clock in v6.1.1) come only from release notes relayed by secondary sites. I found no independent benchmark. One critical piece notes heavy process only pays off on complex work, and that over-compressed review context can lead the agent to hallucinate the spec — [ai-tldr.dev](https://ai-tldr.dev/releases/obra-superpowers-v6/); [dailyaiworld](https://www.dailyaiworld.com/blogs/superpowers-obra-agentic-skills-framework-2026)
- **ruflo:**
  - The maintainer removed an unverified "Flash Attention 2.49x–7.47x" claim after audits — [AugmentCode](https://www.augmentcode.com/learn/ruflo-v3-32-22-meta-harness-claude-code)
  - An 84.8% SWE-bench figure circulates without a verifiable source — [pasqualepillitteri.it](https://pasqualepillitteri.it/news/773/claude-flow-ruflo-guida-orchestrazione-multi-agent)
  - CVE-2026-59726 (CVSS 10): remote code execution through an MCP bridge that was unauthenticated and network-exposed by default — [Dark Reading](https://darkreading.com/cyber-risk/patch-resistant-rufroot-flaw-malicious-ai-agent-swarms)
  - A user reports the generated CLAUDE.md was mostly boilerplate and swarm features went unused unless asked for explicitly — [issue #1476](https://github.com/ruvnet/ruflo/issues/1476)
- **OMC:**
  - The 30–50% token savings claim comes with no method.
  - Its "geobench" measures how often LLMs cite the project, not task performance.
  - Worktree deletion destroys `.omc/` state.
  - [OMC README](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md)
- **Ralph** — [Ralph README](https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md):
  - Stuck loops come from unclear or conflicting tasks in fix_plan.
  - Premature exit is mitigated by the EXIT_SIGNAL gate.
  - Exit code 124 was once misread as an API limit (fixed in v0.11.5).
  - Commits made in E2B are not synced back.
  - Changing .ralphrc to be parsed as data broke shell-syntax configs.
- **Official ralph-wiggum:** critics say the Stop-hook design hides loop mechanics in a markdown state file, depends on permissions and breaks easily. Some see it as a softening of Huntley's original bash loop — [DreamHost](https://www.dreamhost.com/blog/de/die-ralph-wiggum-schleife-von-den-ersten-prinzipien-de/); [VentureBeat](https://venturebeat.com/ai/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now). Several write-ups say the technique struggles with judgment-heavy or ambiguous requirements — [Tessl blog](https://tessl.io/blog/unpacking-the-unpossible-logic-of-ralph-wiggumstyle-ai-coding)
- **wshobson:** the LLM-judge evals are "not validated against human labels" — [README](https://raw.githubusercontent.com/wshobson/agents/main/README.md)
- **karpathy-skills:** no empirical evidence; it trades speed for caution — [README](https://raw.githubusercontent.com/multica-ai/andrej-karpathy-skills/main/README.md)
- **Plugin trust:** Anthropic cannot verify that marketplace plugins work as intended or won't change — [claude-plugins-official](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/README.md)

### Inferences
- The strongest-supported design choices are deterministic external checks (tests, build, lint) and explicit loop safeguards (Ralph's circuit breaker and dual exit). They are concrete, testable, and address documented failures. Persona swarms, "self-learning," and heavy upfront specs have the weakest evidence and the most documented complaints.
- blitz's hook-enforced gates directly address the "false sense of control" and "agent ignores the skill" failures that prompt-only frameworks admit to. That is a defensible differentiator, but blitz also has no published eval showing it works.
- The ruflo CVE is a warning for blitz's cross-model CLI critic and any MCP or network surface: keep the critic invocation local and non-listening.

### Gaps
- No independent, controlled benchmark of any Claude Code plugin framework against vanilla Claude Code was found.
- superpowers-evals results are not published in the README.
- No concrete bug reports on the official ralph-wiggum Stop hook were surfaced.
- The Reddit and HN threads named in the brief were not reached within the tool budget.

## URLs consulted
1. https://raw.githubusercontent.com/obra/superpowers/main/README.md
2. https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/README.md
3. https://raw.githubusercontent.com/gsd-build/get-shit-done/main/README.md
4. https://raw.githubusercontent.com/eyaltoledano/claude-task-master/main/README.md
5. https://raw.githubusercontent.com/humanlayer/humanlayer/main/README.md
6. https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/README.md
7. https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/README.md
8. https://raw.githubusercontent.com/github/spec-kit/main/README.md
9. https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
10. https://raw.githubusercontent.com/wshobson/agents/main/README.md
11. https://raw.githubusercontent.com/frankbria/ralph-claude-code/main/README.md
12. https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/README.md
13. https://raw.githubusercontent.com/multica-ai/andrej-karpathy-skills/main/README.md
14. https://alphasignalai.substack.com/p/how-ruflo-turns-claude-code-into
15. https://www.augmentcode.com/learn/ruflo-v3-32-22-meta-harness-claude-code
16. https://darkreading.com/cyber-risk/patch-resistant-rufroot-flaw-malicious-ai-agent-swarms
17. https://github.com/ruvnet/ruflo/issues/1476
18. https://pasqualepillitteri.it/news/773/claude-flow-ruflo-guida-orchestrazione-multi-agent
19. https://ai-tldr.dev/releases/obra-superpowers-v6/
20. https://pub.towardsai.net/superpowers-6-0-unpacked-faster-ai-code-review-and-fewer-tokens-5ab40a6c564c
21. https://www.dailyaiworld.com/blogs/superpowers-obra-agentic-skills-framework-2026
22. https://www.dreamhost.com/blog/de/die-ralph-wiggum-schleife-von-den-ersten-prinzipien-de/
23. https://venturebeat.com/ai/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now
24. https://www.kartit.net/blog/ralph-wiggum-technique
25. https://tessl.io/blog/unpacking-the-unpossible-logic-of-ralph-wiggumstyle-ai-coding
26. https://metr.org/february-2026-progress-report.pdf
27. https://scienceblog.com/t-a-randomized-trial-by-metr-found-that-experienced-developers-completed-real-coding-tasks-19-slower-when-allowed-to-use-ai-tools-yet-afterwards-they-estimated-on-average-that-ai-had-made-them-20-fast/
28. GitHub repo pages and search API metadata: https://github.com/obra/superpowers, https://github.com/multica-ai/andrej-karpathy-skills, https://github.com/anthropics/skills, https://github.com/anthropics/claude-code, https://github.com/github/spec-kit, https://github.com/openai/codex, https://github.com/ruvnet/ruflo, https://github.com/Fission-AI/OpenSpec, https://github.com/gsd-build/get-shit-done, https://github.com/hesreallyhim/awesome-claude-code, https://github.com/bmad-code-org/BMAD-METHOD, https://github.com/Aider-AI/aider, https://github.com/wshobson/agents, https://github.com/Yeachan-Heo/oh-my-claudecode, https://github.com/anthropics/claude-plugins-official, https://github.com/eyaltoledano/claude-task-master, https://github.com/SuperClaude-Org/SuperClaude_Framework, https://github.com/coleam00/Archon, https://github.com/humanlayer/humanlayer, https://github.com/frankbria/ralph-claude-code, https://github.com/smtg-ai/claude-squad, https://github.com/stravu/crystal, https://github.com/kbwo/ccmanager, https://github.com/lasswellt/blitz-cc
