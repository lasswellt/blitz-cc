#!/usr/bin/env bats
# Blocking PreToolUse guards fail closed: hooks.json carries onFailure: "block"
# (Claude Code >=2.1.295) and each guard exits 2 when it cannot read its input
# (blitz_guard_input in _lib/common.sh).

load '_helpers'

GUARDS=(tasks-guard pre-edit-guard block-test-deletion block-as-any-insertion
        block-test-disabling block-no-verify block-destructive-git block-destructive-sql)

# A PATH with the tools the guards use, minus jq.
nojq_path() {
  local d; d="$(mktemp -d)"
  local t
  for t in bash sh cat dirname basename git grep sed awk tr head tail date mkdir env cut wc sort; do
    local p; p="$(command -v "$t" 2>/dev/null)" || continue
    ln -s "$p" "$d/$t"
  done
  printf '%s' "$d"
}

@test "every blocking PreToolUse guard is wired with onFailure: block" {
  local root="$HOOKS_DIR/../.."
  for g in kill-switch "${GUARDS[@]}"; do
    run jq -r --arg g "$g.sh" '[.hooks.PreToolUse[].hooks[] | select(.command | endswith($g)) | .onFailure] | unique | join(",")' "$root/hooks/hooks.json"
    [ "$status" -eq 0 ]
    [ "$output" = "block" ] || { echo "$g: onFailure=[$output]"; return 1; }
  done
}

@test "advisory hooks stay fail-open (no onFailure)" {
  local root="$HOOKS_DIR/../.."
  run jq -r '[.hooks | to_entries[] | select(.key != "PreToolUse") | .value[].hooks[] | select(.onFailure != null)] | length' "$root/hooks/hooks.json"
  [ "$output" = "0" ]
}

@test "each guard blocks a payload that is not a JSON object" {
  for g in "${GUARDS[@]}"; do
    assert_blocks "$g.sh" 'not json at all' || { echo "guard: $g"; return 1; }
  done
}

@test "each guard blocks when jq is missing, and says why" {
  local p; p="$(nojq_path)"
  for g in "${GUARDS[@]}"; do
    run env PATH="$p" bash "$HOOKS_DIR/$g.sh" <<< "$(fake_tool_input 'ls')"
    [ "$status" -eq 2 ] || { echo "$g exited $status"; return 1; }
    [[ "$output" == *"jq is not installed"* ]] || { echo "$g: $output"; return 1; }
  done
  rm -rf "$p"
}

@test "BLITZ_GUARD_FAIL_OPEN=1 restores fail-open on unreadable input" {
  for g in "${GUARDS[@]}"; do
    run env BLITZ_GUARD_FAIL_OPEN=1 bash "$HOOKS_DIR/$g.sh" <<< 'not json at all'
    [ "$status" -eq 0 ] || { echo "$g exited $status"; return 1; }
  done
}

@test "a well-formed harmless call still passes every guard" {
  for g in block-no-verify block-destructive-git block-destructive-sql block-test-deletion; do
    assert_allows "$g.sh" "$(fake_tool_input 'ls -la')" || { echo "guard: $g"; return 1; }
  done
}
