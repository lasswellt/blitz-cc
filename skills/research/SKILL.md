---
name: research
description: "Investigates libraries, APIs, frameworks, and architecture patterns via parallel research agents (domain, library, codebase, optional infra). Produces a structured docs/_research/<date>_<topic>.md with scope: YAML for /blitz:roadmap ingestion. Use when the user says 'research X', 'compare options', 'evaluate library Y', or '/blitz:research <topic>'."
argument-hint: "<topic>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
model: opus
effort: high
compatibility: ">=2.1.71"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For research document template, research types, and section guidelines, see [references/main.md](references/main.md)
- For context window hygiene, see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For quantified scope → registry ingestion, see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For the opt-in `Workflow` (dynamic-workflows) dispatch path + capability gate, see [agent-orchestration.md](/_shared/agent-orchestration.md)
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)

All research output must satisfy the [Definition of Done](/_shared/sprint-contracts.md). No placeholder sections.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Research Skill

Investigate a topic by spawning parallel research agents, collecting findings, and synthesizing a structured research document. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE TOPIC — Understand What to Research

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Extract Research Topic

Parse the user's request to identify:
- **Topic**: Primary subject (library, API, pattern, architecture decision)
- **Topic slug**: Lowercase, hyphenated for file naming (e.g., `auth-strategy`, `state-machine-libs`)
- **Research type**: Library Evaluation | Architecture Decision | Feature Investigation | Comparison (see references/main.md)
- **Scope constraints**: Any user-specified constraints (must work with X, needs Y, cannot use Z)
- **Decision context**: Why this research is needed

### 0.2 Formulate Research Questions

Generate 3-6 specific questions to answer (e.g.: TypeScript support, breaking changes, framework integration, performance at scale, security implications).

### 0.3 Build Codebase Context

```bash
find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -10
```
Read root `package.json`; note detected stack profile; identify existing code related to the topic.

---

## Phase 1: SPAWN RESEARCH AGENTS — Parallel Investigation

### 1.1 Create Working Directory

```bash
RESEARCH_DIR="${SESSION_TMP_DIR}/research"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
rm -rf "${RESEARCH_DIR}"
mkdir -p "${RESEARCH_DIR}"
```

### 1.2 Determine Required Agents

Spawn 2-4 agents depending on research type:

| Agent Name | Role | Always Spawned | Model | Focus |
|---|---|---|---|---|
| `library-docs` | Library & Documentation Research | Yes | haiku | Official docs, API surface, version history, migration guides, known issues, changelogs |
| `web-researcher` | Web & Community Research (contrarian role) | Yes | haiku | Blog posts, GitHub issues, benchmarks, community sentiment, **counter-evidence + post-mortems** |
| `codebase-analyst` | Codebase Analysis | Yes | sonnet | Existing patterns, integration points, migration impact, affected files, dependency graph |
| `infra-analyst` | Infrastructure Analysis | Conditional (§1.2.5) | haiku | Cloud service docs, pricing, quotas, deployment implications, environment config |

Model routing follows [agent-orchestration.md](../_shared/agent-orchestration.md): retrieval-class workloads (library-docs, web-researcher, infra-analyst) → Haiku 4.5 (12× cheaper than Sonnet, comparable hallucination rate per arxiv 2604.03173). Semantic codebase reasoning (codebase-analyst) → Sonnet 4.6.

### 1.2.5 Spawn-N Gate (skip unneeded agents)

`infra-analyst` is conditional — spawn only when stack has cloud/infra concerns:

```bash
SPAWN_INFRA=false
# Detect via package.json deps + CLAUDE_PLUGIN env
if grep -qE '"(firebase|firebase-admin|@google-cloud|aws-sdk|@aws-sdk|@azure|stripe|twilio)"' package.json 2>/dev/null \
   || grep -qE 'firebase\.json|wrangler\.toml|serverless\.yml|terraform/' . 2>/dev/null; then
  SPAWN_INFRA=true
fi

# Override: user can force via env var
[ "${BLITZ_RESEARCH_FORCE_INFRA:-0}" = "1" ] && SPAWN_INFRA=true

[ "$SPAWN_INFRA" = false ] && echo "[research] infra-analyst skipped (no cloud/infra detected; set BLITZ_RESEARCH_FORCE_INFRA=1 to override)" >&2
```

Saves ~$0.10/run on ~40% of runs (token-economics §9 Gap 6).

### 1.2.6 Select Dispatch Mode (capability gate)

