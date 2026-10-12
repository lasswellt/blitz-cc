#!/usr/bin/env bats
# Tests for hooks/scripts/pre-compact-snapshot.sh (PreCompact: writes .cc-sessions/HANDOFF.json)
# Requires: bats-core, jq, git
load '_helpers'

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  command -v git >/dev/null || skip "git not installed"
  setup_fake_repo
  git init -q .
  mkdir -p .cc-sessions/sessions/s1
}
teardown() { teardown_fake_repo; }

HANDOFF=.cc-sessions/HANDOFF.json

@test "happy path: plan, task, gate, phase, never-edit list and uncommitted paths; handoff_written logged" {
  mkdir -p docs/plans/demo
  jq -n '{"$schema":"blitz-tasks/1.0",plan:"demo",tasks:[{id:"T-001",status:"done"},{id:"T-002",status:"in_progress"}]}' > docs/plans/demo/tasks.json
  jq -n '{checks:[],blocks:0,max_blocks:4,until:"build demo T-002"}' > .cc-sessions/sessions/s1/gate.json
  printf 'x\n' > untracked.txt
  run_hook "pre-compact-snapshot.sh" '{"session_id":"s1","hook_event_name":"PreCompact","trigger":"auto"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"HANDOFF written to .cc-sessions/HANDOFF.json"* ]]
  jq -e . "$HANDOFF" >/dev/null
  [ "$(jq -r .session "$HANDOFF")" = "s1" ]
  [ "$(jq -r .trigger "$HANDOFF")" = "pre-compact" ]
  [ "$(jq -r .plan "$HANDOFF")" = "demo" ]
  [ "$(jq -r .task "$HANDOFF")" = "T-002" ]
  [ "$(jq -r .gate "$HANDOFF")" = ".cc-sessions/sessions/s1/gate.json" ]
  [ "$(jq -r .phase "$HANDOFF")" = "build demo T-002" ]
  [ "$(jq -r '.never_edit | length' "$HANDOFF")" = "2" ]
  jq -e '.never_edit[1] | startswith("docs/plans/*/progress.md")' "$HANDOFF" >/dev/null
  jq -e '.uncommitted | any(. == "?? untracked.txt")' "$HANDOFF" >/dev/null
  jq -e '.recent_files == []' "$HANDOFF" >/dev/null
  [ "$(jq -r .branch "$HANDOFF")" != "" ]
  feed_events | grep -qx handoff_written
  [ "$(jq -r 'select(.event=="handoff_written") | .detail.plan' .cc-sessions/activity-feed.jsonl)" = "demo" ]
}

@test "no plan, no gate: plan, task and gate are JSON null and the phase is unknown" {
  run_hook "pre-compact-snapshot.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  jq -e '.plan == null and .task == null and .gate == null' "$HANDOFF" >/dev/null
  [ "$(jq -r .phase "$HANDOFF")" = "unknown" ]
  [ "$(jq -r 'select(.event=="handoff_written") | .detail.task' .cc-sessions/activity-feed.jsonl)" = "null" ]
}

@test "a quote and a backslash in the gate label and in an uncommitted path keep HANDOFF.json and the feed valid JSON" {
  local label='build "we\ird" T-1'
  jq -n --arg u "$label" '{checks:[],blocks:0,until:$u}' > .cc-sessions/sessions/s1/gate.json
  printf 'x\n' > 'we"ird\file.ts'
  run_hook "pre-compact-snapshot.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  jq -e . "$HANDOFF" >/dev/null
  [ "$(jq -r .phase "$HANDOFF")" = "$label" ]
  jq -e '.uncommitted | any(test("ird"))' "$HANDOFF" >/dev/null
  jq -e . .cc-sessions/activity-feed.jsonl >/dev/null
  [ "$(jq -r 'select(.event=="handoff_written") | .detail.phase' .cc-sessions/activity-feed.jsonl)" = "$label" ]
}

@test "an unsafe session id is never used as a path: no gate, exit 0" {
  mkdir -p '.cc-sessions/sessions/../evil'
  run_hook "pre-compact-snapshot.sh" '{"session_id":"../evil"}'
  [ "$status" -eq 0 ]
  jq -e '.gate == null' "$HANDOFF" >/dev/null
  [ "$(jq -r .session "$HANDOFF")" = "../evil" ]
}

@test "outside a git repository the branch and head fall back and uncommitted is an empty array" {
  rm -rf .git
  run_hook "pre-compact-snapshot.sh" '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r .branch "$HANDOFF")" = "unknown" ]
  [ "$(jq -r .head_sha "$HANDOFF")" = "unknown" ]
  jq -e '.uncommitted == []' "$HANDOFF" >/dev/null
}
