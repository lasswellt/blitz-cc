# Hook Scripts

45 scripts in this directory (42 wired through `hooks/hooks.json` across 24 hook events; `check-registry-validate.sh` and `startup-validate.sh` are sub-invoked; `critic-gemini.sh` is critic-spawned). Every script reads its trigger from stdin (or runs unconditionally on `SessionStart`/`PreCompact`-style events). All exit non-blocking by default; the BLOCKING scripts (exit 2) are: `pre-commit-validate.sh`, `pre-edit-guard.sh`, `task-completed-validate.sh`, `reference-compression-validate.sh`, `skill-frontmatter-validate.sh`, `agent-frontmatter-validate.sh`, `post-edit-typecheck-block.sh`, plus 6 anti-shortcut blockers (`block-no-verify.sh`, `block-destructive-git.sh`, `block-destructive-sql.sh`, `block-test-deletion.sh`, `block-test-disabling.sh`, `block-as-any-insertion.sh`) — 7 anti-shortcut hooks counting `post-edit-typecheck-block.sh`. `workflow-guard.sh` is a WARNER (not a blocker — tracks phase execution order and emits warnings).

## By event

### `SessionStart` — fires once per conversation

| Script | Purpose |
|---|---|
| `session-start.sh` | Replays last 10 activity-feed entries, resets per-session context counter, warns on stale (>4h) active sessions |

### `UserPromptExpansion` — fires before each prompt is sent to the model

| Script | Purpose |
|---|---|
| `blitz-prompt-expansion.sh` | Injects recent activity-feed context into every `/blitz:*` invocation so spawned skills see prior session work |

### `PreToolUse` — fires before any tool execution; can BLOCK with exit 2

| Script | Matcher | Purpose |
|---|---|---|
| `pre-edit-guard.sh` | `Write\|Edit` | Blocks edits to protected paths (`.git/`, `node_modules/`, `.cc-sessions/*.lock`) |
| `pre-edit-backup.sh` | `Write\|Edit` | Snapshots file content to `.cc-sessions/backups/` before each edit |
| `pre-commit-validate.sh` | `Bash` | Fires on `git commit`. Validates SKILL.md frontmatter on staged files; calls `check-version-sync.sh`; blocks bump commits with version drift |
| `reference-compression-validate.sh` | `Bash` | Fires on `git commit`. Validates that any compressed `references/main.md` preserves all structure of its `.original` sibling (code fences, URLs, headings, tables) |
| `markdown-link-validate.sh` | `Bash` | Fires on `git commit`. Warns on broken relative `.md` links across `skills/` (skips fenced code, inline code, http URLs, anchors). Non-blocking; pre-commit-validate.sh prints warnings only |
| `workflow-guard.sh` | `Bash` | Detects anti-patterns in shell commands (`rm -rf` outside scratch, `git push --force` to main, etc.) |
| `block-no-verify.sh` | `Bash` | **P0 anti-shortcut**. Blocks `git commit --no-verify` / `--no-gpg-sign` / `-c commit.gpgsign=false` bypasses |
| `block-destructive-git.sh` | `Bash` | **P0 anti-shortcut**. Blocks `git reset --hard`, `git checkout .`, `git restore .`, `git clean -f`, `git push --force` to main, force-deletes of unmerged branches |
| `block-destructive-sql.sh` | `Bash` | **P0 anti-shortcut**. Blocks `DROP TABLE`, `TRUNCATE`, `DELETE FROM` without `WHERE` against production-shaped paths |
| `block-test-deletion.sh` | `Bash` | **P0 anti-shortcut**. Blocks `rm` / `git rm` of test files (`*.test.*`, `*.spec.*`, `__tests__/`) |
| `block-test-disabling.sh` | `Write\|Edit` | **P1 anti-shortcut**. Blocks `it.skip` / `test.skip` / `describe.skip` / `xit` / `xdescribe` / `it.todo` mass-conversions |
| `block-as-any-insertion.sh` | `Write\|Edit` | **P1 anti-shortcut**. Blocks `as any` / `@ts-ignore` / `@ts-expect-error` insertions in TS files |

### `PostToolUse` — fires after any tool execution; non-blocking

| Script | Matcher | Purpose |
|---|---|---|
| `post-edit-activity-log.sh` | `Write\|Edit` | Appends a `file_change` event to `.cc-sessions/activity-feed.jsonl` |
| `post-edit-format.sh` | `Write\|Edit` | Auto-formats edited files via project's formatter (prettier/eslint/biome auto-detect) |
| `post-edit-lint.sh` | `Write\|Edit` | Runs project linter against the edited file; non-blocking (warnings only) |
| `post-edit-test.sh` | `Write\|Edit` | Finds and runs matching test files for the edited source |
| `analysis-paralysis-guard.sh` | `Write\|Edit` `Read\|Glob\|Grep` | Detects long read-heavy phases without writes; nudges toward action |
| `skill-frontmatter-validate.sh` | `Write\|Edit` | Lints any modified SKILL.md against the Anthropic-canonical frontmatter contract |
| `agent-frontmatter-validate.sh` | `Write\|Edit` | Lints any modified `agents/*.md` against the canonical agent frontmatter contract |
| `post-edit-typecheck-block.sh` | `Write\|Edit` | **P0 quality gate**. Runs project type-checker (tsc/pyright/etc.) against the edited file; exit 2 if new type errors introduced (ratchet invariant 6 absolute floor) |
| `context-monitor.sh` | `Read\|Glob\|Grep` `Bash` | Tracks per-session context-character count; warns at 80% of estimated cap |

