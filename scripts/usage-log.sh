#!/usr/bin/env bash
# usage-log.sh — append one blitz agent's usage to .cc-sessions/agent-usage.jsonl.
#
# The main thread calls it after each blitz agent replies, with the numbers the
# Agent result's usage block reports (total tokens, tool uses, duration).
# /usage and the status line cover the main conversation only, so this ledger is
# the per-task record `sessions dashboard` sums. Exact dollars come from
# `claude -p --output-format json` (total_cost_usd) or the OpenTelemetry
# claude_code.cost.usage metric; this ledger holds tokens.
#
# Usage:
#   usage-log.sh --agent blitz:dev --model sonnet --effort medium \
#                --tokens 48211 [--tool-uses 31] [--duration-ms 182000] \
#                [--plan <slug>] [--task T-004] [--skill build]
# Exit: 0 appended · 2 bad arguments (nothing written)
set -euo pipefail
. "$(dirname "$0")/../hooks/scripts/_lib/common.sh"

AGENT="" MODEL="" EFFORT="" TOKENS="" TOOL_USES=0 DURATION=0 PLAN="" TASK="" SKILL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    --tokens) TOKENS="${2:-}"; shift 2 ;;
    --tool-uses) TOOL_USES="${2:-}"; shift 2 ;;
    --duration-ms) DURATION="${2:-}"; shift 2 ;;
    --plan) PLAN="${2:-}"; shift 2 ;;
    --task) TASK="${2:-}"; shift 2 ;;
    --skill) SKILL="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "usage-log: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$AGENT" ] && [ -n "$MODEL" ] && [ -n "$TOKENS" ] || { echo "usage-log: --agent, --model and --tokens are required" >&2; exit 2; }
for n in "$TOKENS" "$TOOL_USES" "$DURATION"; do
  case "$n" in ''|*[!0-9]*) echo "usage-log: token, tool-use and duration counts are integers" >&2; exit 2 ;; esac
done
# Identifiers end up in a dashboard: keep them to safe characters (TB-1).
safe() { printf '%s' "$1" | tr -cd 'A-Za-z0-9_.:/-' | cut -c1-80; }

ROOT=$(blitz_find_root || true)
DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
mkdir -p "$DIR"
jq -nc \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg agent "$(safe "$AGENT")" --arg model "$(safe "$MODEL")" \
  --arg effort "$(safe "$EFFORT")" --arg plan "$(safe "$PLAN")" --arg task "$(safe "$TASK")" --arg skill "$(safe "$SKILL")" \
  --argjson tokens "$TOKENS" --argjson tool_uses "$TOOL_USES" --argjson duration_ms "$DURATION" \
  '{ts:$ts, agent:$agent, model:$model, effort:$effort, plan:$plan, task:$task, skill:$skill,
    tokens:$tokens, tool_uses:$tool_uses, duration_ms:$duration_ms}' >> "$DIR/agent-usage.jsonl"
