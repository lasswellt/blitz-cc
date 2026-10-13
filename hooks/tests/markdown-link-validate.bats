#!/usr/bin/env bats
# Tests for hooks/scripts/markdown-link-validate.sh (broken relative .md links
# and malformed section citations). `--all`-style manual mode (no stdin) scans
# skills/, agents/, docs/ and, when present, CHANGELOG.md / CHANGELOG-ARCHIVE.md;
# exit 0 clean, 1 on a broken link or a ")§N" citation. The script cds to a
# REPO_ROOT derived from its own path, so each test copies it into a fixture
# tree at <fix>/hooks/scripts/ and runs it from there.
# Requires: bats-core

load '_helpers'

setup() {
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/hooks/scripts" "$FIX/skills" "$FIX/agents" "$FIX/docs"
  cp "$HOOKS_DIR/markdown-link-validate.sh" "$FIX/hooks/scripts/"
  printf '# A\n' > "$FIX/docs/a.md"
}
teardown() { rm -rf "$FIX"; }

# validate_fix: run the copied validator against $FIX with no stdin.
validate_fix() { run bash "$FIX/hooks/scripts/markdown-link-validate.sh" </dev/null; }

@test "clean fixture tree passes --all" {
  printf '[x](a.md)\n' > "$FIX/docs/b.md"
  printf '# Log\n' > "$FIX/CHANGELOG.md"
  validate_fix
  [ "$status" -eq 0 ]
}

@test "broken relative link in docs/ fails" {
  printf '[x](missing.md)\n' > "$FIX/docs/b.md"
  validate_fix
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing.md"* ]]
}

@test "broken link in CHANGELOG.md fails" {
  printf '[x](docs/missing.md)\n' > "$FIX/CHANGELOG.md"
  validate_fix
  [ "$status" -eq 1 ]
  [[ "$output" == *"CHANGELOG.md"* ]]
}

@test "link followed by spaced section citation passes" {
  printf '[x](a.md) §11 rule\n' > "$FIX/docs/b.md"
  validate_fix
  [ "$status" -eq 0 ]
}

@test "link glued to section citation fails" {
  printf '[x](a.md)§4\n' > "$FIX/docs/b.md"
  validate_fix
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed section citation"* ]]
}

@test "tree with no CHANGELOG files passes" {
  [ ! -e "$FIX/CHANGELOG.md" ] && [ ! -e "$FIX/CHANGELOG-ARCHIVE.md" ]
  validate_fix
  [ "$status" -eq 0 ]
}
