#!/usr/bin/env bash
# post-tool-failure.sh — Log failed tool execution
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
TOOL_NAME=$(blitz_extract tool_name)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

DETAIL=$(jq -n --arg tn "$TOOL_NAME" '{tool_name:$tn}')
blitz_log_event "hook" "post_tool_failure" "Tool ${TOOL_NAME:-?} failed" "$DETAIL"
# Inbox (E-041 S4): only hook-shaped failures are attention items; ordinary tool errors
# (a failing grep, a non-zero test run) are the model's to handle in-turn.
case "${TOOL_NAME:-}" in
  Agent|Workflow|Monitor|SendMessage) blitz_inbox_append "hook_failure" "tool ${TOOL_NAME} failed: $(printf '%s' "$INPUT" | jq -r '.error // .message // "no detail"' 2>/dev/null | cut -c1-160)" || true ;;
esac

exit 0
