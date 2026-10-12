#!/usr/bin/env bash
# tasks-guard.sh: PreToolUse guard for the plan files the main thread owns
# (loop.md §Structural rules; the take-home "Default-FAIL" pattern).
#
#   docs/plans/<slug>/tasks.json   written only by scripts/tasks.sh, from any context
#   docs/plans/<slug>/progress.md  the main thread's ledger: a subagent never writes it
#
# Matchers: Write|Edit|NotebookEdit (file_path) and Bash|PowerShell (command).
# Blocks (exit 2) when:
#   - a Write/Edit targets .../docs/plans/<slug>/tasks.json
#   - a shell command redirects into, edits in place, or replaces such a file
#     without going through scripts/tasks.sh
#   - stdin carries a non-empty `agent_type` (subagent context) and the call writes
#     .../docs/plans/<slug>/progress.md by either route; the main conversation
#     (no agent_type on stdin) keeps editing progress.md
# BLITZ_TASKS_GUARD_OFF=1 disables the guard (migration or repair by the operator).
# Containment: environment-layer guard (TB-2 for tasks.json, TB-3 for progress.md).
# Canonical posture: /_shared/security.md.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
[ "${BLITZ_TASKS_GUARD_OFF:-0}" = "1" ] && exit 0
blitz_guard_input tasks-guard

TASKS_RX='(^|[/ "=])docs/plans/[^/]+/tasks\.json'
PROGRESS_RX='(^|[/ "=])docs/plans/[^/]+/progress\.md'
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
# agent_type is set by the harness in subagent context; capped because it is echoed.
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null | cut -c1-80 || true)

# shell_writes <command> <file-regex>: the command redirects into, edits in place,
# replaces, tees into, or opens for writing a file matching <file-regex>.
shell_writes() {
  local cmd="$1" f="$2"
  printf '%s' "$cmd" | grep -qE '>[>|]?[[:space:]]*"?[^ "|;&]*docs/plans/[^/]+/'"$f" \
    || printf '%s' "$cmd" | grep -qE 'sed[[:space:]]+(-[a-zA-Z]*i|--in-place)[^|;&]*'"$f" \
    || printf '%s' "$cmd" | grep -qE '\btee\b[^|;&]*'"$f" \
    || printf '%s' "$cmd" | grep -qE '\b(mv|cp|rm|truncate|sponge)\b[^|;&]*'"$f" \
    || printf '%s' "$cmd" | grep -qE 'open\([^)]*'"$f"'[^)]*["'"'"']w'
}

block() {  # block <what>: tasks.json written other than through scripts/tasks.sh
  blitz_log_event "hook" "tasks_guard_block" "$1" "$(jq -nc --arg t "$TOOL" '{tool:$t,file:"tasks.json"}')"
  printf 'BLOCKED: %s\n  tasks.json is written only by scripts/tasks.sh (add | set | verify). Direct edits would let a task be marked done without its verify[] running.\n' "$1" >&2
  exit 2
}

block_progress() {  # block_progress <what>: progress.md written from subagent context
  blitz_log_event "hook" "tasks_guard_block" "$1" "$(jq -nc --arg t "$TOOL" --arg a "$AGENT_TYPE" '{tool:$t,file:"progress.md",agent_type:$a}')"
  printf 'BLOCKED: %s\n  docs/plans/<slug>/progress.md is the main thread'"'"'s ledger (loop.md §Structural rules). A subagent (%s) reports its outcome in its reply; the orchestrator records it at the task boundary.\n' "$1" "$AGENT_TYPE" >&2
  exit 2
}

# progress.md, subagent context only. Checked first so a command that pairs a
# legitimate scripts/tasks.sh call with a ledger write is still refused.
if [ -n "$AGENT_TYPE" ]; then
  if [ -n "$FILE_PATH" ] && printf '%s' "$FILE_PATH" | grep -qE "$PROGRESS_RX"; then
    block_progress "subagent $TOOL to $FILE_PATH"
  fi
  if [ -n "$COMMAND" ] && printf '%s' "$COMMAND" | grep -qE "$PROGRESS_RX" && shell_writes "$COMMAND" 'progress\.md'; then
    block_progress "subagent shell write to progress.md: $(printf '%s' "$COMMAND" | cut -c1-120)"
  fi
fi

if [ -n "$FILE_PATH" ] && printf '%s' "$FILE_PATH" | grep -qE "$TASKS_RX"; then
  block "direct $TOOL to $FILE_PATH"
fi

if [ -n "$COMMAND" ] && printf '%s' "$COMMAND" | grep -qE "$TASKS_RX"; then
  # Allowed: reads and the canonical writer.
  if printf '%s' "$COMMAND" | grep -qE 'scripts/tasks\.sh'; then exit 0; fi
  if shell_writes "$COMMAND" 'tasks\.json'; then
    block "shell write to tasks.json: $(printf '%s' "$COMMAND" | cut -c1-120)"
  fi
fi
exit 0
