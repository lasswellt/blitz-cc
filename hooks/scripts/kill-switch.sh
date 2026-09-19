#!/usr/bin/env bash
# kill-switch.sh — PreToolUse guard (matcher: every tool). While .cc-sessions/STOP
# exists, every tool call is refused (exit 2) so an unattended loop halts where it
# stands. Remove the file to resume. The file's first line, if any, is echoed as the
# operator's reason. Logged once per session via a marker file next to STOP.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
STOP="$DIR/STOP"
[ -f "$STOP" ] || exit 0

REASON=$(head -n1 "$STOP" 2>/dev/null | tr -d '\r' | cut -c1-200)
if printf '%s' "$REASON" | grep -qiE "$BLITZ_INJECTION_RX"; then REASON="[quarantined reason]"; fi
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)
MARK="$DIR/.stop-logged-$SID"
if [ ! -f "$MARK" ]; then
  blitz_log_event "hook" "kill_switch" "STOP present; refusing tool calls${REASON:+: $REASON}" '{}'
  : > "$MARK" 2>/dev/null || true
fi
printf 'blitz kill switch: %s exists%s. Remove the file to resume; no tool calls run while it is present.\n' "$STOP" "${REASON:+ ($REASON)}" >&2
exit 2
