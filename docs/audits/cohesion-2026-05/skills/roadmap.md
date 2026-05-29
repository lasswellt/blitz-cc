---
unit: skills/roadmap
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `skills/roadmap`

## A. Identity & Boundaries

**Purpose (one sentence):** Generates phased implementation roadmaps from research documents — extracting capabilities, clustering into domains, resolving dependencies, writing `roadmap-registry.json` / `epic-registry.json` / carry-forward registry lines — to satisfy `sprint-plan`'s hard-input gate.

**Description vs body:** Description matches body. Frontmatter description is slightly stale — it says "Extracts capabilities, assesses codebase state, clusters features into domains" (correct) but the extended frontmatter copy in Phase 1.2 (`description:` field of the capability YAML template, lines ~196–196) contains the FULL skill description verbatim as the *default capability description*, which is a copy-paste residue and misleads consumers.

**Overlaps (verified):**

| Other unit | Overlap | Classification |
|---|---|---|
| `skills/research` | Produces `scope:` YAML frontmatter that roadmap ingests (Phase 1.1.5) | Legitimate layering — research is upstream producer |
| `skills/codebase-audit` | Produces `*-epics.md` in `docs/audits/` that roadmap ingests via Phase 0.2 glob | Legitimate layering — audit is alternate upstream producer |
| `skills/sprint-plan` | Consumes roadmap outputs (`epic-registry.json`, `roadmap-registry.json`, `capability-index.json`) | Legitimate layering — sprint-plan is downstream consumer |
| `skills/bootstrap` | Can stub `roadmap-registry.json` + `epic-registry.json` as empty stubs (state-handoff.md §35) | Legitimate layering — bootstrap provides greenfield stubs only |

No true duplication found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited | Followed inline or delegated? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0) | Delegates — "Follow §Session Registration steps 1-9" |
| `verbose-progress.md` | Yes (Phase 0.0) | Delegates |
| `terse-output.md` | Yes (Additional Resources + OUTPUT STYLE snippet) | Delegates |
| `carry-forward-registry.md` | Yes (Phases 1.1.5, 1.1.6, 2.4, 7) | **Partially restated** — Phases 1.1.5 and 2.4 inline full JSONL schemas that duplicate what's in the shared protocol. Drift risk. |
| `state-handoff.md` | Yes (Additional Resources) | Delegates |
| `spawn-protocol.md` | Yes (references/main.md Phases 5.1, 7.1) | Delegates to weight class label + model spec |
| `agent-routing.md` | Not cited | Not cited — subagent spawning in Phases 5, 7 is not validated against the routing constraint |
| `token-budget.md` | Not cited | Not cited — no routing matrix awareness |
| `ratchet-protocol.md` | Not cited | Not cited — skill produces registry artifacts but doesn't record ratchet metrics |
| `shortcut-taxonomy.md` | Not cited | Not cited — no 19-detector reference |
| `knowledge-protocol.md` | Not cited | Not cited |

**Protocols referenced but not listed in Additional Resources:** `agent-routing.md`, `token-budget.md`, `ratchet-protocol.md`, `shortcut-taxonomy.md`, `knowledge-protocol.md` — 5 missing cross-refs.

### Cross-refs live + accurate

- `/_shared/carry-forward-registry.md` — verified live
- `/_shared/state-handoff.md` — verified live
- `/_shared/terse-output.md` — verified live
- `/_shared/session-protocol.md` — verified live
- `/_shared/verbose-progress.md` — verified live
- `/_shared/definition-of-done.md` — not independently verified (not read), inferred live
- `references/main.md` — verified live
- `skills/codebase-audit/SKILL.md Phase 3.3a` — valid cross-ref per audit skill body

### Produces/consumes per state-handoff.md

Verified match:
- Produces: `docs/roadmap/roadmap-registry.json`, `docs/roadmap/epic-registry.json`, `docs/roadmap/capability-index.json`, `.cc-sessions/carry-forward.jsonl` (`created` lines) — all listed in state-handoff.md §roadmap
- Consumes: `docs/_research/**/*.md`, `docs/audits/*-epics.md` — listed in state-handoff.md §41-42

No invented shapes found; all artifact schemas in `references/main.md` are roadmap-internal detail not duplicating shared contracts.

