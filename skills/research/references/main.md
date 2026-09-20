# Research — Reference Material

Templates, research types, section guidelines for research skill.

---

## Research Document Template

Template for final synthesized research document. All sections required.

```markdown
# Research: <Topic Title>

**Date**: YYYY-MM-DD
**Type**: <Library Evaluation | Architecture Decision | Feature Investigation | Comparison>
**Status**: Complete
**Stack**: <detected stack summary>

---

## Summary

<3-5 sentence executive summary. State the topic, key findings, and the recommendation.
This section should be self-contained — a reader should understand the conclusion without
reading further.>

---

## Research Questions

### Q1: <question>
**Answer**: <concise answer, 2-4 sentences>

### Q2: <question>
**Answer**: <concise answer, 2-4 sentences>

### Q3: <question>
**Answer**: <concise answer, 2-4 sentences>

<...additional questions as needed>

---

## Findings

### <Theme 1: e.g., "API Surface and DX">

<Detailed findings organized by theme. Each finding should:>
- State the fact or observation
- Cite the source (documentation URL, GitHub issue, codebase file path)
- Note relevance to the project

### <Theme 2: e.g., "Performance Characteristics">

<...>

### <Theme 3: e.g., "Community and Maintenance">

<...>

---

## Compatibility Analysis

### Stack Compatibility

| Aspect | Status | Notes |
|--------|--------|-------|
| Framework version | Compatible / Incompatible / Untested | <details> |
| Build system | Compatible / Requires config | <details> |
| TypeScript | Full / Partial / None | <details> |
| Package manager | Works / Issues | <details> |
| Existing dependencies | No conflicts / Conflicts with X | <details> |

### Integration Complexity

- **Effort estimate**: <Low (hours) | Medium (1-2 days) | High (3+ days)>
- **Files affected**: <approximate count and key paths>
- **Breaking changes**: <Yes/No — details if yes>
- **Migration path**: <description of migration steps if replacing existing code>

---

## Recommendation

### Decision

<Clear, specific recommendation. Not "it depends" — make a call and justify it.>

### Rationale

<3-5 bullet points explaining why this is the right choice.>

### Comparison Matrix (if applicable)

| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| TypeScript support | Excellent | Good | Poor |
| Bundle size | 12KB | 45KB | 8KB |
| Community activity | High | Medium | Low |
| Learning curve | Low | Medium | High |
| Integration effort | Low | Medium | Low |
| **Overall** | **Recommended** | Acceptable | Not recommended |

---

## Implementation Sketch

<High-level implementation steps, adapted to the detected stack. Include:>

### Step 1: <title>
<Description of what to do. Include key code patterns.>

```<language>
// Example code adapted to project conventions
```

### Step 2: <title>
<...>

### Step 3: <title>
<...>

### Configuration Changes
<Any config file changes needed (package.json, framework config, env vars, etc.)>

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| <risk description> | Low/Medium/High | Low/Medium/High | <mitigation strategy> |
| <risk description> | Low/Medium/High | Low/Medium/High | <mitigation strategy> |

### Open Questions

- <Any questions that could not be answered with available information>
- <Areas that need further investigation or testing>

---

## References

1. <Title> — <URL> — <brief description of what it covers>
2. <Title> — <URL> — <brief description>
3. <Codebase file path> — <what it demonstrates about current implementation>
```

---

## Research Types

### Library Evaluation

**When to use**: User evaluating specific library or choosing between libraries.

**Focus areas**:
- API surface and developer experience
- TypeScript support quality
- Bundle size and tree-shaking
- Version compatibility with project stack
- Maintenance health (last release, open issues, contributors)
- Migration path from current implementation (if any)

**Key questions to generate**:
- How does this integrate with detected framework?
- Bundle size impact?
- Actively maintained?
- What do real users report as pain points?
- How does it compare to alternatives?

### Architecture Decision

**When to use**: User needs to decide architectural approach (state management, API design, data flow pattern, etc.).

**Focus areas**:
- Trade-offs between approaches
- How approach scales with project growth
- Impact on testing and maintainability
- Alignment with team experience and project conventions
- Precedent in similar projects

**Key questions to generate**:
- Concrete trade-offs?
- How does this affect testing?
- Migration path?
- How does this scale?
- What patterns does existing codebase follow?

### Feature Investigation

**When to use**: User needs to implement specific feature (auth, payments, real-time sync, etc.).

