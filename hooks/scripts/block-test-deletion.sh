#!/usr/bin/env bash
# PreToolUse hook. Blocks deletion or emptying of test files.
# Covers two attack vectors:
#   1. Bash: `rm path/to/x.test.ts`, `rm -rf src/__tests__`
#   2. Write/Edit: writing empty content (or removing all `it(`/`test(`) to a *.test.* path
#
# Failure mode: agent "fixes" failing tests by deleting them. Real pattern documented in
# autonomous-coding field reports throughout 2025-2026.
# Containment: environment-layer guard (model-misbehavior). Canonical posture: /_shared/threat-model.md §2 (env-first).
#
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"

block() {
  cat >&2 <<EOF
BLOCKED: test file deletion or emptying.

$1

Deleting or emptying tests to make CI pass is the canonical autonomous-coder
shortcut. If a test is genuinely obsolete, the diff must explain why in a commit
message and the user must approve. Agents do not delete tests on their own.

If the test is broken and you need to fix it, EDIT it (keep the assertions), or
mark it .skip with a TODO comment that the critic agent will see.
EOF
  exit 2
}

case "$TOOL" in
  Bash)
    CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"
    [[ -z "$CMD" ]] && exit 0

    # rm of test/spec files or test directories
    if echo "$CMD" | grep -qE '(^|[[:space:];&|])rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[^&|;]*(\.test\.|\.spec\.|/__tests__/|/test/|/tests/)'; then
      block "Bash command: $CMD"
    fi

    # mv test → non-test (rename to bypass test discovery)
    if echo "$CMD" | grep -qE '(^|[[:space:];&|])(mv|git[[:space:]]+mv)[[:space:]]+[^[:space:]]*(\.test\.|\.spec\.)[^[:space:]]*[[:space:]]+[^[:space:]]*' \
        && echo "$CMD" | grep -qvE '(\.test\.|\.spec\.)[^[:space:]]*$'; then
      block "Renaming a test file to a non-test path: $CMD"
    fi
    ;;

  Write)
    FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"
    CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")"

    [[ -z "$FILE_PATH" ]] && exit 0

    # Only inspect test/spec files
    if ! echo "$FILE_PATH" | grep -qE '(\.test\.|\.spec\.|/__tests__/|/tests?/)'; then
      exit 0
    fi

    # Allow writing a new test file with substantive content
    [[ -z "$CONTENT" ]] && block "Empty Write to test file: $FILE_PATH"

    # Existing test file? Compare assertion count: must not drop to zero.
    if [[ -f "$FILE_PATH" ]]; then
      OLD_COUNT=$(grep -cE '\b(it|test|expect|assert|should)\b' "$FILE_PATH" 2>/dev/null || echo 0)
      NEW_COUNT=$(echo "$CONTENT" | grep -cE '\b(it|test|expect|assert|should)\b' || echo 0)
      if (( OLD_COUNT > 0 )) && (( NEW_COUNT == 0 )); then
        block "Write to $FILE_PATH removes all assertions ($OLD_COUNT → 0)."
      fi
    fi
    ;;

  Edit|MultiEdit)
    # Edits are partial; defer to PostToolUse audit. Allow.
    exit 0
    ;;
esac

exit 0
