#!/usr/bin/env bash
# teammate-idle.sh — Handle TeammateIdle hook event
# Exit code 2 sends feedback to the teammate and keeps them working
# Exit code 0 allows the teammate to go idle
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat)
AGENT_ID=$(blitz_extract agent_id)
AGENT_TYPE=$(blitz_extract agent_type)

ROOT=$(blitz_find_root || true)
if [ -n "$ROOT" ] && [ -n "$AGENT_ID" ]; then
  SESSIONS_DIR="$ROOT/.cc-sessions"
  SESSION_ID="$AGENT_ID"
  DETAIL=$(jq -n --arg t "$AGENT_TYPE" '{agent_type:$t}')
  blitz_log_event "hook" "teammate_idle" "Agent $AGENT_ID ($AGENT_TYPE) went idle" "$DETAIL"
fi

# Opt-in off-screen alert (the article's "audio signal via hooks" pattern).
# A hook cannot invoke the PushNotification tool (that is agent-side), so this
# emits a terminal bell when BLITZ_NOTIFY_ON_IDLE=1 — useful when monitoring
# several sessions via `claude agents` and you want an idle nudge. Default off
# to avoid notification fatigue. Never blocks; always exits 0.
if [ "${BLITZ_NOTIFY_ON_IDLE:-0}" = "1" ]; then
  printf '\a' >&2 2>/dev/null || true
fi

exit 0