### Invariant 5 — OUTPUT STYLE snippet

SKILL.md line 25: verbatim canonical snippet present. **Pass.**

`references/main.md`: no OUTPUT STYLE snippet. References file is not a SKILL.md — validator targets SKILL.md only. **Not a violation.**

### Pipeline chain trace (roadmap → sprint-plan)

roadmap Phase 8 writes `docs/roadmap/roadmap-registry.json` + `docs/roadmap/epic-registry.json`.
sprint-plan Phase 0 step 2 hard-fails if either is absent (state-handoff.md §32-33).
Epic format (SKILL.md Phase 7.3 / references/main.md §7.3) includes `id`, `title`, `phase`, `domain`, `capabilities`, `status`, `depends_on`, `estimated_points`, `estimated_stories` — sprint-plan consumes `id` + `capabilities` + `depends_on` for dependency ordering. **Chain intact.**

---

## C. Conciseness

- SKILL.md: **508 lines** — at the 500-line cap, 8 lines over.
- `references/main.md`: 661 lines — references file, no per-file cap, but considered in total skill weight.

### Anti-laziness / defensive prose to delete

| Location | Quote | Failure mode guarded | Verdict |
|---|---|---|---|
| SKILL.md line 31 | `"Execute the appropriate mode based on arguments. Do NOT skip phases."` | Pre-4.8 model phase-skipping | Delete under 4.8 honesty |
| SKILL.md line 103 | `"For status mode: Print the status report now and STOP."` (duplicates line 48) | Pre-4.8 instruction following | Merge into single statement at line 48 |
| references/main.md lines 254-270 | Full agent-output validation bash loop with `MISSING_COUNT` re-explained | Pre-4.8 agent output silence | Can delegate to spawn-protocol.md §Output validation; inline is redundant |
| references/main.md lines 649 | `"Parallelize where possible. When spawning agents (Phases 5, 7), run concurrently."` | Pre-4.8 serial execution default | Delete; `run_in_background: true` in spawn calls is sufficient |

Estimated removable lines from SKILL.md body: ~15 (duplicate mode explanations, "Do NOT skip" guards).
Estimated removable lines from references/main.md: ~40 (defensive re-explanations, inline schemas duplicating shared protocols).
**Total estimated removable: ~55 lines.**

### DRY — content that belongs in shared protocol

- SKILL.md Phase 1.1.5 steps 1-6 (lines ~149-176): Full JSONL schema for `carry-forward.jsonl` `created` event is restated verbatim from `carry-forward-registry.md`. Should cite protocol and state only the roadmap-specific fields (`notes` value, `parent: null` rationale).
- SKILL.md Phase 2.4 steps 1-4 (lines ~327-356): `progress` event JSONL schema restated from `carry-forward-registry.md`. Same DRY violation.

---

## D. Modernization

### Native primitive overlap (platform-delta.md citations)

**`disallowed-tools` frontmatter** (platform-delta.md v2.1.152):
Roadmap spawns `Agent` tool with `subagent_type: general-purpose`. No `disallowed-tools` in frontmatter. The anti-shortcut taxonomy (19 detectors) is enforced only via hooks, not declaratively. Could add `disallowed-tools: [Bash]` for domain-spec agents in Phase 5 that only need Read/Write (or document explicitly why Bash is needed per agent). **Verdict: delegate opportunity, low urgency.**

**Native workflow orchestration** (platform-delta.md v2.1.154+):
Phases 5 and 7 spawn multiple `Agent` calls in a single assistant message for parallelism. Platform-delta.md §"Native orchestration" notes JS-script fan-out across dozens–hundreds of parallel subagents with intermediate results in script variables, not context window. Current approach is pre-native-workflow pattern. **Tradeoff:** Native workflows lose the Blitz-specific carry-forward registry writer contract (Phase 1.1.5 / 7 backfill), epic file naming conventions, and DoD gate logic. Keeping the Blitz-side spawn is justified until native workflows support structured artifact contracts. **Verdict: keep (opinionation preserved), revisit when native workflow artifact contracts mature.**

**`/goal` completion-condition loop** (platform-delta.md v2.1.139):
Status mode (Phase 0.4) is a one-shot report. No loop needed. N/A.

