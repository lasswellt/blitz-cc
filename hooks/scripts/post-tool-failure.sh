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

exit 0
