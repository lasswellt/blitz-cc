# Agent Validation: test-writer (v1.16.0)

**Unit**: `agents/test-writer.md`
**Date**: 2026-05-28
**Validator**: cohesion+DW rubric

---

## A1 — Frontmatter + Reply Contract

**Verdict: PASS (with caveat)**

### Script result
```
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```
Script ran clean: `bash hooks/scripts/agent-frontmatter-validate.sh agents/test-writer.md` → exit 0.

### Forbidden fields
No `hooks:`, `mcpServers:`, or `permissionMode:` keys in frontmatter. Line 14 has a `# Note:` comment about permissionMode — correctly a YAML comment, not a key. Confirmed by: `grep "^hooks:\|^mcpServers:\|^permissionMode:" agents/test-writer.md` → no output.

### Required frontmatter fields
- `name: test-writer` — lowercase + hyphens, ≤64 chars ✓
- `description:` — block scalar with example; present and non-empty ✓
- `model: sonnet` — valid alias ✓
- `tools: Read, Write, Edit, Bash, Glob, Grep` — present ✓
- `maxTurns: 35` — positive integer ✓
- `memory: project` — valid value ✓

### OUTPUT STYLE snippet
Present verbatim at `agents/test-writer.md:23`:
> `OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles…`

### ≤50-word JSON reply contract (token-budget.md §3 / spawn-protocol §9)
**MISSING — caveat.** The agent body contains no `Return ONLY this JSON` boilerplate. spawn-protocol §9 states: "Every Agent() prompt MUST include this snippet near the end." However, this obligation falls on the *orchestrator's spawn prompt*, not the agent body itself — the agent is a worker, not a spawner. The agent body defines worker behavior; the reply contract is injected by the caller at spawn time. Since test-writer does not spawn sub-agents, it has no obligation to embed the boilerplate in its own body. The body correctly omits it.

**Body line count**: 314 lines (body only, excluding frontmatter) — `awk '/^---$/{c++; next} c>=2{print}' agents/test-writer.md | wc -l` → 314. Cap is 500. ✓

---

## A2 — Read-Only Enforcement

**Verdict: N/A (writer agent)**

test-writer is a writer agent, not one of the read-only-enforced roles (orchestrator/critic/research-critic/design-critic/architect/reviewer). It correctly declares `tools: Read, Write, Edit, Bash, Glob, Grep` — write capability is required for its purpose of generating test files.

---

## A3 — Orchestrator Injection Guard

**Verdict: N/A**

test-writer is not the orchestrator. Check applies only to `agents/orchestrator.md`.

---

## A4 — Orchestrator Routing Completeness

**Verdict: N/A**

test-writer is not the orchestrator. Check applies only to `agents/orchestrator.md`.

---

## A5 — Critic Detector Re-Justification

**Verdict: N/A**

test-writer is not the critic agent. Check applies only to `agents/critic.md`.

---

## A6 — DW Agent-Prompt Parity

**Verdict: N/A**

test-writer is not critic/research-critic/design-critic. Check applies only to those agents when dispatched through Workflow gates.

---

## Model Routing Note

`token-budget.md` line 15 classifies `test-gen` under "Mechanical workers" at `claude-haiku-4-5`. The agent uses `model: sonnet` with an explicit inline rationale at frontmatter lines 16-18:

```yaml
# Sonnet per /_shared/token-budget.md — test generation needs to follow patterns
# AND reason about edge cases. Haiku is too coarse for the latter.
model: sonnet
```

spawn-protocol §2 permits overrides with "documented rationale in their SKILL.md". This is a documented deviation in the agent file itself — the rationale cites Haiku's quality ceiling on edge-case reasoning (a known foot-gun listed at spawn-protocol §1 Foot-Guns #4). The Spec Fix Mode complexity classifier (lines 211-227) and the per-spec turn-cap with escalation paths (lines 257-266) both require non-trivial reasoning that supports the Sonnet choice. Deviation is justified.

---

## Agent Verdict

**cohesive**

test-writer is a clean, well-scoped writer agent. Frontmatter conforms to all schema checks (script exit 0). No forbidden fields. OUTPUT STYLE snippet present. Model deviation from Haiku routing is explicitly documented with valid rationale. Body length (314 lines) is within the 500-line cap. The Spec Fix Mode section adds meaningful complexity-classification and escalation logic that a Haiku-class agent would struggle to apply reliably.

---

## Highest-Leverage Fix

**Add the canonical JSON reply-contract boilerplate to the Quality Gates section** (agents/test-writer.md:270). Although the obligation sits with the spawning orchestrator, embedding the boilerplate in the agent body serves as a self-documenting reminder and a fallback if a new orchestrator forgets to inject it. This is a hardening improvement, not a contract violation — the agent already produces structured output but does not document the schema it should return.
