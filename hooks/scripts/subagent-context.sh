#!/usr/bin/env bash
# subagent-context.sh — SubagentStart. Injects the invariant half of the spawn
# spec into blitz's file-producing agents.
#
# Why a hook and not the prompt: the never-edit list, reply contract, commit
# format, output style, stop conditions and mock policy are identical on every
# spawn. Injected here they are byte-identical per spawn, and the platform
# leaves the subagent's prompt cache intact when it re-injects after the
# subagent's own auto-compaction. The variable half (task id, ROLE, SCOPE_FILES,
# verify[], budget) stays in the spawn prompt.
#
# STATIC BY CONSTRUCTION: never interpolate a timestamp, session id, or command
# output into additionalContext. A byte that changes per spawn defeats the point.
#
# SubagentStart cannot block a spawn; this hook only adds context. Always exits 0.
set -uo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
[ "${BLITZ_DISABLE_SPAWN_INVARIANT:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

AGENT_TYPE=$(blitz_extract agent_type)
case "$AGENT_TYPE" in
  blitz:dev|blitz:test-writer) ;;
  *) exit 0 ;;
esac

INVARIANT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/skills/_shared/spawn-invariant.md"
[ -f "$INVARIANT" ] || exit 0

jq -nc --rawfile ctx "$INVARIANT" \
  '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: $ctx}}' \
  2>/dev/null || exit 0
exit 0
