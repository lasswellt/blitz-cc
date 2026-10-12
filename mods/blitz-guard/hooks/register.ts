import type { EngineInterface, Register } from 'claude-code'
import { READ_ONLY_AGENTS, effortFloor, planProgress, readOnlyVerdict, spawnVerdict, statusText, usageLine } from './policy.ts'

// blitz-guard: an optional layer over blitz's bash hooks (hooks/hooks.json in
// the blitz plugin). Those hooks stay the baseline: a mod is unsandboxed JS the
// person must trust, needs Claude Code >=2.1.287, and is switched off by
// --bare, --safe-mode and disableAllHooks. This module adds what a shell hook
// cannot see:
//   agent.spawn:   blitz agents never become teammates and never run on haiku
//   tool.check:    calls inside a blitz critic's loop (by agentId) stay read-only
//   tool.call Agent:  a blitz:dev/test-writer/critic spawn below `medium` effort
//                   is raised to it (agent.spawn has no effort field; the Agent
//                   call's own `effort` does). Workflow agents never pass here.
//   status line:   plan progress from docs/plans/*/tasks.json
//   turn.complete:  each subagent run's final token counts to
//                   .cc-sessions/agent-usage.mod.jsonl (the SubagentStop hook's
//                   transcript row has output only as a streaming lower bound)

// agentId → subagentType for spawns this session saw. A module variable is
// lost on reload; tool.check falls back to $.agent.list(), which covers every
// subagent but not workflow agents.
const typeOf = new Map<string, string>()

// Plan progress for the status line: the newest unfinished tasks.json under
// docs/plans/ (archive excluded). Refreshed after any scripts/tasks.sh call and
// at session start; cleared when no plan has open work.
async function refresh($: EngineInterface) {
  if (!(await $.fs.exists('docs/plans'))) return
  const plans = (await $.fs.list('docs/plans')).filter(d => d.kind === 'dir' && d.name !== 'archive')
  let best: { mtime: number; text: string } | undefined
  for (const d of plans) {
    const path = `docs/plans/${d.name}/tasks.json`
    const stat = await $.fs.stat(path).catch(() => undefined)
    if (stat === undefined) continue
    const p = planProgress(d.name, String(await $.fs.read(path)))
    if (p === undefined || p.done === p.total) continue
    if (best === undefined || stat.mtimeMs > best.mtime) best = { mtime: stat.mtimeMs, text: statusText(p) }
  }
  $.ui.status(best?.text)
}

// Appends one line to the mod's usage ledger. Read-modify-write, serialized
// through `pending` so two subagents finishing together do not lose a line;
// only this mod writes the file (the bash hook writes agent-usage.jsonl).
const LEDGER = '.cc-sessions/agent-usage.mod.jsonl'
let pending: Promise<void> = Promise.resolve()
async function appendUsage($: EngineInterface, line: string) {
  const before = (await $.fs.exists(LEDGER)) ? String(await $.fs.read(LEDGER)) : ''
  await $.fs.write(LEDGER, before + line + '\n')
}

export const register: Register = on => {
  on('agent.spawn', async ($, e, next) => {
    const verdict = spawnVerdict({
      subagentType: e.subagentType,
      model: e.model,
      isTeammate: e.isTeammate === true,
      isWorkflow: e.workflow !== undefined,
    })
    if (verdict.kind === 'deny') return { deny: verdict.reason }
    const started = verdict.kind === 'model' ? await next({ ...e, model: verdict.model }) : await next(e)
    if (verdict.kind === 'model') $.ui.toast(verdict.reason)
    if (started.agentId !== undefined && e.subagentType.startsWith('blitz:')) {
      typeOf.set(started.agentId, e.subagentType)
      if (e.subagentType === 'blitz:dev') $.ui.status(`blitz ${e.description.slice(0, 40)} running`)
    }
    return started
  }).catch(($, e, next) => next(e))

  on('tool.check', async ($, e, next) => {
    if (e.agentId === undefined) return next(e)
    let agentType = typeOf.get(e.agentId)
    if (agentType === undefined) {
      const row = (await $.agent.list()).find(a => a.id === e.agentId)
      if (row !== undefined && row.type.startsWith('blitz:')) {
        agentType = row.type
        typeOf.set(e.agentId, row.type)
      }
    }
    const verdict = readOnlyVerdict(agentType, e.tool, e.input)
    return verdict.kind === 'deny' ? { decision: 'deny', reason: verdict.reason } : next(e)
  }).catch(($, e, next) => {
    // A failed check inside a known critic refuses; anywhere else the bash
    // hooks and the permission rules decide, as without this mod.
    const known = e.agentId !== undefined ? typeOf.get(e.agentId) : undefined
    return known !== undefined && READ_ONLY_AGENTS.has(known)
      ? { decision: 'deny' as const, reason: 'blitz-guard: the read-only check failed inside a blitz critic; refused.' }
      : next(e)
  })

  on('tool.call', { tool: 'Agent' }, ($, e, next) => {
    const raised = effortFloor(e.subagent_type, e.effort)
    if (raised === undefined) return next(e)
    $.ui.toast(`blitz-guard: ${e.subagent_type} runs at ${raised} effort or above (was ${e.effort}).`)
    return next({ ...e, effort: raised })
  }).catch(($, e, next) => next(e))

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($).catch(() => undefined)
    return result
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const ran = await next(e)
    if (/\btasks\.sh"?\s+(set|verify|add|init)\b/.test(e.command)) await refresh($).catch(() => undefined)
    return ran
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId === undefined || e.usage === undefined) return result
    const agentType = typeOf.get(e.agentId) ?? (await $.agent.list()).find(a => a.id === e.agentId)?.type ?? ''
    const line = usageLine({ ts: new Date(await $.clock.now()).toISOString(), agentId: e.agentId, agentType, usage: e.usage })
    const agentId = e.agentId
    pending = pending.then(() => appendUsage($, line)).catch(() => undefined)
    await pending
    if (agentType.startsWith('blitz:')) typeOf.set(agentId, agentType)
    return result
  }).catch(($, e, next) => next(e))
}
