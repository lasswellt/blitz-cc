# SYNTHESIS.md — Sequenced, leverage-ordered epic plan

**Target:** blitz-cc @ v2.2.1. **Source concept:** anthropic.com/engineering/harness-design-long-running-apps (2026-03-24).

Blitz already has the planner → generator → evaluator harness ([`blitz-loop-map.md`](blitz-loop-map.md)). This plan closes the **five deltas** ([`gap-fixes.md`](gap-fixes.md)), sequenced by leverage: cheapest pre-loop lift first, highest quality lift next, then the loop/contract/trigger refinements. Each epic is a follow-up sprint behind Blitz's own gates — whose upgraded design-critic will navigate the live result and score it.

---

## Sequencing rationale

| Order | Epic | Gap | Why here | Effort | Lift |
|---|---|---|---|---|---|
| **E1** | Criteria-as-steering | 5 | Pre-loop lift, near-zero effort, *shortens every later loop*. Do first so E2–E3 measure against a better baseline. | XS | High/effort |
| **E2** | Live-navigating evaluator | 1 | Highest quality lift (interaction bugs invisible to static shots). The headline. | M | Highest |
| **E3** | Iteration ceiling + refine-vs-pivot | 2 | Unlocks late creative leap. Depends on E2 (a longer loop is only worth it with a live-nav evaluator scoring each cycle). | M | High |
| **E4** | Sprint-contract negotiation | 3 | Bridges spec↔testable. Independent of E1–E3; sequenced after because lower leverage on UI specifically. | M | Med |
| **E5** | Capability-relative trigger | 4 | Stress-test-and-strip. Last because it tunes *when* E2 runs — needs E2 in place to gate. Reclaims budget. | S | Strips waste |

