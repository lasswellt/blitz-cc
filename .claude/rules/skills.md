---
paths:
  - "skills/**"
  - "agents/**"
---

# Skill and agent authoring contract

Enforced by `hooks/scripts/skill-frontmatter-validate.sh` and `hooks/scripts/agent-frontmatter-validate.sh` (both run `--all` on every edit under these paths and on commit).

## SKILL.md

- Required: `name` (lowercase, digits, hyphens, ≤64), third-person `description` ≤300 chars (house rule; the validator fails only above 1,024 and on the cumulative budget), triggers first (the platform truncates `description` + `when_to_use` at 1,536 chars per skill, and every listed skill costs context each turn; cumulative budget 8 000 across all skills); `name` equals the directory name, `compatibility: ">=X.Y.Z"`, `allowed-tools` when invokable.
- `model: inherit` on every model-invokable skill. Pinning a model or `effort` forces a switch on invocation and resets the prompt cache; only skills with `disable-model-invocation: true` may pin. State the recommendation in the body line that starts `> **Session:**`.
- Body ≤500 lines and ≤15,000 bytes; overflow goes to `references/main.md`. After compaction Claude Code re-attaches the first 5,000 tokens of each invoked skill from a combined 25,000-token pool filled most-recent-first, so a long session that chains more than five large skills drops the oldest entirely: keep each body's closing phases (gate, verdict, report) inside the cap, and prefer a fresh session per `next --loop` tick.
- Output style is enforced by `output-styles/terse-technical.md` (force-for-plugin). Skills do not repeat an OUTPUT STYLE snippet.
- Skills that need stack detection include the one-line injection `!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`` under a `## Project Context` heading.
- `allowed-tools` grants only scoped entries: never bare `Bash`, `Write`, `Edit`, `Monitor`, `WebSearch` or `WebFetch`, and no `Bash(...)` wildcard after a shell, interpreter, package runner or network tool (validator rule 12). Pre-approve the plugin's own scripts as `Bash(bash ${CLAUDE_PLUGIN_ROOT}/<script> *)`, read-only git subcommands, `Edit(<dir the skill owns>/**)` and `WebFetch(domain:<host>)`; everything else follows the user's permission mode (`SECURITY.md` §Running unattended).
- `allowed-tools` never lists `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, or `TodoWrite`: those tools are off on current models. Work is tracked in `docs/plans/<slug>/tasks.json`.
- Optional fields the validator shape-checks: `context: fork` (+ `agent`, `background`), `when_to_use`, `arguments`, `user-invocable`, `paths`, `argument-hint`, `disallowed-tools`.
- Every skill claims the hook-created session record (`skills/_shared/sessions.md` §2 Session record, skill preamble steps 1–7); it never mints its own session id.

## agents/*.md

- Required: `name`, `description` with `<example>` blocks, `tools`, `maxTurns`, explicit `model` (`inherit` is not allowed for plugin agents; the routing matrix in `agents.md` §1 decides).
- `memory` ∈ `user|project|local|none`; `isolation: worktree` only; `omitClaudeMd: true` on adversarial reviewers; `experimental.cacheTtl: 1h` on agents spawned more than once per sprint.
- Forbidden (silently stripped for plugin agents): `hooks`, `mcpServers`, `permissionMode`. Never list tools the platform removes from subagents: `ScheduleWakeup`, `Workflow`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `TaskOutput`.
- Read-only roles (critic, design-critic, research-critic) keep Bash to a read subset and gain no network egress beyond their `tools:` line (`research-critic` is the only agent with WebFetch; `agents.md` §1.1).

## Catalog

No numeric inventory ("N skills", "N hooks") in prose anywhere. `docs/CATALOG.md` is generated from frontmatter by `scripts/gen-catalog.sh`; run it after adding, removing, or renaming a skill or agent, and `scripts/gen-catalog.sh --check` fails CI on a stale catalog, a dead `/blitz:<name>` reference, or a numeric inventory claim.
