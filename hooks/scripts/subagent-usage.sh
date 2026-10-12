#!/usr/bin/env bash
# subagent-usage.sh (SubagentStop): record a finished subagent's exact token usage and cost.
#
# The subagent's transcript (stdin `agent_transcript_path`) carries every API
# response's `usage`: input, output, cache reads and 5-minute / 1-hour cache
# writes, with the model. Streaming writes one line per content block with the
# same message id: input and cache counts are final on every line, but
# `output_tokens` is a running snapshot unless the line carries `stop_reason`.
# Lines are grouped by `message.id`, keeping the highest output count; a response
# with no final line makes the row's output and cost a lower bound
# (`output_final: false`). The blitz-guard mod, when installed, records the final
# per-agent counts from `turn.complete`, and the dashboard prefers its output. Each model is priced from _lib/model-prices.json; Haiku's long-context
# multiplier applies per request. One line is appended to
# .cc-sessions/agent-usage.jsonl; /blitz:sessions dashboard sums it per task.
#
# Plan and task come from the subagent's first prompt (`PLAN: <slug>` and the
# first `T-nnn`), which blitz spawn prompts carry; a subagent without them is
# recorded under plan "-". Advisory and async: exits 0 on every path.
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat 2>/dev/null || echo "{}")
command -v jq >/dev/null 2>&1 || exit 0
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty' 2>/dev/null || true)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0
# A transcript is Claude Code's own file, but cap the read: 64 MiB is far past any subagent run.
[ "$(wc -c < "$TRANSCRIPT")" -le 67108864 ] || exit 0

AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || echo "")
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
PRICES="$(dirname "$0")/_lib/model-prices.json"

ROOT=$(blitz_find_root || true)
DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
mkdir -p "$DIR"

ROW=$(jq -Rsc --slurpfile prices "$PRICES" \
  --arg agent_id "$AGENT_ID" --arg agent "$AGENT_TYPE" --arg session "$SESSION_ID" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  def safe: tostring | gsub("[^A-Za-z0-9_.:/-]"; "") | .[0:80];
  [split("\n")[] | select(length > 0) | (try fromjson catch null) | select(type == "object")] as $lines
  # first prompt text, for plan/task attribution
  | ([$lines[] | select(.type == "user") | .message.content
      | if type == "string" then . elif type == "array" then (map(select(.type? == "text") | .text) | join("\n")) else "" end]
     | first // "") as $prompt
  | ($prompt | (capture("PLAN:\\s*(?<p>[A-Za-z0-9_.-]+)") // {p: "-"}).p) as $plan
  | ($prompt | (capture("\\b(?<t>T-[0-9]{3,4})\\b") // {t: "-"}).t) as $task
  # one usage per API response
  | [$lines[] | select(.type == "assistant" and (.message.usage? != null) and (.message.id? != null))
      | {id: .message.id, model: (.message.model // "unknown"), u: .message.usage, final: (.message.stop_reason != null)}]
  | group_by(.id)
  | [.[] | (max_by(.u.output_tokens // 0)) + {final: (map(.final) | any)}] as $msgs
  | ($prices[0].models) as $table
  | [$msgs[] | . as $m
      | ($table | map(select(.match as $k | $m.model | ascii_downcase | contains($k))) | first) as $p
      | ($m.u.cache_creation.ephemeral_1h_input_tokens // 0) as $w1h
      | (($m.u.cache_creation.ephemeral_5m_input_tokens // (($m.u.cache_creation_input_tokens // 0) - $w1h)) | if . < 0 then 0 else . end) as $w5m
      | ($m.u.input_tokens // 0) as $in | ($m.u.output_tokens // 0) as $out | ($m.u.cache_read_input_tokens // 0) as $cr
      | (if $p != null and ($p.long_context_threshold // null) != null and ($in + $cr + $w5m + $w1h) > $p.long_context_threshold
         then $p.long_context_multiplier else 1 end) as $mult
      | {model: $m.model, input: $in, output: $out, cache_read: $cr, cache_write_5m: $w5m, cache_write_1h: $w1h,
         priced: ($p != null), final: $m.final,
         cost: (if $p == null then 0 else
           (($in * $p.input + $out * $p.output + $cr * $p.cache_read + $w5m * $p.cache_write_5m + $w1h * $p.cache_write_1h) * $mult / 1000000) end)}]
  | select(length > 0)
  | {ts: $ts, source: "transcript", session: ($session | safe), agent_id: ($agent_id | safe), agent: ($agent | safe),
     plan: ($plan | safe), task: ($task | safe),
     models: ([.[].model] | unique | map(safe)),
     requests: length,
     input: (map(.input) | add), output: (map(.output) | add), cache_read: (map(.cache_read) | add),
     cache_write_5m: (map(.cache_write_5m) | add), cache_write_1h: (map(.cache_write_1h) | add),
     tokens: (map(.input + .output + .cache_read + .cache_write_5m + .cache_write_1h) | add),
     cost_usd: ((map(.cost) | add) * 1000000 | round / 1000000),
     output_final: (map(.final) | all),
     unpriced_models: ([.[] | select(.priced | not) | .model] | unique | map(safe))}
' "$TRANSCRIPT" 2>/dev/null || true)

[ -n "$ROW" ] && printf '%s\n' "$ROW" >> "$DIR/agent-usage.jsonl"
exit 0
