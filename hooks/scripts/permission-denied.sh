#!/usr/bin/env bash
# permission-denied.sh — Log PermissionDenied events (E-040 S2)
#
# Containment posture (security.md TB-3): this hook NEVER emits
# hookSpecificOutput.retry — a denied tool call stays denied. It prints nothing.
# Effects: feed event `permission_denied` {tool_name} + inbox item kind "permission".
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
TOOL_NAME=$(blitz_extract tool_name)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

DETAIL=$(jq -nc --arg tn "$TOOL_NAME" '{tool_name:$tn}')
blitz_log_event "hook" "permission_denied" "Permission denied for ${TOOL_NAME:-?}" "$DETAIL"
blitz_inbox_append "permission" "Permission denied for ${TOOL_NAME:-unknown tool}" "$SESSION_ID"

exit 0
