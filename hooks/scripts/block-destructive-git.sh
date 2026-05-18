#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks destructive git operations on a dirty tree.
# Patterns: `git reset --hard`, `git checkout -- .`, `git checkout -- *`,
# `git clean -fd`, `git clean -fx`, `git restore .`, `git branch -D` on current branch,
# `git push --force` to main/master.
#
# Allowed when working tree is clean (no risk of losing work).
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

[[ -z "$CMD" ]] && exit 0

# Only inspect git commands
if ! echo "$CMD" | grep -qE '(^|[[:space:];&|])git[[:space:]]'; then
  exit 0
fi

is_dirty() {
  [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]
}

block() {
  local pattern="$1"
  local why="$2"
  cat >&2 <<EOF
BLOCKED: $pattern

$why

If this is intentional, ask the user to run the command themselves. Agents must
not silently destroy uncommitted work. To recover work after an unintended
destructive op, see: git reflog.
EOF
  exit 2
}

# git reset --hard (any form)
if echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+(.*[[:space:]])?--hard'; then
  is_dirty && block "git reset --hard" "Working tree has uncommitted changes; --hard would destroy them."
fi

# git checkout -- . / git checkout -- *
if echo "$CMD" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+--?[[:space:]]*(\.|\*)'; then
  is_dirty && block "git checkout/restore -- ." "Discards all unstaged changes."
fi

# git clean -f / -fd / -fx (no dry-run)
if echo "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*f|--force)' \
    && ! echo "$CMD" | grep -qE '(-n|--dry-run)'; then
  is_dirty && block "git clean -f" "Removes untracked files (config, logs, scratch work)."
fi

# git push --force / -f / --force-with-lease to a protected branch.
# audit-20260517: --force-with-lease was missing, leaving a history-rewrite bypass.
if echo "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]]+(.*[[:space:]])?(--force|--force-with-lease(=[^[:space:]]*)?|-f)([[:space:]]|=|$)' \
    && echo "$CMD" | grep -qE '(main|master|production|release)'; then
  block "git push --force to protected branch" "Force-pushing main/master rewrites shared history."
fi

# git branch -D on current branch.
# Branch name is escaped via grep -F (fixed-string) to prevent ERE metacharacter
# injection from crafted branch names — audit-20260517 sec-bash MEDIUM.
if echo "$CMD" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D'; then
  CURRENT="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$CURRENT" ]] && printf '%s' "$CMD" | grep -qF "$CURRENT"; then
    # Confirm -D and the current branch are both in the command
    if echo "$CMD" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D'; then
      block "git branch -D <current>" "Cannot delete the branch you're on; ambiguous intent."
    fi
  fi
fi

exit 0
