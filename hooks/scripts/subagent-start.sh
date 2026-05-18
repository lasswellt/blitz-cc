#!/usr/bin/env bash
# subagent-start.sh — Log subagent spawn to activity feed
# Fires when a subagent (Agent tool) starts. Non-blocking: always exits 0.
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
blitz_log_event "hook" "subagent_start" "Subagent ${AGENT_TYPE:-?} started" "$DETAIL"

exit 0
