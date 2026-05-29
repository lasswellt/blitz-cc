# Agent Validation Report: doc-writer
**Version:** v1.16.0 cohesion+DW validation
**File:** agents/doc-writer.md
**Date:** 2026-05-28
**Validator:** claude-sonnet-4-6

---

## A1 — Frontmatter + Reply Contract

**Verdict: PASS (with minor cross-doc model discrepancy noted)**

**Frontmatter validation script:**
```
$ bash hooks/scripts/agent-frontmatter-validate.sh agents/doc-writer.md
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```
Script exits clean — all required fields present, OUTPUT STYLE regex passes.

**Silently-stripped fields:** `permissionMode` is not present in frontmatter (there is a comment at line 14 acknowledging it is unsupported for plugin agents). `hooks` and `mcpServers` are absent. No silently-stripped fields.

**OUTPUT STYLE snippet:** Present at line 24, extends the canonical with "Auto-pause for security/irreversible/root-cause sections." This extension is explicitly permitted by terse-output.md line 15: "Agents may extend the canonical snippet with a trailing addendum... Extensions are out of scope for the hash check." The canonical prefix matches verbatim.

**Reply contract (token-budget.md §3):** The ≤50-word JSON reply contract is NOT embedded in the agent file. However, per token-budget.md §3: "Every `Agent()` prompt MUST instruct the subagent to return ONLY the canonical JSON." This is a **spawn-site obligation** placed on the orchestrator/skill that invokes doc-writer, not on doc-writer itself. doc-writer is a terminal writer agent — it writes docs to disk and signals completion implicitly. The spawn-protocol Agent Output Contract (spawn-protocol.md §8) similarly governs how the caller interprets outcomes. No self-declaration required of the agent; this is architecturally correct.

**Model routing:** doc-writer.md declares `model: haiku` (line 19). token-budget.md §1 routing matrix line 15 classifies "doc-gen" as a Mechanical worker → `claude-haiku-4-5`. This is consistent.

**Cross-doc discrepancy (WARN, not blocking):** spawn-protocol.md line 49 lists doc-writer's default model as `sonnet`, which contradicts both doc-writer.md (`haiku`) and token-budget.md (Haiku for doc-gen). The agent's own frontmatter follows the authoritative token-budget.md routing matrix. The spawn-protocol table is stale. No runtime impact since the explicit `model:` in frontmatter overrides any default.

---

## A2 — Read-Only Enforcement

**Verdict: N/A**

doc-writer is a writer agent, not a read-only role (architect/critic/research-critic/design-critic/orchestrator/reviewer). It has `tools: Read, Write, Edit, Bash, Glob, Grep` (line 13), which is correct for its documentation-generation function.

The prose constraint "Never modify source files" (line 172) and "Write documentation files only to `docs/` or `docs/generated/` directories" (line 170) are behavioral guards, not tool-level enforcement. This is appropriate — the agent legitimately needs Write/Edit for documentation files, and path scoping is enforced by prose convention (not allowable-tools restriction).

---

## A3 — Orchestrator Injection Guard

**Verdict: N/A**

doc-writer is not the orchestrator agent.

---

## A4 — Orchestrator Routing Completeness

**Verdict: N/A**

doc-writer is not the orchestrator agent.

---

## A5 — Critic Detector Re-Justification

**Verdict: N/A**

doc-writer is not the critic agent.

---

## A6 — DW Agent-Prompt Parity

**Verdict: N/A**

doc-writer is not critic/research-critic/design-critic. It is not dispatched via Workflow at codebase-audit or research gate points.

---

## Summary

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| A1 — Frontmatter + Reply Contract | PASS | `agent-frontmatter-validate.sh` exits clean; model=haiku matches token-budget.md §1; reply contract is spawn-site obligation not agent-level; silently-stripped fields absent |
| A2 — Read-Only Enforcement | N/A | Writer agent; Write/Edit in tools is correct |
| A3 — Orchestrator Injection Guard | N/A | Not orchestrator |
| A4 — Orchestrator Routing Completeness | N/A | Not orchestrator |
| A5 — Critic Detector Re-Justification | N/A | Not critic |
| A6 — DW Agent-Prompt Parity | N/A | Not critic/research-critic/design-critic |

**Agent verdict:** cohesive

**Highest-leverage fix:** Update spawn-protocol.md line 49 to change doc-writer's default model from `sonnet` to `haiku` — the table is stale relative to both doc-writer.md and token-budget.md §1, creating a misleading reference that could cause callers to override the correct `haiku` declaration with a `sonnet` spawn when consulting only spawn-protocol.md.
