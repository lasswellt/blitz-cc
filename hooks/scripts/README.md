# Hook Scripts

Every script reads its trigger JSON from stdin, sources `_lib/common.sh`, and exits 0 unless it is listed as BLOCKING below (exit 2 with the reason on stderr). BLOCKING PreToolUse guards fail closed: `hooks.json` gives them `onFailure: "block"` (Claude Code ≥2.1.295), so a crash or timeout blocks the call, and each guard that reads its payload calls `blitz_guard_input` first, which exits 2 when jq is missing or the payload is not JSON (`BLITZ_GUARD_FAIL_OPEN=1` in the launch environment opts out; `kill-switch.sh` reads a file, not the payload). Advisory hooks stay fail-open. Wiring lives in `hooks/hooks.json`; the generated component list is `docs/CATALOG.md` (`scripts/gen-catalog.sh`). Authoring contract: `.claude/rules/hooks.md`. Security posture: `skills/_shared/security.md` §Guard posture; the hook trust boundary is `skills/_shared/security.reference.md` §Hook Trust Boundary (TB-1).

Hooks require bash on the host (Git Bash or WSL on native Windows). Without it no hook can start: the blocking guards fail closed and refuse every Write, Edit and Bash call, the advisory hooks silently do nothing. Command guards match `Bash|PowerShell` so the PowerShell tool is covered.

## Blocking scripts

| Script | Event | Blocks when |
|---|---|---|
| `kill-switch.sh` | `PreToolUse` (every tool) | `.cc-sessions/STOP` exists (remove the file to resume) |
| `tasks-guard.sh` | `PreToolUse` `Write\|Edit\|NotebookEdit`, `Bash\|PowerShell` | a write targets `docs/plans/<slug>/tasks.json` other than through `scripts/tasks.sh`; in subagent context (stdin `agent_type` set) also a write to `docs/plans/<slug>/progress.md`, the main thread's ledger, by file tool or shell |
| `pre-edit-guard.sh` | `PreToolUse` `Write\|Edit` | the target is `.git/`, `node_modules/`, `.env*` (except `.development` and `.example`), a package lockfile, or a key/credential file |
| `block-no-verify.sh` | `PreToolUse` `Bash\|PowerShell` | `git commit --no-verify` / `-n` (`BLITZ_OVERRIDE_NO_VERIFY=1` escape, logged) |
| `block-destructive-git.sh` | `PreToolUse` `Bash\|PowerShell` | `reset --hard`, `clean -f`, `checkout .` / `restore .` on a dirty tree; force-push to a protected branch and `branch -D` of the current branch always |
| `block-destructive-sql.sh` | `PreToolUse` `Bash\|PowerShell` | `DROP`, `TRUNCATE`, `DELETE` without `WHERE` outside migrations |
| `block-test-deletion.sh` | `PreToolUse` `Bash\|PowerShell`, `Write\|Edit` | `rm`/`git rm` of test files, or a test file emptied |
| `block-test-disabling.sh` | `PreToolUse` `Write\|Edit` | `.skip` / `.only` / `xit` insertions (`// blitz:skip-pinned:` escape; `BLITZ_DISABLE_TEST_DISABLING_BLOCK=1`) |
| `block-as-any-insertion.sh` | `PreToolUse` `Write\|Edit` | `as any` / `@ts-ignore` insertions in TS (`// blitz:any-allowed:` escape; `BLITZ_DISABLE_AS_ANY_BLOCK=1`) |
| `pre-commit-validate.sh` | `PreToolUse` `Bash\|PowerShell` on `git commit` | a staged secret file, staged SKILL.md frontmatter violations, version drift on a bump commit, registry schema violations, a protocol head over its byte cap, a missing `.reference.md` sibling, an unresolved section citation. Banned patterns and broken links warn only. Fail-closed like the other guards (`blitz_guard_input`, `onFailure: block`) |
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
| `pre-compact-snapshot.sh` | `PreCompact` | writes `HANDOFF.json` with `jq -n` (plan, task, gate path, never-edit list, branch, uncommitted) |
| `notification-log.sh` | `Notification` | routes `needs_input` / `permission` notifications to `inbox.jsonl` |
| `permission-denied.sh` | `PermissionDenied` | inbox `permission` line and a `permission_denied` feed event; never emits `retry` |
| `config-change.sh` | `ConfigChange` | re-runs `startup-validate.sh --strict --quiet` |
| `subagent-context.sh` | `SubagentStart` (`^blitz:(dev|test-writer)$`) | injects `skills/_shared/spawn-invariant.md` as `additionalContext`: the invariant half of the 11-item spawn spec. Static by construction: never interpolate a timestamp, session id or command output, or the per-spawn cache benefit is lost. Cannot block a spawn. (`BLITZ_DISABLE_SPAWN_INVARIANT=1`) |
| `subagent-usage.sh` | `SubagentStop` (async) | reads the finished subagent's `agent_transcript_path`, groups API responses by message id, prices input, output, cache reads and 5m/1h cache writes from `_lib/model-prices.json` (Haiku long-context multiplier per request), and appends one row to `.cc-sessions/agent-usage.jsonl` with plan and task taken from the prompt; `output_final: false` marks a streaming lower bound. Advisory: always exits 0. |
| `worktree-remove.sh` | `WorktreeRemove` | logs; deletes a merged agent branch (`BLITZ_SKIP_BRANCH_CLEANUP=1`). Always exits 0: a non-zero exit **fails the removal** when the directory still exists. |
| `markdown-link-validate.sh` | via `pre-commit-validate.sh` on `git commit` | warns on broken relative `.md` links and heading anchors under `skills/` and `agents/`; CI runs it blocking |

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
| `critic-external.sh` | the `check` skill (§Critic effort and external claims) when `BLITZ_CRITIC_PROVIDER`, `BLITZ_CRITIC_PANEL`, `BLITZ_USE_GEMINI_CRITIC=1` or `BLITZ_DUAL_CRITIC=1` is set; contract in `agents/critic.md` §8 | cross-model critic pass through a non-Claude CLI: `gemini`, `agy` (Antigravity), `copilot` (GitHub Copilot), `codex` (OpenAI Codex, read-only sandbox). `--mode pre-pass --plan --tasks --base` builds the header critic.md requires; every prompt carries `PLUGIN_ROOT`. Per provider `BLITZ_<P>_BIN`, `BLITZ_<P>_MODEL`, `BLITZ_<P>_FLAGS` (newline-split, never space-split). A pre-pass REJECT, single provider or panel, exits 3 as a claim for the in-Claude critic to reproduce (`BLITZ_CRITIC_EXTERNAL_VETO=1` restores exit 2); a provider that cannot answer lands in `errors[]` and never decides the gate alone |
| `critic-gemini.sh` | legacy callers | back-compat shim that pins `critic-external.sh --provider gemini`; flags and env unchanged, exit codes follow `critic-external.sh` (0 LGTM, 3 pre-pass REJECT to confirm, 2 research/design block or veto mode, 1 failure) |
| `_lib/html.sh` | `scripts/sessions-dashboard.sh --html`, the `audit` skill's HTML twin | `emit_html()` and `sanitize_html()`; the HTML side-output contract lives in its header |
| `tests/test-link-resolver.sh` | CI, `scripts/ci-local.sh` | exercises the `/_shared/` link resolution the validators rely on |

