#!/usr/bin/env bash
# tasks-guard.sh — PreToolUse guard: docs/plans/<slug>/tasks.json is written only by
# scripts/tasks.sh (loop.md §Structural rules; the take-home "Default-FAIL" pattern).
#
# Matchers: Write|Edit|NotebookEdit (file_path) and Bash|PowerShell (command).
# Blocks (exit 2) when:
#   - a Write/Edit targets .../docs/plans/<slug>/tasks.json
#   - a shell command redirects into, edits in place, or replaces such a file
#     without going through scripts/tasks.sh
# BLITZ_TASKS_GUARD_OFF=1 disables the guard (migration or repair by the operator).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
[ "${BLITZ_TASKS_GUARD_OFF:-0}" = "1" ] && exit 0

TASKS_RX='(^|[/ "=])docs/plans/[^/]+/tasks\.json'
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

block() {
  blitz_log_event "hook" "tasks_guard_block" "$1" "$(jq -nc --arg t "$TOOL" '{tool:$t}')"
  printf 'BLOCKED: %s\n  tasks.json is written only by scripts/tasks.sh (add | set | verify). Direct edits would let a task be marked done without its verify[] running.\n' "$1" >&2
  exit 2
}

if [ -n "$FILE_PATH" ] && printf '%s' "$FILE_PATH" | grep -qE "$TASKS_RX"; then
  block "direct $TOOL to $FILE_PATH"
fi

if [ -n "$COMMAND" ] && printf '%s' "$COMMAND" | grep -qE "$TASKS_RX"; then
  # Allowed: reads and the canonical writer.
  if printf '%s' "$COMMAND" | grep -qE 'scripts/tasks\.sh'; then exit 0; fi
  if printf '%s' "$COMMAND" | grep -qE '>[>|]?[[:space:]]*"?[^ "|;&]*docs/plans/[^/]+/tasks\.json' \
     || printf '%s' "$COMMAND" | grep -qE 'sed[[:space:]]+(-[a-zA-Z]*i|--in-place)[^|;&]*tasks\.json' \
     || printf '%s' "$COMMAND" | grep -qE '\btee\b[^|;&]*tasks\.json' \
     || printf '%s' "$COMMAND" | grep -qE '\b(mv|cp|rm|truncate|sponge)\b[^|;&]*tasks\.json' \
     || printf '%s' "$COMMAND" | grep -qE 'open\([^)]*tasks\.json[^)]*["'"'"']w'; then
    block "shell write to tasks.json: $(printf '%s' "$COMMAND" | cut -c1-120)"
  fi
fi
exit 0
