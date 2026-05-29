# Token Budget Protocol

Authoritative cost-control protocol for blitz multi-agent workflows. Multi-agent ≈15× chat-token baseline; this protocol drives that down 50–70% via model routing, prompt caching, structured replies, and lazy loading. Every skill that spawns subagents MUST follow this protocol.

**Why this doc exists**: research/2026-05-01_autonomous-blitz-quality-efficiency.md identified concrete savings; this codifies them. Before editing, read that research doc.

---

## 1. Model Routing Matrix (mandatory)

Every agent definition (`agents/*.md`) and every dynamic spawn (`Agent({model: ...})`) MUST set `model:` explicitly. Default inheritance is forbidden because the orchestrator runs Sonnet/Opus and would otherwise burn premium tokens on mechanical work.

| Role | Model | Rationale |
|---|---|---|
| **Mechanical workers**: test-gen, lint-fix, file ops, doc-gen, formatting | `claude-haiku-4-5` | 5× cheaper than Opus; adequate for pattern-following work |
| **Standard workers**: backend-dev, frontend-dev, reviewer, refactorer, browser-agent | `claude-sonnet-4-6` | 40% cheaper than Opus; sufficient for impl + review |
| **Heavy reasoning**: architect, security audit, codebase-audit, research orchestrator | `claude-opus-4-8` | Reserve for genuinely hard multi-step decisions |
| **Orchestrator agents** (`agents/orchestrator.md`, sprint-* orchestrators) | `claude-sonnet-4-6` | 40% cheaper than Opus; orchestration is routing, not synthesis |
| **Plan-check / critic** | `claude-sonnet-4-6` | Adversarial review needs reasoning, not depth |

Model IDs (2026-05-28): `claude-haiku-4-5` (alias of `claude-haiku-4-5-20251001`), `claude-sonnet-4-6`, `claude-opus-4-8`. Skill frontmatter MAY use the short `haiku`/`sonnet`/`opus` aliases; dynamic `Agent({model})` spawns SHOULD use the full IDs above.

**Target distribution**: ≈60% Haiku / 35% Sonnet / 5% Opus by output tokens. Re-affirmed for Opus 4.8 — orchestration stays Sonnet (routing, not synthesis); Opus floor stays ≤5% even though 4.8 fast mode is cheaper (fast mode is NOT cost-justified for routing — see §1.1).

### 1.1 Opus 4.8 fast mode + effort routing

| Lane | Cost (per MTok) | When |
|---|---|---|
| Sonnet 4.6 (workhorse) | $3 in / $15 out | standard workers, orchestration |
| Opus 4.8 standard | premium | heavy reasoning / synthesis |
| Opus 4.8 **fast mode** | ~$10 in / $50 out, 2.5× tok/s (`speed:"fast"`, research preview, Claude-API only) | **latency-critical only** (e.g. wave-dispatch); NOT a default. 3× cheaper than prior Opus fast ($30/$150) but still > Sonnet — do not auto-switch. |

**Effort split** (governs `effort:` frontmatter, distinct from model):
- Routing orchestrators (`agents/orchestrator.md`, `blitz:next`) → `effort: low` (heavy reasoning lives in spawned workers).
- Multi-wave / multi-phase orchestrators (`sprint-dev`) → `effort: high` — the `effort: low` rule applies to routing-only skills, not multi-phase work. Do not "fix" sprint-dev to low.
- `/effort ultracode` sessions spawn multiple SEQUENTIAL workflows; budget per-workflow, not per-session.

---

## 2. Prompt Caching (1-hour TTL on the orchestrator prefix)

Default cache TTL was silently dropped 60min → 5min in early 2026. For a sprint-dev session that spawns 10 subagents over 30 min, default TTL means every spawn after minute 5 pays full write cost on the shared prefix. Net effect: caching is worse than disabled.

### Rule

Plugin agents whose system prompt is ≥1024 tokens (Sonnet) / ≥4096 tokens (Opus, Haiku 4.5) MUST mark their static prefix with:

```
{"type": "ephemeral", "ttl": "1h"}
```

Static prefix = role definition, specialist roster, shared protocols, output style. **Dynamic content (sprint context, story args, activity-feed slice) MUST come AFTER the cached block** or the prefix match breaks and you pay full price.

### Break-even

| TTL | Write cost | Read cost | Reads needed to break even |
|---|---|---|---|
| 5min (default) | 1.25× input | 0.10× input | ~1.3 |
| 1h (opt-in) | 2.00× input | 0.10× input | ~2.2 |

For a 10-spawn sprint-dev: 1h TTL → 1 write + 9 reads = ~2.9× write cost amortized. Default 5min TTL → potentially 10 writes = ~12.5× write cost. **Opt in to 1h.**

### Verification

After every long session, eyeball the cache hit rate via the Anthropic SDK response (`usage.cache_read_input_tokens / (cache_creation_input_tokens + cache_read_input_tokens)`). Target ≥0.6 once the orchestrator has run a few times.

