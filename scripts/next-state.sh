#!/usr/bin/env bash
# next-state.sh — deterministic Observe step for /blitz:next (loop.md §next rows).
# Prints one JSON object and exits 0. Never writes anything.
#
#   {
#     "row": 0..5,                 // decision row per loop.md; tie-break 0 > 1 > 2 > 3 > 4 > 5
#     "reason": "<one line>",
#     "active_plan": "<slug>|null", "plan_priority": N,
#     "next_task": {id,title,role,files,verify,attempts} | null,
#     "in_progress": [id...], "blocked": [{plan,id,reason}], "escalate": [{plan,id,reason}],
#     "paused_plans": [slug...], "done_plans_unarchived": [slug...],
#     "check_stale": bool, "check_result": "PASS|CONDITIONAL|FAIL|none",
#     "inbox_pending": N, "sessions_waiting": N, "kill_switch": bool
#   }
#
# Usage: next-state.sh [--plans-dir DIR] [--sessions-dir DIR] [--no-agent-view]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/scripts/_lib/common.sh
. "$SCRIPT_DIR/../hooks/scripts/_lib/common.sh" 2>/dev/null || true

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PLANS_DIR="${BLITZ_PLANS_DIR:-$ROOT/docs/plans}"
SESSIONS_DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
USE_AGENT_VIEW=1
while [ $# -gt 0 ]; do
  case "$1" in
    --plans-dir) PLANS_DIR="$2"; shift 2;;
    --sessions-dir) SESSIONS_DIR="$2"; shift 2;;
    --no-agent-view) USE_AGENT_VIEW=0; shift;;
    *) echo "next-state.sh: unknown flag $1" >&2; exit 2;;
  esac
done

fm_field() {  # fm_field <file> <key> — YAML frontmatter scalar, unquoted
  [ -f "$1" ] || return 0
  awk -v k="$2" 'NR==1 && $0 != "---" {exit} NR>1 && $0=="---" {exit} NR>1 && index($0, k":")==1 {sub("^" k ":[ ]*",""); gsub(/^"|"$/,""); print; exit}' "$1"
}
report_result() {  # report_result <plan-dir>
  local r; r=$(fm_field "$1/check-report.md" result)
  if [ -z "$r" ] && [ -f "$1/check-report.md" ]; then r=$(grep -m1 -oE '\b(PASS|CONDITIONAL|FAIL)\b' "$1/check-report.md" || true); fi
  printf '%s' "${r:-none}"
}

kill_switch=false; [ -f "$SESSIONS_DIR/STOP" ] && kill_switch=true
inbox_pending=0
if [ -f "$SESSIONS_DIR/inbox.jsonl" ]; then
  inbox_pending=$(jq -sc '[.[] | select(.status == "pending")] | length' "$SESSIONS_DIR/inbox.jsonl" 2>/dev/null || echo 0)
fi
sessions_waiting=0
if [ "$USE_AGENT_VIEW" -eq 1 ] && command -v claude >/dev/null 2>&1 && declare -F blitz_agent_view >/dev/null; then
  sessions_waiting=$(blitz_agent_view 2>/dev/null | jq -sc '[.[] | select((.waitingFor // null) != null)] | length' 2>/dev/null || echo 0)
fi
case "$inbox_pending$sessions_waiting" in *[!0-9]*) inbox_pending=0; sessions_waiting=0;; esac

