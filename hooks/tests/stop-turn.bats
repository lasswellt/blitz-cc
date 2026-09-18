#!/usr/bin/env bats
# Tests for hooks/scripts/stop-turn.sh (Stop hook, non-blocking, E-040 S2)
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "exits 0 on empty stdin and prints nothing" {
  run_hook "stop-turn.sh" ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "never emits a decision (no JSON on stdout)" {
  write_session_record s1
  run_hook "stop-turn.sh" '{"session_id":"s1","stop_hook_active":false,"last_assistant_message":"done"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sets record state idle + last_activity" {
  write_session_record s1
  run_hook "stop-turn.sh" '{"session_id":"s1"}'
  [ "$(jq -r .state .cc-sessions/sessions/s1.json)" = "idle" ]
  [ "$(jq -r .last_activity .cc-sessions/sessions/s1.json)" != "null" ]
}

@test "does not store last_assistant_message" {
  write_session_record s1
  run_hook "stop-turn.sh" '{"session_id":"s1","last_assistant_message":"SECRET-MARKER"}'
  ! grep -rq "SECRET-MARKER" .cc-sessions/
}

@test "no record: still exits 0 without creating one" {
  run_hook "stop-turn.sh" '{"session_id":"ghost"}'
  [ "$status" -eq 0 ]
  [ ! -f .cc-sessions/sessions/ghost.json ]
}

@test "mailbox left untouched when no messaging socket is available" {
  printf '{"type":"message","text":"hi"}\n' > .cc-sessions/mailbox/s1.jsonl
  run_hook "stop-turn.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(wc -l < .cc-sessions/mailbox/s1.jsonl)" -eq 1 ]
  [ ! -f .cc-sessions/mailbox/s1.jsonl.undelivered ]
  ! feed_events | grep -qx "mailbox"
}

@test "mailbox drained + feed event when socket accepts (python3 fake server)" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '{"type":"message","text":"one"}\n{"type":"message","text":"two"}\n' > .cc-sessions/mailbox/s1.jsonl
  SOCK="$FAKE_REPO/sock"
  python3 - "$SOCK" "$FAKE_REPO/sock.log" <<'PY' &
import socket, sys
p, log = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.bind(p); s.listen(4); s.settimeout(10)
with open(log, "wb") as f:
    for _ in range(2):
        c, _a = s.accept(); f.write(c.recv(65536)); c.close()
PY
  SERVER=$!
  sleep 1
  CLAUDE_CODE_MESSAGING_SOCKET="$SOCK" CLAUDE_CODE_MESSAGING_TOKEN=tok \
    run_hook "stop-turn.sh" '{"session_id":"s1"}'
  wait "$SERVER"
  [ "$status" -eq 0 ]
  [ ! -s .cc-sessions/mailbox/s1.jsonl ]
  grep -q '"type":"auth","token":"tok"' "$FAKE_REPO/sock.log"
  grep -q '"text":"two"' "$FAKE_REPO/sock.log"
  feed_events | grep -qx "mailbox"
  [ "$(jq -r 'select(.event=="mailbox") | .detail.count' .cc-sessions/activity-feed.jsonl)" = "2" ]
}
