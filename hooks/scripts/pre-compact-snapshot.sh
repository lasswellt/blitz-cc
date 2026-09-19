#!/usr/bin/env bash
# PreCompact hook — snapshot sprint state AND write HANDOFF.json for cross-compaction
# auto-resume. Inspired by GSD's PreCompact→HANDOFF→SessionStart auto-resume loop.
#
# Two artifacts written:
#   .cc-sessions/compact-state.json — sprint-specific snapshot (legacy)
#   .cc-sessions/HANDOFF.json       — generic resume artifact for any in-flight work
#
# session-start.sh consumes HANDOFF.json on next session boot.

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

# Read stdin exactly once; the native session_id arrives here (C9, E-041 S1).
# Env CLAUDE_SESSION_ID is the fallback for manual runs / older harnesses.
INPUT=$(cat 2>/dev/null || echo "{}")
[ -n "$INPUT" ] || INPUT="{}"

mkdir -p .cc-sessions
HANDOFF_FILE=".cc-sessions/HANDOFF.json"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(blitz_extract session_id)
[ -n "$SESSION_ID" ] || SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# --- HANDOFF.json — generic resume artifact (always written) ---
# Captures everything needed to pick up after compaction without the user
# re-explaining context.
# Active plan + task (loop.md): the plan with an in_progress task, else the first active
# plan with open work. tasks.json is read-only here (never written by a hook).
PLAN_FIELD="null"; TASK_FIELD="null"
for tj in docs/plans/*/tasks.json; do
  [ -f "$tj" ] || continue
  t=$(jq -r '[.tasks[] | select(.status=="in_progress")][0].id // empty' "$tj" 2>/dev/null || true)
  if [ -n "$t" ]; then PLAN_FIELD="\"$(basename "$(dirname "$tj")")\""; TASK_FIELD="\"$t\""; break; fi
done
GATE_FIELD="null"
[ -f ".cc-sessions/sessions/${SESSION_ID}/gate.json" ] && GATE_FIELD="\".cc-sessions/sessions/${SESSION_ID}/gate.json\""
PHASE="$(jq -r '.until // "unknown"' ".cc-sessions/sessions/${SESSION_ID}/gate.json" 2>/dev/null || echo "unknown")"
LAST_ACTIVITY="$(tail -1 .cc-sessions/activity-feed.jsonl 2>/dev/null | jq -r '.message // ""' 2>/dev/null || echo "")"

# `(cmd || true)` keeps a failing git/tail from tripping pipefail — otherwise jq's `[]`
# AND the `|| echo '[]'` fallback both print, yielding invalid JSON (HANDOFF unreadable).
UNCOMMITTED_JSON="$( (git status --porcelain 2>/dev/null || true) | jq -R . | jq -sc . 2>/dev/null || echo '[]')"
BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Recent file changes (last 5 from activity feed)
RECENT_FILES="$( (tail -50 .cc-sessions/activity-feed.jsonl 2>/dev/null || true) \
  | jq -sc '[.[] | select(.event=="file_change") | .detail.files // []] | flatten | unique | .[0:10]' 2>/dev/null \
  || echo '[]')"

cat > "$HANDOFF_FILE" <<JSON
{
  "ts": "${TS}",
  "session": "${SESSION_ID}",
  "trigger": "pre-compact",
  "plan": ${PLAN_FIELD},
  "task": ${TASK_FIELD},
  "gate": ${GATE_FIELD},
  "never_edit": ["docs/plans/*/tasks.json (scripts/tasks.sh only)", "docs/plans/*/progress.md (main thread only)"],
  "phase": "${PHASE}",
  "branch": "${BRANCH}",
  "head_sha": "${HEAD_SHA}",
  "uncommitted": ${UNCOMMITTED_JSON},
  "recent_files": ${RECENT_FILES},
  "last_activity": $(jq -Rs . <<< "$LAST_ACTIVITY"),
  "resume_hint": "Compaction fired. Read HANDOFF.json, docs/plans/<plan>/progress.md and git log --grep Task:, restate the in-flight task in ≤3 sentences, keep the gate armed and the never_edit list, then continue."
}
JSON

echo "[blitz:pre-compact] HANDOFF written to ${HANDOFF_FILE}" >&2

# Append handoff event to activity feed (jq-built: session_id / phase are stdin-supplied)
jq -nc --arg ts "$TS" --arg session "$SESSION_ID" --arg phase "$PHASE" --argjson plan "$PLAN_FIELD" --argjson task "$TASK_FIELD" \
  '{ts:$ts,session:$session,skill:"hook",event:"handoff_written",message:"PreCompact handoff captured",detail:{phase:$phase,plan:$plan,task:$task}}' \
  >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true

exit 0
