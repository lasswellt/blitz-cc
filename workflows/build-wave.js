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
//     plan: 'checkout-v2',                       // slug (label only)
//     wave: 2,                                   // wave number (label + return value only)
//     tasks: [ { id: 'T-003', role: 'backend',   // id keys the result; role is a label
//                prompt: '<11-item spec incl. ROLE: <role> + inlined role file>' }, ... ],
//     replySchema: { type: 'object', properties: {...}, required: [...] },  // per-task reply
//   }
// Prompts are passed in whole by the skill (ROLE: line included); the script does not build them.
// The runtime concurrency cap is CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS; the skill caps a
// wave at 4 tasks before calling.
// Returns { wave, tasks: [{ id, role, ok, result }] } — result is null when the agent died,
// was skipped, or hit a terminal API error (build treats it as BLOCKED circuit-breaker).

if (!args || !Array.isArray(args.tasks) || args.tasks.length === 0) {
  throw new Error('build-wave: args.tasks must be a non-empty array of {id, role, prompt}')
}
if (args.tasks.some(t => !t || typeof t.id !== 'string' || typeof t.prompt !== 'string')) {
  throw new Error('build-wave: every task needs a string id and a string prompt')
}
if (!args.replySchema || typeof args.replySchema !== 'object') {
  throw new Error('build-wave: args.replySchema (JSON Schema for the per-task reply) is required')
}
const wave = args.wave ?? 0
const plan = args.plan ?? ''

phase('Wave')
log(`build-wave: ${plan} wave ${wave} — ${args.tasks.length} task(s), worktree isolation, schema-validated`)

const results = await parallel(args.tasks.map(t => () =>
  agent(t.prompt, {
    label: `${t.id}:w${wave}`,
    phase: 'Wave',
    agentType: 'blitz:dev',
    isolation: 'worktree',
    schema: args.replySchema,
  })))

const tasks = results.map((r, i) => ({ id: args.tasks[i].id, role: args.tasks[i].role ?? null, ok: r !== null, result: r }))
const failed = tasks.filter(t => !t.ok).map(t => t.id)
if (failed.length) log(`build-wave: wave ${wave} — ${failed.length} task(s) returned null: ${failed.join(', ')}`)

return { wave, tasks }