Per [agent-orchestration.md](/_shared/agent-orchestration.md). Both paths produce identical findings files under `${SESSION_TMP_DIR}/research/`; only the orchestration mechanism differs.

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;                 # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;                # auto: use Workflow iff tool present
esac
echo "[research] dispatch=${BLITZ_DISPATCH:-auto} use_workflow=${USE_WORKFLOW}" >&2
```

- **`USE_WORKFLOW` truthy AND `Workflow` tool available** → §1.3-W (Workflow path).
- **else, or on ANY `Workflow` failure** → fall back to §1.3 (`Agent()` path). Never hard-fail.
- Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`.
- The `Workflow` script touches NO filesystem: working-dir creation (§1.1), `${SESSION_TMP_DIR}` polling, summarization (§2.2), classify (§2.1), synthesis (Phase 3), and activity-feed writes all stay in this skill's main-thread Bash (hybrid wrapper boundary).

### 1.3-W Dispatch via Workflow (opt-in path)

Dispatch agents as one `parallel()` barrier; gap second-wave (§2.4) as a conditional `agent()` in the same script — replacing manual poll (§1.7) + classify (§2.1) + jq-gated second wave with native primitives.

```js
export const meta = { name: 'research', description: 'Parallel research agents + conditional gap second-wave', phases: [{ title: 'Investigate' }, { title: 'GapFill' }] }
// args: { roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema } — prompts embed OUTPUT STYLE + write-as-you-go
const found = await parallel(args.roster.map(a => () =>
  agent(a.prompt, { label: a.name, phase: 'Investigate',
    model: a.name === 'codebase-analyst' ? 'sonnet' : 'haiku', schema: args.findingsSchema })))
// One narrow second wave (≤2 agents) for unanswered / under-cited questions
const gaps = (await agent(args.gapPrompt, { phase: 'GapFill', model: 'haiku', schema: args.gapSchema }))
  ?.filter(g => !g.answered || g.citations_count < 2).slice(0, 2) ?? []
const gapFills = await parallel(gaps.map(g => () =>
  agent(`Research only: ${g.q}. Max 5 web searches.`, { label: `gap:${g.q.slice(0,24)}`, phase: 'GapFill', model: 'haiku', schema: args.findingsSchema })))
return { found: found.map((f,i)=>({ name: args.roster[i].name, ok: f!==null, result: f })), gapFills: gapFills.filter(Boolean) }
```

- Model routing per token-budget: `codebase-analyst` → sonnet, retrieval agents → haiku.
- `infra-analyst` included in `args.roster` only when §1.2.5 set `SPAWN_INFRA=true`.
- Each prompt MUST embed the OUTPUT STYLE snippet (Invariant 5) + write-as-you-go rule (§1.3 step 5).
- `null` entries = failed agents; `schema` replaces the §2.1 `classify_output()` gate. Apply the §2.1 abort threshold against the count of non-`null` results.
- After the workflow returns, proceed to §2.2 (summarize) → Phase 3 (synthesize) unchanged.

### 1.3 Spawn Agents via Agent Tool (default path)

Spawn each agent in **a single assistant message** (so they run concurrently) using the `Agent` tool with:

- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails the write)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from the Opus orchestrator)
- `description: research <agent-name>`
- `prompt`: the agent prompt template from Section 1.5 below, filled with topic, questions, output path, and stack profile
- `run_in_background: true` (orchestrator polls output files in Phase 1.7)

Each agent prompt MUST include: research topic + questions; detected stack profile; output file path (`${SESSION_TMP_DIR}/research/<agent-name>.md`); research limits (§1.5); write-as-you-go rule ("Stub your output file with `# IN PROGRESS` before your first tool call. Append findings as you discover them. Do NOT accumulate in memory.").

Cross-cutting findings synthesized by orchestrator in Phase 2 (not peer-to-peer; per [agent-orchestration.md](/_shared/agent-orchestration.md)).

### 1.5 Research Limits Per Agent

| Agent | Max Web Searches | Max Files Read | Max Output Length |
|---|---|---|---|
| `library-docs` | 8 | 5 | 200 lines |
| `web-researcher` | 10 | 3 | 200 lines |
| `codebase-analyst` | 0 | 15 | 150 lines |
| `infra-analyst` | 6 | 8 | 150 lines |

### 1.6 Agent Prompt Templates

The 4 templates share a canonical preamble (OUTPUT STYLE + BUDGET + WRITE-AS-YOU-GO + JSON reply contract). Full preamble + per-agent role text live in [`references/main.md`](references/main.md) §Agent Prompt Templates — paste from there into each Agent() spawn. Orchestrator MAY mark the canonical preamble `cache_control: {type: "ephemeral", ttl: "1h"}` once the total static prefix crosses 1024 tokens (after Haiku-routing migration).

