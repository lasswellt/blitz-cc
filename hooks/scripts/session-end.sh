#!/usr/bin/env bash
# session-end.sh — Close the session record on SessionEnd (E-040 S2)
#
# Input: {session_id, reason: clear|resume|logout|prompt_input_exit|other, ...}
# Effects (all best-effort, always exit 0):
#   1. Session record (.cc-sessions/sessions/<sid>.json, or a legacy
#      .cc-sessions/<x>.json whose .claude_session_id == sid): status mapped from
#      reason (prompt_input_exit|other -> completed, resume -> suspended,
#      clear -> cleared, logout -> logged_out), `ended` set to now.
#   2. Every *.lock under .cc-sessions/ whose body names this session_id is
#      removed — ownership-guarded (grep -q "$SID"), never a foreign lock
#      (sessions.md §2).
#   3. Feed event `session_end` (logged even when no record exists).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
REASON=$(blitz_extract reason)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)
[ -z "$REASON" ] && REASON="other"

case "$REASON" in
  prompt_input_exit|other) STATUS="completed" ;;
  resume)                  STATUS="suspended" ;;
  clear)                   STATUS="cleared" ;;
  logout)                  STATUS="logged_out" ;;
  *)                       STATUS="completed" ;;
esac

RECORD=$(blitz_session_record_find "$SESSION_ID" 2>/dev/null || true)
RELEASED=0
if [ -n "$RECORD" ]; then
  blitz_session_update "$SESSION_ID" \
    ".status = $(jq -n --arg s "$STATUS" '$s') | .state = \"ended\" | .ended = \$now | .last_activity = \$now"

  # Release owned locks only (ownership guard: the lock body must name this sid).
  while IFS= read -r lock; do
    [ -f "$lock" ] || continue
    if grep -qF -- "$SESSION_ID" "$lock" 2>/dev/null; then
      rm -f "$lock" 2>/dev/null && RELEASED=$((RELEASED + 1))
    fi
  done < <(find "$SESSIONS_DIR" -type f -name '*.lock' 2>/dev/null || true)
fi

DETAIL=$(jq -nc --arg reason "$REASON" --arg status "$STATUS" \
  --argjson released "$RELEASED" --argjson had_record "$([ -n "$RECORD" ] && echo true || echo false)" \
  '{reason:$reason,status:$status,locks_released:$released,record:$had_record}')
blitz_log_event "hook" "session_end" "Session ended (${REASON} -> ${STATUS})" "$DETAIL"

exit 0
