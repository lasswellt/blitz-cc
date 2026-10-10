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
    "sh -c 'git log --oneline -5'",
    "find src -name '*.ts' -newer package.json",
    'node -e "console.log(require(\'./package.json\').version)"',
    'python3 -c "import json; print(json.load(open(\'tasks.json\'))[\'plan\'])"',
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
    ['Bash', { command: "sh -c 'rm -rf src'" }],
    ['Bash', { command: 'bash -lc "git push origin HEAD"' }],
    ['Bash', { command: "sh -c \"bash -c 'echo x > src/a.ts'\"" }],
    ['Bash', { command: 'eval "$CMD"' }],
    ['Bash', { command: '$TOOL src/a.ts' }],
    ['Bash', { command: 'source ./scripts/setup.sh' }],
    ['Bash', { command: "find src -name '*.bak' -delete" }],
    ['Bash', { command: 'find . -name x -exec rm {} +' }],
    ['Bash', { command: 'git ls-files | xargs sed -i s/a/b/' }],
    ['Bash', { command: 'node -e "require(\'fs\').writeFileSync(\'src/a.ts\', \'\')"' }],
    ['Bash', { command: 'python3 -c "import os; os.remove(\'src/a.ts\')"' }],
    ['Bash', { command: 'bash /tmp/x.sh' }],
    ['Bash', { command: '/tmp/x.sh --go' }],
    ['Bash', { command: 'node $TMPDIR/run.js' }],
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

import { effortFloor, usageLine } from '../hooks/policy.ts'

test('effort floor raises blitz implementation and verdict agents below medium only', async () => {
  expect(effortFloor('blitz:dev', 'low')).toBe('medium')
  expect(effortFloor('blitz:critic', 'low')).toBe('medium')
  expect(effortFloor('blitz:critic', 'high')).toBe(undefined)
  expect(effortFloor('blitz:dev', undefined)).toBe(undefined)
  expect(effortFloor('blitz:research-critic', 'low')).toBe(undefined)
  expect(effortFloor('Explore', 'low')).toBe(undefined)
})

test('usage line keeps counts numeric and identifiers safe', async () => {
  const row = JSON.parse(usageLine({ ts: '2026-10-10T00:00:00Z', agentId: 'a1$(x)', agentType: 'blitz:dev',
    usage: { model: 'claude-sonnet-5-5', input_tokens: 10, output_tokens: 2500, cache_read_input_tokens: 9000, cache_creation_input_tokens: -1 } }))
  expect(row).toEqual({ ts: '2026-10-10T00:00:00Z', source: 'turn.complete', agent_id: 'a1x', agent: 'blitz:dev',
    model: 'claude-sonnet-5-5', input: 10, output: 2500, cache_read: 9000, cache_write: 0 })
})
