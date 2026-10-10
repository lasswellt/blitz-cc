# blitz-guard

Optional [Claude Mod](https://code.claude.com/docs/en/plugins/mods/overview) for the blitz plugin. It adds checks that a shell hook cannot make, on top of blitz's bash hooks, which stay the baseline.

| Event | What it does |
|---|---|
| `agent.spawn` | Refuses a `blitz:*` agent that would start as an agent-team teammate (it would lose its `skills` preload and could not be resumed). Moves a `blitz:*` agent named on haiku to its routing default (`agents.md` §1.3); a workflow agent, whose spawn cannot be rewritten, is refused and the skill falls back to its `Agent()` path. |
| `tool.check` | Inside a `blitz:critic`, `blitz:research-critic` or `blitz:design-critic` loop (matched by `agentId`), refuses `Write`/`Edit`/`NotebookEdit` and shell that writes: git writes, `rm`/`mv`/`cp`, in-place edits, package installs, redirection outside `/tmp` and `/dev/null`, `tasks.sh init|add|set`, `find -delete`/`-exec rm`, `xargs` into a writer, and interpreter one-liners that write files. `sh -c`/`bash -c` payloads are checked recursively; `eval`, `source` and commands taken from a variable are refused outright because their text does not show what runs. `tasks.sh verify` and read-only commands pass. |
| `tool.call` on `Agent` | Raises a `blitz:dev`, `blitz:test-writer` or `blitz:critic` call made below `medium` effort to `medium` (the Agent tool's `effort` is rewritable here; `agent.spawn` has no effort field). An absent effort is left to the agent file's `effort:`. Workflow agents do not pass through this hook. |
| `turn.complete` | Appends each subagent run's final token counts to `.cc-sessions/agent-usage.mod.jsonl`. blitz's SubagentStop hook prices runs from their transcripts, whose output counts are streaming snapshots; the dashboard uses these final counts where they exist. |
| status line | `blitz <slug> 3/7 · T-004 running · 1 blocked` from the newest unfinished `docs/plans/*/tasks.json`, refreshed after each `scripts/tasks.sh` call. |

## Install

```
/plugin install blitz-guard --marketplace lasswellt/blitz-cc
```

Requires Claude Code 2.1.287 or later (mods); blitz itself requires 2.1.296.

## What it is not

- **Not a boundary.** A mod is unsandboxed JavaScript running with your privileges, and `--bare`, `--safe-mode` and `disableAllHooks` switch it off. The shell checks match command text: they unwrap `sh -c` and refuse `eval` and variable-led commands, and refuse running files from temp directories, but the commands a plan itself declares (a task's `verify[]` through `tasks.sh`, `npm run build`) can still write, by design. blitz's bash hooks, the permission rules, auto mode and the sandbox remain the layers that hold.
- **Effort: a floor, not a router.** It only raises a too-low effort on the Agent call. Workflow agents are not covered (their `agent()` options cannot be rewritten), and the floor relies on Claude Code honouring a rewritten `effort`, which the plugin test confirms reaches the engine but no live run has confirmed takes effect.
- **Fail-open outside critics.** If a hook throws, spawns and non-critic tool calls proceed as without the mod; a failed check inside a known critic loop refuses.

## Develop

```bash
claude plugin validate mods/blitz-guard
claude plugin test mods/blitz-guard
claude --plugin-dir ./mods/blitz-guard    # one session, hot-reloads on save
```

`hooks/policy.ts` holds every rule as a pure function; `hooks/register.ts` wires them to events.
