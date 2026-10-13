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

@test "writes no feed line per batch (the feed carries loop and skill events only)" {
  run_hook "heartbeat.sh" '{"session_id":"s1","hook_event_name":"PostToolBatch"}'
  [ "$status" -eq 0 ]
  [ ! -f .cc-sessions/activity-feed.jsonl ]
}

@test "marks record state working + last_activity" {
  write_session_record s1
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$(jq -r .state .cc-sessions/sessions/s1.json)" = "working" ]
  [ "$(jq -r .last_activity .cc-sessions/sessions/s1.json)" != "null" ]
}

@test "no record: nothing written on disk" {
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ ! -f .cc-sessions/sessions/s1.json ]
  [ ! -f .cc-sessions/activity-feed.jsonl ]
}

tia_fixture() {  # a vitest project with one changed source file and its sibling test
  printf '{"name":"x","devDependencies":{"vitest":"2.0.0"}}\n' > package.json
  mkdir -p src bin .cc-sessions/sessions/s1
  printf 'export const a = 1\n' > src/a.ts
  printf 'import { a } from "./a"\n' > src/a.test.ts
  printf 'src/a.ts\n' > .cc-sessions/sessions/s1/touched.txt
  # an npx on PATH that records any call: the heartbeat must never use it
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/npx.calls"\n' "$PWD" > bin/npx; chmod +x bin/npx
  export PATH="$PWD/bin:$PATH"
}

@test "TIA runs the project's own node_modules/.bin runner, never npx" {
  tia_fixture
  mkdir -p node_modules/.bin
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/vitest.calls"\n' "$PWD" > node_modules/.bin/vitest; chmod +x node_modules/.bin/vitest
  run_hook "heartbeat.sh" "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}"
  [ "$status" -eq 0 ]
  grep -q '^run --reporter=json' vitest.calls
  [ ! -f npx.calls ]
}

@test "TIA skips (no download) when the runner is not installed locally" {
  tia_fixture
  run_hook "heartbeat.sh" "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}"
  [ "$status" -eq 0 ]
  [ ! -f npx.calls ]
}

inbox_line() {  # id kind session status
  jq -nc --arg id "$1" --arg k "$2" --arg s "$3" --arg st "$4" '{id:$id,ts:"2026-10-12T00:00:00Z",kind:$k,session:$s,status:$st}'
}

@test "dismisses own pending needs_input" {
  mkdir -p .cc-sessions
  inbox_line a needs_input s1 pending > .cc-sessions/inbox.jsonl
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/inbox.jsonl)" = "dismissed" ]
  [ "$(jq -r .dismissed_by .cc-sessions/inbox.jsonl)" = "heartbeat" ]
}

@test "dismisses own pending permission" {
  mkdir -p .cc-sessions
  inbox_line a permission s1 pending > .cc-sessions/inbox.jsonl
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .cc-sessions/inbox.jsonl)" = "dismissed" ]
}

@test "leaves other session's pending needs_input and own escalation untouched, keeps order" {
  mkdir -p .cc-sessions
  { inbox_line a needs_input s2 pending; inbox_line b escalation s1 pending; inbox_line c needs_input s1 pending; } > .cc-sessions/inbox.jsonl
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .id .cc-sessions/inbox.jsonl | paste -sd,)" = "a,b,c" ]
  [ "$(jq -r .status .cc-sessions/inbox.jsonl | paste -sd,)" = "pending,pending,dismissed" ]
}

@test "no inbox file: exit 0 and none created" {
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ ! -f .cc-sessions/inbox.jsonl ]
}

@test "malformed inbox line: exit 0 and file unchanged" {
  mkdir -p .cc-sessions
  { inbox_line a needs_input s1 pending; echo 'not json {'; } > .cc-sessions/inbox.jsonl
  cp .cc-sessions/inbox.jsonl before.jsonl
  run_hook "heartbeat.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  cmp .cc-sessions/inbox.jsonl before.jsonl
}
