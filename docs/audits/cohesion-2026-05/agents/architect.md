---
unit: agents/architect.md
kind: agent
verdict: REFINE
removable_lines: 18
created: 2026-05-28
---

# Cohesion + Modernization Audit — `agents/architect.md`

## A. Role Clarity & Overlap

**Role**: structural analysis specialist — coupling, cohesion, dependency graphs, module boundaries, production-readiness placeholders. Read-only.

**Overlap assessment**:

| Potential overlap | Verdict | Rationale |
|---|---|---|
| `/blitz:codebase-audit` | **Keep distinct** | codebase-audit fans 10 agents across 5 pillars (Architecture, Performance, Security, Maintainability, Robustness); architect is one pillar among those 10. When spawned by codebase-audit, architect IS a delegate; standalone, it answers structural-only questions faster. |
| `/blitz:integration-check` | **Keep distinct** | integration-check = export-to-import wiring, orphan routes, auth coverage. architect = dependency direction, coupling metrics, module-system consistency. Scope non-overlapping. |
| `/blitz:code-doctor` | **Keep distinct** | code-doctor = framework-specific anti-patterns (Vue/Pinia/Firestore). architect = language-agnostic graph analysis. Different detection mechanism and target. |
| `/code-review` (platform skill) | **Keep distinct** | `/code-review` reviews diff for correctness bugs + simplification. architect analyzes whole-codebase structural health. Tempo, scope, and output differ. |

No retire/delegate recommendation. Role is justified and used by `codebase-audit` + `sprint-review` as a sub-agent.

## B. Contract Compliance

### Subagent JSON Reply Contract (`token-budget.md` §3)

**Verdict: NON-COMPLIANT — prose leakage.**

`agents/architect.md` defines a rich output format (Dependency Map, Findings, Health Table, Prioritized Recommendations). This is the **agent's own reply prose**, not a file written to `SESSION_TMP_DIR`. When spawned via `Agent()`, the orchestrator receives this prose directly, violating the `≤50-word summary` JSON contract from `token-budget.md` §3.

The token-budget canonical schema requires:
```json
{"status": "...", "summary": "<≤50 words>", "files_changed": [...], "issues": [...]}
```

The agent currently returns ~200–400-line structured markdown. Spawning skills like `codebase-audit` must either:
1. Accept prose (context-bloat violation), or
2. Instruct architect to write findings to a file and return the canonical JSON (current correct pattern per `spawn-protocol.md` §1 decision matrix row "Architecture analysis with written report").

The agent body has no instruction to write findings to a file and return canonical JSON. The "Collaboration Hints" section mentions `${SESSION_TMP_DIR}/architect-findings.md` but frames it as optional ("if a session temp dir is provided"). This should be mandatory when spawned, with JSON reply.

**Prose-reply leakage confirmed** (lines 94–125: structured markdown response format with no JSON return path).

### Agent Output Contract (`spawn-protocol.md`)

`spawn-protocol.md` §1 explicitly calls out:
> "Architecture analysis with written report → use `general-purpose`; `blitz:architect` is read-only — orchestrator must write report from agent text"

This clarifies the footgun but does NOT fix it in the agent itself. The agent body should include explicit branching: if `SESSION_TMP_DIR` provided → write to file + return JSON; else → return markdown prose (standalone interactive mode).

### Prompt Boilerplate (`agent-prompt-boilerplate.md`)

Agent body does NOT include:
- BUDGET block (Medium class appropriate for 15-turn analysis)
- WRITE-AS-YOU-GO preamble
- HEARTBEAT protocol
- CONFIRMATION line
- PARTIAL degradation block

These are required for Medium/Heavy agents per `agent-prompt-boilerplate.md`. For an agent spawned as part of codebase-audit with `maxTurns: 15`, this is a Medium-class spawn and all four blocks should be present.

**Verdict: missing 4 boilerplate sections**.

### OUTPUT STYLE Snippet

Line 24 of `agents/architect.md` contains the canonical OUTPUT STYLE snippet verbatim — **COMPLIANT**.

## C. Tooling

**Declared tools**: `Read, Glob, Grep, Bash`

