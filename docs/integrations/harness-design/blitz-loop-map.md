# blitz-loop-map.md — Blitz's existing loop mapped onto the article's harness

**Target:** blitz-cc @ **v2.2.1** (the brief said v2.1.0; current `.claude-plugin/plugin.json:3` is `"version": "2.2.1"` — v2.1.0 is two releases back at `CHANGELOG.md:58`. The design pillar the live-nav evaluator composes with landed in v2.1.0).

**Thesis:** Blitz already has the planner/generator/evaluator architecture. This is not "add a harness." It is closing five specific deltas. Credit first, then the gaps.

---

## 1. The three-agent map

| Article agent | Blitz equivalent | Alignment |
|---|---|---|
| **Planner** (expand prompt → spec, high-level, deliberately under-specified) | `sprint-plan` (selects unblocked epics, spawns research agents, emits story files per `sprint-contracts.md`) + the planner persona | **Strong.** Blitz expands roadmap epics → stories. See Gap 3 for whether `sprint-plan` under-specifies like the article's planner or over-specifies. |
| **Generator** (build one feature/sprint at a time) | `sprint-dev` (waves of backend/frontend/test agents in worktrees) and `ui-build` (5-phase Discover→Analyze→Design→Implement→Refine) for UI | **Strong.** `ui-build` is one-page-at-a-time; `sprint-dev` is story-at-a-time within dependency waves. |
| **Evaluator — design** (live-nav, 4 weighted criteria) | `agents/design-critic.md` (5 dims, vision, sonnet) | **Strong rubric, but static-screenshot and capped at 3 iters.** → Gap 1, Gap 2. |
| **Evaluator — code/QA** | `agents/critic.md` (adversarial, read-only, must emit LGTM) + `/blitz:audit` (10-agent Multi-Review) + `/blitz:review` (deterministic + semantic lanes) | **Strong.** Multi-Review aggregation already present; critic gates PASS (sprint-review Inv 7). |

Blitz's review/audit consolidation (`CHANGELOG.md:76`, v2.0.0, sprints 18–20) produced exactly the planner → generator → evaluator loop the article describes — independently. The credit is real and load-bearing: **the architecture exists; the gaps are deltas inside it.**

---

## 2. Independent convergence — Creative Distinction ≈ Originality

The article weights **Originality** highest because the model is weakest there. Blitz's `design-critic` independently arrived at the same framing: `agents/design-critic.md:69` — *"The single hardest pass-bar in autonomous UI generation is dimension 2.5 [Creative Distinction]. Score it ruthlessly."* And `:110` — *"A 'competent but generic' output should score 5–6 on Creative Distinction, not 8. If it could come from any AI tool circa 2025, score it accordingly."*

That is the article's Originality criterion (*"template layouts, library defaults, and AI-generated patterns"*) in Blitz's own words, written before this integration. Blitz does not need to be taught the insight — it needs the insight to **steer the generator too** (Gap 5) and to be graded against a **live page** (Gap 1).

---

## 3. The 5-dim ↔ 4-criteria reconciliation

Blitz's `design-critic` scores 5 dimensions (`agents/design-critic.md:54–67`). The article grades 4. They reconcile cleanly:

| Blitz dimension (`design-critic.md`) | Article criterion | Notes |
|---|---|---|
| **2.5 Creative Distinction** (`:66`) | **Originality** (the weighted one) | Direct match. Both are "does this look generic / template / AI-default." Blitz already treats it as the hardest bar (`:69`). |
| **2.3 Visual Polish** (`:60`) | **Craft** | Both = spacing rhythm, alignment, type hierarchy, color cohesion, contrast. Direct match. |
| **2.4 UX** (`:63`) | **Functionality** | Both = usability independent of aesthetics: affordances, primary-action clarity, empty/loading/error states. |
| **2.2 Aesthetic Fit** (`:57`) + **2.1 Prompt Adherence** (`:54`) | **Design quality** ("coherent whole, not a collection of parts") | Two Blitz dims fold into one article criterion: Aesthetic Fit (embodies the chosen tone) + Prompt Adherence (delivers the asked-for genre) together = "coherent intentional whole." |

**Weighting check.** The article weights design + originality over craft + functionality. Blitz does **not** currently weight dimensions — `design-critic` uses equal 0–10 with a flat threshold (`:100` PASS = all five ≥7). Its *prose* over-weights 2.5 (score it "ruthlessly," `:69`/`:110`) but its *scoring math* does not. **Reconciliation recommendation:** keep equal numeric scoring (it is simpler and the flat ≥7 gate is a strong floor) but make the prose emphasis explicit and symmetric — flag both Creative Distinction (≈Originality) and Aesthetic Fit (the design-quality "coherent whole" half) as the dimensions where the model is weakest and the grader should be hardest. This matches the article's intent (grade hardest where the model is weakest) without adding a fragile weighting scheme. See [`gap-fixes.md`](gap-fixes.md) Cohesion note 2.

---

## 4. Where Blitz already exceeds the article

- **Multi-Review aggregation.** `/blitz:audit` spawns 10 parallel agents (2 independent same-scope passes per pillar) — the article's evaluator is single. Blitz's code/QA evaluator is more redundant than the article's.
- **Deterministic lane first.** The `design` pillar (`check-registry.json`, `pillar == design`, 47 rows per registry header) runs a key-free `npx impeccable detect` deterministic pass (gradient-text, banned fonts, identical card grids, raw token literals) **before** the semantic critic. The article's evaluator has no equivalent zero-FP mechanical pre-filter. Blitz's design-critic can therefore focus on what only vision/navigation reveals — which is exactly what Gap 1 (live nav) amplifies.
- **Gate integration.** sprint-review Phase 3.6 Invariant 7 makes the critic's LGTM a hard PASS gate; the article's evaluator advises, it does not gate a release pipeline.

---

## 5. The five gaps as deltas (not architecture)

Each gap is a specific thing the article's harness does that Blitz's does not — verified against the live v2.2.1 tree in [`gap-fixes.md`](gap-fixes.md):

1. **(HIGH)** Evaluator scores static screenshots, not a live navigated page. `design-critic.md:44` static input; no Playwright in `tools:` (`:16`).
2. **(HIGH)** Iteration ceiling of 3, refine-only, no pivot. `ui-build/SKILL.md:318`, `:333`, `:330–332`.
3. **(MED)** No generator↔evaluator sprint-contract negotiation; DoD is planner-assigned one-directionally. `sprint-dev/SKILL.md:271–280`.
4. **(MED)** Evaluator runs on a fixed `design_quality` flag, not a capability-relative decision. `ui-build/SKILL.md:315–318`.
5. **(LOW effort / HIGH leverage)** Criteria steer the evaluator but not the generator. `ui-build/SKILL.md:326` (criteria passed to critic by name only; no generation-side rubric).

The architecture stays. These five are the work.
