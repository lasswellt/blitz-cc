#!/usr/bin/env bash
# _lib/common.sh — Shared helper library for blitz hook scripts.
#
# Source this file near the top of each hook script:
#   . "$(dirname "$0")/_lib/common.sh"
#
# Provides: blitz_find_root, blitz_extract, blitz_session_id,
#           blitz_log_event, blitz_live_worktree_paths, blitz_atomic_write,
#           blitz_session_record_path, blitz_session_record_find,
#           blitz_session_update, blitz_inbox_append, blitz_inbox_post
#
# Designed for set -euo pipefail callers. Every function handles its own
# error paths. Global fallback vars: SESSION_ID, SESSIONS_DIR, INPUT.

# BLITZ_INJECTION_RX — canonical prompt-injection marker pattern (POSIX ERE, for grep -iE).
# Single source of truth for BOTH the live echo path (session-start.sh) and the
# persistent-state classifier (startup-validate.sh) so the two never drift (SEC-R2-03).
# UNION of the historical patterns from both scripts: instruction verbs, role
# directives, tag/role smuggling (HTML-style AND ChatML <|im_start|>/<|im_end|>),
# tool-invocation strings, and secret/exfil markers. Case-insensitivity is the
# caller's responsibility (always pair with grep -i). Keep ERE-safe: `\|` is a
# literal pipe, `\.` a literal dot — both escaped for grep -E.
BLITZ_INJECTION_RX='(ignore (the )?(previous|above)|you are now|disregard (all|previous|the)|new instructions:|system:|</?(system|tool|assistant|im_start|im_end)>|tool_call|<\|.*\|>|exfiltrat|\.aws/credentials|BEGIN (RSA|OPENSSH|PRIVATE))'

# blitz_find_root [start_dir]
# Walk up from start_dir (or pwd) looking for .claude-plugin/.
# Prints absolute project root. Falls back to pwd on miss; returns 1.
blitz_find_root() {
  local dir
  dir="$(cd "${1:-$(pwd)}" 2>/dev/null && pwd || pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.claude-plugin" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  printf '%s\n' "$(pwd)"
  return 1
}

# blitz_extract field [json_string]
# Extract a JSON field from json_string (default: $INPUT).
# Tries top-level first (.field), then nested under tool_input (.tool_input.field).
# Prints empty string on miss. Safe under set -e.
# Field name validated against [a-zA-Z_][a-zA-Z0-9_]* to prevent jq filter injection
# in case a caller passes a non-literal field name.
blitz_extract() {
  local field="$1" input="${2:-${INPUT:-}}"
  case "$field" in
    [a-zA-Z_]*) ;;  # valid identifier prefix
    *) return 0 ;;
  esac
  case "$field" in
    *[!a-zA-Z0-9_]*) return 0 ;;  # contains non-identifier char
  esac
  local val
  val=$(printf '%s' "$input" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null) \
    && [ -n "$val" ] && { printf '%s\n' "$val"; return 0; } || true
  val=$(printf '%s' "$input" | jq -r --arg f "$field" '.tool_input[$f] // empty' 2>/dev/null) \
    && { printf '%s\n' "$val"; return 0; } || true
  return 0
}

# blitz_session_id
# Emit a cli-<8hex> session ID derived from timestamp.
# Falls back gracefully when md5sum / sha256sum absent (e.g., minimal containers).
blitz_session_id() {
  local raw ts
  ts=$(date +%Y%m%d%H%M 2>/dev/null || date +%s)
  raw=$(
    printf '%s' "$ts" | md5sum 2>/dev/null | cut -c1-8 ||
    printf '%s' "$ts" | sha256sum 2>/dev/null | cut -c1-8 ||
    printf '%s' "$ts" | cut -c-8 ||
    echo "unknown"
  ) 2>/dev/null
  printf 'cli-%s' "${raw:-unknown}"
}

