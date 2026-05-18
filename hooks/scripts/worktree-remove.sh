#!/usr/bin/env bash
# worktree-remove.sh — Log worktree removal + opportunistic branch cleanup
# Fires after a worktree is removed. Non-blocking: always exits 0.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
WORKTREE_PATH=$(blitz_extract worktree_path)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

DETAIL=$(jq -n --arg wp "$WORKTREE_PATH" '{worktree_path:$wp}')
blitz_log_event "hook" "worktree_remove" "Worktree removed" "$DETAIL"

# Opportunistic branch cleanup (skip when escape hatch set).
if [ "${BLITZ_SKIP_BRANCH_CLEANUP:-0}" != "1" ] && [ -n "$WORKTREE_PATH" ]; then
  BRANCH=$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | \
    awk -v p="$WORKTREE_PATH" 'BEGIN{w=""} /^worktree /{w=$2} /^branch /{if(w==p){sub("refs/heads/","",$2); print $2; exit}}')
  if [[ "$BRANCH" =~ ^(worktree-agent-|worktree-sprint-) ]]; then
    if git -C "$ROOT" merge-base --is-ancestor "$BRANCH" origin/HEAD 2>/dev/null; then
      if git -C "$ROOT" branch -d "$BRANCH" 2>/dev/null; then
        BDET=$(jq -n --arg br "$BRANCH" '{branch:$br}')
        blitz_log_event "hook" "branch_cleanup" "Auto-deleted merged branch $BRANCH" "$BDET"
      fi
    fi
  fi
fi

exit 0
