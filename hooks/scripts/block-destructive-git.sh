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

# Push-force and reset-hard are fail-closed: the base rule is the BASE
# behaviour, an unbounded `.*` gap between the verb and the flag on the whole
# command. Narrowing it once (gap `[^;&|]*`) let redirections (`2>&1 --force`,
# `>| log -f`) and expansions holding a separator (`$(echo a;b) --force`) cut
# the gap and hide a real flag. So the only exception is the reverse: allow
# when a CLEAR command break, outside quotes, sits between verb and flag. That
# lets `git push origin HEAD && rm -f tmp` through without trusting `;&|`
# characters whose meaning a char scan cannot be sure of.
#
# mark_command_breaks rewrites every certain break outside quotes to `;` and
# every other `;`, `&`, `|` to `_`, so the rules can use gap `[^;]*`:
#   `;`, newline, `&&`, `||`, a bare `|`, a lone background `&` -> `;`
#   quoted or backslash-escaped `;&|`, `>&` `<&` `&>` (incl. `2>&1`), `>|`,
#   `|&`, and `|` after a digit or `>` -> `_` (not a break: keeps blocking)
# A newline inside quotes is argument text (space), outside it ends the command.
# Quote characters stay, so a quoted '--force' still reads as --force. An
# unterminated quote masks to end of string: masking only widens the gap, so
# every ambiguity resolves toward blocking.
mark_command_breaks() {
  local LC_ALL=C s="$1" out="" q="" c p="" nx i n
  n=${#s}
  for (( i = 0; i < n; i++ )); do
    c="${s:i:1}"; nx="${s:i+1:1}"
    if [[ "$c" == '\' && "$q" != "'" ]]; then
      # Escape: copy the backslash, then mask the escaped char if it could
      # read as a break.
      out+="$c"; (( i++ )) || true
      c="${s:i:1}"
      [[ "$c" == [\;\&\|] || "$c" == $'\n' ]] && c="_"
      out+="$c"; p="_"; continue
    fi
    if [[ -n "$q" ]]; then
      [[ "$c" == "$q" ]] && q=""
      [[ "$c" == [\;\&\|] ]] && c="_"
      [[ "$c" == $'\n' ]] && c=" "
      out+="$c"; p="_"; continue
    fi
    case "$c" in
      "'"|'"') q="$c" ;;
      ';'|$'\n') c=";" ;;
      '&')
        if [[ "$p" == [\<\>] || "$nx" == '>' ]]; then c="_"
        elif [[ "$nx" == '&' ]]; then c=";;"; (( i++ )) || true
        else c=";"; fi ;;
      '|')
        if [[ "$p" == [\>0-9] ]]; then c="_"
        elif [[ "$nx" == '|' ]]; then c=";;"; (( i++ )) || true
        elif [[ "$nx" == '&' ]]; then c="__"; (( i++ )) || true
        else c=";"; fi ;;
    esac
    p="${s:i:1}"; out+="$c"
  done
  printf '%s' "$out"
}

# The exception is disabled (BASE behaviour, block) when the command holds a
# construct whose separators a char scan cannot attribute: command/arithmetic
# substitution, backticks, ANSI-C quoting, parameter expansion, process
# substitution, here-docs, or a backslash-newline continuation. Also past the
# 8 KiB scan cap, which keeps the per-call cost bounded: fail closed rather
# than trust a partial scan. Newlines join to spaces so the line-based grep
# sees the whole command.
case "$CMD_N" in
  *'$('*|*'`'*|*"\$'"*|*'${'*|*'<('*|*'>('*|*'<<'*|*$'\\\n'*) BREAKS_OK=0 ;;
  *) BREAKS_OK=1 ;;
esac
(( $(LC_ALL=C; printf '%s' "$CMD_N" | wc -c) > 8192 )) && BREAKS_OK=0
# A function or alias defined earlier in the line can forward a flag that
# appears after a break into the git call (`f(){ git push "$@"; }; f --force
# origin main`), so a break no longer separates verb from flag. Fail closed.
printf '%s' "$CMD_N" | grep -qE '\(\)|(^|[;&|({[:space:]])(function|alias)[[:space:]]' && BREAKS_OK=0
if (( BREAKS_OK )); then
  CMD_B="$(mark_command_breaks "$CMD_N")"; GAP='[^;]*'
else
  CMD_B="${CMD_N//$'\n'/ }"; GAP='.*'
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
# The gap is $GAP on CMD_B: unbounded unless a certain command break separates
# verb and flag; see mark_command_breaks.
if printf '%s\n' "$CMD_B" | grep -qE "git[[:space:]]+reset[[:space:]]+(${GAP}[[:space:]])?[\"']?--hard"; then
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
# The gap is $GAP on CMD_B: a flag after a certain command break is not ours;
# any other separator (quoted, redirection, expansion) does not end the push.
if printf '%s\n' "$CMD_B" | grep -qE "git[[:space:]]+push[[:space:]]+(${GAP}[[:space:]])?[\"']?(--force|--force-with-lease(=[^[:space:]]*)?|-f)([[:space:]]|=|[\"']|\$)" \
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
