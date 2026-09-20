export const meta = {
  name: 'review-fanout',
  description: 'Parallel or sequential critic --mode survey lenses plus the adversarial critic --mode reject (check Phases 2.1 and 4.3)',
  whenToUse: 'Only from /blitz:check when Phase 2.1 selected the Workflow path. Findings files and the check-report stay in the skill (main thread).',
  phases: [
    { title: 'Review', detail: 'blitz:critic MODE: survey lenses (spec compliance, then code quality)', model: 'sonnet' },
    { title: 'Critic', detail: 'blitz:critic MODE: reject adversarial verdict, schema-validated' },
  ],
}

// Extracted from skills/check/SKILL.md Phases 2.1 and 4.3. Plugin workflow: runs as
// /blitz:review-fanout. No filesystem, no clock — the script dispatches and validates only.
//
// args shape (required):
//   {
//     lenses: [ { name: 'spec-compliance', prompt: '<MODE: survey + lens template + Output line>' }, ... ],
//     sequential: false,        // true → each lens receives all prior lenses' findings
//     criticPrompt: '<MODE: reject critic prompt + Output line>',
//     surveySchema: { type: 'object', properties: { findings: {...}, verdict: { enum: ['CLEAN','FINDINGS'] } }, required: ['findings'] },
//     criticSchema:   { type: 'object', properties: { verdict: { enum: ['LGTM','REJECT'] }, ... }, required: ['verdict'] }
//   }
// Returns { reviews: [{ name, ok, result }], critic } — critic is null on failure; the skill
// MUST then fall back to the Agent() critic spawn (LGTM before PASS is load-bearing).

if (!args || !Array.isArray(args.lenses) || args.lenses.length === 0) {
  throw new Error('review-fanout: args.lenses must be a non-empty array of {name, prompt}')
}
if (!args.criticPrompt || !args.surveySchema || !args.criticSchema) {
  throw new Error('review-fanout: args.criticPrompt, args.surveySchema and args.criticSchema are required')
}

phase('Review')
let reviews
if (args.sequential) {
  // Sequential accumulator: a true chain (NOT pipeline — pipeline's `prev` is same-item only).
  log(`review-fanout: sequential mode — ${args.lenses.length} survey lens(es), each sees prior findings`)
  reviews = []
  let prior = []
  for (const a of args.lenses) {
    const f = await agent(`${a.prompt}\n\nPrior findings:\n${JSON.stringify(prior)}`,
      { label: a.name, phase: 'Review', agentType: 'blitz:critic', model: 'sonnet', schema: args.surveySchema })
    reviews.push(f)
    if (f) prior = [...prior, f]
  }
} else {
  log(`review-fanout: parallel mode — ${args.lenses.length} survey lens(es)`)
  reviews = await parallel(args.lenses.map(a => () =>
    agent(a.prompt, { label: a.name, phase: 'Review', agentType: 'blitz:critic', model: 'sonnet', schema: args.surveySchema })))
}
const missing = reviews.filter(f => f === null).length
if (missing) log(`review-fanout: ${missing} survey lens(es) returned null (skill applies the /_shared/agents.reference.md §4.4 fan-out gate)`)

// Adversarial critic (MODE: reject), schema-validated (replaces jq parse of LGTM|REJECT).
phase('Critic')
const critic = await agent(args.criticPrompt,
  { label: 'critic', phase: 'Critic', agentType: 'blitz:critic', schema: args.criticSchema })
if (critic === null) log('review-fanout: critic returned null — skill must fall back to the Agent() critic')

return {
  reviews: reviews.map((f, i) => ({ name: args.lenses[i]?.name, ok: f !== null, result: f })),
  critic,
}