# blitz_log_event skill event message [detail_json]
# Append one JSON line to the activity feed via jq (guaranteed valid JSON).
# Uses global SESSION_ID if set; derives one via blitz_session_id() otherwise.
# Uses global SESSIONS_DIR if set; derives from blitz_find_root() otherwise.
blitz_log_event() {
  local skill="${1:-hook}" event="${2:-event}" message="${3:-}" detail="${4:-}"
  # NOTE: `${4:-{}}` is NOT safe here — bash closes the expansion at the first `}`,
  # leaving a stray `}` appended to any caller-supplied detail (invalid JSON, event lost).
  [ -n "$detail" ] || detail='{}'
  local ts session_id sessions_dir
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  session_id="${SESSION_ID:-$(blitz_session_id)}"
  sessions_dir="${SESSIONS_DIR:-$(blitz_find_root)/.cc-sessions}"
  mkdir -p "$sessions_dir" 2>/dev/null || true
  jq -nc \
    --arg ts "$ts" \
    --arg session "$session_id" \
    --arg sk "$skill" \
    --arg ev "$event" \
    --arg msg "$message" \
    --argjson det "$detail" \
    '{ts:$ts,session:$session,skill:$sk,event:$ev,message:$msg,detail:$det}' \
    >> "${sessions_dir}/activity-feed.jsonl" 2>/dev/null || true
}

# blitz_live_worktree_paths
# Emit absolute worktree paths owned by background sessions tracked by the
# native agent view (`claude agents`, CC >=2.1.141). One path per line.
#
# Best-effort DATA-LOSS GUARD: a background session edits inside its own
# `.claude/worktrees/<id>` worktree, where uncommitted work lives. Native agent
# view auto-isolates background sessions there (see worktree-lifecycle.md
# §Interop), so the same `.claude/worktrees/` dir now holds BOTH blitz
# `Agent({isolation:"worktree"})` worktrees AND native background-session
# worktrees. Callers (worktree-prune, cleanup) MUST skip any worktree whose
# path appears here, regardless of merge-status / age / --force — removing it
# would destroy a live session's uncommitted changes.
#
# Prints nothing and returns 0 when the `claude` CLI or `--json` is unavailable
# (older CC, Bedrock/Vertex, or agent view disabled). Never blocks the caller.
blitz_live_worktree_paths() {
  command -v claude >/dev/null 2>&1 || return 0
  local json
  json=$(claude agents --json 2>/dev/null) || return 0
  [ -n "$json" ] || return 0
  printf '%s' "$json" | jq -r 'if type=="array" then .[]?.cwd // empty else empty end' 2>/dev/null || true
  return 0
}

# blitz_atomic_write target content
# Write content to target via mktemp+mv (atomic).
# Falls back to direct write if mktemp fails.
blitz_atomic_write() {
  local target="$1" content="$2"
  local dir tmp
  dir=$(dirname "$target")
  if tmp=$(mktemp -p "$dir" .blitz-atomic.XXXXXX 2>/dev/null || mktemp 2>/dev/null); then
    printf '%s' "$content" > "$tmp" && mv "$tmp" "$target" || { rm -f "$tmp" 2>/dev/null; return 1; }
  else
    printf '%s' "$content" > "$target"
  fi
}

# --- Session records + inbox (E-040 S2; record writer arrives with E-041 S1) ---

# _blitz_sessions_dir
# Print the .cc-sessions/ directory (SESSIONS_DIR override, else <root>/.cc-sessions).
_blitz_sessions_dir() {
  printf '%s\n' "${SESSIONS_DIR:-$(blitz_find_root)/.cc-sessions}"
}