# Scan plans
plans_json='[]'
if [ -d "$PLANS_DIR" ]; then
  for d in "$PLANS_DIR"/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    [ "$slug" = "archive" ] && continue
    [ -f "$d/tasks.json" ] || continue
    status=$(fm_field "$d/spec.md" status); [ -n "$status" ] || status="active"
    prio=$(fm_field "$d/spec.md" priority)
    case "$prio" in P0|p0) prio=0;; P1|p1) prio=1;; P2|p2) prio=2;; ''|*[!0-9]*) prio=100;; esac
    result=$(report_result "$d")
    updated=$(jq -r '.updated // ""' "$d/tasks.json" 2>/dev/null)
    rts=$(fm_field "$d/check-report.md" ts)
    stale=true
    if [ "$result" = "PASS" ] && [ -n "$rts" ] && [ "$rts" \> "$updated" ]; then stale=false; fi
    row=$(jq -c --arg slug "$slug" --arg status "$status" --argjson prio "$prio" --arg result "$result" --argjson stale "$stale" '
      {slug:$slug, status:$status, priority:$prio, check_result:$result, check_stale:$stale,
       tasks:.tasks,
       done:(.tasks | map(select(.status=="done") | .id)),
       in_progress:[.tasks[] | select(.status=="in_progress") | .id],
       blocked:[.tasks[] | select(.status=="blocked") | {id, reason:(.blocked_reason // "unknown")}],
       open_ready:([.tasks[] | select(.status=="open")] as $open | (.tasks | map(select(.status=="done") | .id)) as $done
                   | [$open[] | select(all(.depends_on[]?; . as $x | $done | index($x) != null))] | map({id,title,role,files,verify,attempts})),
       all_done:((.tasks | length) > 0 and all(.tasks[]; .status=="done"))}' "$d/tasks.json" 2>/dev/null) || continue
    plans_json=$(printf '%s' "$plans_json" | jq -c --argjson r "$row" '. + [$r]')
  done
fi

jq -nc --argjson plans "$plans_json" --argjson inbox "$inbox_pending" --argjson waiting "$sessions_waiting" --argjson kill "$kill_switch" '
  ($plans | map(select(.status=="active")) | sort_by(.priority, .slug)) as $active
  | ([$active[] | .blocked[] as $b | {plan:.slug, id:$b.id, reason:$b.reason}]) as $blocked
  | ([$blocked[] | select(.reason | IN("hard_spec","oracle-underivable","test-assertion-suspect"))]) as $escalate
  | ([$active[] | select((.in_progress | length) > 0 or (.open_ready | length) > 0)] | .[0]) as $work
  | ([$active[] | select(.all_done and .check_stale)] | .[0]) as $needs_check
  | ([$active[] | select(.all_done and (.check_stale | not) and .check_result == "PASS")] | .[0]) as $verified
  | {
      kill_switch: $kill, inbox_pending: $inbox, sessions_waiting: $waiting,
      paused_plans: [$plans[] | select(.status=="paused") | .slug],
      done_plans_unarchived: [$plans[] | select(.status=="done") | .slug],
      blocked: $blocked, escalate: $escalate
    }
  | if $kill then . + {row:0, reason:"kill switch .cc-sessions/STOP present", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif ($inbox > 0 or $waiting > 0) then . + {row:0, reason:"inbox pending or a session is waiting for input", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif ($escalate | length) > 0 then . + {row:1, reason:"blocked task needs a human: \($escalate[0].plan)/\($escalate[0].id) (\($escalate[0].reason))", active_plan:$escalate[0].plan, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif $work != null then . + {row:2, reason:"open work in \($work.slug)", active_plan:$work.slug, plan_priority:$work.priority,
          next_task:(if ($work.in_progress | length) > 0 then ($work.tasks[] | select(.id == $work.in_progress[0]) | {id,title,role,files,verify,attempts}) else $work.open_ready[0] end),
          in_progress:$work.in_progress, check_stale:$work.check_stale, check_result:$work.check_result}
    elif $needs_check != null then . + {row:3, reason:"all tasks done in \($needs_check.slug); check report missing, stale, or not PASS", active_plan:$needs_check.slug, plan_priority:$needs_check.priority, next_task:null, in_progress:[], check_stale:true, check_result:$needs_check.check_result}
    elif $verified != null then . + {row:4, reason:"\($verified.slug) verified PASS; mark done, learn, archive; ship is slash-only", active_plan:$verified.slug, plan_priority:$verified.priority, next_task:null, in_progress:[], check_stale:false, check_result:"PASS"}
    else . + {row:5, reason:"no active plan with open work", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"} end'