**Focus areas**:
- Available approaches and services
- Integration requirements
- Security implications
- Cost and scaling considerations
- Existing code that can be reused

**Key questions to generate**:
- Available approaches?
- Security requirements?
- Impact on UX?
- Infrastructure changes needed?
- Cost model at scale?

### Comparison

**When to use**: User wants head-to-head comparison of options (frameworks, services, patterns).

**Focus areas**:
- Feature parity matrix
- Performance benchmarks
- Developer experience comparison
- Community and ecosystem comparison
- Total cost of ownership

**Key questions to generate**:
- Criteria that matter most for this project?
- How do options compare on each criterion?
- Deal-breakers?
- Switching cost if choice proves wrong?
- Which option aligns best with team's strengths?

---

## Implementation Sketch Guidelines

Implementation Sketch section must adapt to detected stack. Guidelines:

### General Rules
- Reference actual project file paths (e.g., "add to existing `src/composables/` directory")
- Use project's detected package manager for install commands
- Follow project's detected coding patterns (Composition API vs Options API, etc.)
- Show configuration changes for detected build system
- Include type definitions if project uses TypeScript

### Stack-Specific Adaptation

When detected stack includes specific frameworks/tools, adapt code examples:

- **Package installation**: Use detected package manager (`pnpm add`, `yarn add`, `npm install`)
- **Import paths**: Follow project path alias conventions (`@/`, `~/`, relative)
- **Component patterns**: Match project component style (SFC Composition API, Options API, etc.)
- **State management**: Use detected state library (Pinia, Vuex, composables, Redux, Zustand, etc.)
- **Testing**: Show test examples using detected test runner (Vitest, Jest, etc.)
- **Configuration**: Show config changes for detected build system (Vite, Webpack, Nuxt config, etc.)

If no specific stack detected, use generic Node.js/TypeScript patterns; note where user should adapt.

---

## Agent Prompt Templates

Paste the canonical preamble at the top of every spawn prompt; append the per-agent role section. The preamble is **identical across templates** so the main thread can apply `cache_control: {type: "ephemeral", ttl: "1h"}` once the total static prefix crosses 1024 tokens.

### Canonical Preamble (paste verbatim)

```
pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths,
commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version
numbers. No preamble. No trailing summary of work already evident in the diff or tool
output. Format: fragments OK.

BUDGET: Medium-class agent. Hard wall-clock budget 3 minutes. Respect the per-agent
limits in SKILL.md §1.5 (max searches, max files read, max output lines). Use HEARTBEAT
lines between phases (`HEARTBEAT: <phase> at <ISO-8601>`). Emit PARTIAL marker block
when ≤3 tool calls remain or budget is approaching.

WRITE-AS-YOU-GO: Stub your output file with `# IN PROGRESS` before your first tool call.
Append findings as you discover them. Do NOT accumulate in memory — every section gets
written immediately.

CITATION RULES (all agents):
- Every cited URL gets a structured entry per §Structured Citations Schema below.
- Do NOT quote text verbatim unless you fetched the source THIS turn. Paraphrase + cite
  the URL only, OR tag the quote `[QUOTE_UNVERIFIED]` (synthesizer strips these).
- Prefer dated sources (publication date ≤12 months old when possible).
- Per-claim source-grounding: every declarative finding cites at least one URL.

REPLY CONTRACT: At task end, return ONLY this JSON to the main thread (no markdown
fence, no preamble, no postamble):
{
  "status": "complete|partial|failed",
  "summary": "<one sentence ≤50 words>",
  "files_changed": ["<your output file path>"],
  "issues": [],
  "next_blocked_by": []
}
```

### library-docs

```

You are library-docs, a research agent specializing in official documentation analysis.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/library-docs.md

TASKS:
1. Find official documentation for the topic/library.
2. Document the API surface relevant to the project's use case.
3. Check version compatibility with the project's stack.
4. Note any migration guides, breaking changes, or deprecations.
5. Find code examples that match the project's patterns.
6. Document known issues and workarounds.
```

### web-researcher (contrarian role)

```

You are web-researcher, a research agent specializing in community knowledge and real-world usage.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/web-researcher.md

CONTRARIAN ROLE: Of the parallel agents on this topic, you are explicitly assigned the
counter-evidence role. Your job is to find sources that CONTRADICT the obvious consensus
answer. Search for:
  - dissenting opinions, retracted claims, failed implementations
  - benchmarks showing the opposite of expected
  - GitHub issues / blog post-mortems where the recommended approach failed
