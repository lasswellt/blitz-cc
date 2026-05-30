# Agent-View Dispatch + Background-Session Interop

How blitz skills run as **background sessions** under Claude Code's native agent view (`claude agents`, CC >=2.1.139, research preview), and how blitz's parallel-session machinery interops with the platform. Provenance: `docs/_research/2026-05-30_parallel-claude-sessions.md` (deliverables A/C/D).

Blitz does **not** reimplement the agents view, recaps, or terminal multiplexing — the platform owns those. This doc covers the interop blitz does own: dispatch ergonomics, row-summary quality, worktree reconciliation, the conflict overlay, and remote alerts.

## Dispatching a blitz skill as a background agent

blitz skills (`/blitz:*`) and agents (`@backend-dev` etc.) are valid agent-view dispatch targets with zero extra code:

```bash
claude --bg "/blitz:audit"                       # dispatch a skill to the background
claude --bg --name "audit-q2" "/blitz:audit"     # named row in agent view
claude --agent backend-dev --bg "implement CAP-12"   # run a blitz agent as the main session agent
```
Or interactively: open `claude agents`, type `/blitz:audit` in the dispatch input, press Enter. From inside a running session: `/bg` (alias `/background`) to background the current conversation.

Manage from the shell: `claude attach <id>`, `claude logs <id>`, `claude stop <id>`, `claude respawn <id>`, `claude rm <id>`, `claude daemon status`.

**Version floor:** agent view v2.1.139+; `claude agents --json` / `--cwd` v2.1.141+; `worktree.bgIsolation` v2.1.143+; `--agent` dispatch honoring blitz agent defs v2.1.157+. All blitz interop degrades silently below these floors.

## Row-summary quality (orchestrators show as ONE row)

Agent view shows each background session as one row whose one-line summary is **Haiku-generated from recent output** (refresh ≤15s + at each turn end). Subagents and Workflow agents a session spawns are **not** separate rows — a blitz orchestrator (sprint-dev, audit, research) appears as a single row.

Implication: the orchestrator's row can look idle while its fan-out agents work. Mitigation — the [verbose-progress.md](verbose-progress.md) current-phase one-liner is what the Haiku summarizer reads. Emit it frequently and make it carry fan-out state (e.g. `sprint-dev wave 2/3 · 4/7 stories done`) so the row reads true. This is already the verbose-progress contract; background dispatch makes it load-bearing.

## Worktree isolation interop

Background sessions auto-isolate into `.claude/worktrees/<id>` before editing — the same dir blitz `Agent({isolation:"worktree"})` worktrees use. The reconciliation (live-session prune guard, collision-guard scope, `worktree.bgIsolation: "none"` escape hatch) is specified in [worktree-lifecycle.md](worktree-lifecycle.md) §Interop. Never prune a live background session's worktree — it holds uncommitted work.

## Cross-session conflict overlay

The platform manages session *processes* but does **not** do semantic conflict detection. blitz's conflict matrix still applies — and is extended to background sessions via [session-protocol.md](session-protocol.md) §5b-i (reads `claude agents --json`, infers skill from session name, WARNs on matrix hits). This is blitz's durable value-add over native.

## Remote alerts

Native agent view shows a *local* "Needs input" indicator + tab-title count. For **off-screen** alerts (phone), blitz fires `PushNotification` (no-op if Remote Control unconfigured) at genuine human-escalation points only — to avoid notification fatigue:
- Stuck-loop PAUSE — [spawn-protocol.md](spawn-protocol.md) §Stuck-loop detection step 3.
- Deviation Tier-3 ESCALATE — [deviation-protocol.md](deviation-protocol.md) §Orchestrator Handling.

Both gate on the developer-profile `notify` preference (`.cc-sessions/developer-profile.json`; skip when `notify: off`). Completion pushes (sprint-dev, ship) are unchanged.

For an idle terminal bell (the article's "audio signal via hooks"), set `BLITZ_NOTIFY_ON_IDLE=1` — `hooks/scripts/teammate-idle.sh` emits `\a` on `TeammateIdle`. Default off. A hook cannot invoke `PushNotification` (agent-side only), so the bell is the hook-level mechanism.

## Disable

`disableAgentView` setting / `CLAUDE_CODE_DISABLE_AGENT_VIEW=1` turns agent view off. blitz interop (prune live-guard, conflict overlay) then degrades to `.cc-sessions/*.json`-only; `/blitz:health` Phase 2.5 warns when disabled.

## Cross-references

- [worktree-lifecycle.md](worktree-lifecycle.md) §Interop — worktree reconciliation + live-session guard
- [session-protocol.md](session-protocol.md) §5b-i — conflict overlay
- [spawn-protocol.md](spawn-protocol.md), [deviation-protocol.md](deviation-protocol.md) — remote alert points
- [verbose-progress.md](verbose-progress.md) — row-summary source
- Research provenance: `docs/_research/2026-05-30_parallel-claude-sessions.md`
