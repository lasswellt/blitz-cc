#!/usr/bin/env bats
# Tests for scripts/tasks.sh, the only writer of docs/plans/<slug>/tasks.json
load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; export BLITZ_PLANS_DIR="$FAKE_REPO/docs/plans"; TASKS="$HOOKS_DIR/../../scripts/tasks.sh"; }
teardown() { teardown_fake_repo; }

@test "init creates a schema-tagged tasks.json" {
  run bash "$TASKS" init demo
  [ "$status" -eq 0 ]
  [ "$(jq -r '."$schema"' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "blitz-tasks/1.0" ]
  [ "$(jq -r '.plan' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "demo" ]
}

@test "add refuses a task with no verify command" {
  run bash "$TASKS" add demo --id T-001 --title "x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no --verify-cmd"* ]]
}

@test "add refuses test-only verify unless --test-only-ok" {
  run bash "$TASKS" add demo --id T-001 --title "x" --verify-cmd "npx vitest run a.test.ts"
  [ "$status" -eq 2 ]
  run bash "$TASKS" add demo --id T-001 --title "x" --verify-cmd "npx vitest run a.test.ts" --test-only-ok
  [ "$status" -eq 0 ]
}

@test "add treats non-JS runners (rspec, dotnet test, mix test) as test-only" {
  run bash "$TASKS" add demo --id T-001 --title "x" --verify-cmd "bundle exec rspec spec/a_spec.rb"
  [ "$status" -eq 2 ]
  run bash "$TASKS" add demo --id T-001 --title "x" --verify-cmd "dotnet test" --verify-cmd "mix test"
  [ "$status" -eq 2 ]
  run bash "$TASKS" add demo --id T-001 --title "x" --verify-cmd "bundle exec rspec spec/a_spec.rb" --verify-cmd "! grep -q TODO lib/a.rb"
  [ "$status" -eq 0 ]
}

