#!/usr/bin/env bats
# Tests for hooks/scripts/block-destructive-git.sh

load '_helpers'

# block-destructive-git.sh uses 'is_dirty()' for some checks, which calls
# git status. The force-push guard to protected branches does NOT require
# a dirty tree — it always blocks. We test those directly.

@test "blocks git push --force to main" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --force origin main")"
}

@test "blocks git push -f to master" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push -f origin master")"
}

@test "blocks git push --force-with-lease to main" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --force-with-lease origin main")"
}

@test "allows git push origin HEAD (normal push)" {
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin HEAD")"
}

@test "allows git push to feature branch" {
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin feature/my-branch")"
}

@test "branch name with regex metachar does not falsely block" {
  # Branch name 'main|.*' should not match protected-branch check on a
  # git command that targets a different branch
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git branch -D some-other-branch")"
}

@test "allows non-git commands" {
  assert_allows "block-destructive-git.sh" "$(fake_tool_input "npm install")"
}
