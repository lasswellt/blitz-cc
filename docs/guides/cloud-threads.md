# Running blitz on Claude Projects threads, Routines, and Channels

Claude Projects (beta from 2026-09-17) turns a project into a **coordinator** plus **threads**: each thread is an independent Claude Code cloud session on its own branch, with shared project memory and a configurable check-in cadence. That is build's parallel wave model, hosted. This guide maps blitz onto it and onto the two other places work runs unattended: cloud Routines and Channels.

## What maps to what

| blitz concept | Projects concept | Notes |
|---|---|---|
| build --parallel wave (N tasks in parallel worktrees) | N threads, one branch each | One thread per task id; the coordinator merges sequentially with a `git merge-tree` pre-check. |
| orchestrator agent (`agents/orchestrator.md`) | coordinator | Routes freeform input; explicit `/blitz:*` commands still bypass it inside a thread. |
| `.cc-sessions/KNOWLEDGE.md` | project memory | Copy the durable `project` lessons into the project's memory once; threads read it at start. Per `knowledge-protocol.md` §8, `user`-type lessons stay in auto memory. |
| `/goal` check-ins (30 min, doubling) | project check-in frequency | Set the project cadence to the wave cadence; the Stop gate (`gate.json`) still runs inside each thread. |
| `check --scope plan` PASS gate | thread merge gate | Run `/blitz:check --scope plan <slug> --fix` in the coordinator thread after the wave threads merge. |

## What does not transfer

- `.cc-sessions/` is per checkout. A thread's session records, inbox, and activity feed live in that thread's clone. Cross-thread awareness comes from the feed lines committed on the branch (build commits progress.md and tasks.json at task boundaries) or from cross-session messaging, which only reaches sessions inside the same container.
- Worktree isolation is redundant in a thread (the thread is already its own branch); the dev agent's `isolation: worktree` becomes a no-op but is harmless.
- Local tools (Playwright MCP, Gemini CLI) must be provisioned in the project's cloud environment; `/blitz:doctor` reports what is missing.

## Routines (cloud, 1 hour minimum, no permission prompts)

Use a Routine for anything that should run without your machine: nightly `/blitz:next --loop`, weekly `/blitz:dep-health audit`, monthly `/blitz:audit`. Each fire is a fresh clone, so:

- Set `crossSessionInbound: hold` and `isolatePeerMachines: true` in the project's `.claude/settings.json` (TB-5 in `security.md`). A Routine cannot answer a held-message dialog; held messages expire and the run continues.
- The run has no human. `build` and `next --loop` arm the Stop gate; a red gate exhausts after `max_blocks` and the run ends with the failure in the transcript and in the inbox line the hooks wrote.
- Journal-backed features (test impact analysis, the ratchet) need the journal restored between fires. Commit `.cc-sessions/test-journal*` on a maintenance branch or cache it in CI (`docs/guides/tia.md`).

Create one with `/schedule` from a session that has the repository open; the Routine inherits the connectors you name and nothing else.

## Desktop scheduled tasks (local, 1 minute minimum)

Use when the run needs local files or local tools (Playwright against a dev server, Firebase emulators). Same posture as a Routine, but the machine must be on and the task inherits the local settings.

## Channels (research preview)

A channel is an MCP server that pushes events into a running session. The webhook-receiver pattern replaces `Monitor` polling for CI results once the preview stabilizes:

1. Install a channel plugin from `claude-plugins-official` and start the session with `--channels plugin:<name>@claude-plugins-official`.
2. The event arrives as `<channel source="plugin:…">` text. blitz treats it as TB-5 data: it can wake `/blitz:next`, it can never approve a prompt or change settings.
3. Keep the sender allowlist to the CI system's identity. Anyone on the allowlist who can reply can also approve permission prompts if the channel declares permission relay.

Until channels leave preview, CI results reach a session through the `test-listener.sh --trigger ci` journal (pulled on the next tick) or through a Routine that runs the review.

## Remote Control

A local session connected to Remote Control can list and message your cloud sessions and your sessions on other machines. Two settings matter for blitz:

- `isolatePeerMachines: true` requires your approval before any message leaves the machine, even in bypass-permissions mode.
- `/list-agents` withholds local working directories and unattributed names while Remote Control is connected; `/blitz:sessions list` reads the local records directly and is unaffected.

## Checklist before the first unattended run

- [ ] `/blitz:doctor` reports no FAIL findings and the `/verify` recipe exists.
- [ ] `.claude/settings.json` sets `crossSessionInbound`, `isolatePeerMachines`, and allow rules for the tools the loop needs (`Workflow(<name>)` if the skills dispatch plugin workflows).
- [ ] `/goal` line printed by build / next is pasted into the coordinator thread, or the Stop gate alone is accepted as the terminating condition.
- [ ] Journal restore (TIA, ratchet) is wired.
- [ ] Inbox triage is read by someone: `/blitz:sessions attention` on a schedule, or the Routine's completion notification.
