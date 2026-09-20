#!/usr/bin/env bash
# post-edit-typecheck-block.sh — PostToolUse on Write|Edit. BLOCKING (exit 2).
#
# Runs the project's typecheck command for the edited file's language and
# refuses the edit when the diagnostic count INCREASED against the pre-edit
# baseline. This is the ratchet: it prevents the "rush to completion" failure
# mode where an agent declares done on a broken build.
#
# Language-agnostic. The command, and how to count its diagnostics, come from
# the `typecheck` lane of templates/toolchain.default.json via
# scripts/toolchain.sh. tsc, mypy, cargo check, go build and gradle all emit
# one diagnostic per line, so one counted-lines ratchet covers all of them.
# Before 3.1.0 this hook opened with `[[ -f tsconfig.json ]] || exit 0` and was
# a silent no-op in every non-TypeScript repository.
#
# Containment: environment-layer guard (model-misbehavior).
# Canonical posture: /_shared/security.md §2 (env-first).
#
# Baseline: .cc-sessions/typecheck-baseline.json, schema 2, keyed by toolchain
# row id so a polyglot repo ratchets each language independently and a Python
# edit can never reset the TypeScript floor.
#
# Skips: no resolving row, CI, BLITZ_DISABLE_TYPECHECK_BLOCK=1, file outside
# the row's scope probe.
#
# Exit 0 = allow, Exit 2 = block.
set -uo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT="$(cat)"
FILE_PATH=$(blitz_extract file_path)
[ -z "$FILE_PATH" ] && exit 0

[ "${BLITZ_DISABLE_TYPECHECK_BLOCK:-0}" = "1" ] && exit 0
[ "${CI:-}" = "true" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

TOOLCHAIN="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/toolchain.sh"
[ -f "$TOOLCHAIN" ] || exit 0

ROOT=$(blitz_find_root 2>/dev/null || true)
[ -n "$ROOT" ] && cd "$ROOT" 2>/dev/null || true

ROW=$(bash "$TOOLCHAIN" resolve typecheck "$FILE_PATH" 2>/dev/null || true)
[ -z "$ROW" ] && exit 0

ROW_ID=$(printf '%s' "$ROW" | jq -r '.id // "unknown"')
COUNTER=$(printf '%s' "$ROW" | jq -r '.counter // "lines"')

# Tab-separated argv with {file} substituted, then split on tabs.
_argv() { printf '%s' "$ROW" | jq -r --arg file "$FILE_PATH" --arg k "$1" \
  '(.[$k] // []) | map(if . == "{file}" then $file else . end) | @tsv'; }

# Scope probe: a row may name a command that lists the files its checker
# covers (tsc --listFilesOnly). When the edited file is outside that set the
# check would be noise, so skip. Cheap relative to the full run.
SCOPE_TSV=$(_argv scopeProbe)
if [ -n "$SCOPE_TSV" ]; then
  declare -a SCOPE_ARGV=(); IFS=$'\t' read -r -a SCOPE_ARGV <<< "$SCOPE_TSV"
  if [ "${#SCOPE_ARGV[@]}" -gt 0 ]; then
    BASE_NAME=$(basename "$FILE_PATH")
    if ! "${SCOPE_ARGV[@]}" 2>/dev/null | grep -qF "$BASE_NAME"; then exit 0; fi
  fi
fi

CMD_TSV=$(_argv cmd)
[ -z "$CMD_TSV" ] && exit 0
declare -a CMD_ARGV=(); IFS=$'\t' read -r -a CMD_ARGV <<< "$CMD_TSV"
[ "${#CMD_ARGV[@]}" -eq 0 ] && exit 0

mkdir -p .cc-sessions 2>/dev/null || true
BASELINE_FILE=".cc-sessions/typecheck-baseline.json"
LOCK_FILE="${BASELINE_FILE}.lock"
LOCK_DIR=".cc-sessions/typecheck-baseline.lockdir"

# Concurrency protection for the read-run-write sequence. flock(1) on
# Linux/BSD; mkdir-as-mutex on macOS where flock is not in base install.
TYPECHECK_LOCK_MODE=""
LOCK_HELD=0
acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>>"$LOCK_FILE"
    if flock -w 30 9; then TYPECHECK_LOCK_MODE="flock"; LOCK_HELD=1; return 0; fi
    return 1
  fi
  local waited=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    [ "$waited" -ge 30 ] && return 1
    sleep 1; waited=$((waited + 1))
  done
  TYPECHECK_LOCK_MODE="mkdir"; LOCK_HELD=1; return 0
}
release_lock() {
  [ "$LOCK_HELD" -eq 0 ] && return 0
  if [ "$TYPECHECK_LOCK_MODE" = "flock" ]; then flock -u 9 2>/dev/null || true
  else rmdir "$LOCK_DIR" 2>/dev/null || true; fi
  LOCK_HELD=0
}
TMP_BASELINE=""
cleanup() {
  [ -n "$TMP_BASELINE" ] && [ -f "$TMP_BASELINE" ] && rm -f "$TMP_BASELINE"
  release_lock
}
trap cleanup EXIT INT TERM
if ! acquire_lock; then
  echo "[typecheck-block] lock acquisition timed out, skipping" >&2
  exit 0
fi

