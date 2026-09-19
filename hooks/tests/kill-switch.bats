#!/usr/bin/env bats
# Tests for hooks/scripts/kill-switch.sh (PreToolUse: refuse every tool while .cc-sessions/STOP exists)
load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "no STOP file: exit 0" {
  run_hook "kill-switch.sh" '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
}

@test "STOP present: exit 2 with the reason, logged once per session" {
  echo "pausing for review" > .cc-sessions/STOP
  run_hook "kill-switch.sh" '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 2 ]
  run_hook "kill-switch.sh" '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"a"}}'
  [ "$status" -eq 2 ]
  [ "$(feed_events | grep -c kill_switch)" = "1" ]
}

@test "removing STOP resumes" {
  touch .cc-sessions/STOP
  run_hook "kill-switch.sh" '{"session_id":"s1"}'
  [ "$status" -eq 2 ]
  rm .cc-sessions/STOP
  run_hook "kill-switch.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
}
