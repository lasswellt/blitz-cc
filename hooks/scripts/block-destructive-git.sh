#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks destructive git operations on a dirty tree.
# Patterns: `git reset --hard`, `git checkout -- .`, `git checkout -- *`,
# `git clean -fd`, `git clean -fx`, `git restore .`, `git branch -D` on current branch,
# `git push --force` to main/master.
#
# Allowed when working tree is clean (no risk of losing work).
# Containment: environment-layer guard (user-misuse). Canonical posture: /_shared/security.md §2 (env-first).
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

[[ -z "$CMD" ]] && exit 0

# Only inspect git commands
if ! echo "$CMD" | grep -qE '(^|[[:space:];&|])git[[:space:]]'; then
  exit 0
fi

# SEC-R2-01: a global flag placed BEFORE the git verb (e.g.
# `git -c core.pager=cat reset --hard`, `git --no-pager clean -fdx`) would
# otherwise slip past verb regexes that anchor the verb immediately after
# `git `. Normalize by stripping a leading run of recognized global flags so
# the verb sits directly after `git ` for matching. We rewrite each `git
# <globals> <verb>` occurrence to `git <verb>` in a working copy used only for
# verb detection (the original $CMD is preserved for messages).
#
# Recognized git global flags (git(1)): -c name=value, -C <path>, --no-pager,
# --paginate, -p, --git-dir[=| ]<path>, --work-tree[=| ]<path>.
normalize_git_globals() {
  # Repeatedly strip ONE leading global flag token that follows `git `, until
  # none remain. Done with sed in a loop to handle interleaved/multiple flags.
  local s="$1" prev=""
  while [[ "$s" != "$prev" ]]; do
    prev="$s"
    s="$(printf '%s' "$s" | sed -E \
      's/((^|[;&|][[:space:]]*)git)[[:space:]]+(-c[[:space:]]+[^[:space:]]+|-C[[:space:]]+[^[:space:]]+|--no-pager|--paginate|-p|--git-dir(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)|--work-tree(=[^[:space:]]+|[[:space:]]+[^[:space:]]+))[[:space:]]+/\1 /g')"
  done
  printf '%s' "$s"
}
CMD_N="$(normalize_git_globals "$CMD")"

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

# git reset --hard (any form). Matched on the global-flag-normalized command.
if echo "$CMD_N" | grep -qE 'git[[:space:]]+reset[[:space:]]+(.*[[:space:]])?--hard'; then
  is_dirty && block "git reset --hard" "Working tree has uncommitted changes; --hard would destroy them."
fi

# git checkout -- . / git checkout -- *
if echo "$CMD_N" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+--?[[:space:]]*(\.|\*)'; then
  is_dirty && block "git checkout/restore -- ." "Discards all unstaged changes."
fi

# git clean -f / -fd / -fx (no dry-run)
if echo "$CMD_N" | grep -qE 'git[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*f|--force)' \
    && ! echo "$CMD_N" | grep -qE '[[:space:]](-[a-zA-Z]*n|--dry-run)([[:space:]]|$)'; then
  is_dirty && block "git clean -f" "Removes untracked files (config, logs, scratch work)."
fi

# git push --force / -f / --force-with-lease to a protected branch.
# audit-20260517: --force-with-lease was missing, leaving a history-rewrite bypass.
if echo "$CMD_N" | grep -qE 'git[[:space:]]+push[[:space:]]+(.*[[:space:]])?(--force|--force-with-lease(=[^[:space:]]*)?|-f)([[:space:]]|=|$)' \
    && echo "$CMD" | grep -qE '(main|master|production|release)'; then
  block "git push --force to protected branch" "Force-pushing main/master rewrites shared history."
fi

# git branch -D / -d on current branch.
# H2/SEC-R2-01: compare $CURRENT as a WHOLE argument token, not a substring.
# `grep -qF "$CURRENT"` substring-matched, so `git branch -D feature-mainline`
# was wrongly blocked when on `main`. We now extract the operand tokens after
# `git branch -D/-d` and block only on an exact-equality match to $CURRENT.
if echo "$CMD_N" | grep -qE 'git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*[dD]|--delete)([[:space:]]|$)'; then
  CURRENT="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$CURRENT" ]]; then
    # Pull the substring from `git branch ... -D/-d` to the next separator,
    # then iterate its whitespace-separated tokens, skipping flag tokens, and
    # compare each operand for exact equality with the current branch.
    BR_SEG="$(printf '%s' "$CMD_N" | sed -nE 's/.*git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*[dD]|--delete)[[:space:]]+([^;&|]*).*/\2/p')"
    for tok in $BR_SEG; do
      [[ "$tok" == -* ]] && continue
      # Strip surrounding quotes a crafted name might carry.
      tok="${tok#\"}"; tok="${tok%\"}"; tok="${tok#\'}"; tok="${tok%\'}"
      if [[ "$tok" == "$CURRENT" ]]; then
        block "git branch -D <current>" "Cannot delete the branch you're on; ambiguous intent."
      fi
    done
  fi
fi

exit 0
