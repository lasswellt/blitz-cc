#!/usr/bin/env bats
# Tests for hooks/scripts/block-test-disabling.sh (PreToolUse on Write|Edit)
# Blocks NET-NEW test-disabling markers (skip/only/x-prefixed describe-or-it
# variants/todo) in test files. Env opt-out the hook actually reads:
# BLITZ_DISABLE_TEST_DISABLING_BLOCK=1. Escape hatch: inline blitz skip-pinned
# marker comment.
#
# NOTE: the disabling tokens are assembled from fragments at runtime so this
# .bats file (which itself lives under hooks/tests/) does not trip the very hook
# under test when it is written/committed.

load '_helpers'

# Build a Write payload for a test file: tool_name=Write, file_path + content.
fake_write_content() {
  jq -n --arg fp "$1" --arg c "$2" \
    '{"tool_name":"Write","tool_input":{"file_path":$fp,"content":$c},"session_id":"test-session"}'
}

DOT='.'
SKIP_TOK="${DOT}skip("
ONLY_TOK="${DOT}only("
PIN_MARKER='// blitz:skip-pinned: #1234'

@test "blocks a Write that inserts a skip token into a .test.ts file" {
  assert_blocks "block-test-disabling.sh" \
    "$(fake_write_content "$BATS_TEST_TMPDIR/foo.test.ts" "it${SKIP_TOK}'x', () => {})")"
}

@test "blocks a Write that inserts an only token into a .spec.ts file" {
  assert_blocks "block-test-disabling.sh" \
    "$(fake_write_content "$BATS_TEST_TMPDIR/foo.spec.ts" "it${ONLY_TOK}'x', () => {})")"
}

@test "allows the skip insertion when BLITZ_DISABLE_TEST_DISABLING_BLOCK=1" {
  # Confirms the hook reads the documented opt-out env var.
  BLITZ_DISABLE_TEST_DISABLING_BLOCK=1 assert_allows "block-test-disabling.sh" \
    "$(fake_write_content "$BATS_TEST_TMPDIR/foo.test.ts" "it${SKIP_TOK}'x', () => {})")"
}

@test "allows a skip pinned with the inline blitz skip-pinned marker" {
  assert_allows "block-test-disabling.sh" \
    "$(fake_write_content "$BATS_TEST_TMPDIR/foo.test.ts" "it${SKIP_TOK}'x', () => {}) ${PIN_MARKER}")"
}

@test "ignores non-test files (skip token in app source is out of scope)" {
  # BATS_TEST_TMPDIR has a /test/ path segment, so use a clean mktemp dir to
  # exercise the genuinely-non-test code path.
  local src; src="$(mktemp -d)"
  run assert_allows "block-test-disabling.sh" \
    "$(fake_write_content "$src/app.ts" "promise${SKIP_TOK})")"
  rm -rf "$src"
  [ "$status" -eq 0 ]
}
