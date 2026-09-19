# blitz — development guidelines

This repo is the **blitz** Claude Code plugin: skills in `skills/` (auto-discovered as `/blitz:<name>`), agents in `agents/`, hooks in `hooks/`, shared protocols in `skills/_shared/`. Floor: Claude Code ≥2.1.271 (`.claude-plugin/compat.json`). The catalog is generated into `docs/CATALOG.md`; never state component counts in prose.

## Where the rules live

- Skill and agent authoring contract: `.claude/rules/skills.md` (loads when you touch `skills/**` or `agents/**`).
- Hook authoring contract: `.claude/rules/hooks.md` (loads when you touch `hooks/**`); index in `hooks/scripts/README.md`.
- Shared protocols, one file per concern: `loop.md` (artifacts, `tasks.json`, `next` rows, gates), `sessions.md`, `agents.md`, `quality.md`, `security.md`, `output.md`.
- Validators: `hooks/scripts/{skill,agent}-frontmatter-validate.sh --all`, `hooks/scripts/markdown-link-validate.sh --all`, `scripts/validate-plugin-structure.sh`, `scripts/check-version-sync.sh`, `scripts/gen-catalog.sh --check`, `bats hooks/tests/`. Run them with `</dev/null` from a non-tty shell.

## Working here

- Run the validators before committing; `pre-commit-validate.sh` runs them again and blocks on drift.
- After adding, removing, or renaming a skill or agent, run `scripts/gen-catalog.sh` and commit `docs/CATALOG.md`.
- `docs/plans/<slug>/tasks.json` is written only through `scripts/tasks.sh`; `tasks-guard.sh` denies everything else.
- Set model and effort once per session (`claude --model opus --effort high`); skills are `model: inherit` unless slash-only.
- Quiet flags keep context small: `npx vitest run <file> --reporter=dot`, `git --no-pager`, `--silent` on npm scripts.
- `.cc-sessions/`, `docs/_research/`, `docs/audits/` are gitignored runtime output. Tracked research and reviews go under `docs/research/` and `docs/reviews/`.

## Clarification gate

Before a non-trivial freeform task, state assumptions and tradeoffs: two or three readings, pick one with a one-line rationale, name a simpler approach if one exists, ask one focused question if something is unclear. Trivial tasks skip the gate. Adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT).

## Compaction

Preserve: the active plan slug and task id, `${CLAUDE_SESSION_ID}`, the path of any `gate.json` in force, undelivered mailbox lines, the list of modified files, and the exact test and lint commands used. The PreCompact hook writes `.cc-sessions/HANDOFF.json` for the same purpose.
