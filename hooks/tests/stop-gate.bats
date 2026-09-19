#!/usr/bin/env bats
# Tests for hooks/scripts/stop-gate.sh (Stop hook, conditional blocking gate, E-042 S1)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; mkdir -p .cc-sessions/sessions/s1; }
teardown() { teardown_fake_repo; }

write_gate() {  # write_gate '<checks json array>' [blocks] [max]
  jq -n --argjson c "$1" --argjson b "${2:-0}" --argjson m "${3:-6}" \
    '{checks:$c, blocks:$b, max_blocks:$m, until:"phase-3"}' > .cc-sessions/sessions/s1/gate.json
}

@test "no gate file: exit 0, nothing logged" {
  run_hook "stop-gate.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passing checks: exit 0, blocks reset, gate_pass logged" {
  write_gate '[{"name":"true","cmd":"true"}]' 3
  run_hook "stop-gate.sh" '{"session_id":"s1","stop_hook_active":false}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .blocks .cc-sessions/sessions/s1/gate.json)" = "0" ]
  feed_events | grep -q gate_pass
}

@test "failing check: exit 2 with reason, blocks incremented" {
  write_gate '[{"name":"tsc","cmd":"echo type error TS2322; exit 1"}]'
  run_hook "stop-gate.sh" '{"session_id":"s1","stop_hook_active":false}'
  [ "$status" -eq 2 ]
  [ "$(jq -r .blocks .cc-sessions/sessions/s1/gate.json)" = "1" ]
  [ "$(jq -r .last_failed .cc-sessions/sessions/s1/gate.json)" = "tsc" ]
  feed_events | grep -q gate_block
}

@test "blocks >= max_blocks: stands down with gate_exhausted" {
  write_gate '[{"name":"fail","cmd":"exit 1"}]' 6 6
  run_hook "stop-gate.sh" '{"session_id":"s1","stop_hook_active":false}'
  [ "$status" -eq 0 ]
  feed_events | grep -q gate_exhausted
}

@test "stop_hook_active true: never blocks" {
  write_gate '[{"name":"fail","cmd":"exit 1"}]'
  run_hook "stop-gate.sh" '{"session_id":"s1","stop_hook_active":true}'
  [ "$status" -eq 0 ]
}

@test "terminal marker in last_assistant_message: never blocks" {
  write_gate '[{"name":"fail","cmd":"exit 1"}]'
  run_hook "stop-gate.sh" '{"session_id":"s1","last_assistant_message":"work halted LOOP_ESCALATE reason"}'
  [ "$status" -eq 0 ]
}

@test "max_blocks above 4 is clamped under the platform's 5-block cap" {
  write_gate '[{"name":"fail","cmd":"exit 1"}]' 4 20
  run_hook "stop-gate.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  feed_events | grep -q gate_exhausted
}

@test "malformed gate.json: stands down with warning" {
  echo '{"checks":"nope"}' > .cc-sessions/sessions/s1/gate.json
  run_hook "stop-gate.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  feed_events | grep -q warning
}

@test "check timeout is honored" {
  write_gate '[{"name":"slow","cmd":"sleep 5","timeout":1}]'
  run_hook "stop-gate.sh" '{"session_id":"s1"}'
  [ "$status" -eq 2 ]
}
