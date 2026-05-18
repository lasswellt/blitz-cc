#!/usr/bin/env bash
# post-edit-activity-log.sh — Append file change events to the activity feed
# Fires after every Write|Edit tool use to maintain cross-instance awareness
# Non-blocking: always exits 0

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat)
FILE_PATH=$(blitz_extract file_path)

[ -z "$FILE_PATH" ] && exit 0

ROOT=$(blitz_find_root "$(dirname "$FILE_PATH" 2>/dev/null || echo ".")" || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
HOOK_AGENT=$(blitz_extract agent_id)
[ -z "$SESSION_ID" ] && SESSION_ID="${HOOK_AGENT:-$(blitz_session_id)}"

REL_PATH="${FILE_PATH#$ROOT/}"
HOOK_AGENT_TYPE=$(blitz_extract agent_type)

DETAIL=$(jq -n --arg f "$REL_PATH" --arg t "${HOOK_AGENT_TYPE:-}" \
  'if $t != "" then {files: [$f], agent_type: $t} else {files: [$f]} end')
blitz_log_event "freeform" "file_change" "Edited $REL_PATH" "$DETAIL"

exit 0
