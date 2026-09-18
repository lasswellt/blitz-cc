#!/usr/bin/env bats
# Tests for scripts/test-listener.sh (E-043 S1/S6 — journal writer)
# Requires: bats-core, jq, python3

load '_helpers'

LISTENER="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/test-listener.sh"
FIXTURE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/fixtures/tia"

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  setup_fake_repo
  cp -r "$FIXTURE/." "$FAKE_REPO/"
  git init -q "$FAKE_REPO" && git -C "$FAKE_REPO" add -A \
    && git -C "$FAKE_REPO" -c user.email=t@t -c user.name=t commit -qm init
  JOURNAL="$FAKE_REPO/.cc-sessions/test-journal.jsonl"
  META="$FAKE_REPO/.cc-sessions/test-journal.meta.json"
}
teardown() { teardown_fake_repo; }

@test "--start increments runs_started and creates meta.json" {
  run bash "$LISTENER" --start --run-id r1
  [ "$status" -eq 0 ]
  [ "$(jq -r .runs_started "$META")" = "1" ]
  [ "$(jq -r .runs_recorded "$META")" = "0" ]
}

@test "records one journal line per test file with the documented schema" {
  bash "$LISTENER" --start --run-id r1 --session s1
  run bash "$LISTENER" --trigger post-edit --changed src/b.ts --selected-by selector \
    --run-id r1 --session s1 < vitest-report.json
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$JOURNAL" | tr -d ' ')" = "2" ]
  jq -e 'select(.test_file=="tests/b.test.ts") | .result=="fail" and .failed_names==["b returns b"]
         and .changed==["src/b.ts"] and .trigger=="post-edit" and .selected_by=="selector"
         and .run_id=="r1" and .session=="s1" and .duration_ms==80 and (.commit|length)==40' "$JOURNAL" | grep -q true
  jq -e 'select(.test_file=="tests/a.test.ts") | .result=="pass" and .failed_names==[]' "$JOURNAL" | grep -q true
  [ "$(jq -r .runs_recorded "$META")" = "1" ]
  [ "$(jq -r .last_run_id "$META")" = "r1" ]
  [ "$(jq -r .runs_started "$META")" = "$(jq -r .runs_recorded "$META")" ]
}

@test "malformed JSON: exit 0, nothing journaled, feed warning" {
  run bash -c "echo 'not json' | bash '$LISTENER' --trigger ci"
  [ "$status" -eq 0 ]
  [ ! -f "$JOURNAL" ]
  feed_events | grep -qx "warning"
}

@test "missing --trigger: exit 0" {
  run bash "$LISTENER" < vitest-report.json
  [ "$status" -eq 0 ]
}

@test "concurrent writers produce no interleaved lines" {
  for i in 1 2 3 4 5 6; do
    bash "$LISTENER" --trigger ci --run-id "c$i" < vitest-report.json &
  done
  wait
  [ "$(wc -l < "$JOURNAL" | tr -d ' ')" = "12" ]
  jq -c . "$JOURNAL" > /dev/null
  [ "$(jq -r .runs_recorded "$META")" = "6" ]
  [ ! -f "$FAKE_REPO/.cc-sessions/test-journal.lock" ]
}

@test "stale lock (>60s) is recovered" {
  : > "$FAKE_REPO/.cc-sessions/test-journal.lock"
  touch -d '2 minutes ago' "$FAKE_REPO/.cc-sessions/test-journal.lock" 2>/dev/null \
    || touch -t "$(date -v-2M +%Y%m%d%H%M 2>/dev/null)" "$FAKE_REPO/.cc-sessions/test-journal.lock"
  run bash "$LISTENER" --start
  [ "$status" -eq 0 ]
  [ "$(jq -r .runs_started "$META")" = "1" ]
}

@test "runs_started / runs_recorded drift > 3 raises a hook_failure inbox item" {
  for i in 1 2 3 4 5; do bash "$LISTENER" --start; done
  [ -f "$FAKE_REPO/.cc-sessions/inbox.jsonl" ]
  jq -e 'select(.kind=="hook_failure") | .text | test("test journal: 5 runs started, 0 recorded")' \
    "$FAKE_REPO/.cc-sessions/inbox.jsonl" | grep -q true
}

@test "--prune keeps at most 5000 lines and drops entries older than 30 days" {
  old='{"ts":"2000-01-01T00:00:00Z","run_id":"old","test_file":"x","result":"pass"}'
  printf '%s\n' "$old" > "$JOURNAL"
  for i in $(seq 1 5010); do printf '{"ts":"2999-01-01T00:00:00Z","run_id":"n%s","test_file":"x","result":"pass"}\n' "$i"; done >> "$JOURNAL"
  run bash "$LISTENER" --prune
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$JOURNAL" | tr -d ' ')" = "5000" ]
  ! grep -q '"run_id":"old"' "$JOURNAL"
  grep -q '"run_id":"n5010"' "$JOURNAL"
}
