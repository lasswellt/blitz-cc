#!/usr/bin/env bats
# Contract tests for workflows/*.js: the args shape each skill passes is what the script accepts.
# The Workflow runtime is stubbed (agent/parallel/phase/log) so only arg validation and result
# shaping run; no model is called.
load '_helpers'

WF="$HOOKS_DIR/../../workflows"

run_workflow() {  # run_workflow <script> <args-json>
  node --input-type=module -e "
    const fs = await import('node:fs');
    let src = fs.readFileSync('$WF/$1', 'utf8').replace(/^export const meta/m, 'const meta');
    globalThis.args = JSON.parse(process.argv[1]);
    globalThis.phase = () => {}; globalThis.log = () => {};
    globalThis.agent = async (p, o) => ({ prompt: p.slice(0, 20), opts: o });
    globalThis.parallel = async (fns) => Promise.all(fns.map(f => f()));
    globalThis.pipeline = async (items, a, b) => Promise.all(items.map(async i => b(await a(i))));
    const fn = new (Object.getPrototypeOf(async function(){}).constructor)(src + '\n');
    try { console.log(JSON.stringify(await fn())); } catch (e) { console.error(e.message); process.exit(1); }
  " "$2"
}

@test "build-wave accepts {plan, wave, tasks, replySchema} and keys results by id" {
  run run_workflow build-wave.js '{"plan":"demo","wave":1,"tasks":[{"id":"T-001","role":"backend","prompt":"ROLE: backend"},{"id":"T-002","role":"test","prompt":"ROLE: test"}],"replySchema":{"type":"object"}}'
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.wave')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.tasks[1].id')" = "T-002" ]
  [ "$(printf '%s' "$output" | jq -r '.tasks[0].result.opts.agentType')" = "blitz:dev" ]
  [ "$(printf '%s' "$output" | jq -r '.tasks[0].result.opts.isolation')" = "worktree" ]
}

@test "build-wave rejects the old {agents, storySchema} shape with a clear message" {
  run run_workflow build-wave.js '{"wave":1,"agents":[{"role":"backend","prompt":"x"}],"storySchema":{}}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"args.tasks must be a non-empty array"* ]]
}

@test "review-fanout accepts {lenses, criticPrompt, surveySchema, criticSchema}" {
  run run_workflow review-fanout.js '{"lenses":[{"name":"security","prompt":"MODE: survey"}],"sequential":false,"criticPrompt":"MODE: reject","surveySchema":{"type":"object"},"criticSchema":{"type":"object"}}'
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.reviews[0].name')" = "security" ]
  [ "$(printf '%s' "$output" | jq -r '.critic.opts.agentType')" = "blitz:critic" ]
}

@test "audit-sweep accepts {roster, findingsSchema} and types its agents" {
  run run_workflow audit-sweep.js '{"roster":[{"name":"backend-a","prompt":"p"}],"findingsSchema":{"type":"object"}}'
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.agents[0].name')" = "backend-a" ]
  [ "$(printf '%s' "$output" | jq -r '.agents[0].result.opts.agentType')" = "general-purpose" ]
}
