#!/usr/bin/env bash
# shellcheck source=_lib/common.sh
# session-start.sh — Initialize session context on SessionStart hook
# 1. Owns the session record (.cc-sessions/sessions/<session_id>.json, E-041 S1):
#    created from stdin fields on a fresh start; reopened (status active,
#    state working, skill/working_on/locks kept) on source=resume|compact.
#    Logs feed event `session_start` with session=<native session_id>.
# 2. Surfaces HANDOFF.json, echoes the sanitized recent feed, resets the
#    context counter.
# 3. Stale-session cleanup via blitz_session_stale (canonical + legacy records):
#    status failed / failed_reason stale_session_cleanup, owned locks released,
#    feed `warning`.
# Non-blocking: always exits 0. Tolerates empty stdin (older CC, manual runs).

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
[ -n "$INPUT" ] || INPUT="{}"
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR" "$SESSIONS_DIR/sessions"

# --- Session record (hook-owned; skills PATCH skill/working_on/args later) ---
SESSION_ID=$(blitz_extract session_id)
SOURCE=$(blitz_extract source)          # SessionStart matcher value: startup|resume|clear|compact|fork
[ -n "$SOURCE" ] || SOURCE="startup"
if [ -n "$SESSION_ID" ] && RECORD=$(blitz_session_record_path "$SESSION_ID"); then
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  CWD=$(blitz_extract cwd); [ -n "$CWD" ] || CWD="$(pwd)"
  EFFORT=$(printf '%s' "$INPUT" | jq -r '.effort.level // .effort // empty' 2>/dev/null || true)
  if [ -f "$RECORD" ] && { [ "$SOURCE" = "resume" ] || [ "$SOURCE" = "compact" ]; }; then
    # Reopen: keep skill / working_on / args / locks_held from the prior life.
    blitz_session_update "$SESSION_ID" \
      ".status = \"active\" | .state = \"working\" | .last_activity = \$now | .source = $(jq -n --arg s "$SOURCE" '$s') | del(.ended) | del(.failed_reason)"
  elif [ ! -f "$RECORD" ] || ! jq -e . "$RECORD" >/dev/null 2>&1; then
    NEW_RECORD=$(jq -nc \
      --arg sid "$SESSION_ID" --arg cwd "$CWD" --arg now "$NOW_ISO" \
      --arg tp "$(blitz_extract transcript_path)" --arg sp "$(blitz_extract scratchpad_dir)" \
      --arg pm "$(blitz_extract permission_mode)" --arg ef "$EFFORT" \
      --arg at "$(blitz_extract agent_type)" --arg src "$SOURCE" \
      '{session_id:$sid, harness:"claude", cwd:$cwd, dirs:[], started:$now, last_activity:$now,
        status:"active", state:"working", skill:null, working_on:null, args:null, locks_held:[],
        transcript_path:(if $tp=="" then null else $tp end),
        scratchpad_dir:(if $sp=="" then null else $sp end),
        permission_mode:(if $pm=="" then null else $pm end),
        effort:(if $ef=="" then null else $ef end),
        agent_type:(if $at=="" then null else $at end), source:$src}' 2>/dev/null || true)
    [ -n "$NEW_RECORD" ] && blitz_atomic_write "$RECORD" "$NEW_RECORD" 2>/dev/null || true
  else
    # Record exists on a non-resume start (clear/fork/startup replay): mark it live again.
    blitz_session_update "$SESSION_ID" \
      ".status = \"active\" | .state = \"working\" | .last_activity = \$now | .source = $(jq -n --arg s "$SOURCE" '$s')"
  fi
  blitz_log_event "hook" "session_start" "Session started (${SOURCE})" \
    "$(jq -nc --arg src "$SOURCE" --arg cwd "$CWD" '{source:$src,cwd:$cwd}')"
fi

# --- Containment: pre-trust field sanitization (TB-1, AP-1) ---
# This hook runs at SessionStart and echoes project-local .cc-sessions/ fields into
# Claude's context. Those files are UNTRUSTED inbound data (a cloned repo controls them),
# so every echoed free-text field is capped at 200 chars (parity with orchestrator.md:146)
# and injection-scanned — replaced with a quarantine marker on a hit. This hook NEVER
# eval/sources project-controlled content; it only parses (jq) and echoes sanitized text.
# Canonical posture: /_shared/security.md §3 TB-1 + /_shared/security.md.
# Canonical injection pattern lives in _lib/common.sh (BLITZ_INJECTION_RX) so the
# live echo path here and startup-validate.sh's persistent-state scan never drift (SEC-R2-03).
sanitize() {
  local s; s=$(cut -c1-200)
  if printf '%s' "$s" | grep -qiE "$BLITZ_INJECTION_RX"; then
    printf '[quarantined: suspicious field — see startup-validate.sh]'
  else
    printf '%s' "$s"
  fi
}

