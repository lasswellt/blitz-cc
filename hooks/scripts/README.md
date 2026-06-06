# Hook Scripts

36 scripts wired through `hooks/hooks.json`, covering 16 hook events. Every script reads its trigger from stdin (or runs unconditionally on `SessionStart`/`PreCompact`-style events). All exit non-blocking by default; the BLOCKING scripts (exit 2) are: `pre-commit-validate.sh`, `pre-edit-guard.sh`, `task-completed-validate.sh`, `reference-compression-validate.sh`, `skill-frontmatter-validate.sh`, `agent-frontmatter-validate.sh`, `post-edit-typecheck-block.sh`, plus 6 anti-shortcut blockers (`block-no-verify.sh`, `block-destructive-git.sh`, `block-destructive-sql.sh`, `block-test-deletion.sh`, `block-test-disabling.sh`, `block-as-any-insertion.sh`). `workflow-guard.sh` is a WARNER (not a blocker — tracks phase execution order and emits warnings).

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
| `post-tool-batch.sh` | Logs batch completion. Stub — logging only; future: single batched ratchet check instead of per-edit. |

### `PostToolUseFailure` — fires on tool failure

| Script | Purpose |
|---|---|
| `post-tool-failure.sh` | Logs tool name + failure. Stub — logging only; future: auto-recover from common failure modes. |

### `StopFailure` — fires when a turn ends via API error (rate_limit / billing_error / etc.)

| Script | Purpose |
|---|---|
| `stop-failure.sh` | Logs failure_type to activity feed. Stub — logging only; future: write advisories to KNOWLEDGE.md. |

### `Stop` — intentionally not wired

No plain `Stop` hook is registered. Turn-end state persistence is handled out-of-band: `PreCompact` snapshot/handoff + the always-on activity-feed protocol (model-written, see CLAUDE.md). A `Stop` hook would only add another logging stub (cf. `stop-failure.sh`, `subagent-stop.sh`), so it is omitted by design. `StopFailure` (API-error turn end) and `SubagentStop` are wired because they capture states the activity-feed protocol cannot.

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

- **Stdin contract** — `PreToolUse` / `PostToolUse` / `UserPromptExpansion` hooks receive a JSON blob on stdin (`{"tool_name": ..., "tool_input": {...}}`). Other events pass minimal context.
- **Repo root discovery** — every script walks up from `pwd` to the nearest `.claude-plugin/` directory; falls back to `pwd`. Never hardcodes a path.
- **Non-blocking default** — all scripts `exit 0` on success. Only `pre-commit-validate.sh`, `pre-edit-guard.sh`, `task-completed-validate.sh`, `reference-compression-validate.sh`, and `skill-frontmatter-validate.sh` can return exit 2 to block the originating action.
- **Activity-feed appends** — when a hook needs to record an event, it writes a single JSONL line to `.cc-sessions/activity-feed.jsonl` per the format in `skills/_shared/terse-output.md`. Use `jq -nc` to build the JSON (never `printf` — escaping bugs).
- **Quiet by default** — hook scripts only emit output when there is something the user must see. Otherwise stay silent.

## Adding a new hook

1. Drop the script under `hooks/scripts/` with executable bit set (`chmod +x`).
2. Wire it into `hooks/hooks.json` under the appropriate event + matcher.
3. Add a row to the table above.
4. Test with a manual invocation (mock stdin via `echo '{"tool_name":"Bash"...}' | hooks/scripts/your-hook.sh`).
