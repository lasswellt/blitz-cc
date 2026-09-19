# CC Plugin Suite — Development Guidelines

This repo is the **blitz** Claude Code plugin: 38 development skills in `skills/`, 11 plugin agents in `agents/`, 46 hook scripts across 24 events in `hooks/`, and 13 shared protocol files in `skills/_shared/`. Skills are auto-discovered from `skills/<name>/SKILL.md` and invoked as `/blitz:<name>`. The plugin floor is Claude Code ≥2.1.271 (`.claude-plugin/compat.json`).

## Activity Feed

The `SessionStart` hook prints recent activity from other sessions and the hooks record session start/end, idle, notifications, and file edits in `.cc-sessions/activity-feed.jsonl`. You still append the events only you can know, one JSONL line each, `session` = your native session id (`${CLAUDE_SESSION_ID}`):

- `task_start` when you begin a task, `decision` for a non-trivial choice, `verification` with `detail: {"command", "result": "pass|fail"}` after a build/test/lint, `task_complete` with `detail: {"summary"}`.
- Format: `{"ts":"<ISO-8601>","session":"<id>","skill":"freeform|<skill>","event":"<type>","message":"<≤200 chars>","detail":{}}`. Full spec: `skills/_shared/output.md` §Activity Feed.
- If the feed shows another session on overlapping files, say so before editing.

## Where the rules live

- Skill and agent authoring contract (frontmatter, OUTPUT STYLE snippet, model inheritance): `.claude/rules/skills.md` (loads when you touch `skills/**` or `agents/**`).
- Hook authoring contract (stdin fields, exit codes, helpers, bats): `.claude/rules/hooks.md` (loads when you touch `hooks/**`).
- Shared protocols: `skills/_shared/` — one file per concern; `loop.md` (tasks.json, gate, next rows, scheduling), `sessions.md` (session records, inbox, mailbox, handoff), `agents.md` (spawning, reply contract, parallelism, Workflow), `quality.md` (check registry, ratchet, structural done, DoD), `security.md` (TB-1…TB-5, kill switch), `output.md` (terse output, progress lines).
- Hook index: `hooks/scripts/README.md`. Validators: `scripts/validate-plugin-structure.sh`, `scripts/check-version-sync.sh`, `hooks/scripts/{skill,agent}-frontmatter-validate.sh --all`, `hooks/scripts/markdown-link-validate.sh --all`, `bats hooks/tests/`.

## Working here

- Run the validators above before committing; `pre-commit-validate.sh` runs them again and blocks on drift.
- No numeric inventory in prose. `docs/CATALOG.md` is generated from frontmatter (`scripts/gen-catalog.sh`); regenerate it after adding, removing, or renaming a skill or agent.
- Set model and effort once per session (`claude --model opus --effort high`); every skill is `model: inherit`.
- Quiet flags keep context small: `npx vitest run <file> --reporter=dot`, `git --no-pager`, `--silent` on npm scripts.
- `.cc-sessions/`, `sprints/`, `docs/_research/`, `docs/roadmap/`, `docs/audits/` are gitignored runtime output. Tracked research and reviews go under `docs/research/` and `docs/reviews/`.

## Clarification Gate (Karpathy Principle 1)

Before any non-trivial freeform task, state assumptions and surface tradeoffs: list 2–3 interpretations and pick one with a one-line rationale; name a simpler approach if one exists; if something is unclear, ask one focused question. `autonomy=high|full` skips the question but still writes a one-line ASSUMPTIONS block before the first edit. Trivial tasks skip the gate. Skill-level scope rules stay authoritative; the more restrictive rule wins. Adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT).

## Quality Gates

`sprint-review` Phase 3.6 enforces 8 invariants (registry consistency, epic completion, OUTPUT STYLE presence, the 8-metric ratchet, critic LGTM, branch hygiene); the verification stack (Stop gate, `/goal`, critic, `/verify`) is defined in `skills/_shared/quality.md`. The 20-detector anti-shortcut taxonomy (13 reject / 7 advisory) lives there too.

## Compaction

When compacting, preserve: the sprint id and phase, `${CLAUDE_SESSION_ID}`, the path of any `gate.json` in force, undelivered mailbox lines, the list of modified files, and the exact test/lint commands used. The PreCompact hook writes `.cc-sessions/HANDOFF.json` for the same purpose.
