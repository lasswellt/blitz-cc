#!/usr/bin/env bash
# worktree-create.sh — Log worktree creation events
# Fires on `claude --worktree` or `isolation: worktree` agent frontmatter.
#
# CAUTION: this is a worktree event. Per platform docs, a command hook for
# WorktreeCreate may print a path to STDOUT to override the default worktree
# location, and a NON-ZERO exit ABORTS worktree creation (different from
# other events). This stub does neither — logs only and exits 0 so default
# behavior proceeds unchanged.

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
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"worktree_create\",\"message\":\"Worktree created\",\"detail\":{\"worktree_path\":\"$WORKTREE_PATH\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true

# IMPORTANT: do NOT print to stdout; that would override the default worktree path.
exit 0
