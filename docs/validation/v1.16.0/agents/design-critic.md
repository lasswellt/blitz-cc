# Validation Report — agents/design-critic.md (v1.16.0 cohesion+DW)

**Date:** 2026-05-28  
**Validator:** claude-sonnet-4-6 (automated rubric)  
**Unit:** design-critic  
**File:** agents/design-critic.md

---

## A1 — Frontmatter + Reply Contract

### Hook run

```
$ bash hooks/scripts/agent-frontmatter-validate.sh agents/design-critic.md
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```

All 10 checks passed: `name`, `description`, `model: sonnet`, `tools`, `maxTurns: 15`, no forbidden fields (`hooks`, `mcpServers`, `permissionMode` all absent), `color: purple` valid, body 86 lines (cap 500), OUTPUT STYLE snippet present.

### Reply contract divergences

The canonical JSON from token-budget.md §3 (line 529) and spawn-protocol.md §8 (line 529) specifies:

```json
{"status", "summary≤50w", "files_changed", "issues", "next_blocked_by", "metrics"}
```

design-critic's §3 reply (lines 70–92) returns:

```json
{"status", "summary", "files_changed", "issues", "next_blocked_by", "scores", "verdict"}
```

Two deviations:

1. **`metrics` absent** — token-budget.md line 94 states "`metrics` keys are optional but encouraged for any agent that touches code." design-critic is screenshot-only (no code touched), so `metrics` omission is acceptable by spec.

2. **`scores{}` is a domain extension** — not in the canonical schema. The "Return ONLY this JSON" language (agent line 68) advertises scores{} as mandatory output, but it is absent from the canonical contract. ui-build's `jq` parse of the reply will see an unknown key, which is benign (jq ignores extra keys), but the orchestrator cannot rely on `scores{}` existing without explicit contract documentation.

3. **`verdict` field added** (PASS/ITERATE/REWORK) — similarly undeclared in canonical; benign for parsing but undocumented as a consumer-facing extension.

4. **`status` hardcoded to `"complete"`** — design-critic has no partial/failed status handling (lines 70–92 show only `"complete"` in the template). If the agent exhausts context mid-review, no PARTIAL marker is emitted, violating spawn-protocol §8 PARTIAL output classification.

**Verdict for A1:** PASS on frontmatter (validator confirms clean). FAIL on reply contract: `status` fixed to `"complete"` with no PARTIAL path; `scores{}` and `verdict` are undocumented domain extensions not cross-referenced in spawn-protocol or token-budget.

---

## A2 — Read-Only Enforcement

**Frontmatter tools field** (line 16): `tools: Read, Grep, Glob, Bash`

`Write` and `Edit` are absent from `tools:`. The platform enforces this: the agent cannot call tools not listed in frontmatter. This is structural enforcement, not prose assertion.

**Prose confirmation** (line 30): "You are read-only. You have no Write or Edit tools."

Bash is included — this is appropriate for screenshot inspection (`ls /tmp/ui-build-screenshots/`) and heuristic file discovery. Bash with no Write/Edit does not confer write-to-disk capability through the tool protocol.

**Verdict for A2:** PASS. Read-only enforced structurally via `tools:` frontmatter (no Write/Edit listed); prose assertion corroborates.

---

## A3 — Orchestrator Injection Guard (N/A)

design-critic is a pure worker agent, not the orchestrator. No HANDOFF.json or activity-feed jq rendering in this file.

**Verdict for A3:** N/A

---

## A4 — Orchestrator Routing Completeness (N/A)

design-critic is not the orchestrator.

**Verdict for A4:** N/A

---

## A5 — Critic Detector Re-Justification (N/A)

design-critic is a visual scoring agent, not the shortcut-taxonomy critic (`agents/critic.md`).

**Verdict for A5:** N/A

---

## A6 — DW Agent-Prompt Parity

### Dispatch chain

design-critic is spawned only from `skills/ui-build/SKILL.md` Phase 5.4.2 (lines 320–328). The spawn uses `Agent()` with `subagent_type: "blitz:design-critic"`.

**Workflow adoption status:** `ui-build` does NOT appear in the `workflow-dispatch.md` adoption table (lines 80–84 list only `codebase-audit` [WIRED] and `research` [WIRED]). ui-build uses the legacy `Agent()` path exclusively. No `Workflow` dispatch exists at the ui-build gate.

