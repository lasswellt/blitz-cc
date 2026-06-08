# CC Plugin Suite — Development Guidelines

## Activity Feed (Always-On)

**Every Claude Code session in this repo MUST maintain the activity feed, regardless of whether a skill is invoked.**

### On Conversation Start

1. Create `.cc-sessions/` if it doesn't exist: `mkdir -p .cc-sessions`
2. Read the last 20 lines of `.cc-sessions/activity-feed.jsonl` (if it exists)
3. Print a brief summary of recent activity from other sessions so the user knows what's been happening
4. Log your own session start:
   ```
   {"ts":"<ISO-8601>","session":"cli-<8-char-hex>","skill":"freeform","event":"session_start","message":"<brief description of what user asked>","detail":{}}
   ```

### On Every Substantive Action

Append a line to `.cc-sessions/activity-feed.jsonl` when you:
- Start working on a task (even without a skill): `event: "task_start"`
- Make a significant decision: `event: "decision"`
- Complete a file edit or creation: `event: "file_change"` with `detail: {"files": ["path1", "path2"]}`
- Run a build, test, or lint command: `event: "verification"` with `detail: {"command": "...", "result": "pass|fail"}`
- Complete the task: `event: "task_complete"` with `detail: {"summary": "..."}`

### Entry Format

```jsonl
{"ts":"<ISO-8601>","session":"<id>","skill":"freeform","event":"<type>","message":"<human-readable>","detail":{}}
```

For skill invocations, the skill name replaces `"freeform"`. The verbose-progress protocol in `skills/_shared/terse-output.md` has the full specification.

### Reading the Feed

Before starting work, always check recent activity. If another session is actively working on overlapping files, mention it to the user. Format:

```
Recent activity:
  [cli-a3f7c1b2] 5m ago — Editing skills/sprint-dev/SKILL.md (freeform)
  [sprint-dev-b4e8f2a1] 28m ago — Sprint 3 implementation complete (sprint-dev)
```

If no activity feed exists or is empty, skip the summary silently.

## Skill System

This repo contains **37 development skills** in `skills/` and **10 plugin agents** in `agents/` (`architect`, `backend-dev`, `critic`, `design-critic`, `doc-writer`, `frontend-dev`, `orchestrator`, `research-critic`, `reviewer`, `test-writer`). Skills are auto-discovered by Claude Code from `skills/<name>/SKILL.md` (Anthropic-canonical layout — no central registry). Skills are invoked via `/blitz:<skill-name>`.

Every SKILL.md must satisfy the canonical frontmatter contract enforced by `hooks/scripts/skill-frontmatter-validate.sh`: third-person description ≤1024 chars (matches the official platform cap per [platform.claude.com/docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices); enforced to keep the always-loaded skill listing lean — cumulative description budget tracked in `docs/audits/skill-startup-token-budget.md`), body ≤500 lines, required fields (`name`, `description`, `model`, `effort`, `compatibility`, `allowed-tools` when invokable), and the verbatim OUTPUT STYLE snippet from `/_shared/terse-output.md`.

**Holistic-machine entry point**: `agents/orchestrator.md` is activated as the plugin's main-thread agent via `.claude-plugin/settings.json {"agent": "orchestrator"}` (Claude Code ≥2.1.117). Freeform user input lands on the orchestrator; explicit slash commands bypass it. See `skills/_shared/agent-orchestration.md` for the constraint-aware routing protocol (subagents cannot spawn subagents → super-orchestrator skills stay slash-invoked).

## Shared Protocols