# _blitz_safe_id id
# Return 0 iff id is a safe path component ([A-Za-z0-9_.-]+, no leading dot).
# Guards every helper that turns a stdin-supplied session_id into a path.
_blitz_safe_id() {
  case "${1:-}" in
    ''|.*|*/*) return 1 ;;
    *[!A-Za-z0-9_.-]*) return 1 ;;
  esac
  return 0
}

# blitz_session_record_path sid
# Print the canonical session record path: .cc-sessions/sessions/<sid>.json.
# Prints nothing (returns 1) when sid is unsafe.
blitz_session_record_path() {
  _blitz_safe_id "${1:-}" || return 1
  printf '%s/sessions/%s.json\n' "$(_blitz_sessions_dir)" "$1"
}

# blitz_session_record_find sid
# Print the path of the record that belongs to sid: the canonical path when it
# exists, else the first legacy record `.cc-sessions/<anything>.json` whose
# `.claude_session_id == sid` (skill-written records, session-lifecycle.md §3).
# Prints nothing and returns 1 when no record exists.
blitz_session_record_find() {
  local sid="${1:-}" canonical dir f
  canonical=$(blitz_session_record_path "$sid") || return 1
  if [ -f "$canonical" ]; then printf '%s\n' "$canonical"; return 0; fi
  dir=$(_blitz_sessions_dir)
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    if [ "$(jq -r '.claude_session_id // empty' "$f" 2>/dev/null)" = "$sid" ]; then
      printf '%s\n' "$f"; return 0
    fi
  done
  return 1
}

# blitz_session_update sid jq_filter
# Apply jq_filter to the session record (atomic via blitz_atomic_write).
# No-op (returns 0) when the record is missing or unparsable. The filter runs
# with $now bound to the current ISO-8601 UTC timestamp.
blitz_session_update() {
  local sid="${1:-}" filter="${2:-.}" path now updated
  path=$(blitz_session_record_find "$sid") || return 0
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  updated=$(jq -c --arg now "$now" "$filter" "$path" 2>/dev/null) || return 0
  [ -n "$updated" ] || return 0
  blitz_atomic_write "$path" "$updated" 2>/dev/null || true
  return 0
}

# blitz_inbox_append kind text [session]
# Append one pending item to .cc-sessions/inbox.jsonl:
#   {ts,id:"inb-<8hex>",source:"hook",kind,session,text,status:"pending"}
# text is capped at 200 chars and injection-scanned (BLITZ_INJECTION_RX) —
# a hit stores a quarantine marker instead (same discipline as session-start.sh).
blitz_inbox_append() {
  local kind="${1:-notification}" text="${2:-}" session="${3:-${SESSION_ID:-}}"
  local dir ts id
  dir=$(_blitz_sessions_dir)
  mkdir -p "$dir" 2>/dev/null || true
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  id=$( (od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || true )
  [ -n "$id" ] || id=$(printf '%s%s' "$ts" "$$" | md5sum 2>/dev/null | cut -c1-8) || id="00000000"
  text=$(printf '%s' "$text" | tr -d '\r' | tr '\n' ' ' | cut -c1-200)
  if printf '%s' "$text" | grep -qiE "$BLITZ_INJECTION_RX"; then
    text='[quarantined: suspicious field — see startup-validate.sh]'
  fi
  jq -nc --arg ts "$ts" --arg id "inb-$id" --arg kind "$kind" \
    --arg session "$session" --arg text "$text" \
    '{ts:$ts,id:$id,source:"hook",kind:$kind,session:$session,text:$text,status:"pending"}' \
    >> "$dir/inbox.jsonl" 2>/dev/null || true
}

# blitz_inbox_post text
# Best-effort delivery of one JSON line to the Claude Code messaging socket
# (CC >=2.1.224): writes {"type":"auth","token":$CLAUDE_CODE_MESSAGING_TOKEN}
# then text, each newline-terminated. Transport: socat if present, else a
# python3 one-liner, else no-op. Returns 0 on delivery, 1 otherwise. Never
# blocks longer than ~1s per call.
blitz_inbox_post() {
  local text="${1:-}" sock="${CLAUDE_CODE_MESSAGING_SOCKET:-}" token="${CLAUDE_CODE_MESSAGING_TOKEN:-}"
  [ -n "$text" ] && [ -n "$sock" ] && [ -S "$sock" ] || return 1
  local auth payload
  auth=$(jq -nc --arg t "$token" '{type:"auth",token:$t}' 2>/dev/null) || return 1
  payload=$(printf '%s\n%s\n' "$auth" "$text")
  if command -v socat >/dev/null 2>&1; then
    printf '%s' "$payload" | socat -t1 - "UNIX-CONNECT:$sock" >/dev/null 2>&1 && return 0
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    BLITZ_SOCK="$sock" BLITZ_PAYLOAD="$payload" python3 - <<'PYEOF' >/dev/null 2>&1 && return 0
import os, socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(1.0)
s.connect(os.environ["BLITZ_SOCK"])
s.sendall(os.environ["BLITZ_PAYLOAD"].encode())
s.close()
PYEOF
    return 1
  fi
  return 1
}

# fail rel message
# Emit a "✗ rel: message" line to stderr and set RC=1 in the caller's scope.
# Used by the frontmatter validators (which initialize RC=0 before validating).
fail() {
  printf '  ✗ %s: %s\n' "$1" "$2" >&2
  RC=1
}
