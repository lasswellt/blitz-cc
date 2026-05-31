# harness-model.md — The article's planner/generator/evaluator harness

**Source:** "Harness design for long-running application development" — anthropic.com/engineering/harness-design-long-running-apps (2026-03-24).
**Purpose:** Primary-source extraction of the harness model the rest of this integration maps Blitz onto. Quotes are verbatim from the article.

---

## 1. The three-agent model

The article describes a GAN-inspired harness — a **generator** that produces work and a skeptical **evaluator** that grades it — fronted by a **planner** that expands a short prompt into an ambitious spec.

| Agent | Role (verbatim where quoted) |
|---|---|
| **Planner** | Takes a brief prompt and expands it into a full product spec, staying *"focused on product context and high level technical design rather than detailed technical implementation."* The under-specification is deliberate — it avoids cascading spec errors and leaves implementation latitude to the generator. |
| **Generator** | *"instructed to work in sprints, picking up one feature at a time from the spec."* Stack in the article: React, Vite, FastAPI, SQLite/PostgreSQL. |
| **Evaluator** | Given the Playwright MCP to *"click through the running application the way a user would, testing UI features, API endpoints, and database states,"* then grades against defined criteria and writes a detailed critique. |

The central claim: **subjective quality becomes gradable once you write explicit criteria, and a separate skeptical evaluator beats self-evaluation** (self-evaluation skews positive).

---

## 2. The four design grading criteria + weighting rationale

The article grades design output on four criteria:

| Criterion | Definition (verbatim) |
|---|---|
| **Design quality** | *"Does the design feel like a coherent whole rather than a collection of parts?"* |
| **Originality** | *"Is there evidence of custom decisions, or is this template layouts, library defaults, and AI-generated patterns?"* |
| **Craft** | *"Technical execution: typography hierarchy, spacing consistency, color harmony, contrast ratios."* |
| **Functionality** | *"Usability independent of aesthetics."* |

**Weighting rationale:** design + originality are weighted over craft + functionality, *because the model is already competent at the latter two*. Verbatim: *"Claude already scored well on craft and functionality by default... But on design and originality, Claude often produced outputs that were bland at best."* The harness spends its grading budget where the model is weakest, not where it is already strong.

---

## 3. Live-navigation evaluator (the headline technique)

The evaluator was handed *"the Playwright MCP, which let it interact with the live page directly before scoring each criterion and writing a detailed critique."* Rather than scoring a static screenshot, *"the evaluator would navigate the page on its own, screenshotting and carefully studying the implementation before producing its assessment."* Because it actively navigated, **each cycle took real wall-clock time** — the cost is paid in exchange for catching interaction-dependent failure.

**Bugs this caught that a static screenshot cannot** (from the retro game maker):
- *"The actual game was broken. My entities appeared on screen but nothing responded to input."* — the broken-wiring class: UI renders, nothing responds.
- Route matching: *"FastAPI matches 'reorder' as a frame_id integer and returns 422."*
- Missing handler logic: the delete-key handler *"requires both `selection` and `selectedEntityId` to be set, but clicking an entity only sets `selectedEntityId`."*

These live in interaction state (click, keypress, route, API/DB round-trip) — invisible in a rendered photo. The technique moves the evaluator from *judging a photo* to *using the product*.

---

## 4. Sprint-contract negotiation

Before each sprint, *"the generator and evaluator negotiated a sprint contract: agreeing on what 'done' looked like for that chunk of work before any code was written."* The generator proposed implementation details + success criteria; the evaluator reviewed and amended; they iterated until agreement. The contract bridges the deliberately high-level spec to testable, evaluator-co-owned criteria. Scale: *"Sprint 3 alone had 27 criteria covering the level editor."*

The negotiation is the mechanism that connects an intentionally under-specified planner output (§1) to verifiable acceptance — without the planner having to pre-specify implementation detail it would only get wrong.

---

## 5. The 5–15 iteration loop + refine-vs-pivot

The frontend design loop ran *"5 to 15 iterations per generation."* After each evaluation the generator made *"a strategic decision after each evaluation: refine the current direction if scores were trending well, or pivot to an entirely different aesthetic if the approach wasn't working."*

**Pivot is not refinement.** The Dutch-museum example: by iteration 9 the design was *"clean, dark-themed"* and polished. *"Then, on the tenth cycle, it scrapped the approach entirely and reimagined the site as a spatial experience: a 3D room with a checkered floor rendered in CSS perspective, artwork hung on the walls in free-form positions, and doorway-based navigation between gallery rooms."* This late creative leap — the kind not seen from single-pass generation — only happens because (a) the loop runs long enough to reach iteration 10, and (b) a pivot path exists at all. A 3-iteration refine-only cap forecloses both.

---

## 6. Criteria as steering (cheapest lift, pre-loop)

The four criteria were given to **both** generator and evaluator in their prompts. The finding: *"Even on the first iteration, outputs were noticeably better than a baseline with no prompting at all, suggesting the criteria and associated language themselves steered the model away from generic defaults before any evaluator feedback led to further refinement."*

Phrasing mattered: *"Including phrases like 'the best designs are museum quality' pushed designs toward a particular visual convergence, suggesting that the prompting associated with the criteria directly shaped the character of the output."*

The criteria are not only a grading rubric — handed to the generator they are a **generation rubric** that lifts output before any evaluator cycle runs. This is the lowest-effort component of the whole harness.

---

## 7. The evaluator as a dynamic cost (stress-test-and-strip)

The evaluator is *"not a fixed yes-or-no decision. It is worth the cost when the task sits beyond what the current model does reliably solo."* As models improve, the boundary moves: with Opus 4.6, *"the boundary moved outward. Tasks that used to need the evaluator's check to be implemented coherently were now often within what the generator handled well on its own, and for tasks within that boundary, the evaluator became unnecessary overhead."*

Closing principle (the lens for the entire Blitz integration): *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."*

---

## 8. Cost & time figures (budget honesty)

| Run | Model | Time | Cost |
|---|---|---|---|
| Retro game maker — solo (no harness) | Opus 4.5 | 20 min | $9 |
| Retro game maker — full harness | Opus 4.5 | 6 hr | $200 |
| DAW — simplified harness | Opus 4.6 | 3 hr 50 min | $124.70 |

The harness is ~20× the wall-clock and ~22× the cost of a solo run on the same model. The lift justified it **for high-stakes output**; the §7 principle is what decides when it does not. Any Blitz adoption of the longer loop / live navigation must bound this cost (see [`loop-upgrade.md`](loop-upgrade.md) and [`gap-fixes.md`](gap-fixes.md) Gap 2/Gap 4) and reserve the expensive path for the high-stakes tier.

---

## 9. The model in one line

**Planner** (expand prompt → ambitious, deliberately-under-specified spec) → **Generator** (build one feature/sprint at a time, steered by the same criteria the evaluator will grade) → **Evaluator** (negotiate the contract first; then *navigate the live page*, grade the weighted criteria, write a critique) → **Generator decides refine-or-pivot** over 5–15 iterations — with the evaluator switched on only when the task sits beyond solo capability, a boundary that is re-examined every model release.

Next: [`blitz-loop-map.md`](blitz-loop-map.md) maps Blitz's existing loop onto this model.
