#!/usr/bin/env bats
# Tests for hooks/scripts/tasks-guard.sh (PreToolUse: tasks.json is written only by scripts/tasks.sh)
load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

@test "blocks Write to a plan's tasks.json" {
  assert_blocks "tasks-guard.sh" "$(fake_edit_input "$FAKE_REPO/docs/plans/demo/tasks.json" Write)"
}

@test "blocks Edit to a plan's tasks.json" {
  assert_blocks "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/tasks.json" Edit)"
}

@test "allows edits to spec.md and progress.md" {
  assert_allows "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/spec.md" Edit)"
  assert_allows "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/progress.md" Write)"
}

@test "blocks shell redirection and sed -i into tasks.json" {
  assert_blocks "tasks-guard.sh" "$(fake_tool_input "jq '.tasks[0].passes=true' docs/plans/demo/tasks.json > docs/plans/demo/tasks.json")"
  assert_blocks "tasks-guard.sh" "$(fake_tool_input "sed -i 's/false/true/' docs/plans/demo/tasks.json")"
  assert_blocks "tasks-guard.sh" "$(fake_tool_input "cp /tmp/x docs/plans/demo/tasks.json")"
}

@test "allows reads and the canonical writer" {
  assert_allows "tasks-guard.sh" "$(fake_tool_input "cat docs/plans/demo/tasks.json")"
  assert_allows "tasks-guard.sh" "$(fake_tool_input "jq '.tasks' docs/plans/demo/tasks.json")"
  assert_allows "tasks-guard.sh" "$(fake_tool_input "bash scripts/tasks.sh verify demo T-001")"
}

@test "BLITZ_TASKS_GUARD_OFF=1 disables the guard" {
  BLITZ_TASKS_GUARD_OFF=1 assert_allows "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/tasks.json" Write)"
}

@test "still blocks in a consumer project without .claude-plugin/ (no fail-open)" {
  # A consumer repo has no .claude-plugin/; blitz_find_root must not abort the guard.
  rm -rf "$FAKE_REPO/.claude-plugin"
  git -C "$FAKE_REPO" init -q .
  assert_blocks "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/tasks.json" Edit)"
}
