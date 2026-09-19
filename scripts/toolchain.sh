#!/usr/bin/env bash
# toolchain.sh — resolve a language toolchain lane to an argv, from data.
#
# The plugin ships templates/toolchain.default.json. Rows are data; this script
# is the only executor. Adding a language means adding rows there, never adding
# a script here. That is what makes the post-edit hooks language-agnostic.
#
# Trust: the table is PLUGIN content. A project may disable rows or reorder
# preference through .blitz-toolchain.json, but may never supply a `cmd`:
# per security.md TB-1 the checkout is untrusted inbound data, and an argv read
# from repo content would be arbitrary execution on every edit.
#
# Usage:
#   toolchain.sh detect [--refresh]     write/refresh .cc-sessions/toolchain.json
#   toolchain.sh stacks                 print detected stack ids, one per line
#   toolchain.sh resolve <lane> <file>  print the winning row as JSON, or nothing
#   toolchain.sh run <lane> <file>      resolve then exec; stdout is tool output
#   toolchain.sh explain                human-readable table of what resolved
#
# Exit: 0 when a row ran or none applied; the tool's own status is reported in
# the `run` JSON on stderr, never as this script's exit code.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SELF_DIR/.." && pwd)}"
TABLE="${BLITZ_TOOLCHAIN_TABLE:-$PLUGIN_ROOT/templates/toolchain.default.json}"
CACHE=".cc-sessions/toolchain.json"
OVERRIDE=".blitz-toolchain.json"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$TABLE" ] || exit 0

# --- stack detection -------------------------------------------------------

_marker_present() {
  case "$1" in
    *'*'*) compgen -G "$1" >/dev/null 2>&1 ;;
    *)     [ -e "$1" ] ;;
  esac
}

detect_stacks() {
  # One line per (stack, marker) PAIR. Joining a stack's markers into a single
  # field with a newline separator would split across this line-based read, so
  # only each stack's first marker was ever tested.
  local id m
  while IFS=$'\t' read -r id m; do
    [ -z "$id" ] || [ -z "$m" ] && continue
    _marker_present "$m" && printf '%s\n' "$id"
  done < <(jq -r '.stacks[] | .id as $i | .markers[] | "\($i)\t\(.)"' "$TABLE" 2>/dev/null) \
    | awk '!seen[$0]++'
}

# --- detection artifact ----------------------------------------------------
#
# Stack detection is a handful of file-existence tests, so it is recomputed on
# every call and never served from a TTL cache. A cached stack list goes stale
# the moment someone adds a Cargo.toml, and a ratchet that does not notice a
# new language for an hour is worse than no cache saving. The artifact below is
# written for `doctor` and `check` to read, not to be read back by this script.

cmd_detect() {
  local stacks tmp
  stacks=$(detect_stacks | sort -u | jq -R . | jq -sc .)
  [ -z "$stacks" ] && stacks='[]'
  mkdir -p .cc-sessions 2>/dev/null || true
  tmp=$(mktemp -p .cc-sessions .toolchain.XXXXXX 2>/dev/null) || { jq -nc --argjson s "$stacks" '{stacks:$s}'; return 0; }
  jq -n --argjson stacks "$stacks" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg tbl "$TABLE" \
    '{"$schema":"blitz-toolchain-cache/1.0", detected_at:$ts, table:$tbl, stacks:$stacks}' > "$tmp" \
    && mv "$tmp" "$CACHE" || rm -f "$tmp"
  cat "$CACHE" 2>/dev/null || jq -nc --argjson s "$stacks" '{stacks:$s}'
}

cmd_stacks() { detect_stacks | sort -u; }

# --- override (restricted schema: disable + prefer only) -------------------

_disabled_ids() {
  [ -f "$OVERRIDE" ] || return 0
  jq -r '(.disable // [])[]' "$OVERRIDE" 2>/dev/null || true
}
_preferred_ids() {
  local lane="$1"
  [ -f "$OVERRIDE" ] || return 0
  jq -r --arg l "$lane" '((.prefer // {})[$l] // [])[]' "$OVERRIDE" 2>/dev/null || true
}

