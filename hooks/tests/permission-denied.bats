#!/usr/bin/env bats
# Tests for hooks/scripts/permission-denied.sh (PermissionDenied hook, E-040 S2)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "exits 0 on empty stdin" {
  run_hook "permission-denied.sh" ""
  [ "$status" -eq 0 ]
}

@test "logs permission_denied with tool_name and an inbox permission item" {
  run_hook "permission-denied.sh" '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
  [ "$status" -eq 0 ]
  feed_events | grep -qx "permission_denied"
  [ "$(jq -r 'select(.event=="permission_denied") | .detail.tool_name' .cc-sessions/activity-feed.jsonl)" = "Bash" ]
  [ "$(jq -r .kind .cc-sessions/inbox.jsonl)" = "permission" ]
}

@test "never prints anything (no retry, containment posture)" {
  run_hook "permission-denied.sh" '{"session_id":"s1","tool_name":"Bash"}'
  [ -z "$output" ]
  # no executable line may mention retry (comments explaining the posture are fine)
  ! grep -vE '^[[:space:]]*#' "$HOOKS_DIR/permission-denied.sh" | grep -q "retry"
}
