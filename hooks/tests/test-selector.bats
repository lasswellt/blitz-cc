#!/usr/bin/env bats
# Tests for scripts/test-selector.sh (E-043 S2 — impacted-test selection)
# Requires: bats-core, jq, python3, git

load '_helpers'

SELECTOR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/test-selector.sh"
LISTENER="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/test-listener.sh"
FIXTURE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/fixtures/tia"

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  setup_fake_repo
  cp -r "$FIXTURE/." "$FAKE_REPO/"
  git init -q "$FAKE_REPO" && git -C "$FAKE_REPO" add -A \
    && git -C "$FAKE_REPO" -c user.email=t@t -c user.name=t commit -qm init
}
teardown() { teardown_fake_repo; }

# sel — selector with stderr dropped (`run` merges stderr into $output; the
# cold-start / graph notes there are not part of the contract under test).
sel() { bash "$SELECTOR" "$@" 2>/dev/null; }

# seed_journal — one recorded run where tests/b.test.ts failed after src/b.ts changed
seed_journal() {
  bash "$LISTENER" --start --run-id r1
  bash "$LISTENER" --trigger post-edit --changed src/b.ts --selected-by selector --run-id r1 < vitest-report.json
}

@test "cold start: graph reaches the transitive test (b.ts -> a.ts -> a.test.ts)" {
  run sel src/b.ts
  [ "$status" -eq 0 ]
  echo "$output" | grep -qP '^tests/b\.test\.ts\tgraph$'
  echo "$output" | grep -qP '^tests/a\.test\.ts\tgraph$'
  [ "$(echo "$output" | wc -l | tr -d ' ')" = "2" ]
}

@test "cold start: a.ts selects only a.test.ts" {
  run sel src/a.ts
  [ "$output" = "$(printf 'tests/a.test.ts\tgraph')" ]
}

@test "sibling matcher: same-dir <name>.test.ts and __tests__/<name>.ts" {
  printf 'export const c = 1\n' > src/c.ts
  printf 'import { c } from "./c"\n' > src/c.test.ts
  mkdir -p src/__tests__ && printf 'export {}\n' > src/__tests__/c.ts
  run sel src/c.ts
  echo "$output" | grep -qP '^src/c\.test\.ts\tsibling,graph$'
  echo "$output" | grep -qP '^src/__tests__/c\.ts\tsibling$'
}

@test "changed test file selects itself" {
  run sel tests/a.test.ts
  echo "$output" | grep -qP '^tests/a\.test\.ts\tsibling$'
}

@test "files on stdin, one per line" {
  run bash -c "printf 'src/a.ts\n' | bash '$SELECTOR' 2>/dev/null"
  [ "$output" = "$(printf 'tests/a.test.ts\tgraph')" ]
}

@test "journal recent-fail + co-change tags" {
  seed_journal
  run sel src/b.ts
  echo "$output" | grep -qP '^tests/b\.test\.ts\tgraph,recent-fail,co-change$'
  run sel src/a.ts
  echo "$output" | grep -qP '^tests/b\.test\.ts\trecent-fail$'
  run sel README.md
  [ "$output" = "$(printf 'tests/b.test.ts\trecent-fail')" ]
}

@test "recent-fail only looks at the last 5 runs" {
  seed_journal
  for i in 2 3 4 5 6 7; do
    sed 's/"status": "failed"/"status": "passed"/; s/"failed"/"passed"/g' vitest-report.json \
      | bash "$LISTENER" --trigger ci --run-id "r$i"
  done
  run sel README.md
  [ -z "$output" ]
}

@test "--full tags every test file" {
  run sel --full
  [ "$output" = "$(printf 'tests/a.test.ts\tfull\ntests/b.test.ts\tfull')" ]
}

@test "auto-full on config / lockfile / setup changes" {
  for f in package.json pnpm-lock.yaml vitest.config.ts tsconfig.json tests/setup.ts; do
    run sel "$f"
    echo "$output" | grep -qP '^tests/a\.test\.ts\tfull$' || { echo "no auto-full for $f"; false; }
  done
}

@test "auto-full when more than 40 files changed" {
  files=$(for i in $(seq 1 41); do printf 'src/f%s.ts ' "$i"; done)
  run sel $files
  echo "$output" | grep -qP '^tests/b\.test\.ts\tfull$'
}

@test "auto-full when escaped_failures_recent has a non-zero entry in the last 3" {
  printf '{"runs_started":0,"runs_recorded":0,"escaped_failures_recent":[3,0,1,0]}\n' > .cc-sessions/test-journal.meta.json
  run sel src/a.ts
  echo "$output" | grep -qP '^tests/b\.test\.ts\tfull$'
  printf '{"runs_started":0,"runs_recorded":0,"escaped_failures_recent":[3,0,0,0]}\n' > .cc-sessions/test-journal.meta.json
  run sel src/a.ts
  [ "$output" = "$(printf 'tests/a.test.ts\tgraph')" ]
}

@test "--json reports selection_ratio and graph mode" {
  run sel --json src/a.ts
  echo "$output" | jq -e '.mode=="selected" and .graph=="static" and .runner=="vitest"
    and .total_test_files==2 and .selection_ratio==0.5 and .selected[0].file=="tests/a.test.ts"' | grep -q true
}

@test "no args: uses git diff (staged + unstaged)" {
  printf '// touched\n' >> src/a.ts
  run sel
  [ "$output" = "$(printf 'tests/a.test.ts\tgraph')" ]
}

@test "resolver error falls back to the full set and exits 0" {
  run bash -c "PATH=/nonexistent \"$BASH\" '$SELECTOR' src/a.ts"
  [ "$status" -eq 0 ]
}
