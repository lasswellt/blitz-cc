---
unit: skills/codebase-map
kind: skill
verdict: needs-tightening
removable_lines: 18
created: 2026-05-28
---

# Audit: skills/codebase-map

## A. Identity & Boundaries

**Purpose (one sentence):** Builds `CODEBASE-MAP.md` by spawning 4 parallel dimension agents (Technology, Architecture, Quality, Concerns) and synthesizing cross-dimensional recommendations for brownfield onboarding and sprint-planning prereqs.

**Description ↔ body match:** Accurate. Description cites the 4 dimensions, the output artifact, and the trigger phrases. Body implements exactly that.

**Overlap analysis:**

| Skill/Agent | Overlap Zone | True Dup vs Layering |
|---|---|---|
| `codebase-audit` | Both analyze architecture, quality, security/concerns of the same codebase | **Legitimate layering** — `codebase-map` is orientation (what is here?); `codebase-audit` is judgement (what is wrong?). `codebase-audit` spawns 10 agents, produces roadmap-ingestible findings. `codebase-map` spawns 4, produces human-readable snapshot. Triggers differ. |
| `health` | Both surface concerns, dependency health, quality signals | **Legitimate layering** — `health` is a fast point-in-time status check; `codebase-map` is a persistent reference artifact. |
| `code-doctor` | Quality / tech-debt surface | **Legitimate layering** — `code-doctor` prescribes fixes; `codebase-map` describes state. |
| `sprint-plan` | `sprint-plan` trigger hints include "analyze project" | Minor trigger-phrase collision; resolved by `state-handoff.md` pipeline position (`codebase-map → roadmap → sprint-plan`). Not a real dup. |

No true duplicates found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited in SKILL.md | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Phase 0.0 (by ref) | Followed — "Follow session-protocol.md §Session Registration" |
| `verbose-progress.md` | Phase 0.0 (by ref) | Followed — by ref, not restated |
| `spawn-protocol.md` | Phase 1.2 (by ref) | Partially followed — explicitly sets `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: false`. Inline restatement of weight-class cap (file cap, 25 tool calls, 250-line output, 5-min wall-clock) duplicates `spawn-protocol.md` Medium-class definition. **Drift risk.** |
| `terse-output.md` | OUTPUT STYLE block | Verbatim canonical snippet present — **Invariant 5 satisfied** in SKILL.md. |
| `agent-prompt-boilerplate.md` | `references/main.md` via `<!-- import: -->` comment | `references/main.md` has `<!-- import: /_shared/agent-prompt-boilerplate.md -->` comment but does NOT actually import — it keeps inline copies of BUDGET, WRITE-AS-YOU-GO, HEARTBEAT, CONFIRMATION sections. Comment is aspirational, not functional. The OUTPUT STYLE snippet in the agent prompt template is verbatim-correct — **Invariant 5 satisfied** in `references/main.md`. |
| `state-handoff.md` | Not cited | **Not cited, not violated.** `codebase-map` is pipeline-adjacent (feeds roadmap) but is not itself listed in `state-handoff.md`'s pipeline table. No artifact produced that state-handoff tracks. |
| `story-frontmatter.md` | Not applicable | Skill does not produce story files. Correct. |
| `token-budget.md` | Not cited | `model: opus` + `effort: medium` frontmatter set. Per `platform-delta.md` (2026-05-28), current Opus is `claude-opus-4-8`. Frontmatter uses `model: opus` alias — acceptable if alias resolves correctly, but `token-budget.md` routing matrix should be consulted. **Inferred — did not read token-budget.md.** |

### Cross-reference liveness

- `references/main.md` — exists, verified read.
- `/_shared/spawn-protocol.md` — cited, exists (confirmed by `skill-cross-references.md` grep).
- `/_shared/session-protocol.md` — cited, exists.
- `/_shared/verbose-progress.md` — cited, exists.
- `/_shared/terse-output.md` — cited, exists.
- `/_shared/agent-prompt-boilerplate.md` — cited in `references/main.md`, exists.

All cross-refs appear live.

### State-handoff / story-frontmatter shapes

Skill produces `CODEBASE-MAP.md` at project root. Not tracked in `state-handoff.md` pipeline table. Acceptable — `codebase-map` is an on-ramp tool consumed by humans and `roadmap`, not by a skill with a formal contract. No invented shapes conflict with existing contracts.

### Pipeline chain trace

`codebase-map → CODEBASE-MAP.md → (human reads) → /blitz:roadmap extend`

`roadmap extend` reads `docs/_research/*.md` and `scope:` frontmatter; it does NOT read `CODEBASE-MAP.md` directly (confirmed: `state-handoff.md` research section). Chain is informal (human-mediated) — that's intentional per the skill's onboarding purpose. No broken contract.

---

## C. Conciseness

**Body line count:** SKILL.md = 176 lines (well within 500-line cap). `references/main.md` = ~180 lines (not subject to SKILL.md cap).

**Anti-laziness prose to mark for deletion:**

Line 27 (SKILL.md):
> `Execute every phase in order. Do NOT skip phases.`

Guards model tendency to skip phases. With 4.8 honesty gains (platform-delta.md, `claude-opus-4-8 / 2026-05-28`) this is a legacy defensive nudge. ~1 line removable.

Line 27 (SKILL.md):
> `ultrathink during synthesis — the value of this map is cross-dimensional reasoning (e.g., "high test coverage on the wrong layer," "architecture A but stack B implies tension X") that single-dimension analysis misses.`

Legitimate — this is prescriptive scope for the Recommendations section, not a model-behavior guard. Keep.

Lines 78–86 (SKILL.md) — inline restatement of spawn-protocol.md Medium-class budget:
> `**Weight class**: Medium (per spawn-protocol.md). The prompt MUST declare: file cap from the roster, max 25 tool calls, max 250-line output, 5-min wall-clock, stub-then-append write pattern.`

