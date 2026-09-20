# Hook Scripts

Every script reads its trigger JSON from stdin, sources `_lib/common.sh`, and exits 0 unless it is listed as BLOCKING below (exit 2 with the reason on stderr). Wiring lives in `hooks/hooks.json`; the generated component list is `docs/CATALOG.md` (`scripts/gen-catalog.sh`). Authoring contract: `.claude/rules/hooks.md`. Security posture: `skills/_shared/security.md` §4.

Hooks require bash on the host (Git Bash or WSL on native Windows; without it the guards fail open). Command guards match `Bash|PowerShell` so the PowerShell tool is covered.

## Blocking scripts

| Script | Event | Blocks when |
|---|---|---|
| `kill-switch.sh` | `PreToolUse` (every tool) | `.cc-sessions/STOP` exists (remove the file to resume) |
| `tasks-guard.sh` | `PreToolUse` `Write\|Edit\|NotebookEdit`, `Bash\|PowerShell` | a write targets `docs/plans/<slug>/tasks.json` other than through `scripts/tasks.sh` |
| `pre-edit-guard.sh` | `PreToolUse` `Write\|Edit` | the target is `.git/`, `node_modules/`, `.env`, a lockfile, or a `.cc-sessions/*.lock` |
| `block-no-verify.sh` | `PreToolUse` `Bash\|PowerShell` | `git commit --no-verify` / `-n` / gpg-sign bypasses (`BLITZ_OVERRIDE_NO_VERIFY=1` escape) |
| `block-destructive-git.sh` | `PreToolUse` `Bash\|PowerShell` | `reset --hard`, `clean -f`, `checkout .`, force-push to main on a dirty tree |
| `block-destructive-sql.sh` | `PreToolUse` `Bash\|PowerShell` | `DROP`, `TRUNCATE`, `DELETE` without `WHERE` outside migrations |
| `block-test-deletion.sh` | `PreToolUse` `Bash\|PowerShell`, `Write\|Edit` | `rm`/`git rm` of test files, or a test file emptied |
| `block-test-disabling.sh` | `PreToolUse` `Write\|Edit` | `.skip` / `.only` / `xit` insertions (`// blitz:skip-pinned:` escape; `BLITZ_DISABLE_TEST_DISABLING_BLOCK=1`) |
| `block-as-any-insertion.sh` | `PreToolUse` `Write\|Edit` | `as any` / `@ts-ignore` insertions in TS (`// blitz:any-allowed:` escape; `BLITZ_DISABLE_AS_ANY_BLOCK=1`) |
| `pre-commit-validate.sh` | `PreToolUse` `Bash\|PowerShell` on `git commit` | staged SKILL.md frontmatter violations, version drift on a bump commit, registry schema violations |
| `post-edit-typecheck-block.sh` | `PostToolUse` `Write\|Edit` | the edit adds type errors over the session baseline (`BLITZ_DISABLE_TYPECHECK_BLOCK=1`) |
| `stop-gate.sh` | `Stop` | a `gate.json` is armed for the session and a check fails (stands down on `stop_hook_active`, terminal markers, or `max_blocks`) |

## Non-blocking scripts

| Script | Event | Purpose |
|---|---|---|
| `session-start.sh` | `SessionStart` | owns `.cc-sessions/sessions/<session_id>.json`; surfaces `HANDOFF.json` (≤24 h); replays the sanitized feed tail; stale-session sweep; runs `startup-validate.sh` |
| `blitz-prompt-expansion.sh` | `UserPromptExpansion` `blitz:.*` | injects the feed tail, peer sessions, and inbox count into `/blitz:*` invocations |
| `post-edit-format.sh` | `PostToolUse` `Write\|Edit` | prettier/biome format, then eslint/biome lint on code files; remaining lint output returned as context |
| `post-edit-test.sh` | `PostToolUse` `Write\|Edit` | records the edited path in `sessions/<sid>/touched.txt` for the heartbeat's test selection |
| `skill-frontmatter-validate.sh --all`, `agent-frontmatter-validate.sh --all` | `PostToolUse` `Write\|Edit` (async) | authoring-contract lint for `skills/**/SKILL.md` and `agents/*.md` |
| `heartbeat.sh` | `PostToolBatch` | `state: working`; runs the selected tests for touched files (`scripts/test-selector.sh` → `test-listener.sh`); ≤10-line failure digest (`BLITZ_TIA_DISABLE=1`) |
| `stop-turn.sh` | `Stop` | `state: idle`; drains `mailbox/<sid>.jsonl` to the messaging socket (auth line from `CLAUDE_CODE_MESSAGING_TOKEN`) |
| `stop-failure.sh` | `StopFailure` | inbox `hook_failure` line when a turn dies on an API error |
| `session-end.sh` | `SessionEnd` | closes the record, releases owned locks |
| `pre-compact-snapshot.sh` | `PreCompact` | writes `HANDOFF.json` (plan, task, gate path, never-edit list, branch, uncommitted) |
| `notification-log.sh` | `Notification` | routes `needs_input` / `permission` notifications to `inbox.jsonl` |
| `permission-denied.sh` | `PermissionDenied` | inbox `permission_denied` line; never emits `retry` |
| `config-change.sh` | `ConfigChange` | re-runs `startup-validate.sh --strict --quiet` |
| `subagent-context.sh` | `SubagentStart` (`^blitz:(dev|test-writer)$`) | injects `skills/_shared/spawn-invariant.md` as `additionalContext`: the invariant half of the 11-item spawn spec. Static by construction — never interpolate a timestamp, session id or command output, or the per-spawn cache benefit is lost. Cannot block a spawn. (`BLITZ_DISABLE_SPAWN_INVARIANT=1`) |
| `worktree-remove.sh` | `WorktreeRemove` | logs; deletes a merged agent branch (`BLITZ_SKIP_BRANCH_CLEANUP=1`). Always exits 0: a non-zero exit **fails the removal** when the directory still exists. |
| `markdown-link-validate.sh` | `PreToolUse` on `git commit` | warns on broken relative `.md` links and anchors under `skills/` and `agents/`; CI runs it blocking |

