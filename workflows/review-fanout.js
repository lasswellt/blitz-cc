export const meta = {
  name: 'review-fanout',
  description: 'Parallel or sequential sprint reviewers plus the adversarial critic (sprint-review §2.2.0-W)',
  whenToUse: 'Only from /blitz:sprint-review when §2.2.0 selected the Workflow path. Findings files and the report stay in the skill (main thread).',
  phases: [
    { title: 'Review', detail: 'security / backend / frontend / pattern reviewers', model: 'sonnet' },
    { title: 'Critic', detail: 'blitz:critic adversarial verdict, schema-validated' },
  ],
}

// Extracted from skills/sprint-review/SKILL.md §2.2.0-W (E-045 S3). Plugin workflow: runs as
// /blitz:review-fanout. No filesystem, no clock — the script dispatches and validates only.
//
// args shape (required):
//   {
//     roster: [ { name: 'security-reviewer', prompt: '<template + OUTPUT STYLE snippet>' }, ... ],
//     sequential: false,        // true → each reviewer receives all prior reviewers' findings
//     criticPrompt: '<critic prompt + OUTPUT STYLE snippet>',
//     reviewerSchema: { type: 'object', properties: {...}, required: [...] },
//     criticSchema:   { type: 'object', properties: { verdict: { enum: ['LGTM','REJECT'] }, ... }, required: ['verdict'] }
//   }
// Returns { reviews: [{ name, ok, result }], critic } — critic is null on failure; the skill
// MUST then fall back to the Agent() critic spawn (Invariant 7 is load-bearing).

if (!args || !Array.isArray(args.roster) || args.roster.length === 0) {
  throw new Error('review-fanout: args.roster must be a non-empty array of {name, prompt}')
}
if (!args.criticPrompt || !args.reviewerSchema || !args.criticSchema) {
  throw new Error('review-fanout: args.criticPrompt, args.reviewerSchema and args.criticSchema are required')
}

phase('Review')
let reviews
if (args.sequential) {
  // Sequential accumulator: a true chain (NOT pipeline — pipeline's `prev` is same-item only).
  log(`review-fanout: sequential mode — ${args.roster.length} reviewer(s), each sees prior findings`)
  reviews = []
  let prior = []
  for (const a of args.roster) {
    const f = await agent(`${a.prompt}\n\nPrior findings:\n${JSON.stringify(prior)}`,
      { label: a.name, phase: 'Review', model: 'sonnet', schema: args.reviewerSchema })
    reviews.push(f)
    if (f) prior = [...prior, f]
  }
} else {
  log(`review-fanout: parallel mode — ${args.roster.length} reviewer(s)`)
  reviews = await parallel(args.roster.map(a => () =>
    agent(a.prompt, { label: a.name, phase: 'Review', model: 'sonnet', schema: args.reviewerSchema })))
}
const missing = reviews.filter(f => f === null).length
if (missing) log(`review-fanout: ${missing} reviewer(s) returned null (skill applies the §2.4 N=4 gate)`)

// Invariant 7: adversarial critic, schema-validated (replaces jq parse of LGTM|REJECT).
phase('Critic')
const critic = await agent(args.criticPrompt,
  { label: 'critic', phase: 'Critic', agentType: 'blitz:critic', schema: args.criticSchema })
if (critic === null) log('review-fanout: critic returned null — skill must fall back to the Agent() critic')

return {
  reviews: reviews.map((f, i) => ({ name: args.roster[i]?.name, ok: f !== null, result: f })),
  critic,
}
