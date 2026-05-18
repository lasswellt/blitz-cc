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

exit 0