Dependency edges: **E1 → (E2 → E3 → E5)**; **E4** parallel. E5 last (it gates E2's trigger).

---

## E1 — Criteria-as-steering (Gap 5) · `skills/ui-build/SKILL.md`

Extract the 5-dimension definitions (`agents/design-critic.md:54–67`) to a shared snippet; cite it from both the agent and ui-build's Phase 3/4 generation prompt. Add the rubric-as-steering block + "museum quality" phrasing ([`loop-upgrade.md`](loop-upgrade.md) §1). Generator and evaluator now share one rubric source.

**Acceptance**
```sh
grep -iE "museum quality|generation rubric|graded on these 5 dimensions" skills/ui-build/SKILL.md
# shared snippet cited by both
grep -rlE "Creative Distinction|Aesthetic Fit" skills/ui-build/SKILL.md agents/design-critic.md | wc -l   # ≥2
```

---

## E2 — Live-navigating evaluator (Gap 1) · `agents/design-critic.md` + `skills/ui-build/SKILL.md`

Grant the Playwright navigation subset (no `browser_run_code_unsafe`/`browser_evaluate`); add the navigate-before-score section; preserve the static fallback with a `coverage_boundary` note; update the read-screenshots rule to "read the rendered app, not the source"; have ui-build Phase 5.4 pass a live dev-server URL. Full spec: [`design-critic-upgrade.md`](design-critic-upgrade.md).

**Acceptance**
```sh
grep -E "browser_navigate" agents/design-critic.md
grep -iE "navigate the (live )?page|broken[- ]wiring" agents/design-critic.md
grep -iE "static fallback|coverage_boundary" agents/design-critic.md
grep -iE "rendered app, not the source" agents/design-critic.md
grep -nE "dev[- ]server URL|live URL|--url" skills/ui-build/SKILL.md
! grep -E "browser_run_code_unsafe|browser_evaluate" agents/design-critic.md
```

---

## E3 — Iteration ceiling + refine-vs-pivot (Gap 2) · `skills/ui-build/SKILL.md`

Replace the flat 3-cap (high tier) with `ceiling = min(10, budget_remaining)`; add the refine-vs-pivot decision driving pivots through the 13-tone menu (`:115–117`); track tried tones; log pivots; escalate at the bound. Full spec: [`loop-upgrade.md`](loop-upgrade.md) §2.

**Acceptance**
```sh
grep -iE "MAX_DESIGN_ITERS|PIVOT_AFTER|refine.{0,8}pivot" skills/ui-build/SKILL.md
grep -iE "pivot to (a |an )?different (tone|aesthetic)" skills/ui-build/SKILL.md
! grep -E "Max 3 revisions per page" skills/ui-build/SKILL.md
```

---

## E4 — Sprint-contract negotiation (Gap 3) · `skills/sprint-dev/SKILL.md` + `skills/_shared/session-lifecycle.md`

Add a pre-wave contract step: generator proposes build + verification; evaluator (critic/design-critic) amends; converge (bounded N rounds, else escalate); negotiated criteria become `scope.acceptance` (co-owned). Scope the negotiation to the gap between high-level acceptance and testable behaviors — do not duplicate what `sprint-plan` already pins ([`gap-fixes.md`](gap-fixes.md) Gap 3). Register the contract artifact in the handoff table.

**Acceptance**
```sh
grep -iE "sprint contract|contract negotiation|propose.*verify|co-own" skills/sprint-dev/SKILL.md
grep -iE "negotiated contract|sprint-contract" skills/_shared/session-lifecycle.md
```

---

## E5 — Capability-relative trigger (Gap 4) · `skills/ui-build/SKILL.md`

Keep `high` always-evaluated; make `standard` conditional on edge-of-capability signals (novel aesthetic / interaction complexity / low generator confidence / deterministic-lane hits); annotate as a per-model-release living decision; cross-link the v1.16.0/cohesion code-detector precedent. Full spec: [`loop-upgrade.md`](loop-upgrade.md) §3.

**Acceptance**
```sh
grep -iE "edge[- ]of[- ]capability|novel aesthetic|unnecessary overhead|capability-relative" skills/ui-build/SKILL.md
grep -iE "v1.16.0|cohesion-2026-05|det-20" skills/ui-build/SKILL.md
```

---

## Cross-cutting requirements

1. **Reuse, don't rebuild.** Every epic extends an existing artifact — no new agents ([`blitz-loop-map.md`](blitz-loop-map.md) §1). E1/E3/E5 → `ui-build/SKILL.md`; E2 → `design-critic.md` + ui-build; E4 → `sprint-dev` + `session-lifecycle.md`.
2. **5-dim ↔ 4-criteria reconciliation** holds (Creative Distinction≈Originality, Visual Polish≈Craft, UX≈Functionality, Aesthetic Fit+Prompt Adherence≈Design quality). Keep equal numeric scoring; make the "grade hardest where the model is weakest" emphasis explicit and symmetric ([`blitz-loop-map.md`](blitz-loop-map.md) §3).
3. **Compose with the design pillar.** Deterministic `npx impeccable detect` (Layer 0/1/2, `check-registry.json pillar==design`) runs first and feeds the live-nav critic mechanical findings; the critic spends its navigation budget on what only live interaction reveals ([`design-critic-upgrade.md`](design-critic-upgrade.md) §6).
4. **Budget honesty.** Article: full harness 6 hr / $200; DAW 3 hr 50 / $124.70 ([`harness-model.md`](harness-model.md) §8). Bound E3's ceiling and E2's live-nav cost via `agent-orchestration.md`; reserve the expensive path for `high`; E5 reclaims `standard`-tier waste. Surface the tradeoff; never silently incur it on `standard`.
5. **Stress-test framing.** The whole integration is the article's closing lesson applied to Blitz: strip stale scaffolding (E5), add capability the model now enables (E2 live nav, E3 longer creative loop), steer earlier (E1). Re-examine each design release against the current model — exactly as v1.16.0/cohesion did for code detectors.

## Corrections folded in (vs. the brief)
- **Version:** target is **v2.2.1**, not v2.1.0 (`plugin.json:3`; v2.1.0 is two releases back).
- **Gap 4 precedent:** the detector re-justification is **v1.16.0 A5 + cohesion-2026-05 + check-registry det-20**, not v2.0.0 (which is the review/audit consolidation, `CHANGELOG.md:76`).
- **Gap 5 surface:** ui-build's 5.4 / iteration / `design_quality` logic lives in `SKILL.md`, not `references/main.md`; the 5 dims reach the critic by name only at `SKILL.md:326`.

## Definition of done (this pass)
- [x] Article harness model documented + mapped onto Blitz's loop, with credit + 5-dim↔4-criteria reconciliation — [`harness-model.md`](harness-model.md), [`blitz-loop-map.md`](blitz-loop-map.md).
- [x] 5 gaps confirmed against live v2.2.1, each extending an existing artifact — [`gap-fixes.md`](gap-fixes.md).
- [x] Live-navigating design-critic spec (Playwright nav before scoring, static fallback) — [`design-critic-upgrade.md`](design-critic-upgrade.md).
- [x] ui-build loop upgrade (capability-relative trigger, raised+bounded ceiling, refine-vs-pivot, criteria-as-steering) — [`loop-upgrade.md`](loop-upgrade.md).
- [x] Leverage-ordered epic plan, criteria-steering + live-nav first, suite runs on itself — this file.
- Implementation: follow-up sprint behind Blitz's gates.