# --- row resolution --------------------------------------------------------

_probe_ok() {
  local row="$1" allow_exit probe
  probe=$(printf '%s' "$row" | jq -r '(.probe // []) | @tsv' 2>/dev/null)
  [ -z "$probe" ] && return 0
  allow_exit=$(printf '%s' "$row" | jq -r '.probeAllowExit // false')
  local -a argv=(); IFS=$'\t' read -r -a argv <<< "$probe"
  [ "${#argv[@]}" -eq 0 ] && return 0
  command -v "${argv[0]}" >/dev/null 2>&1 || [ -x "${argv[0]}" ] || return 1
  if [ "$allow_exit" = "true" ]; then "${argv[@]}" >/dev/null 2>&1; return 0; fi
  "${argv[@]}" >/dev/null 2>&1
}

_when_ok() {
  local row="$1" f
  local whens; whens=$(printf '%s' "$row" | jq -r '(.when // [])[]' 2>/dev/null)
  if [ -n "$whens" ]; then
    local hit=0
    while IFS= read -r f; do [ -n "$f" ] && _marker_present "$f" && { hit=1; break; }; done <<< "$whens"
    [ "$hit" -eq 1 ] || return 1
  fi
  local deps; deps=$(printf '%s' "$row" | jq -r '(.whenDep // [])[]' 2>/dev/null)
  if [ -n "$deps" ]; then
    [ -f package.json ] || return 1
    local hit=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      jq -e --arg d "$f" '((.devDependencies[$d] // .dependencies[$d]) != null)' package.json >/dev/null 2>&1 && { hit=1; break; }
    done <<< "$deps"
    [ "$hit" -eq 1 ] || return 1
  fi
  return 0
}

