#!/usr/bin/env bash
# subagent-stop.sh — Log subagent completion to activity feed
# Fires when a subagent finishes. Non-blocking: always exits 0.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
AGENT_ID=$(blitz_extract agent_id)
AGENT_TYPE=$(blitz_extract agent_type)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

DETAIL=$(jq -n --arg id "$AGENT_ID" --arg t "$AGENT_TYPE" '{agent_id:$id,agent_type:$t}')
blitz_log_event "hook" "subagent_stop" "Subagent ${AGENT_TYPE:-?} stopped" "$DETAIL"

exit 0
