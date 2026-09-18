#!/usr/bin/env bats
# Tests for hooks/scripts/model-switch-warn.sh (PreModelSwitch hook, E-040 S2)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "exits 0 on empty stdin (never blocks the switch)" {
  run_hook "model-switch-warn.sh" ""
  [ "$status" -eq 0 ]
}

@test "prints the one-line advisory naming both models" {
  run_hook "model-switch-warn.sh" '{"session_id":"s1","from_model":"claude-opus-4","to_model":"claude-sonnet-4"}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "[blitz] model switch claude-opus-4 -> claude-sonnet-4 resets the prompt cache"* ]]
}

@test "logs cache_bust with from/to" {
  run_hook "model-switch-warn.sh" '{"session_id":"s1","from_model":"a","to_model":"b"}'
  [ "$(jq -r 'select(.event=="cache_bust") | "\(.detail.from)>\(.detail.to)"' .cc-sessions/activity-feed.jsonl)" = "a>b" ]
}
