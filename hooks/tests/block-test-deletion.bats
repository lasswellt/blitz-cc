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

# ---------------------------------------------------------------------------
# H3 boundary regression cases (HTC-2). Bare test dirs without a trailing
# slash must still block; generated artifacts under non-source trees must not.
# ---------------------------------------------------------------------------

@test "blocks rm -rf src/__tests__ (no trailing slash)" {
  assert_blocks "block-test-deletion.sh" \
    "$(fake_tool_input "rm -rf src/__tests__")"
}

@test "blocks rm -rf tests (bare top-level test dir)" {
  assert_blocks "block-test-deletion.sh" \
    "$(fake_tool_input "rm -rf tests")"
}

@test "allows rm of a compiled sourcemap (dist/app.test.js.map)" {
  assert_allows "block-test-deletion.sh" \
    "$(fake_tool_input "rm dist/app.test.js.map")"
}

@test "allows rm of a generated cache dir under node_modules" {
  assert_allows "block-test-deletion.sh" \
    "$(fake_tool_input "rm -rf node_modules/.cache/test")"
}
