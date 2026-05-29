---
unit: skills/ui-build
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Audit — `skills/ui-build`

## A. Identity & Boundaries

**One-sentence purpose**: Discover a Vue 3 project's design patterns then generate production-grade, framework-native UI in a 5-phase workflow (Discover → Analyze → Design → Implement → Refine).

**Description vs body match**: Accurate. Description names the 5 phases and trigger phrases correctly.

**Overlapping skills/agents**:

| Other unit | Overlapping surface | Classification |
|---|---|---|
| `skills/design-extract` | Both write `DESIGN.md`; `ui-build` §3.0.2 + §3.1 overlap token-discovery work on brownfield runs | **Legitimate layering** — `design-extract` reverse-engineers existing tokens; `ui-build` writes forward-design decisions. Directionality distinct. `ui-build` correctly defers: "run `/blitz:design-extract` first." |
| `frontend-design:frontend-design` | Both produce tone + typography + motion decisions on greenfield | **Legitimate layering** — `ui-build` delegates to `frontend-design` when available; §3.0.1 inline fallback only runs when skill unavailable. Correct. |
| `agents/design-critic` | Both evaluate screenshots against DESIGN.md | **Legitimate layering** — `ui-build` spawns `design-critic` as subagent; not a duplication of logic. |
| `skills/ui-audit` | `ui-audit` audits cross-page consistency post-build; `ui-build` Phase 5.1 runs an inline quality checklist | **Legitimate layering** — `ui-audit` is read-only runtime browser audit; `ui-build` Phase 5 is static source review. No true duplication. |
| `skills/completeness-gate` | Phase 5.1.5 invokes completeness-gate for three-state coverage | **Legitimate layering** — `ui-build` delegates; does not restate gate logic inline. ✓ |

No true duplication found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited | Followed correctly | Notes |
|---|---|---|---|
| `session-protocol.md` | ✓ Phase 0 | ✓ | |
| `verbose-progress.md` | ✓ Phase 0 | ✓ | |
| `terse-output.md` | ✓ (link + snippet) | ✓ Invariant 5 snippet present verbatim | |
| `spawn-protocol.md` | ✗ **NOT cited** | ✗ | Spawns `agents/design-critic` at Phase 5.4.2 with `Agent({...})` call but cites no spawn-protocol. Agent Output Contract, Token Budget & Reply Contract (§9), HEARTBEAT/PARTIAL/WRAP_UP patterns all absent. |
| `token-budget.md` | ✗ NOT cited | ✗ | No model-routing note for the design-critic subagent. |
| `agent-routing.md` | ✗ NOT cited | ✗ | Spawning skill must assert subagents-cannot-spawn-subagents constraint per agent-routing.md. |
| `story-frontmatter.md` | Implicitly consumed (`design_quality:` field at Phase 5.4.2) | Partial | Consumption documented in `story-frontmatter.md:125` ✓, but SKILL.md does not cite the protocol nor reference the field schema. |
| `definition-of-done.md` | ✓ (link, Phase 4 footer) | ✓ | |
| `frontend-design-heuristics.md` | Implicit via `frontend-design:frontend-design` delegation | Partial | Not cited directly; Phase 5.4.2 design-critic prompt references "DESIGN.md heuristics" without naming the shared file. |

### OUTPUT STYLE (Invariant 5)

Snippet present at line 31, verbatim. ✓

### Cross-refs

- `references/main.md` — exists, readable, 221 lines. ✓
- `/_shared/terse-output.md` — standard path. ✓
- `/_shared/session-protocol.md` — ✓
- `/_shared/definition-of-done.md` — cited, assumed live (not independently verified here).
- `skills/design-extract/SKILL.md` — cited at line 128. ✓
- `agents/design-critic.md` — spawned at line 320; file exists (confirmed via design-extract audit).

### State-handoff

`ui-build` is not in the sprint pipeline; `state-handoff.md` does not cover it. The skill consumes `story-frontmatter.md:design_quality` implicitly and produces `.vue`/`.ts` source + `DESIGN.md`. No formal declaration needed (not a pipeline skill), but the `DESIGN.md` artifact is a shared pipeline artifact informally consumed by `design-extract` and `design-critic`. No blocking issue.

### Pipeline trace (one real chain)

`sprint-plan` emits story with `design_quality: standard` → `sprint-dev` dispatches `ui-build` story → `ui-build` Phase 5.4.2 reads `design_quality` from story frontmatter → spawns `design-critic` with screenshots → `design-critic` returns canonical JSON scores → `ui-build` surfaces scores / optionally iterates.

Chain is coherent **except**: `ui-build` does not specify how it reads `design_quality` from story frontmatter at runtime (no `Read` of the story file in Phase 5). Inferred from context; not verified in body. Minor gap.

---

## C. Conciseness

**Body line count**: 409 lines (cap: 500). Within cap. ✓

### Anti-laziness / defensive prose candidates for deletion

