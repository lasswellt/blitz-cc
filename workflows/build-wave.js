export const meta = {
  name: 'build-wave',
  description: 'Dispatch one wave of blitz dev agents in isolated worktrees (build --parallel §Wave)',
  whenToUse: 'Dispatch one wave of blitz dev agents in isolated worktrees (build --parallel §Wave). Only from /blitz:build --parallel when Phase 0 selected the Workflow path. One wave per run; tasks.json, progress.md, the merge-tree pre-check and the wave-boundary commit stay in the skill (main thread).',
  phases: [{ title: 'Wave', detail: 'one blitz:dev per task, isolation: worktree, schema-validated reply' }],
}

// Extracted from skills/build/SKILL.md §Wave (build --parallel). Plugin workflow: runs as
// /blitz:build-wave. The script owns dispatch + schema validation ONLY — no filesystem, no
// clock (timestamp and randomness calls throw here; the skill stamps timestamps after return).
//
// args shape (required):
//   {
//     wave: 2,                                   // wave number (label + return value only)
//     agents: [ { role: 'backend',               // label only; every agent is blitz:dev
//                 prompt: '<11-item spec incl. ROLE: <role> + inlined role file>' }, ... ],
//     storySchema: { type: 'object', properties: {...}, required: [...] },  // per-task reply
//     concurrencyNote: 'optional free text'      // informational; the runtime cap is
//                                                //   CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS
//   }
// Prompts are passed in whole by the skill (ROLE: line included); the script does not build them.
// Returns { wave, agents: [{ role, ok, result }] } — result is null when the agent died,
// was skipped, or hit a terminal API error (the fix loop in /_shared/agents.md §8 handles it main-thread).

if (!args || !Array.isArray(args.agents) || args.agents.length === 0) {
  throw new Error('build-wave: args.agents must be a non-empty array of {role, prompt}')
}
if (!args.storySchema || typeof args.storySchema !== 'object') {
  throw new Error('build-wave: args.storySchema (JSON Schema for the per-task reply) is required')
}
const wave = args.wave ?? 0

phase('Wave')
log(`build-wave: wave ${wave} — ${args.agents.length} agent(s), worktree isolation, schema-validated`)

const results = await parallel(args.agents.map(a => () =>
  agent(a.prompt, {
    label: `${a.role}:w${wave}`,
    phase: 'Wave',
    agentType: 'blitz:dev',
    isolation: 'worktree',
    schema: args.storySchema,
  })))

const agents = results.map((r, i) => ({ role: args.agents[i].role, ok: r !== null, result: r }))
const failed = agents.filter(a => !a.ok).map(a => a.role)
if (failed.length) log(`build-wave: wave ${wave} — ${failed.length} agent(s) returned null: ${failed.join(', ')}`)

return { wave, agents }
