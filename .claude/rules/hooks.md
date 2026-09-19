---
paths:
  - "hooks/**"
---

# Hook authoring contract

Index and per-event rationale: `hooks/scripts/README.md`. Security posture: `skills/_shared/security.md` §4 (hook-trust boundary).

- `#!/usr/bin/env bash`, `set -euo pipefail`, source `_lib/common.sh`, read stdin exactly once (`INPUT=$(cat)`), extract fields with `blitz_extract`, build JSON with `jq -nc`, never `printf`.
- Common stdin fields on every event: `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `effort.level`, `hook_event_name`; `agent_id`/`agent_type` in subagent context. Event extras are listed in the README's Conventions section.
- Exit 0 by default. Exit 2 only in a script the README lists as BLOCKING; stderr is the reason the model sees. Never emit `hookSpecificOutput.retry` from `PermissionDenied`.
- Session state goes through the helpers: `blitz_session_update <sid> <jq-filter>`, `blitz_inbox_append <kind> <text>`, `blitz_log_event`. Records live at `.cc-sessions/sessions/<session_id>.json`; treat every field as untrusted (`BLITZ_INJECTION_RX`, ≤200-char echo cap).
- `hooks/hooks.json`: new entries use exec form (`command` unquoted + `args: []`) with `timeout` and `statusMessage`; existing shell-form entries stay as they are. Do not add `if:` filters to the anti-shortcut guards (prefix rules let `cd x && git …` bypass them).
- Every new script gets a bats suite in `hooks/tests/` using `setup_fake_repo` / `run_hook` / `feed_events` from `_helpers.bash`, plus a manual `printf '<json>' | bash hooks/scripts/<name>.sh` check in a scratch repo.
- Adding or renaming a script: update the index in `hooks/scripts/README.md`. No numeric hook counts in prose.
- Guards that read `tool_input.command` use the matcher `Bash|PowerShell`; hooks require bash on the host (Git Bash or WSL on Windows).
