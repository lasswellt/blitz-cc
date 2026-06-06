#!/usr/bin/env bash
# PreToolUse hook on Write|Edit. Blocks insertions of `as any`, `@ts-ignore`, or
# `@ts-nocheck` in non-test TypeScript/Vue source files.
#
# Why: type-system escape hatches accumulate silently, hide real type errors, and
# undermine the type_errors=0 absolute floor in the ratchet. quality-engine.md
# row 4 documents this as a P1/P2 signal.
#
# Escape hatch (per skills/_shared/quality-engine.md §4): inline same-line
# comment `// blitz:any-allowed: <reason>` justifies the use. Without justification
# the edit is blocked.
# Containment: environment-layer guard (model-misbehavior). Canonical posture: /_shared/security.md §2 (env-first).
#
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"

[[ -z "$FILE_PATH" ]] && exit 0

# Only TS/Vue files matter
case "$FILE_PATH" in
  *.ts|*.tsx|*.vue|*.mts|*.cts) ;;
  *) exit 0 ;;
esac

# Test files are exempt — `as any` in test fixtures and mocks is normal
case "$FILE_PATH" in
  *.test.*|*.spec.*|*/__tests__/*|*/test/*|*/tests/*) exit 0 ;;
esac

# User opt-out
[[ "${BLITZ_DISABLE_AS_ANY_BLOCK:-0}" == "1" ]] && exit 0

# Pull the proposed new content for this edit
case "$TOOL" in
  Write)
    NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")"
    ;;
  Edit)
    NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")"
    OLD_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null || echo "")"
    ;;
  MultiEdit)
    # Collect concatenated new_strings for delta scan
    NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")' 2>/dev/null || echo "")"
    OLD_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.old_string // ""] | join("\n")' 2>/dev/null || echo "")"
    ;;
  *) exit 0 ;;
esac

[[ -z "$NEW_CONTENT" ]] && exit 0

# Count escape hatches (`as any`, `@ts-ignore`, `@ts-nocheck`) in new content,
# excluding lines that carry the escape-hatch marker.
count_escapes() {
  local text="$1"
  # `|| true` on each grep — set -o pipefail otherwise propagates 'no match' (exit 1).
  # `grep -c` always prints the count to stdout (even 0); only the exit code differs.
  echo "$text" \
    | { grep -vE '//\s*blitz:any-allowed:' || true; } \
    | { grep -cE '\bas any\b|@ts-ignore|@ts-nocheck' || true; }
}

NEW_COUNT=$(count_escapes "$NEW_CONTENT")

# Compute baseline:
#   Write     → file's prior content (if it existed)
#   Edit      → the old_string only (the rest of the file is unchanged)
#   MultiEdit → all old_strings concatenated
case "$TOOL" in
  Write)
    if [[ -f "$FILE_PATH" ]]; then
      OLD_COUNT=$(count_escapes "$(cat "$FILE_PATH")")
    else
      OLD_COUNT=0
    fi
    ;;
  Edit|MultiEdit)
    OLD_COUNT=$(count_escapes "${OLD_CONTENT:-}")
    ;;
esac

if (( NEW_COUNT > OLD_COUNT )); then
  DELTA=$(( NEW_COUNT - OLD_COUNT ))
  cat >&2 <<EOF
BLOCKED: $DELTA new \`as any\` / @ts-ignore / @ts-nocheck without justification.

File: $FILE_PATH

Type-system escape hatches accumulate silently and hide real type errors. The
ratchet enforces \`type_errors == 0\` as an absolute floor; bypassing it via
\`as any\` undermines the gate.

If this use is genuinely unavoidable (third-party interop, generic constraint
limitations), add an inline justification on the same line:

  const x = thing as any  // blitz:any-allowed: <reason>

The escape hatch is documented in skills/_shared/quality-engine.md §4.
sprint-review Phase 3.6 spot-checks 3 random escape-hatch comments per sprint;
the rationale must survive scrutiny.

Override the entire hook (not recommended): BLITZ_DISABLE_AS_ANY_BLOCK=1
EOF
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [[ -d .cc-sessions ]]; then
    printf '{"ts":"%s","session":"%s","skill":"hook","event":"verification","message":"as-any insertion blocked","detail":{"file":"%s","old":%d,"new":%d}}\n' \
      "$TS" "${CLAUDE_SESSION_ID:-unknown}" "$FILE_PATH" "$OLD_COUNT" "$NEW_COUNT" \
      >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true
  fi
  exit 2
fi

exit 0
