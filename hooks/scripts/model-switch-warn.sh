#!/usr/bin/env bash
# model-switch-warn.sh — Advise on PreModelSwitch (E-040 S2)
#
# NEVER blocks (exit 2 would veto the switch). Logs feed event `cache_bust`
# {from,to} and prints a one-line advisory: a model switch resets the prompt
# cache, so model/effort should be set once per session
# (session-lifecycle.md §Context Management).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)
FROM=$(blitz_extract from_model)
TO=$(blitz_extract to_model)

DETAIL=$(jq -nc --arg f "$FROM" --arg t "$TO" '{from:$f,to:$t}')
blitz_log_event "hook" "cache_bust" "Model switch ${FROM:-?} -> ${TO:-?}" "$DETAIL"

echo "[blitz] model switch ${FROM:-?} -> ${TO:-?} resets the prompt cache; set model/effort once per session (see session-lifecycle.md §Context Management)"

exit 0