cmd_resolve() {
  local lane="$1" file="${2:-}" only_stack="${3:-}"
  [ -z "$lane" ] && return 0
  local stacks
  if [ -n "$only_stack" ]; then
    stacks=$(printf '%s' "$only_stack" | jq -R . | jq -sc .)
  else
    stacks=$(cmd_stacks | jq -R . | jq -sc .)
  fi
  [ -z "$stacks" ] && stacks='[]'
  local disabled; disabled=$(_disabled_ids | jq -R . | jq -sc .); [ -z "$disabled" ] && disabled='[]'
  local prefer;   prefer=$(_preferred_ids "$lane" | jq -R . | jq -sc .); [ -z "$prefer" ] && prefer='[]'

  # Candidate rows: lane's rows whose stack is present, whose match hits the
  # file, and which are not disabled. Preferred ids sort first, table order
  # otherwise.
  local rows
  rows=$(jq -c --arg lane "$lane" --arg file "$file" \
              --argjson stacks "$stacks" --argjson disabled "$disabled" --argjson prefer "$prefer" '
    [ (.lanes[$lane] // [])[]
      | . as $r
      | select(($stacks | index($r.stack)) != null)
      | select(($disabled | index($r.id)) == null)
      | select(($file == "") or ($r.match == null) or ($file | test($r.match)))
    ]
    | sort_by(. as $r | ($prefer | index($r.id)) // 9999)
    | .[]' "$TABLE" 2>/dev/null)

  [ -z "$rows" ] && return 0
  local row
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    _when_ok "$row" || continue
    _probe_ok "$row" || continue
    printf '%s\n' "$row"
    return 0
  done <<< "$rows"
  return 0
}

# _argv_from ROW_JSON FILE -> tab-separated argv with {file} substituted
_argv_from() {
  printf '%s' "$1" | jq -r --arg file "${2:-}" '(.cmd // []) | map(if . == "{file}" then $file else . end) | @tsv'
}

# cmd_run LANE [FILE]
#
# With a FILE, runs the one row that resolves for it. WITHOUT a file, runs the
# lane once per detected stack: that is what a whole-project check wants in a
# polyglot repo, where "the typechecker" is mypy AND cargo check AND tsc. The
# registry's det-11/det-12 rows call it this way. Output is concatenated; the
# resolution line for each row goes to stderr.
cmd_run() {
  local lane="$1" file="${2:-}" row argv_tsv out status
  if [ -z "$file" ]; then
    local st ext
    while IFS= read -r st; do
      [ -z "$st" ] && continue
      ext=$(_rep_ext "$st")
      row=$(cmd_resolve "$lane" "$ext" "$st")
      [ -z "$row" ] && continue
      argv_tsv=$(_argv_from "$row" "$ext")
      [ -z "$argv_tsv" ] && continue
      local -a sargv=(); IFS=$'\t' read -r -a sargv <<< "$argv_tsv"
      [ "${#sargv[@]}" -eq 0 ] && continue
      out=$("${sargv[@]}" 2>&1); status=$?
      printf '%s' "$out"
      printf '%s\n' "$row" | jq -c --argjson st "$status" '{id:.id, stack:.stack, exit:$st}' >&2
    done < <(cmd_stacks)
    return 0
  fi
  row=$(cmd_resolve "$lane" "$file")
  [ -z "$row" ] && return 0
  argv_tsv=$(_argv_from "$row" "$file")
  [ -z "$argv_tsv" ] && return 0
  local -a argv=(); IFS=$'\t' read -r -a argv <<< "$argv_tsv"
  out=$("${argv[@]}" 2>&1); status=$?
  printf '%s' "$out"
  printf '%s\n' "$row" | jq -c --argjson st "$status" '{id:.id, stack:.stack, exit:$st}' >&2
  return 0
}

# cmd_lanes — one line per (lane, stack) that actually resolves, in ONE
# process. detect-stack.sh injects this into skill context, so spawning a
# resolve per extension-lane pair would stall every skill that reads the
# stack profile.
_rep_ext() {
  case "$1" in
    node) echo "a.ts" ;; deno) echo "a.ts" ;; python) echo "a.py" ;;
    rust) echo "a.rs" ;; go) echo "a.go" ;; ruby) echo "a.rb" ;;
    jvm) echo "a.java" ;; dotnet) echo "a.cs" ;; php) echo "a.php" ;;
    elixir) echo "a.ex" ;; swift) echo "a.swift" ;; *) echo "" ;;
  esac
}
cmd_lanes() {
  local st lane ext row id
  while IFS= read -r st; do
    [ -z "$st" ] && continue
    ext=$(_rep_ext "$st"); [ -z "$ext" ] && continue
    for lane in format lint typecheck test build; do
      row=$(cmd_resolve "$lane" "$ext" "$st")
      [ -z "$row" ] && continue
      id=$(printf '%s' "$row" | jq -r '.id')
      printf '%s\t%s\t%s\n' "$lane" "$st" "$id"
    done
  done < <(cmd_stacks)
}

cmd_explain() {
  local lane f
  printf 'stacks: %s\n' "$(cmd_stacks | paste -sd, - 2>/dev/null)"
  for lane in format lint typecheck test build; do
    printf '%s:\n' "$lane"
    for f in a.ts a.vue a.py a.rs a.go a.rb a.cs a.php a.ex a.swift a.java; do
      local row; row=$(cmd_resolve "$lane" "$f")
      [ -n "$row" ] && printf '  %-10s -> %s\n' "$f" "$(printf '%s' "$row" | jq -r '.id')"
    done
  done
}

case "${1:-}" in
  detect)  shift; cmd_detect "${1:-}" ;;
  lanes)   shift; cmd_lanes ;;
  stacks)  shift; cmd_stacks "${1:-}" ;;
  resolve) shift; cmd_resolve "${1:-}" "${2:-}" "${3:-}" ;;
  run)     shift; cmd_run "${1:-}" "${2:-}" ;;
  explain) shift; cmd_explain ;;
  *) echo "usage: toolchain.sh {detect|stacks|lanes|resolve <lane> <file> [stack]|run <lane> [file]|explain}" >&2; exit 2 ;;
esac
exit 0
