#!/usr/bin/env bash
# sessions-dashboard.sh — render .cc-sessions/dashboard.md (E-041 S5, /blitz:sessions dashboard)
#
# Usage: scripts/sessions-dashboard.sh [--html] [--out <path>]
#   --html        also write the HTML twin via hooks/scripts/_lib/html.sh emit_html
#                 (<out>.html next to the .md; trusted-tier: every quoted field is
#                 sanitized here first, and the converter output is scrubbed by sanitize_html)
#   --out <path>  markdown path (default .cc-sessions/dashboard.md)
#
# Sections: Sessions table, Attention queue (prints HEARTBEAT_OK when empty), Locks,
# Inbox (pending), Timeline (last 200 feed lines), Token estimate per session.
# Inputs (all optional, all untrusted repo-local data — TB-1; bad JSON lines skipped):
#   .cc-sessions/sessions/*.json   hook-owned records (+ legacy .cc-sessions/<skill>-<hex>.json)
#   .cc-sessions/activity-feed.jsonl, inbox.jsonl, **/*.lock, context-char-count
#   `claude agents --json --all` overlay via blitz_agent_view (empty when unavailable)
# The rendered markdown is also printed to stdout. Pure bash + jq + python3.
# Exit 0 always on a rendered dashboard; 2 on bad arguments.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../hooks/scripts/_lib"
. "$LIB_DIR/common.sh"

HTML=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --html) HTML=1 ;;
    --out) shift; [ -n "${1:-}" ] || { echo "sessions-dashboard: --out needs a path" >&2; exit 2; }; OUT="$1" ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "sessions-dashboard: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || { echo "sessions-dashboard: jq required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "sessions-dashboard: python3 required" >&2; exit 2; }

ROOT=$(blitz_find_root || true)
SESSIONS_DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
mkdir -p "$SESSIONS_DIR"
[ -n "$OUT" ] || OUT="$SESSIONS_DIR/dashboard.md"

WORK=$(mktemp -d 2>/dev/null || mktemp -d -t blitz-dash)
trap 'rm -rf "$WORK"' EXIT