@test "add stores verify commands with timeouts and defaults" {
  bash "$TASKS" add demo --id T-001 --title "first" --files a.ts,b.ts --verify-cmd "true::30" --verify-cmd "! grep -q TODO a.ts"
  [ "$(jq -r '.tasks[0].verify[0].timeout' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "30" ]
  [ "$(jq -r '.tasks[0].verify[1].timeout' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "120" ]
  [ "$(jq -r '.tasks[0].files | length' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "2" ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "open" ]
  [ "$(jq -r '.tasks[0].passes' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "false" ]
}

@test "set status=done is refused until verify passes" {
  bash "$TASKS" add demo --id T-001 --title "first" --verify-cmd "true"
  run bash "$TASKS" set demo T-001 status=done
  [ "$status" -eq 2 ]
  run bash "$TASKS" set demo T-001 status=in_progress
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "in_progress" ]
}

@test "verify runs checks in order, records evidence, flips passes and status" {
  bash "$TASKS" add demo --id T-001 --title "first" --verify-cmd "true" --verify-cmd "echo ok"
  run bash "$TASKS" verify demo T-001
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].passes' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "true" ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "done" ]
  [ "$(jq -r '.tasks[0].last_verify.ok' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "true" ]
}

@test "verify failure keeps passes false and stores the failing command tail" {
  bash "$TASKS" add demo --id T-001 --title "first" --verify-cmd "echo boom; exit 1"
  run bash "$TASKS" verify demo T-001
  [ "$status" -eq 1 ]
  [ "$(jq -r '.tasks[0].passes' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "false" ]
  [ "$(jq -r '.tasks[0].last_verify.failed' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "echo boom; exit 1" ]
  [[ "$(jq -r '.tasks[0].last_verify.tail' "$BLITZ_PLANS_DIR/demo/tasks.json")" == *boom* ]]
}

@test "verify respects per-check timeout" {
  bash "$TASKS" add demo --id T-001 --title "slow" --verify-cmd "sleep 5::1"
  run bash "$TASKS" verify demo T-001
  [ "$status" -eq 1 ]
}

@test "three failed attempts trip the circuit breaker" {
  bash "$TASKS" add demo --id T-001 --title "first" --verify-cmd "false"
  bash "$TASKS" set demo T-001 attempts=+1 >/dev/null
  bash "$TASKS" set demo T-001 attempts=+1 >/dev/null
  run bash "$TASKS" set demo T-001 attempts=+1
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "blocked" ]
  [ "$(jq -r '.tasks[0].blocked_reason' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "circuit-breaker" ]
}

@test "next returns the first open task whose dependencies are done" {
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true"
  bash "$TASKS" add demo --id T-002 --title "b" --depends T-001 --verify-cmd "true"
  run bash "$TASKS" next demo
  [ "$(printf '%s' "$output" | jq -r .id)" = "T-001" ]
  bash "$TASKS" verify demo T-001 >/dev/null
  run bash "$TASKS" next demo
  [ "$(printf '%s' "$output" | jq -r .id)" = "T-002" ]
}

@test "set rejects passes/last_verify and unknown keys" {
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true"
  run bash "$TASKS" set demo T-001 passes=true
  [ "$status" -eq 2 ]
  run bash "$TASKS" set demo T-001 bogus=1
  [ "$status" -eq 2 ]
}

@test "set status=open attempts=0 unblocks a circuit-breaker task (breaker skipped on explicit status)" {
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true"
  bash "$TASKS" set demo T-001 attempts=3 >/dev/null
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "blocked" ]
  run bash "$TASKS" set demo T-001 status=open blocked_reason= attempts=0
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "open" ]
  [ "$(jq -r '.tasks[0].blocked_reason' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "null" ]
  # a bare attempts bump with no explicit status still trips the breaker
  bash "$TASKS" set demo T-001 attempts=3 >/dev/null
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "blocked" ]
}

@test "list --status and --json filter and emit an array" {
  bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true"
  bash "$TASKS" add demo --id T-002 --title "b" --verify-cmd "true"
  bash "$TASKS" verify demo T-001 >/dev/null
  run bash "$TASKS" list demo --status done --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'length')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].id')" = "T-001" ]
  run bash "$TASKS" list demo --status open
  [[ "$output" == *"T-002"* ]]
  [[ "$output" != *"T-001"* ]]
}

@test "add rejects an unknown origin and accepts learn and issue:N" {
  run bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" --origin sprint
  [ "$status" -eq 2 ]
  run bash "$TASKS" add demo --id T-001 --title "a" --verify-cmd "true" --origin learn
  [ "$status" -eq 0 ]
  run bash "$TASKS" add demo --id T-002 --title "b" --verify-cmd "true" --origin issue:42
  [ "$status" -eq 0 ]
}

# --- per-command verify evidence (3.3.0) -----------------------------------

@test "verify records per-command evidence on success" {
  bash "$TASKS" add demo --id T-001 --title t --verify-cmd 'echo hello' --verify-cmd 'true' --origin plan >/dev/null
  bash "$TASKS" verify demo T-001 >/dev/null
  run jq -r '.tasks[0].last_verify.runs | length' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" = "2" ]
  run jq -r '.tasks[0].last_verify.runs[0] | "\(.exit) \(.tail)"' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" = "0 hello" ]
  run jq -r '.tasks[0].last_verify.runs[0] | has("duration_ms") and has("recorded_at")' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" = "true" ]
}

@test "verify records the failing command's evidence and stops there" {
  bash "$TASKS" add demo --id T-002 --title t \
    --verify-cmd 'echo "boom" >&2; exit 3' --verify-cmd 'echo never' --origin plan >/dev/null
  run bash "$TASKS" verify demo T-002
  [ "$status" -ne 0 ]
  # Only the command that ran is recorded; the one after the failure is not.
  run jq -r '.tasks[0].last_verify.runs | length' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" = "1" ]
  run jq -r '.tasks[0].last_verify.runs[0].exit' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" = "3" ]
  run jq -r '.tasks[0].last_verify.runs[0].tail' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [[ "$output" == *boom* ]]
}

@test "verify evidence tail is capped" {
  bash "$TASKS" add demo --id T-003 --title t \
    --verify-cmd 'head -c 9000 /dev/zero | tr "\0" "x"; true' --origin plan >/dev/null
  BLITZ_VERIFY_EVIDENCE_CAP=500 bash "$TASKS" verify demo T-003 >/dev/null
  run jq -r '.tasks[0].last_verify.runs[0].tail | length' "$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$output" -le 500 ]
}

