#!/usr/bin/env bats
# Tests for scripts/toolchain.sh and the two language-agnostic post-edit hooks.
#
# Before 3.1.0 post-edit-format.sh carried a JS/TS extension allowlist and
# post-edit-typecheck-block.sh opened with `[[ -f tsconfig.json ]] || exit 0`,
# so formatting, linting and the diagnostic ratchet were all silent no-ops in
# every non-TypeScript repository. These tests pin the replacement: a data
# table, one executor, and a per-language baseline.

load '_helpers'

setup() {
  # HOOKS_DIR is exported by _helpers and is the only path that survives bats
  # preprocessing; ${BASH_SOURCE[0]} at file scope points at a temp file.
  PLUGIN_ROOT="$(cd "$HOOKS_DIR/../.." && pwd)"
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
  TC="$PLUGIN_ROOT/scripts/toolchain.sh"
}

# A table whose every row runs a stub on PATH, so resolution is deterministic
# regardless of which real toolchains the test host happens to have installed.
write_stub_table() {
  mkdir -p stub
  cat > stub/bin-probe <<'EOF'
#!/bin/sh
exit 0
EOF
  cat > stub/checker <<'EOF'
#!/bin/sh
n=$(cat .stub-errors 2>/dev/null || echo 0)
i=0
while [ "$i" -lt "$n" ]; do
  echo "src/x.zz:$((i+1)):1: error: stub diagnostic"
  i=$((i+1))
done
exit 0
EOF
  chmod +x stub/bin-probe stub/checker
  export PATH="$PWD/stub:$PATH"
  cat > stub-table.json <<'EOF'
{
  "$schema": "blitz-toolchain/1.0",
  "stacks": [ { "id": "zz", "markers": ["zz.marker"] } ],
  "lanes": {
    "format": [
      { "id": "zz-fmt",  "stack": "zz", "match": "\\.zz$", "probe": ["bin-probe"], "cmd": ["bin-probe"] },
      { "id": "zz-fmt2", "stack": "zz", "match": "\\.zz$", "probe": ["bin-probe"], "cmd": ["bin-probe"] }
    ],
    "typecheck": [
      { "id": "zz-check", "stack": "zz", "match": "\\.zz$", "probe": ["bin-probe"],
        "cmd": ["checker"], "counter": "regex:: error: " }
    ]
  }
}
EOF
  export BLITZ_TOOLCHAIN_TABLE="$PWD/stub-table.json"
}

@test "stacks: detects node, python, rust and go from their markers" {
  setup_fake_repo
  touch package.json pyproject.toml Cargo.toml go.mod
  run bash "$TC" stacks
  [[ "$output" == *node* ]]
  [[ "$output" == *python* ]]
  [[ "$output" == *rust* ]]
  [[ "$output" == *go* ]]
  teardown_fake_repo
}

@test "stacks: an empty directory detects nothing" {
  setup_fake_repo
  run bash "$TC" stacks
  [ -z "$output" ]
  teardown_fake_repo
}

@test "stacks: a language added after the first call is seen immediately" {
  # Regression guard: a TTL-cached stack list would miss this for an hour, and
  # a ratchet that does not notice a new language is worse than no cache saving.
  setup_fake_repo
  touch package.json
  run bash "$TC" stacks
  [[ "$output" != *rust* ]]
  touch Cargo.toml
  run bash "$TC" stacks
  [[ "$output" == *rust* ]]
  teardown_fake_repo
}

@test "resolve: returns nothing when the file matches no row" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  run bash "$TC" resolve format a.unknown
  [ -z "$output" ]
  teardown_fake_repo
}

@test "resolve: returns nothing when the stack marker is absent" {
  setup_fake_repo
  write_stub_table
  run bash "$TC" resolve format a.zz
  [ -z "$output" ]
  teardown_fake_repo
}

@test "resolve: picks the first matching row in table order" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  run bash "$TC" resolve format a.zz
  [[ "$output" == *'"id":"zz-fmt"'* ]]
  teardown_fake_repo
}

@test "resolve: .blitz-toolchain.json can disable a row" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  echo '{"disable":["zz-fmt"]}' > .blitz-toolchain.json
  run bash "$TC" resolve format a.zz
  [[ "$output" == *'"id":"zz-fmt2"'* ]]
  teardown_fake_repo
}

@test "resolve: .blitz-toolchain.json can reorder preference" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  echo '{"prefer":{"format":["zz-fmt2"]}}' > .blitz-toolchain.json
  run bash "$TC" resolve format a.zz
  [[ "$output" == *'"id":"zz-fmt2"'* ]]
  teardown_fake_repo
}

