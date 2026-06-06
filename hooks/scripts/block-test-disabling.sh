#!/usr/bin/env bash
# PreToolUse hook on Write|Edit. Blocks insertions of `.skip(`, `.only(`, `xit`,
# `xdescribe`, `xtest`, or `test.todo(` in test files.
#
# Why: disabling tests is a canonical autonomous-coder shortcut for "making CI
# pass." quality-engine.md row 13 documents this. Test deletion is already
# blocked by block-test-deletion.sh; this hook closes the rename-equivalent
# escape (leave the test file in place, but neuter every test inside).
#
# Escape hatch: inline same-line comment `// blitz:skip-pinned: #<issue-or-url>`
# justifies the .skip with a tracked reason.
# Containment: environment-layer guard (model-misbehavior). Canonical posture: /_shared/security.md §2 (env-first).
#
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"

[[ -z "$FILE_PATH" ]] && exit 0

# Only test files are in scope
case "$FILE_PATH" in
  *.test.*|*.spec.*|*/__tests__/*|*/test/*|*/tests/*) ;;
  *) exit 0 ;;
esac

# User opt-out
[[ "${BLITZ_DISABLE_TEST_DISABLING_BLOCK:-0}" == "1" ]] && exit 0

# Extract proposed new content
case "$TOOL" in
  Write)
    NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")"
    ;;
  Edit)
    NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")"
    OLD_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null || echo "")"
    ;;
  MultiEdit)
    NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")' 2>/dev/null || echo "")"
    OLD_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.old_string // ""] | join("\n")' 2>/dev/null || echo "")"
    ;;
  *) exit 0 ;;
esac

[[ -z "$NEW_CONTENT" ]] && exit 0

# Count test-disabling tokens; exclude lines with the escape-hatch marker
count_disablers() {
  local text="$1"
  # `|| true` on each grep — set -o pipefail otherwise propagates 'no match' (exit 1).
  # `grep -c` always prints the count to stdout (even 0); only the exit code differs.
  echo "$text" \
    | { grep -vE '//\s*blitz:skip-pinned:' || true; } \
    | { grep -cE '\.skip\s*\(|\.only\s*\(|\bxit\b|\bxdescribe\b|\bxtest\b|test\.todo\s*\(' || true; }
}

NEW_COUNT=$(count_disablers "$NEW_CONTENT")

case "$TOOL" in
  Write)
    if [[ -f "$FILE_PATH" ]]; then
      OLD_COUNT=$(count_disablers "$(cat "$FILE_PATH")")
    else
      OLD_COUNT=0
    fi
    ;;
  Edit|MultiEdit)
    OLD_COUNT=$(count_disablers "${OLD_CONTENT:-}")
    ;;
esac

if (( NEW_COUNT > OLD_COUNT )); then
  DELTA=$(( NEW_COUNT - OLD_COUNT ))
  cat >&2 <<EOF
BLOCKED: $DELTA new test-disabling token(s) without justification.

File: $FILE_PATH
Patterns matched: .skip( | .only( | xit | xdescribe | xtest | test.todo(

Disabling tests to make CI pass is the canonical autonomous-coder shortcut. If a
test is broken, fix it. If the test pins to a known external issue, mark it with
the escape hatch:

  it.skip('foo', () => { ... })  // blitz:skip-pinned: #1234

The escape hatch is documented in skills/_shared/quality-engine.md §4. Without
the marker the edit is blocked.

\`.only\` in a committed test file is almost always a debugging mistake; remove it
before committing.

Override the entire hook (not recommended): BLITZ_DISABLE_TEST_DISABLING_BLOCK=1
EOF
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [[ -d .cc-sessions ]]; then
    printf '{"ts":"%s","session":"%s","skill":"hook","event":"verification","message":"test-disabling insertion blocked","detail":{"file":"%s","old":%d,"new":%d}}\n' \
      "$TS" "${CLAUDE_SESSION_ID:-unknown}" "$FILE_PATH" "$OLD_COUNT" "$NEW_COUNT" \
      >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true
  fi
  exit 2
fi

exit 0
