#!/usr/bin/env bash
# PreCompact hook: snapshot loop state into .cc-sessions/HANDOFF.json so the session
# that follows a compaction resumes the same task (sessions.reference.md §7).
# Inspired by GSD's PreCompact -> HANDOFF -> SessionStart auto-resume loop.
#
# session-start.sh surfaces HANDOFF.json on the next boot while it is <=24 h old.
# The document is built with jq -n, never printf or a heredoc: a quote or a
# backslash in a gate label, a branch name or an uncommitted path would otherwise
# leave an unreadable file, and the next session would start without its context.
# tasks.json is read-only here: no hook writes it.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

# Read stdin exactly once; the native session_id arrives here (C9, E-041 S1).
# Env CLAUDE_SESSION_ID is the fallback for manual runs / older harnesses.
INPUT=$(cat 2>/dev/null || echo "{}")
[ -n "$INPUT" ] || INPUT="{}"

ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"
HANDOFF_FILE="$SESSIONS_DIR/HANDOFF.json"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(blitz_extract session_id)
[ -n "$SESSION_ID" ] || SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Active plan + task (loop.md): the plan with an in_progress task, else none.
PLAN=""; TASK=""
for tj in "$ROOT"/docs/plans/*/tasks.json; do
  [ -f "$tj" ] || continue
  t=$(jq -r '[.tasks[]? | select(.status=="in_progress")][0].id // empty' "$tj" 2>/dev/null || true)
  if [ -n "$t" ]; then PLAN=$(basename "$(dirname "$tj")"); TASK="$t"; break; fi
done

# The armed Stop gate, if any: its path (relative, as loop.md documents it) and its
# `until` label as the phase. A session id that is not a safe path component is
# reported as "no gate" rather than used in a path.
GATE=""; PHASE="unknown"
if _blitz_safe_id "$SESSION_ID" && [ -f "$SESSIONS_DIR/sessions/$SESSION_ID/gate.json" ]; then
  GATE=".cc-sessions/sessions/$SESSION_ID/gate.json"
  PHASE=$(jq -r '.until // "unknown"' "$SESSIONS_DIR/sessions/$SESSION_ID/gate.json" 2>/dev/null || echo "unknown")
  [ -n "$PHASE" ] || PHASE="unknown"
fi

FEED="$SESSIONS_DIR/activity-feed.jsonl"
LAST_ACTIVITY=$( (tail -1 "$FEED" 2>/dev/null || true) | jq -r '.message // ""' 2>/dev/null || echo "")
# Recent file changes: the last 50 feed lines, at most 10 paths.
RECENT_FILES=$( (tail -50 "$FEED" 2>/dev/null || true) \
  | jq -sc '[.[] | select(.event=="file_change") | .detail.files // []] | flatten | unique | .[0:10]' 2>/dev/null \
  || echo '[]')
# `(cmd || true)` keeps a failing git from tripping pipefail; jq -R quotes each
# status line, so a path with a quote or a backslash stays one valid string.
UNCOMMITTED=$( (git -C "$ROOT" status --porcelain 2>/dev/null || true) | jq -R . | jq -sc . 2>/dev/null || echo '[]')
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)
HEAD_SHA=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
# Both --argjson inputs must be arrays; a jq failure above would otherwise hand
# jq -n a non-JSON string and the whole document would be lost.
printf '%s' "$RECENT_FILES" | jq -e 'type == "array"' >/dev/null 2>&1 || RECENT_FILES='[]'
printf '%s' "$UNCOMMITTED" | jq -e 'type == "array"' >/dev/null 2>&1 || UNCOMMITTED='[]'

HANDOFF=$(jq -n \
  --arg ts "$TS" --arg session "$SESSION_ID" --arg plan "$PLAN" --arg task "$TASK" \
  --arg gate "$GATE" --arg phase "$PHASE" --arg branch "$BRANCH" --arg head "$HEAD_SHA" \
  --arg last "$LAST_ACTIVITY" --argjson uncommitted "$UNCOMMITTED" --argjson recent "$RECENT_FILES" '
  def opt: if . == "" then null else . end;
  { ts: $ts, session: $session, trigger: "pre-compact",
    plan: ($plan | opt), task: ($task | opt), gate: ($gate | opt),
    never_edit: ["docs/plans/*/tasks.json (scripts/tasks.sh only)", "docs/plans/*/progress.md (main thread only)"],
    phase: $phase, branch: $branch, head_sha: $head,
    uncommitted: $uncommitted, recent_files: $recent, last_activity: $last,
    resume_hint: "Compaction fired. Read HANDOFF.json, docs/plans/<plan>/progress.md and git log --grep Task:, restate the in-flight task in ≤3 sentences, keep the gate armed and the never_edit list, then continue." }')
blitz_atomic_write "$HANDOFF_FILE" "$HANDOFF"$'\n'

echo "[blitz:pre-compact] HANDOFF written to ${HANDOFF_FILE#"$ROOT"/}" >&2

# Feed event (jq-built through blitz_log_event; session_id and phase are stdin- and file-supplied).
blitz_log_event "hook" "handoff_written" "PreCompact handoff captured" \
  "$(jq -nc --arg phase "$PHASE" --arg plan "$PLAN" --arg task "$TASK" \
      '{phase:$phase, plan:($plan | if . == "" then null else . end), task:($task | if . == "" then null else . end)}')"

exit 0
