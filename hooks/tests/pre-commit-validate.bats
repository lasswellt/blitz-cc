#!/usr/bin/env bats
# Tests for hooks/scripts/pre-commit-validate.sh (PreToolUse Bash|PowerShell on
# `git commit`; BLOCKING, fail-closed through blitz_guard_input).
#
# The repo-level validators (version sync, SKILL.md lint, registry schema, protocol
# caps, section refs) resolve from CLAUDE_PLUGIN_ROOT or the git toplevel. In the
# throwaway repo neither carries them, so these cases exercise the staged-file
# checks and the guard contract; the validators have their own suites.
load '_helpers'

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  command -v git >/dev/null || skip "git not installed"
  setup_fake_repo
  git init -q .
  unset CLAUDE_PLUGIN_ROOT
}
teardown() { teardown_fake_repo; }

commit_input() { fake_tool_input "git commit -m 'x'"; }

@test "a command that is not a git commit passes without touching the index" {
  assert_allows "pre-commit-validate.sh" "$(fake_tool_input "ls -la")"
}

@test "a clean commit passes" {
  printf 'hello\n' > a.txt; git add a.txt
  assert_allows "pre-commit-validate.sh" "$(commit_input)"
}

@test "blocks a commit with a staged .env file, naming it" {
  printf 'SECRET=1\n' > .env; git add .env
  run_hook "pre-commit-validate.sh" "$(commit_input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Secret file staged: .env"* ]]
}

@test "blocks a commit with a staged key file" {
  printf 'k\n' > server.pem; git add server.pem
  assert_blocks "pre-commit-validate.sh" "$(commit_input)"
}

@test ".env.example is not a secret" {
  printf 'SECRET=\n' > .env.example; git add .env.example
  assert_allows "pre-commit-validate.sh" "$(commit_input)"
}

@test "banned code patterns warn but allow" {
  printf 'console.log(1)\n' > a.js; git add a.js
  run_hook "pre-commit-validate.sh" "$(commit_input)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: console.log"* ]]
}

@test "fails closed on stdin that is not a JSON object" {
  assert_blocks "pre-commit-validate.sh" 'not json at all'
}

@test "fails closed when jq is missing, and says why" {
  local p; p="$(nojq_path)"
  run env PATH="$p" bash "$HOOKS_DIR/pre-commit-validate.sh" <<< "$(commit_input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *"jq is not installed"* ]]
  rm -rf "$p"
}

@test "BLITZ_GUARD_FAIL_OPEN=1 lets unreadable input through" {
  BLITZ_GUARD_FAIL_OPEN=1 assert_allows "pre-commit-validate.sh" 'not json at all'
}

@test "hooks.json wires it with onFailure: block" {
  run jq -r '[.hooks.PreToolUse[].hooks[] | select(.command | endswith("pre-commit-validate.sh")) | .onFailure] | unique | join(",")' "$HOOKS_DIR/../hooks.json"
  [ "$status" -eq 0 ]
  [ "$output" = "block" ]
}
