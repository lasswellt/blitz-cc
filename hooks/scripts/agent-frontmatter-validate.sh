#!/usr/bin/env bash
# agent-frontmatter-validate.sh — Plugin agent frontmatter lint.
#
# Sibling of skill-frontmatter-validate.sh. Validates agents/*.md against the
# plugin-agent contract. The forbidden-field check enforces a constraint
# documented in .cc-sessions/KNOWLEDGE.md: Claude Code silently strips
# `hooks:`, `mcpServers:`, and `permissionMode:` from plugin agent frontmatter
# (they only work in `~/.claude/agents/`), so leaving them in the file produces
# a silently-broken agent with no warning.
#
# Usage:
#   agent-frontmatter-validate.sh [agent-path...]
#   agent-frontmatter-validate.sh --all   # scan agents/*.md
#
# Exit:
#   0 — all agents conform
#   1 — one or more files violate the contract
#
# Checks:
#   1. YAML frontmatter parses (delimited by ---)
#   2. name: present, ≤64 chars, lowercase + digits + hyphens, no "anthropic"/"claude"
#   3. description: present, non-empty, ≤1024 chars
#   4. model: present, one of opus|sonnet|haiku
#   5. tools: present, non-empty
#   6. maxTurns: present, positive integer
#   7. Forbidden fields absent: hooks, mcpServers, permissionMode (silently stripped)
#   8. Optional fields, if present, match expected shape:
#        background: true|false
#        color: known palette token (cyan|orange|green|red|yellow|magenta|blue|purple)
#        memory: project|none
#   9. Body length ≤500 lines (excluding frontmatter) — same cap as SKILL.md
#  10. Canonical OUTPUT STYLE snippet present verbatim OR `[CANONICAL PREAMBLE]`
#      inheritance marker (templates that inherit from a referenced preamble)

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"
SCRIPT_NAME="$(basename "$0")"
BLITZ_ROOT="${BLITZ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RC=0
SNIPPET_RE='OUTPUT STYLE: (terse-technical|lite|full|ultra) per /_shared/terse-output\.md'
INHERIT_RE='\[CANONICAL PREAMBLE\]'

