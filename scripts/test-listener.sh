#!/usr/bin/env bash
# test-listener.sh — stateless test-result journal writer (E-043 S1/S6).
#
# Reads a Vitest (`vitest run --reporter=json`) or Jest (`jest --json`) report
# on stdin and appends ONE line per test file to .cc-sessions/test-journal.jsonl:
#   {ts, run_id, session, trigger, commit, changed:[…], test_file, result,
#    failed_names:[…], duration_ms, selected_by}
# then increments runs_recorded in .cc-sessions/test-journal.meta.json
#   {runs_started, runs_recorded, last_run_id, escaped_failures_recent:[…]}
#
# Usage:
#   test-listener.sh --start --run-id <id> [--session <sid>]        # runs_started++
#   test-listener.sh --trigger post-edit|check|ci [--changed <f1,f2,…>]
#                    [--selected-by <mode>] [--run-id <id>] [--session <sid>] < runner.json
#   test-listener.sh --prune                                         # keep 5000 lines / 30 days
#
# Design (Anthropic test-impact-analysis post): append-only journal, stateless
# writers, no service. Observability invariant: runs_started == runs_recorded.
# Every append happens under a noclobber lock (5s spin, >60s stale recovery).
# Never blocks a hook: malformed input -> feed warning + exit 0.
# Dependencies: bash, jq, python3, git (optional). No npm packages.
set -uo pipefail

TRIGGER="" CHANGED="" SELECTED_BY="" RUN_ID="" SESSION="" MODE="record"
while [ $# -gt 0 ]; do
  case "$1" in
    --start) MODE="start" ;;
    --prune) MODE="prune" ;;
    --trigger) TRIGGER="${2:-}"; shift ;;
    --changed) CHANGED="${2:-}"; shift ;;
    --selected-by) SELECTED_BY="${2:-}"; shift ;;
    --run-id) RUN_ID="${2:-}"; shift ;;
    --session) SESSION="${2:-}"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "test-listener: unknown arg: $1" >&2 ;;
  esac
  shift
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SESSIONS_DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
mkdir -p "$SESSIONS_DIR" 2>/dev/null || true
JOURNAL="$SESSIONS_DIR/test-journal.jsonl"
META="$SESSIONS_DIR/test-journal.meta.json"
LOCK="$SESSIONS_DIR/test-journal.lock"
SESSION="${SESSION:-${SESSION_ID:-${CLAUDE_SESSION_ID:-}}}"
[ -n "$RUN_ID" ] || RUN_ID=$( (od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || date +%s )

# Shared helpers when running inside the plugin (optional; local fallbacks below).
COMMON="$(cd "$(dirname "$0")" && pwd)/../hooks/scripts/_lib/common.sh"
[ -f "$COMMON" ] && . "$COMMON" 2>/dev/null || true

_ts() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ; }

tia_log() { # event message
  if command -v blitz_log_event >/dev/null 2>&1; then
    SESSION_ID="${SESSION:-}" SESSIONS_DIR="$SESSIONS_DIR" blitz_log_event "tia" "$1" "$2" "{\"run_id\":\"$RUN_ID\"}"
  else
    jq -nc --arg ts "$(_ts)" --arg s "$SESSION" --arg ev "$1" --arg msg "$2" --arg rid "$RUN_ID" \
      '{ts:$ts,session:$s,skill:"tia",event:$ev,message:$msg,detail:{run_id:$rid}}' \
      >> "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null || true
  fi
}

tia_inbox() { # kind text
  if command -v blitz_inbox_append >/dev/null 2>&1; then
    SESSIONS_DIR="$SESSIONS_DIR" blitz_inbox_append "$1" "$2" "$SESSION"
  else
    local id; id=$( (od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || echo 00000000 )
    jq -nc --arg ts "$(_ts)" --arg id "inb-$id" --arg kind "$1" --arg s "$SESSION" --arg text "$2" \
      '{ts:$ts,id:$id,source:"hook",kind:$kind,session:$s,text:$text,status:"pending"}' \
      >> "$SESSIONS_DIR/inbox.jsonl" 2>/dev/null || true
  fi
}

# _mtime path — epoch mtime; GNU stat first, BSD stat second. A file that vanished
# between the noclobber attempt and this call (another writer finished) reports
# "now" so the caller never treats a just-taken lock as stale.
_mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null) || m=$(stat -f %m "$1" 2>/dev/null) || m=""
  case "$m" in ''|*[!0-9]*) m=$(date +%s) ;; esac
  printf '%s\n' "$m"
}

# tia_lock — noclobber lock, 5s spin (50 x 0.1s), stale (>60s) recovery.
tia_lock() {
  local i=0 age
  while :; do
    if ( set -o noclobber; : > "$LOCK" ) 2>/dev/null; then return 0; fi
    age=$(( $(date +%s) - $(_mtime "$LOCK") ))
    if [ "$age" -gt 60 ]; then rm -f "$LOCK" 2>/dev/null; continue; fi
    i=$((i + 1)); [ "$i" -ge 50 ] && return 1
    sleep 0.1
  done
}
tia_unlock() { rm -f "$LOCK" 2>/dev/null || true; }

# tia_meta_update jq_filter — read-modify-write meta.json atomically (caller holds lock).
tia_meta_update() {
  local cur upd tmp
  cur=$(cat "$META" 2>/dev/null); printf '%s' "$cur" | jq -e . >/dev/null 2>&1 || cur='{}'
  upd=$(printf '%s' "$cur" | jq -c --arg rid "$RUN_ID" \
    '{runs_started:0,runs_recorded:0,last_run_id:"",escaped_failures_recent:[]} + . | '"$1") || return 1
  tmp=$(mktemp -p "$SESSIONS_DIR" .tia-meta.XXXXXX 2>/dev/null || mktemp) || return 1
  printf '%s\n' "$upd" > "$tmp" && mv "$tmp" "$META"
}