@test "every deterministic registry row carries an exit contract or is prose" {
  local reg="$HOOKS_DIR/../../skills/_shared/check-registry.json"
  run jq -r '[.checks[]
    | select(.lane=="deterministic")
    | select((.id|IN("det-17","det-18")) | not)
    | select(.detection.exit == null) | .id] | join(",")' "$reg"
  [ -z "$output" ]
}

@test "a grep-tailed detector passes on exit 1, not exit 0" {
  # `grep` exits 1 when it finds nothing, which is the PASS case for a
  # detector hunting for a bad pattern. Reading it as "non-zero means fail"
  # inverts every grep row in the registry.
  local reg="$HOOKS_DIR/../../skills/_shared/check-registry.json"
  run jq -r '.checks[] | select(.id=="det-05") | .detection.exit.pass | join(",")' "$reg"
  [ "$output" = "1" ]
  run jq -r '.checks[] | select(.id=="det-01") | .detection.exit.pass | join(",")' "$reg"
  [ "$output" = "0" ]
}

@test "counter rows take their verdict from stdout, not the exit code" {
  local reg="$HOOKS_DIR/../../skills/_shared/check-registry.json"
  run jq -r '.checks[] | select(.id=="det-03") | .detection.exit.verdict' "$reg"
  [ "$output" = "stdout" ]
}

# --- selective post-merge re-verify -----------------------------------------

@test "verify --changed re-verifies only tasks whose files the paths touch" {
  bash "$TASKS" add demo --id T-001 --title a --files src/a.rs --verify-cmd 'true' --origin plan >/dev/null
  bash "$TASKS" add demo --id T-002 --title b --files py/b.py --verify-cmd 'true' --origin plan >/dev/null
  bash "$TASKS" add demo --id T-003 --title c --files docs/c.md --verify-cmd 'true' --origin plan >/dev/null
  for i in T-001 T-002 T-003; do bash "$TASKS" verify demo "$i" >/dev/null; done
  run bash "$TASKS" verify demo --changed src/a.rs py/b.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 task(s) re-verified"* ]]
  [[ "$output" != *"T-003"* ]]
}

@test "verify --changed catches a break that survived a clean merge" {
  bash "$TASKS" add demo --id T-001 --title a --files src/a.rs \
    --verify-cmd 'test -f ok.flag' --origin plan >/dev/null
  touch ok.flag
  bash "$TASKS" verify demo T-001 >/dev/null
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "done" ]
  # A textually clean merge can still break a task semantically.
  rm ok.flag
  run bash "$TASKS" verify demo --changed src/a.rs
  [ "$status" -eq 1 ]
  [[ "$output" == *"T-001"* ]]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "in_progress" ]
  [ "$(jq -r '.tasks[0].passes' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "false" ]
}

@test "verify --changed matches by directory prefix in both directions" {
  bash "$TASKS" add demo --id T-001 --title a --files src/api --verify-cmd 'true' --origin plan >/dev/null
  bash "$TASKS" verify demo T-001 >/dev/null
  run bash "$TASKS" verify demo --changed src/api/handler.rs
  [[ "$output" == *"1 task(s) re-verified"* ]]
}

