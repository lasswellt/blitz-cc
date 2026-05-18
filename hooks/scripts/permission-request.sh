#!/usr/bin/env bash
# permission-request.sh — Log permission-prompt opportunities
# Fires when a permission dialog is about to be shown. Non-blocking: always exits 0.
#
# Stub: logs only. Does NOT emit a permissionDecision JSON, so the user is
# still prompted normally.
#
# This hook is intentionally async:true in hooks.json because async hooks cannot
# return permissionDecision values (Claude Code ignores the response). A
# synchronous hook that tries to auto-approve patterns based on grep-alone can
# be fooled by compound commands (e.g. `git status && rm -rf dist`). If selective
# auto-approval is added in the future, implement it as a separate synchronous
# hook with an explicit safelist and test coverage — not by re-enabling code in
# this file.

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
blitz_log_event "hook" "permission_request" "Permission requested for ${TOOL_NAME:-?}" "$DETAIL"

exit 0
