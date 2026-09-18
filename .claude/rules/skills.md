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
- The OUTPUT STYLE snippet must be byte-identical to the canonical block in `skills/_shared/terse-output.md`.
- Import the Project Context block from `skills/_shared/project-context.md` verbatim.
- Optional fields the validator shape-checks: `context: fork` (+ `agent`, `background`), `when_to_use`, `arguments`, `user-invocable`, `paths`, `argument-hint`, `disallowed-tools`.
- Every skill claims the hook-created session record (`skills/_shared/session-lifecycle.md` §Session Registration); it never mints its own session id.

## agents/*.md

- Required: `name`, `description` with `<example>` blocks, `tools`, `maxTurns`, explicit `model` (`inherit` is not allowed for plugin agents; the routing matrix in `agent-orchestration.md` §1 decides).
- `memory` ∈ `user|project|local|none`; `isolation: worktree` only; `omitClaudeMd: true` on adversarial reviewers; `experimental.cacheTtl: 1h` on agents spawned more than once per sprint.
- Forbidden (silently stripped for plugin agents): `hooks`, `mcpServers`, `permissionMode`. Never list tools the platform removes from subagents: `ScheduleWakeup`, `Workflow`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `TaskOutput`.
- Read-only roles (architect, critic, design-critic, research-critic, reviewer) keep Bash to a read subset and never gain network egress beyond what `security.md` §5 grants.

## Counts

Adding or removing a skill, agent, or shared protocol changes asserted counts. Run `scripts/check-count-sync.sh --write`, then fix the prose it flags in `README.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `CLAUDE.md`.
