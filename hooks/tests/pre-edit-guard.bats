#!/usr/bin/env bats
# Tests for hooks/scripts/pre-edit-guard.sh (PreToolUse Write|Edit, BLOCKING)
# Blocks a Write/Edit whose tool_input.file_path is a .env* file (except
# .env.development and .env.example), a package lockfile, a key or credential
# file, a .git/ internal, or anything under node_modules/. Ordinary files pass.
# Fails closed through blitz_guard_input; the jq-missing path and the
# hooks.json onFailure wiring are covered by guard-fail-closed.bats.
# Requires: bats-core, jq

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; }
teardown() { teardown_fake_repo; }

# edit_payload <file_path> [tool_name] [agent_type]
edit_payload() {
  jq -nc --arg fp "$1" --arg tn "${2:-Write}" --arg at "${3:-}" \
    '{tool_name:$tn, tool_input:{file_path:$fp}, session_id:"test-session"}
     + (if $at == "" then {} else {agent_type:$at} end)'
}

# expect_block <file_path> <reason fragment>: the guard exits 2 and names the reason.
expect_block() {
  run_hook "pre-edit-guard.sh" "$(edit_payload "$1")"
  [ "$status" -eq 2 ] || { echo "$1: expected exit 2, got $status"; return 1; }
  [[ "$output" == *"$2"* ]] || { echo "$1: reason missing [$2]: $output"; return 1; }
}

# expect_allow <file_path>: the guard exits 0 and stays silent.
expect_allow() {
  run_hook "pre-edit-guard.sh" "$(edit_payload "$1")"
  [ "$status" -eq 0 ] || { echo "$1: expected exit 0, got $status"; return 1; }
  [ -z "$output" ] || { echo "$1: unexpected output: $output"; return 1; }
}

@test "an ordinary source file passes silently" {
  expect_allow /repo/src/app.ts
  expect_allow src/lib/util.py
  expect_allow /repo/README.md
}

@test ".env files are blocked and the reason names the two editable variants" {
  local f
  for f in .env .env.local .env.production .env.staging.secret; do
    expect_block "/repo/$f" "BLOCKED: Editing $f is not allowed. Only .env.development and .env.example may be edited."
  done
}

@test ".env.development and .env.example pass" {
  expect_allow /repo/.env.development
  expect_allow /repo/.env.example
}

@test "package lockfiles are blocked with a pointer to the package manager" {
  local f
  for f in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb composer.lock Gemfile.lock poetry.lock; do
    expect_block "/repo/$f" "BLOCKED: Editing lock file $f is not allowed. Use the package manager"
  done
}

@test "key and certificate files are blocked by extension" {
  local f
  for f in server.pem id_rsa.key client.p12 cert.pfx release.keystore app.jks; do
    expect_block "/repo/secrets/$f" "BLOCKED: Editing secret/key file $f is not allowed."
  done
}

@test "credential JSON files are blocked by name" {
  local f
  for f in credentials.json service-account.json serviceAccountKey.json my-secret-config.json; do
    expect_block "/repo/config/$f" "BLOCKED: Editing secret/key file $f is not allowed."
  done
}

@test "git internals are blocked by absolute and relative path" {
  expect_block /repo/.git/config "git internal files"
  expect_block .git/HEAD "git internal files"
  expect_block /repo/.git/hooks/pre-commit "git internal files"
}

@test "paths that merely start with .git pass" {
  expect_allow /repo/.gitignore
  expect_allow /repo/.github/workflows/ci.yml
  expect_allow /repo/.gitattributes
}

@test "anything under node_modules/ is blocked" {
  expect_block /repo/node_modules/left-pad/index.js "inside node_modules"
  expect_block node_modules/left-pad/index.js "inside node_modules"
}

@test "a filename that contains node_modules without the directory passes" {
  expect_allow /repo/src/node_modules_shim.ts
}

@test "the decision keys on tool_input.file_path for Write, Edit and NotebookEdit alike" {
  local tn
  for tn in Write Edit NotebookEdit; do
    run_hook "pre-edit-guard.sh" "$(edit_payload /repo/.env "$tn")"
    [ "$status" -eq 2 ] || { echo "$tn on .env: exit $status"; return 1; }
    run_hook "pre-edit-guard.sh" "$(edit_payload /repo/src/app.ts "$tn")"
    [ "$status" -eq 0 ] || { echo "$tn on app.ts: exit $status"; return 1; }
  done
}

@test "a payload without file_path passes (the guard never inspects notebook_path)" {
  run_hook "pre-edit-guard.sh" '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/repo/.env"},"session_id":"test-session"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fails closed on stdin that is not a JSON object, naming the guard" {
  local bad
  for bad in 'not json at all' '' '[1,2]' '"string"'; do
    run_hook "pre-edit-guard.sh" "$bad"
    [ "$status" -eq 2 ] || { echo "[$bad]: expected exit 2, got $status"; return 1; }
    [[ "$output" == *"BLOCKED by blitz pre-edit-guard: hook input is not a JSON object"* ]] || { echo "[$bad]: $output"; return 1; }
  done
}

@test "frontend agent touching backend paths: warning on stderr, edit allowed" {
  run_hook "pre-edit-guard.sh" "$(edit_payload /repo/functions/api.ts Edit frontend-dev)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: frontend agent editing backend file: /repo/functions/api.ts"* ]]
  run_hook "pre-edit-guard.sh" "$(edit_payload /repo/backend/server.ts Edit frontend-dev)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: frontend agent editing backend file"* ]]
}

@test "backend agent touching frontend paths: warning on stderr, edit allowed" {
  local p
  for p in /repo/src/components/Button.tsx /repo/src/pages/index.tsx /repo/src/layouts/Main.tsx; do
    run_hook "pre-edit-guard.sh" "$(edit_payload "$p" Edit backend-dev)"
    [ "$status" -eq 0 ] || { echo "$p: exit $status"; return 1; }
    [[ "$output" == *"WARNING: backend agent editing frontend file: $p"* ]] || { echo "$p: $output"; return 1; }
  done
}

@test "an agent editing inside its own domain gets no warning" {
  run_hook "pre-edit-guard.sh" "$(edit_payload /repo/src/components/Button.tsx Edit frontend-dev)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook "pre-edit-guard.sh" "$(edit_payload /repo/functions/api.ts Edit backend-dev)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a protected target is blocked before any role warning is considered" {
  run_hook "pre-edit-guard.sh" "$(edit_payload /repo/functions/.env Edit frontend-dev)"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" != *"WARNING"* ]]
}
