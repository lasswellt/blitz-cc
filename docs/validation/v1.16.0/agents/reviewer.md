# v1.16.0 Cohesion+DW Validation — agents/reviewer.md

**Date**: 2026-05-28  
**Validator**: claude-sonnet-4-6  
**Unit**: reviewer  
**File**: agents/reviewer.md

---

## A1 — Frontmatter + Reply Contract

**Verdict: PASS**

`hooks/scripts/agent-frontmatter-validate.sh agents/reviewer.md` output:
```
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```

All 10 script checks pass:
- name: `reviewer` (lowercase, ≤64 chars, no reserved words)
- description: present, non-empty, ≤1024 chars
- model: `sonnet` (matches token-budget.md matrix — standard worker)
- tools: `Read, Write, Bash, Glob, Grep` (present, non-empty)
- maxTurns: `20` (positive integer)
- Forbidden fields absent: `hooks`, `mcpServers`, `permissionMode` — correctly excluded; line 14 carries an explanatory comment confirming awareness.
- background: `true` (valid)
- memory: `project` (valid)
- body: 166 lines (well under 500 cap)
- OUTPUT STYLE snippet: present verbatim at line 23

**JSON reply contract (token-budget.md §3)**: reviewer is a leaf worker (does not spawn agents via Agent()); the JSON reply contract applies to callers invoking it via Agent(), not to the agent body itself. The agent produces a Markdown findings file (written incrementally, referenced path returned). No violation.

**Agent Output Contract (spawn-protocol.md §8)**: reviewer writes output to `${SESSION_TMP_DIR}/review-findings.md` or `/tmp/review-findings.md` (lines 39–48). Write-as-you-go protocol declared (lines 36–49). These satisfy the Medium-class mandatory patterns. No contract violation.

**Silently-stripped fields**: none present. Comment at line 14 documents the constraint.

---

## A2 — Read-Only Enforcement

**Verdict: FAIL (prose-only, no tool-level enforcement)**

**Tool list** (agents/reviewer.md line 13): `tools: Read, Write, Bash, Glob, Grep`

Write IS present. The reviewer is intentionally given Write access to produce findings files; spawn-protocol.md §1 table explicitly notes reviewer as "No (Write for findings only)".

**Enforcement mechanism**: prose-only, via Constraints section (lines 179–186):
> "Never create, modify, or delete source files. Only write to the review findings file (`${SESSION_TMP_DIR}/review-findings.md` or `/tmp/review-findings.md`)."

There is **no structural enforcement** (no `disallowed-tools`, no path-scoped Write restriction, no hook) preventing the model from issuing a Write call to a source file path. The constraint relies entirely on in-context instruction compliance.

**Contrast with architect** (spawn-protocol.md §1 table): `blitz:architect` is described as "strictly read-only" and lists only `Read, Glob, Grep, Bash` — Write is absent, providing structural enforcement. The reviewer does not have an equivalent structural guardrail.

**Risk**: A misconfigured prompt or jailbreak-adjacent input could cause the reviewer to write to source files despite the prose constraint. The Constraints section is the only barrier.

**Mitigation present**: The Constraints section is clear and specific (lines 179–186). The Write-As-You-Go Protocol explicitly scopes writes to the findings file path (lines 37–39). These reduce but do not eliminate the risk compared to structural enforcement.

---

## A3 — Orchestrator Injection Guard

**Verdict: N/A**

reviewer is not the orchestrator agent.

---

## A4 — Orchestrator Routing Completeness

**Verdict: N/A**

reviewer is not the orchestrator agent.

---

## A5 — Critic Detector Re-Justification

**Verdict: N/A**

reviewer is not the critic agent.

---

## A6 — DW Agent-Prompt Parity

**Verdict: N/A**

reviewer is not a DW-dispatched critic/research-critic/design-critic agent.

---

## Agent Verdict

**needs-hardening**

The agent is coherent, passes all automated frontmatter checks, and honors the Agent Output Contract. However, A2 reveals a structural gap: Write access is not scoped to the findings file path at the tool level — only at the prose instruction level. The agent could be hardened by removing Write from the tool list and delegating findings-file creation to the orchestrator (as architect does), or by adding a hook that rejects Write calls to non-tmp paths. Neither option is available within the plugin-agent model (hooks are silently stripped), making the prose constraint the only practical lever today. This should be documented as a known limitation.

## Highest-Leverage Fix

Add a comment to the Constraints section (agents/reviewer.md line 182) explicitly noting that tool-level Write scoping is not structurally enforceable in the plugin-agent model, and move the Write-path restriction into a dedicated `disallowed-paths:` frontmatter field when/if Claude Code adds that capability — until then, document the gap in `.cc-sessions/KNOWLEDGE.md` so future callers know to validate reviewer output paths.
