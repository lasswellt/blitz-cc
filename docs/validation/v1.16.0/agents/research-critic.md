# v1.16.0 Validation — agents/research-critic.md

**Unit**: research-critic  
**File**: `agents/research-critic.md`  
**Date**: 2026-05-28  
**Validator**: Claude Sonnet 4.6 (val-research-critic-a1b2c3d4)

---

## A1 — Frontmatter + Reply Contract

**Verdict**: PASS

`hooks/scripts/agent-frontmatter-validate.sh agents/research-critic.md` → `[agent-frontmatter-validate.sh] OK: 1 agent .md files conform`

Checks confirmed:
- `name: research-critic` (25 chars, lowercase+hyphens, no reserved words) — `agents/research-critic.md:2`
- `description:` present, 1003 chars (within 1024 cap) — `agents/research-critic.md:3-18`
- `model: sonnet` — `agents/research-critic.md:29`
- `tools: Read, Grep, Glob, Bash, WebFetch` — `agents/research-critic.md:20`
- `maxTurns: 30` — `agents/research-critic.md:21`
- `color: orange` (valid palette token) — `agents/research-critic.md:30`
- `background: true` — `agents/research-critic.md:31`
- Forbidden fields absent: no `hooks:`, `mcpServers:`, or `permissionMode:` in frontmatter

**Reply contract (token-budget.md §3)**:  
Section `## 3. Output Format` (`agents/research-critic.md:194`) declares canonical JSON with `"summary": "<verdict + headline reject reason in ≤50 words>"` — satisfies the ≤50-word summary cap. Extended fields (`verdict`, `citation_health`) are domain-specific additions; the base schema fields (`status`, `summary`, `files_changed`, `issues`, `next_blocked_by`) are all present.

**Agent Output Contract (spawn-protocol.md §8)**:  
Agent is read-only; consumed by the research skill orchestrator at `skills/research/SKILL.md:412-419`. The orchestrator reads `verdict` field and `citation_health` per §3 contract. Output classification (PASS / CITATIONS_MISSING) is a structured verdict, not a file-write, which is consistent with the read-only role.

---

## A2 — Read-Only Enforcement

**Verdict**: PASS

`tools:` frontmatter (`agents/research-critic.md:20`): `Read, Grep, Glob, Bash, WebFetch` — Write and Edit are **absent from the tools list**. This is structural enforcement via the allowed-tools whitelist, not prose assertion.

Body also contains prose assertion at line 41: "You are read-only. Tools: Read, Grep, Glob, Bash, WebFetch. No Write, no Edit, no Agent." and line 226: "never use Write or Edit. You don't have those tools."

**Enforcement is structural** (allowed-tools list lacks Write/Edit/Agent). Prose assertion is redundant reinforcement. No `disallowed-tools:` field needed because Write/Edit are simply not granted. PASS.

---

## A3 — Orchestrator Injection Guard

**Verdict**: N/A

research-critic is not the orchestrator agent. This check applies only to `agents/orchestrator.md`.

---

## A4 — Orchestrator Routing Completeness

**Verdict**: N/A

research-critic is not the orchestrator agent. This check applies only to `agents/orchestrator.md`.

---

## A5 — Critic Detector Re-Justification

**Verdict**: N/A

research-critic is not `agents/critic.md`. The 19-detector taxonomy and KEEP/THIN classification apply only to the shortcut-taxonomy critic. research-critic reviews citation/claim validity in research docs, a completely distinct scope from shortcut detection.

---

## A6 — DW Agent-Prompt Parity

**Verdict**: FAIL (spawn prompt missing OUTPUT STYLE; DW path not applicable)

Two findings:

### Finding 1: research-critic is NOT dispatched via Workflow (N/A for DW parity)

The research skill's Workflow adoption (`workflow-dispatch.md:81`, status "WIRED") covers only the §1.3-W research agent pool (`parallel([library-docs, web-researcher, codebase-analyst, infra-analyst])`) and the conditional gap second-wave agent. The DW research doc confirms: "wrapper synthesizes doc + runs research-critic **as today**" (`docs/_research/2026-05-28_dynamic-workflows-blitz-adoption.md:102`).

research-critic is spawned at `skills/research/SKILL.md:412-419` via `Agent()` outside the Workflow script, in Phase 3 (post-synthesis). The Workflow script operates only in Phase 1 (research agents). Therefore the Workflow prompt-parity check is **N/A for the DW dispatch path**.

### Finding 2: Agent() spawn prompt at §3.2.5 lacks OUTPUT STYLE snippet (FAIL)

spawn-protocol.md §7 (line 417) states: "Every agent spawn MUST inject the terse-output directive ... append to every Agent() prompt template."

The §3.2.5 spawn prompt (`skills/research/SKILL.md:416-418`) is:
```
"Probe all citations in docs/_research/${TIMESTAMP}_${TOPIC_SLUG}.md.
 Return canonical JSON with verdict (PASS | CITATIONS_MISSING) and
 per-citation status (LIVE | DEAD | LIKELY_HALLUCINATED | UNKNOWN)."
```

No OUTPUT STYLE snippet embedded. The snippet does appear in research-critic's own body (`agents/research-critic.md:47-51`), which serves as the agent's system prompt. But spawn-protocol §7 requires it in the user-prompt argument to `Agent()`, ensuring the directive reaches agents even if the agent's system prompt is absent, overridden, or inherited differently.

**workflow-dispatch.md §Mandatory prompt invariants** repeats this requirement: "every `agent()` prompt MUST embed the terse-output snippet ... Centralize prompt assembly so the snippet is structurally unavoidable."

Since the snippet is only in the agent body (system prompt) and not in the spawn-prompt parameter, the Invariant 5 contract is not structurally unavoidable at the spawn site.

---

## Agent Verdict

**needs-tightening**

The agent is functionally correct and structurally read-only. The single gap is the §3.2.5 Agent() spawn prompt in `skills/research/SKILL.md` which omits the mandatory OUTPUT STYLE snippet. The snippet lives in the agent body but not in the spawn-prompt parameter, violating spawn-protocol §7 and the workflow-dispatch §Mandatory prompt invariants requirement for "structurally unavoidable" injection.

---

## Highest-Leverage Fix

Add the canonical OUTPUT STYLE snippet to the §3.2.5 Agent() spawn prompt in `skills/research/SKILL.md:416-418`:

```python
Agent({
  subagent_type: "blitz:research-critic",
  description: "Citation + claim validity probe",
  prompt: """OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers,
pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths,
commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version
numbers. No preamble. No trailing summary of work already evident in the diff or tool
output. Format: fragments OK.

Probe all citations in docs/_research/${TIMESTAMP}_${TOPIC_SLUG}.md.
Return canonical JSON with verdict (PASS | CITATIONS_MISSING) and
per-citation status (LIVE | DEAD | LIKELY_HALLUCINATED | UNKNOWN)."""
})
```

This makes Invariant 5 compliance structurally unavoidable at the spawn site, regardless of how the agent body is loaded.