### `PreCompact` — fires before context compaction

| Script | Purpose |
|---|---|
| `pre-compact-snapshot.sh` | Snapshots current sprint state (`STATE.md`, registry tail, todo list) so a post-compact session can recover |

### `PostCompact` — fires after context compaction completes

| Script | Purpose |
|---|---|
| `post-compact-log.sh` | Logs compaction stats and prints restoration hints to the user |

### `TaskCompleted` — fires when an in-progress task transitions to completed

| Script | Purpose |
|---|---|
| `task-completed-validate.sh` | Validates task completion against the Definition of Done (story-id format check, deliverable checklist) |

### `TeammateIdle` — fires when a sibling agent reports idle (multi-agent runs)

| Script | Purpose |
|---|---|
| `teammate-idle.sh` | Forwards idle events to the activity feed so orchestrators can detect stalls |

### `SubagentStart` — fires when a subagent (Agent tool) spawns

| Script | Purpose |
|---|---|
| `subagent-start.sh` | Logs subagent spawn (agent_id, agent_type) to activity feed. Stub — logging only. |

### `SubagentStop` — fires when a subagent finishes

| Script | Purpose |
|---|---|
| `subagent-stop.sh` | Logs subagent completion to activity feed. Stub — logging only; future: enforce Agent Output Contract (agent-orchestration.md §9). |

### `PostToolBatch` — fires after a parallel tool batch resolves, before next model call

| Script | Purpose |
|---|---|
| `heartbeat.sh` | Marks the session record `state:"working"` + `last_activity` (liveness signal for stale-session detection) and logs batch completion (was `post-tool-batch.sh`). Future: single batched ratchet check instead of per-edit. |

### `PostToolUseFailure` — fires on tool failure

| Script | Purpose |
|---|---|
| `post-tool-failure.sh` | Logs tool name + failure. Stub — logging only; future: auto-recover from common failure modes. |

### `StopFailure` — fires when a turn ends via API error (rate_limit / billing_error / etc.)

| Script | Purpose |
|---|---|
| `stop-failure.sh` | Logs failure_type to activity feed. Stub — logging only; future: write advisories to KNOWLEDGE.md. |

### `Stop` — wired (non-blocking heartbeat + mailbox drain; blocking gate arrives in E-042)

| Script | Purpose |
|---|---|
| `stop-turn.sh` | Turn-end heartbeat: sets record `state:"idle"` + `last_activity`, then drains `.cc-sessions/mailbox/<session_id>.jsonl` to the Claude Code messaging socket (`$CLAUDE_CODE_MESSAGING_SOCKET`, CC >=2.1.224) via `blitz_inbox_post` — auth line then one message per line; undelivered lines are kept, delivered ones truncated, count logged as feed event `mailbox`. Never emits a decision, never reads `last_assistant_message`. `timeout: 20`, `async: false`. |

Rationale: `Stop` is the only event that can deterministically mark a session idle and deliver a mailbox at turn end. The old "would only be a logging stub" argument no longer holds now that session records (E-041) and cross-session messaging exist. The blocking verification gate (`stop-gate.sh`, gate-file driven) lands with E-042 as a separate entry so this script stays a pure heartbeat. A `prompt`-type Stop hook is never used (it would collide with a user `/goal`).

### `SessionEnd` — fires once when the session ends

| Script | Purpose |
|---|---|
| `session-end.sh` | Closes the session record (`.cc-sessions/sessions/<session_id>.json`, or a legacy `.cc-sessions/<x>.json` whose `claude_session_id` matches): `reason` → `status` (`prompt_input_exit`/`other` → `completed`, `resume` → `suspended`, `clear` → `cleared`, `logout` → `logged_out`), sets `ended`; releases every `*.lock` under `.cc-sessions/` whose body names this session (ownership-guarded, never a foreign lock); logs feed event `session_end`. |

### `Notification` — fires when Claude Code shows a notification

| Script | Purpose |
|---|---|
| `notification-log.sh` | `permission*` → `.cc-sessions/inbox.jsonl` item kind `permission`; `*input*` / `idle_prompt` / `elicit*` → kind `needs_input` (text sanitized ≤200 chars + `BLITZ_INJECTION_RX`); both log feed event `needs_input`. Other types log `notification` only. `async`. |

### `PermissionDenied` — fires after a tool call is denied

| Script | Purpose |
|---|---|
| `permission-denied.sh` | Logs feed event `permission_denied` `{tool_name}` + inbox item kind `permission`. **Never emits `hookSpecificOutput.retry`** (containment posture, security.md TB-3): a denied call stays denied. Prints nothing. `async`. |

### `PreModelSwitch` — fires before the model changes