You are not neutral — your bias is toward finding counter-evidence. Mitigates agent-
agreement bias per arxiv 2604.02923 (homogeneous 18.3% reduction → heterogeneous 35.9%).

TASKS:
1. Search recent (≤12 months) blog posts, tutorials, guides — prefer dated cites.
2. Check GitHub issues for common problems and their resolutions.
3. Find benchmarks or performance comparisons if relevant.
4. Assess community sentiment (adoption rate, maintenance, contributor count).
5. Identify alternatives and how they compare.
6. Surface "gotchas" and post-mortems (the contrarian focus above).
```

### codebase-analyst

```

You are codebase-analyst, a research agent specializing in impact analysis.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/codebase-analyst.md

TASKS:
1. Identify all files and modules related to the research topic.
2. Map the dependency graph of affected code.
3. Assess integration points where the topic would connect to existing code.
4. Identify existing patterns that should be followed or migrated.
5. Estimate migration effort (files to change, complexity of changes).
6. Note potential conflicts with existing dependencies.

Do NOT use web search. Focus entirely on the codebase. Cite findings as `path/to/file.ts:LINE`.
```

### infra-analyst (conditional — see SKILL.md §1.2.5)

```

You are infra-analyst, a research agent specializing in infrastructure and deployment implications.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/infra-analyst.md

TASKS:
1. Check cloud service documentation for relevant features, quotas, and pricing.
2. Assess deployment pipeline impact (new build steps, environment variables, secrets).
3. Review security implications (new permissions, access patterns, data flow).
4. Evaluate environment configuration changes needed.
5. Check for compatibility with existing infrastructure setup.
6. Note monitoring and observability considerations.
```

---

## Structured Citations Schema

Every research doc MUST include structured citations in YAML frontmatter, readable by `agents/research-critic.md` for liveness probing. Fights the documented 3-13% URL hallucination rate (arxiv 2604.03173).

### YAML schema

```yaml
---
citations:
  - url: "https://example.com/path"
    title: "<title from page or paper>"
    pub_date: "2026-04"          # YYYY or YYYY-MM (older than 12mo without justification → flagged)
    fetched_ts: "2026-05-01T16:30:00Z"  # ISO-8601 of in-turn fetch; null if not fetched this turn
    claimed_span: "≤400 char excerpt the agent quoted/relied on"
    status: LIVE                 # LIVE | DEAD | LIKELY_HALLUCINATED | UNKNOWN | NOT_FETCHED
---
```

`fetched_ts: null` + `status: NOT_FETCHED` flags training-knowledge-only citations — research-critic probes these first (highest hallucination risk).

### Required body sections (in addition to base 8)

Two extra sections beyond the base 8 (Summary / Research Questions / Findings / Compatibility / Recommendation / Implementation Sketch / Risks / References):

- `## Dissent / Contradictory Evidence` — preserve the contrarian agent's findings explicitly. Synthesizer MUST surface counter-evidence here rather than silently collapsing to consensus. Single-domain consensus (≥3 cited findings, all from one domain) is rejected: surface here and reduce confidence.
- `## Citation Health` (auto-populated by research-critic) — table of `{url, status, last_probed_at}` for every cited URL. CITATIONS_MISSING verdict triggers a `<!-- WARNING: citations failed liveness check -->` HTML comment at doc top.

### `[QUOTE_UNVERIFIED]` tag

Any quoted text where the source was not fetched in-turn MUST carry the inline tag:

```markdown
> "[QUOTE_UNVERIFIED] As reported in <source>, the failure rate exceeded 30%."
```

Synthesizer MAY strip these from the final doc OR convert to paraphrase. Producing them with the tag is mandatory; eliding them entirely (and pretending the quote is verified) is the failure mode being fought.

### Outcome-based acceptance criteria (preferred over artifact-based)

Per validity research §9, acceptance checks (the `verify[]` a task carries once `plan` derives it) that name implementation files by exact path are forward-coupled to implementation decisions made later. A hypothetical `precompact-handoff.sh` acceptance check illustrates this: criterion referenced a file that landed elsewhere; only an OR-fallback rescued the check.

Prefer:
- ✅ Outcome: `when PreCompact fires, .cc-sessions/HANDOFF.json contains the active plan slug`
- ❌ Artifact: `test -f hooks/scripts/precompact-handoff.sh` (hypothetical path; the real script is `pre-compact-snapshot.sh`)

