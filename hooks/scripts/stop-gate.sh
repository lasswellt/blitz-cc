#!/usr/bin/env bash
# stop-gate.sh — Conditional deterministic verification gate (Stop event, E-042 S1)
#
# Strict no-op unless a sprint or loop has written a gate file:
#   .cc-sessions/sessions/<session_id>/gate.json
#   { "checks": [ {"name": "tsc", "cmd": "npx tsc --noEmit", "timeout": 120}, ... ],
#     "blocks": 0, "max_blocks": 6, "until": "<phase label>" }
#
# When the gate is armed, every check runs in order; the first failure blocks
# the turn from ending (exit 2, reason on stderr with a 200-char tail of the
# failing check's output) and increments `blocks`. When every check passes,
# `blocks` resets to 0 and the turn ends normally.
#
# The gate stands down (exit 0) when:
#   - no gate file exists for this session
#   - stdin `stop_hook_active` is true (Claude Code re-entered after a block)
#   - `last_assistant_message` carries a terminal marker
#     (LOOP_DONE | LOOP_ESCALATE | LOOP_DEFER | BLOCKED: | ESCALATE:)
#   - blocks >= max_blocks (logged as `gate_exhausted`; the platform's own
#     cap is 8 consecutive blocks — max_blocks defaults to 6 so blitz never
#     reaches it)
#
# Never wire a prompt-type Stop hook alongside this one: a user `/goal` is
# itself a prompt-based Stop hook and the two would fight. Owner of the
# verification-stack contract: /_shared/quality.md §Verification stack.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)
_blitz_safe_id "$SESSION_ID" || exit 0

GATE="$SESSIONS_DIR/sessions/$SESSION_ID/gate.json"
[ -f "$GATE" ] || exit 0
jq -e '.checks | type == "array"' "$GATE" >/dev/null 2>&1 || {
  blitz_log_event "hook" "warning" "gate.json malformed; gate stands down" "$(jq -nc --arg p "$GATE" '{path:$p}')"
  exit 0
}

# Re-entry after a block: never block twice in a row without a new turn.
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

# Terminal markers: the skill has already declared an outcome; do not trap it.
LAST=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null | tail -c 4000)
if printf '%s' "$LAST" | grep -qE 'LOOP_DONE|LOOP_ESCALATE|LOOP_DEFER|BLOCKED:|ESCALATE:'; then
  exit 0
fi

BLOCKS=$(jq -r '.blocks // 0' "$GATE")
MAX=$(jq -r '.max_blocks // 6' "$GATE")
case "$BLOCKS$MAX" in *[!0-9]*) BLOCKS=0; MAX=6 ;; esac
if [ "$MAX" -gt 7 ]; then MAX=7; fi   # stay under the platform's 8-consecutive cap
if [ "$BLOCKS" -ge "$MAX" ]; then
  blitz_log_event "hook" "gate_exhausted" "Stop gate exhausted after $BLOCKS blocks; standing down" \
    "$(jq -nc --arg u "$(jq -r '.until // ""' "$GATE")" --argjson b "$BLOCKS" '{until:$u,blocks:$b}')"
  exit 0
fi

# Run checks in order; first failure blocks.
N=$(jq -r '.checks | length' "$GATE")
i=0
while [ "$i" -lt "$N" ]; do
  NAME=$(jq -r ".checks[$i].name // \"check-$i\"" "$GATE")
  CMD=$(jq -r ".checks[$i].cmd // \"\"" "$GATE")
  TMO=$(jq -r ".checks[$i].timeout // 120" "$GATE")
  case "$TMO" in *[!0-9]*|"") TMO=120 ;; esac
  i=$((i + 1))
  [ -n "$CMD" ] || continue
  OUT_FILE=$(mktemp)
  RC=0
  ( cd "$ROOT" && timeout "$TMO" bash -c "$CMD" ) >"$OUT_FILE" 2>&1 || RC=$?
  if [ "$RC" -ne 0 ]; then
    TAIL=$(tail -c 200 "$OUT_FILE" | tr '\n' ' ')
    rm -f "$OUT_FILE"
    NEXT=$((BLOCKS + 1))
    blitz_atomic_write "$GATE" "$(jq --argjson b "$NEXT" '.blocks = $b | .last_failed = $name' --arg name "$NAME" "$GATE")"
    blitz_log_event "hook" "gate_block" "Stop gate: $NAME failed (rc=$RC), block $NEXT/$MAX" \
      "$(jq -nc --arg n "$NAME" --argjson rc "$RC" --argjson b "$NEXT" '{check:$n,rc:$rc,blocks:$b}')"
    printf 'blitz stop-gate: check "%s" failed (rc=%s, block %s/%s). Fix it before ending the turn. Tail: %s\n' \
      "$NAME" "$RC" "$NEXT" "$MAX" "$TAIL" >&2
    exit 2
  fi
  rm -f "$OUT_FILE"
done

if [ "$BLOCKS" -ne 0 ]; then
  blitz_atomic_write "$GATE" "$(jq '.blocks = 0 | del(.last_failed)' "$GATE")"
fi
blitz_log_event "hook" "gate_pass" "Stop gate: all $N checks passed" "$(jq -nc --argjson n "$N" '{checks:$n}')"
exit 0
