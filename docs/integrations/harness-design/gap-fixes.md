# gap-fixes.md — The five gaps, confirmed against v2.2.1 and fix-designed

Each gap: **article concept → exact Blitz surface (file:line) → fix design → artifact extended → quality lift → cost impact.** Every gap extends an existing artifact. No new agents.

Verified against the live tree at **v2.2.1** (`.claude-plugin/plugin.json:3`).

---

## Gap 1 (HIGH) — Evaluator scores static screenshots, not a live navigated page

**Article.** The evaluator had the Playwright MCP and *"would navigate the page on its own, screenshotting and carefully studying the implementation before producing its assessment."* Each cycle took real wall-clock because it was *using* the product. This is where the hardest bugs lived: *"my entities appeared on screen but nothing responded to input."* See [`harness-model.md`](harness-model.md) §3.

**Blitz surface (confirmed).**
- `agents/design-critic.md:4` — *"Reads screenshots of a rendered page and scores."*
- `agents/design-critic.md:27–28` — *"You read screenshots of a rendered page and score the visual output across 5 dimensions."*
- `agents/design-critic.md:44` — input is `` `/tmp/ui-build-screenshots/*.png` `` (pre-captured, passed in).
- `agents/design-critic.md:16` — `tools: Read, Grep, Glob, Bash`. **No Playwright MCP.** Capability rationale (`:17–19`) deliberately keeps it read-only / no MCP egress.
- `agents/design-critic.md:108` — *"Read screenshots, not source... the source is irrelevant to your scoring."*
- ui-build captures the screenshots then spawns the critic on the images: `skills/ui-build/SKILL.md:305` (Phase 5.4), `:309–311` (capture at 375/768/1440), `:320–328` (spawn critic on images).

What this forecloses: hover/focus/pressed states, scroll behavior, modal/transition correctness, real responsive behavior (not a compressed shot), and the broken-wiring bug class the article's evaluator caught.

**Fix design.** Grant `design-critic` the Playwright MCP and add a navigation step *before* scoring: click primary actions, exercise interactive states, resize to test breakpoints, study transitions, then screenshot and score. Static-screenshot path remains the **fallback** when Playwright is unavailable (ui-build already warns on that at `:307`). Full spec in [`design-critic-upgrade.md`](design-critic-upgrade.md).

Reconcile with the read-screenshots-not-source rule (`:108`): **the rule stands.** Navigating the *rendered app* is not reading source — the critic still never opens `.vue`/CSS files. The input surface expands from a static image to the live DOM; the prohibition (judge output, not implementation) is unchanged.

**Artifact extended.** `agents/design-critic.md` (tools grant + §1 Inputs + a new navigation section); `skills/ui-build/SKILL.md` Phase 5.4 (hand the critic a live URL, not just image paths).

**Quality lift.** Highest of the five. Moves the evaluator from "judging a photo" to "using the product" — the only way to catch interaction-dependent failure, which is the class the article documents as hardest-caught. Composes with the deterministic design-pillar detector (`check-registry.json` `pillar == design`): mechanical tells caught by `npx impeccable detect` feed the critic so it spends its live-nav budget only on what navigation reveals.

**Cost impact.** Each design-critic cycle now costs real wall-clock (browser session + navigation turns) instead of one vision pass over 3 PNGs. `maxTurns` (`:20`, currently 15) likely needs raising for the navigation budget. Reserve for `design_quality: high`; `standard` runs once and should default to the static path unless the capability-relative trigger (Gap 4) escalates it. Security: the Bash/no-egress posture (`:17–19`, `threat-model.md §5`) must be re-stated for the MCP grant — Playwright is a controlled local-browser capability, not arbitrary network egress; document the boundary.

---

## Gap 2 (HIGH) — Iteration ceiling of 3, refine-only, no strategic pivot

**Article.** *"5 to 15 iterations per generation,"* with a per-iteration *"strategic decision... refine the current direction if scores were trending well, or pivot to an entirely different aesthetic if the approach wasn't working."* The Dutch-museum design **pivoted on iteration 10** into a 3D spatial experience — a creative leap unseen from single-pass generation. See [`harness-model.md`](harness-model.md) §5.

