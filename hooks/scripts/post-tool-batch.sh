#!/usr/bin/env bash
# post-tool-batch.sh — Log parallel tool batch completion
# Fires after a batch of parallel tools resolves. Non-blocking: always exits 0.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

blitz_log_event "hook" "post_tool_batch" "Parallel tool batch resolved"

exit 0
