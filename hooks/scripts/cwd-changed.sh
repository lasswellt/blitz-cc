#!/usr/bin/env bash
# cwd-changed.sh — Track working-directory changes on the session record (E-040 S2)
#
# One script, two events (dispatched on hook_event_name):
#   CwdChanged     {new_cwd|cwd}        -> record.cwd
#   DirectoryAdded {path, method}       -> record.dirs[] (unique)
# Non-blocking, exit 0; no-op when no record exists. Always logs a feed event.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)
EVENT=$(blitz_extract hook_event_name)

case "$EVENT" in
  DirectoryAdded)
    DIR_PATH=$(blitz_extract path)
    METHOD=$(blitz_extract method)
    if [ -n "$DIR_PATH" ]; then
      blitz_session_update "$SESSION_ID" \
        ".dirs = ((.dirs // []) + [$(jq -n --arg p "$DIR_PATH" '$p')] | unique) | .last_activity = \$now"
    fi
    blitz_log_event "hook" "directory_added" "Directory added: ${DIR_PATH:-?}" \
      "$(jq -nc --arg p "$DIR_PATH" --arg m "$METHOD" '{path:$p,method:$m}')"
    ;;
  *)
    NEW_CWD=$(blitz_extract new_cwd)
    [ -z "$NEW_CWD" ] && NEW_CWD=$(blitz_extract cwd)
    if [ -n "$NEW_CWD" ]; then
      blitz_session_update "$SESSION_ID" \
        ".cwd = $(jq -n --arg c "$NEW_CWD" '$c') | .last_activity = \$now"
    fi
    blitz_log_event "hook" "cwd_changed" "cwd -> ${NEW_CWD:-?}" \
      "$(jq -nc --arg c "$NEW_CWD" '{cwd:$c}')"
    ;;
esac

exit 0
