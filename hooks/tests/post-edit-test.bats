#!/usr/bin/env bats
# Tests for hooks/scripts/post-edit-test.sh (PostToolUse Write|Edit, advisory)
# Records each edited path once in .cc-sessions/sessions/<sid>/touched.txt so the
# heartbeat can select impacted tests; runs nothing itself. Always exits 0.
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

TOUCHED=".cc-sessions/sessions/test-session/touched.txt"

# edit_as <session_id> <file_path>
edit_as() { jq -nc --arg sid "$1" --arg fp "$2" '{tool_name:"Write",tool_input:{file_path:$fp},session_id:$sid}'; }

@test "records the edited path, exit 0, no output" {
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$TOUCHED")" = "/repo/src/a.ts" ]
}

@test "a second edit of the same file adds no duplicate line" {
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts)"
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts Edit)"
  [ "$(wc -l < "$TOUCHED" | tr -d ' ')" = "1" ]
}

@test "distinct files get one line each, in edit order" {
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts)"
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/b.ts Edit)"
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts)"
  [ "$(wc -l < "$TOUCHED" | tr -d ' ')" = "2" ]
  [ "$(sed -n 1p "$TOUCHED")" = "/repo/src/a.ts" ]
  [ "$(sed -n 2p "$TOUCHED")" = "/repo/src/b.ts" ]
}

@test "a top-level file_path is honoured as well as tool_input.file_path" {
  run_hook "post-edit-test.sh" '{"file_path":"/repo/src/c.ts","session_id":"test-session"}'
  [ "$status" -eq 0 ]
  [ "$(cat "$TOUCHED")" = "/repo/src/c.ts" ]
}

@test "paths under .cc-sessions/ are never recorded and no session dir is created" {
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/.cc-sessions/sessions/s1.json)"
  [ "$status" -eq 0 ]
  run_hook "post-edit-test.sh" "$(fake_edit_input .cc-sessions/inbox.jsonl Edit)"
  [ "$status" -eq 0 ]
  [ ! -e .cc-sessions/sessions/test-session ]
}

@test "the .cc-sessions exclusion is anchored to a path component" {
  run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/my.cc-sessions/file.ts)"
  [ "$(cat "$TOUCHED")" = "/repo/src/my.cc-sessions/file.ts" ]
}

@test "empty stdin: exit 0, nothing written" {
  run_hook "post-edit-test.sh" ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(ls -A .cc-sessions/sessions)" ]
}

@test "malformed stdin: exit 0, nothing written" {
  run_hook "post-edit-test.sh" 'not json at all'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(ls -A .cc-sessions/sessions)" ]
}

@test "a payload without file_path: exit 0, nothing written" {
  run_hook "post-edit-test.sh" '{"tool_name":"Write","tool_input":{"content":"x"},"session_id":"test-session"}'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A .cc-sessions/sessions)" ]
}

@test "a session id with spaces, slashes and shell characters maps to one safe directory" {
  run_hook "post-edit-test.sh" "$(edit_as 'we ird/../sid$x' /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  [ -f ".cc-sessions/sessions/we_ird_.._sid_x/touched.txt" ]
  [ "$(ls -A .cc-sessions/sessions | wc -l | tr -d ' ')" = "1" ]
  [ ! -e .cc-sessions/sid ]
  [ ! -e "$FAKE_REPO/sid" ]
}

@test "a dot-leading session id is refused rather than named as a hidden path" {
  run_hook "post-edit-test.sh" "$(edit_as '..' /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  run_hook "post-edit-test.sh" "$(edit_as '.hidden' /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A .cc-sessions/sessions)" ]
  [ ! -e .cc-sessions/touched.txt ]
}

@test "an empty session id falls back to a derived cli-<hex> id" {
  run_hook "post-edit-test.sh" "$(edit_as '' /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  ls -A .cc-sessions/sessions | grep -qE '^cli-[0-9a-f]{8}$'
}

@test "SESSIONS_DIR redirects the record" {
  SESSIONS_DIR="$FAKE_REPO/alt" run_hook "post-edit-test.sh" "$(fake_edit_input /repo/src/a.ts)"
  [ "$status" -eq 0 ]
  [ -f "$FAKE_REPO/alt/sessions/test-session/touched.txt" ]
  [ ! -e "$TOUCHED" ]
}
