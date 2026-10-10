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

// Shell that runs code the text does not show: these are refused in a critic
// rather than guessed at.
const OPAQUE: { rx: RegExp; what: string }[] = [
  { rx: /(^|[;&|(]\s*)(eval|source|\.)\s/, what: 'dynamic execution (eval/source)' },
  { rx: /(^|[;&|(]\s*)(\$[A-Za-z_{(]|`)/, what: 'a command taken from a variable or substitution' },
  { rx: /\bxargs\b[^|;&]*\b(rm|mv|cp|sh|bash|tee|sed\s+-i)\b/, what: 'xargs into a writer' },
  { rx: /\bfind\b[^|;&]*\s-(delete|exec(dir)?\s+(rm|mv|cp|sh|bash|sed))\b/, what: 'find that deletes or rewrites' },
  // Writing to /tmp is allowed, so running what is there is not: it is code no check saw.
  { rx: /(^|[;&|(]\s*|\b(?:ba|z|da|k)?sh\s+|\b(?:python3?|node|perl|ruby|deno|bun)\s+)(\/tmp\/|\/var\/tmp\/|\$\{?(TMPDIR|SESSION_TMP_DIR)\}?\/)/, what: 'running a file from a temp directory' },
]
// Interpreter one-liners that write or delete files.
const INLINE_CODE = /\b(python3?|node|perl|ruby|deno|bun)\s+(-c|-e|--eval|-p)\s/
const INLINE_WRITE = /(writeFile|appendFile|createWriteStream|unlink|rmSync|rmdirSync|renameSync|copyFile|os\.remove|os\.unlink|os\.rename|shutil\.|\.write_text|\.write_bytes|open\([^)]*,\s*['"][wax]|File\.write|IO\.write|truncate)/
// `sh -c '<payload>'` and friends: the payload is shell too and is checked the same way.
const SHELL_C = /\b(?:ba|z|da|k)?sh\s+(?:-[a-zA-Z]*c[a-zA-Z]*)\s+(?:'([^']*)'|"((?:[^"\\]|\\.)*)")/g

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
    const why = shellWrite(raw, 0)
    if (why !== undefined) return { kind: 'deny', reason: `blitz-guard: ${agentType} is read-only; ${why}.` }
  }
  return { kind: 'pass' }
}

/** Why a shell command writes, or undefined. Recurses into `sh -c` payloads (depth-capped). */
function shellWrite(raw: string, depth: number): string | undefined {
  if (depth > 3) return 'shell nested too deep to check'
  if (PLAN_WRITE.test(raw)) return 'this command is a plan-state write (only `tasks.sh verify` is allowed)'
  if (INLINE_CODE.test(raw) && INLINE_WRITE.test(raw)) return 'an inline interpreter script writes or deletes files'
  for (const m of raw.matchAll(SHELL_C)) {
    const inner = shellWrite((m[1] ?? m[2] ?? '').replace(/\\(["\\$`])/g, '$1'), depth + 1)
    if (inner !== undefined) return `inside sh -c: ${inner}`
  }
  const cmd = unquoted(raw)
  for (const { rx, what } of OPAQUE) if (rx.test(cmd)) return `this command is ${what}`
  for (const { rx, what } of MUTATING) if (rx.test(cmd)) return `this command is ${what}`
  if (writesFile(cmd)) return 'redirect output to /tmp or /dev/null'
  return undefined
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

export type UsageFacts = {
  ts: string
  agentId: string
  agentType: string
  usage: { model: string; input_tokens: number; output_tokens: number; cache_read_input_tokens: number; cache_creation_input_tokens?: number }
}

/** One JSONL row for .cc-sessions/agent-usage.mod.jsonl: a subagent run's final counts. Identifiers kept to safe characters. */
export function usageLine(f: UsageFacts): string {
  const safe = (s: string) => s.replace(/[^A-Za-z0-9_.:/-]/g, '').slice(0, 80)
  const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? Math.floor(v) : 0)
  return JSON.stringify({
    ts: f.ts,
    source: 'turn.complete',
    agent_id: safe(f.agentId),
    agent: safe(f.agentType),
    model: safe(f.usage.model),
    input: n(f.usage.input_tokens),
    output: n(f.usage.output_tokens),
    cache_read: n(f.usage.cache_read_input_tokens),
    cache_write: n(f.usage.cache_creation_input_tokens),
  })
}

export type Effort = 'low' | 'medium' | 'high' | 'xhigh' | 'max'
const EFFORT_ORDER: Effort[] = ['low', 'medium', 'high', 'xhigh', 'max']

/**
 * The lowest effort a blitz agent runs at. Anthropic documents Sonnet 5.5 at
 * `low` skipping its own checks and Opus 5.5 `medium` as the strong default, so
 * an implementation agent or the verdict below `medium` is a routing mistake.
 * An absent effort is left alone: the agent file's `effort:` applies.
 */
export const EFFORT_FLOOR: Record<string, Effort> = {
  'blitz:dev': 'medium',
  'blitz:test-writer': 'medium',
  'blitz:critic': 'medium',
}

/** The effort an Agent call should carry, or undefined to leave the call as it is. */
export function effortFloor(subagentType: string | undefined, effort: Effort | undefined): Effort | undefined {
  if (subagentType === undefined || effort === undefined) return undefined
  const floor = EFFORT_FLOOR[subagentType]
  if (floor === undefined) return undefined
  return EFFORT_ORDER.indexOf(effort) < EFFORT_ORDER.indexOf(floor) ? floor : undefined
}
