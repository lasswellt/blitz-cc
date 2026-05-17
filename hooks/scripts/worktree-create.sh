#!/usr/bin/env bash
# worktree-create.sh — Log worktree creation events + collision guard (GH#51596)
# Fires on `claude --worktree` or `isolation: worktree` agent frontmatter.
#
# CAUTION: this is a worktree event. Per platform docs, a command hook for
# WorktreeCreate may print a path to STDOUT to override the default worktree
# location, and a NON-ZERO exit ABORTS worktree creation (different from
# other events). This hook intentionally exits non-zero only when the
# collision guard triggers — see comment block at the guard.

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
BRANCH="$(extract branch)"
[ -z "$SESSION_ID" ] && SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo unknown)"

# Collision guard — GH#51596: the 8-hex agentId prefix in `worktree-agent-<8hex>`
# can collide with a branch from a prior session, silently reusing stale commits
# + stashes. This is the root cause of dual-implementation merge conflicts like
# blitz's sprint-289/CAP-148. Refuse re-use when the existing branch is ahead of
# origin/HEAD; user runs /blitz:worktree-prune to inspect, or sets
# BLITZ_ALLOW_WORKTREE_COLLISION=1 to force-proceed.
if [[ "$BRANCH" =~ ^worktree-agent-[0-9a-f]{8}$ ]] \
   && [ "${BLITZ_ALLOW_WORKTREE_COLLISION:-0}" != "1" ]; then
  if git -C "$ROOT" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    AHEAD=$(git -C "$ROOT" rev-list --count "origin/HEAD..$BRANCH" 2>/dev/null || echo 0)
    if [ "${AHEAD:-0}" -gt 0 ]; then
      TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"worktree_collision_blocked\",\"message\":\"Refused stale agent branch $BRANCH ($AHEAD commits ahead)\",\"detail\":{\"branch\":\"$BRANCH\",\"ahead\":$AHEAD}}" >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true
      echo "BLITZ: refusing to reuse stale agent branch $BRANCH ($AHEAD commits ahead of origin/HEAD)" >&2
      echo "  -> run /blitz:worktree-prune to inspect, or set BLITZ_ALLOW_WORKTREE_COLLISION=1 to force" >&2
      exit 1
    fi
  fi
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"hook\",\"event\":\"worktree_create\",\"message\":\"Worktree created\",\"detail\":{\"worktree_path\":\"$WORKTREE_PATH\",\"branch\":\"$BRANCH\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true

# IMPORTANT: do NOT print to stdout; that would override the default worktree path.
exit 0
