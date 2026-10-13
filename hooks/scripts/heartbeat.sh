#!/usr/bin/env bash
# heartbeat.sh: PostToolBatch heartbeat (renamed from post-tool-batch.sh, E-040 S2)
# Fires after a batch of parallel tools resolves, before the next model call.
# Marks the session record state:"working" + last_activity (liveness signal for
# stale-session detection, sessions.md §3). It writes no feed line: the feed
# carries loop and skill events only (sessions.reference.md §9).
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

# A tool batch running proves this session is no longer waiting on the user, so
# its own pending needs_input/permission notices (written by notification-log.sh)
# are stale; left pending they make `next --loop` defer on its own idle prompt.
# Cheap grep first (no rewrite when nothing matches); jq to a same-dir tmp then
# mv (atomic). Any failure (e.g. a malformed line) leaves the inbox untouched.
INBOX="$SESSIONS_DIR/inbox.jsonl"
if [ -n "$SESSION_ID" ] && [ -f "$INBOX" ] && grep -q 'pending' "$INBOX" 2>/dev/null \
   && grep -qF -- "$SESSION_ID" "$INBOX" 2>/dev/null; then
  INBOX_TMP=$(mktemp "$INBOX.XXXXXX" 2>/dev/null) || INBOX_TMP=""
  if [ -n "$INBOX_TMP" ]; then
    if jq -c --arg sid "$SESSION_ID" '
         if .status == "pending" and .session == $sid and (.kind == "needs_input" or .kind == "permission")
         then .status = "dismissed" | .dismissed_by = "heartbeat" else . end' \
         "$INBOX" > "$INBOX_TMP" 2>/dev/null && ! cmp -s "$INBOX" "$INBOX_TMP"; then
      mv "$INBOX_TMP" "$INBOX" 2>/dev/null || rm -f "$INBOX_TMP"
    else
      rm -f "$INBOX_TMP"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# E-043 S3: test-impact run, once per batch.
# post-edit-test.sh appends every edited file to
# .cc-sessions/sessions/<sid>/touched.txt; here: selector -> runner -> listener.
# Output on stdout is delivered to the model via asyncRewake (hooks.json), so we
# print ONLY on failure (a <=10-line digest). BLITZ_TIA_DISABLE=1 opts out.
# ---------------------------------------------------------------------------
[ "${BLITZ_TIA_DISABLE:-0}" = "1" ] && exit 0
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -c 'A-Za-z0-9_.-' '_')
TOUCHED="$SESSIONS_DIR/sessions/$SAFE_SID/touched.txt"
[ -s "$TOUCHED" ] || exit 0

PROJECT_ROOT=$(blitz_extract cwd); [ -d "${PROJECT_ROOT:-}" ] || PROJECT_ROOT="$ROOT"
[ -f "$PROJECT_ROOT/package.json" ] || exit 0
if grep -qE '"vitest"' "$PROJECT_ROOT/package.json" 2>/dev/null; then RUNNER=vitest
elif grep -qE '"jest"' "$PROJECT_ROOT/package.json" 2>/dev/null; then RUNNER=jest
else exit 0; fi

PLUGIN_SCRIPTS="$(cd "$(dirname "$0")/../../scripts" 2>/dev/null && pwd)"
SELECTOR="$PLUGIN_SCRIPTS/test-selector.sh"; LISTENER="$PLUGIN_SCRIPTS/test-listener.sh"
[ -x "$SELECTOR" ] && [ -x "$LISTENER" ] || exit 0

# Claim this batch's touched set atomically (same-directory rename) so a concurrent
# heartbeat cannot run it twice. One scratch dir holds the runner's report; the
# EXIT trap removes it and the claimed batch file on every exit path.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/blitz-tia.XXXXXX" 2>/dev/null) || exit 0
BATCH="$TOUCHED.$$"
trap 'rm -rf "$WORK" "$BATCH"' EXIT
mv "$TOUCHED" "$BATCH" 2>/dev/null || exit 0
CHANGED=$(sort -u "$BATCH" | grep -v '^$' || true)
[ -n "$CHANGED" ] || exit 0

RUN_ID=$( (od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || date +%s )
cd "$PROJECT_ROOT" || exit 0
SELECTED=$(printf '%s\n' "$CHANGED" | "$SELECTOR" 2>/dev/null | cut -f1 | grep -v '^$' || true)
[ -n "$SELECTED" ] || exit 0

"$LISTENER" --start --run-id "$RUN_ID" --session "$SESSION_ID" 2>/dev/null || true
REPORT="$WORK/report.json"; : > "$REPORT"
CHANGED_CSV=$(printf '%s\n' "$CHANGED" | paste -sd, -)
# The project's own runner from node_modules/.bin, never a launcher: npx would
# download and run an unpinned package when the project has none installed.
BIN="$PROJECT_ROOT/node_modules/.bin/$RUNNER"
[ -x "$BIN" ] || exit 0
# shellcheck disable=SC2086  # SELECTED is a newline list of paths; word-split intended
if [ "$RUNNER" = vitest ]; then
  timeout 120s "$BIN" run --reporter=json --outputFile="$REPORT" $SELECTED >/dev/null 2>&1 || true
else
  timeout 120s "$BIN" --json --outputFile="$REPORT" $SELECTED >/dev/null 2>&1 || true
fi
"$LISTENER" --trigger post-edit --changed "$CHANGED_CSV" --selected-by selector \
  --run-id "$RUN_ID" --session "$SESSION_ID" < "$REPORT" 2>/dev/null || true

# Failure digest (<=10 lines): "file: failed test names".
DIGEST=$(jq -r '
  [.testResults[]? | select(.status == "failed" or ([.assertionResults[]? | select(.status=="failed")] | length > 0))
   | "\(.name | sub("^.*/(?<t>[^/]+/[^/]+)$"; "\(.t)")): \([.assertionResults[]? | select(.status=="failed") | .fullName] | join(", "))"]
  | .[0:9][]' "$REPORT" 2>/dev/null || true)
if [ -n "$DIGEST" ]; then
  N=$(printf '%s\n' "$DIGEST" | wc -l | tr -d ' ')
  echo "blitz TIA: $N failing test file(s) after edits to $(printf '%s\n' "$CHANGED" | wc -l | tr -d ' ') file(s) [run $RUN_ID]"
  printf '%s\n' "$DIGEST" | cut -c1-200
fi

exit 0
