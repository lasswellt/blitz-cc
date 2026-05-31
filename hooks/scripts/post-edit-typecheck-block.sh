#!/usr/bin/env bash
# PostToolUse hook on Write|Edit for TypeScript/Vue files.
# Runs incremental tsc and BLOCKS (exit 2) if the type-error count INCREASED
# vs the pre-edit baseline stored in .cc-sessions/typecheck-baseline.json.
#
# Why blocking: post-edit-test.sh always exits 0 (advisory). This hook actively
# rejects edits that introduce type errors, preventing the "rush to completion"
# failure mode where agents declare done on a broken build.
# Containment: environment-layer guard (model-misbehavior). Canonical posture: /_shared/threat-model.md §2 (env-first).
#
# Skip conditions: no tsconfig.json (not a TS project), CI env, BLITZ_DISABLE_TYPECHECK_BLOCK=1,
#   edited file not in tsconfig include scope.
#
# Concurrency: read/tsc/write sequence is wrapped in flock on
#   .cc-sessions/typecheck-baseline.json.lock. Baseline write is atomic (tmp+mv).
#
# Exit 0 = allow / pass-through, Exit 2 = block (regression).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"

[[ -z "$FILE_PATH" ]] && exit 0

# Only TS/Vue files matter
case "$FILE_PATH" in
  *.ts|*.tsx|*.vue|*.mts|*.cts) ;;
  *) exit 0 ;;
esac

# Skip if no TS project
[[ -f tsconfig.json ]] || exit 0

# User opt-out
[[ "${BLITZ_DISABLE_TYPECHECK_BLOCK:-0}" == "1" ]] && exit 0

# CI guard: don't double-run in CI
[[ "${CI:-}" == "true" ]] && exit 0

# Need npx
command -v npx >/dev/null 2>&1 || exit 0

# Detect tsc variant (vue-tsc when available, else tsc)
TSC_CMD="tsc"
if command -v vue-tsc >/dev/null 2>&1 || \
   (npx --no-install vue-tsc --version >/dev/null 2>&1); then
  TSC_CMD="vue-tsc"
fi

# Scope filter: skip if file not in tsconfig include set.
# --listFilesOnly is fast (~200ms) and avoids the full 2-8s typecheck when out of scope.
if ! npx --no-install "$TSC_CMD" --listFilesOnly 2>/dev/null | grep -qF "$FILE_PATH"; then
  exit 0
fi

mkdir -p .cc-sessions
BASELINE_FILE=".cc-sessions/typecheck-baseline.json"
LOCK_FILE="${BASELINE_FILE}.lock"
LOCK_DIR=".cc-sessions/typecheck-baseline.lockdir"

# Concurrency protection for the read-tsc-write sequence.
# Prefer flock(1) on Linux/BSD; fall back to mkdir-as-mutex on macOS where flock
# is not in base install. 30s timeout on either path.
TYPECHECK_LOCK_MODE=""
LOCK_HELD=0
acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>>"$LOCK_FILE"
    if flock -w 30 9; then
      TYPECHECK_LOCK_MODE="flock"
      LOCK_HELD=1
      return 0
    fi
    return 1
  fi
  local waited=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    [[ "$waited" -ge 30 ]] && return 1
    sleep 1
    waited=$((waited + 1))
  done
  TYPECHECK_LOCK_MODE="mkdir"
  LOCK_HELD=1
  return 0
}
release_lock() {
  [[ "$LOCK_HELD" -eq 0 ]] && return 0
  if [[ "$TYPECHECK_LOCK_MODE" = "flock" ]]; then
    flock -u 9 2>/dev/null || true
  else
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  LOCK_HELD=0
}
TMP_BASELINE=""
cleanup() {
  [[ -n "$TMP_BASELINE" && -f "$TMP_BASELINE" ]] && rm -f "$TMP_BASELINE"
  release_lock
}
trap cleanup EXIT INT TERM
if ! acquire_lock; then
  echo "[typecheck-block] lock acquisition timed out, skipping" >&2
  exit 0
fi

# Run incremental tsc; capture error count
TSC_OUTPUT=$(npx --no-install "$TSC_CMD" --incremental --noEmit --pretty false 2>&1 || true)
NEW_COUNT=$(echo "$TSC_OUTPUT" | grep -cE '^[^:]+\.(ts|tsx|vue|mts|cts).*error TS' || true)
NEW_COUNT=${NEW_COUNT:-0}

# Read prior baseline (default 0 if missing)
OLD_COUNT=0
if [[ -f "$BASELINE_FILE" ]]; then
  OLD_COUNT=$(jq -r '.error_count // 0' "$BASELINE_FILE" 2>/dev/null || echo 0)
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if (( NEW_COUNT > OLD_COUNT )); then
  # Regression: refuse the edit, show the user what broke.
  DELTA=$((NEW_COUNT - OLD_COUNT))
  cat >&2 <<EOF
BLOCKED: type-error regression after edit to $FILE_PATH.

Baseline: $OLD_COUNT errors. After your edit: $NEW_COUNT errors. Delta: +$DELTA.

First few new errors:
$(echo "$TSC_OUTPUT" | grep -E '^[^:]+\.(ts|tsx|vue|mts|cts).*error TS' | head -5)

Fix the type errors in this same edit, or revert and try a different approach.
The build must remain green. To temporarily bypass (not recommended):
  BLITZ_DISABLE_TYPECHECK_BLOCK=1
EOF
  # Log the rejection
  if [[ -f .cc-sessions/activity-feed.jsonl ]]; then
    printf '{"ts":"%s","session":"%s","skill":"hook","event":"verification","message":"typecheck regression blocked","detail":{"file":"%s","old":%d,"new":%d}}\n' \
      "$TS" "${CLAUDE_SESSION_ID:-unknown}" "$FILE_PATH" "$OLD_COUNT" "$NEW_COUNT" \
      >> .cc-sessions/activity-feed.jsonl
  fi
  exit 2
fi

# No regression: update baseline atomically (tmp + mv).
# Includes a schema_version + integrity sentinel so an interrupted write does
# not leave a 0-byte file that silently resets the ratchet floor.
TMP_BASELINE=$(mktemp -p "$(dirname "$BASELINE_FILE")" .baseline.XXXXXX)
# Use jq -n --arg/--argjson to guarantee JSON escaping. Filenames containing
# quotes/backslashes/newlines would otherwise corrupt the file and the next
# `jq -r '.error_count // 0'` read defaults to 0 — silently resetting the
# ratchet floor.
jq -n --argjson sv 1 --argjson ec "$NEW_COUNT" --arg ts "$TS" --arg ft "$FILE_PATH" \
  '{schema_version: $sv, error_count: $ec, updated: $ts, file_trigger: $ft, complete: true}' \
  > "$TMP_BASELINE"
mv "$TMP_BASELINE" "$BASELINE_FILE"
TMP_BASELINE=""

release_lock
exit 0
