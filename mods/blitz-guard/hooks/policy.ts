// Pure policy for the blitz-guard mod: no `$`, so `claude plugin test` can
// exercise every rule directly. register.ts wires these into the events.

/** blitz agent types whose definition is read-only (agents/*.md, security.md §5). */
export const READ_ONLY_AGENTS = new Set([
  'blitz:critic',
  'blitz:research-critic',
  'blitz:design-critic',
])

/** The model each blitz agent falls back to when a spawn names a disallowed one (agents.md §1.3). */
export const DEFAULT_MODEL: Record<string, string> = {
  'blitz:dev': 'sonnet',
  'blitz:test-writer': 'sonnet',
  'blitz:critic': 'opus',
  'blitz:research-critic': 'sonnet',
  'blitz:design-critic': 'sonnet',
}

export type SpawnFacts = {
  subagentType: string
  model?: string
  isTeammate?: boolean
  isWorkflow: boolean
}

export type SpawnVerdict =
  | { kind: 'pass' }
  | { kind: 'deny'; reason: string }
  | { kind: 'model'; model: string; reason: string }

const isBlitz = (t: string) => t.startsWith('blitz:')
const family = (m: string) => (/haiku/i.test(m) ? 'haiku' : /sonnet/i.test(m) ? 'sonnet' : /opus/i.test(m) ? 'opus' : 'other')

/**
 * agent.spawn policy. blitz agents never run as teammates (a teammate loses its
 * skills preload and cannot be resumed) and never on haiku (the routing matrix
 * keeps haiku for collectors and retrieval, not implementation or verdicts).
 * A workflow agent's content cannot be rewritten, only refused.
 */
export function spawnVerdict(f: SpawnFacts): SpawnVerdict {
  if (!isBlitz(f.subagentType)) return { kind: 'pass' }
  if (f.isTeammate) {
    return {
      kind: 'deny',
      reason: `blitz-guard: ${f.subagentType} runs as a subagent, not a teammate. With agent teams on, drop \`name\` or pass \`isolation\` (agents.md §1.5).`,
    }
  }
  if (f.model !== undefined && family(f.model) === 'haiku') {
    const fallback = DEFAULT_MODEL[f.subagentType] ?? 'sonnet'
    const reason = `blitz-guard: ${f.subagentType} does not run on haiku (agents.md §1.3)`
    return f.isWorkflow
      ? { kind: 'deny', reason: `${reason}; the workflow agent is refused and the skill falls back to the Agent path.` }
      : { kind: 'model', model: fallback, reason: `${reason}; running it on ${fallback}.` }
  }
  return { kind: 'pass' }
}

const WRITE_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

// Shell that changes the repository or the machine. Best effort by text: the
// critic's own Bash is a read subset by contract, and blitz's bash hooks and the
// sandbox stay the boundary. Writes under /tmp and /dev/null are allowed (the
// critic's §2.8b literals file); `scripts/tasks.sh verify` is the one plan-state
// write a critic makes.
const MUTATING: { rx: RegExp; what: string }[] = [
  { rx: /\bgit\s+(commit|push|reset|checkout|switch|restore|add|rm|mv|merge|rebase|cherry-pick|revert|stash|tag|clean|apply|am|branch\s+-[dDmM]|worktree\s+(add|remove|prune))\b/, what: 'a git write' },
  { rx: /(^|[;&|(]\s*|\b(xargs|sudo|env|timeout\s+\d+)\s+)(rm|rmdir|mv|cp|chmod|chown|ln|truncate|shred|dd|install|touch|mkdir)\s/, what: 'a file-system write' },
  { rx: /\b(sed|perl)\s+(-[a-zA-Z]*i|--in-place)/, what: 'an in-place edit' },
  { rx: /\b(npm|pnpm|yarn|bun)\s+(i|install|add|remove|uninstall|update|upgrade|link|publish)\b/, what: 'a package change' },
  { rx: /\b(pip3?|uv|poetry|cargo|go)\s+(install|add|remove|uninstall|get)\b/, what: 'a package change' },
]

// Checked on the raw command: the script path is usually quoted ("${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh").
const PLAN_WRITE = /\btasks\.sh"?\s+(init|add|set)\b/

/** The command with quoted strings blanked, so a grep pattern like 'a>b' or 'rm -rf' is not read as shell. */
function unquoted(cmd: string): string {
  return cmd.replace(/'[^']*'/g, "''").replace(/"(?:[^"\\]|\\.)*"/g, '""')
}

/** Output redirections to anything but /dev/null, /tmp, a numbered fd or $TMPDIR. */
function writesFile(cmd: string): boolean {
  const re = /(^|[^<>&0-9])(>>?|>\|)\s*("?)([^\s"&;|)]+)/g
  let m: RegExpExecArray | null
  while ((m = re.exec(cmd)) !== null) {
    const target = m[4] ?? ''
    if (/^(\/dev\/null|\/dev\/std(out|err)|&\d|\/tmp\/|\$\{?TMPDIR\}?\/|\$\{?SESSION_TMP_DIR\}?\/)/.test(target)) continue
    return true
  }
  return /\btee\s+(-a\s+)?(?!\/tmp\/|\/dev\/null)[^\s|;&]+/.test(cmd)
}