### Events blitz deliberately does not register

| Event | Why not |
|---|---|
| `WorktreeCreate` | Configuring it **replaces** the platform's `git worktree` creation entirely. The hook owns the checkout, must print the created directory as the last non-empty line of stdout, and "if the hook fails or produces no path, worktree creation fails with an error". A configured hook also makes the platform skip `.worktreeinclude`. There is no observe-only mode, and its only event-specific input field is `name` (a slug), not `worktree_path` or `branch`. blitz registered a logging-only handler through 3.0.1, which broke `claude --worktree`, every `isolation: worktree` subagent, and background-session isolation in consumer projects. The stale-branch collision guard moved to `doctor` D-314 and `build` Phase 0.4. `hooks/tests/worktree.bats` keeps it deregistered. |

## Sub-invoked and spawned

| Script | Called by | Purpose |
|---|---|---|
| `startup-validate.sh` | `session-start.sh`, `config-change.sh` | shape + injection scan of `.cc-sessions/*.json`, `docs/plans/*/tasks.json` (`done ⇒ passes`, known `origin`, non-empty `verify[]`), `docs/solutions/*.md`, feed tail; quarantine findings to the inbox |
| `check-registry-validate.sh` | `pre-commit-validate.sh`, CI | schema lint for `skills/_shared/check-registry.json` |
| `../../scripts/count-tokens.sh` | `doctor`, CI, manual | authoritative Claude token counts via `messages.count_tokens`, cached by content hash in `.cc-sessions/token-counts.json`. `--calibrate` prints the measured bytes-per-token and the safe body cap at the worst observed ratio. Exits 3 with clearly-marked byte estimates when no credential is available. **Never substitute tiktoken or any local BPE library**: they are OpenAI's and undercount Claude by ~15-20% on prose and more on code, which is what this repo measures. |
| `../../scripts/toolchain.sh` | `post-edit-format.sh`, `post-edit-typecheck-block.sh`, `detect-stack.sh`, `doctor` | resolves a lane (`format`/`lint`/`typecheck`) + file extension to an argv from `templates/toolchain.default.json`. The rows are data; this is the only executor. A project may `disable`/`prefer` rows in `.blitz-toolchain.json` but may never supply a `cmd` (TB-1: the checkout is untrusted inbound data). |
| `critic-external.sh` | `agents/critic.md` when `BLITZ_CRITIC_PROVIDER`, `BLITZ_CRITIC_PANEL`, `BLITZ_USE_GEMINI_CRITIC=1` or `BLITZ_DUAL_CRITIC=1` is set | cross-model critic pass through a non-Claude CLI: `gemini`, `agy` (Antigravity), `copilot` (GitHub Copilot). Per provider `BLITZ_<P>_BIN`, `BLITZ_<P>_MODEL`, `BLITZ_<P>_FLAGS` (newline-split, never space-split). A panel merges verdicts under **any REJECT blocks**; a provider that cannot answer lands in `errors[]` and never decides the gate alone |
| `critic-gemini.sh` | legacy callers | back-compat shim that pins `critic-external.sh --provider gemini`; flags, env and exit codes unchanged |

## Conventions

- Common stdin fields on every event: `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `effort.level`, `hook_event_name`; `agent_id` / `agent_type` in subagent context. `${CLAUDE_PROJECT_DIR}` stays at the launch root inside a worktree; read `cwd` for the worktree path.
- State helpers in `_lib/common.sh`: `blitz_session_update`, `blitz_inbox_append`, `blitz_mailbox_send`, `blitz_log_event`, `blitz_atomic_write`, `blitz_agent_view`. Every stdin or file field is untrusted (`BLITZ_INJECTION_RX`, 200-char echo cap).
- Tests: `bats hooks/tests/` (`_helpers.bash`: `setup_fake_repo`, `run_hook`, `feed_events`, `assert_blocks`, `assert_allows`).
- Environment overrides read by shell: `BLITZ_OVERRIDE_NO_VERIFY`, `BLITZ_DISABLE_TYPECHECK_BLOCK`, `BLITZ_DISABLE_AS_ANY_BLOCK`, `BLITZ_DISABLE_TEST_DISABLING_BLOCK`, `BLITZ_TASKS_GUARD_OFF`, `BLITZ_TIA_DISABLE`, `BLITZ_ALLOW_WORKTREE_COLLISION`, `BLITZ_SKIP_BRANCH_CLEANUP`, `BLITZ_GEMINI_*`, `BLITZ_USE_GEMINI_CRITIC`, `BLITZ_DUAL_CRITIC`, `BLITZ_OUTPUT_FORMAT`, `BLITZ_PLANS_DIR`. Read by skills: `BLITZ_DISPATCH`, `BLITZ_AUTONOMOUS`, `BLITZ_BASE`, `BLITZ_REVIEW_SEQUENTIAL`, `BLITZ_FIX_ROUNDS_MAX`.
