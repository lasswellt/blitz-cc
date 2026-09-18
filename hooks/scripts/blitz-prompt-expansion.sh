#!/usr/bin/env bash
# UserPromptExpansion hook — injects activity-feed context into every blitz:* invocation.
# Fires when a /blitz:<skill> slash command expands. Reads last 5 activity-feed lines
# and appends them as context so skills have instant awareness of prior session state
# without requiring Claude to read CLAUDE.md manually.
#
# Hook input (stdin): JSON with command_name, command_args
# Hook output (stdout): JSON with additionalContext field

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
[ -n "$INPUT" ] || INPUT="{}"
THIS_SID=$(blitz_extract session_id)
[ -n "$THIS_SID" ] || THIS_SID="${CLAUDE_SESSION_ID:-}"

SESSIONS_ROOT=".cc-sessions"
ACTIVITY_FEED="$SESSIONS_ROOT/activity-feed.jsonl"

# Read recent activity (last 5 substantive events, skip session_start noise)
RECENT_ACTIVITY=""
if [ -f "$ACTIVITY_FEED" ]; then
  RECENT_ACTIVITY=$(tail -20 "$ACTIVITY_FEED" 2>/dev/null \
    | grep -v '"event":"session_start"' \
    | tail -5 \
    | jq -r '"\(.ts | split("T")[1] | split(".")[0]) [\(.session | split("-")[0:2] | join("-"))] \(.skill)/\(.event): \(.message)"' 2>/dev/null \
    | head -5 \
    || echo "")
fi

# --- Peer sessions (E-041 S2): one line per OTHER active hook-owned record ---
# Every field is untrusted repo-local data (TB-1): ≤200 chars + BLITZ_INJECTION_RX.
sanitize_line() {
  local s; s=$(tr -d '\r' | tr '\n' ' ' | cut -c1-200)
  if printf '%s' "$s" | grep -qiE "$BLITZ_INJECTION_RX"; then
    printf '[quarantined: suspicious field — see startup-validate.sh]'
  else
    printf '%s' "$s"
  fi
}
PEERS=""
NOW=$(date +%s)
PEER_COUNT=0
for rec in "$SESSIONS_ROOT"/sessions/*.json; do
  [ -f "$rec" ] || continue
  [ "$PEER_COUNT" -lt 5 ] || break
  row=$(jq -r 'select(.status=="active") | [(.session_id // ""), (.skill // "-"), (.working_on // "-"), (.state // "-"), (.last_activity // .started // "")] | @tsv' "$rec" 2>/dev/null || true)
  [ -n "$row" ] || continue
  IFS=$'\t' read -r sid skill working state last <<< "$row"
  [ -n "$sid" ] || continue
  [ "$sid" = "$THIS_SID" ] && continue
  age="?"
  if last_e=$(blitz_iso_epoch "$last" 2>/dev/null); then age=$(( (NOW - last_e) / 60 )); fi
  line=$(printf '[blitz] peer %s %s: %s (%s, %sm)' "${sid:0:8}" "$skill" "$working" "$state" "$age" | sanitize_line)
  PEERS="${PEERS}${line}"$'\n'
  PEER_COUNT=$((PEER_COUNT + 1))
done

# --- Inbox pending count (E-041 S4) ---
INBOX_LINE=""
if [ -s "$SESSIONS_ROOT/inbox.jsonl" ]; then
  PENDING=$(jq -r 'select(.status=="pending") | 1' "$SESSIONS_ROOT/inbox.jsonl" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  [ "${PENDING:-0}" -gt 0 ] && INBOX_LINE="[blitz] inbox: ${PENDING} pending"
fi

if [ -z "$RECENT_ACTIVITY" ] && [ -z "$PEERS" ] && [ -z "$INBOX_LINE" ]; then
  # No context available — pass through without modification
  exit 0
fi

# Build additionalContext injection — use jq for safe JSON encoding
# (the prior sed/tr/sed sequence mangled backslashes from escaped quotes).
CONTEXT=""
[ -n "$RECENT_ACTIVITY" ] && CONTEXT=$(printf 'Recent blitz activity:\n%s' "$RECENT_ACTIVITY")
[ -n "$PEERS" ] && CONTEXT=$(printf '%s\n%s' "$CONTEXT" "${PEERS%$'\n'}")
[ -n "$INBOX_LINE" ] && CONTEXT=$(printf '%s\n%s' "$CONTEXT" "$INBOX_LINE")
CONTEXT="${CONTEXT#$'\n'}"

jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "UserPromptExpansion", additionalContext: $ctx}}'

exit 0
