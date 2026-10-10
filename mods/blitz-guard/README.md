# blitz-guard

Optional [Claude Mod](https://code.claude.com/docs/en/plugins/mods/overview) for the blitz plugin. It adds checks that a shell hook cannot make, on top of blitz's bash hooks, which stay the baseline.

| Event | What it does |
|---|---|
| `agent.spawn` | Refuses a `blitz:*` agent that would start as an agent-team teammate (it would lose its `skills` preload and could not be resumed). Moves a `blitz:*` agent named on haiku to its routing default (`agents.md` §1.3); a workflow agent, whose spawn cannot be rewritten, is refused and the skill falls back to its `Agent()` path. |
| `tool.check` | Inside a `blitz:critic`, `blitz:research-critic` or `blitz:design-critic` loop (matched by `agentId`), refuses `Write`/`Edit`/`NotebookEdit` and shell that writes: git writes, `rm`/`mv`/`cp`, in-place edits, package installs, redirection outside `/tmp` and `/dev/null`, and `tasks.sh init|add|set`. `tasks.sh verify` and read-only commands pass. |
| status line | `blitz <slug> 3/7 · T-004 running · 1 blocked` from the newest unfinished `docs/plans/*/tasks.json`, refreshed after each `scripts/tasks.sh` call. |

## Install

```
/plugin install blitz-guard --marketplace lasswellt/blitz-cc
```

Requires Claude Code 2.1.287 or later (mods); blitz itself requires 2.1.296.

## What it is not

- **Not a boundary.** A mod is unsandboxed JavaScript running with your privileges, and `--bare`, `--safe-mode` and `disableAllHooks` switch it off. The shell checks match command text and miss `sh -c '…'`, variables and quoted payloads. blitz's bash hooks, the permission rules, auto mode and the sandbox remain the layers that hold.
- **No effort control.** `agent.spawn` exposes no effort field in Claude Code 2.1.296, so effort stays the spawn's own (`agents.md` §1.3).
- **Fail-open outside critics.** If a hook throws, spawns and non-critic tool calls proceed as without the mod; a failed check inside a known critic loop refuses.

## Develop

```bash
claude plugin validate mods/blitz-guard
claude plugin test mods/blitz-guard
claude --plugin-dir ./mods/blitz-guard    # one session, hot-reloads on save
```

`hooks/policy.ts` holds every rule as a pure function; `hooks/register.ts` wires them to events.
