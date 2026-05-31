#!/usr/bin/env bash
# startup-validate.sh — Persistent-state validation (Gap 1 / TB-2).
#
# Containment: environment-layer startup classifier. Canonical posture:
#   /_shared/threat-model.md §3 TB-2 (persistent .cc-sessions/ state is untrusted across sessions).
# Registry: check-registry.json sec-startup-schema + sec-startup-injection.
#
# WHY: session-protocol.md startup reads ALL .cc-sessions/*.json + activity-feed
# + carry-forward.jsonl into context. An injection landing there is reloaded each
# session and (for carry-forward) auto-injected into the next sprint. This is the
# article's persistent-state poisoning (AP-4) and the memory-poisoning literature's
# temporally-decoupled attack (MINJA arXiv 2601.05504). Per the env-first principle
# (§2), the boundary is this deterministic scan, not "the model will notice".
#
# WHAT: for every persistent-state file, (1) confirm JSON/JSONL parses (schema floor),
# (2) scan free-text field VALUES for injection markers, (3) report findings. Entries
# that fail are surfaced for quarantine — they are NOT silently loaded into context.
#
# Non-blocking by default (exit 0 + surfaced findings) so a single bad entry never
# bricks startup; --strict makes it exit 2 (for CI / audit gate). Quarantine is
# advisory here (surfaces the path); the session-protocol startup step performs the move.
#
# Usage: startup-validate.sh [--strict] [--quiet]
# Exit: 0 = clean OR non-strict; 2 = findings AND --strict.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

STRICT=0; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --quiet) QUIET=1 ;;
  esac
done

ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
[ -d "$SESSIONS_DIR" ] || exit 0
QUARANTINE_DIR="$SESSIONS_DIR/quarantine"

# Injection markers (case-insensitive). Instruction verbs / role directives / tag
# smuggling / tool-invocation strings. URL handling is field-scoped (see below) to
# avoid flagging legitimate incident URLs in activity-feed messages.
INJECTION_RX='(ignore (the )?(previous|above)|you are now|disregard (all|previous|the)|new instructions:|system:|</?(system|tool|assistant|im_start|im_end)>|tool_call|<\|.*\|>|exfiltrat|\.aws/credentials|BEGIN (RSA|OPENSSH|PRIVATE))'

FINDINGS=0
PROV_MISSING=0
OVERLONG=0
report() { FINDINGS=$((FINDINGS+1)); [ "$QUIET" = 1 ] || echo "[startup-validate] $1" >&2; }

# Scan a single JSON object's string values for markers. $1=json, $2=label.
scan_obj() {
  local json="$1" label="$2" vals
  # All string leaf values, one per line.
  vals=$(printf '%s' "$json" | jq -r '[.. | strings] | .[]' 2>/dev/null || true)
  if printf '%s' "$vals" | grep -qiE "$INJECTION_RX"; then
    report "INJECTION MARKER in $label — quarantine candidate: $(printf '%s' "$vals" | grep -ioE "$INJECTION_RX" | head -1)"
    return 1
  fi
  # Over-long free-text field: an uncapped injection SURFACE, not an attack itself.
  # The mitigation is echo-time [0:200] capping (Gap 5 / session-start.sh), so this
  # is advisory — counted, never a hard finding or strict-blocker.
  if printf '%s' "$vals" | awk '{ if (length($0) > 400) exit 1 }'; then : ; else
    OVERLONG=$((OVERLONG+1))
  fi
  return 0
}

# 1. Session JSON files — schema floor + scan.
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if ! jq empty "$f" 2>/dev/null; then
    report "MALFORMED JSON (does not parse) — $base"; continue
  fi
  # Schema floor: a session file must carry session_id + status.
  case "$base" in
    developer-profile.json|model-profiles.json|HANDOFF.json) : ;; # known non-session shapes
    *) jq -e '.session_id and .status' "$f" >/dev/null 2>&1 || report "SCHEMA: $base missing session_id/status" ;;
  esac
  scan_obj "$(cat "$f")" "$base" || true
done

# 2. Carry-forward registry — highest blast radius (drives sprint-plan). Per-line.
CF="$SESSIONS_DIR/carry-forward.jsonl"
if [ -f "$CF" ]; then
  n=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n=$((n+1))
    if ! printf '%s' "$line" | jq empty 2>/dev/null; then
      report "carry-forward.jsonl line $n MALFORMED"; continue
    fi
    scan_obj "$line" "carry-forward.jsonl:$n" || true
    # Provenance floor (S-1): a carry-forward entry should declare source. Migration
    # advisory (pre-S-1 entries lack it) — counted, not a per-line finding, so it
    # never dominates output or blocks --strict.
    printf '%s' "$line" | jq -e '.provenance.source // .source' >/dev/null 2>&1 || \
      PROV_MISSING=$((PROV_MISSING+1))
  done < "$CF"
  [ "$PROV_MISSING" -gt 0 ] && [ "$QUIET" != 1 ] && \
    echo "[startup-validate] $PROV_MISSING carry-forward entr(ies) lack provenance.source (S-1 migration pending; advisory)" >&2 || true
fi

# 3. Activity feed — scan last 50 entries (bounded).
FEED="$SESSIONS_DIR/activity-feed.jsonl"
if [ -f "$FEED" ]; then
  # Process substitution (not a pipe) so report()'s FINDINGS increment survives.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s' "$line" | jq empty 2>/dev/null || continue
    # message is the skill-written free-text field — the injection surface (orchestrator.md:146).
    msg=$(printf '%s' "$line" | jq -r '.message // ""' 2>/dev/null || true)
    if printf '%s' "$msg" | grep -qiE "$INJECTION_RX"; then
      report "INJECTION MARKER in activity-feed message — cap/quarantine before echo"
    fi
  done < <(tail -50 "$FEED" 2>/dev/null)
fi

[ "$OVERLONG" -gt 0 ] && [ "$QUIET" != 1 ] && \
  echo "[startup-validate] $OVERLONG field(s) >400 chars — capped at echo-time per Gap 5 (advisory)" >&2 || true

if [ "$FINDINGS" -gt 0 ]; then
  [ "$QUIET" = 1 ] || echo "[startup-validate] $FINDINGS finding(s). Quarantine suspect entries (mv to $QUARANTINE_DIR/) before loading into context." >&2
  [ "$STRICT" = 1 ] && exit 2
fi
exit 0
