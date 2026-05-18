#!/usr/bin/env bats
# Tests for hooks/scripts/block-test-deletion.sh (PreToolUse Write|Edit + Bash matchers)
# This hook fires on Bash commands that delete test files.

load '_helpers'

@test "blocks rm on a spec file" {
  assert_blocks "block-test-deletion.sh" \
    "$(fake_tool_input "rm -f src/auth.spec.ts")"
}

@test "blocks rm on a test file" {
  assert_blocks "block-test-deletion.sh" \
    "$(fake_tool_input "rm tests/user.test.js")"
}

@test "allows rm on non-test files" {
  assert_allows "block-test-deletion.sh" \
    "$(fake_tool_input "rm -f dist/bundle.js")"
}

@test "allows ls command" {
  assert_allows "block-test-deletion.sh" \
    "$(fake_tool_input "ls tests/")"
}
