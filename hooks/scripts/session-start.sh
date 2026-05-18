#!/usr/bin/env bash
# shellcheck source=_lib/common.sh
# session-start.sh — Initialize session context on SessionStart hook
# Displays recent activity feed and checks for stale sessions
# Non-blocking: always exits 0

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

# --- HANDOFF.json auto-resume detection ---
# If a recent PreCompact wrote HANDOFF.json, surface it so Claude resumes
# the in-flight task instead of starting fresh.
HANDOFF="$SESSIONS_DIR/HANDOFF.json"
if [ -f "$HANDOFF" ]; then
  HANDOFF_AGE_SEC=$(( $(date +%s) - $(stat -c %Y "$HANDOFF" 2>/dev/null || stat -f %m "$HANDOFF" 2>/dev/null || echo 0) ))
  # Surface only if HANDOFF.json is fresh (≤24h). Older = stale, ignore.
  if [ "$HANDOFF_AGE_SEC" -le 86400 ]; then
    HANDOFF_PHASE=$(jq -r '.phase // "unknown"' "$HANDOFF" 2>/dev/null || echo "unknown")
    HANDOFF_SPRINT=$(jq -r '.sprint // "none"' "$HANDOFF" 2>/dev/null || echo "none")
    HANDOFF_BRANCH=$(jq -r '.branch // "unknown"' "$HANDOFF" 2>/dev/null || echo "unknown")
    HANDOFF_UNCOMMITTED_COUNT=$(jq -r '.uncommitted | length' "$HANDOFF" 2>/dev/null || echo 0)
    HANDOFF_LAST=$(jq -r '.last_activity // ""' "$HANDOFF" 2>/dev/null || echo "")
    cat <<EOF
[blitz] HANDOFF detected (compaction-resume artifact):
  sprint:      $HANDOFF_SPRINT
  phase:       $HANDOFF_PHASE
  branch:      $HANDOFF_BRANCH
  uncommitted: $HANDOFF_UNCOMMITTED_COUNT files
  last action: $HANDOFF_LAST

To continue prior work: read .cc-sessions/HANDOFF.json (full context), then
restate the in-flight task in ≤3 sentences and resume from the next dispatch.
To start fresh instead: archive HANDOFF.json (mv .cc-sessions/HANDOFF.json{,.archived-\$(date +%s)}).
EOF
  fi
fi

# Display recent activity (last 10 entries)
FEED="$SESSIONS_DIR/activity-feed.jsonl"
if [ -f "$FEED" ] && [ -s "$FEED" ]; then
  LINES=$(tail -10 "$FEED" 2>/dev/null || true)
  if [ -n "$LINES" ]; then
    echo "[blitz] Recent activity:"
    echo "$LINES" | while IFS= read -r line; do
      SESSION=$(echo "$line" | grep -o '"session":"[^"]*"' | head -1 | sed 's/"session":"//;s/"$//' || true)
      MSG=$(echo "$line" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//' || true)
      SKILL=$(echo "$line" | grep -o '"skill":"[^"]*"' | head -1 | sed 's/"skill":"//;s/"$//' || true)
      [ -n "$MSG" ] && echo "  [$SESSION] $SKILL: $MSG"
    done
  fi
fi

# Reset the per-session context-utilization counter so warnings track THIS session.
# (Without this reset, the monotonic counter accumulates across sessions and stays
# above the 80% threshold forever after any long session.)
echo 0 > "$SESSIONS_DIR/context-char-count" 2>/dev/null || true

# Check for stale sessions (active but >4h old). Use a portable epoch parser:
# GNU date first, BSD date fallback, python3 last-ditch. If all fail, skip
# the session — better silent skip than every session reporting "stale".
parse_iso_epoch() {
  local iso="$1"
  date -d "$iso" +%s 2>/dev/null && return 0
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null && return 0
  python3 - "$iso" <<'PYEOF' 2>/dev/null && return 0
import sys
from datetime import datetime
print(int(datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00')).timestamp()))
PYEOF
  return 1
}

NOW=$(date +%s)
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
  [ "$STATUS" = "active" ] || continue
  STARTED=$(grep -o '"started"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"started"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
  [ -n "$STARTED" ] || continue
  START_EPOCH=$(parse_iso_epoch "$STARTED") || continue
  AGE=$(( NOW - START_EPOCH ))
  if [ "$AGE" -gt 14400 ]; then
    SID=$(basename "$f" .json)
    echo "[blitz] WARNING: Stale session detected: $SID (started ${AGE}s ago)"
  fi
done

exit 0