This exact data lives in `spawn-protocol.md`. If Medium-class budget changes in the protocol, this line silently drifts. ~3 lines removable (replace with "Weight class: Medium — spawn-protocol.md §Medium defines all caps").

`references/main.md` BUDGET/WRITE-AS-YOU-GO/HEARTBEAT/CONFIRMATION sections are inline copies of `agent-prompt-boilerplate.md` content. The `<!-- import: -->` comment claims they are dedup targets but they are not. ~14 lines of boilerplate in the agent prompt template are duplicated from `_shared/agent-prompt-boilerplate.md`. If boilerplate changes, `references/main.md` drifts silently.

**Estimated removable lines:** 18 (1 phase-order nudge + 3 spawn-budget restatement in SKILL.md + 14 boilerplate inline in references/main.md that could be replaced with a true import or explicit "see agent-prompt-boilerplate.md for canonical text" note).

**Content that belongs in a shared protocol:** Quality Scoring Rubric (1–5 scale, weighted formula) is defined only here. If another skill needs the same rubric, it re-invents. Could move to `_shared/quality-rubric.md`. Not blocking — codebase-map is currently the only consumer.

---

## D. Modernization

### Native primitive overlap

Per `platform-delta.md` (v2.1.154+ / 2026-05-28): native orchestration can fan 4 parallel subagents in script variables without touching Claude's context. The 4-agent fan-out in Phase 1 could use native Workflow dispatch.

**Claim: keep with optional native path** — rationale: `codebase-map` enforces a specific 4-dimension schema, shared inventory pre-build (Phase 0.1), PARTIAL/MISSING retry logic, and a structured merge. Native workflows provide raw parallelism but not the orchestration logic. Delegating entirely loses the dimension-schema contract and the Phase 2 gate. **Tradeoff:** adding a native workflow dispatch path (guarded by capability check, same as `codebase-audit`'s `workflow-dispatch.md`) would reduce latency and context pressure without losing the contract. Recommend adding `workflow-dispatch.md` reference as an opt-in path, not replacing the current path.

Per `platform-delta.md` (`disallowed-tools`, v2.1.152): dimension agents currently constrained by prompt instructions ("max 25 tool calls", "No web searches"). Could replace prompt-prose with `disallowed-tools: WebSearch` in spawn params. **Concrete win:** no prose needed for the web-search prohibition.

**Model/effort sanity:** `model: opus`, `effort: medium`. Opus orchestrator + sonnet workers matches the MEMORY.md constraint (`model: sonnet/haiku` skills crash at load from `[1m]` parents; use opus orchestrator + sonnet Agent workers). Workers explicitly set `model: sonnet` in Phase 1.2. **Correct.**

Per `platform-delta.md` (model IDs, 2026-05-28): current Opus ID is `claude-opus-4-8`, Sonnet is `claude-sonnet-4-6`. Frontmatter uses `model: opus` alias — verify alias resolution in Claude Code ≥2.1.154. If alias is unresolved, pin to `claude-opus-4-8`. **Inferred risk — did not verify alias table.**

---

## E. Correctness

- `compatibility: ">=2.1.71"` — Agent tool with `model:` param requires ≥2.1.71; no newer feature used that would require bumping. **Correct** unless `disallowed-tools` spawn-param path is added (requires v2.1.152).
- `subagent_type: general-purpose` — valid per current spawn-protocol.
- `run_in_background: false` — Phase 1.2 sets this explicitly. Correct for synchronous fan-out.
- Phase 0.1 bash: `find` excludes `node_modules`, `.git`, `dist`. Does not exclude `.cc-sessions` — inventory could include session temp files if they have matching extensions. Low-severity.
- Phase 0.1 bash: `for f in package.json pnpm-workspace.yaml ...` — no `deno.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`. Limits usefulness on non-JS repos. Known scope constraint, not a bug.
- Phase 2 MISSING gate: `MISSING_COUNT >= 2` aborts; `== 1` retries. Logic is correct but the retry is described in prose without a concrete retry mechanism (no loop, no fallback Agent call shown). Gap between spec and implementation guidance.
- **Subagents-cannot-spawn-subagents constraint** (`agent-routing.md`): skill is slash-invoked, orchestrator spawns 4 agents. Those agents are `general-purpose`, no Agent tool in their prompt. Constraint honored. Dynamic Workflows (platform-delta.md v2.1.154+) allow JS-orchestrated fan-out at the platform level, but that changes the dispatch mechanism, not the constraint for Blitz-level Agent calls. Constraint still valid for current architecture.

---

## F. Verdict

**`needs-tightening`**

Three highest-leverage edits:

1. **Replace inline spawn-budget restatement** (SKILL.md lines ~78–86) with "Weight class: Medium — all caps defined in [spawn-protocol.md](/_shared/spawn-protocol.md) §Medium." Eliminates drift vector.

2. **Add `workflow-dispatch.md` opt-in path** (matching `codebase-audit` pattern) to Phase 1 — native parallel dispatch for the 4 agents when workflows are available. Adds `compatibility: ">=2.1.154"` gate. Zero loss of contract; latency + context improvement.

3. **Convert `references/main.md` inline boilerplate to true dedup** — replace the BUDGET/WRITE-AS-YOU-GO/HEARTBEAT/CONFIRMATION inline copies with a canonical reference to `_shared/agent-prompt-boilerplate.md` and a note that `references/main.md` is the byte-stable spawn source only for dimension-specific content. Or mark the `<!-- import: -->` comment as `<!-- inline-copy: from agent-prompt-boilerplate.md — keep in sync -->` to make the intent explicit and auditable.
