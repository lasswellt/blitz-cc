---
id: E-044
title: "Memory + context economics"
status: planned
priority: P1
phase: 2
domain: platform
depends_on: []
cc_floor: "2.1.271"
estimated_stories: 8
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-044 Memory + context economics

**Why.** The session-value guidance is blunt: set model and effort once, keep CLAUDE.md short, push procedures into skills and hooks, keep noisy output out of the main context. blitz violates the first rule structurally (every skill pins `model: opus` + `effort`, C6) and the second by carrying a per-session procedure in CLAUDE.md (C13). Agent frontmatter has gained `omitClaudeMd`, `experimental.cacheTtl`, `skills` preload, and three memory scopes that the validator rejects (C7). KNOWLEDGE.md and auto memory now overlap.

## Stories

### S1 Skills inherit the session model
- **Files:** all 37 `skills/*/SKILL.md`; `hooks/scripts/skill-frontmatter-validate.sh:150-156`.
- **Change:** `model: opus` → `model: inherit`; delete `effort:` lines; add one body line under the header: "Recommended session: opus / effort high. Set once (`--model`, `/effort`); read `${CLAUDE_EFFORT}` to adapt." Validator accepts `inherit`, makes `effort` optional, WARNs when present unless `disable-model-invocation: true` (slash-only skills such as `migrate`, `release`, `ship` may keep a pin). Add optional shape checks for `context: fork`, `agent`, `background`, `when_to_use`, `arguments`, `user-invocable`, `paths`.
- **Acceptance:** `skill-frontmatter-validate.sh --all` green; on a live `opus[1m]` session `/blitz:next` runs without the `sonnet[1m]` credits error (this is the 2.4.4 regression check).

### S2 Agent frontmatter modernization
- **Files:** `agents/backend-dev.md`, `frontend-dev.md`, `infra-dev.md`, `test-writer.md`, `reviewer.md` (add `experimental:\n  cacheTtl: 1h`); `agents/critic.md`, `design-critic.md`, `research-critic.md` (add `omitClaudeMd: true`, the spec arrives in the prompt and consumer CLAUDE.md must not steer the adversary); `hooks/scripts/agent-frontmatter-validate.sh:138`.
- **Change:** validator: `memory` ∈ user | project | local | none; shape checks for `isolation: worktree`, `omitClaudeMd`, `experimental.cacheTtl`, `skills`; `model: inherit` stays a FAIL for `agents/` (routing matrix mandates explicit); FAIL if `tools:` lists `ScheduleWakeup`, `Workflow`, or `AskUserQuestion` (removed from subagents).
- **Acceptance:** `agent-frontmatter-validate.sh --all` green; a fixture with `memory: local` passes.

### S3 KNOWLEDGE.md and auto memory
- **Files:** `skills/_shared/knowledge-protocol.md` (new §8); `skills/retrospective/SKILL.md`; `skills/_shared/agent-orchestration.md:1394-1398` (C5).
- **Change:** auto memory (per user, typed `user` / `feedback` / `project` / `reference` files, 200-line index) vs KNOWLEDGE.md (project-local, injectable into subagent prompts). Rule: `user`-type lessons → auto memory only; `project` / `reference` lessons → KNOWLEDGE.md canonical + one pointer line in `MEMORY.md`; retrospective writes both; `autoMemoryEnabled: false` → KNOWLEDGE.md only. Replace the hard-coded path with `autoMemoryDirectory` semantics.
- **Acceptance:** `markdown-link-validate.sh`; retrospective fixture produces the pointer line.

### S4 CLAUDE.md trim + rules
- **Files:** `CLAUDE.md`; new `.claude/rules/hooks.md` (`paths: ["hooks/**"]`), `.claude/rules/skills.md` (`paths: ["skills/**", "agents/**"]`); `.github/workflows/ci.yml`.
- **Change:** CLAUDE.md ≤ 60 lines: remove the activity-feed duties (hook-owned after E-041), remove catalog counts (count-sync covers README), collapse Quality Gates to a pointer. Add a Compaction section ("preserve sprint id, phase, `${CLAUDE_SESSION_ID}`, `gate.json` path, open mailbox lines, modified files, test commands"). Add quiet-flag guidance (`npx vitest run <file> --reporter=dot`, `git --no-pager`). Relocate hook-author and frontmatter-contract paragraphs into the rules files. CI adds a `wc -l CLAUDE.md` ≤ 200 guard.
- **Acceptance:** `/context` in a fresh session shows CLAUDE.md and both rules; `InstructionsLoaded` hook (E-040 S6, optional) logs `path_glob_match` when editing under `hooks/`.

### S5 Prompt-cache guidance
- **Files:** `skills/_shared/agent-orchestration.md` §2 Prompt Caching (fix C4), §4 (mention `/skill-doctor`), §8; `hooks/scripts/model-switch-warn.sh` (E-040 S2).
- **Change:** document `experimental.cacheTtl`, `subagentPromptCacheTtl`, `CLAUDE_CODE_SUBAGENT_MODEL(_FORCE)`; fan-out prefix stagger; the `PreModelSwitch` hook is the only runtime nudge for "set model once".

### S6 Context hygiene in the session protocol
- **Files:** `skills/_shared/session-lifecycle.md` §Context Management.
- **Change:** add `/btw` for side questions, `/compact` before a break (cache expiry), `/rewind` to discard recent turns, `/rename` before `/clear`, `/skill-doctor` for never-invoked skills, and the 30 k-char output auto-file behavior (so skills stop truncating manually).

### S7 Skill preload on agents (measure first)
- **Files:** `agents/test-writer.md` (candidate `skills: [test-gen]`), `agent-orchestration.md` §5.
- **Change:** document when `skills:` preload beats `@import` prose; adopt only where `/skill-doctor` shows the skill is invoked every time the agent runs.

### S8 Description budget check in health
- **Files:** `skills/health/SKILL.md` Phase 3.4.
- **Change:** invoke `/skill-doctor` when available; report per-skill context cost and never-invoked skills; fail if cumulative description chars exceed the validator's budget.

## Verification
- `skill-frontmatter-validate.sh --all && agent-frontmatter-validate.sh --all && check-count-sync.sh && markdown-link-validate.sh`.
- Live: `/context` before and after on the same prompt shows the CLAUDE.md token reduction; invoke `/blitz:next` twice in one session and confirm no model-switch warning.

## Risks
- `model: inherit` reverses the 2.4.4 decision. S1 acceptance includes the live check.
- Rules with `paths:` load on file read, not on invocation; hook-author rules only appear once a hook file is opened. Acceptable.
