---
title: "Platform Delta — Claude Code & API, cohesion audit 2026-05"
created: 2026-05-28
---

# Platform Delta

Single citation source for native-overlap claims in the cohesion-2026-05 audit.

## Verified Changes

| Change | Version / Date | Primary URL | Why it matters to Blitz |
|--------|---------------|-------------|-------------------------|
| Native orchestration: JS script fans work across dozens–hundreds of parallel subagents; intermediate results stay in script variables, not Claude's context window | v2.1.154+ / 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz `spawn-protocol.md` + `agent-routing.md` partially replicate this in-process; native workflows may obsolete worktree-per-agent pattern |
| Adversarial verification built into `/deep-research` workflow: independent agents refute each other's findings, votes converge before reporting | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz `agents/critic.md` + `agents/research-critic.md` serve same role; native workflow makes the pattern first-class |
| Resumable state: completed agents return cached results on resume; resume limited to same session (fresh start on new session) | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz `STATE.md` + `carry-forward-registry.md` handle cross-session resume; native resume is intra-session only — gap persists |
| Workflow trigger: include `workflow` in prompt (or `/effort ultracode`); `alt+w` suppresses unintended trigger | 2026-05-28 | https://code.claude.com/docs/en/workflows | Affects how Blitz skills authored for `ultracode` effort behave in auto-mode; no skill changes required today |
| `/effort ultracode` = `xhigh` reasoning + automatic workflow orchestration; each substantive task can spawn several sequential workflows; session-scoped | 2026-05-28 | https://code.claude.com/docs/en/workflows | `token-budget.md` model-routing matrix must account for `ultracode` producing multi-workflow sessions |
| Workflows available on Anthropic API, Bedrock, Vertex AI, Foundry, CLI, Desktop, VS Code, `-p`, Agent SDK; `-p`/Agent SDK never prompted | v2.1.154+ / 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz CI/non-interactive pipelines (`claude -p`) get workflows without confirmation — review permission rules |
| Confirmation behavior: default/accept-edits every run unless "don't ask again"; auto → first launch only; ultracode/bypass/`-p`/Agent SDK → never | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz `session-protocol.md` autonomy levels map to these modes; high/full autonomy aligns with auto-mode skip |
| Concurrency cap: 16 concurrent agents per run (lower on CPU-constrained machines) | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz sprint-dev parallelism budget should not assume >16 simultaneous agents in a single workflow run |
| Total agent cap: 1,000 agents per run; prevents runaway loops | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz `stuck-loop detection` + `ratchet-protocol.md` provide complementary guard; 1k cap is platform floor |
| Workflows gated by plan: all paid (Pro/Max/Team/Enterprise); Pro must enable from `/config`; Team/Enterprise admins can disable | 2026-05-28 | https://code.claude.com/docs/en/workflows | Blitz skills that recommend workflows must gate on plan; skill docs should note Pro requires explicit opt-in |
| `claude-opus-4-8` fast mode: up to 2.5x output tokens/sec vs standard; `speed: "fast"` API param; research preview, Claude API only | fast-mode-2026-02-01 beta header / 2026-05-28 | https://platform.claude.com/docs/en/build-with-claude/fast-mode | `token-budget.md` Opus routing should surface fast mode for latency-critical Blitz skills (sprint-dev wave dispatch) |
| `claude-opus-4-8` fast mode pricing: $10 input / $50 output per MTok — 3x cheaper than Opus 4.6/4.7 fast mode ($30/$150) | 2026-05-28 | https://platform.claude.com/docs/en/build-with-claude/fast-mode | Cost model in `token-budget.md` must update Opus fast-mode cost column |
| Opus 4.8 honesty: ~4x less likely than Opus 4.7 to let own code flaws pass unremarked | claude-opus-4-8 / 2026-05-28 | https://www.anthropic.com/news/claude-opus-4-8 | Critic/reviewer agent fidelity improves without Blitz-side changes; may reduce critic false-negative rate |
| `disallowed-tools` SKILL.md frontmatter field: removes named tools from Claude's pool for skill duration | v2.1.152 | https://code.claude.com/docs/en/skills | Enables per-skill tool lockdown; `shortcut-taxonomy.md` blockers could be reinforced via frontmatter |
| `/reload-skills` command: re-scans skill/command directories without session restart | v2.1.152 | https://code.claude.com/docs/en/skills | Hooks that install/modify skills can now call `reloadSkills: true` in `SessionStart` output to make skills live immediately |
| `SessionStart` hooks: `hookSpecificOutput` supports `additionalContext`, `sessionTitle`, `initialUserMessage`, `watchPaths`, `reloadSkills` | v2.1.152 | https://code.claude.com/docs/en/hooks | Blitz `hooks/hooks.json` SessionStart hook can inject session context + auto-reload skills on install |
| `effort.level` in hook JSON input + `$CLAUDE_EFFORT` env var (PreToolUse, PostToolUse, Stop, SubagentStop); values: low/medium/high/xhigh/max/ultra | v2.1.141 | https://code.claude.com/docs/en/hooks | Blitz anti-shortcut hooks can branch on effort level; ultracode (`ultra`) triggers heavier validation |
| `settings.autoMode.hard_deny` array: prose rules always blocked in auto-mode; not read from project settings (prevents repo manipulation) | v2.1.136 | https://code.claude.com/docs/en/settings | Blitz autonomy-level rules in `session-protocol.md` should align with built-in hard_deny list to avoid duplicating |
| `--plugin-url <url>` fetches plugin `.zip` from URL; `--plugin-dir` accepts `.zip`; `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` forces HTTPS | v2.1.128 (zip), v2.1.129 (url) | https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md | Blitz can distribute as `.zip` plugin; CI pipelines can pin plugin version via URL |
| `/code-review --fix` applies findings to working tree after diff review; `--comment` posts inline PR comments | v2.1.152 / 2026-05-27 | https://code.claude.com/docs/en/code-review#review-a-diff-locally | Replaces manual apply step in Blitz `sprint-review` Phase 3.6 critic loop |
| `/simplify` reinstated (v2.1.154): cleanup-only review (reuse, simplification, efficiency, altitude) with auto-apply; no bug-hunting | v2.1.154 / 2026-05-28 | https://code.claude.com/docs/en/code-review#review-a-diff-locally | Blitz `simplify` skill now has a native platform equivalent; skill wrapper may delegate to `/simplify` |
| `/goal` completion-condition loop: fast model checks condition after each turn; loops until condition holds, then clears | v2.1.139 / 2026-05-11 | https://code.claude.com/docs/en/whats-new/2026-w20 | Complements Blitz `--loop` / `/blitz:next --loop`; native `/goal` is simpler for single-condition exit criteria |
| `claude agents` TUI: one-screen view of running/blocked/done sessions; attach/detach; background sessions persist without terminal | v2.1.139 / 2026-05-11 (research preview) | https://code.claude.com/docs/en/whats-new/2026-w20 | Blitz multi-worktree sprint-dev visibility gap partially closed by native `claude agents` panel |
| Mid-conversation system messages: `{"role":"system"}` at non-first position in messages array; preserves prompt cache; Opus 4.8 only; Claude API + AWS Platform only | 2026-05-28 | https://platform.claude.com/docs/en/build-with-claude/mid-conversation-system-messages | Blitz agent prompt injection pattern in `agent-prompt-boilerplate.md` can use mid-conv system messages to update instructions without breaking cache hits |
| Model IDs current as of 2026-05-28: `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001` (alias `claude-haiku-4-5`) | 2026-05-28 | https://platform.claude.com/docs/en/about-claude/models/overview | SKILL.md frontmatter `model:` fields + `token-budget.md` routing matrix must reference these IDs |