tia_check_drift() {
  local s r d
  s=$(jq -r '.runs_started // 0' "$META" 2>/dev/null || echo 0)
  r=$(jq -r '.runs_recorded // 0' "$META" 2>/dev/null || echo 0)
  d=$(( s - r )); [ "$d" -lt 0 ] && d=$(( -d ))
  if [ "$d" -gt 3 ]; then
    tia_inbox "hook_failure" "test journal: $s runs started, $r recorded"
    tia_log "warning" "test journal drift: $s started / $r recorded"
  fi
}

case "$MODE" in
  start)
    tia_lock || { tia_log "warning" "test journal lock timeout (--start)"; exit 0; }
    tia_meta_update '.runs_started += 1' || tia_log "warning" "meta update failed (--start)"
    tia_unlock
    tia_check_drift
    exit 0 ;;
  prune)
    tia_lock || { tia_log "warning" "test journal lock timeout (--prune)"; exit 0; }
    if [ -f "$JOURNAL" ]; then
      TMP=$(mktemp -p "$SESSIONS_DIR" .tia-prune.XXXXXX 2>/dev/null || mktemp)
      python3 - "$JOURNAL" > "$TMP" <<'PY' && mv "$TMP" "$JOURNAL" || rm -f "$TMP"
import sys, json, datetime
cut = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ")
keep = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if not line.strip():
        continue
    try:
        ts = json.loads(line).get("ts", "")
    except Exception:
        continue
    if ts >= cut:
        keep.append(line)
sys.stdout.write("".join(l + "\n" for l in keep[-5000:]))
PY
    fi
    tia_unlock
    exit 0 ;;
esac

# ---- record mode ----------------------------------------------------------
if [ -z "$TRIGGER" ]; then
  echo "test-listener: --trigger post-edit|check|ci required" >&2
  exit 0
fi
COMMIT=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")
REPORT=$(cat 2>/dev/null || true)

# Python source held in a variable: a heredoc on `python3 -` would replace the
# piped report on stdin.
PARSE_PY=$(cat <<'PY'
import sys, json, os
root, run_id, session, trigger, commit, changed, selected_by, ts = sys.argv[1:9]
raw = sys.stdin.read()
try:
    rep = json.loads(raw)
    results = rep["testResults"]
    assert isinstance(results, list)
except Exception as e:
    sys.stderr.write(f"malformed: {e}\n"); sys.exit(3)
root = os.path.realpath(root) + os.sep
def _rel(c):  # journal `changed` entries are repo-relative so the selector's co-change lookup matches
    if os.path.isabs(c):
        rp = os.path.realpath(c)
        return rp[len(root):] if rp.startswith(root) else c
    return c
changed_list = sorted({_rel(c.strip()) for c in changed.split(",") if c.strip()})
out = []
for tr in results:
    name = tr.get("name") or tr.get("testFilePath") or ""
    if os.path.isabs(name):
        rp = os.path.realpath(name)
        if rp.startswith(root):
            name = rp[len(root):]
        else:  # report produced in another checkout: keep the longest suffix that exists here
            parts = name.lstrip(os.sep).split(os.sep)
            for i in range(len(parts)):
                cand = os.sep.join(parts[i:])
                if os.path.exists(root + cand):
                    name = cand; break
    asserts = tr.get("assertionResults") or []
    failed = [a.get("fullName") or a.get("title") or "" for a in asserts if a.get("status") == "failed"]
    status = tr.get("status", "")
    if status == "failed" or failed:
        result = "fail"
    elif status == "passed" or any(a.get("status") == "passed" for a in asserts):
        result = "pass"
    else:
        result = "skip"
    st, en = tr.get("startTime"), tr.get("endTime")
    if isinstance(st, (int, float)) and isinstance(en, (int, float)) and en >= st:
        dur = int(en - st)
    else:
        dur = int(sum(a.get("duration") or 0 for a in asserts))
    out.append(json.dumps({"ts": ts, "run_id": run_id, "session": session, "trigger": trigger,
        "commit": commit, "changed": changed_list, "test_file": name, "result": result,
        "failed_names": failed, "duration_ms": dur, "selected_by": selected_by}, separators=(",", ":")))
sys.stdout.write("".join(l + "\n" for l in out))
PY
)
LINES=$(printf '%s' "$REPORT" | python3 -c "$PARSE_PY" "$ROOT" "$RUN_ID" "$SESSION" "$TRIGGER" "$COMMIT" "$CHANGED" "$SELECTED_BY" "$(_ts)"); RC=$?
if [ "$RC" -ne 0 ]; then
  tia_log "warning" "test-listener: malformed runner JSON on stdin (trigger=$TRIGGER); nothing journaled"
  exit 0
fi

tia_lock || { tia_log "warning" "test journal lock timeout; run $RUN_ID not journaled"; exit 0; }
[ -n "$LINES" ] && printf '%s\n' "$LINES" >> "$JOURNAL"
tia_meta_update '.runs_recorded += 1 | .last_run_id = $rid' || tia_log "warning" "meta update failed (record)"
tia_unlock
tia_check_drift
N=$(printf '%s' "$LINES" | grep -c . || true)
tia_log "test_run_recorded" "journaled $N test file(s), trigger=$TRIGGER, selected_by=${SELECTED_BY:-none}"
exit 0