**Model/effort frontmatter:**
- `model: opus` — correct per memory note (orchestrator uses opus + sonnet workers). Subagent spawns in references/main.md explicitly set `model: sonnet` to prevent `[1m]` inheritance. **Compliant with memory feedback.**
- `effort: high` — reasonable for full-generation run (Phases 0-8, multiple agent spawns). Appropriate.
- `model: opus` current ID should be `claude-opus-4-8` per platform-delta.md §"Model IDs current as of 2026-05-28". Frontmatter uses alias `opus` — acceptable if the platform resolves aliases; if not, should be updated to `claude-opus-4-8`. **Uncertainty: alias resolution behavior not verified.**

**Opus 4.8 fast mode** (platform-delta.md §fast-mode-2026-02-01):
Roadmap is latency-tolerant (generates large artifact trees). Fast mode not needed. N/A.

**`agent-routing.md` constraint** (subagents-cannot-spawn-subagents):
Roadmap is slash-invoked, so it IS allowed to spawn subagents. Phase 5 and 7 spawn `Agent` calls correctly from the top-level skill. Dynamic Workflows (platform-delta.md v2.1.154+) do not change this calculus for slash-invoked skills — constraint applies to subagents spawning further subagents. **No change needed.**

---

## E. Correctness

### Stale version refs

- `compatibility: ">=2.1.71"` — no evidence this is wrong, but spawn API `subagent_type: general-purpose` requires a more recent version. Not verified against changelog. **Uncertainty: version floor may be too low.**
- references/main.md line 215, 335: `"Previous TeamCreate+SendMessage spawn removed in v1.4.0"` — version tag `v1.4.0` is a Blitz internal version, not a Claude Code version. Confusing in context; should reference sprint/PR where change was made or drop entirely.

### Dead flags/env vars

- `${SESSION_TMP_DIR}` — used in multiple bash snippets (Phase 1.1.5, 2.4, references/main.md Phase 5). Not defined in SKILL.md. Inferred to be set by `session-protocol.md`. If session-protocol doesn't set it, all temp-file writes silently use CWD. **Uncertainty: not verified in session-protocol.md.**
- `${CLAUDE_SKILL_DIR}` — used in Phase 5 path reference (`${CLAUDE_SKILL_DIR}/references/main.md`). Standard platform env var, expected valid.

### Wrong tool names

- `ToolSearch` in `allowed-tools` — verified correct (deferred tool discovery mechanism).
- `Agent` in `allowed-tools` — correct.

### Broken paths

- `/_shared/definition-of-done.md` — not read, inferred live. **Uncertainty.**
- `skills/codebase-audit/SKILL.md Phase 3.3a` — cross-ref to specific phase in another skill. Phase numbering drift is a known risk when audit skill updates.

### SKILL.md line 196 — description field of capability YAML template

```yaml
description: "Generates phased implementation roadmaps from research documents. Extracts capabilities and quantified scope: blocks..."
```

This is the roadmap skill's own description pasted as the *default value* for a capability's `description` field. Should be `"<2-3 sentences describing the capability>"` or similar placeholder. A consumer filling in this template would accidentally copy the skill description. **Bug.**

---

## F. Verdict

**`needs-tightening`**

Skill is coherent, pipeline-correct, and appropriately positioned. No retire/delegate/split/merge warranted. Issues are: 8 lines over body cap (fixable by deferring more to references/), DRY violations on carry-forward JSONL schemas, stale capability template description field, and 5 missing `_shared` protocol cross-refs.

### Top 3 highest-leverage edits

1. **Fix capability YAML template description field** (SKILL.md ~line 196): Replace the roadmap skill's own description pasted there with `"<2-3 sentences describing the capability>"`. This is a latent data-corruption bug for every consumer who copies the template.

2. **Remove inline JSONL schema restatements** (SKILL.md Phase 1.1.5 steps 4-5, Phase 2.4 steps 4 addendum): Replace with single-line cite to `carry-forward-registry.md` writer contract + the roadmap-specific `notes` value. Eliminates drift risk and ~20 lines.

3. **Add `agent-routing.md` + `token-budget.md` to Additional Resources** and add note that Phase 5/7 agents must not spawn further subagents (spawn-protocol §subagents-cannot-spawn-subagents constraint). Currently the subagent prompts in references/main.md don't include this guard.
