#!/usr/bin/env bats
# Tests for hooks/scripts/agent-frontmatter-validate.sh (plugin-agent frontmatter lint)
# Runs as PostToolUse Write|Edit `--all` (async, scope-guarded by the edited path)
# and by explicit path from CI and scripts/ci-local.sh. Required fields: name,
# description, model (opus|sonnet|haiku), tools, maxTurns. Forbidden fields:
# hooks, mcpServers, permissionMode (Claude Code strips them from plugin agents).
# Optional fields must match their documented shape. Exit 0 conform, 1 violations.
# Requires: bats-core

load '_helpers'

VALIDATE="$HOOKS_DIR/agent-frontmatter-validate.sh"
REQUIRED=$'name: good\ndescription: Fixture agent for the validator suite.\nmodel: sonnet\ntools: Read, Grep\nmaxTurns: 10'

setup()    { FIX="$(mktemp -d)"; mkdir -p "$FIX/agents"; }
teardown() { rm -rf "$FIX"; }

# agent <name> <frontmatter block>: write $FIX/agents/<name>.md with that frontmatter.
agent() { printf -- '---\n%s\n---\n\nBody.\n' "$2" > "$FIX/agents/$1.md"; }

# good_plus <extra lines>: the required fields plus extra frontmatter lines.
good_plus() { agent good "$REQUIRED"$'\n'"$1"; }

# without <field>: the required fields minus one.
without() { printf '%s\n' "$REQUIRED" | grep -v "^$1:"; }

# with_value <field> <value>: the required fields with one value replaced.
with_value() { printf '%s\n' "$REQUIRED" | sed "s/^$1: .*/$1: $2/"; }

# validate_fix [args]: run the validator against $FIX with no stdin.
validate_fix() { BLITZ_ROOT="$FIX" run bash "$VALIDATE" "$@" </dev/null; }

# check_bad <frontmatter line(s)> <expected message fragment>
check_bad() {
  good_plus "$1"
  validate_fix --all
  [ "$status" -eq 1 ] || { echo "$1: exit $status"; return 1; }
  [[ "$output" == *"$2"* ]] || { echo "$1: $output"; return 1; }
}

@test "the shipped agents pass with --all" {
  run bash "$VALIDATE" --all </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"*"agent .md files conform"* ]]
}

