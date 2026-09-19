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

# --- spawn invariant (SubagentStart) ---------------------------------------

@test "spawn invariant: injected for blitz:dev" {
  setup_fake_repo
  run_hook "subagent-context.sh" \
    "$(jq -nc '{hook_event_name:"SubagentStart",agent_id:"a1",agent_type:"blitz:dev",session_id:"t"}')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName":"SubagentStart"'* ]]
  [[ "$output" == *"Never-edit list"* ]]
  teardown_fake_repo
}

@test "spawn invariant: injected for blitz:test-writer" {
  setup_fake_repo
  run_hook "subagent-context.sh" \
    "$(jq -nc '{hook_event_name:"SubagentStart",agent_id:"a1",agent_type:"blitz:test-writer",session_id:"t"}')"
  [[ "$output" == *"additionalContext"* ]]
  teardown_fake_repo
}

@test "spawn invariant: not injected for other agent types" {
  setup_fake_repo
  for t in Explore general-purpose blitz:critic blitz:research-critic; do
    run_hook "subagent-context.sh" \
      "$(jq -nc --arg t "$t" '{hook_event_name:"SubagentStart",agent_id:"a1",agent_type:$t,session_id:"t"}')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  teardown_fake_repo
}

@test "spawn invariant: the injected block is byte-identical across spawns" {
  # The whole point of moving this out of the prompt is that it does not vary.
  # A timestamp, session id or command output in here would defeat it.
  setup_fake_repo
  run_hook "subagent-context.sh" \
    "$(jq -nc '{hook_event_name:"SubagentStart",agent_id:"a1",agent_type:"blitz:dev",session_id:"s1"}')"
  local first="$output"
  sleep 1
  run_hook "subagent-context.sh" \
    "$(jq -nc '{hook_event_name:"SubagentStart",agent_id:"a2",agent_type:"blitz:dev",session_id:"s2"}')"
  [ "$first" = "$output" ]
  teardown_fake_repo
}

@test "spawn invariant: BLITZ_DISABLE_SPAWN_INVARIANT=1 opts out" {
  setup_fake_repo
  BLITZ_DISABLE_SPAWN_INVARIANT=1 run_hook "subagent-context.sh" \
    "$(jq -nc '{hook_event_name:"SubagentStart",agent_id:"a1",agent_type:"blitz:dev",session_id:"t"}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  teardown_fake_repo
}

@test "spawn invariant: hooks.json registers it with an anchored plugin-scoped matcher" {
  # A plugin-scoped agent type contains ':', which puts the matcher on the
  # regex path; an unanchored matcher would also catch blitz:dev-something.
  run jq -r '.hooks.SubagentStart[0].matcher' "$(cd "$HOOKS_DIR/.." && pwd)/hooks.json"
  [ "$output" = '^blitz:(dev|test-writer)$' ]
}

@test "every blitz agent sets experimental.cacheTtl" {
  # Subagents fall outside the main-conversation TTL bucket and get 5 minutes
  # by default, so a critic re-spawned in a fix loop pays a cold prefix.
  local root; root="$(cd "$HOOKS_DIR/../.." && pwd)"
  for f in "$root"/agents/*.md; do
    grep -q 'cacheTtl' "$f" || { echo "missing cacheTtl: $f" >&2; return 1; }
  done
}

# --- whole-project lanes ----------------------------------------------------

@test "lanes: attributes each row to its own stack" {
  # Whole-project lanes (test, build) match any extension, so without a stack
  # filter the first stack in table order wins every lookup and rows land under
  # the wrong language.
  setup_fake_repo
  touch pyproject.toml Cargo.toml
  run bash "$TC" lanes
  [[ "$output" != *"test"$'\t'"rust"$'\t'"python-"* ]]
  [[ "$output" != *"build"$'\t'"python"$'\t'"rust-"* ]]
  teardown_fake_repo
}

@test "resolve: a stack filter restricts to that stack's rows" {
  setup_fake_repo
  write_stub_table
  touch zz.marker
  run bash "$TC" resolve format a.zz zz
  [[ "$output" == *'"id":"zz-fmt"'* ]]
  run bash "$TC" resolve format a.zz nosuchstack
  [ -z "$output" ]
  teardown_fake_repo
}

@test "run: with no file runs the lane once per detected stack" {
  setup_fake_repo
  mkdir -p stub
  printf '#!/bin/sh\n[ "$1" = "--version" ] && exit 0\necho "ran-$0"\n' > stub/tool-a
  cp stub/tool-a stub/tool-b
  chmod +x stub/tool-a stub/tool-b
  export PATH="$PWD/stub:$PATH"
  cat > two-stack.json <<'EOF'
{ "$schema": "blitz-toolchain/1.0",
  "stacks": [ {"id":"aa","markers":["aa.marker"]}, {"id":"bb","markers":["bb.marker"]} ],
  "lanes": { "test": [
    {"id":"aa-test","stack":"aa","match":".*","probe":["tool-a","--version"],"cmd":["tool-a"]},
    {"id":"bb-test","stack":"bb","match":".*","probe":["tool-b","--version"],"cmd":["tool-b"]} ] } }
EOF
  export BLITZ_TOOLCHAIN_TABLE="$PWD/two-stack.json"
  touch aa.marker bb.marker
  run bash "$TC" run test
  [[ "$output" == *tool-a* ]]
  [[ "$output" == *tool-b* ]]
  teardown_fake_repo
}

@test "no registry row references an undefined variable" {
  # det-11/det-12 called toolchain.sh with ${BLITZ_PROBE_FILE}, which was set
  # nowhere; a bare `run <lane>` now means every detected stack.
  local reg="$HOOKS_DIR/../../skills/_shared/check-registry.json"
  run grep -c 'BLITZ_PROBE_FILE' "$reg"
  [ "$output" = "0" ]
}

# --- skill body budget ------------------------------------------------------

@test "every SKILL.md body is under the compaction re-attach cap" {
  # Claude Code re-attaches an invoked skill after compaction keeping only the
  # FIRST 5,000 TOKENS. Markdown puts terminal phases last, so an over-cap body
  # loses its verdict, gate, report and recovery — exactly what a long session
  # needs, and a long session is when compaction fires.
  local root; root="$(cd "$HOOKS_DIR/../.." && pwd)"
  local over=0 f b
  for f in "$root"/skills/*/SKILL.md; do
    b=$(awk 'f{print} /^---$/{c++; if(c==2) f=1}' "$f" | wc -c | tr -d ' ')
    if [ "$b" -gt 18000 ]; then
      echo "over cap: $f (${b}B)" >&2
      over=1
    fi
  done
  [ "$over" -eq 0 ]
}

@test "terminal phases sit inside the 5,000-token cut point" {
  # Not just "under the cap" — the closing sections specifically must survive.
  local root; root="$(cd "$HOOKS_DIR/../.." && pwd)"
  local bad=0 f body off
  for f in "$root"/skills/*/SKILL.md; do
    body=$(awk 'f{print} /^---$/{c++; if(c==2) f=1}' "$f")
    for h in '## Recovery' '## Report' '## Gate' '## Gotchas' '## Error Recovery'; do
      off=$(printf '%s' "$body" | grep -bF "$h" | head -1 | cut -d: -f1)
      [ -z "$off" ] && continue
      if [ "$((off / 4))" -gt 5000 ]; then
        echo "past the cut point: $f '$h' at ~$((off / 4)) tok" >&2
        bad=1
      fi
    done
  done
  [ "$bad" -eq 0 ]
}