@test "verify --changed is a no-op when no done task owns the paths" {
  bash "$TASKS" add demo --id T-001 --title a --files src/a.rs --verify-cmd 'true' --origin plan >/dev/null
  bash "$TASKS" verify demo T-001 >/dev/null
  run bash "$TASKS" verify demo --changed unrelated/x.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to re-verify"* ]]
}

@test "verify --changed with no paths is a usage error" {
  # The plan must exist first, or require_file exits 3 (not found) before the
  # path check is ever reached.
  bash "$TASKS" init demo >/dev/null
  run bash "$TASKS" verify demo --changed
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs at least one path"* ]]
}

# --- portability and input validation (review 2026-10-12, item 21) ------------

# path_without <tool>: a PATH that resolves every tool tasks.sh needs except
# <tool>, to simulate a host that lacks it (stock macOS ships no `timeout`).
path_without() {
  local bin="$FAKE_REPO/bin-without-$1" t p
  mkdir -p "$bin"
  for t in bash sh jq git date mktemp mv rm cat tail head tr sed grep sleep column dirname basename mkdir wc cut sort od; do
    [ "$t" = "$1" ] && continue
    if p=$(command -v "$t" 2>/dev/null); then ln -s "$p" "$bin/$t"; fi
  done
  printf '%s' "$bin"
}

@test "list --status accepts only the loop.md status enum" {
  bash "$TASKS" add demo --id T-001 --title a --verify-cmd true
  run bash "$TASKS" list demo --status finished
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be open|in_progress|done|blocked"* ]]
  # a jq fragment is rejected as a value, never spliced into the filter
  run bash "$TASKS" list demo --status 'open") or true or ("'
  [ "$status" -eq 2 ]
  run bash "$TASKS" list demo --status
  [ "$status" -eq 2 ]
  [[ "$output" == *"--status needs a value"* ]]
  run bash "$TASKS" list demo --status blocked --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "writes stage their temp file beside tasks.json without GNU mktemp -p" {
  # A BSD-style mktemp rejects -p; the full-path template must carry the write.
  local bin="$FAKE_REPO/bin-bsd-mktemp" real
  mkdir -p "$bin"; real=$(command -v mktemp)
  printf '#!/usr/bin/env bash\ncase " $* " in *" -p "*|*" --tmpdir"*) echo "mktemp: illegal option -- p" >&2; exit 1;; esac\nexec "%s" "$@"\n' "$real" > "$bin/mktemp"
  chmod +x "$bin/mktemp"
  run env PATH="$bin:$PATH" mktemp -p "$FAKE_REPO" x.XXXXXX
  [ "$status" -ne 0 ]
  run env PATH="$bin:$PATH" bash "$TASKS" add demo --id T-001 --title a --verify-cmd true
  [ "$status" -eq 0 ]
  run env PATH="$bin:$PATH" bash "$TASKS" set demo T-001 status=in_progress
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "in_progress" ]
  [ -z "$(find "$BLITZ_PLANS_DIR/demo" -name '.tasks.*')" ]
}

