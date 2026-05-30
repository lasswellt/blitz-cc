#!/usr/bin/env bash
# _lib/common.sh — Shared helper library for blitz hook scripts.
#
# Source this file near the top of each hook script:
#   . "$(dirname "$0")/_lib/common.sh"
#
# Provides: blitz_find_root, blitz_extract, blitz_session_id,
#           blitz_log_event, blitz_live_worktree_paths, blitz_atomic_write
#
# Designed for set -euo pipefail callers. Every function handles its own
# error paths. Global fallback vars: SESSION_ID, SESSIONS_DIR, INPUT.

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
  local skill="${1:-hook}" event="${2:-event}" message="${3:-}" detail="${4:-{}}"
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
