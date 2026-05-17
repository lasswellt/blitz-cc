#!/usr/bin/env bash
# stop-failure.sh — Log turn-end failures (rate limits, billing, server errors)
# Fires when a turn ends via API error rather than normal completion.
# Matchers: rate_limit|authentication_failed|billing_error|server_error|max_output_tokens|unknown
# Output/exit ignored by Claude Code per platform docs. Logs to activity feed.
#
# Stub: logs only. Future behavior could write a rate-limit advisory to
# KNOWLEDGE.md so subsequent sessions know to use shorter prompts or
# fallback models.

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
FAILURE_TYPE="$(extract failure_type)"
[ -z "$FAILURE_TYPE" ] && FAILURE_TYPE="$(extract reason)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"stop_failure\",\"message\":\"Turn ended with failure: ${FAILURE_TYPE:-unknown}\",\"detail\":{\"failure_type\":\"$FAILURE_TYPE\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