OR-fallbacks (`test -f path-A || test -f path-B`) remain valid for compatibility but should not be the primary form.

---

## Agent Output Format (legacy — agents now use REPLY CONTRACT JSON)

Pre-v1.11, each research agent wrote findings to a Markdown file in this shape. From v1.11 forward, agents return canonical JSON to the main thread AND write Markdown findings (the file uses this format; the JSON references it).

```markdown
# <Agent Name> — Research Findings

## Topic: <research topic>
## Date: <ISO date>

---

### Finding 1: <title>
**Source**: <URL or file path>
**Relevance**: <High | Medium | Low>
<2-4 sentence description of the finding>

### Finding 2: <title>
<...>

---

## Summary
- **Findings count**: <N>
- **Key insight**: <one sentence>
- **Confidence level**: <High | Medium | Low>
- **Gaps**: <what could not be determined>

---

## Follow-Up Skill Graph

(SKILL.md §4.2 — research-outcome → suggested-skill table)

| Research Outcome | Suggested Skill | Rationale |
|---|---|---|
| Recommendation made, work is larger than a one-sentence diff | `plan <slug> --from-research <doc>` | Derives `docs/plans/<slug>/{spec.md, plan.md, tasks.json}` from the Recommendation; then `build`. |
| Recommendation is a one-sentence diff | `build` | Skip the plan; inline path. |
| Question was about the existing code, not a decision | `research --codebase <question>` | Read-only trace with `file:line` evidence. |
| Library selected, ready to integrate | `refactor` | Refactor existing code to use the new library. |
| Feature approach decided | `ui-build` | Build the feature UI. |
| Security concern identified | `audit` | Audit for related vulnerabilities. |
| Performance approach selected | `test-gen` | Generate performance-related tests. |
```

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

### 1.3-W Dispatch via Workflow (opt-in path)

Dispatch agents as one `parallel()` barrier; gap second-wave (§2.4) as a conditional `agent()` in the same script — replacing manual poll (§1.7) + classify (§2.1) + jq-gated second wave with native primitives.

```js
export const meta = { name: 'research', description: 'Parallel research agents + conditional gap second-wave', phases: [{ title: 'Investigate' }, { title: 'GapFill' }] }
// args: { roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema } — prompts embed OUTPUT STYLE + write-as-you-go
const OS = 'OUTPUT STYLE: terse-technical per /_shared/output.md. Drop articles/fillers/hedging; preserve code/paths/commands/JSON verbatim; no preamble.'
const found = await parallel(args.roster.map(a => () =>
  agent(a.prompt, { label: a.name, phase: 'Investigate',
    model: a.name === 'codebase-analyst' ? 'sonnet' : 'haiku', schema: args.findingsSchema })))
// One narrow second wave (≤2 agents) for unanswered / under-cited questions
const gaps = (await agent(args.gapPrompt, { phase: 'GapFill', model: 'haiku', schema: args.gapSchema }))
  ?.filter(g => !g.answered || g.citations_count < 2).slice(0, 2) ?? []
const gapFills = await parallel(gaps.map(g => () =>
  agent(`${OS}\n\nResearch only: ${g.q}. Max 5 web searches.`, { label: `gap:${g.q.slice(0,24)}`, phase: 'GapFill', model: 'haiku', schema: args.findingsSchema })))
return { found: found.map((f,i)=>({ name: args.roster[i].name, ok: f!==null, result: f })), gapFills: gapFills.filter(Boolean) }
```

- Model routing per token-budget: `codebase-analyst` → sonnet, retrieval agents → haiku.
- `infra-analyst` included in `args.roster` only when §1.2.5 set `SPAWN_INFRA=true`.
- Each prompt MUST embed the OUTPUT STYLE snippet (Invariant 5) + write-as-you-go rule (§1.3 step 5).
- `null` entries = failed agents; `schema` replaces the §2.1 `classify_output()` gate. Apply the §2.1 abort threshold against the count of non-`null` results.
- After the workflow returns, proceed to §2.2 (summarize) → Phase 3 (synthesize) unchanged.

## Codebase mode (`--codebase`)

Answer a question about the current codebase from evidence, not memory. Rules:

