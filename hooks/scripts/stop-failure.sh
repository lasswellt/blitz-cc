#!/usr/bin/env bash
# stop-failure.sh — Log turn-end failures (rate limits, billing, server errors)
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
FAILURE_TYPE=$(blitz_extract failure_type)
[ -z "$FAILURE_TYPE" ] && FAILURE_TYPE=$(blitz_extract reason)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

DETAIL=$(jq -n --arg ft "$FAILURE_TYPE" '{failure_type:$ft}')
blitz_log_event "hook" "stop_failure" "Turn ended with failure: ${FAILURE_TYPE:-unknown}" "$DETAIL"
# Inbox (E-041 S4): a turn that died on the API (rate limit, billing, server error) needs a human
# or a retry decision; billing/auth are non-recoverable for an unattended loop.
blitz_inbox_append "hook_failure" "turn ended with ${FAILURE_TYPE:-unknown}; unattended loops stall until this clears" || true

exit 0
