#!/usr/bin/env bash
# post-tool-failure.sh — Log failed tool execution
# Fires on tool error (e.g. Edit failed, Bash non-zero, MCP tool errored).
# Non-blocking: always exits 0.
#
# Stub: logs only. Future behavior could auto-recover from common failure modes
# (e.g. stale Read cache, Edit that errored on mid-file state).

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
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"post_tool_failure\",\"message\":\"Tool ${TOOL_NAME:-?} failed\",\"detail\":{\"tool_name\":\"$TOOL_NAME\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