1. **Parse the question.** If it names no symbol, path, or behavior that can be searched, ask one focused `AskUserQuestion` (multiple choice when possible: "Which area: (a) frontend component, (b) backend function, (c) both?"). Never ask more than one; if `autonomy=high|full`, skip the question and state the assumption in one line.
2. **Locate — semantic first, grep second.** Resolve a symbol in this order, stopping at the first that works:
   1. **`LSP`** — workspace symbol search → `goToDefinition` → `findReferences`. One call returns the definition and every call site as a location list. Use it whenever the target is a symbol (function, type, class, constant) in a language with a running server.
   2. **`Grep` / `Glob`** from the most specific term outward (symbol → import sites → routes/config), then `Read` with an `offset` around each hit. Use this when the `LSP` tool is inactive: no language server for the file's language, a binary that is not installed, or a **cloud session**, where Claude Code does not start plugin language servers at all.

   Never read a whole file to find one symbol. For a question wider than ~15 files, spawn one `Explore` subagent (read-only, haiku) with the question and a 150-line reply cap; more than one only when the question has independent halves.
3. **Read before claiming.** Every statement in the answer cites `path:line` you opened in this turn. Quote the load-bearing line verbatim (≤2 lines per cite). No cite → say "not found" rather than guess.
4. **Trace, don't summarize.** For "how does Y work": entry point → each hop (call, event, store mutation, rule) → side effects, as a numbered chain with one cite per hop. For "where is X": ranked list of candidates, best first, with why.
5. **No writes.** No `Write`/`Edit`, no scratch files, no `docs/research/` doc, no session registration or feed lines beyond `task_start`/`task_complete`. If the answer reveals work to do, end with one line: `Next: /blitz:plan <slug>` or `/blitz:build <one-sentence diff>`.
6. **Stop.** Answer ≤40 lines; offer `--codebase` follow-ups only if the user asks.

Output shape:

```
Answer: <one sentence>
1. <hop> — path:line — `<verbatim>`
2. …
Not verified: <anything inferred rather than read>
Next: <optional one line>
```

Everything below is topic research.

### 3.1 Generate Research Document

Write to:
```
docs/research/YYYY-MM-DD_<topic-slug>.md
```

```bash
mkdir -p docs/research    # tracked; docs/_research/ is legacy (gitignored) — never write there
```

**Output style:** terse-technical per [/_shared/output.md](/_shared/output.md). Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, paths, commands, grep patterns, YAML/JSON frontmatter, tables, error codes, dates, versions. No preamble, no trailing summary. Fragments OK. Intensity: `lite` for user-facing Summary + Research-Questions + Risks (reasoning chain must survive); `full` for Findings narrative + Implementation Sketch. Auto-pause for security/irreversible/root-cause sections — write full prose.

**Terse exemptions (LITE intensity):** §7 Risks + Open Questions (full sentences + reasoning chain required). Resume terse on next section.

Use the template from `references/main.md`. Required sections:

1. **Summary** — 3-5 sentence executive summary + recommendation.
2. **Research Questions** — Each question with a concise answer.
3. **Findings** — By theme (not by agent); each finding must cite its source.
4. **Compatibility Analysis** — Fit with detected stack: version compat, dependency conflicts, integration complexity.
5. **Recommendation** — Actionable with rationale; comparison matrix if comparing options. This section is the contract for `/blitz:plan --from-research <doc>`: it must state one `### Decision`, a `### Rationale`, and the affected areas/files so `plan` can derive tasks without re-researching.
6. **Implementation Sketch** — High-level steps adapted to detected stack: key code patterns, file locations, config changes.
7. **Risks** — Known risks, mitigations, open questions.
8. **References** — All cited docs, articles, discussions.

### 2.1 Classify Outputs (canonical gate from spawn-protocol §8)

Run the standard classifier BEFORE reading findings. MISSING / EMPTY / MALFORMED outputs MUST NOT silently pass through as SUCCESS:

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/research/library-docs.md"
  "${SESSION_TMP_DIR}/research/web-researcher.md"
  "${SESSION_TMP_DIR}/research/codebase-analyst.md"
)
[ "$SPAWN_INFRA" = true ] && EXPECTED_OUTPUTS+=("${SESSION_TMP_DIR}/research/infra-analyst.md")

