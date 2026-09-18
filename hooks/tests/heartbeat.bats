#!/usr/bin/env bats
# Tests for hooks/scripts/heartbeat.sh (PostToolBatch hook; was post-tool-batch.sh)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "exits 0 on empty stdin and prints nothing" {
  run_hook "heartbeat.sh" ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "logs post_tool_batch (feed contract preserved from post-tool-batch.sh)" {
  run_hook "heartbeat.sh" '{"session_id":"s1","hook_event_name":"PostToolBatch"}'
  feed_events | grep -qx "post_tool_batch"
}

@test "marks record state working + last_activity" {
  write_session_record s1
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$(jq -r .state .cc-sessions/sessions/s1.json)" = "working" ]
  [ "$(jq -r .last_activity .cc-sessions/sessions/s1.json)" != "null" ]
}

@test "no record: no-op on disk besides the feed" {
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ ! -f .cc-sessions/sessions/s1.json ]
}