OUT=$("${CMD_ARGV[@]}" 2>&1)

# Count diagnostics. `regex:<ERE>` counts matching lines; `lines` counts
# non-empty lines. The ERE comes from the plugin-shipped table, never from the
# checkout (security.md TB-1).
case "$COUNTER" in
  regex:*)
    RX="${COUNTER#regex:}"
    NEW_COUNT=$(printf '%s\n' "$OUT" | grep -cE -- "$RX" 2>/dev/null || true) ;;
  lines|*)
    NEW_COUNT=$(printf '%s\n' "$OUT" | grep -c '[^[:space:]]' 2>/dev/null || true) ;;
esac
NEW_COUNT=${NEW_COUNT:-0}
case "$NEW_COUNT" in ''|*[!0-9]*) NEW_COUNT=0 ;; esac

# Read the prior baseline for THIS row. Schema 2 is keyed by row id; a
# schema-1 file carried a single bare error_count, which belonged to tsc.
# Starts EMPTY, not 0: empty means "no floor recorded for this lane yet", and
# the FIRST_RUN branch below records the floor instead of blocking. Defaulting
# to 0 here (as this hook did before 3.1.0) made the first edit in any repo
# with pre-existing diagnostics an automatic block over errors it did not cause.
OLD_COUNT=""
if [ -f "$BASELINE_FILE" ]; then
  SV=$(jq -r '.schema_version // 1' "$BASELINE_FILE" 2>/dev/null || echo 1)
  if [ "$SV" = "2" ]; then
    OLD_COUNT=$(jq -r --arg id "$ROW_ID" '.lanes[$id].error_count // empty' "$BASELINE_FILE" 2>/dev/null || echo "")
  else
    case "$ROW_ID" in
      node-tsc|node-vue-tsc) OLD_COUNT=$(jq -r '.error_count // empty' "$BASELINE_FILE" 2>/dev/null || echo "") ;;
      *) OLD_COUNT="" ;;
    esac
  fi
fi

# No baseline for this lane yet: record the current count as the floor and
# allow. Blocking on the first edit would refuse work over pre-existing
# errors the edit did not cause.
FIRST_RUN=0
if [ -z "$OLD_COUNT" ]; then FIRST_RUN=1; OLD_COUNT="$NEW_COUNT"; fi
case "$OLD_COUNT" in ''|*[!0-9]*) OLD_COUNT=0 ;; esac

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$FIRST_RUN" -eq 0 ] && [ "$NEW_COUNT" -gt "$OLD_COUNT" ]; then
  DELTA=$((NEW_COUNT - OLD_COUNT))
  SAMPLE=$(case "$COUNTER" in
    regex:*) printf '%s\n' "$OUT" | grep -E -- "${COUNTER#regex:}" 2>/dev/null | head -5 ;;
    *)       printf '%s\n' "$OUT" | grep '[^[:space:]]' 2>/dev/null | head -5 ;;
  esac)
  cat >&2 <<EOF
BLOCKED: typecheck regression after edit to $FILE_PATH.

Checker: $ROW_ID. Baseline: $OLD_COUNT diagnostic(s). After your edit: $NEW_COUNT. Delta: +$DELTA.

First few new diagnostics:
$SAMPLE

Fix them in this same edit, or revert and try a different approach. The build
must remain green. To temporarily bypass (not recommended):
  BLITZ_DISABLE_TYPECHECK_BLOCK=1
EOF
  DET=$(jq -nc --arg f "$FILE_PATH" --arg id "$ROW_ID" --argjson o "$OLD_COUNT" --argjson n "$NEW_COUNT" \
    '{file:$f, checker:$id, old:$o, new:$n}')
  blitz_log_event "hook" "verification" "typecheck regression blocked" "$DET" 2>/dev/null || true
  exit 2
fi

# No regression (or first run): record this lane's floor atomically. The
# schema_version + complete sentinel means an interrupted write cannot leave a
# 0-byte file whose next read defaults to 0 and silently resets the ratchet.
EXISTING='{"schema_version":2,"lanes":{}}'
if [ -f "$BASELINE_FILE" ]; then
  CUR=$(jq -c 'if (.schema_version // 1) == 2 then . else {schema_version:2, lanes:{}} end' "$BASELINE_FILE" 2>/dev/null || echo "")
  [ -n "$CUR" ] && EXISTING="$CUR"
fi
TMP_BASELINE=$(mktemp -p "$(dirname "$BASELINE_FILE")" .baseline.XXXXXX 2>/dev/null) || { release_lock; exit 0; }
# jq --arg guarantees escaping: a path with quotes, backslashes or newlines
# would otherwise corrupt the file and the next read would reset the floor.
printf '%s' "$EXISTING" | jq --arg id "$ROW_ID" --argjson ec "$NEW_COUNT" --arg ts "$TS" --arg ft "$FILE_PATH" \
  '.schema_version = 2
   | .complete = true
   | .updated = $ts
   | .lanes[$id] = {error_count: $ec, updated: $ts, file_trigger: $ft}' > "$TMP_BASELINE" 2>/dev/null \
  && mv "$TMP_BASELINE" "$BASELINE_FILE" || rm -f "$TMP_BASELINE"
TMP_BASELINE=""

release_lock
exit 0