Source: [dev.to/whoffagents](https://dev.to/whoffagents/claude-prompt-caching-in-2026-the-5-minute-ttl-change-thats-costing-you-money-4363), [platform.claude.com/docs/prompt-caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

---

## 3. Subagent Reply Contract (canonical JSON, ≤50-word summary)

Every `Agent()` prompt MUST instruct the subagent to return ONLY the canonical JSON shown below. Prose replies are forbidden — they bloat orchestrator context by 430–1,930 tokens per return × N agents = 8–38 K tokens/sprint of pure waste.

### Canonical schema

```json
{
  "status": "complete|partial|failed",
  "summary": "<one sentence, ≤50 words, ≤400 chars>",
  "files_changed": ["path/relative/to/repo"],
  "issues": [
    {"severity": "blocker|major|minor", "where": "path:line", "what": "≤30 words"}
  ],
  "next_blocked_by": ["e.g. needs-typecheck", "needs-user-input"],
  "metrics": {
    "test_count_delta": 0,
    "type_errors_delta": 0,
    "lines_changed": 0
  }
}
```

`metrics` keys are optional but encouraged for any agent that touches code (sprint-review aggregates these directly without re-grepping).

### Embedding in spawn prompts

Every Agent() prompt MUST include this snippet near the end:

> Return ONLY this JSON, nothing else. No markdown fence, no preamble, no postamble. The orchestrator parses your reply with `jq`; any deviation breaks the run.

Skills that need richer output (research docs, audit findings, generated code) MUST write that to a file and reference its path in `files_changed[]`. Never inline file contents into the JSON.

### Validator (orchestrator-side)

```bash
parse_reply() {
  local raw="$1"
  echo "$raw" | jq -e '.status,.summary' >/dev/null 2>&1 || {
    echo "BAD_REPLY: agent returned non-conforming output" >&2
    return 1
  }
  local len=$(echo "$raw" | jq -r '.summary | length')
  (( len > 400 )) && echo "WARN: summary $len chars > 400 budget" >&2
  return 0
}
```

A reply that fails the schema check is treated as MALFORMED per spawn-protocol §8.

---

## 4. Lazy Skill Loading (do not preload all 37)

The orchestrator agent MUST NOT inject all 37 skill descriptions at startup. Skill bodies load only on slash-invocation; for orchestrator routing, expose ONLY the wave-relevant skill names + descriptions.

**Pattern** (orchestrator agent body):

```
At session start, run:
  ls skills/ | head -40

When the user describes a goal, grep skill descriptions:
  grep -h '^description:' skills/*/SKILL.md | head -50

Spawn at most one specialist agent per turn. Do not preemptively pull skill bodies.
```

Don't load 25K tokens of skill content for every session — load 0 tokens until needed.

---

## 5. Deferred MCP Tool Loading

Default behavior in Claude Code: MCP tool **definitions** are deferred (only names in context). Tool **schemas** load on first call.

Skills MUST NOT eagerly enable all plugin MCP servers. Each active server pays ~18K tokens/turn baseline ([code.claude.com/docs/costs](https://code.claude.com/docs/en/costs)). One published workflow cut MCP overhead 51K→8.5K tokens (83% reduction) by lazy-loading via ToolSearch.

**Rule**: any skill that uses MCP tools MUST cite the tools by name in its `allowed-tools:` frontmatter or rely on `ToolSearch` for on-demand schema fetch. Bulk-enable is forbidden.

---

## 6. PostToolUse Output Replacement

Claude Code v2.1.121+ allows PostToolUse hooks to replace tool output via `hookSpecificOutput.updatedToolOutput`. Use this to summarize verbose outputs (test runs, build logs, large file reads) before they enter orchestrator context.

Pattern: any spawn site that runs `npm test` or `npm run build` and pipes to the orchestrator MUST route through a summarizing hook. Raw 10K-line test output → 100-line digest. Saves tens of thousands of tokens per spawn.

---

## 7. CLAUDE.md and Memory Hygiene

CLAUDE.md is loaded into every session — keep ≤200 lines. Workflow-specific instructions belong in `skills/*/SKILL.md` (lazy-loaded), not CLAUDE.md.

User memory at `~/.claude/projects/-home-tom-development-blitz/memory/MEMORY.md` is also loaded every session (truncated at 200 lines). Each entry should be one line, ≤150 chars.

---

## 8. Subagents vs Agent Teams (use subagents)

| Mode | Token overhead vs single chat | Use case |
|---|---|---|
| Subagents (current blitz) | 200–500% | Result-only return; orchestrator-worker pattern |
| Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | ~700% (plan mode) | Peer-to-peer debate, competing hypotheses |

For blitz Hybrid Pattern A's 20 specialist workers: **use subagents**. Reserve Agent Teams for genuinely peer-to-peer debugging where multiple hypotheses must run concurrently.

---

## 9. Anti-Patterns (banned)

| Anti-pattern | Token cost | Fix |
|---|---|---|
| Subagent Reads whole file instead of line range | 500–5K extra tokens | Use `offset`+`limit` on Read |
| Subagent pastes raw tool output verbatim into reply | Multiplies per agent | PostToolUse summarizer; reply contract caps |
| Subagent re-states task prompt in reply | ~200 tokens | Reply contract omits preamble |
| Verbose progress prose ("I am now analyzing…") | 50–300 tokens/step | terse-output protocol |
| Orchestrator accumulates raw subagent returns | Compounds across N | Reply contract `summary` only |
| Bulk-enable all MCP servers | 18K tokens/turn/server | ToolSearch lazy load |
| Preload all 37 skill bodies | 25K+ tokens | Lazy skill discovery |
| Default-inheritance Opus on Haiku-class work | 5× per token | Explicit `model:` in every spawn |

---

## 10. Per-Skill Budget Caps (advisory)

Skills SHOULD declare a token budget in frontmatter (informational; not enforced yet):

```yaml
---
token-budget:
  orchestrator-input: 50000   # parent context bytes consumed
  per-spawn-output: 800       # bytes returned to parent
  total-spawns: 20
---
```

When a skill exceeds its budget at runtime, log to activity-feed `event: budget_exceeded` and continue (advisory). A future hook may enforce hard caps.

---

## Related

- `skills/_shared/spawn-protocol.md` §8 — output contract / classification
- `skills/_shared/terse-output.md` — output style enforcement
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` — research basis
