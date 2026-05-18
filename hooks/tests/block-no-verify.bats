#!/usr/bin/env bats
# Tests for hooks/scripts/block-no-verify.sh
# Requires: bats-core (https://github.com/bats-core/bats-core)

load '_helpers'

# Note: block-no-verify.sh calls jq -r '.tool_input.command' on stdin.
# It checks for --no-verify and -n (short form) in the command string.

@test "blocks git commit --no-verify" {
  assert_blocks "block-no-verify.sh" "$(fake_tool_input "git commit --no-verify -m 'test'")"
}

@test "blocks git commit -n (short form)" {
  assert_blocks "block-no-verify.sh" "$(fake_tool_input "git commit -n -m 'test'")"
}

@test "blocks git commit -n at end of command" {
  assert_blocks "block-no-verify.sh" "$(fake_tool_input "git commit -m 'test' -n")"
}

@test "allows normal git commit (no verify flag)" {
  assert_allows "block-no-verify.sh" "$(fake_tool_input "git commit -m 'normal commit'")"
}

@test "allows non-git commands" {
  assert_allows "block-no-verify.sh" "$(fake_tool_input "npm test")"
}

@test "allows empty command" {
  assert_allows "block-no-verify.sh" "$(fake_tool_input "")"
}

@test "BLITZ_OVERRIDE_NO_VERIFY=1 allows commit --no-verify" {
  BLITZ_OVERRIDE_NO_VERIFY=1 assert_allows "block-no-verify.sh" \
    "$(fake_tool_input "git commit --no-verify -m 'emergency'")"
}
