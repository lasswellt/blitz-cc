#!/usr/bin/env bats
# Tests for hooks/scripts/session-start.sh (SessionStart hook; record owner, E-041 S1)
# Requires: bats-core, jq. A fake `claude` shim on PATH returns canned agent-view JSON.

load '_helpers'

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  setup_fake_repo
  # Fake `claude` CLI: prints $FAKE_AGENTS_JSON (default: empty array) for `agents --json [--all]`.
  mkdir -p "$FAKE_REPO/bin"
  cat > "$FAKE_REPO/bin/claude" <<'SH'
#!/usr/bin/env bash
printf '%s' "${FAKE_AGENTS_JSON:-[]}"
SH
  chmod +x "$FAKE_REPO/bin/claude"
  export PATH="$FAKE_REPO/bin:$PATH"
  export FAKE_AGENTS_JSON='[]'
}
teardown() { teardown_fake_repo; }

@test "empty stdin: exits 0, no record created, no feed session_start" {
  run_hook "session-start.sh" ""
  [ "$status" -eq 0 ]
  [ -z "$(ls -A .cc-sessions/sessions)" ]
  ! feed_events | grep -qx "session_start"
}

@test "creates the canonical record from stdin fields" {
  run_hook "session-start.sh" '{"session_id":"s1","cwd":"/w","transcript_path":"/t.jsonl","scratchpad_dir":"/sp","permission_mode":"default","effort":{"level":"low"},"source":"startup","hook_event_name":"SessionStart"}'
  [ "$status" -eq 0 ]
  [ -f .cc-sessions/sessions/s1.json ]
  [ "$(jq -r .session_id .cc-sessions/sessions/s1.json)" = "s1" ]
  [ "$(jq -r .harness .cc-sessions/sessions/s1.json)" = "claude" ]
  [ "$(jq -r .status .cc-sessions/sessions/s1.json)" = "active" ]
  [ "$(jq -r .state .cc-sessions/sessions/s1.json)" = "working" ]
  [ "$(jq -r .cwd .cc-sessions/sessions/s1.json)" = "/w" ]
  [ "$(jq -r .transcript_path .cc-sessions/sessions/s1.json)" = "/t.jsonl" ]
  [ "$(jq -r .scratchpad_dir .cc-sessions/sessions/s1.json)" = "/sp" ]
  [ "$(jq -r .effort .cc-sessions/sessions/s1.json)" = "low" ]
  [ "$(jq -r .source .cc-sessions/sessions/s1.json)" = "startup" ]
  [ "$(jq -r '.skill' .cc-sessions/sessions/s1.json)" = "null" ]
  [ "$(jq -r '.locks_held|length' .cc-sessions/sessions/s1.json)" = "0" ]
}

@test "feed session_start carries session=<session_id> and detail.source" {
  run_hook "session-start.sh" '{"session_id":"s1","cwd":"/w","source":"startup"}'
  line=$(grep '"event":"session_start"' .cc-sessions/activity-feed.jsonl | tail -1)
  [ "$(printf '%s' "$line" | jq -r .session)" = "s1" ]
  [ "$(printf '%s' "$line" | jq -r .detail.source)" = "startup" ]
  [ "$(printf '%s' "$line" | jq -r .detail.cwd)" = "/w" ]
}

@test "source=resume reopens the record and keeps skill/working_on/locks" {
  jq -n '{session_id:"s1",status:"suspended",state:"ended",started:"2026-01-01T00:00:00Z",skill:"build",working_on:"demo/T-003",locks_held:["a.lock"],ended:"2026-01-01T01:00:00Z"}' \
    > .cc-sessions/sessions/s1.json
  run_hook "session-start.sh" '{"session_id":"s1","source":"resume"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/sessions/s1.json)" = "active" ]
  [ "$(jq -r .state .cc-sessions/sessions/s1.json)" = "working" ]
  [ "$(jq -r .skill .cc-sessions/sessions/s1.json)" = "build" ]
  [ "$(jq -r .working_on .cc-sessions/sessions/s1.json)" = "demo/T-003" ]
  [ "$(jq -r '.locks_held[0]' .cc-sessions/sessions/s1.json)" = "a.lock" ]
  [ "$(jq -r .source .cc-sessions/sessions/s1.json)" = "resume" ]
  [ "$(jq -r '.ended' .cc-sessions/sessions/s1.json)" = "null" ]
}

@test "unsafe session_id never becomes a path" {
  run_hook "session-start.sh" '{"session_id":"../evil"}'
  [ "$status" -eq 0 ]
  [ ! -f .cc-sessions/evil.json ]
  [ ! -f .cc-sessions/sessions/../evil.json ]
}

@test "stale cleanup: old idle record with no overlay → failed, lock released, warning" {
  jq -n '{session_id:"old",status:"active",state:"idle",started:"2026-01-01T00:00:00Z",last_activity:"2026-01-01T00:00:00Z"}' \
    > .cc-sessions/sessions/old.json
  echo "old" > .cc-sessions/tasks.json.lock
  echo "someone-else" > .cc-sessions/foreign.lock
  run_hook "session-start.sh" '{"session_id":"s1","source":"startup"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/sessions/old.json)" = "failed" ]
  [ "$(jq -r .failed_reason .cc-sessions/sessions/old.json)" = "stale_session_cleanup" ]
  [ ! -f .cc-sessions/tasks.json.lock ]
  [ -f .cc-sessions/foreign.lock ]
  feed_events | grep -qx "warning"
  printf '%s' "$output" | grep -q "Stale session cleaned up: old"
}

@test "stale cleanup: overlay says working → record kept active" {
  jq -n '{session_id:"busy",status:"active",state:"idle",started:"2026-01-01T00:00:00Z",last_activity:"2026-01-01T00:00:00Z"}' \
    > .cc-sessions/sessions/busy.json
  export FAKE_AGENTS_JSON='[{"sessionId":"busy","state":"working","status":"busy","pid":1,"cwd":"/x","kind":"background","name":"n"}]'
  run_hook "session-start.sh" '{"session_id":"s1"}'
  [ "$(jq -r .status .cc-sessions/sessions/busy.json)" = "active" ]
  ! feed_events | grep -qx "warning"
}

@test "stale cleanup covers legacy .cc-sessions/<skill>-<hex>.json records" {
  jq -n '{claude_session_id:"leg",skill:"audit",status:"active",started:"2026-01-01T00:00:00Z",last_activity:"2026-01-01T00:00:00Z"}' \
    > .cc-sessions/audit-deadbeef.json
  run_hook "session-start.sh" '{"session_id":"s1"}'
  [ "$(jq -r .status .cc-sessions/audit-deadbeef.json)" = "failed" ]
}

@test "own fresh record is never marked stale" {
  run_hook "session-start.sh" '{"session_id":"s1"}'
  [ "$(jq -r .status .cc-sessions/sessions/s1.json)" = "active" ]
}

@test "HANDOFF surfacing and feed echo still work" {
  jq -n '{phase:"build demo",plan:"demo",task:"T-003",branch:"main",uncommitted:[],last_activity:"x"}' > .cc-sessions/HANDOFF.json
  printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","session":"p","skill":"quick","event":"task_start","message":"hello feed","detail":{}}' >> .cc-sessions/activity-feed.jsonl
  run_hook "session-start.sh" '{"session_id":"s1"}'
  printf '%s' "$output" | grep -q "HANDOFF detected"
  printf '%s' "$output" | grep -q "hello feed"
  [ "$(cat .cc-sessions/context-char-count)" = "0" ]
}
