#!/usr/bin/env bats
# check-registry-validate.bats: schema lint for skills/_shared/check-registry.json.
# Covers what the 2026-10-12 review added to the validator (open items #14 and #16):
# detector_count recomputed from the rows, the axis enums (pillar, severity,
# consolidated_target, stacks), the source tag on vendored impeccable rows and the
# Apache-2.0 attribution block. The derivation invariant and the impeccable exit
# contract are covered in design-pillar.bats.

load _helpers

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATOR="$REPO_ROOT/hooks/scripts/check-registry-validate.sh"
  REGISTRY="$REPO_ROOT/skills/_shared/check-registry.json"
  TMPDIR="$(mktemp -d)"; cd "$TMPDIR"
}
teardown() { rm -rf "$TMPDIR"; }

# mutate '<jq filter>': write a mutated copy of the live registry to $TMPDIR/bad.json
mutate() { jq "$1" "$REGISTRY" > "$TMPDIR/bad.json"; }

@test "the live registry passes and the summary names the row count" {
  run bash "$VALIDATOR" "$REGISTRY"
  [ "$status" -eq 0 ]
  n=$(jq '.checks | length' "$REGISTRY")
  echo "$output" | grep -q "OK: $n checks"
  echo "$output" | grep -q 'detector_count matches the rows'
}

@test "the default registry path resolves from the script location, not the cwd" {
  # $PWD is a scratch dir with no registry; the validator still finds the plugin's.
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

# --- detector_count recomputed from the rows ---------------------------------

@test "a stale whole_registry row count fails and names the field" {
  mutate '.detector_count.whole_registry.rows -= 1'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'detector_count.whole_registry.rows: stored'
}

@test "a stale whole_registry reject count fails" {
  mutate '.detector_count.whole_registry.reject -= 1'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'detector_count.whole_registry.reject: stored'
}

@test "a stale design row or vendored count fails" {
  mutate '.detector_count.design.rows += 3 | .detector_count.design.vendored -= 1'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'detector_count.design.rows: stored'
  echo "$output" | grep -q 'detector_count.design.vendored: stored'
}

@test "a det-NN advisory id list that disagrees with the rows fails" {
  mutate '.detector_count.advisory_ids |= .[1:]'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'detector_count.advisory_ids: stored'
}

@test "a missing detector_count block fails" {
  mutate 'del(.detector_count)'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'detector_count block missing'
}

@test "adding a row without updating detector_count fails on the count, not only the floor" {
  mutate '.checks += [(.checks[] | select(.id=="det-09")) | .id = "det-99"]'
  n=$(jq '.detector_count.catalogued' "$REGISTRY")
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "detector_count.catalogued: stored $n but the rows compute $((n + 1))"
  echo "$output" | grep -q 'detector_count.whole_registry.rows: stored'
}

# --- axis enums ---------------------------------------------------------------

@test "an out-of-enum pillar fails (perf is spelled performance)" {
  mutate '(.checks[] | select(.id=="sem-perf") | .pillar) = "perf"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "sem-perf: pillar='perf' not in"
}

@test "an out-of-enum severity fails" {
  mutate '(.checks[] | select(.id=="det-05") | .severity) = "P4"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "det-05: severity='P4' not in"
}

@test "an out-of-enum consolidated_target fails" {
  mutate '(.checks[] | select(.id=="det-01") | .consolidated_target) = "review"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "det-01: consolidated_target='review' not in"
}

@test "an out-of-enum lane fails" {
  mutate '(.checks[] | select(.id=="det-01") | .lane) = "heuristic"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "det-01: lane='heuristic' not in"
}

@test "a stack id the toolchain table does not know fails; an empty stacks list fails" {
  mutate '(.checks[] | select(.id=="det-01") | .stacks) = ["node", "cobol"]
        | (.checks[] | select(.id=="det-02") | .stacks) = []'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "det-01: stacks \['cobol'\] not in"
  echo "$output" | grep -q 'det-02: stacks must be a non-empty list'
}

@test "the stacks enum follows templates/toolchain.default.json" {
  for id in $(jq -r '.stacks[].id' "$REPO_ROOT/templates/toolchain.default.json"); do
    jq --arg s "$id" '(.checks[] | select(.id=="det-01") | .stacks) = [$s]' "$REGISTRY" > "$TMPDIR/bad.json"
    run bash "$VALIDATOR" "$TMPDIR/bad.json"
    [ "$status" -eq 0 ]
  done
}

@test "a design row without layer or adapter fails" {
  mutate '(.checks[] | select(.id=="design-side-tab")) |= del(.layer, .adapter)'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'design-side-tab: design row layer=None not in'
  echo "$output" | grep -q 'design-side-tab: design row adapter=None not in'
}

# --- source tag and attribution (ATTRIBUTION.md §3, §5) -----------------------

@test "a vendored row whose source tag drops the license pointer fails" {
  mutate '(.checks[] | select(.id=="design-side-tab") | .source) = "impeccable@2.3.2 cli/engine/registry/antipatterns.mjs#side-tab (re-grounded, framework-adaptive)"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'design-side-tab: vendored impeccable row needs source'
}

@test "a vendored row with no source fails" {
  mutate '(.checks[] | select(.id=="design-gradient-text")) |= del(.source)'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'design-gradient-text: source missing or empty'
}

@test "a row is vendored by its detection command even when owner is changed" {
  mutate '(.checks[] | select(.id=="design-side-tab")) |= (.owner = "blitz" | .source = "blitz authorship")'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'design-side-tab: vendored impeccable row needs source'
}

@test "a vendored row pinned to a different impeccable version than the notice fails" {
  mutate '(.checks[] | select(.id=="design-side-tab") | .source) |= sub("impeccable@2\\.3\\.2"; "impeccable@2.4.0")'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'design-side-tab: source pins impeccable@2.4.0 but attribution.notice pins impeccable@2.3.2'
}

@test "a non-vendored row keeps a free-text source citation" {
  mutate '(.checks[] | select(.id=="det-01") | .source) = "a conference talk, 2026"'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 0 ]
}

@test "a non-vendored row without a source fails" {
  mutate '(.checks[] | select(.id=="det-01")) |= del(.source)'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'det-01: source missing or empty'
}

@test "a missing attribution block fails" {
  mutate 'del(.attribution)'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'attribution block missing'
}

@test "an attribution notice that no longer names the license fails" {
  mutate '.attribution.notice = "Modified by the Blitz project from pbakaus/impeccable@2.3.2."'
  run bash "$VALIDATOR" "$TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'attribution.notice must name'
}

@test "every vendored row carries the tag the CI grep counts" {
  # The ci.yml step fails when this count drops to zero; the validator keeps it equal
  # to the number of owner:impeccable rows.
  tagged=$(grep -c '"source": "impeccable@' "$REGISTRY")
  owned=$(jq '[.checks[] | select(.owner=="impeccable")] | length' "$REGISTRY")
  [ "$tagged" -gt 0 ]
  [ "$tagged" -eq "$owned" ]
  [ "$(jq '.detector_count.design.vendored' "$REGISTRY")" -eq "$owned" ]
}