**Assessment**:
- Appropriate for read-only structural analysis.
- `Bash` enables `find`, `wc -l`, circular-dep detection scripts — justified.
- No `Write`, `Edit` — correctly absent for a read-only agent.
- Missing `disallowed-tools` frontmatter field (platform-delta.md v2.1.152). As of v2.1.152, `disallowed-tools` in agent frontmatter declaratively enforces the read-only constraint rather than relying on prose instruction. Adding `disallowed-tools: [Write, Edit, NotebookEdit]` would make read-only **enforceable** not just **asserted**.

**"Read-only by construction" assessment**: currently ASSERTED in prose (lines 28–29, 155–157), NOT declaratively enforced. Platform now supports declarative enforcement via `disallowed-tools`. This is a concrete hardening opportunity.

Note: `permissionMode` frontmatter is silently ignored for plugin agents (acknowledged at line 13) — `disallowed-tools` is the correct mechanism.

## D. Model/Effort Under 4.8

**Declared model**: `sonnet` (line 18), with comment noting spawning skill may override to `opus` for heavy reasoning.

**token-budget.md routing matrix** (verified, not inferred): assigns architect to `opus (4.7)` — "Heavy reasoning: architect, security audit, codebase-audit, research orchestrator."

**Conflict**: `token-budget.md` says opus; `agents/architect.md` says sonnet. The inline comment at line 15–17 partially reconciles this ("spawning skill MAY override to opus") but the agent default contradicts the routing matrix.

**4.8 impact**: `claude-opus-4-8` fast mode (platform-delta.md `fast-mode-2026-02-01`) delivers up to 2.5× output tokens/sec at $10/$50 per MTok input/output — 3× cheaper than Opus 4.6/4.7 fast mode. For latency-sensitive architect spawns in sprint-dev wave dispatch, Opus 4.8 fast mode is now cost-competitive with Sonnet in some scenarios. The default-to-sonnet stance is defensible cost-wise but leaves Opus 4.8's graph-reasoning capability (GraphWalks F1 68.1% vs 40.3% for 4.7 — unverified, system-card PDF) on the table.

**Recommendation**: align `model:` with `token-budget.md` routing matrix (set to `opus`) or document the deliberate downgrade rationale inline. Current discrepancy is confusing for skill authors who follow the matrix.

## E. Not Applicable (architect is not a critic agent)

## F. Not Applicable (architect is not an orchestrator)

## Removable Lines

Lines eligible for removal (18 total):

| Lines | Content | Reason |
|---|---|---|
| 129–143 | Escalation Protocol → Cross-Skill Recommendations (14 lines) | Duplicates skill-dispatch knowledge already in orchestrator routing; cross-skill recommendation strings ("Performance issues → /blitz:perf-profile") are orchestrator concerns, not analyst concerns. Architect should emit severity-tagged findings and let the orchestrator route. |
| 145–150 | Collaboration Hints (6 lines, partial) | Lines making file-writing optional ("if a session temp dir is provided") conflict with correct spawn-protocol behavior. Once WRITE-AS-YOU-GO boilerplate is added, this section reduces to 2 lines. Net removable: 4 of 6 lines. |

**Total removable: 18 lines**.

## Top Edits (leverage-ranked)

1. **Add `disallowed-tools: [Write, Edit, NotebookEdit]` to frontmatter** — converts asserted read-only to enforced. Zero behavior change in practice; prevents future misconfiguration. (platform-delta.md v2.1.152)
2. **Add spawn-mode branching** — when `SESSION_TMP_DIR` is defined in prompt args, write findings to `${SESSION_TMP_DIR}/architect-findings.md` and return canonical JSON; else return full markdown. Fixes prose-reply leakage when called by codebase-audit/sprint-review.
3. **Add Medium-class boilerplate** — BUDGET (15 reads, 25 tool calls, 5 min), WRITE-AS-YOU-GO, HEARTBEAT (file-append variant), CONFIRMATION line. Required per `agent-prompt-boilerplate.md`.
4. **Align `model:` with `token-budget.md` routing matrix** — change `model: sonnet` to `model: opus` or add explicit inline rationale for the downgrade. Current conflict is an authoring footgun.
5. **Replace optional `SESSION_TMP_DIR` file-writing (line 148) with mandatory pattern** — remove "if a session temp dir is provided" hedge; write is always required when spawned.
