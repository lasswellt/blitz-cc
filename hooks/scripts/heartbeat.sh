#!/usr/bin/env bash
# heartbeat.sh — PostToolBatch heartbeat (renamed from post-tool-batch.sh, E-040 S2)
# Fires after a batch of parallel tools resolves, before the next model call.
# Marks the session record state:"working" + last_activity (liveness signal for
# stale-session detection, session-lifecycle.md §5a) and logs the batch.
# Non-blocking: always exits 0. No-op on the record when none exists.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

blitz_session_update "$SESSION_ID" '.state = "working" | .last_activity = $now'
blitz_log_event "hook" "post_tool_batch" "Parallel tool batch resolved"

exit 0
