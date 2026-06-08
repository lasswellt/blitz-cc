#!/usr/bin/env bats
# Tests for hooks/scripts/block-as-any-insertion.sh (PreToolUse on Write|Edit)
# Blocks NET-NEW `as any` / @ts-ignore / @ts-nocheck in non-test TS/Vue source.
# Env opt-out the hook actually reads: BLITZ_DISABLE_AS_ANY_BLOCK=1.
#
# NOTE: BATS_TEST_TMPDIR contains a `/test/` path segment, which the hook treats
# as a (test-exempt) scope. Source-file cases therefore use a clean mktemp dir
# with no test segment so the hook sees them as real source.

load '_helpers'

# Build a Write payload: tool_name=Write, file_path + content.
fake_write_content() {
  jq -n --arg fp "$1" --arg c "$2" \
    '{"tool_name":"Write","tool_input":{"file_path":$fp,"content":$c},"session_id":"test-session"}'
}

setup() {
  SRC_DIR="$(mktemp -d)"   # /tmp/tmp.XXXX — no /test/ segment
}

teardown() {
  [ -n "${SRC_DIR:-}" ] && rm -rf "$SRC_DIR"
  return 0
}

@test "blocks a Write that inserts 'as any' into a .ts source file" {
  assert_blocks "block-as-any-insertion.sh" \
    "$(fake_write_content "$SRC_DIR/foo.ts" "const x = y as any")"
}

@test "allows the same insertion when BLITZ_DISABLE_AS_ANY_BLOCK=1" {
  # Confirms the hook reads the documented opt-out env var.
  BLITZ_DISABLE_AS_ANY_BLOCK=1 assert_allows "block-as-any-insertion.sh" \
    "$(fake_write_content "$SRC_DIR/foo.ts" "const x = y as any")"
}

@test "allows 'as any' when justified with the inline blitz:any-allowed marker" {
  assert_allows "block-as-any-insertion.sh" \
    "$(fake_write_content "$SRC_DIR/foo.ts" "const x = y as any // blitz:any-allowed: vendor interop")"
}

@test "allows 'as any' in a test file (test fixtures are exempt)" {
  assert_allows "block-as-any-insertion.sh" \
    "$(fake_write_content "$SRC_DIR/foo.test.ts" "const x = y as any")"
}

@test "ignores non-TS files" {
  assert_allows "block-as-any-insertion.sh" \
    "$(fake_write_content "$SRC_DIR/readme.md" "const x = y as any")"
}
