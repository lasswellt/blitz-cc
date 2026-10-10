#!/usr/bin/env bats
# Tests for hooks/scripts/subagent-usage.sh (SubagentStop: exact per-subagent usage and cost)

load '_helpers'

setup()    { command -v jq >/dev/null || skip "jq not installed"; setup_fake_repo; TR="$FAKE_REPO/agent.jsonl"; : > "$TR"; }
teardown() { teardown_fake_repo; }

line() {  # line <msg-id> <model> <in> <out> <cache_read> <w5m> <w1h> <stop|null>
  jq -nc --arg id "$1" --arg m "$2" --argjson i "$3" --argjson o "$4" --argjson cr "$5" --argjson w5 "$6" --argjson w1 "$7" --argjson st "$8" \
    '{type:"assistant", message:{id:$id, model:$m, stop_reason:$st, content:[{type:"text",text:"x"}],
      usage:{input_tokens:$i, output_tokens:$o, cache_read_input_tokens:$cr, cache_creation_input_tokens:($w5+$w1),
             cache_creation:{ephemeral_5m_input_tokens:$w5, ephemeral_1h_input_tokens:$w1}}}}' >> "$TR"
}
prompt() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:$t}}' >> "$TR"; }
run_usage() { run_hook "subagent-usage.sh" "$(jq -nc --arg p "$TR" '{session_id:"s1", agent_id:"ag1", agent_type:"blitz:dev", agent_transcript_path:$p}')"; }
row() { jq -c "$1" .cc-sessions/agent-usage.jsonl; }

@test "dedupes streaming lines by message id and prices every token class exactly" {
  prompt $'PLAN: checkout\nT-004 Wire the store\nROLE: backend'
  line m1 claude-sonnet-5-5 10 40 1000000 100000 0 null      # first content block: running snapshot
  line m1 claude-sonnet-5-5 10 1000 1000000 100000 0 '"tool_use"'   # final line of the same response
  run_usage
  [ "$status" -eq 0 ]
  [ "$(row '.requests')" = "1" ]
  [ "$(row '.output')" = "1000" ]
  [ "$(row '.plan + "/" + .task')" = '"checkout/T-004"' ]
  # 10*2 + 1000*10 + 1e6*0.10 + 1e5*2.5 per Mtok = 0.00002 + 0.01 + 0.10 + 0.25
  [ "$(row '.cost_usd')" = "0.36002" ]
  [ "$(row '.output_final')" = "true" ]
}

@test "1h cache writes are priced at 2x input and Opus rates apply by model id" {
  line m1 claude-opus-5-5 0 0 0 0 1000000 '"end_turn"'
  run_usage
  [ "$(row '.cost_usd')" = "8" ]
}

@test "Haiku over 100K input tokens bills every rate at 5x" {
  line m1 claude-haiku-5-5 50000 1000 60000 0 0 '"end_turn"'
  run_usage
  # (50000*0.10 + 1000*0.50 + 60000*0.005) * 5 / 1e6 = 0.029
  [ "$(row '.cost_usd')" = "0.029" ]
}

@test "a response with no final line makes output a lower bound" {
  line m1 claude-sonnet-5-5 10 40 0 0 0 null
  line m2 claude-sonnet-5-5 10 99 0 0 0 '"end_turn"'
  run_usage
  [ "$(row '.output_final')" = "false" ]
  [ "$(row '.requests')" = "2" ]
}

@test "unknown models are counted but not priced, and named" {
  line m1 some-other-model 1000 1000 0 0 0 '"end_turn"'
  run_usage
  [ "$(row '.cost_usd')" = "0" ]
  [ "$(row '.unpriced_models[0]')" = '"some-other-model"' ]
}

@test "missing or empty transcript writes nothing and exits 0" {
  run_hook "subagent-usage.sh" '{"agent_id":"x","agent_transcript_path":"/nonexistent/file.jsonl"}'
  [ "$status" -eq 0 ]
  run_usage
  [ "$status" -eq 0 ]
  [ ! -s .cc-sessions/agent-usage.jsonl ]
}

@test "prompt-derived identifiers are stripped to safe characters" {
  prompt 'PLAN: demo$(rm)x T-0042'
  line m1 claude-sonnet-5-5 1 1 0 0 0 '"end_turn"'
  run_usage
  [ "$(row '.plan')" = '"demo"' ]
  [ "$(row '.task')" = '"T-0042"' ]
}
