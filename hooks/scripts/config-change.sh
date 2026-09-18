#!/usr/bin/env bash
# config-change.sh — Re-validate persistent state on ConfigChange (E-040 S2)
#
# Input: {source: user_settings|project_settings|local_settings|policy_settings|skills}
# A settings/skills change is a TB-2 boundary event: re-run the deterministic
# persistent-state classifier (startup-validate.sh --strict --quiet), swallow
# its stdout, and log feed event `config_change` {source, validate: pass|fail}.
# Always exit 0 (never blocks the config change itself).
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
ROOT=$(blitz_find_root || true)
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

SESSION_ID=$(blitz_extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=$(blitz_session_id)
SOURCE=$(blitz_extract source)

RESULT="pass"
VALIDATOR="$(dirname "$0")/startup-validate.sh"
if [ -f "$VALIDATOR" ]; then
  bash "$VALIDATOR" --strict --quiet >/dev/null 2>&1 </dev/null || RESULT="fail"
else
  RESULT="skipped"
fi

DETAIL=$(jq -nc --arg s "$SOURCE" --arg r "$RESULT" '{source:$s,validate:$r}')
blitz_log_event "hook" "config_change" "Config changed (${SOURCE:-unknown}); startup-validate: ${RESULT}" "$DETAIL"
[ "$RESULT" = "fail" ] && echo "[blitz] config change (${SOURCE:-unknown}): startup-validate --strict found issues in .cc-sessions/ — run hooks/scripts/startup-validate.sh" || true

exit 0