## Conventions

- Common stdin fields on every event: `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `effort.level`, `hook_event_name`; `agent_id` / `agent_type` in subagent context. `${CLAUDE_PROJECT_DIR}` stays at the launch root inside a worktree; read `cwd` for the worktree path.
- State helpers in `_lib/common.sh`: `blitz_session_update`, `blitz_inbox_append`, `blitz_mailbox_send`, `blitz_log_event`, `blitz_atomic_write`, `blitz_agent_view`. Every stdin or file field is untrusted (`BLITZ_INJECTION_RX`, 200-char echo cap).
- Tests: `bats hooks/tests/` (`_helpers.bash`: `setup_fake_repo`, `run_hook`, `feed_events`, `assert_blocks`, `assert_allows`, `nojq_path`).
- Environment overrides read by hooks and scripts. Guards: `BLITZ_OVERRIDE_NO_VERIFY` (logged), `BLITZ_DISABLE_TYPECHECK_BLOCK`, `BLITZ_DISABLE_AS_ANY_BLOCK`, `BLITZ_DISABLE_TEST_DISABLING_BLOCK`, `BLITZ_TASKS_GUARD_OFF`, `BLITZ_DISABLE_POST_EDIT_FORMAT`, `BLITZ_DISABLE_SPAWN_INVARIANT`, `BLITZ_TIA_DISABLE`, `BLITZ_SKIP_BRANCH_CLEANUP`, `BLITZ_GUARD_FAIL_OPEN` (launch environment only). Critic: `BLITZ_CRITIC_PROVIDER`, `BLITZ_CRITIC_PANEL`, `BLITZ_CRITIC_ARG_CAP`, `BLITZ_CRITIC_NO_REDACT`, `BLITZ_CRITIC_EXTERNAL_VETO`, `BLITZ_{GEMINI,AGY,COPILOT,CODEX}_{BIN,MODEL,FLAGS}`. Paths and caps: `BLITZ_PLANS_DIR`, `BLITZ_SESSIONS_DIR`, `BLITZ_ROOT`, `BLITZ_TOOLCHAIN_TABLE`, `BLITZ_OUTPUT_FORMAT`, `BLITZ_LINT_ECHO_CAP`, `BLITZ_SKILL_BODY_CAP`, `BLITZ_VERIFY_EVIDENCE_CAP`, `BLITZ_LOOP_NO_PROGRESS_MAX`, `BLITZ_LOOP_SAME_ERROR_MAX`, `BLITZ_COUNT_MODEL`, `BLITZ_IMPECCABLE_GLOBAL_ROOT`, `BLITZ_CTX_CHARS`. Followed by skill prose only (no script reads them): `BLITZ_DISPATCH`, `BLITZ_AUTONOMOUS`, `BLITZ_BASE`, `BLITZ_REVIEW_SEQUENTIAL`, `BLITZ_FIX_ROUNDS_MAX`, `BLITZ_DUAL_CRITIC`, `BLITZ_USE_GEMINI_CRITIC`, `BLITZ_ALLOW_WORKTREE_COLLISION`, `BLITZ_OUTPUT_INTENSITY`, `BLITZ_AUDIT_CONFIDENCE_THRESHOLD`, `BLITZ_RESEARCH_FORCE_INFRA`, `BLITZ_RESEARCH_NO_CRITIC`. Only `BLITZ_OVERRIDE_NO_VERIFY` logs its use.
