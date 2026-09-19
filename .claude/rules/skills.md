---
paths:
  - "skills/**"
  - "agents/**"
---

# Skill and agent authoring contract

Enforced by `hooks/scripts/skill-frontmatter-validate.sh` and `hooks/scripts/agent-frontmatter-validate.sh` (both run `--all` on every edit under these paths and on commit).

## SKILL.md

- Required: `name` (lowercase, digits, hyphens, ≤64), third-person `description` ≤1024 chars (cumulative budget 14 500 across all skills), `compatibility: ">=X.Y.Z"`, `allowed-tools` when invokable.
- `model: inherit` on every model-invokable skill. Pinning a model or `effort` forces a switch on invocation and resets the prompt cache; only skills with `disable-model-invocation: true` may pin. State the recommendation in the body line that starts `> **Session:**`.
- Body ≤500 lines; overflow goes to `references/main.md`.
- Output style is enforced by `output-styles/terse-technical.md` (force-for-plugin). Skills do not repeat an OUTPUT STYLE snippet.
- Skills that need stack detection include the one-line injection `!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`` under a `## Project Context` heading.
- `allowed-tools` never lists `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, or `TodoWrite`: those tools are off on current models. Work is tracked in `docs/plans/<slug>/tasks.json`.
- Optional fields the validator shape-checks: `context: fork` (+ `agent`, `background`), `when_to_use`, `arguments`, `user-invocable`, `paths`, `argument-hint`, `disallowed-tools`.
- Every skill claims the hook-created session record (`skills/_shared/sessions.md` §Session Registration); it never mints its own session id.

## agents/*.md

- Required: `name`, `description` with `<example>` blocks, `tools`, `maxTurns`, explicit `model` (`inherit` is not allowed for plugin agents; the routing matrix in `agents.md` §1 decides).
- `memory` ∈ `user|project|local|none`; `isolation: worktree` only; `omitClaudeMd: true` on adversarial reviewers; `experimental.cacheTtl: 1h` on agents spawned more than once per sprint.
- Forbidden (silently stripped for plugin agents): `hooks`, `mcpServers`, `permissionMode`. Never list tools the platform removes from subagents: `ScheduleWakeup`, `Workflow`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `TaskOutput`.
- Read-only roles (architect, critic, design-critic, research-critic, reviewer) keep Bash to a read subset and never gain network egress beyond what `security.md` §5 grants.

## Catalog

No numeric inventory ("N skills", "N hooks") in prose anywhere. `docs/CATALOG.md` is generated from frontmatter by `scripts/gen-catalog.sh`; run it after adding, removing, or renaming a skill or agent, and `scripts/gen-catalog.sh --check` fails CI on a stale catalog, a dead `/blitz:<name>` reference, or a numeric inventory claim.
