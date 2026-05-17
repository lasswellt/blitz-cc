#!/usr/bin/env bash
# worktree-remove.sh — Log worktree removal + opportunistic branch cleanup
# Fires after a worktree is removed. Non-blocking: always exits 0.
#
# Per Claude Code spec, `git worktree remove` (and the platform's equivalent)
# leaves the underlying branch intact. This hook opportunistically deletes
# `worktree-agent-*` and `worktree-sprint-*` branches IFF they are fully merged
# into origin/HEAD — best-effort, never blocks.

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
WORKTREE_PATH="$(extract worktree_path)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"worktree_remove\",\"message\":\"Worktree removed\",\"detail\":{\"worktree_path\":\"$WORKTREE_PATH\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true

# Opportunistic branch cleanup (skip when escape hatch set).
# Derives the branch name from git worktree metadata; only deletes when the
# branch is an ancestor of origin/HEAD (i.e., already merged or empty).
if [ "${BLITZ_SKIP_BRANCH_CLEANUP:-0}" != "1" ] && [ -n "$WORKTREE_PATH" ]; then
  BRANCH=$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | \
    awk -v p="$WORKTREE_PATH" 'BEGIN{w=""} /^worktree /{w=$2} /^branch /{if(w==p){sub("refs/heads/","",$2); print $2; exit}}')
  if [[ "$BRANCH" =~ ^(worktree-agent-|worktree-sprint-) ]]; then
    if git -C "$ROOT" merge-base --is-ancestor "$BRANCH" origin/HEAD 2>/dev/null; then
      if git -C "$ROOT" branch -d "$BRANCH" 2>/dev/null; then
        TS2=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        echo "{\"ts\":\"$TS2\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"branch_cleanup\",\"message\":\"Auto-deleted merged branch $BRANCH\",\"detail\":{\"branch\":\"$BRANCH\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true
      fi
    fi
  fi
fi

exit 0
