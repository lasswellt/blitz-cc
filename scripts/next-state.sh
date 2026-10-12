#!/usr/bin/env bash
# next-state.sh: deterministic Observe step for /blitz:next (loop.md §next rows).
# Prints one JSON object and exits 0. Never writes anything.
#
#   {
#     "row": 0..5,                 // decision row per loop.md; tie-break 0 > 1 > 2 > 3 > 4 > 5
#     "reason": "<one line>",
#     "active_plan": "<slug>|null", "plan_priority": N|null (rows 2-4 only),
#     "next_task": {id,title,role,files,verify,attempts} | null,
#     "in_progress": [id...], "blocked": [{plan,id,reason}], "escalate": [{plan,id,reason}],
#     "paused_plans": [slug...], "done_plans_unarchived": [slug...],
#     "check_stale": bool, "check_result": "PASS|CONDITIONAL|FAIL|none",
#     "inbox_pending": N, "sessions_waiting": N, "kill_switch": bool,
#     "loop_breaker": {open, reason, no_progress, same_error}
#   }
#
# Loop circuit breaker (row 1): reads .cc-sessions/loop-ticks.jsonl, one line per
# `next --loop` tick ({row, plan, task, progress, error}), written by next Phase 4.
# Opens after BLITZ_LOOP_NO_PROGRESS_MAX (3) trailing build/check ticks with no
# progress, or BLITZ_LOOP_SAME_ERROR_MAX (5) trailing ticks with the same error.
# A line {"reset": true} (a human ruled) discards every earlier tick.
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

