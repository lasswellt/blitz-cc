#!/usr/bin/env bats
# Tests for scripts/next-state.sh — Observe step for /blitz:next (loop.md rows 0–5)
load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; export BLITZ_PLANS_DIR="$FAKE_REPO/docs/plans"; TASKS="$HOOKS_DIR/../../scripts/tasks.sh"; NS="$HOOKS_DIR/../../scripts/next-state.sh"; }
teardown() { teardown_fake_repo; }
ns() { run bash "$NS" --plans-dir "$BLITZ_PLANS_DIR" --sessions-dir "$FAKE_REPO/.cc-sessions" --no-agent-view; }
spec() { mkdir -p "$BLITZ_PLANS_DIR/$1"; printf -- '---\nstatus: %s\npriority: %s\ncreated: 2026-09-19\n---\n# %s\n' "$2" "${3:-10}" "$1" > "$BLITZ_PLANS_DIR/$1/spec.md"; }

@test "row 5 when no plans exist" {
  ns; [ "$status" -eq 0 ]; [ "$(printf '%s' "$output" | jq -r .row)" = "5" ]
}

@test "row 2 with the next ready task" {
  spec demo active
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" add demo --id T-002 --title "b" --depends T-001 --verify-cmd "true" >/dev/null
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "2" ]
  [ "$(printf '%s' "$output" | jq -r .next_task.id)" = "T-001" ]
  [ "$(printf '%s' "$output" | jq -r .active_plan)" = "demo" ]
}

@test "row 3 when all tasks done and no check report" {
  spec demo active
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" verify demo T-001 >/dev/null
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "3" ]
}

@test "row 4 when check report is a fresh PASS" {
  spec demo active
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" verify demo T-001 >/dev/null
  printf -- '---\nresult: PASS\nts: 2999-01-01T00:00:00Z\n---\n' > "$BLITZ_PLANS_DIR/demo/check-report.md"
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "4" ]
}

@test "row 1 when a task is blocked on a human-only reason" {
  spec demo active
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" set demo T-001 blocked_reason=hard_spec >/dev/null
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.escalate[0].id')" = "T-001" ]
}

@test "row 0 when the inbox has a pending item or the kill switch is set" {
  spec demo active
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" >/dev/null
  echo '{"ts":"t","id":"inb-1","kind":"needs_input","status":"pending","text":"x"}' > "$FAKE_REPO/.cc-sessions/inbox.jsonl"
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "0" ]
  rm "$FAKE_REPO/.cc-sessions/inbox.jsonl"; touch "$FAKE_REPO/.cc-sessions/STOP"
  ns; [ "$(printf '%s' "$output" | jq -r .row)" = "0" ]; [ "$(printf '%s' "$output" | jq -r .kill_switch)" = "true" ]
}

@test "paused plans are reported and never selected; priority orders active plans" {
  spec low active 50; spec high active 1; spec off paused
  bash "$TASKS" add low --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" add high --id T-001 --title "a" --verify-cmd "true" >/dev/null
  bash "$TASKS" add off --id T-001 --title "a" --verify-cmd "true" >/dev/null
  ns; [ "$(printf '%s' "$output" | jq -r .active_plan)" = "high" ]
  [ "$(printf '%s' "$output" | jq -r '.paused_plans[0]')" = "off" ]
}
