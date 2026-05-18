#!/usr/bin/env bash
# task-completed-validate.sh — Validate task completion against Definition of Done
# Exit code 2 blocks task completion and sends feedback
# Exit code 0 allows task completion
# Non-blocking by default: exits 0

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat)

TASK_SUBJECT=$(blitz_extract subject)
AGENT_TYPE=$(blitz_extract agent_type)

ROOT=$(blitz_find_root) || exit 0

# Only validate sprint story tasks (format: "S{N}-{NNN}: ..." or "S{N}-G{NNN}: ..." for gap-closure)
if [[ ! "$TASK_SUBJECT" =~ ^S[0-9]+-G?[0-9]+: ]]; then
  exit 0
fi

# Quick check for placeholder patterns in recently modified files
RECENT_FILES=$(git diff --name-only HEAD~1 HEAD -- '*.ts' '*.tsx' '*.vue' '*.js' '*.jsx' 2>/dev/null || true)

PLACEHOLDERS_FOUND=0
for file in $RECENT_FILES; do
  [ -f "$ROOT/$file" ] || continue
  if grep -qE '(TODO:\s*implement|throw new Error.*Not implemented|return \{\}|return \[\]|PLACEHOLDER|STUB)' "$ROOT/$file" 2>/dev/null; then
    PLACEHOLDERS_FOUND=1
    echo "[task-validate] WARNING: Placeholder found in $file"
  fi
done

if [ "$PLACEHOLDERS_FOUND" -eq 1 ]; then
  echo "[task-validate] Task '$TASK_SUBJECT' has placeholder implementations. Please complete them before marking done."
  # Exit 2 to block completion and send feedback
  exit 2
fi

SESSION_ID="${AGENT_TYPE:-$(blitz_session_id)}"
SESSIONS_DIR="$ROOT/.cc-sessions"
blitz_log_event "hook" "task_validated" "Task completed and validated: $TASK_SUBJECT"

exit 0