# --- HANDOFF.json auto-resume detection ---
# If a recent PreCompact wrote HANDOFF.json, surface it so Claude resumes
# the in-flight task instead of starting fresh.
HANDOFF="$SESSIONS_DIR/HANDOFF.json"
if [ -f "$HANDOFF" ]; then
  HANDOFF_AGE_SEC=$(( $(date +%s) - $(stat -c %Y "$HANDOFF" 2>/dev/null || stat -f %m "$HANDOFF" 2>/dev/null || echo 0) ))
  # Surface only if HANDOFF.json is fresh (≤24h). Older = stale, ignore.
  if [ "$HANDOFF_AGE_SEC" -le 86400 ]; then
    HANDOFF_PHASE=$(jq -r '.phase // "unknown"' "$HANDOFF" 2>/dev/null | sanitize || echo "unknown")
    HANDOFF_SPRINT=$(jq -r '.sprint // "none"' "$HANDOFF" 2>/dev/null | sanitize || echo "none")
    HANDOFF_BRANCH=$(jq -r '.branch // "unknown"' "$HANDOFF" 2>/dev/null | sanitize || echo "unknown")
    HANDOFF_UNCOMMITTED_COUNT=$(jq -r '.uncommitted | length' "$HANDOFF" 2>/dev/null || echo 0)
    HANDOFF_LAST=$(jq -r '.last_activity // ""' "$HANDOFF" 2>/dev/null | sanitize || echo "")
    cat <<EOF
[blitz] HANDOFF detected (compaction-resume artifact):
  sprint:      $HANDOFF_SPRINT
  phase:       $HANDOFF_PHASE
  branch:      $HANDOFF_BRANCH
  uncommitted: $HANDOFF_UNCOMMITTED_COUNT files
  last action: $HANDOFF_LAST

To continue prior work: read .cc-sessions/HANDOFF.json (full context), then
restate the in-flight task in ≤3 sentences and resume from the next dispatch.
To start fresh instead: archive HANDOFF.json (mv .cc-sessions/HANDOFF.json{,.archived-\$(date +%s)}).
EOF
  fi
fi

# Display recent activity (last 10 entries)
FEED="$SESSIONS_DIR/activity-feed.jsonl"
if [ -f "$FEED" ] && [ -s "$FEED" ]; then
  LINES=$(tail -10 "$FEED" 2>/dev/null || true)
  if [ -n "$LINES" ]; then
    echo "[blitz] Recent activity:"
    echo "$LINES" | while IFS= read -r line; do
      SESSION=$(echo "$line" | grep -o '"session":"[^"]*"' | head -1 | sed 's/"session":"//;s/"$//' | sanitize || true)
      MSG=$(echo "$line" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//' | sanitize || true)
      SKILL=$(echo "$line" | grep -o '"skill":"[^"]*"' | head -1 | sed 's/"skill":"//;s/"$//' | sanitize || true)
      [ -n "$MSG" ] && echo "  [$SESSION] $SKILL: $MSG"
    done
  fi
fi

# Reset the per-session context-utilization counter so warnings track THIS session.
# (Without this reset, the monotonic counter accumulates across sessions and stays
# above the 80% threshold forever after any long session.)
echo 0 > "$SESSIONS_DIR/context-char-count" 2>/dev/null || true

# --- Stale-session cleanup (E-041 S1) ---
# Rule lives in blitz_session_stale (common.sh): last_activity > 30 min with no
# working|blocked overlay row, or started > 4 h with no overlay row at all.
# Covers canonical records (sessions/<sid>.json) AND legacy skill-minted
# records (.cc-sessions/<skill>-<hex>.json) for backward compatibility.
# Stale → status failed, failed_reason stale_session_cleanup, owned locks
# released (ownership grep guard, same as session-end.sh), feed `warning`.
AGENT_VIEW=$(blitz_agent_view 2>/dev/null || true)
for f in "$SESSIONS_DIR"/sessions/*.json "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  [ "$(jq -r '.status // empty' "$f" 2>/dev/null)" = "active" ] || continue
  SID=$(jq -r '.session_id // .claude_session_id // empty' "$f" 2>/dev/null || true)
  [ -n "$SID" ] || SID=$(basename "$f" .json)
  [ -n "$SESSION_ID" ] && [ "$SID" = "$SESSION_ID" ] && continue
  blitz_session_stale "$f" "$AGENT_VIEW" || continue
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  UPDATED=$(jq -c --arg now "$NOW_ISO" \
    '.status = "failed" | .failed_reason = "stale_session_cleanup" | .state = "ended" | .ended = $now' \
    "$f" 2>/dev/null || true)
  [ -n "$UPDATED" ] && blitz_atomic_write "$f" "$UPDATED" 2>/dev/null || true
  RELEASED=0
  while IFS= read -r lock; do
    [ -f "$lock" ] || continue
    if grep -qF -- "$SID" "$lock" 2>/dev/null; then
      rm -f "$lock" 2>/dev/null && RELEASED=$((RELEASED + 1))
    fi
  done < <(find "$SESSIONS_DIR" -type f -name '*.lock' 2>/dev/null || true)
  SAFE_SID=$(printf '%s' "$SID" | sanitize)
  echo "[blitz] WARNING: Stale session cleaned up: ${SAFE_SID} (status failed, ${RELEASED} lock(s) released)"
  blitz_log_event "hook" "warning" "Stale session ${SAFE_SID} marked failed (stale_session_cleanup)" \
    "$(jq -nc --arg sid "$SID" --argjson rel "$RELEASED" --arg rec "${f#"$ROOT"/}" '{session:$sid,locks_released:$rel,record:$rec,reason:"stale_session_cleanup"}')"
done

exit 0