# Fast-path scope guard for PostToolUse Write|Edit invocations.
# When invoked as `--all` with hook JSON on stdin, exit 0 early unless the
# edited file is an agent .md. Falls through to the existing behavior when
# called from the CLI (no stdin tty) or with explicit file arguments.
if [ "$#" -eq 1 ] && [ "${1:-}" = "--all" ] && [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
  if [ -n "$INPUT" ]; then
    EDITED_FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
    case "$EDITED_FILE" in
      agents/*.md|*/agents/*.md) ;;
      "") ;;
      *) exit 0 ;;
    esac
  fi
fi

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [agent-path...] | --all
  Validates agents/*.md against plugin-agent frontmatter contract.
  Without arguments, validates agents/*.md under \$BLITZ_ROOT (or cwd).
EOF
}

TARGETS=()
if [ "$#" -eq 0 ] || [ "${1:-}" = "--all" ]; then
  while IFS= read -r f; do TARGETS+=("$f"); done < <(find "${BLITZ_ROOT}/agents" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort)
else
  for arg in "$@"; do
    [ "$arg" = "--help" ] && { usage; exit 0; }
    TARGETS+=("$arg")
  done
fi

[ "${#TARGETS[@]}" -eq 0 ] && { echo "[$SCRIPT_NAME] No agent .md files found" >&2; exit 1; }

fail() {
  printf '  ✗ %s: %s\n' "$1" "$2" >&2
  RC=1
}

validate_one() {
  local f="$1"
  local rel="${f#$BLITZ_ROOT/}"
  [ ! -f "$f" ] && { fail "$rel" "file not found"; return; }

  local fm body
  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$f")
  body=$(awk '/^---$/{c++; next} c>=2{print}' "$f")
  [ -z "$fm" ] && { fail "$rel" "missing YAML frontmatter"; return; }

  local name desc model tools maxturns bg color memory
  name=$(printf '%s\n'     "$fm" | awk -F': *' '/^name:/{print $2; exit}'     | tr -d '"')
  desc=$(printf '%s\n'     "$fm" | awk -F': *' '/^description:/{$1=""; sub(/^ */,""); print; exit}' | sed 's/^"\(.*\)"$/\1/')
  model=$(printf '%s\n'    "$fm" | awk -F': *' '/^model:/{print $2; exit}'    | tr -d '"')
  tools=$(printf '%s\n'    "$fm" | awk -F': *' '/^tools:/{$1=""; sub(/^ */,""); print; exit}')
  maxturns=$(printf '%s\n' "$fm" | awk -F': *' '/^maxTurns:/{print $2; exit}' | tr -d '"')
  bg=$(printf '%s\n'       "$fm" | awk -F': *' '/^background:/{print $2; exit}' | tr -d '"')
  color=$(printf '%s\n'    "$fm" | awk -F': *' '/^color:/{print $2; exit}'    | tr -d '"')
  memory=$(printf '%s\n'   "$fm" | awk -F': *' '/^memory:/{print $2; exit}'   | tr -d '"')

  # 2. name
  [ -z "$name" ] && fail "$rel" "frontmatter missing 'name:'"
  [ "${#name}" -gt 64 ] && fail "$rel" "name '$name' exceeds 64 chars"
  echo "$name" | grep -qE '^[a-z0-9-]+$' || fail "$rel" "name '$name' must be lowercase + digits + hyphens"
  case "$name" in *anthropic*|*claude*) fail "$rel" "name contains reserved word 'anthropic' or 'claude'";; esac

  # 3. description
  [ -z "$desc" ] && fail "$rel" "frontmatter missing 'description:'"
  [ "${#desc}" -gt 1024 ] && fail "$rel" "description length ${#desc} exceeds 1024 chars"

  # 4. model
  [ -z "$model" ] && fail "$rel" "frontmatter missing 'model:'"
  case "$model" in opus|sonnet|haiku|"") ;; *) fail "$rel" "model '$model' must be opus|sonnet|haiku";; esac

  # 5. tools
  [ -z "$tools" ] && fail "$rel" "frontmatter missing 'tools:' (comma-separated tool list)"

  # 6. maxTurns
  [ -z "$maxturns" ] && fail "$rel" "frontmatter missing 'maxTurns:'"
  echo "$maxturns" | grep -qE '^[1-9][0-9]*$' || fail "$rel" "maxTurns '$maxturns' must be positive integer"

  # 7. Forbidden fields (silently stripped by Claude Code in plugin agents)
  local forbidden
  for forbidden in hooks mcpServers permissionMode; do
    if printf '%s\n' "$fm" | grep -qE "^${forbidden}:"; then
      fail "$rel" "forbidden field '${forbidden}:' — silently stripped by Claude Code in plugin agents (see .cc-sessions/KNOWLEDGE.md). Move to ~/.claude/agents/ if needed."
    fi
  done

  # 8. Optional shape checks
  if [ -n "$bg" ]; then
    case "$bg" in true|false) ;; *) fail "$rel" "background '$bg' must be true|false";; esac
  fi
  if [ -n "$color" ]; then
    case "$color" in cyan|orange|green|red|yellow|magenta|blue|purple|pink|gray) ;; *) fail "$rel" "color '$color' not in {cyan,orange,green,red,yellow,magenta,blue,purple,pink,gray}";; esac
  fi
  if [ -n "$memory" ]; then
    case "$memory" in project|none) ;; *) fail "$rel" "memory '$memory' must be project|none";; esac
  fi

  # 9. Body length cap (matches skill cap; references/ overflow not yet a pattern for agents)
  local body_lines
  body_lines=$(printf '%s\n' "$body" | wc -l)
  [ "$body_lines" -gt 500 ] && fail "$rel" "body is $body_lines lines (cap 500)"

  # 10. OUTPUT STYLE snippet OR canonical-preamble inheritance marker
  if ! printf '%s\n' "$body" | grep -qE "$SNIPPET_RE"; then
    if ! printf '%s\n' "$body" | grep -qE "$INHERIT_RE"; then
      fail "$rel" "missing canonical OUTPUT STYLE snippet (verbatim from /_shared/terse-output.md) or '[CANONICAL PREAMBLE]' inheritance marker"
    fi
  fi
}

for f in "${TARGETS[@]}"; do validate_one "$f"; done

if [ "$RC" -eq 0 ]; then
  echo "[$SCRIPT_NAME] OK: ${#TARGETS[@]} agent .md files conform"
else
  echo "[$SCRIPT_NAME] FAIL: violations above" >&2
fi
exit "$RC"
