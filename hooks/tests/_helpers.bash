#!/usr/bin/env bash
# _helpers.bash — shared test utilities for blitz hook bats tests.
#
# Run tests: bats hooks/tests/
# Skip gracefully when bats not installed:
#   command -v bats >/dev/null || { echo "bats not installed; run: npm install -g bats"; exit 0; }

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
export HOOKS_DIR

# Fake a minimal Claude Code hook JSON payload for a Bash tool invocation.
# fake_tool_input "git commit --no-verify -m 'x'"
fake_tool_input() {
  jq -n --arg cmd "$1" '{"tool_name":"Bash","tool_input":{"command":$cmd},"session_id":"test-session"}'
}

# Fake a PostToolUse Write|Edit hook payload. Optional 2nd arg sets tool_name
# (default Write).
# fake_edit_input "/path/to/file.ts" [Write|Edit]
fake_edit_input() {
  jq -n --arg fp "$1" --arg tn "${2:-Write}" '{"tool_name":$tn,"tool_input":{"file_path":$fp},"session_id":"test-session"}'
}

# assert_blocks hook_script input_json
# Run the hook with input; assert exit code 2 (blocked).
assert_blocks() {
  local hook="$HOOKS_DIR/$1" input="$2"
  local status=0
  printf '%s' "$input" | bash "$hook" 2>/dev/null || status=$?
  if [ "$status" -ne 2 ]; then
    echo "FAIL: expected exit 2 (block) from $1 but got $status" >&2
    return 1
  fi
  return 0
}

# assert_allows hook_script input_json
# Run the hook with input; assert exit code 0 (allowed).
assert_allows() {
  local hook="$HOOKS_DIR/$1" input="$2"
  local status=0
  printf '%s' "$input" | bash "$hook" 2>/dev/null || status=$?
  if [ "$status" -ne 0 ]; then
    echo "FAIL: expected exit 0 (allow) from $1 but got $status" >&2
    return 1
  fi
  return 0
}

# Temporary CC-sessions dir for tests that log to activity feed.
setup_sessions() {
  export SESSIONS_DIR="$(mktemp -d)"
}

teardown_sessions() {
  [ -n "${SESSIONS_DIR:-}" ] && rm -rf "$SESSIONS_DIR"
}

# ---------------------------------------------------------------------------
# Session-lifecycle hook helpers (E-040 S2). Scripts resolve the repo root via
# blitz_find_root (nearest .claude-plugin/ above pwd), so tests build a throwaway
# repo dir, cd into it, and inspect .cc-sessions/ afterwards.
# ---------------------------------------------------------------------------

# setup_fake_repo — create + enter a temp repo with .claude-plugin/ and
# .cc-sessions/{sessions,mailbox}/. Exports FAKE_REPO and unsets the live
# messaging socket so no test ever posts to a real Claude Code session.
setup_fake_repo() {
  FAKE_REPO="$(mktemp -d)"
  export FAKE_REPO
  mkdir -p "$FAKE_REPO/.claude-plugin" "$FAKE_REPO/.cc-sessions/sessions" "$FAKE_REPO/.cc-sessions/mailbox"
  unset SESSIONS_DIR CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN
  cd "$FAKE_REPO"
}

teardown_fake_repo() {
  cd /
  [ -n "${FAKE_REPO:-}" ] && rm -rf "$FAKE_REPO"
}

# write_session_record sid [extra_json_fields]
# Seed .cc-sessions/sessions/<sid>.json (status active).
write_session_record() {
  jq -n --arg sid "$1" '{session_id:$sid,status:"active",started:"2026-01-01T00:00:00Z"}' \
    > "$FAKE_REPO/.cc-sessions/sessions/$1.json"
}

# run_hook script_name json_input — run a hook in $FAKE_REPO; sets $status/$output.
run_hook() {
  local hook="$HOOKS_DIR/$1" input="$2"
  run bash -c "printf '%s' \"\$1\" | bash \"\$2\"" _ "$input" "$hook"
}

# feed_events — print the event names logged to the fake repo's activity feed.
feed_events() {
  jq -r '.event' "$FAKE_REPO/.cc-sessions/activity-feed.jsonl" 2>/dev/null || true
}
