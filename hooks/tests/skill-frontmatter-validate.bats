#!/usr/bin/env bats
# Tests for hooks/scripts/skill-frontmatter-validate.sh rule 13: no positional
# $N in a SKILL.md body (Claude Code substitutes arguments there). $ARGUMENTS
# stays allowed: skills rely on its substitution in prose.
# Requires: bats-core

load '_helpers'

VALIDATE="$HOOKS_DIR/skill-frontmatter-validate.sh"
FM=$'name: good\ndescription: Fixture skill for the validator suite.\nmodel: inherit\nallowed-tools: Read, Grep\ncompatibility: ">=2.1.271"'

setup()    { FIX="$(mktemp -d)"; mkdir -p "$FIX/skills/good"; }
teardown() { rm -rf "$FIX"; }

# skill <frontmatter> <body>: write $FIX/skills/good/SKILL.md.
skill() { printf -- '---\n%s\n---\n\n%s\n' "$1" "$2" > "$FIX/skills/good/SKILL.md"; }

validate_fix() { BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all </dev/null; }

# bad <body>: expect exit 1 naming file line 11 (7 frontmatter lines, blank, "Run:", blank, then the hit).
bad() {
  skill "$FM" "$1"
  validate_fix
  [ "$status" -eq 1 ] || { echo "exit $status: $output"; return 1; }
  [[ "$output" == *"SKILL.md:11: positional"* ]] || { echo "$output"; return 1; }
}

@test "a clean fixture skill passes" {
  skill "$FM" "Plain body."
  validate_fix
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: 1 SKILL.md files conform"* ]]
}

@test "awk print \$2 in the body fails naming the line" {
  bad "$(printf 'Run:\n\n    awk '"'"'{print $2}'"'"' f')"
}

@test "a price like \$0.10 in the body fails" {
  bad "$(printf 'Run:\n\ncosts $0.10 each')"
}

@test "\$ARGUMENTS in the body passes (deliberate prose substitution)" {
  skill "$FM" "$(printf 'Run:\n\nUse $ARGUMENTS here')"
  validate_fix
  [ "$status" -eq 0 ] || { echo "exit $status: $output"; return 1; }
}

@test "\$1 in the frontmatter only passes" {
  skill "$FM"$'\nargument-hint: "$1 name"' "Plain body."
  validate_fix
  [ "$status" -eq 0 ]
}

@test "\${VAR} and \$VAR pass" {
  skill "$FM" 'Use ${HOME} and $HOME and ${CLAUDE_PLUGIN_ROOT}.'
  validate_fix
  [ "$status" -eq 0 ]
}
