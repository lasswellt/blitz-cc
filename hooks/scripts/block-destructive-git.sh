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
. "$(dirname "$0")/_lib/common.sh"
blitz_guard_input block-destructive-git
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

# The push and reset --hard rules bound their flag gap with [^;&|] so a flag in
# a LATER command (`git push origin main; rm -f x`) is not attributed to git.
# A separator inside quotes (`-o 'a;b'`) is argument text, not a command break,
# so mask it to `_` before matching; otherwise a quoted `;` would hide a real
# --force. Quote characters stay, so a quoted '--force' still reads as --force.
# Backslash-escaped chars are copied verbatim and an escaped separator is masked
# too. An unterminated quote masks to end of string: masking only widens the
# bound, so every ambiguity here resolves toward blocking.
mask_quoted_separators() {
  local LC_ALL=C s="$1" out="" q="" c i n
  n=${#s}
  for (( i = 0; i < n; i++ )); do
    c="${s:i:1}"
    if [[ "$q" == "'" ]]; then
      [[ "$c" == "'" ]] && q=""
    elif [[ "$c" == '\' && "$q" != "'" ]]; then
      # Escape: copy the backslash, then mask/copy the escaped char.
      out+="$c"; (( i++ )) || true
      c="${s:i:1}"
      [[ "$c" == [\;\&\|] ]] && c="_"
      out+="$c"; continue
    elif [[ "$q" == '"' ]]; then
      [[ "$c" == '"' ]] && q=""
    elif [[ "$c" == "'" || "$c" == '"' ]]; then
      q="$c"; out+="$c"; continue
    fi
    [[ -n "$q" && "$c" == [\;\&\|] ]] && c="_"
    out+="$c"
  done
  printf '%s' "$out"
}

# Scan cap 8 KiB keeps the per-call cost bounded. Past it, skip masking and use
# the unbounded gap (pre-T-008 behaviour): fail closed rather than trust a
# partial scan.
if (( $(LC_ALL=C; printf '%s' "$CMD_N" | wc -c) > 8192 )); then
  CMD_Q="$CMD_N"; GAP='.*'
else
  CMD_Q="$(mask_quoted_separators "$CMD_N")"; GAP='[^;&|]*'
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

# git reset --hard (any form). Matched on the global-flag-normalized command.
# The gap is $GAP on CMD_Q (quote-masked), so the flag must belong to the same
# simple command; see mask_quoted_separators.
if echo "$CMD_Q" | grep -qE "git[[:space:]]+reset[[:space:]]+(${GAP}[[:space:]])?[\"']?--hard"; then
  is_dirty && block "git reset --hard" "Working tree has uncommitted changes; --hard would destroy them."
fi

# git checkout -- . / git checkout -- *
if echo "$CMD_N" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?(\.|\*)'; then
  is_dirty && block "git checkout/restore ." "Discards all unstaged changes."
fi

# git clean -f / -fd / -fx (no dry-run)
if echo "$CMD_N" | grep -qE 'git[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*f|--force)' \
    && ! echo "$CMD_N" | grep -qE '[[:space:]](-[a-zA-Z]*n|--dry-run)([[:space:]]|$)'; then
  is_dirty && block "git clean -f" "Removes untracked files (config, logs, scratch work)."
fi

# git push --force / -f / --force-with-lease to a protected branch.
# audit-20260517: --force-with-lease was missing, leaving a history-rewrite bypass.
# The gap is $GAP on CMD_Q: a flag in a later command is not ours, but a
# separator inside quotes was masked and does not end the push command.
if echo "$CMD_Q" | grep -qE "git[[:space:]]+push[[:space:]]+(${GAP}[[:space:]])?[\"']?(--force|--force-with-lease(=[^[:space:]]*)?|-f)([[:space:]]|=|[\"']|\$)" \
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
