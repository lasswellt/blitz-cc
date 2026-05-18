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
  jq -n --arg cmd "$1" '{"tool_input":{"command":$cmd},"session_id":"test-session"}'
}

# Fake a PostToolUse Write|Edit hook payload.
# fake_edit_input "/path/to/file.ts"
fake_edit_input() {
  jq -n --arg fp "$1" '{"tool_input":{"file_path":$fp},"session_id":"test-session"}'
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
