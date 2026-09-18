---
id: E-046
title: "Cloud threads, routines, channels posture"
status: implemented
implemented_in: "2.5.0"
priority: P2
phase: 3
domain: session
depends_on: [E-041]
cc_floor: "2.1.271"
estimated_stories: 5
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-046 Cloud threads, routines, channels posture

**Why.** Claude Projects (2026-09-17) turns a project into a coordinator plus threads, where each thread is an independent Claude Code cloud session on its own branch with shared project memory and a configurable check-in cadence. That is sprint-dev's wave model, hosted. Scheduling has split into `/loop` (session), Desktop tasks (machine), and Routines (cloud, 1 h minimum); Channels (research preview) push CI and webhook events into a running session instead of polling. blitz documents none of this and still references agent-team tooling that is experimental and off by default.

## Stories

### S1 blitz-on-Projects guide
- **Files:** new `docs/guides/cloud-threads.md`; `README.md` §Parallel Sessions; `skills/_shared/agent-orchestration.md` §Agent-View.
- **Change:** map sprint-dev waves → threads (one branch each, `sprint-N/<lane>` naming unchanged), orchestrator → coordinator, KNOWLEDGE.md → project memory pointer, `/goal` check-in cadence → project check-in setting. State what does not transfer: `.cc-sessions/` is per-checkout, so cross-thread awareness relies on the activity feed committed to the branch or on messaging (same container only).
- **Acceptance:** doc reviewed against a real Project run once local execution ships.

### S2 Routines for nightly hygiene
- **Files:** `skills/code-sweep/SKILL.md`, `skills/dep-health/SKILL.md`, `skills/quality-metrics/SKILL.md` (loop sections); `skills/_shared/session-lifecycle.md` §Scheduling.
- **Change:** each loop-compatible skill documents its `/schedule` form (Routine, 1 h minimum, fresh clone, no permission prompts) and its Desktop-task form; `/loop` guidance moves to "dedicated session, `.claude/loop.md` carries the prompt, 7-day expiry".
- **Acceptance:** a Routine running `/blitz:code-sweep --loop-tick` completes without prompting.

### S3 Channels for CI push
- **Files:** `skills/_shared/session-lifecycle.md` §Scheduling; `skills/_shared/security.md`.
- **Change:** describe the webhook-receiver pattern (research preview, opt-in with `--channels`, org `channelsEnabled` / `allowedChannelPlugins`, sender allowlist, permission relay). Position it as the replacement for `Monitor`-based CI polling once out of preview. Security: inbound channel text is untrusted (TB-1) and can never approve.
- **Acceptance:** doc only; no plugin code depends on channels.

### S4 Retire unverified tool references
- **Files:** `skills/setup/SKILL.md:102`; `skills/_shared/agent-orchestration.md:1077,1402-1409`; `skills/_shared/sprint-contracts.md:880`; `skills/sprint-dev/SKILL.md`, `skills/ship/SKILL.md`.
- **Change:** verify `TeamCreate`, `PushNotification`, and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` on a live 2.1.276 session (`/list-agents`, tool listing). Replace remote alerting with cross-session `SendMessage` to a named "watch" session and with Routine/Channel notifications; keep agent teams as "experimental, disabled by default, not adopted".
- **Acceptance:** `grep -rn "TeamCreate\|PushNotification" skills agents` returns only a historical note.

### S5 Remote Control posture
- **Files:** `skills/_shared/session-lifecycle.md`; `README.md`.
- **Change:** document that a session connected to Remote Control can list and message cloud sessions, that `isolatePeerMachines: true` requires approval before any cross-machine message, and that `/list-agents` withholds local details while connected.

## Verification
- `markdown-link-validate.sh`; validator sweep.

## Risks
- Projects local execution is "coming very soon"; S1 may need a second pass.
- Channels are a research preview; keep every reference labeled as such.