### Prompt parity check (Agent() path)

The spawn prompt in ui-build Phase 5.4.2 (line 326):

```
"Critique screenshots at /tmp/ui-build-screenshots/*.png against DESIGN.md (or frontend-design heuristics if no DESIGN.md). Score 5 dimensions 0–10: Prompt Adherence, Aesthetic Fit, Visual Polish, UX, Creative Distinction. Pass threshold ≥7 on all five. Return canonical JSON."
```

**Missing: OUTPUT STYLE snippet** — token-budget.md §3 line 98 requires every `Agent()` prompt to include the terse-output snippet near the end. The spawn prompt does not embed it. Since design-critic is a named agent (`subagent_type: "blitz:design-critic"`), its system prompt IS the agent body (which does include OUTPUT STYLE on line 33), so the snippet is present in the agent's own context. However, for `Agent()` spawns of named agents, the additional `prompt:` field is prepended to (or overlaid with) the agent body — the agent's own OUTPUT STYLE line covers this case.

**Missing: "Return ONLY this JSON" boilerplate** — token-budget.md §3 line 100 requires this verbatim near the end of every `Agent()` prompt. The spawn prompt says "Return canonical JSON" (loose), not the required boilerplate. This is a gap in the spawn-side prompt, though the agent body itself has "Return ONLY this JSON, nothing else:" on line 68.

**Workflow parity conclusion:** ui-build has NOT adopted Workflow for design-critic dispatch. A6 asks whether prompts dispatched through `Workflow`'s `agent()` carry identical contract. Since this dispatch path does not exist yet, there is no parity gap to measure — but the spawn prompt already omits required boilerplate (OUTPUT STYLE embedding per token-budget, "Return ONLY" verbatim) even on the Agent() path.

**Verdict for A6:** FAIL (partial). ui-build is not a Workflow adopter so no DW parity gap exists yet. However, the Agent() spawn prompt at ui-build Phase 5.4.2 line 326 omits the required "Return ONLY this JSON" boilerplate (token-budget §3:100) — this is a pre-existing gap that would carry forward into any future Workflow migration.

---

## Summary

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| A1 Frontmatter + reply contract | FAIL | Validator: OK; but `status` fixed to `"complete"` (no PARTIAL path), `scores{}`/`verdict` undocumented extensions — agents/design-critic.md:70–92 vs spawn-protocol:529 |
| A2 Read-only enforcement | PASS | `tools: Read, Grep, Glob, Bash` — no Write/Edit listed at agents/design-critic.md:16; structurally enforced |
| A3 Orchestrator injection guard | N/A | Not the orchestrator |
| A4 Orchestrator routing completeness | N/A | Not the orchestrator |
| A5 Critic detector re-justification | N/A | Not the shortcut-taxonomy critic |
| A6 DW agent-prompt parity | FAIL (partial) | ui-build not a Workflow adopter; Agent() spawn prompt at skills/ui-build/SKILL.md:326 omits "Return ONLY this JSON" boilerplate required by token-budget §3:100 |

---

## Agent Verdict

**needs-tightening**

The agent passes structural checks cleanly (validator OK, read-only enforced). Two issues need tightening:

1. The reply contract has no `status: "partial"` path — if the agent exhausts context scoring 5 dimensions on 3 viewports, it emits nothing rather than a PARTIAL, making the orchestrator classify the output as MISSING/TIMEOUT rather than PARTIAL for narrow retry.

2. The `scores{}` and `verdict` domain extensions are not cross-referenced in spawn-protocol or token-budget, making them invisible to orchestrator authors consuming the reply.

---

## Highest-Leverage Fix

**Add a PARTIAL reply path to §3 and register `scores{}` + `verdict` as declared domain extensions in the reply contract block.** Specifically: (a) add a `status: "partial"` branch to the §3 JSON template with a PARTIAL marker (per spawn-protocol §3), and (b) add a one-line comment in §3 noting that `scores{}` and `verdict` are design-critic-specific extensions that consumer orchestrators (ui-build Phase 5.4.2) must `jq`-select by name. This costs ~10 lines and closes the PARTIAL classification gap that would cause silent TIMEOUT vs PARTIAL misrouting on large screenshot sets.
