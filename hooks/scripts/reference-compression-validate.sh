#!/usr/bin/env bash
# PreToolUse hook — validates that any compressed references/main.md still
# preserves the structural elements of its sibling references/main.md.original
# backup IN THE CALLING REPO (not plugin internals).
#
# v1.12.1: scope changed from plugin cache to user CWD. Prior versions did
# `cd $(dirname $0)/../..` which pointed into the plugin install dir, so
# drift in OUR bundled .original pairs blocked every blitz user's git commit
# regardless of whether their project had any pairs. New behavior: operate
# on the calling git repo. Most user projects have no `.original` files,
# so the hook exits 0 immediately. Plugin developers running commits inside
# the plugin repo still get the validation.
#
# Dual-mode:
#   - With hook JSON on stdin (PreToolUse/Bash): only fires on `git commit`,
#     exits 1 on drift (advisory — does NOT block; user can choose to abort).
#   - Without JSON on stdin (direct invocation / CI): runs unconditionally,
#     exits 1 on drift.
#
# Checks (between <file>.original and <file>) — LOSS-ONLY semantics:
#   1. Compressed must contain ≥ original's count of fenced code-block delimiters
#   2. Compressed's URL set must be a superset of original's
#   3. Compressed's heading set must be a superset of original's (additive OK)
#   4. Compressed must contain ≥ original's count of table-row lines
#
# Additive content (new headings, new URLs, new sections added in later
# sprints) is explicitly allowed. Only LOSS of structural elements is a
# failure. This matches the actual semantic intent of compression review.

set -uo pipefail

HOOK_MODE=0
EXIT_BLOCK=1   # downgraded from 2 in v1.12.1 — plugin-internal drift must
               # not hard-block user commits

# If stdin is a pipe and contains JSON, run in hook mode.
if [[ ! -t 0 ]]; then
  INPUT="$(cat || true)"
  if [[ -n "$INPUT" ]] && echo "$INPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    HOOK_MODE=1
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null || true)
    # Only validate on git commit
    if [[ "$COMMAND" != *"git commit"* ]]; then
      exit 0
    fi
  fi
fi

# Operate on the CALLING REPO, not plugin internals. v1.12.0 and earlier
# pointed REPO_ROOT at the plugin cache via "$(dirname $0)/../.." which made
# every user's commit fail when our bundled .original files drifted from
# the maintained sources. v1.12.1+: use the caller's git repo root, or fall
# back to CWD if not in a git repo. If pwd is somehow the plugin repo (eg.
# the plugin author is developing it), behavior is unchanged for them — the
# pairs live in that repo and get validated.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" 2>/dev/null || exit 0

FAILED=0
CHECKED=0

# Find compressed pairs in THIS repo only. Most user projects will have
# none — find returns nothing, while-loop body never executes, exit 0.
while IFS= read -r orig; do
  [[ -z "$orig" ]] && continue
  compressed="${orig%.original}"
  if [[ ! -f "$compressed" ]]; then
    echo "FAIL $orig: sibling $compressed missing"
    FAILED=1
    continue
  fi
  CHECKED=$((CHECKED + 1))

  # 1. Code-fence delimiter parity (LOSS-ONLY: compressed must have ≥ original)
  of=$(grep -c '^```' "$orig" || true)
  cf=$(grep -c '^```' "$compressed" || true)
  if [[ "$cf" -lt "$of" ]]; then
    echo "FAIL $compressed: code-fence count $cf < $of (original) — content lost"
    FAILED=1
  fi

  # 2. URL set parity (LOSS-ONLY: compressed's set must be ⊇ original's)
  missing_urls=$(comm -23 \
    <(grep -oE 'https?://[^ )<>"'"'"']+' "$orig"        | sort -u) \
    <(grep -oE 'https?://[^ )<>"'"'"']+' "$compressed" | sort -u))
  if [[ -n "$missing_urls" ]]; then
    echo "FAIL $compressed: URL(s) missing from compressed:"
    echo "$missing_urls" | sed 's/^/  /'
    FAILED=1
  fi

  # 3. Heading list parity (LOSS-ONLY: compressed's set must be ⊇ original's)
  missing_headings=$(comm -23 \
    <(grep -E '^#+ ' "$orig"        | sort -u) \
    <(grep -E '^#+ ' "$compressed" | sort -u))
  if [[ -n "$missing_headings" ]]; then
    echo "FAIL $compressed: heading(s) missing from compressed:"
    echo "$missing_headings" | sed 's/^/  /'
    FAILED=1
  fi

  # 4. Table-row count parity (LOSS-ONLY: compressed must have ≥ original)
  ot=$(grep -c '^|' "$orig" || true)
  ct=$(grep -c '^|' "$compressed" || true)
  if [[ "$ct" -lt "$ot" ]]; then
    echo "FAIL $compressed: table-row count $ct < $ot (original) — content lost"
    FAILED=1
  fi
done < <(find . -type f -path '*/references/main.md.original' 2>/dev/null)

if [[ "$FAILED" -ne 0 ]]; then
  echo "reference-compression-validate: $FAILED check(s) failed across $CHECKED pair(s)"
  if [[ "$HOOK_MODE" -eq 1 ]]; then
    echo "(advisory only — exit 1; commit not blocked. Refresh .original files"
    echo " in the plugin repo to clear, or use --no-verify for this one commit.)"
  fi
  exit "$EXIT_BLOCK"
fi

# Stay silent in hook mode when all good; be chatty when invoked manually.
if [[ "$HOOK_MODE" -eq 0 ]]; then
  echo "reference-compression-validate: OK ($CHECKED pair(s) checked)"
fi
exit 0