@test "verify honors the per-check timeout without a timeout binary" {
  bash "$TASKS" add demo --id T-001 --title slow --verify-cmd "sleep 5::1"
  local bin; bin=$(path_without timeout)
  run env PATH="$bin" bash -c 'command -v timeout'
  [ "$status" -ne 0 ]
  run env PATH="$bin" bash "$TASKS" verify demo T-001
  [ "$status" -eq 1 ]
  [ "$(jq -r '.tasks[0].last_verify.runs[0].exit' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "124" ]
  [ "$(jq -r '.tasks[0].passes' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "false" ]
}

@test "verify without a timeout binary keeps the command's own exit code" {
  bash "$TASKS" add demo --id T-001 --title ok --verify-cmd "true" --verify-cmd "echo fine"
  bash "$TASKS" add demo --id T-002 --title bad --verify-cmd "exit 3"
  local bin; bin=$(path_without timeout)
  run env PATH="$bin" bash "$TASKS" verify demo T-001
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "done" ]
  [ "$(jq -r '.tasks[0].last_verify.runs[1].tail' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "fine" ]
  run env PATH="$bin" bash "$TASKS" verify demo T-002
  [ "$status" -eq 1 ]
  [ "$(jq -r '.tasks[1].last_verify.runs[0].exit' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "3" ]
}

seed_dep_plan() {
  bash "$TASKS" add demo --id T-001 --title a --verify-cmd "true"
  bash "$TASKS" add demo --id T-002 --title b --verify-cmd "true"
  bash "$TASKS" add demo --id T-003 --title c --verify-cmd "true"
}

@test "set depends_on sets and clears" {
  seed_dep_plan
  run bash "$TASKS" set demo T-002 depends_on=T-001,T-003
  [ "$status" -eq 0 ]
  [ "$(jq -c '.tasks[1].depends_on' "$BLITZ_PLANS_DIR/demo/tasks.json")" = '["T-001","T-003"]' ]
  run bash "$TASKS" set demo T-002 depends_on=
  [ "$status" -eq 0 ]
  [ "$(jq -c '.tasks[1].depends_on' "$BLITZ_PLANS_DIR/demo/tasks.json")" = '[]' ]
}

@test "set depends_on rejects an unknown id and a self-dependency" {
  seed_dep_plan
  run bash "$TASKS" set demo T-002 depends_on=T-009
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown task 'T-009'"* ]]
  run bash "$TASKS" set demo T-002 depends_on=T-002
  [ "$status" -eq 2 ]
  [[ "$output" == *"itself"* ]]
}

@test "set depends_on rejects a cycle and leaves the file unchanged" {
  seed_dep_plan
  bash "$TASKS" set demo T-002 depends_on=T-003
  bash "$TASKS" set demo T-003 depends_on=T-001
  before=$(cat "$BLITZ_PLANS_DIR/demo/tasks.json")
  run bash "$TASKS" set demo T-001 depends_on=T-002
  [ "$status" -eq 2 ]
  [[ "$output" == *"depends_on would create a cycle"* ]]
  [ "$(cat "$BLITZ_PLANS_DIR/demo/tasks.json")" = "$before" ]
}

@test "add-verify appends entries and resets passes" {
  bash "$TASKS" add demo --id T-001 --title a --verify-cmd "true"
  bash "$TASKS" verify demo T-001
  run bash "$TASKS" add-verify demo T-001 "echo hi::30" "true"
  [ "$status" -eq 0 ]
  f="$BLITZ_PLANS_DIR/demo/tasks.json"
  [ "$(jq '.tasks[0].verify | length' "$f")" = "3" ]
  [ "$(jq -r '.tasks[0].verify[1].timeout' "$f")" = "30" ]
  [ "$(jq -r '.tasks[0].verify[2].timeout' "$f")" = "120" ]
  [ "$(jq -r '.tasks[0].passes' "$f")" = "false" ]
  [ "$(jq -r '.tasks[0].last_verify' "$f")" = "null" ]
}

@test "add-verify on a done task reopens it" {
  bash "$TASKS" add demo --id T-001 --title a --verify-cmd "true"
  bash "$TASKS" verify demo T-001
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "done" ]
  run bash "$TASKS" add-verify demo T-001 "true::5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reopened"* ]]
  [ "$(jq -r '.tasks[0].status' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "open" ]
}

@test "add-verify rejects missing and empty commands, unknown task" {
  bash "$TASKS" add demo --id T-001 --title a --verify-cmd "true"
  run bash "$TASKS" add-verify demo T-001 ""
  [ "$status" -eq 2 ]
  run bash "$TASKS" add-verify demo T-001 "::30"
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty command"* ]]
  [ "$(jq '.tasks[0].verify | length' "$BLITZ_PLANS_DIR/demo/tasks.json")" = "1" ]
  run bash "$TASKS" add-verify demo T-009 "true"
  [ "$status" -eq 3 ]
}
