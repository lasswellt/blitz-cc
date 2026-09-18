export const meta = {
  name: 'sprint-wave',
  description: 'Dispatch one dependency-ordered wave of blitz dev agents in isolated worktrees (sprint-dev §2.3-W)',
  whenToUse: 'Only from /blitz:sprint-dev when §2.0 selected the Workflow path. One wave per run; STATE.md, carry-forward and the wave-boundary commit stay in the skill (main thread).',
  phases: [{ title: 'Wave', detail: 'one agent per role, isolation: worktree, schema-validated reply' }],
}

// Extracted from skills/sprint-dev/SKILL.md §2.3-W (E-045 S3). Plugin workflow: runs as
// /blitz:sprint-wave. The script owns dispatch + schema validation ONLY — no filesystem, no
// clock (timestamp and randomness calls throw here; the skill stamps timestamps after return).
//
// args shape (required):
//   {
//     wave: 2,                                   // wave number (label + return value only)
//     agents: [ { role: 'backend-dev',           // agentType becomes 'blitz:<role>'
//                 prompt: '<14-item spec + OUTPUT STYLE snippet>' }, ... ],
//     storySchema: { type: 'object', properties: {...}, required: [...] },
//     concurrencyNote: 'optional free text'      // informational; the runtime cap is
//                                                //   CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS
//   }
// Returns { wave, agents: [{ role, ok, result }] } — result is null when the agent died,
// was skipped, or hit a terminal API error (§2.4 circuit breaker handles it main-thread).

if (!args || !Array.isArray(args.agents) || args.agents.length === 0) {
  throw new Error('sprint-wave: args.agents must be a non-empty array of {role, prompt}')
}
if (!args.storySchema || typeof args.storySchema !== 'object') {
  throw new Error('sprint-wave: args.storySchema (JSON Schema for the per-story reply) is required')
}
const wave = args.wave ?? 0

phase('Wave')
log(`sprint-wave: wave ${wave} — ${args.agents.length} agent(s), worktree isolation, schema-validated`)

const results = await parallel(args.agents.map(a => () =>
  agent(a.prompt, {
    label: `${a.role}:w${wave}`,
    phase: 'Wave',
    agentType: `blitz:${a.role}`,
    isolation: 'worktree',
    schema: args.storySchema,
  })))

const agents = results.map((r, i) => ({ role: args.agents[i].role, ok: r !== null, result: r }))
const failed = agents.filter(a => !a.ok).map(a => a.role)
if (failed.length) log(`sprint-wave: wave ${wave} — ${failed.length} agent(s) returned null: ${failed.join(', ')}`)

return { wave, agents }
