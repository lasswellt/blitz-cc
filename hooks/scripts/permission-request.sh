#!/usr/bin/env bash
# permission-request.sh — Log permission-prompt opportunities
# Fires when a permission dialog is about to be shown. Non-blocking: always exits 0.
#
# Stub: logs only. Does NOT emit a permissionDecision JSON, so the user is
# still prompted normally.
#
# This hook is intentionally async:true in hooks.json because async hooks cannot
# return permissionDecision values (Claude Code ignores the response). A
# synchronous hook that tries to auto-approve patterns based on grep-alone can
# be fooled by compound commands (e.g. `git status && rm -rf dist`). If selective
# auto-approval is added in the future, implement it as a separate synchronous
# hook with an explicit safelist and test coverage — not by re-enabling code in
# this file.

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
