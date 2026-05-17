#!/usr/bin/env bash
# subagent-start.sh — Log subagent spawn to activity feed
# Fires when a subagent (Agent tool) starts. Non-blocking: always exits 0.
#
# Stub: logs only. Future behavior could register subagent in session-protocol
# matrix or enforce agent-output-contract preamble injection.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

# Find project root by walking up from cwd looking for .claude-plugin/
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
AGENT_ID="$(extract agent_id)"
AGENT_TYPE="$(extract agent_type)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"subagent_start\",\"message\":\"Subagent ${AGENT_TYPE:-?} started\",\"detail\":{\"agent_id\":\"$AGENT_ID\",\"agent_type\":\"$AGENT_TYPE\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
