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

# ---------------------------------------------------------------------------
# progress.md is the main thread's ledger: denied from subagent context (stdin
# agent_type set), still editable from the main conversation.
# ---------------------------------------------------------------------------

sub_edit_input() {  # sub_edit_input <path> <tool>: a Write/Edit payload from a blitz:dev subagent
  jq -n --arg fp "$1" --arg tn "$2" \
    '{tool_name:$tn,tool_input:{file_path:$fp},session_id:"test-session",agent_id:"ag1",agent_type:"blitz:dev"}'
}
sub_tool_input() {  # sub_tool_input <command>: a Bash payload from a blitz:dev subagent
  jq -n --arg cmd "$1" \
    '{tool_name:"Bash",tool_input:{command:$cmd},session_id:"test-session",agent_id:"ag1",agent_type:"blitz:dev"}'
}

@test "subagent: blocks Write, Edit and NotebookEdit to progress.md and logs the agent type" {
  assert_blocks "tasks-guard.sh" "$(sub_edit_input "$FAKE_REPO/docs/plans/demo/progress.md" Write)"
  assert_blocks "tasks-guard.sh" "$(sub_edit_input "docs/plans/demo/progress.md" Edit)"
  assert_blocks "tasks-guard.sh" "$(jq -n '{tool_name:"NotebookEdit",tool_input:{notebook_path:"docs/plans/demo/progress.md"},session_id:"t",agent_type:"blitz:dev"}')"
  [ "$(jq -r 'select(.event=="tasks_guard_block") | .detail.agent_type' .cc-sessions/activity-feed.jsonl | sort -u)" = "blitz:dev" ]
  [ "$(jq -r 'select(.event=="tasks_guard_block") | .detail.file' .cc-sessions/activity-feed.jsonl | sort -u)" = "progress.md" ]
}

@test "subagent: blocks shell writes to progress.md, allows reads and git add" {
  assert_blocks "tasks-guard.sh" "$(sub_tool_input "echo '## done' >> docs/plans/demo/progress.md")"
  assert_blocks "tasks-guard.sh" "$(sub_tool_input "sed -i 's/open/done/' docs/plans/demo/progress.md")"
  assert_blocks "tasks-guard.sh" "$(sub_tool_input "bash scripts/tasks.sh verify demo T-001 && echo ok >> docs/plans/demo/progress.md")"
  assert_allows "tasks-guard.sh" "$(sub_tool_input "tail -20 docs/plans/demo/progress.md")"
  assert_allows "tasks-guard.sh" "$(sub_tool_input "git add docs/plans/demo/progress.md")"
}

@test "main conversation (no agent_type) keeps editing progress.md" {
  assert_allows "tasks-guard.sh" "$(fake_edit_input "docs/plans/demo/progress.md" Edit)"
  assert_allows "tasks-guard.sh" "$(fake_edit_input "$FAKE_REPO/docs/plans/demo/progress.md" Write)"
  assert_allows "tasks-guard.sh" "$(fake_tool_input "echo '## done' >> docs/plans/demo/progress.md")"
}

@test "subagent: tasks.json behaviour is unchanged (writes blocked, reads and tasks.sh allowed)" {
  assert_blocks "tasks-guard.sh" "$(sub_edit_input "docs/plans/demo/tasks.json" Write)"
  assert_blocks "tasks-guard.sh" "$(sub_tool_input "cp /tmp/x docs/plans/demo/tasks.json")"
  assert_allows "tasks-guard.sh" "$(sub_tool_input "cat docs/plans/demo/tasks.json")"
  assert_allows "tasks-guard.sh" "$(sub_tool_input "bash scripts/tasks.sh verify demo T-001")"
  assert_allows "tasks-guard.sh" "$(sub_edit_input "docs/plans/demo/spec.md" Edit)"
}
