#!/usr/bin/env bash
# notification-log.sh — Route Notification events to the inbox (E-040 S2)
#
# Input: {notification_type|type, message, title, ...}. Non-blocking, exit 0.
#   permission*                   -> inbox kind "permission", feed `needs_input`
#   *input* | idle_prompt | elicit -> inbox kind "needs_input", feed `needs_input`
#   anything else                 -> feed `notification` only
# Inbox text is sanitized (<=200 chars + BLITZ_INJECTION_RX) by blitz_inbox_append.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

NKIND=$(blitz_extract notification_type)
[ -z "$NKIND" ] && NKIND=$(blitz_extract type)
MESSAGE=$(blitz_extract message)
[ -z "$MESSAGE" ] && MESSAGE=$(blitz_extract title)

KIND=""
case "$(printf '%s' "$NKIND" | tr '[:upper:]' '[:lower:]')" in
  *permission*)               KIND="permission" ;;
  *input*|*idle*|*elicit*)    KIND="needs_input" ;;
esac

SAFE_MSG=$(printf '%s' "$MESSAGE" | tr -d '\r' | tr '\n' ' ' | cut -c1-200)
DETAIL=$(jq -nc --arg t "$NKIND" --arg k "$KIND" '{notification_type:$t,kind:$k}')
if [ -n "$KIND" ]; then
  blitz_inbox_append "$KIND" "${SAFE_MSG:-$NKIND}" "$SESSION_ID"
  blitz_log_event "hook" "needs_input" "Waiting on user (${NKIND:-notification})" "$DETAIL"
else
  blitz_log_event "hook" "notification" "Notification (${NKIND:-unknown})" "$DETAIL"
fi

exit 0