**Blitz surface (confirmed).**
- `skills/ui-build/SKILL.md:318` — `high` tier runs *"with up to 3 iteration cycles."*
- `skills/ui-build/SKILL.md:333` — *"Max 3 revisions per page; then escalate to user choice."*
- `skills/ui-build/SKILL.md:330–332` — refine-only: *"feed critique back to Phase 4 IMPLEMENT for one revision."* No pivot path.
- The pivot *space already exists*: the 13-tone vocabulary at `skills/ui-build/SKILL.md:115–117` (canonical home `docs/integrations/impeccable/references-regrounded.md:113–117`).

Low cap + refine-only forecloses exactly the late-emerging creative leaps the article documents (a pivot at iteration 10 is impossible when the loop ends at 3).

**Fix design.**
1. **Raise the ceiling for `design_quality: high`** toward the article's 5–15 range, gated by a **budget/turn bound** (per `token-budget.md`), not a flat 3. Keep escalate-to-user as the exit, but at the bound, not at 3.
2. **Add the refine-vs-pivot decision** after each evaluation: scores trending up → refine current direction; scores flat/stuck after N iters → **pivot** to a different tone from the 13-tone menu (the pivot space). Make pivot explicit in the loop, not "one more revision."
3. `standard`/`skip` tiers unchanged (cost discipline). Full spec in [`loop-upgrade.md`](loop-upgrade.md).

**Artifact extended.** `skills/ui-build/SKILL.md` Phase 5.4.2 (`:313–335`).

**Quality lift.** High for customer-facing pages — unlocks the late creative leap that is the article's most striking result. The pivot is what separates "polished version of the first idea" from "a genuinely better different idea."

**Cost impact.** Direct multiplier on the most expensive tier. Article's full harness was 6 hr / $200 at ~15 iterations. The bound must come from `token-budget.md` (`:201–212` advisory per-skill caps; `:36` ultracode sequential-workflow budgeting; 1h cache amortization `:61` makes longer loops cheaper per-iteration if the prefix is cached). High tier justifies it; `standard` must never silently incur it.

---

## Gap 3 (MEDIUM) — No generator↔evaluator sprint-contract negotiation

**Article.** Before each sprint the generator and evaluator *"negotiated a sprint contract: agreeing on what 'done' looked like... before any code was written."* The generator proposed; the evaluator reviewed; they iterated to agreement (*"Sprint 3 alone had 27 criteria"*). The contract bridges a deliberately high-level spec to testable, evaluator-co-owned criteria. See [`harness-model.md`](harness-model.md) §4.

**Blitz surface (confirmed).** DoD is **planner-assigned, one-directional**, not negotiated:
- `skills/sprint-dev/SKILL.md:271` — *"Read story — Parse frontmatter... Note `verify` and `done` fields."*
- `skills/sprint-dev/SKILL.md:273` — *"Run the story's `verify` commands if defined."*
- `skills/sprint-dev/SKILL.md:280` — *"Check done criteria — Verify the story's `done` field is satisfied."*
- Stories come from sprint-plan and are consumed read-only: `skills/_shared/state-handoff.md:57`.
- Acceptance enforced downstream by the critic from planner-authored `acceptance_checks:` (`agents/critic.md:106–161`).
- No contract-negotiation step exists at sprint start (confirmed); inter-agent comms are status prefixes only (`sprint-dev/SKILL.md:288–314`).

**Fix design.** Add a **contract-negotiation step** at sprint start: generator (`sprint-dev`) proposes what it will build + how the evaluator will verify it (the testable behaviors); evaluator (`critic` / `design-critic`) reviews and amends; converge before code. The negotiated criteria **become** the sprint's `scope.acceptance` — co-owned, not handed down. Use Blitz's file-based handoff (`state-handoff.md`; the article used files too). Most valuable where the spec is intentionally high-level.

