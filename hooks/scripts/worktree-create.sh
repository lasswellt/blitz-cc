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
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
WORKTREE_PATH=$(blitz_extract worktree_path)
BRANCH=$(blitz_extract branch)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)

# Collision guard — GH#51596: the 8-hex agentId prefix in `worktree-agent-<8hex>`
# can collide with a branch from a prior session, silently reusing stale commits
# + stashes. This is the root cause of dual-implementation merge conflicts like
# blitz's sprint-289/CAP-148. Refuse re-use when the existing branch is ahead of
# origin/HEAD; user runs /blitz:worktree-prune to inspect, or sets
# BLITZ_ALLOW_WORKTREE_COLLISION=1 to force-proceed.
#
# INTEROP (native agent view, CC >=2.1.139): this guard is scoped to the
# `worktree-agent-<8hex>` branch name only, so it does NOT fire for native
# background-session worktrees (`claude --bg` / `claude agents`), which the
# platform isolates under .claude/worktrees/ with different branch naming.
# No false-abort on background dispatch. See worktree-lifecycle.md §Interop.
if [[ "$BRANCH" =~ ^worktree-agent-[0-9a-f]{8}$ ]] \
   && [ "${BLITZ_ALLOW_WORKTREE_COLLISION:-0}" != "1" ]; then
  if git -C "$ROOT" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    AHEAD=$(git -C "$ROOT" rev-list --count "origin/HEAD..$BRANCH" 2>/dev/null || echo 0)
    if [ "${AHEAD:-0}" -gt 0 ]; then
      CDET=$(jq -n --arg br "$BRANCH" --argjson ah "${AHEAD:-0}" '{branch:$br,ahead:$ah}')
      blitz_log_event "hook" "worktree_collision_blocked" "Refused stale agent branch $BRANCH ($AHEAD commits ahead)" "$CDET"
      echo "BLITZ: refusing to reuse stale agent branch $BRANCH ($AHEAD commits ahead of origin/HEAD)" >&2
      echo "  -> run /blitz:worktree-prune to inspect, or set BLITZ_ALLOW_WORKTREE_COLLISION=1 to force" >&2
      exit 1
    fi
  fi
fi

DETAIL=$(jq -n --arg wp "$WORKTREE_PATH" --arg br "$BRANCH" '{worktree_path:$wp,branch:$br}')
blitz_log_event "hook" "worktree_create" "Worktree created" "$DETAIL"

# IMPORTANT: do NOT print to stdout; that would override the default worktree path.
exit 0
