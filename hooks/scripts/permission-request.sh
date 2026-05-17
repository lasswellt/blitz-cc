#!/usr/bin/env bash
# permission-request.sh — Log permission-prompt opportunities
# Fires when a permission dialog is about to be shown. Non-blocking: always exits 0.
#
# Stub: logs only. Does NOT emit a permissionDecision JSON, so the user is
# still prompted normally. Future behavior could auto-approve safe patterns
# (e.g. read-only Bash like `git status`, `ls`, `pwd`) by emitting:
#   {"hookSpecificOutput":{"hookEventName":"PermissionRequest",
#     "decision":{"behavior":"allow"},
#     "permissionDecisionReason":"safe read-only pattern"}}
# This requires a careful allowlist; ship as a separate change after pattern review.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

DIR="$(pwd)"
ROOT=""
while [ "$DIR" != "/" ]; do
  [ -d "$DIR/.claude-plugin" ] && { ROOT="$DIR"; break; }
  DIR="$(dirname "$DIR")"
done
[ -z "$ROOT" ] && ROOT="$(pwd)"

SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

extract() { echo "$INPUT" | { grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" || true; } | head -1 | sed "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"//;s/\"$//"; }

SESSION_ID="$(extract session_id)"
TOOL_NAME="$(extract tool_name)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"permission_request\",\"message\":\"Permission requested for ${TOOL_NAME:-?}\",\"detail\":{\"tool_name\":\"$TOOL_NAME\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
