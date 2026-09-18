#!/usr/bin/env bash
# stop-turn.sh — Non-blocking turn-end hook (Stop event, E-040 S2)
#
# Never blocks (no decision JSON, always exit 0). The blocking verification
# gate is a separate script (stop-gate.sh, E-042) so this one stays a pure
# heartbeat + mailbox drain:
#   1. Session record: state:"idle", last_activity now (no-op when absent).
#   2. Mailbox drain: .cc-sessions/mailbox/<session_id>.jsonl, one JSON message
#      per line, is delivered to the Claude Code messaging socket
#      ($CLAUDE_CODE_MESSAGING_SOCKET, CC >=2.1.224) via blitz_inbox_post.
#      On the first failed delivery the undelivered tail is kept (never lost,
#      never duplicated); on full delivery the mailbox is truncated and a feed
#      event `mailbox` records the count.
# Does NOT read or store last_assistant_message (containment: TB-1).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

blitz_session_update "$SESSION_ID" '.state = "idle" | .last_activity = $now'

MAILBOX="$SESSIONS_DIR/mailbox/$SESSION_ID.jsonl"
if _blitz_safe_id "$SESSION_ID" && [ -s "$MAILBOX" ]; then
  TOTAL=0; SENT=0; FAILED=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    TOTAL=$((TOTAL + 1))
    if [ "$FAILED" -eq 0 ] && blitz_inbox_post "$line"; then
      SENT=$((SENT + 1))
    else
      FAILED=1
      printf '%s\n' "$line" >> "$MAILBOX.undelivered"
    fi
  done < "$MAILBOX"
  if [ "$FAILED" -eq 0 ]; then
    : > "$MAILBOX"
    rm -f "$MAILBOX.undelivered" 2>/dev/null || true
    [ "$SENT" -gt 0 ] && blitz_log_event "hook" "mailbox" "Delivered ${SENT} mailbox message(s)" \
      "$(jq -nc --argjson n "$SENT" '{count:$n}')"
  elif [ "$SENT" -gt 0 ] && [ -f "$MAILBOX.undelivered" ]; then
    # partial delivery: keep only the undelivered tail
    mv -f "$MAILBOX.undelivered" "$MAILBOX" 2>/dev/null || true
  else
    rm -f "$MAILBOX.undelivered" 2>/dev/null || true   # nothing delivered: mailbox untouched
  fi
fi

exit 0