| Script | Purpose |
|---|---|
| `model-switch-warn.sh` | Logs feed event `cache_bust` `{from,to}` and prints a one-line advisory (a model switch resets the prompt cache; set model/effort once per session). Always exit 0 — exit 2 would veto the switch. `timeout: 5`. |

### `CwdChanged` / `DirectoryAdded` — fires on working-directory changes

| Script | Purpose |
|---|---|
| `cwd-changed.sh` | One script, both events (dispatched on `hook_event_name`): `CwdChanged` sets `record.cwd`; `DirectoryAdded` appends `path` to `record.dirs[]` (unique). Logs `cwd_changed` / `directory_added`. No-op on the record when none exists. `async`. |

### `ConfigChange` — fires when settings or skills change

| Script | Purpose |
|---|---|
| `config-change.sh` | TB-2 boundary event: re-runs `startup-validate.sh --strict --quiet` (stdout suppressed), logs feed event `config_change` `{source, validate: pass\|fail}`, prints one warning line only on a strict failure. Always exit 0. `timeout: 60`. |

### `PermissionRequest` — fires when a permission dialog is about to be shown

| Script | Purpose |
|---|---|
| `permission-request.sh` | Logs the tool requesting permission. Stub — logging only; emits NO permissionDecision so the user is still prompted normally. Future: auto-approve safe read-only patterns. |

### `WorktreeCreate` — fires on `--worktree` or `isolation: worktree`

| Script | Purpose |
|---|---|
| `worktree-create.sh` | Logs worktree creation. **Stub — emits nothing to stdout** (would override default worktree path) and exits 0 (non-zero would ABORT worktree creation). |

### `WorktreeRemove` — fires after worktree removal

| Script | Purpose |
|---|---|
| `worktree-remove.sh` | Logs worktree removal. Stub — logging only. |

## Standalone (invoked by skills, not wired to a hook event)

| Script | Invoked by | Purpose |
|---|---|---|
| `critic-gemini.sh` | `sprint-review`, `research` | Optional cross-model critic. Pipes the artifact through Gemini for a second-opinion review; used to mitigate single-model agreement bias. |

## Conventions

- **Stdin contract** — every hook receives one JSON object on stdin. Common fields (CC ≥2.1.271): `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `effort` (`{level}`), `hook_event_name`, plus `agent_id` / `agent_type` in subagent context. Per-event extras: `tool_name` + `tool_input` (`PreToolUse` / `PostToolUse` / `PermissionRequest` / `PermissionDenied`), `reason` (`SessionEnd`: `clear|resume|logout|prompt_input_exit|other`), `stop_hook_active` + `last_assistant_message` (`Stop` — never persisted by blitz), `notification_type` + `message` (`Notification`), `from_model` + `to_model` (`PreModelSwitch`), `new_cwd` (`CwdChanged`), `path` + `method` (`DirectoryAdded`), `source` (`ConfigChange`: `user_settings|project_settings|local_settings|policy_settings|skills`). Read stdin once (`INPUT=$(cat)`) and pull fields with `blitz_extract` from `_lib/common.sh`; scripts must exit 0 on empty stdin.
- **Entry forms in `hooks.json`** — legacy entries use shell form (`"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/scripts/x.sh --flag"`); new entries use exec form (`command` = unquoted executable path, `args` = literal list) with `timeout` (seconds) and `statusMessage`. `if` (permission-rule filter, e.g. `"Bash(git *)"`) gates the five git-only commit guards so non-git Bash calls never spawn them. `scripts/validate-plugin-structure.sh` validates both forms, the `if` shape and integer timeouts. `once` is skill-only and is not used here.
- **Session record + inbox helpers** — `blitz_session_record_path` / `blitz_session_record_find` / `blitz_session_update <sid> <jq-filter>` (atomic, no-op when the record is missing), `blitz_inbox_append <kind> <text> [session]` (`.cc-sessions/inbox.jsonl`), `blitz_inbox_post <text>` (messaging socket; socat → python3 → no-op).
- **Repo root discovery** — every script walks up from `pwd` to the nearest `.claude-plugin/` directory; falls back to `pwd`. Never hardcodes a path.
- **Non-blocking default** — all scripts `exit 0` on success. Only the BLOCKING scripts listed at the top of this file return exit 2 to block the originating action.
- **Activity-feed appends** — when a hook needs to record an event, it writes a single JSONL line to `.cc-sessions/activity-feed.jsonl` per the format in `skills/_shared/terse-output.md`. Use `jq -nc` to build the JSON (never `printf` — escaping bugs).
- **Quiet by default** — hook scripts only emit output when there is something the user must see. Otherwise stay silent.

## Adding a new hook

1. Drop the script under `hooks/scripts/` with executable bit set (`chmod +x`).
2. Wire it into `hooks/hooks.json` under the appropriate event + matcher (exec form: `{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<name>.sh","args":[],"timeout":N,"statusMessage":"..."}`).
3. Add a row to the table above.
4. Test with a manual invocation (mock stdin via `echo '{"tool_name":"Bash"...}' | hooks/scripts/your-hook.sh`).