**Templates by role** (all consume the canonical preamble):
- `library-docs` — model: haiku. Official docs, API surface, version compat. Citation rule: structured entries, no `[QUOTE_UNVERIFIED]` text.
- `web-researcher` — model: haiku. **Contrarian role** (counter-evidence focus to mitigate agent-agreement bias per arxiv 2604.02923).
- `codebase-analyst` — model: sonnet. Semantic codebase reasoning, no web search. file:LINE cites.
- `infra-analyst` — model: haiku. **Conditional** (§1.2.5 spawn-N gate). Cloud + deployment.

### 1.7 Wait for Completion

```bash
for f in ${SESSION_TMP_DIR}/research/*.md; do
  [ -s "$f" ] && echo "DONE: $f" || echo "PENDING: $f"
done
```

**Timeout:** If any agent has not produced output after 3 minutes, mark it as failed and proceed with available findings.

---

## Phase 2: COLLECT AND VALIDATE — Gather All Findings

### 2.1 Classify Outputs (canonical gate from spawn-protocol §8)

Run the standard classifier BEFORE reading findings. MISSING / EMPTY / MALFORMED outputs MUST NOT silently pass through as SUCCESS:

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/research/library-docs.md"
  "${SESSION_TMP_DIR}/research/web-researcher.md"
  "${SESSION_TMP_DIR}/research/codebase-analyst.md"
)
[ "$SPAWN_INFRA" = true ] && EXPECTED_OUTPUTS+=("${SESSION_TMP_DIR}/research/infra-analyst.md")

# classify_output() and gate logic from /_shared/agent-orchestration.md §8
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

### 2.2 Summarize Each Agent File (Haiku — token saving)

Compress via Haiku summarization-on-read before synthesis (Pattern B from token-economics §5; saves ~$0.26/run on ~100K tokens):

```bash
for f in "${EXPECTED_OUTPUTS[@]}"; do
  [ "$(classify_output "$f")" = "SUCCESS" ] || continue
  Agent({
    subagent_type: "general-purpose",
    model: "haiku",
    description: "Summarize $(basename $f .md) findings to ≤30 lines",
    prompt: "Read ${f}. Output ≤30 lines listing the most important findings as
             bullets. Preserve URLs, file:line refs, dates, version numbers verbatim.
             Drop prose. Write to ${f}.summary.md. Return canonical JSON reply with
             status + files_changed."
  })
done

# Synthesizer reads SUMMARIES, not raw findings
SYNTHESIS_INPUT_FILES=()
for f in "${EXPECTED_OUTPUTS[@]}"; do
  [ -f "${f}.summary.md" ] && SYNTHESIS_INPUT_FILES+=("${f}.summary.md") || SYNTHESIS_INPUT_FILES+=("$f")
done
```

If a Haiku summarizer fails or times out, fall back to the raw file — never skip the agent's findings entirely.

### 2.3 Cross-Reference Findings

Read `SYNTHESIS_INPUT_FILES` and surface:
- **Contradictions** — Document explicitly in `## Dissent / Contradictory Evidence`; never silently collapse to consensus (mitigates agent-agreement bias per arxiv 2604.02923).
- **Gaps** — Unanswered questions → §2.4.
- **Convergence** — Require ≥3 distinct source domains before treating consensus as established; single-domain consensus is rejected.

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

---

## Phase 3: SYNTHESIZE — Produce Research Document

### 3.1 Generate Research Document

Write to:
```
docs/_research/YYYY-MM-DD_<topic-slug>.md
```

```bash
mkdir -p docs/_research
```

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, paths, commands, grep patterns, YAML/JSON frontmatter (especially `scope:`), tables, error codes, dates, versions. No preamble, no trailing summary. Fragments OK. Intensity: `lite` for user-facing Summary + Research-Questions + Risks (reasoning chain must survive); `full` for Findings narrative + Implementation Sketch. Auto-pause for security/irreversible/root-cause sections — write full prose.

**Terse exemptions (LITE intensity):** §7 Risks + Open Questions (full sentences + reasoning chain required). Resume terse on next section.

Use the template from `references/main.md`. Required sections:

1. **Summary** — 3-5 sentence executive summary + recommendation.
2. **Research Questions** — Each question with a concise answer.
3. **Findings** — By theme (not by agent); each finding must cite its source.
4. **Compatibility Analysis** — Fit with detected stack: version compat, dependency conflicts, integration complexity.
5. **Recommendation** — Actionable with rationale; comparison matrix if comparing options.
6. **Implementation Sketch** — High-level steps adapted to detected stack: key code patterns, file locations, config changes.
7. **Risks** — Known risks, mitigations, open questions.
8. **References** — All cited docs, articles, discussions.