## Unverified — do not cite downstream

Items below sourced from system-card PDF not directly fetchable; confirmed only via secondary search results citing the card. Do not use as authoritative citations until primary PDF is directly verified.

| Change | Version / Date | Primary URL | Note |
|--------|---------------|-------------|------|
| Opus 4.8: 0% uncritically-reporting-flawed-results eval score | claude-opus-4-8 / 2026-05-28 | https://cdn.sanity.io/files/4zrzovbb/website/c886650a2e96fc0925c805a1a7ca77314ccbf4a6.pdf | System card PDF; not directly verified |
| Opus 4.8: >10x overconfidence reduction vs 4.7; achieved via abstaining when uncertain | claude-opus-4-8 / 2026-05-28 | https://cdn.sanity.io/files/4zrzovbb/website/c886650a2e96fc0925c805a1a7ca77314ccbf4a6.pdf | System card PDF; not directly verified |
| Opus 4.8: perfect lazy-investigation eval score; Opus 4.7 incorrect ~25% on same eval | claude-opus-4-8 / 2026-05-28 | https://cdn.sanity.io/files/4zrzovbb/website/c886650a2e96fc0925c805a1a7ca77314ccbf4a6.pdf | System card PDF; not directly verified |
| GraphWalks 1M-token F1: Opus 4.8 = 68.1% vs Opus 4.7 = 40.3% | claude-opus-4-8 vs 4.7 / 2026-05-28 | https://cdn.sanity.io/files/4zrzovbb/website/c886650a2e96fc0925c805a1a7ca77314ccbf4a6.pdf | System card PDF; not directly verified |
| Gray Swan agent red-team ASR regression: Opus 4.8 ~9.6% vs Opus 4.7 6.0% (thinking enabled) | claude-opus-4-8 vs 4.7 / 2026-05-28 | https://cdn.sanity.io/files/4zrzovbb/website/c886650a2e96fc0925c805a1a7ca77314ccbf4a6.pdf | System card PDF; not directly verified |
