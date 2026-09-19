#!/usr/bin/env bats
# Tests for the worktree hook contract.
#
# Regression guard for the P0 in 3.0.1: blitz registered a WorktreeCreate hook
# that only logged. Per platform docs, configuring WorktreeCreate *replaces*
# git worktree creation entirely, the hook must print the created directory to
# stdout, and "if the hook fails or produces no path, worktree creation fails
# with an error". A registered no-op handler therefore broke `claude --worktree`,
# every `isolation: worktree` subagent, and background-session isolation in any
# project with blitz installed. It also made the platform skip .worktreeinclude.
#
# The fix is deregistration. These tests assert it stays deregistered, and that
# WorktreeRemove (which IS additive for git worktrees) keeps its exit-0 contract.

load '_helpers'

setup() {
  HOOKS_JSON="$(cd "$HOOKS_DIR/.." && pwd)/hooks.json"
}

@test "hooks.json does not register WorktreeCreate" {
  run jq -e '.hooks | has("WorktreeCreate")' "$HOOKS_JSON"
  [ "$status" -ne 0 ]
}

@test "no worktree-create.sh handler exists" {
  [ ! -f "$HOOKS_DIR/worktree-create.sh" ]
}

@test "hooks.json still registers WorktreeRemove" {
  run jq -e '.hooks | has("WorktreeRemove")' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
}

@test "worktree-remove.sh exits 0 on a well-formed event" {
  setup_fake_repo
  git init -q . 2>/dev/null || true
  run_hook "worktree-remove.sh" \
    "$(jq -n '{session_id:"test-session",hook_event_name:"WorktreeRemove",
               cwd:".",worktree_path:"/nonexistent/.claude/worktrees/feature-auth"}')"
  [ "$status" -eq 0 ]
  teardown_fake_repo
}

@test "worktree-remove.sh exits 0 on empty input (non-zero would fail removal)" {
  setup_fake_repo
  git init -q . 2>/dev/null || true
  run_hook "worktree-remove.sh" '{}'
  [ "$status" -eq 0 ]
  teardown_fake_repo
}

@test "worktree-remove.sh logs a worktree_remove feed event" {
  setup_fake_repo
  git init -q . 2>/dev/null || true
  run_hook "worktree-remove.sh" \
    "$(jq -n '{session_id:"test-session",hook_event_name:"WorktreeRemove",
               cwd:".",worktree_path:"/nonexistent/wt"}')"
  run feed_events
  [[ "$output" == *"worktree_remove"* ]]
  teardown_fake_repo
}

@test "no hook script reads worktree_path or branch from a WorktreeCreate payload" {
  # WorktreeCreate's only event-specific input field is `name`. Any script
  # extracting worktree_path/branch on that event is reading fields that do
  # not exist.
  run grep -rl 'hook_event_name.*WorktreeCreate' "$HOOKS_DIR"
  [ -z "$output" ]
}