fm_field() {  # fm_field <file> <key>: YAML frontmatter scalar, unquoted
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

NP_MAX="${BLITZ_LOOP_NO_PROGRESS_MAX:-3}"; SE_MAX="${BLITZ_LOOP_SAME_ERROR_MAX:-5}"
case "$NP_MAX$SE_MAX" in *[!0-9]*) NP_MAX=3; SE_MAX=5;; esac
loop_breaker='{"open":false,"reason":null,"no_progress":0,"same_error":0}'
if [ -f "$SESSIONS_DIR/loop-ticks.jsonl" ]; then
  loop_breaker=$(jq -Rsc --argjson np "$NP_MAX" --argjson se "$SE_MAX" '
    [split("\n")[] | select(length > 0) | (try fromjson catch null) | select(type == "object")] as $all
    | ($all | map(.reset == true) | rindex(true)) as $r
    | (if $r == null then $all else $all[($r + 1):] end) as $ticks
    | [$ticks[] | select(.row == 2 or .row == 3)] as $work
    | ($work | reverse) as $rev
    | (($rev | map(.progress == true) | index(true)) // ($rev | length)) as $no_progress
    | ($rev[0].error // null) as $last_err
    | (if $last_err == null or $last_err == "" then 0
       else (($rev | map(.error == $last_err) | index(false)) // ($rev | length)) end) as $same_error
    | {no_progress: $no_progress, same_error: $same_error,
       open: ($no_progress >= $np or $same_error >= $se),
       reason: (def safe: tostring | gsub("[^A-Za-z0-9_.:/ -]"; "") | .[0:120];   # ledger is repo state (TB-1)
                if $no_progress >= $np then "\($no_progress) build/check ticks in a row made no progress (last: \($rev[0].plan // "?" | safe)/\($rev[0].task // "plan" | safe))"
                elif $same_error >= $se then "same error \($same_error) ticks in a row: \($last_err | safe)"
                else null end)}' "$SESSIONS_DIR/loop-ticks.jsonl" 2>/dev/null) \
    || loop_breaker='{"open":false,"reason":null,"no_progress":0,"same_error":0}'
fi

# Scan plans. Rows travel over stdin, never argv: one plan's tasks.json can exceed
# the 128 KiB per-argument limit (MAX_ARG_STRLEN) and jq then fails with E2BIG.
plans_rows=''
if [ -d "$PLANS_DIR" ]; then
  for d in "$PLANS_DIR"/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    [ "$slug" = "archive" ] && continue
    [ -f "$d/tasks.json" ] || continue
    status=$(fm_field "$d/spec.md" status); [ -n "$status" ] || status="active"
    prio=$(fm_field "$d/spec.md" priority)
    case "$prio" in P0|p0) prio=0;; P1|p1) prio=1;; P2|p2) prio=2;; ''|*[!0-9]*) prio=100;; esac
    created=$(fm_field "$d/spec.md" created); [ -n "$created" ] || created="9999-12-31"
    result=$(report_result "$d")
    updated=$(jq -r '.updated // ""' "$d/tasks.json" 2>/dev/null)
    rts=$(fm_field "$d/check-report.md" ts)
    stale=true
    if [ "$result" = "PASS" ] && [ -n "$rts" ] && [ ! "$rts" \< "$updated" ]; then stale=false; fi
    row=$(jq -c --arg slug "$slug" --arg status "$status" --argjson prio "$prio" --arg created "$created" --arg result "$result" --argjson stale "$stale" '
      {slug:$slug, status:$status, priority:$prio, created:$created, check_result:$result, check_stale:$stale,
       tasks:.tasks,
       done:(.tasks | map(select(.status=="done") | .id)),
       in_progress:[.tasks[] | select(.status=="in_progress") | .id],
       blocked:[.tasks[] | select(.status=="blocked") | {id, reason:(.blocked_reason // "unknown")}],
       open_ready:([.tasks[] | select(.status=="open")] as $open | (.tasks | map(select(.status=="done") | .id)) as $done
                   | [$open[] | select(all(.depends_on[]?; . as $x | $done | index($x) != null))] | map({id,title,role,files,verify,attempts})),
       all_done:((.tasks | length) > 0 and all(.tasks[]; .status=="done"))}' "$d/tasks.json" 2>/dev/null) || continue
    plans_rows+="$row"$'\n'
  done
fi

printf '%s' "$plans_rows" | jq -sc --argjson inbox "$inbox_pending" --argjson waiting "$sessions_waiting" --argjson kill "$kill_switch" --argjson breaker "$loop_breaker" '
  . as $plans
  | ($plans | map(select(.status=="active")) | sort_by(.priority, .created, .slug)) as $active
  | ([$active[] | .blocked[] as $b | {plan:.slug, id:$b.id, reason:$b.reason}]) as $blocked
  | ([$blocked[] | select(.reason | IN("hard_spec","oracle-underivable","test-assertion-suspect"))]) as $escalate
  | ([$active[] | select((.in_progress | length) > 0 or (.open_ready | length) > 0)] | .[0]) as $work
  | ([$active[] | select(.all_done and .check_stale)] | .[0]) as $needs_check
  | ([$active[] | select(.all_done and (.check_stale | not) and .check_result == "PASS")] | .[0]) as $verified
  | {
      kill_switch: $kill, inbox_pending: $inbox, sessions_waiting: $waiting,
      paused_plans: [$plans[] | select(.status=="paused") | .slug],
      done_plans_unarchived: [$plans[] | select(.status=="done") | .slug],
      blocked: $blocked, escalate: $escalate, loop_breaker: $breaker
    }
  | if $kill then . + {plan_priority:null, row:0, reason:"kill switch .cc-sessions/STOP present", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif ($inbox > 0 or $waiting > 0) then . + {plan_priority:null, row:0, reason:"inbox pending or a session is waiting for input", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif ($escalate | length) > 0 then . + {plan_priority:null, row:1, reason:"blocked task needs a human: \($escalate[0].plan)/\($escalate[0].id) (\($escalate[0].reason))", active_plan:$escalate[0].plan, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif $breaker.open then . + {plan_priority:null, row:1, reason:"loop circuit breaker: \($breaker.reason)", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"}
    elif $work != null then . + {row:2, reason:"open work in \($work.slug)", active_plan:$work.slug, plan_priority:$work.priority,
          next_task:(if ($work.in_progress | length) > 0 then ($work.tasks[] | select(.id == $work.in_progress[0]) | {id,title,role,files,verify,attempts}) else $work.open_ready[0] end),
          in_progress:$work.in_progress, check_stale:$work.check_stale, check_result:$work.check_result}
    elif $needs_check != null then . + {row:3, reason:"all tasks done in \($needs_check.slug); check report missing, stale, or not PASS", active_plan:$needs_check.slug, plan_priority:$needs_check.priority, next_task:null, in_progress:[], check_stale:true, check_result:$needs_check.check_result}
    elif $verified != null then . + {row:4, reason:"\($verified.slug) verified PASS; mark done, learn, archive; ship is slash-only", active_plan:$verified.slug, plan_priority:$verified.priority, next_task:null, in_progress:[], check_stale:false, check_result:"PASS"}
    else . + {plan_priority:null, row:5, reason:"no active plan with open work", active_plan:null, next_task:null, in_progress:[], check_stale:false, check_result:"none"} end'