# --- 1. Session records → records.jsonl (canonical first, then legacy; bad JSON skipped) ---
: > "$WORK/records.jsonl"
for f in "$SESSIONS_DIR"/sessions/*.json "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  jq -c --arg path "$f" --arg stem "$(basename "$f" .json)" \
    'select(type=="object" and has("status")) |
     . + {_sid: (.session_id // .claude_session_id // $stem), _path: $path,
          _legacy: (if .session_id then false else true end),
          _mtime: 0}' "$f" 2>/dev/null >> "$WORK/records.jsonl" || true
done

# --- 2. Feed (last 200 valid lines), inbox (valid lines), overlay ---
: > "$WORK/feed.jsonl"
if [ -s "$SESSIONS_DIR/activity-feed.jsonl" ]; then
  tail -400 "$SESSIONS_DIR/activity-feed.jsonl" 2>/dev/null | while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" | jq -c 'select(type=="object")' 2>/dev/null || true
  done | tail -200 > "$WORK/feed.jsonl" || true
fi
: > "$WORK/inbox.jsonl"
if [ -s "$SESSIONS_DIR/inbox.jsonl" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" | jq -c 'select(type=="object")' 2>/dev/null || true
  done < "$SESSIONS_DIR/inbox.jsonl" > "$WORK/inbox.jsonl" || true
fi
blitz_agent_view > "$WORK/overlay.jsonl" 2>/dev/null || : > "$WORK/overlay.jsonl"

# --- 3. Locks: path, owner (record sid named in the body, else JSON field), age ---
: > "$WORK/locks.jsonl"
NOW=$(date +%s)
while IFS= read -r lock; do
  [ -f "$lock" ] || continue
  mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo "$NOW")
  owner=""
  while IFS= read -r sid; do
    [ -n "$sid" ] || continue
    if grep -qF -- "$sid" "$lock" 2>/dev/null; then owner="$sid"; break; fi
  done < <(jq -r '._sid' "$WORK/records.jsonl" 2>/dev/null || true)
  [ -n "$owner" ] || owner=$(jq -r '.session // .owner // .session_id // empty' "$lock" 2>/dev/null | head -1 || true)
  [ -n "$owner" ] || owner=$(head -c 64 "$lock" 2>/dev/null | tr -d '\n' || true)
  jq -nc --arg p "${lock#"$SESSIONS_DIR"/}" --arg o "$owner" --argjson age "$(( NOW - mtime ))" \
    '{path:$p,owner:$o,age_s:$age}' >> "$WORK/locks.jsonl" 2>/dev/null || true
done < <(find "$SESSIONS_DIR" -type f -name '*.lock' 2>/dev/null | sort || true)

# --- 4. Transcript sizes (KB) per record; context-char-count for this checkout ---
: > "$WORK/sizes.jsonl"
while IFS=$'\t' read -r sid tp; do
  kb=""
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    bytes=$(stat -c %s "$tp" 2>/dev/null || stat -f %z "$tp" 2>/dev/null || echo 0)
    kb=$(( bytes / 1024 ))
  fi
  jq -nc --arg sid "$sid" --arg kb "$kb" '{sid:$sid,kb:(if $kb=="" then null else ($kb|tonumber) end)}' \
    >> "$WORK/sizes.jsonl" 2>/dev/null || true
done < <(jq -r '[._sid, (.transcript_path // "")] | @tsv' "$WORK/records.jsonl" 2>/dev/null || true)
CTX_CHARS=""
[ -f "$SESSIONS_DIR/context-char-count" ] && CTX_CHARS=$(tr -dc '0-9' < "$SESSIONS_DIR/context-char-count" 2>/dev/null | head -c 12 || true)

# --- 5. Render (python3: joins, sorting, sanitizing) ---
BLITZ_WORK="$WORK" BLITZ_RX="$BLITZ_INJECTION_RX" BLITZ_CTX_CHARS="$CTX_CHARS" \
BLITZ_SESSIONS_DIR="$SESSIONS_DIR" BLITZ_NOW="$NOW" python3 - > "$WORK/dashboard.md" <<'PYEOF'
import json, os, re, sys, time
from datetime import datetime, timezone

W = os.environ["BLITZ_WORK"]
NOW = int(os.environ["BLITZ_NOW"])
RX = re.compile(os.environ["BLITZ_RX"], re.I)
QUAR = "[quarantined: suspicious field]"

def rows(name):
    out = []
    try:
        with open(os.path.join(W, name)) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                if isinstance(o, dict):
                    out.append(o)
    except FileNotFoundError:
        pass
    return out

def san(v, n=120):
    s = "" if v is None else str(v)
    s = s.replace("\r", " ").replace("\n", " ").replace("|", "\\|")
    if RX.search(s):
        return QUAR
    return s[:n] + ("…" if len(s) > n else "")

def epoch(iso):
    if not iso:
        return None
    try:
        return int(datetime.fromisoformat(str(iso).replace("Z", "+00:00")).timestamp())
    except Exception:
        return None

def age_m(iso):
    e = epoch(iso)
    return "?" if e is None else str(max(0, (NOW - e) // 60))

def short(sid):
    if not sid:
        return "-"
    s = san(str(sid), 64)
    return s if s == QUAR else s[:8]

records = rows("records.jsonl")
feed = rows("feed.jsonl")
inbox = rows("inbox.jsonl")
overlay = {o.get("sessionId"): o for o in rows("overlay.jsonl") if o.get("sessionId")}
locks = rows("locks.jsonl")
sizes = {o.get("sid"): o.get("kb") for o in rows("sizes.jsonl")}
ctx_chars = os.environ.get("BLITZ_CTX_CHARS") or ""

# PR label per session: latest feed line whose message/detail mentions a PR
pr_rx = re.compile(r"(?:PR\s?#|pull/|pulls/)(\d+)", re.I)
pr_by_sid = {}
for ev in feed:
    sid = ev.get("session")
    if not sid:
        continue
    blob = json.dumps(ev.get("message", "")) + json.dumps(ev.get("detail", {}))
    m = pr_rx.search(blob)
    if m:
        pr_by_sid[sid] = "#" + m.group(1)

out = []
p = out.append
p("# Sessions dashboard")
p("")
p(f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')} · {len(records)} record(s) · "
  f"{len(overlay)} agent-view row(s){'' if overlay else ' (agent view unavailable)'} · feed lines considered: {len(feed)}")
p("")

# --- Sessions ---
p("## Sessions")
p("")
if not records:
    p("_No session records under `.cc-sessions/sessions/`._")
else:
    p("| sid | skill | status/state | overlay state/status | waitingFor | age (m) | cwd | PR |")
    p("|---|---|---|---|---|---|---|---|")
    def rk(r):
        e = epoch(r.get("last_activity") or r.get("started"))
        return -(e or 0)
    for r in sorted(records, key=rk):
        sid = r.get("_sid", "")
        ov = overlay.get(sid, {})
        ovs = "/".join(x for x in [ov.get("state") or "", ov.get("status") or ""] if x) or "-"
        p("| {} | {} | {} | {} | {} | {} | {} | {} |".format(
            short(sid) + (" (legacy)" if r.get("_legacy") else ""),
            san(r.get("skill") or "-", 24),
            san(f"{r.get('status') or '-'}/{r.get('state') or '-'}", 32),
            san(ovs, 24),
            san(ov.get("waitingFor") or "-", 24),
            age_m(r.get("last_activity") or r.get("started")),
            san(r.get("cwd") or "-", 60),
            san(pr_by_sid.get(sid, "-"), 12)))
p("")

# --- Attention queue ---
p("## Attention queue")
p("")
attention = []  # (epoch, sid, reason)
sids = {r.get("_sid") for r in records}
for r in records:
    sid = r.get("_sid")
    if (r.get("status") or "") != "active":
        continue
    ov = overlay.get(sid, {})
    ts = epoch(r.get("last_activity") or r.get("started")) or 0
    if ov.get("waitingFor"):
        attention.append((ts, sid, f"waiting for {san(ov.get('waitingFor'), 40)}"))
    elif ov.get("state") == "blocked":
        attention.append((ts, sid, "overlay state blocked"))
# overlay-only rows (no record) that are blocked / waiting
for sid, ov in overlay.items():
    if sid in sids:
        continue
    if ov.get("waitingFor") or ov.get("state") == "blocked":
        attention.append((NOW, sid, f"(no record) {san(ov.get('waitingFor') or 'blocked', 40)}"))
# feed rule: last needs_input/permission_denied newer than the last idle/session_end
last_need, last_idle = {}, {}
for ev in feed:
    sid = ev.get("session"); e = epoch(ev.get("ts")) or 0
    if not sid:
        continue
    if ev.get("event") in ("needs_input", "permission_denied"):
        last_need[sid] = max(last_need.get(sid, 0), e)
    elif ev.get("event") in ("idle", "session_end"):
        last_idle[sid] = max(last_idle.get(sid, 0), e)
for sid, e in last_need.items():
    if e > last_idle.get(sid, -1):
        attention.append((e, sid, "feed: needs_input/permission_denied since last idle"))
# inbox rule
for it in inbox:
    if it.get("status") != "pending":
        continue
    attention.append((epoch(it.get("ts")) or 0, it.get("session") or "", f"inbox {san(it.get('kind') or '-', 20)}: {san(it.get('text'), 80)}"))
attention.sort(key=lambda t: t[0])
if not attention:
    p("HEARTBEAT_OK")
else:
    p("| since | sid | reason |")
    p("|---|---|---|")
    for e, sid, reason in attention:
        since = datetime.fromtimestamp(e, timezone.utc).strftime("%H:%M:%SZ") if e else "?"
        p(f"| {since} | {short(sid)} | {reason} |")
p("")

# --- Locks ---
p("## Locks")
p("")
if not locks:
    p("_No `*.lock` files under `.cc-sessions/`._")
else:
    p("| lock | owner | age (m) |")
    p("|---|---|---|")
    for l in locks:
        p(f"| {san(l.get('path'), 60)} | {short(l.get('owner') or '?')} | {int(l.get('age_s') or 0) // 60} |")
p("")

# --- Inbox ---
p("## Inbox")
p("")
pending = [i for i in inbox if i.get("status") == "pending"]
if not pending:
    p("_No pending inbox items._")
else:
    p("| ts | id | kind | sid | text |")
    p("|---|---|---|---|---|")
    for i in pending:
        p(f"| {san(i.get('ts'), 20)} | {san(i.get('id'), 12)} | {san(i.get('kind'), 16)} | {short(i.get('session'))} | {san(i.get('text'), 120)} |")
p("")

# --- Timeline ---
p("## Timeline")
p("")
if not feed:
    p("_Activity feed empty._")
else:
    p("| time | sid | event | message |")
    p("|---|---|---|---|")
    for ev in feed:
        t = str(ev.get("ts") or "")
        t = t.split("T")[1][:8] if "T" in t else san(t, 8)
        p(f"| {san(t, 8)} | {short(ev.get('session'))} | {san(ev.get('event'), 24)} | {san(ev.get('message'), 120)} |")
p("")

# --- Token estimate ---
p("## Token estimate (per session)")
p("")
p("_Estimate only: transcript size on disk / 4 ≈ tokens; `context-char-count` is this checkout's per-session counter (reset by session-start.sh)._")
p("")
if not records:
    p("_No sessions._")
else:
    p("| sid | transcript (KB) | ~tokens | context-char-count |")
    p("|---|---|---|---|")
    for r in records:
        sid = r.get("_sid")
        kb = sizes.get(sid)
        tok = "-" if kb is None else f"~{(kb * 1024) // 4:,}"
        p(f"| {short(sid)} | {'-' if kb is None else kb} | {tok} | {ctx_chars or '-'} |")
p("")
sys.stdout.write("\n".join(out))
PYEOF

mkdir -p "$(dirname "$OUT")"
blitz_atomic_write "$OUT" "$(cat "$WORK/dashboard.md")"
cat "$OUT"
echo
echo "sessions-dashboard: wrote $OUT" >&2

if [ "$HTML" -eq 1 ]; then
  . "$LIB_DIR/html.sh"
  emit_html "$OUT"     # trusted tier: fields sanitized above; converter output scrubbed by sanitize_html
fi
exit 0
