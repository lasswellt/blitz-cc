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

# ---------------------------------------------------------------------------
# Write branch (a test file emptied of every assertion) and the PowerShell tool,
# which shares the Bash|PowerShell matcher.
# ---------------------------------------------------------------------------

@test "blocks a Write that strips every assertion from an existing test file" {
  local f; f="$(mktemp -d)/a.test.ts"
  printf 'it("a", () => { expect(1).toBe(1) })\n' > "$f"
  assert_blocks "block-test-deletion.sh" \
    "$(jq -n --arg fp "$f" '{tool_name:"Write",tool_input:{file_path:$fp,content:"const x = 1;\n"},session_id:"t"}')"
}

@test "allows a Write that keeps assertions in an existing test file" {
  local f; f="$(mktemp -d)/a.test.ts"
  printf 'it("a", () => { expect(1).toBe(1) })\n' > "$f"
  assert_allows "block-test-deletion.sh" \
    "$(jq -n --arg fp "$f" '{tool_name:"Write",tool_input:{file_path:$fp,content:"it(\"b\", () => { expect(2).toBe(2) })\n"},session_id:"t"}')"
}

@test "blocks rm of a test file issued through the PowerShell tool" {
  assert_blocks "block-test-deletion.sh" \
    "$(jq -n '{tool_name:"PowerShell",tool_input:{command:"rm tests/user.test.js"},session_id:"t"}')"
}
