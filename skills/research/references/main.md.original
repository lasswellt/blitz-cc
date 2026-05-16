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

Paste the canonical preamble at the top of every spawn prompt; append the per-agent role section. The preamble is **identical across templates** so the orchestrator can apply `cache_control: {type: "ephemeral", ttl: "1h"}` once the total static prefix crosses 1024 tokens.

### Canonical Preamble (paste verbatim)

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers,
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

REPLY CONTRACT: At task end, return ONLY this JSON to the orchestrator (no markdown
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
[CANONICAL PREAMBLE]

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
[CANONICAL PREAMBLE]

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
[CANONICAL PREAMBLE]

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
[CANONICAL PREAMBLE]

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

Every research doc MUST include structured citations in YAML frontmatter (alongside `scope:`), readable by `agents/research-critic.md` for liveness probing. Fights the documented 3-13% URL hallucination rate (arxiv 2604.03173).

### YAML schema

```yaml
---
scope:
  - id: cf-2026-MM-DD-<slug>
    ...
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

Per validity research §9, scope acceptance checks that name implementation files by exact path are forward-coupled to implementation decisions made later. The `precompact-handoff.sh` instance from the 2026-05-01 session illustrated this: criterion referenced a file that landed elsewhere; only an OR-fallback rescued the check.

Prefer:
- ✅ Outcome: `when PreCompact fires, .cc-sessions/HANDOFF.json contains the active sprint id`
- ❌ Artifact: `test -f hooks/scripts/precompact-handoff.sh`

OR-fallbacks (`test -f path-A || test -f path-B`) remain valid for compatibility but should not be the primary form.

---

## Agent Output Format (legacy — agents now use REPLY CONTRACT JSON)

Pre-v1.11, each research agent wrote findings to a Markdown file in this shape. From v1.11 forward, agents return canonical JSON to the orchestrator AND write Markdown findings (the file uses this format; the JSON references it).

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
```