**Note on whether Blitz's planner under-specifies (article's deliberate choice) or over-specifies.** The article's planner stays *"focused on product context and high level technical design rather than detailed technical implementation."* Blitz's `sprint-plan` emits structured stories with `verify`/`done`/`acceptance_criteria` fields (`story-frontmatter.md`). If those fields already pin testable detail, the planner is *more* specified than the article's — in which case the negotiation is lighter (the evaluator amends/co-signs existing criteria rather than co-authoring from scratch). **Recommendation:** scope the negotiation to the gap between high-level acceptance and testable behaviors; do not duplicate what `sprint-plan` already pins. This keeps the fix additive and avoids re-litigating planner output.

**Artifact extended.** `skills/sprint-dev/SKILL.md` (new pre-wave Phase ~0.5 contract step); `skills/_shared/state-handoff.md` (new negotiated-contract artifact in the handoff table).

**Quality lift.** Medium — bridges the user-story↔testable-implementation gap, gives the evaluator co-ownership of "done" (catches mis-scoped stories before code, not after review). Highest value where stories are deliberately high-level.

**Cost impact.** One short negotiation round per sprint (proposal + review + converge), file-based — cheap relative to a sprint. Bounded by an iteration cap (converge or escalate to user after N rounds) to avoid negotiation loops.

---

## Gap 4 (MEDIUM) — Evaluator runs on a fixed flag, not a capability-relative decision

**Article.** The evaluator is *"not a fixed yes-or-no decision. It is worth the cost when the task sits beyond what the current model does reliably solo."* With Opus 4.6 the boundary moved outward and the evaluator became *"unnecessary overhead"* for tasks now within solo capability. Closing principle: harness components encode assumptions about what the model can't do alone — stress-test them, they go stale as models improve. See [`harness-model.md`](harness-model.md) §7.

**Blitz surface (confirmed).** The critic runs on a fixed page-category flag, not a capability-relative signal:
- `skills/ui-build/SKILL.md:315–318` — `design_quality:` ∈ `skip` (admin) / `standard` (run once) / `high` (up to 3 cycles). Read from story frontmatter; page-category-based.
- `skills/ui-build/SKILL.md:335` — `standard` reports scores, does not auto-iterate.

**Correction to the brief.** The brief cites "the v2.0.0 work that already re-justified critic detectors against model honesty gains." That is inaccurate: v2.0.0 (`CHANGELOG.md:76`) is the review/audit consolidation. The detector re-justification against Opus-4.8 honesty/self-correction is **v1.16.0 + the cohesion audit**, specifically:
- `docs/validation/v1.16.0/agents/critic.md:20` — *"A5 — Critic detector re-justification (19 vs 20 reconciliation) — PASS"*, per-detector KEEP-vs-THIN table at `:25–36` (e.g. `as any`/`@ts-ignore` KEEP for adversarial cross-check; stub detectors marked THIN because *"Opus 4.8 self-flags stubs on review"*).
- `docs/audits/cohesion-2026-05/agents/critic.md:81` — *"E. Detector-by-Detector Re-justification (4.8 Honesty Lens)."*
- `skills/_shared/check-registry.json:482` (det-20) — *"Honesty-sensitive: down-weighted under Opus 4.8."*

So the precedent the brief wants **exists and is exactly the right model** — it is just v1.16.0/cohesion, not v2.0.0. Connect Gap 4 to *that* work: Blitz already applies the article's stress-test-and-strip discipline to its **code** detectors; Gap 4 extends the same discipline to its **design** evaluator trigger.

**Fix design.** Reframe the evaluator trigger as **capability-relative**:
- Keep `high` **always-evaluated** (customer-facing stakes justify it regardless of model capability).
- Make `standard`'s evaluator **conditional** on edge-of-capability signals: novel aesthetic (a tone the project hasn't shipped), high interaction complexity, low generator self-confidence (the generator self-reports), or deterministic-lane findings present. When none fire, `standard` ships solo (the evaluator is overhead).
- Document the trigger as a **living decision re-examined each model release**, cross-linked to the v1.16.0/cohesion detector re-justification precedent.

**Artifact extended.** `skills/ui-build/SKILL.md:315–335` (`design_quality` trigger logic); cross-reference `docs/validation/.../A5` and `check-registry.json:482` as the precedent pattern.

