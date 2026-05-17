#!/usr/bin/env bash
# subagent-stop.sh — Log subagent completion to activity feed
# Fires when a subagent finishes. Non-blocking: always exits 0.
#
# Stub: logs only. Future behavior could enforce the Agent Output Contract
# (spawn-protocol.md §9) against the subagent's reply before it propagates.

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
AGENT_ID="$(extract agent_id)"
AGENT_TYPE="$(extract agent_type)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"subagent_stop\",\"message\":\"Subagent ${AGENT_TYPE:-?} stopped\",\"detail\":{\"agent_id\":\"$AGENT_ID\",\"agent_type\":\"$AGENT_TYPE\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
