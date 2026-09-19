export const meta = {
  name: 'audit-sweep',
  description: '5-pillar audit: 2 independent same-scope agents per pillar, one parallel() barrier (audit §1.1-W)',
  whenToUse: 'Only from /blitz:audit when §1.0 selected the Workflow path. Inventory, findings aggregation, ratchet.json and the report stay in the skill (main thread).',
  phases: [{ title: 'Audit', detail: '10 pillar agents, model sonnet, schema-validated findings', model: 'sonnet' }],
}

// Extracted from skills/audit/SKILL.md §1.1-W (E-045 S3). Plugin workflow: runs as
// /blitz:audit-sweep. No filesystem, no clock — dispatch + schema validation only.
//
// args shape (required):
//   {
//     roster: [ { name: 'security-a', prompt: '<pillar template, inventory inline, OUTPUT STYLE snippet>' }, ... ],
//     findingsSchema: { type: 'object', properties: {...}, required: [...] }
//   }
// Returns { agents: [{ name, ok, result }] } — result is null for a failed agent (Phase 2.2
// handles MISSING agents exactly as under the Agent() path).

if (!args || !Array.isArray(args.roster) || args.roster.length === 0) {
  throw new Error('audit-sweep: args.roster must be a non-empty array of {name, prompt}')
}
if (!args.findingsSchema || typeof args.findingsSchema !== 'object') {
  throw new Error('audit-sweep: args.findingsSchema (JSON Schema for the findings reply) is required')
}

phase('Audit')
log(`audit-sweep: dispatching ${args.roster.length} pillar agent(s) as one barrier`)

const findings = await parallel(args.roster.map(a => () =>
  agent(a.prompt, { label: a.name, phase: 'Audit', agentType: 'general-purpose', model: 'sonnet', schema: args.findingsSchema })))

const agents = findings.map((f, i) => ({ name: args.roster[i].name, ok: f !== null, result: f }))
const failed = agents.filter(a => !a.ok).map(a => a.name)
if (failed.length) log(`audit-sweep: ${failed.length} agent(s) returned null: ${failed.join(', ')}`)

return { agents }