export type CheckVerdict = { kind: 'pass' } | { kind: 'deny'; reason: string }

/** tool.check policy for a call inside a read-only blitz agent's loop. */
export function readOnlyVerdict(agentType: string | undefined, tool: string, input: unknown): CheckVerdict {
  if (agentType === undefined || !READ_ONLY_AGENTS.has(agentType)) return { kind: 'pass' }
  if (WRITE_TOOLS.has(tool)) {
    return { kind: 'deny', reason: `blitz-guard: ${agentType} is read-only; ${tool} is refused.` }
  }
  if (tool === 'Bash' || tool === 'PowerShell') {
    const raw = String((input as { command?: unknown } | null)?.command ?? '')
    if (PLAN_WRITE.test(raw)) return { kind: 'deny', reason: `blitz-guard: ${agentType} is read-only; this command is a plan-state write (only \`tasks.sh verify\` is allowed).` }
    const cmd = unquoted(raw)
    for (const { rx, what } of MUTATING) {
      if (rx.test(cmd)) return { kind: 'deny', reason: `blitz-guard: ${agentType} is read-only; this command is ${what}.` }
    }
    if (writesFile(cmd)) return { kind: 'deny', reason: `blitz-guard: ${agentType} is read-only; redirect output to /tmp or /dev/null.` }
  }
  return { kind: 'pass' }
}

export type PlanProgress = { slug: string; done: number; total: number; inProgress: string[]; blocked: number }

/** Progress of one tasks.json, or undefined when it does not parse as blitz-tasks. */
export function planProgress(slug: string, text: string): PlanProgress | undefined {
  let doc: unknown
  try {
    doc = JSON.parse(text)
  } catch {
    return undefined
  }
  const tasks = (doc as { tasks?: unknown })?.tasks
  if (!Array.isArray(tasks)) return undefined
  const status = (t: unknown) => String((t as { status?: unknown })?.status ?? '')
  return {
    slug,
    done: tasks.filter(t => status(t) === 'done').length,
    total: tasks.length,
    inProgress: tasks.filter(t => status(t) === 'in_progress').map(t => String((t as { id?: unknown }).id ?? '?')),
    blocked: tasks.filter(t => status(t) === 'blocked').length,
  }
}

/** The status-line text: `blitz <slug> 3/7 · T-004 running · 1 blocked`. Slug and ids are repo data: kept to safe characters. */
export function statusText(p: PlanProgress): string {
  const safe = (s: string) => s.replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 40)
  const parts = [`blitz ${safe(p.slug)} ${p.done}/${p.total}`]
  if (p.inProgress.length > 0) parts.push(`${p.inProgress.slice(0, 3).map(safe).join(' ')} running`)
  if (p.blocked > 0) parts.push(`${p.blocked} blocked`)
  return parts.join(' · ')
}