@test "resolve: a cmd supplied by the checkout is ignored (TB-1)" {
  # The checkout is untrusted inbound data. A project that could name the argv
  # would have arbitrary execution on every edit, so only the plugin-shipped
  # table supplies cmd; the override schema carries disable/prefer only.
  setup_fake_repo
  write_stub_table
  touch zz.marker
  echo '{"lanes":{"format":[{"id":"evil","stack":"zz","match":"\\.zz$","cmd":["sh","-c","touch PWNED"]}]}}' > .blitz-toolchain.json
  run bash "$TC" run format a.zz
  [ ! -f PWNED ]
  teardown_fake_repo
}

@test "post-edit-format: exits 0 when no row resolves" {
  setup_fake_repo
  write_stub_table
  printf 'x\n' > a.unknown
  run_hook "post-edit-format.sh" "$(fake_edit_input "a.unknown")"
  [ "$status" -eq 0 ]
  teardown_fake_repo
}

@test "post-edit-format: exits 0 for a language with no toolchain installed" {
  setup_fake_repo
  touch Cargo.toml
  printf 'fn main() {}\n' > a.rs
  run_hook "post-edit-format.sh" "$(fake_edit_input "a.rs")"
  [ "$status" -eq 0 ]
  teardown_fake_repo
}

@test "typecheck ratchet: first run records the floor instead of blocking" {
  # A repo with pre-existing diagnostics must not have its first edit refused
  # over errors that edit did not cause.
  setup_fake_repo
  write_stub_table
  touch zz.marker
  echo 3 > .stub-errors
  printf 'x\n' > a.zz
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  [ "$status" -eq 0 ]
  run jq -r '.lanes."zz-check".error_count' .cc-sessions/typecheck-baseline.json
  [ "$output" = "3" ]
  teardown_fake_repo
}

@test "typecheck ratchet: blocks when the diagnostic count increases" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  printf 'x\n' > a.zz
  echo 1 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  [ "$status" -eq 0 ]
  echo 4 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  [ "$status" -eq 2 ]
  teardown_fake_repo
}

@test "typecheck ratchet: allows and lowers the floor when diagnostics drop" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  printf 'x\n' > a.zz
  echo 5 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  echo 2 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  [ "$status" -eq 0 ]
  run jq -r '.lanes."zz-check".error_count' .cc-sessions/typecheck-baseline.json
  [ "$output" = "2" ]
  teardown_fake_repo
}

@test "typecheck ratchet: the baseline is keyed per lane, not global" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  printf 'x\n' > a.zz
  echo 2 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  run jq -r '.schema_version' .cc-sessions/typecheck-baseline.json
  [ "$output" = "2" ]
  run jq -r '.lanes | keys | join(",")' .cc-sessions/typecheck-baseline.json
  [ "$output" = "zz-check" ]
  teardown_fake_repo
}

@test "typecheck ratchet: BLITZ_DISABLE_TYPECHECK_BLOCK=1 opts out" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  printf 'x\n' > a.zz
  echo 1 > .stub-errors
  run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  echo 9 > .stub-errors
  BLITZ_DISABLE_TYPECHECK_BLOCK=1 run_hook "post-edit-typecheck-block.sh" "$(fake_edit_input "a.zz")"
  [ "$status" -eq 0 ]
  teardown_fake_repo
}

@test "test-disabling guard blocks a Python skip marker" {
  setup_fake_repo
  run_hook "block-test-disabling.sh" \
    "$(jq -nc '{tool_name:"Write",tool_input:{file_path:"test_auth.py",content:"@pytest.mark.skip(reason=\"wip\")\ndef test_login(): assert True\n"},session_id:"t"}')"
  [ "$status" -eq 2 ]
  teardown_fake_repo
}

@test "test-disabling guard blocks a Go t.Skip" {
  setup_fake_repo
  run_hook "block-test-disabling.sh" \
    "$(jq -nc '{tool_name:"Write",tool_input:{file_path:"auth_test.go",content:"func TestLogin(t *testing.T) { t.Skip(\"wip\") }\n"},session_id:"t"}')"
  [ "$status" -eq 2 ]
  teardown_fake_repo
}

@test "test-disabling guard blocks a Rust #[ignore]" {
  setup_fake_repo
  run_hook "block-test-disabling.sh" \
    "$(jq -nc '{tool_name:"Write",tool_input:{file_path:"lib_test.rs",content:"#[ignore]\nfn test_add() { assert_eq!(1,1); }\n"},session_id:"t"}')"
  [ "$status" -eq 2 ]
  teardown_fake_repo
}

@test "test-disabling guard honours the pinned escape hatch with a # comment" {
  setup_fake_repo
  run_hook "block-test-disabling.sh" \
    "$(jq -nc '{tool_name:"Write",tool_input:{file_path:"test_auth.py",content:"@pytest.mark.skip(reason=\"wip\")  # blitz:skip-pinned: #1234\ndef test_login(): assert True\n"},session_id:"t"}')"
  [ "$status" -eq 0 ]
  teardown_fake_repo
}
