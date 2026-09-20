#!/usr/bin/env bash
# tasks.sh — the only writer of docs/plans/<slug>/tasks.json (blitz-tasks/1.0).
#
# Usage:
#   tasks.sh init   <plan>
#   tasks.sh list   <plan> [--status open|in_progress|done|blocked] [--json]
#   tasks.sh add    <plan> --id T-001 --title "..." [--role backend|frontend|infra|test]
#                   [--files a,b] [--depends T-000,T-002] [--origin plan|audit|check|learn|issue:N]
#                   --verify-cmd "cmd"[::timeout] (repeatable) [--test-only-ok] [--notes "..."]
#   tasks.sh set    <plan> <id> key=value ...   keys: status blocked_reason notes role title attempts (N or +1)
#   tasks.sh verify <plan> <id> [--dry]         runs verify[] in order; writes passes + last_verify
#   tasks.sh verify <plan> --changed <paths>    re-verifies only the done tasks whose files[] the
#                                               paths touch (post-merge selective re-verify)
#   tasks.sh next   <plan>                      prints the first open task whose depends_on are all done
#
# Contract (loop.md §Structural rules):
#   - verify[] is never empty; a task whose checks are all test runners needs --test-only-ok.
#   - `status: done` is written only by `verify` after every check exits 0.
#   - Writes are atomic (tmp + mv) and bump `updated`.
# Exit: 0 ok · 1 verify failed · 2 usage/contract error · 3 not found
set -euo pipefail

PLANS_DIR="${BLITZ_PLANS_DIR:-}"
if [ -z "$PLANS_DIR" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  PLANS_DIR="$ROOT/docs/plans"
fi
TEST_RUNNER_RX='(vitest|jest|npm (run )?test|pnpm test|yarn test|pytest|go test|cargo test|bats )'
ISO() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Epoch milliseconds. GNU date does %3N; BSD/macOS does not, so fall back to
# second resolution rather than emitting the literal "3N".
NOW_MS() {
  local ms
  ms=$(date +%s%3N 2>/dev/null || true)
  case "$ms" in ''|*[!0-9]*) ms=$(( $(date +%s) * 1000 ));; esac
  printf '%s' "$ms"
}
die() { echo "tasks.sh: $*" >&2; exit 2; }
usage() { sed -n '2,18p' "$0"; exit 2; }