### 3.1.1 Emit Structured Scope (when quantified)

If any finding or recommendation contains a **quantified scope claim** — regex match: `\d+\s+(files|components|modals|routes|tests|endpoints|pages|views|tables|endpoints|migrations|fields|records)` in the Summary, Findings, or Recommendation sections — the research doc MUST include a `scope:` YAML frontmatter block at the top of the file, above the `# <title>` heading.

Machine-readable contract parsed by `roadmap extend`; without it quantified claims silently drop between sprints. Full `scope:` format, 5 emission rules, pre-write cross-check: [references/main.md](references/main.md#structured-scope-emission). Registry protocol: [sprint-contracts.md](/_shared/sprint-contracts.md).

### 3.2 Quality Gates

Before finalizing:
- Every research question has an answer (even if "insufficient data").
- Recommendation is specific and actionable (not "it depends").
- Implementation sketch references real project paths and patterns.
- No agent's findings are silently dropped.
- **Scope block present** whenever the doc contains quantified scope language — or an explicit `<!-- no-registry: <reason> -->` comment. No un-registered quantified claims are allowed to land in `docs/_research/`.

### 3.2.5 Citation Validation (research-critic agent)

After §3.1, spawn `agents/research-critic.md` to probe every cited URL (WebFetch HEAD-equivalent) and verify quoted spans. Catches 3-13% URL hallucination rate (arxiv 2604.03173) before `/blitz:roadmap` ingestion. Critic runs **content inspection** (§2.1.5, TB-4) — fetched pages are untrusted (`sec-content-inspection`; [threat-model.md](/_shared/security.md) §3 TB-4). Reply carries `source_trust: "untrusted"`; cap + scan any interpolated field:

```
Agent({
  subagent_type: "blitz:research-critic",
  description: "Citation + claim validity probe",
  prompt: "Probe all citations in docs/_research/${TIMESTAMP}_${TOPIC_SLUG}.md.
           Return canonical JSON with verdict (PASS | CITATIONS_MISSING) and
           per-citation status (LIVE | DEAD | LIKELY_HALLUCINATED | UNKNOWN).
           Output style: terse-technical per /_shared/terse-output.md. Return ONLY the canonical JSON — no prose, no preamble."
})
```

If verdict is `CITATIONS_MISSING`:
- Surface failing citations to the user.
- Skip Phase 3.3 cleanup (preserve `${SESSION_TMP_DIR}/research/` for inspection).
- Mark the doc with a `<!-- WARNING: citation-validity check failed; see issues below -->` comment.
- Do NOT auto-fix; let the user decide whether to retry, accept, or abandon.

Optional: `BLITZ_RESEARCH_NO_CRITIC=1` skips this phase (default-on for docs destined for `/blitz:roadmap` ingestion).

### 3.3 Clean Up (CONDITIONAL — preserve findings on failure)

```bash
DOC_PATH="docs/_research/${TIMESTAMP}_${TOPIC_SLUG}.md"
SYNTHESIS_OK=false
if [ -f "$DOC_PATH" ] && [ "$(wc -l < "$DOC_PATH")" -ge 50 ]; then
  if [ "${CRITIC_VERDICT:-PASS}" = "PASS" ]; then
    SYNTHESIS_OK=true
  fi
fi

if [ "$SYNTHESIS_OK" = true ]; then
  rm -rf "${SESSION_TMP_DIR}/research"
else
  echo "[research] PRESERVING ${SESSION_TMP_DIR}/research for inspection (synthesis missing/short or critic flagged)" >&2
fi
```

---

## Phase 4: REPORT — Present to User

### 4.1 Output Summary

```
Research Complete: <topic>
========================
Document: docs/_research/YYYY-MM-DD_<topic-slug>.md
Agents: <succeeded>/<total> succeeded
Questions answered: <N>/<total>

Key Finding: <one-sentence top finding>
Recommendation: <one-sentence recommendation>
```

### 4.2 Follow-Up Suggestions

Suggest next steps. Full research-outcome → skill table: [references/main.md](references/main.md#follow-up-skill-graph).

---

## Error Recovery

- **No web search available**: Skip `library-docs` and `web-researcher` web searches; rely on `codebase-analyst`; inform user research is limited.
- **Topic too broad**: Ask user to narrow scope; suggest specific sub-topics.
- **No relevant codebase code found**: Greenfield investigation — skip codebase compatibility analysis; focus on stack-level compatibility.
- **Contradictory findings**: Present both sides with evidence; let recommendation acknowledge the trade-off.
- **Agent timeout**: Proceed with available findings; note which agent timed out and coverage lost.