# classify_output() and gate logic from /_shared/agents.reference.md §8
classify_output() {
  local f="$1"
  if [ ! -f "$f" ]; then echo MISSING; return; fi
  if [ ! -s "$f" ]; then echo EMPTY; return; fi
  if grep -q '^PARTIAL: true' "$f"; then
    grep -q '^COMPLETED:' "$f" && grep -q '^MISSING:' "$f" \
      && echo PARTIAL || echo MALFORMED
    return
  fi
  echo SUCCESS
}

declare -A COUNTS=()
for f in "${EXPECTED_OUTPUTS[@]}"; do
  c=$(classify_output "$f")
  COUNTS[$c]=$((${COUNTS[$c]:-0} + 1))
  echo "$f → $c"
done

MISSING_COUNT=$(( ${COUNTS[MISSING]:-0} + ${COUNTS[EMPTY]:-0} + ${COUNTS[MALFORMED]:-0} ))
N=${#EXPECTED_OUTPUTS[@]}
case $N in
  1) THRESHOLD=1 ;;
  2|3) THRESHOLD=2 ;;
  *) THRESHOLD=$(( (N + 1) / 2 )) ;;
esac

if [ "$MISSING_COUNT" -ge "$THRESHOLD" ]; then
  echo "[research] ABORT: $MISSING_COUNT/$N agents failed (threshold $THRESHOLD)" >&2
  # Do NOT clean up — preserve findings dir for inspection
  exit 1
fi
```

### 3.2.5 Citation Validation (research-critic agent)

After §3.1, spawn `agents/research-critic.md` to probe every cited URL (WebFetch HEAD-equivalent) and verify quoted spans. Catches 3-13% URL hallucination rate (arxiv 2604.03173) before `/blitz:plan --from-research` ingests the doc. Critic runs **content inspection** (§2.1.5, TB-4) — fetched pages are untrusted (`sec-content-inspection`; [security.md](/_shared/security.md) §3 TB-4). Reply carries `source_trust: "untrusted"`; cap + scan any interpolated field:

```
Agent({
  subagent_type: "blitz:research-critic",
  description: "Citation + claim validity probe",
  prompt: "Probe all citations in docs/research/${TIMESTAMP}_${TOPIC_SLUG}.md.
           Return canonical JSON with verdict (PASS | CITATIONS_MISSING) and
           per-citation status (LIVE | DEAD | LIKELY_HALLUCINATED | UNKNOWN).
           Output style: terse-technical per /_shared/output.md. Return ONLY the canonical JSON — no prose, no preamble."
})
```

If verdict is `CITATIONS_MISSING`:
- Surface failing citations to the user.
- Skip Phase 3.3 cleanup (preserve `${SESSION_TMP_DIR}/research/` for inspection).
- Mark the doc with a `<!-- WARNING: citation-validity check failed; see issues below -->` comment.
- Do NOT auto-fix; let the user decide whether to retry, accept, or abandon.

Optional: `BLITZ_RESEARCH_NO_CRITIC=1` skips this phase (default-on: the doc feeds `plan`).

### 2.4 Gap Detection (1 Haiku call → optional second wave)

```bash
GAPS=$(Agent({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Identify research-question gaps in summarized findings",
  prompt: "Read ${SYNTHESIS_INPUT_FILES[@]}. For each research question in:
           ${QUESTIONS}
           Return JSON array: [{q: '...', answered: bool, citations_count: int}].
           If answered: false OR citations_count < 2, flag as GAP."
}))
NUM_GAPS=$(echo "$GAPS" | jq '[.[] | select(.answered == false or .citations_count < 2)] | length')
ELAPSED_SEC=$(( $(date +%s) - SESSION_START ))

# One narrow second wave (max 2 agents) if budget allows
if [ "$NUM_GAPS" -gt 0 ] && [ "$NUM_GAPS" -le 2 ] && [ "$ELAPSED_SEC" -lt 600 ]; then
  echo "[research] $NUM_GAPS gap(s) detected; spawning narrow second wave" >&2
  # Spawn a Haiku web-researcher per gap, scoped to that single question
  echo "$GAPS" | jq -c '.[] | select(.answered == false or .citations_count < 2)' | head -2 | while read -r gap; do
    GAP_Q=$(echo "$gap" | jq -r '.q')
    # Agent({...}) spawn here — scope: this single question, max 5 web searches, output to .gap-N.md
  done
fi
```

If gap-fill agents return findings, append summaries to `SYNTHESIS_INPUT_FILES` before synthesis. If gaps remain, surface them in the doc's `## Open questions` section.