All skills follow the protocols in `skills/_shared/` (13 `.md` files + `check-registry.json`). As of the 2026-06-06 consolidation, each file owns one cross-cutting concern (former fragments absorbed; see each file's top-of-file **Absorbs/Consolidates** map):

- **terse-output.md** — output style + canonical exemptions + console verbosity / activity-feed logging (absorbed `verbose-progress.md`). Validator-pinned home of the canonical OUTPUT STYLE snippet.
- **session-lifecycle.md** — multi-session safety (locks, registration, autonomy), checkpoints, context/compaction handoff, the **state-handoff** resume contract, and loop scheduling (absorbed `session-protocol`, `checkpoint-protocol`, `context-management`, `state-handoff`, `scheduling`).
- **sprint-contracts.md** — carry-forward registry (Reader Algorithm + writer contracts), story frontmatter schema, Definition of Done, deviation + scope-limit protocols (absorbed `carry-forward-registry`, `story-frontmatter`, `definition-of-done`, `deviation-protocol`, `scope-limit-protocol`).
- **agent-orchestration.md** — subagent type/weight, HEARTBEAT/PARTIAL/WRAP_UP, timeouts, stuck-loop detection, Agent Output + Token Budget & Reply contract, prompt boilerplate, routing decision tree (+ subagents-cannot-spawn-subagents), the opt-in `Workflow` dispatch contract, and the 60/35/5 model-routing matrix (absorbed `spawn-protocol`, `agent-prompt-boilerplate`, `agent-routing`, `agent-view-dispatch`, `workflow-dispatch`, `token-budget`).
- **quality-engine.md** — check-registry semantics, the quality-skill decision matrix, the 20-detector anti-shortcut taxonomy (13 reject / 7 advisory), the 8-metric ratchet, and the deterministic verification recipe (absorbed `check-registry.md`, `quality-matrix`, `shortcut-taxonomy`, `ratchet-protocol`, `deterministic-test-recipe`). The `check-registry.json` data file stays separate.
- **security.md** — Blitz containment posture / threat model (TB-1…TB-4, canonical owner cited by the `block-*.sh` guards), hook-trust boundary, package-install policy (absorbed `threat-model`, `hook-trust`, `package-install-policy`).
- **project-context.md** — load-time injection block imported verbatim into SKILL.md headers.
- **skill-cross-references.md** — author-time dedup target for the Additional Resources block.
- **design-criteria.md** — design-pillar criteria; complemented by `docs/integrations/impeccable/` (framework-adaptive design pillar; supersedes the retired `frontend-design-heuristics.md`).
- **knowledge-protocol.md** — `.cc-sessions/KNOWLEDGE.md` cross-session lessons format.
- **session-report-template.md** — session report output template.
- **worktree-lifecycle.md** — worktree lifecycle, ratchet-linked (`stale_worktree_branch_count`).
- **html-template-helper.md** — shared-protocol convention + reusable `emit_html()` bash helper for opt-in HTML side-output (E-039); consumed by audit, codebase-map, quality-metrics, research.

## Hooks

38 hook scripts (35 event-wired through `hooks/hooks.json`, 2 sub-invoked, 1 critic-spawned) across 16 events (`SessionStart`, `UserPromptExpansion`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, `TaskCompleted`, `TeammateIdle`, `SubagentStart`, `SubagentStop`, `PostToolBatch`, `PostToolUseFailure`, `StopFailure`, `PermissionRequest`, `WorktreeCreate`, `WorktreeRemove`). They handle file protection, auto-formatting, auto-linting, auto-testing, commit validation (frontmatter lint, version sync, link rot, reference compression), context monitoring, activity-feed logging, and **7 anti-shortcut blockers**: 5 P0 (block-no-verify, block-destructive-git, block-destructive-sql, block-test-deletion, post-edit-typecheck-block) plus 2 P1 (block-as-any-insertion, block-test-disabling). See [hooks/scripts/README.md](hooks/scripts/README.md) for the full index grouped by event.

## Clarification Gate (Karpathy Principle 1)

Before any non-trivial freeform task, **state assumptions explicitly** and **surface tradeoffs**:

- If multiple interpretations exist, list 2-3 and pick the most likely with one-line rationale — do not silently pick.
- If a simpler approach exists than what was requested, name it. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask 1 focused question.

**Autonomy override:** `autonomy=high|full` skips the question step. In that mode, still write a one-line ASSUMPTIONS block before the first edit so the user can correct course on read-back.

**Trivial tasks** (typo fix, single-line tweak, rename within one file): skip the gate. Use judgment.

**Precedence:** Skill-level scope rules (e.g., `skills/quick/SKILL.md:47`) remain authoritative — this gate adds the upstream "think first" step. If two rules conflict, the more restrictive wins.

Adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT). Original principles by Andrej Karpathy.

## Quality Gates (v1.11+)

`sprint-review` Phase 3.6 enforces 8 invariants. Sprint cannot reach PASS while any fails:

1. Carry-forward Reader Algorithm — registry consistency
2. Reserved (canonical algorithm)
3. Epic completion — no `done` epics with `incomplete` registry entries
4. Reserved (canonical algorithm)
5. OUTPUT STYLE snippet present in every SKILL.md + agent-prompt template
6. **Ratchet** — 8 monotonic metrics never regress without carry-forward (`type_errors > 0` is absolute floor; `stale_worktree_branch_count` added 2026-05-17 per [worktree-lifecycle.md](skills/_shared/worktree-lifecycle.md))
7. **Critic** — `agents/critic.md` adversarial review must emit LGTM (it runs the 20-detector shortcut taxonomy)
8. **Branch hygiene** — sprint-dev Phase 4.4 deleted every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch (per-sprint scope; complements Invariant 6's cross-sprint cumulative metric)