**Quality lift.** Indirect — does not raise ceiling, *strips stale scaffolding*. Reclaims tokens/wall-clock the evaluator no longer earns at the `standard` tier under Opus 4.8, redirecting budget to where it does earn (Gap 1's live nav on high-stakes pages).

**Cost impact.** Net **savings** at the `standard` tier (skip evaluator when the page is within solo capability). The risk it manages is over-paying for a check the model no longer needs — exactly the article's "unnecessary overhead."

---

## Gap 5 (LOW effort / HIGH leverage) — Criteria steer the evaluator, not the generator

**Article.** The four criteria were given to **both** generator and evaluator. First-iteration output beat a no-prompt baseline — *"the criteria... themselves steered the model away from generic defaults before any evaluator feedback."* Phrasing ("museum quality") produced visual convergence. See [`harness-model.md`](harness-model.md) §6.

**Blitz surface (confirmed).**
- Evaluator has the 5 scored dims (`agents/design-critic.md:54–67`).
- Generator (`ui-build`) steers via tone commitment (`SKILL.md:115–124`), banned fonts (`:121`, `:191`, `:206–207`), DESIGN.md heuristics (`:128`), Implementation Gate (`:182–221`), anti-pattern list (`:376–393`).
- But the generator does **not** carry the *same scored rubric the evaluator grades against*. At the spawn site the 5 dims are passed **to the critic by name only**: `skills/ui-build/SKILL.md:326` — *"Score 5 dimensions 0–10: Prompt Adherence, Aesthetic Fit, Visual Polish, UX, Creative Distinction. Pass threshold ≥7 on all five."* The generation prompt has **no block mirroring the rubric** — generation vocabulary (tone/tokens/gates) and evaluator vocabulary (5 scored dims) are disjoint. Creative Distinction in particular has generation-side coverage only as banned-font/color/avoid-generic rules, not as a scored target the generator is told it will be measured on.

**Fix design.** Give the generator the **same criteria the evaluator scores against**, as forward steering in the Phase 3/4 generation prompt: state the 5 dimensions and what scores well on each (especially Creative Distinction / Aesthetic Fit — the two the model is weakest on), with steering language. Test whether specific phrasing (the article's "museum quality") produces useful convergence for Blitz's 13-tone vocabulary. Full spec in [`loop-upgrade.md`](loop-upgrade.md).

**Artifact extended.** `skills/ui-build/SKILL.md` Phase 3/4 generation prompt (add a rubric-as-steering block; reuse the exact dimension definitions from `design-critic.md:54–67` so generator and evaluator share one source of truth).

**Quality lift.** High leverage for near-zero effort. The article got measurable first-iteration lift from this **before any loop runs** — every iteration starts from a better baseline, which also shortens the Gap 2 loop (fewer iterations to reach PASS). Cheapest gap, sequenced first.

**Cost impact.** Negligible — a few hundred tokens of additional generation-prompt context, cached on the static prefix (`token-budget.md:46–50`). Likely **net negative cost** by reducing iterations needed downstream.

---

## Summary table

| Gap | Sev | Surface (file:line) | Artifact extended | Lift | Cost |
|---|---|---|---|---|---|
| 1 Live nav | HIGH | `design-critic.md:16,44,108`; `ui-build:305–328` | design-critic.md, ui-build 5.4 | Highest (interaction bugs) | +wall-clock; reserve for `high` |
| 2 Iterate+pivot | HIGH | `ui-build:318,330–333` | ui-build 5.4.2 | High (late creative leap) | Multiplier; bound via token-budget |
| 3 Contract | MED | `sprint-dev:271–280`; `state-handoff:57` | sprint-dev, state-handoff | Med (scope before code) | One round/sprint; cheap |
| 4 Capability trigger | MED | `ui-build:315–335` | ui-build trigger | Strips stale scaffolding | Net savings |
| 5 Criteria-steer | LOW eff | `ui-build:326` | ui-build gen prompt | High/effort | Negligible / net negative |
