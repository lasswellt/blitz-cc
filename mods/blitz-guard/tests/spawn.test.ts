import { expect, test } from 'claude-code/testing'

// What the engine fills in for a spawn the model's Agent call made.
const ENGINE = {
  tool_use_id: 'toolu_test',
  provider: { plugin: 'engine', tier: 'core' },
  parentModel: 'claude-opus-5-5',
  background: true,
  fork: false,
} as const

// The test's own agent.spawn hook sits beneath the plugin and stands for the
// engine: it records what reached it and starts nothing.
test('agent.spawn: a blitz agent on haiku reaches the engine on its default model', async ($, on) => {
  const seen: { subagentType: string; model?: string }[] = []
  on('agent.spawn', ($, e) => {
    seen.push({ subagentType: e.subagentType, model: e.model })
    return { model: e.model ?? 'inherit', agentId: `a${seen.length}` }
  })
  const r = await $.agent.spawn({ ...ENGINE, subagentType: 'blitz:critic', model: 'haiku', prompt: 'MODE: reject', description: 'check critic' })
  expect(r.deny).toBe(undefined)
  expect(seen).toEqual([{ subagentType: 'blitz:critic', model: 'opus' }])
})

test('agent.spawn: other agents pass through unchanged', async ($, on) => {
  const seen: (string | undefined)[] = []
  on('agent.spawn', ($, e) => {
    seen.push(e.model)
    return { model: e.model ?? 'inherit', agentId: 'g1' }
  })
  await $.agent.spawn({ ...ENGINE, subagentType: 'general-purpose', model: 'haiku', prompt: 'p', description: 'd' })
  expect(seen).toEqual(['haiku'])
})

test('tool.call Agent: a blitz:critic call at low effort reaches the engine at medium', async ($, on) => {
  const seen: (string | undefined)[] = []
  on('tool.call', { tool: 'Agent' }, ($, e) => {
    seen.push(e.effort)
    return { result: 'started' } as never
  })
  await $.tool.call({ tool: 'Agent', description: 'check critic', prompt: 'MODE: reject', subagent_type: 'blitz:critic', effort: 'low' })
  await $.tool.call({ tool: 'Agent', description: 'build T-001', prompt: 'p', subagent_type: 'blitz:dev', effort: 'high' })
  expect(seen).toEqual(['medium', 'high'])
})
