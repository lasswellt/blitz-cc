#!/usr/bin/env bats
# Tests for hooks/scripts/session-end.sh (SessionEnd hook, E-040 S2)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "exits 0 on empty stdin" {
  run_hook "session-end.sh" ""
  [ "$status" -eq 0 ]
}

@test "logs session_end even when no record exists" {
  run_hook "session-end.sh" '{"session_id":"nope","reason":"clear"}'
  [ "$status" -eq 0 ]
  feed_events | grep -qx "session_end"
  [ ! -f .cc-sessions/sessions/nope.json ]
}

@test "maps prompt_input_exit -> completed and sets ended" {
  write_session_record s1
  run_hook "session-end.sh" '{"session_id":"s1","reason":"prompt_input_exit"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/sessions/s1.json)" = "completed" ]
  [ "$(jq -r .ended .cc-sessions/sessions/s1.json)" != "null" ]
}

@test "maps resume -> suspended, clear -> cleared, logout -> logged_out, other -> completed" {
  for pair in resume:suspended clear:cleared logout:logged_out other:completed; do
    write_session_record s1
    run_hook "session-end.sh" "{\"session_id\":\"s1\",\"reason\":\"${pair%%:*}\"}"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status .cc-sessions/sessions/s1.json)" = "${pair##*:}" ]
  done
}

@test "releases only locks that name this session (ownership guard)" {
  write_session_record s1
  printf '{"session_id":"s1"}' > .cc-sessions/mine.lock
  printf '{"session_id":"s2"}' > .cc-sessions/theirs.lock
  run_hook "session-end.sh" '{"session_id":"s1","reason":"other"}'
  [ "$status" -eq 0 ]
  [ ! -f .cc-sessions/mine.lock ]
  [ -f .cc-sessions/theirs.lock ]
}

@test "accepts legacy .cc-sessions/<x>.json records via claude_session_id" {
  echo '{"claude_session_id":"s9","status":"active"}' > .cc-sessions/cli-deadbeef.json
  run_hook "session-end.sh" '{"session_id":"s9","reason":"logout"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/cli-deadbeef.json)" = "logged_out" ]
}

@test "prints nothing to stdout" {
  write_session_record s1
  run_hook "session-end.sh" '{"session_id":"s1","reason":"other"}'
  [ -z "$output" ]
}