plan_file() {
  local plan="$1"
  case "$plan" in ''|*/*|.*) die "bad plan slug '$plan'";; esac
  printf '%s/%s/tasks.json\n' "$PLANS_DIR" "$plan"
}
require_file() { [ -f "$1" ] || { echo "tasks.sh: no tasks.json for plan (expected $1)" >&2; exit 3; }; }
atomic_write() {  # atomic_write <file> <json>
  local f="$1" json="$2" tmp
  printf '%s' "$json" | jq -e . >/dev/null || die "refusing to write invalid JSON to $f"
  tmp=$(mktemp -p "$(dirname "$f")" .tasks.XXXXXX)
  printf '%s\n' "$json" > "$tmp" && mv "$tmp" "$f"
}
bump() { jq --arg now "$(ISO)" '.updated = $now'; }

cmd_init() {
  local plan="$1" f
  f=$(plan_file "$plan")
  if [ -f "$f" ]; then echo "$f"; return 0; fi
  mkdir -p "$(dirname "$f")"
  atomic_write "$f" "$(jq -nc --arg p "$plan" --arg now "$(ISO)" '{"$schema":"blitz-tasks/1.0",plan:$p,updated:$now,tasks:[]}')"
  echo "$f"
}

cmd_list() {
  local plan="$1"; shift
  local status="" json=0
  while [ $# -gt 0 ]; do
    case "$1" in --status) status="$2"; shift 2;; --json) json=1; shift;; *) die "unknown flag $1";; esac
  done
  local f; f=$(plan_file "$plan"); require_file "$f"
  local filter='.tasks'
  [ -n "$status" ] && filter="[.tasks[] | select(.status == \"$status\")]"
  if [ "$json" -eq 1 ]; then jq -c "$filter" "$f"; return 0; fi
  jq -r "$filter | .[] | \"\(.id)\t\(.status)\t\(if .passes then \"pass\" else \"fail\" end)\t\(.attempts // 0)\t\(.title)\"" "$f" | column -t -s $'\t' 2>/dev/null || jq -r "$filter | .[] | \"\(.id) \(.status) \(.title)\"" "$f"
}

cmd_add() {
  local plan="$1"; shift
  local id="" title="" role="backend" files="" depends="" origin="plan" notes="" test_only_ok=0
  local -a verify=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --id) id="$2"; shift 2;; --title) title="$2"; shift 2;; --role) role="$2"; shift 2;;
      --files) files="$2"; shift 2;; --depends) depends="$2"; shift 2;; --origin) origin="$2"; shift 2;;
      --notes) notes="$2"; shift 2;; --verify-cmd) verify+=("$2"); shift 2;; --test-only-ok) test_only_ok=1; shift;;
      *) die "unknown flag $1";;
    esac
  done
  [ -n "$id" ] && [ -n "$title" ] || die "add needs --id and --title"
  echo "$id" | grep -qE '^T-[0-9]{3,}$' || die "id '$id' must look like T-001"
  case "$role" in backend|frontend|infra|test) ;; *) die "role '$role' must be backend|frontend|infra|test";; esac
  echo "$origin" | grep -qE '^(plan|audit|check|learn|issue:[0-9]+)$' || die "origin '$origin' must be plan|audit|check|learn|issue:<n>"
  [ "${#verify[@]}" -gt 0 ] || die "add refuses a task with no --verify-cmd: every task carries an executable check"
  if [ "$test_only_ok" -eq 0 ]; then
    local non_test=0 v
    for v in "${verify[@]}"; do printf '%s' "${v%%::*}" | grep -qEi "$TEST_RUNNER_RX" || non_test=1; done
    [ "$non_test" -eq 1 ] || die "all verify commands are test runners; add a non-test check (grep/shell/e2e) or pass --test-only-ok (tests alone get gamed; see quality.md)"
  fi
  local f; f=$(cmd_init "$plan")
  if jq -e --arg id "$id" '.tasks[] | select(.id == $id)' "$f" >/dev/null; then die "task $id already exists in $plan"; fi
  local vjson='[]' v cmd tmo
  for v in "${verify[@]}"; do
    cmd="${v%%::*}"; tmo=120
    [ "$v" != "$cmd" ] && tmo="${v##*::}"
    case "$tmo" in *[!0-9]*|"") tmo=120;; esac
    vjson=$(printf '%s' "$vjson" | jq -c --arg c "$cmd" --argjson t "$tmo" '. + [{cmd:$c,timeout:$t}]')
  done
  local task
  task=$(jq -nc --arg id "$id" --arg title "$title" --arg role "$role" --arg files "$files" --arg dep "$depends" \
    --arg origin "$origin" --arg notes "$notes" --argjson verify "$vjson" '
    {id:$id, title:$title, role:$role,
     files: (if $files == "" then [] else ($files | split(",") | map(select(length>0))) end),
     depends_on: (if $dep == "" then [] else ($dep | split(",") | map(select(length>0))) end),
     verify:$verify, passes:false, status:"open", blocked_reason:null, attempts:0,
     last_verify:null, origin:$origin, notes:$notes}')
  atomic_write "$f" "$(jq --argjson t "$task" '.tasks += [$t]' "$f" | bump)"
  echo "added $id to $plan"
}

cmd_set() {
  local plan="$1" id="$2"; shift 2
  local f; f=$(plan_file "$plan"); require_file "$f"
  jq -e --arg id "$id" '.tasks[] | select(.id == $id)' "$f" >/dev/null || { echo "tasks.sh: no task $id in $plan" >&2; exit 3; }
  local kv key val json explicit=0; json=$(cat "$f")
  for kv in "$@"; do
    key="${kv%%=*}"; val="${kv#*=}"
    case "$key" in
      status|blocked_reason) explicit=1;;
    esac
    case "$key" in
      status)
        case "$val" in open|in_progress|blocked) ;;
          done) [ "$(printf '%s' "$json" | jq -r --arg id "$id" '.tasks[] | select(.id==$id) | .passes')" = "true" ] || die "status=done is written only by 'tasks.sh verify' after every check passes";;
          *) die "status '$val' must be open|in_progress|done|blocked";; esac
        json=$(printf '%s' "$json" | jq --arg id "$id" --arg v "$val" '(.tasks[] | select(.id==$id) | .status) = $v | (.tasks[] | select(.id==$id) | .blocked_reason) |= (if $v == "blocked" then . else null end)');;
      blocked_reason)
        case "$val" in hard_spec|oracle-underivable|test-assertion-suspect|scope-expansion-needed|circuit-breaker|dependency-missing|ratchet:*|null|"") ;; *) die "unknown blocked_reason '$val'";; esac
        json=$(printf '%s' "$json" | jq --arg id "$id" --arg v "$val" '(.tasks[] | select(.id==$id) | .blocked_reason) = (if ($v == "" or $v == "null") then null else $v end) | (.tasks[] | select(.id==$id) | .status) |= (if ($v == "" or $v == "null") then . else "blocked" end)');;
      attempts)
        if [ "$val" = "+1" ]; then json=$(printf '%s' "$json" | jq --arg id "$id" '(.tasks[] | select(.id==$id) | .attempts) |= ((. // 0) + 1)')
        else case "$val" in *[!0-9]*|"") die "attempts must be a number or +1";; esac
          json=$(printf '%s' "$json" | jq --arg id "$id" --argjson v "$val" '(.tasks[] | select(.id==$id) | .attempts) = $v'); fi;;
      notes|title) json=$(printf '%s' "$json" | jq --arg id "$id" --arg k "$key" --arg v "$val" '(.tasks[] | select(.id==$id) | .[$k]) = $v');;
      role) case "$val" in backend|frontend|infra|test) ;; *) die "bad role";; esac
        json=$(printf '%s' "$json" | jq --arg id "$id" --arg v "$val" '(.tasks[] | select(.id==$id) | .role) = $v');;
      passes|last_verify) die "'$key' is written only by 'tasks.sh verify'";;
      *) die "unknown key '$key'";;
    esac
  done
  # circuit breaker: 3 failed attempts without a pass -> blocked. Skipped when this call set
  # status or blocked_reason explicitly (the operator's unblock recipe: status=open attempts=0).
  [ "$explicit" -eq 1 ] || json=$(printf '%s' "$json" | jq --arg id "$id" '(.tasks[] | select(.id==$id)) |= (if ((.attempts // 0) >= 3 and .passes == false and .status != "blocked" and .status != "done") then .status = "blocked" | .blocked_reason = (.blocked_reason // "circuit-breaker") else . end)')
  atomic_write "$f" "$(printf '%s' "$json" | bump)"
  jq -r --arg id "$id" '.tasks[] | select(.id==$id) | "\(.id) status=\(.status) attempts=\(.attempts) blocked_reason=\(.blocked_reason // "-")"' "$f"
}

cmd_verify() {
  local plan="$1" id="$2"; shift 2
  local dry=0; [ "${1:-}" = "--dry" ] && dry=1
  local f; f=$(plan_file "$plan"); require_file "$f"
  local task; task=$(jq -c --arg id "$id" '.tasks[] | select(.id == $id)' "$f")
  [ -n "$task" ] || { echo "tasks.sh: no task $id in $plan" >&2; exit 3; }
  local n i cmd tmo out rc=0 failed="" tail=""
  n=$(printf '%s' "$task" | jq '.verify | length')
  [ "$n" -gt 0 ] || die "task $id has no verify[] entries"
  local root; root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  # Per-command evidence. Without it a reviewer has to re-run the suite to see
  # what a verdict rested on, and "cannot_verify" is not a defensible answer.
  local runs="[]" t0 t1 dur head_out
  i=0
  while [ "$i" -lt "$n" ]; do
    cmd=$(printf '%s' "$task" | jq -r ".verify[$i].cmd")
    tmo=$(printf '%s' "$task" | jq -r ".verify[$i].timeout // 120")
    case "$tmo" in *[!0-9]*|"") tmo=120;; esac
    i=$((i + 1))
    if [ "$dry" -eq 1 ]; then echo "[dry] $cmd (timeout ${tmo}s)"; continue; fi
    out=$(mktemp)
    rc=0
    t0=$(NOW_MS)
    ( cd "$root" && timeout "$tmo" bash -c "$cmd" ) >"$out" 2>&1 || rc=$?
    t1=$(NOW_MS); dur=$((t1 - t0)); [ "$dur" -lt 0 ] && dur=0
    # 2 KB is the difference between "the critic reads the tail" and "the
    # critic re-runs the suite"; more than that is a log, not evidence.
    head_out=$(tail -c "${BLITZ_VERIFY_EVIDENCE_CAP:-2000}" "$out" 2>/dev/null || true)
    runs=$(printf '%s' "$runs" | jq -c --arg cmd "$cmd" --argjson exit "$rc" \
      --argjson ms "$dur" --arg tail "$head_out" --arg ts "$(ISO)" \
      '. + [{cmd:$cmd, exit:$exit, duration_ms:$ms, tail:$tail, recorded_at:$ts}]')
    if [ "$rc" -ne 0 ]; then
      failed="$cmd"; tail=$(tail -c 200 "$out" | tr '\n' ' ')
      rm -f "$out"; break
    fi
    rm -f "$out"
  done
  [ "$dry" -eq 1 ] && return 0
  local ok=true; [ "$rc" -eq 0 ] || ok=false
  local lv
  lv=$(jq -nc --arg ts "$(ISO)" --argjson ok "$ok" --arg failed "$failed" --arg tail "$tail" \
       --argjson runs "$runs" '{ts:$ts,ok:$ok,failed:$failed,tail:$tail,runs:$runs}')
  local json
  json=$(jq --arg id "$id" --argjson lv "$lv" --argjson ok "$ok" '
    (.tasks[] | select(.id==$id)) |= (.last_verify = $lv | .passes = $ok | .status = (if $ok then "done" else (if .status == "done" then "in_progress" else .status end) end) | .blocked_reason = (if $ok then null else .blocked_reason end))' "$f")
  atomic_write "$f" "$(printf '%s' "$json" | bump)"
  if [ "$ok" = true ]; then echo "PASS $plan/$id ($n checks)"; return 0; fi
  echo "FAIL $plan/$id: $failed (rc=$rc) :: $tail" >&2
  return 1
}

# cmd_verify_changed PLAN PATH...
#
# After merging a parallel wave, a clean textual merge is not a semantic one:
# two tasks can each pass alone and break each other once combined. Re-running
# every task's verify[] is the safe answer and the slow one. This re-verifies
# exactly the tasks whose files[] intersect the merged paths, which is the set
# a merge can have broken.
#
# Paths come from `git diff --name-only <base>..HEAD` and are matched against
# each task's files[] by exact path or by directory prefix.
cmd_verify_changed() {
  local plan="$1"; shift
  local f; f=$(plan_file "$plan"); require_file "$f"
  [ "$#" -gt 0 ] || die "verify --changed needs at least one path"

  local paths_json; paths_json=$(printf '%s\n' "$@" | jq -R . | jq -sc .)
  local ids
  ids=$(jq -r --argjson paths "$paths_json" '
    .tasks[]
    | . as $t
    | select($t.status == "done")
    | select(($t.files // []) | any(. as $tf
        | $paths | any(. as $p
            | $p == $tf
            or ($tf | endswith("/")) and ($p | startswith($tf))
            or ($p | startswith($tf + "/"))
            or ($tf | startswith($p + "/")))))
    | $t.id' "$f")

  if [ -z "$ids" ]; then
    echo "verify --changed $plan: no done task owns any of the $# changed path(s); nothing to re-verify"
    return 0
  fi

  local id rc=0 n=0 failed=""
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    n=$((n + 1))
    if cmd_verify "$plan" "$id"; then :; else rc=1; failed="$failed $id"; fi
  done <<< "$ids"

  if [ "$rc" -eq 0 ]; then
    echo "verify --changed $plan: $n task(s) re-verified, all pass"
  else
    echo "verify --changed $plan: $n task(s) re-verified, FAILED:$failed" >&2
  fi
  return "$rc"
}

cmd_next() {
  local plan="$1" f; f=$(plan_file "$plan"); require_file "$f"
  jq -c '
    (.tasks | map(select(.status=="done") | .id)) as $done
    | [.tasks[] | select(.status=="in_progress")] as $wip
    | if ($wip | length) > 0 then $wip[0]
      else ([.tasks[] | select(.status=="open") | select(all(.depends_on[]; . as $d | $done | index($d) != null))] | .[0] // empty) end' "$f"
}

[ $# -ge 1 ] || usage
cmd="$1"; shift
case "$cmd" in
  init)   [ $# -ge 1 ] || usage; cmd_init "$@";;
  list)   [ $# -ge 1 ] || usage; cmd_list "$@";;
  add)    [ $# -ge 1 ] || usage; cmd_add "$@";;
  set)    [ $# -ge 3 ] || usage; cmd_set "$@";;
  verify)
    [ $# -ge 2 ] || usage
    if [ "${2:-}" = "--changed" ]; then
      plan="$1"; shift 2; cmd_verify_changed "$plan" "$@"
    else
      cmd_verify "$@"
    fi
    ;;
  next)   [ $# -ge 1 ] || usage; cmd_next "$@";;
  -h|--help|help) usage;;
  *) die "unknown command '$cmd'";;
esac