@test "the shipped agents pass by explicit path (the CI invocation form)" {
  run bash "$VALIDATE" "$HOOKS_DIR"/../../agents/*.md </dev/null
  [ "$status" -eq 0 ]
}

@test "a fixture with every required field passes" {
  agent good "$REQUIRED"
  validate_fix --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: 1 agent .md files conform"* ]]
}

@test "each missing required field is named" {
  local field
  for field in name description model tools maxTurns; do
    agent good "$(without "$field")"
    validate_fix --all
    [ "$status" -eq 1 ] || { echo "$field: exit $status"; return 1; }
    [[ "$output" == *"agents/good.md: frontmatter missing '$field:'"* ]] || { echo "$field: $output"; return 1; }
  done
}

@test "model must be opus, sonnet or haiku" {
  agent good "$(with_value model inherit)"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"model 'inherit' must be opus|sonnet|haiku"* ]]
  local m
  for m in opus sonnet haiku; do
    agent good "$(with_value model "$m")"
    validate_fix --all
    [ "$status" -eq 0 ] || { echo "$m: $output"; return 1; }
  done
}

@test "maxTurns must be a positive integer" {
  local v
  for v in 0 ten 1.5 -3; do
    agent good "$(with_value maxTurns "$v")"
    validate_fix --all
    [ "$status" -eq 1 ] || { echo "$v: exit $status"; return 1; }
    [[ "$output" == *"maxTurns '$v' must be positive integer"* ]] || { echo "$v: $output"; return 1; }
  done
}

@test "name must be lowercase with digits and hyphens, free of reserved words, at most 64 chars" {
  agent good "$(with_value name Dev_Agent)"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"name 'Dev_Agent' must be lowercase + digits + hyphens"* ]]
  agent good "$(with_value name claude-helper)"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"reserved word 'anthropic' or 'claude'"* ]]
  local long; long=$(head -c 65 /dev/zero | tr '\0' 'a')
  agent good "$(with_value name "$long")"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds 64 chars"* ]]
}

@test "description over 1024 chars fails" {
  local long; long=$(head -c 1030 /dev/zero | tr '\0' 'd')
  agent good "$(with_value description "$long")"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"description length 1030 exceeds 1024 chars"* ]]
}

@test "effort accepts low|medium|high|xhigh|max and nothing else" {
  check_bad 'effort: turbo' "effort 'turbo' must be low|medium|high|xhigh|max"
  local e
  for e in low medium high xhigh max; do
    good_plus "effort: $e"
    validate_fix --all
    [ "$status" -eq 0 ] || { echo "$e: $output"; return 1; }
  done
}

@test "autoCompactWindow must be a positive integer token count" {
  local v
  for v in 0 abc 50k -12 1.5; do
    check_bad "autoCompactWindow: $v" "autoCompactWindow '$v' must be a positive integer"
  done
  good_plus 'autoCompactWindow: 150000'
  validate_fix --all
  [ "$status" -eq 0 ]
}

@test "forbidden fields are reported as silently stripped, with the pointer to agents.md" {
  local f
  for f in hooks mcpServers permissionMode; do
    check_bad "$f: something" "forbidden field '$f:'"
    [[ "$output" == *"silently stripped by Claude Code in plugin agents"*"skills/_shared/agents.md"* ]] || { echo "$f: $output"; return 1; }
  done
}

@test "other optional fields are shape-checked" {
  check_bad 'background: yes' "background 'yes' must be true|false"
  check_bad 'color: teal' "color 'teal' not in {cyan,orange,green,red,yellow,magenta,blue,purple,pink,gray}"
  check_bad 'memory: global' "memory 'global' must be user|project|local|none"
  check_bad 'isolation: container' "isolation 'container' must be worktree"
  check_bad 'omitClaudeMd: 1' "omitClaudeMd '1' must be true|false"
  check_bad $'experimental:\n  cacheTtl: 2h' "experimental.cacheTtl '2h' must be 5m|1h"
}

@test "the optional fields the shipped agents use pass together" {
  good_plus $'effort: high\nmemory: project\nomitClaudeMd: true\nbackground: true\ncolor: cyan\nisolation: worktree\nautoCompactWindow: 120000\nexperimental:\n  cacheTtl: 1h'
  validate_fix --all
  [ "$status" -eq 0 ]
}

@test "tools listing a tool the platform removes from subagents fails" {
  local t
  for t in TodoWrite TaskCreate AskUserQuestion EnterPlanMode; do
    agent good "$(with_value tools "Read, $t, Grep")"
    validate_fix --all
    [ "$status" -eq 1 ] || { echo "$t: exit $status"; return 1; }
    [[ "$output" == *"tools lists '$t'"* ]] || { echo "$t: $output"; return 1; }
  done
}

@test "a body over 500 lines fails" {
  agent good "$REQUIRED"
  yes 'line' | head -n 501 >> "$FIX/agents/good.md"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"lines (cap 500)"* ]]
}

@test "a file without frontmatter fails" {
  printf 'Just a body.\n' > "$FIX/agents/good.md"
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing YAML frontmatter"* ]]
}

@test "quoted scalar values are accepted" {
  agent good $'name: "good"\ndescription: "Fixture agent."\nmodel: "sonnet"\ntools: Read\nmaxTurns: "10"'
  validate_fix --all
  [ "$status" -eq 0 ]
}

@test "hook form: --all with a non-agent file_path on stdin exits 0 without validating" {
  agent broken 'name: broken'
  BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all <<< '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook form: an agents/*.md file_path on stdin runs the full validation" {
  agent broken 'name: broken'
  BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all <<< '{"tool_name":"Edit","tool_input":{"file_path":"agents/broken.md"}}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"agents/broken.md:"* ]]
  BLITZ_ROOT="$FIX" run bash "$VALIDATE" --all <<< "{\"tool_input\":{\"file_path\":\"$FIX/agents/broken.md\"}}"
  [ "$status" -eq 1 ]
}

@test "explicit paths are validated as given" {
  agent broken 'name: broken'
  agent good "$REQUIRED"
  run bash "$VALIDATE" "$FIX/agents/good.md" </dev/null
  [ "$status" -eq 0 ]
  run bash "$VALIDATE" "$FIX/agents/broken.md" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: violations above"* ]]
}

@test "no agent files under BLITZ_ROOT: exit 1 with a message" {
  validate_fix --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"No agent .md files found"* ]]
}

@test "--help prints usage and exits 0" {
  run bash "$VALIDATE" --help </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
