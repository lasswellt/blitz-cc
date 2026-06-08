#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks `--no-verify` in any git command.
# Hooks are guard rails, not obstacles. Bypassing them silently lands broken commits.
# Real incident: anthropics/claude-code#40117 — agent landed 6 commits with 63 failing
# tests via --no-verify + git stash tricks despite explicit deny rules.
#
# Emergency override (user, not agent): BLITZ_OVERRIDE_NO_VERIFY=1 must be set in env.
#
# Containment: environment-layer guard (user-misuse). Canonical posture: /_shared/security.md §2 (env-first).
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

[[ -z "$CMD" ]] && exit 0

# Match --no-verify OR the POSIX short alias -n as standalone git-commit args.
# The short form `git commit -n` is equivalent per git-commit(1) and was missing
# from the original pattern — closing the bypass documented in audit-20260517.
#
# To avoid false positives from -n inside commit message strings like
# `git commit -m "use -n flag"`, strip quoted strings before pattern check.
CMD_CLEAN="$(printf '%s' "$CMD" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g')"
NO_VERIFY_LONG="$(printf '%s' "$CMD_CLEAN" | grep -cE '(^|[[:space:]])--no-verify([[:space:]]|$)' || true)"
# -n short form: standalone flag OR combined short flags like -an, -nm, -na, -anm
# Git's POSIX short-flag grouping means -n can be combined with other flags (-an = -a -n).
#
# The short-flag scan MUST be scoped to the `git ... commit` segment only.
# A bare `.*` between `commit` and the `-n` flag would span command separators
# (&&, ;, |) and false-positive on a separate `-n` command chained after the
# commit (e.g. `git commit -m wip && npm run lint -n`). To prevent that, split
# CMD_CLEAN on separators and test only segments whose token stream contains a
# `git ... commit` invocation, anchoring the short-flag scan to that segment.
NO_VERIFY_SHORT=0
# Split on &&, ||, ;, | (and newlines) into segments; the literal control-char
# substitution lets us iterate segment-by-segment without a subshell pipe.
SEGMENTS="$(printf '%s' "$CMD_CLEAN" | sed -E 's/(&&|\|\||[;|])/\n/g')"
while IFS= read -r SEG; do
  # Only consider a segment that actually contains `git ... commit`.
  if printf '%s' "$SEG" | grep -qE 'git[[:space:]]+([^&|;]*[[:space:]])?commit([[:space:]]|$)'; then
    # Within this git-commit segment, scan only the flag tokens that follow
    # `commit` (a short flag bundle containing n). [^&|;] keeps the scan inside
    # the segment even though we already split, belt-and-suspenders.
    if printf '%s' "$SEG" | grep -qE 'commit([[:space:]]+[^&|;]*)?[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)'; then
      NO_VERIFY_SHORT=1
    fi
  fi
done <<< "$SEGMENTS"
if [[ "${NO_VERIFY_LONG:-0}" -gt 0 || "${NO_VERIFY_SHORT:-0}" -gt 0 ]]; then
  if [[ "${BLITZ_OVERRIDE_NO_VERIFY:-0}" == "1" ]]; then
    # Logged override: user explicitly set the env var.
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
    if [[ -d .cc-sessions ]]; then
      printf '{"ts":"%s","session":"%s","skill":"hook","event":"override","message":"BLITZ_OVERRIDE_NO_VERIFY used","detail":{"command":%s}}\n' \
        "$TS" "$SESSION_ID" "$(echo "$CMD" | jq -Rs .)" \
        >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true
    fi
    exit 0
  fi
  cat >&2 <<'EOF'
BLOCKED: --no-verify is forbidden.

Hooks are guard rails, not obstacles. If a pre-commit hook is failing, the commit
should not happen. Fix the underlying issue (failing test, lint error, type error)
and commit normally.

Real incident (anthropics/claude-code#40117): an agent landed 6 commits with 63
failing tests by using --no-verify + git stash. This block exists to prevent that.

If you genuinely need an emergency override (production hotfix with a known-flaky
test), the USER (not the agent) should set BLITZ_OVERRIDE_NO_VERIFY=1 in the
shell env before retrying. This is logged to the activity feed.
EOF
  exit 2
fi

exit 0