| Lines | Quote | Failure mode guarded | Delete? |
|---|---|---|---|
| 377–393 | `## Critical Anti-Patterns (NEVER DO THESE)` — 8 bullet restatements of rules already in Implementation Gate table (lines 183–194) and Code Quality Gates (lines 247–255) | Guarded against model forgetting rules stated 60 lines earlier; 4.8 honesty renders defensive restatement unnecessary | **Delete** (~18 lines savings) |
| 400–410 | `## Production Readiness (NON-NEGOTIABLE) … BANNED PATTERNS` block | Anti-placeholder guard; cites `definition-of-done.md` but then restates the same patterns inline | **Delegate** — move to `definition-of-done.md` (or already there); remove inline restatement (~15 lines savings) |
| 248–255 | `#### Code Quality Gates` list under Phase 4 body | Duplicates Implementation Gate *table* rows 183–194 in prose form | **Delete** (~8 lines savings) |
| 24 | `"Never skip phases."` inline instruction | Anti-skipping nudge; model comprehension at 4.8 does not require it | **Delete** (1 line) |

Estimated removable: **~55 lines** (anti-duplication + anti-laziness nudges).

### Content belonging in shared protocols (DRY candidates)

- Three-state template (lines 228–244) is Vue-specific; belongs in `references/main.md` (already referenced) not in SKILL.md body.
- Aesthetic gates bash block (lines 202–221) is reusable across any UI-touching skill; candidate for `references/main.md`.

---

## D. Modernization

### Native primitive overlap

**`disallowed-tools` frontmatter** (platform-delta.md v2.1.152): `ui-build` does not use this. Phase 4 bans `console.log`, `!important`, etc., enforced by bash checks. Could add `disallowed-tools: TaskCreate` (no subagent spawning except design-critic) but the real anti-patterns are runtime code patterns, not tool use — no strong candidate here. **Keep as-is; no blocking gap.**

**Workflows / native orchestration** (platform-delta.md v2.1.154+): 5-phase linear workflow. Not a fan-out pattern; no native workflow overlap. **Keep as-is.**

**`/simplify` native** (platform-delta.md v2.1.154): Phase 5.1 quality checklist could be partially delegated to `/simplify` for code-quality pass. Low value — `ui-build`'s Phase 5 is Vue-specific (three-state, A11y, responsive); `/simplify` covers generic reuse/efficiency. **Keep as-is.**

**`/goal` completion loop** (platform-delta.md v2.1.139): Phase 5.1.5 runs completeness-gate once. Could be wrapped in `/goal` for loop-until-pass on `design_quality: high`. **Delegate** — low-priority but clean fit.

### Model / effort frontmatter

`model: opus` — correct. 5-phase generative build with aesthetic judgment, A11y reasoning, multi-framework branching. Sonnet is insufficient for brownfield discovery + design decisions in single pass.

`effort: high` — correct.

`compatibility: ">=2.1.71"` — stale. Spawns `design-critic` subagent; `disallowed-tools` available since v2.1.152; `design_quality` story field implies sprint-plan integration which requires `>=2.1.117`. **Bump to `>=2.1.117`** (matching `design-extract`'s floor).

**`claude-opus-4-8` fast mode** (platform-delta.md fast-mode-2026-02-01): Generative UI build is latency-sensitive. Fast mode ($10/$50 per MTok) is 3x cheaper than prior Opus fast mode. Worth noting in `token-budget.md` routing; no SKILL.md change required.

---

## E. Correctness

**Stale compatibility floor**: `>=2.1.71` should be `>=2.1.117` (see §D).

**Missing `spawn-protocol.md` citation**: Phase 5.4.2 `Agent({...})` call violates the requirement that spawning skills cite `spawn-protocol.md`. No HEARTBEAT, no PARTIAL, no WRAP_UP, no token budget guard, no three-tier timeout. **Blocking gap.**

**`story-frontmatter.md` `design_quality` field read path**: Phase 5.4.2 says "Story frontmatter `design_quality:` controls this step" but body never shows how the field is read at runtime. Model must infer. Needs one explicit Read instruction pointing to the story file.

**`frontend-design-heuristics.md` not cited**: Phase 5.4.2 design-critic prompt says "DESIGN.md heuristics" but the canonical heuristics file is `/_shared/frontend-design-heuristics.md`. Prompt should name the file explicitly so design-critic receives it.

**Subagents-cannot-spawn-subagents**: `ui-build` is slash-invoked (not a subagent). Spawning `design-critic` is valid. No violation.

**Model IDs** (platform-delta.md 2026-05-28): `model: opus` is an alias. Not a breaking issue but token-budget.md routing matrix uses `claude-opus-4-8`; alignment preferred.

---

## F. Verdict

**`needs-tightening`**

### Top 3 highest-leverage edits

1. **Add `spawn-protocol.md` citation + Agent Output Contract to Phase 5.4.2** — missing HEARTBEAT/PARTIAL/three-tier timeout for design-critic spawn. Cite `/_shared/spawn-protocol.md` in Phase 0 references block; add minimal timeout + WRAP_UP guard to Agent() call.

2. **Delete `## Critical Anti-Patterns` + `## Production Readiness` blocks (lines 376–410)** — ~33 lines of rule restatements already covered by Implementation Gate table and `definition-of-done.md` reference. Pure 4.8-era defensive duplication.

3. **Bump `compatibility` to `>=2.1.117`** and name `/_shared/frontend-design-heuristics.md` explicitly in Phase 5.4.2 design-critic prompt.
