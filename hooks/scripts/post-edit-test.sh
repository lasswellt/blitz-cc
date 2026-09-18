#!/usr/bin/env bash
# PostToolUse hook (Write|Edit) — records the edited file for test-impact analysis.
# Always exits 0 (non-blocking).
#
# E-043 S3: this script no longer finds or runs tests. The filename-sibling
# matcher moved to scripts/test-selector.sh (source 1 of 4, alongside the
# import graph and the journal's recent-fail / co-change history), and the run
# itself moved to hooks/scripts/heartbeat.sh (PostToolBatch, async +
# asyncRewake): once per tool batch it reads this session's touched.txt, asks
# the selector for the impacted test files, runs them through
# scripts/test-listener.sh, and re-wakes the model with a failure digest.
# Splitting record (here) from run (heartbeat) means N edits in one batch cost
# one selected-set run instead of N sibling runs. Set BLITZ_TIA_DISABLE=1 to
# stop the heartbeat run; this recorder stays cheap and harmless.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat)

FILE_PATH=$(blitz_extract file_path)
[ -n "$FILE_PATH" ] || exit 0

SESSION_ID=$(blitz_extract session_id)
[ -n "$SESSION_ID" ] || SESSION_ID=$(blitz_session_id)
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -c 'A-Za-z0-9_.-' '_')
case "$SAFE_SID" in ''|.*) exit 0 ;; esac

ROOT=$(blitz_find_root || true)
SESSIONS_DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
TOUCHED_DIR="$SESSIONS_DIR/sessions/$SAFE_SID"
TOUCHED="$TOUCHED_DIR/touched.txt"

# Never track the session/journal bookkeeping itself.
case "$FILE_PATH" in *"/.cc-sessions/"*|".cc-sessions/"*) exit 0 ;; esac

mkdir -p "$TOUCHED_DIR" 2>/dev/null || exit 0
if [ ! -f "$TOUCHED" ] || ! grep -qxF -- "$FILE_PATH" "$TOUCHED" 2>/dev/null; then
  printf '%s\n' "$FILE_PATH" >> "$TOUCHED" 2>/dev/null || true
fi

exit 0
