import { expect, test } from 'claude-code/testing'
import { planProgress, readOnlyVerdict, spawnVerdict, statusText } from '../hooks/policy.ts'

test('non-blitz spawns pass untouched', async () => {
  expect(spawnVerdict({ subagentType: 'general-purpose', model: 'haiku', isWorkflow: false }).kind).toBe('pass')
  expect(spawnVerdict({ subagentType: 'Explore', isTeammate: true, isWorkflow: false }).kind).toBe('pass')
})

test('a blitz agent never becomes a teammate', async () => {
  const v = spawnVerdict({ subagentType: 'blitz:dev', isTeammate: true, isWorkflow: false })
  expect(v.kind).toBe('deny')
})

test('a blitz agent named on haiku is moved to its default model, or refused in a workflow', async () => {
  const direct = spawnVerdict({ subagentType: 'blitz:critic', model: 'claude-haiku-5-5', isWorkflow: false })
  expect(direct).toEqual({ kind: 'model', model: 'opus', reason: expect.any(String) })
  const wf = spawnVerdict({ subagentType: 'blitz:dev', model: 'haiku', isWorkflow: true })
  expect(wf.kind).toBe('deny')
  expect(spawnVerdict({ subagentType: 'blitz:dev', model: 'sonnet', isWorkflow: false }).kind).toBe('pass')
  expect(spawnVerdict({ subagentType: 'blitz:critic', model: 'opus', isWorkflow: true }).kind).toBe('pass')
  expect(spawnVerdict({ subagentType: 'blitz:dev', isWorkflow: false }).kind).toBe('pass')
})

test('critics may read and run checks', async () => {
  const ok = [
    'git diff "$BASE"...HEAD',
    'git log --oneline -15',
    "grep -rEn 'rm -rf|a>b' src/",
    'npx tsc --noEmit 2>&1 | grep -cE "error TS" || echo 0',
    'bash scripts/tasks.sh verify demo T-001 >/dev/null 2>&1',
    'grep -oE x f.test.js > /tmp/blitz-critic-literals.txt',
    'timeout 60 node -e "require(\'./src/a.js\')"',
    'cat docs/sweeps/ratchet.json | jq .metrics',
  ]
  for (const command of ok) expect(readOnlyVerdict('blitz:critic', 'Bash', { command })).toEqual({ kind: 'pass' })
  expect(readOnlyVerdict('blitz:research-critic', 'WebFetch', { url: 'https://x' })).toEqual({ kind: 'pass' })
})

test('critics may not write', async () => {
  const bad: [string, unknown][] = [
    ['Write', { file_path: 'src/a.ts', content: '' }],
    ['Edit', { file_path: 'src/a.ts' }],
    ['Bash', { command: 'git commit -am x' }],
    ['Bash', { command: 'git checkout -- src/a.ts' }],
    ['Bash', { command: 'rm -rf src' }],
    ['Bash', { command: 'cd src && mv a.ts b.ts' }],
    ['Bash', { command: "sed -i 's/a/b/' src/a.ts" }],
    ['Bash', { command: 'echo x > src/a.ts' }],
    ['Bash', { command: 'echo x >> docs/plans/demo/progress.md' }],
    ['Bash', { command: 'npm install left-pad' }],
    ['Bash', { command: 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" set demo T-001 status=done' }],
    ['Bash', { command: 'ls | tee src/out.txt' }],
  ]
  for (const [tool, input] of bad) expect(readOnlyVerdict('blitz:critic', tool, input).kind).toBe('deny')
})

test('dev agents and unknown loops are not restricted here', async () => {
  expect(readOnlyVerdict('blitz:dev', 'Write', { file_path: 'src/a.ts' })).toEqual({ kind: 'pass' })
  expect(readOnlyVerdict(undefined, 'Bash', { command: 'rm -rf x' })).toEqual({ kind: 'pass' })
})

test('plan progress reads tasks.json and the status line keeps to safe characters', async () => {
  const text = JSON.stringify({ tasks: [
    { id: 'T-001', status: 'done' }, { id: 'T-002', status: 'in_progress' },
    { id: 'T-003', status: 'blocked' }, { id: 'T-004', status: 'open' },
  ] })
  const p = planProgress('checkout-v2', text)
  expect(p).toEqual({ slug: 'checkout-v2', done: 1, total: 4, inProgress: ['T-002'], blocked: 1 })
  expect(statusText(p!)).toBe('blitz checkout-v2 1/4 · T-002 running · 1 blocked')
  expect(statusText({ slug: 'x$(rm -rf /)', done: 0, total: 1, inProgress: [], blocked: 0 })).toBe('blitz xrm-rf 0/1')
  expect(planProgress('bad', '{not json')).toBe(undefined)
})
