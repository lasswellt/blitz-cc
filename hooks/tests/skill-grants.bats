#!/usr/bin/env bats
# Rule 12 of hooks/scripts/skill-frontmatter-validate.sh: skills pre-approve
# only scoped grants (no bare Bash/Write/Edit/Monitor/WebSearch/WebFetch, no
# wildcard after a shell, interpreter, package runner or network tool).

load '_helpers'

VALIDATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/hooks/scripts/skill-frontmatter-validate.sh"

setup() {
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/skills/demo"
}
teardown() { rm -rf "$FIX"; }

grants() {
  printf -- '---\nname: demo\ndescription: Does demo work when asked.\nmodel: inherit\ncompatibility: ">=2.1.296"\nallowed-tools: %s\n---\nbody\n' "$1" > "$FIX/skills/demo/SKILL.md"
}

@test "the shipped skills pass the grant rule" {
  run bash "$VALIDATE" --all </dev/null
  [ "$status" -eq 0 ]
}

@test "scoped grants pass" {
  grants 'Read, Glob, Grep, Edit(docs/plans/**), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh *), Bash(git diff *), WebFetch(domain:registry.npmjs.org)'
  BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all </dev/null
  [ "$status" -eq 0 ]
}

@test "bare tools are refused" {
  for t in Bash Write Edit Monitor WebSearch WebFetch; do
    grants "Read, $t, Grep"
    BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"bare '$t'"* ]]
  done
}

@test "wildcards after a shell, interpreter, runner or network tool are refused" {
  for r in 'Bash(*)' 'Bash(bash *)' 'Bash(python3:*)' 'Bash(npx *)' 'Bash(curl *)' 'Bash(node *)'; do
    grants "Read, $r"
    BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"wildcards a shell"* ]]
  done
}
