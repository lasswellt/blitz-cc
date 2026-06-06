# loop-upgrade.md — ui-build loop upgrade (Gaps 2, 4, 5)

**Extends:** `skills/ui-build/SKILL.md` (Phase 3/4 generation prompt + Phase 5.4 loop).
**Concepts:** [`harness-model.md`](harness-model.md) §5, §6, §7 · **Gaps:** [`gap-fixes.md`](gap-fixes.md) Gap 2, Gap 4, Gap 5.

Three changes to the generate→evaluate loop, ordered by leverage: criteria-as-steering (Gap 5, pre-loop), raised+bounded iteration ceiling with refine-vs-pivot (Gap 2), and a capability-relative evaluator trigger (Gap 4).

---

## 1. Criteria-as-steering (Gap 5) — the generation prompt carries the evaluator's rubric

**Today.** The 5 dimensions reach the critic by name only at the spawn site (`ui-build/SKILL.md:326`); the generation prompt steers via tone/tokens/gates (`:115–124`, `:182–221`, `:376–393`) but never states the scored rubric the output will be measured on.

**Change.** Add a **rubric-as-steering block** to the Phase 3/4 generation prompt, reusing the *exact* dimension definitions from `agents/design-critic.md:54–67` so generator and evaluator share one source of truth. Proposed block:

```md
### Generation rubric — you will be graded on these 5 dimensions (0–10, pass ≥7 each)
The best designs are museum quality. Build to that bar from the first pass.

- Prompt Adherence — deliver the genre asked for (a landing page looks like a landing page).
- Aesthetic Fit — fully embody the ONE committed tone; no tonal drift.
- Visual Polish — spacing rhythm, alignment, type scale, color cohesion, contrast.
- UX — clear primary action, real empty/loading/error states, genuinely usable at 375px.
- Creative Distinction — a point of view, not generic AI output. THIS IS THE HARDEST BAR.
  If it could come from any AI tool circa 2025, it fails. Avoid: banned fonts, purple-on-white
  gradients, all-rounded corners, all-centered layouts, dashboard sameness.
```

- Source the dimension text from one shared location (extract `design-critic.md:54–67` to a snippet both the agent and ui-build cite) so the rubric cannot drift between generator and evaluator.
- The "museum quality" phrasing is the article's tested convergence lever (§6) — keep it; A/B against Blitz's 13-tone vocabulary to confirm it helps rather than homogenizes (the article warns convergence is a real effect; for a *toy-like* or *lo-fi/zine* tone "museum quality" may pull the wrong way — consider tone-conditional phrasing).
- Emphasize the two dimensions the model is weakest on (Creative Distinction ≈ Originality, Aesthetic Fit ⊂ Design quality), per [`blitz-loop-map.md`](blitz-loop-map.md) §3.

**Why first:** measurable first-iteration lift before any evaluator cycle, and it shortens the Gap 2 loop (fewer iterations to PASS). Near-zero cost (cached prefix, `agent-orchestration.md:46–50`).

---

## 2. Raised + bounded iteration ceiling with refine-vs-pivot (Gap 2)

**Today.** `high` tier caps at *"up to 3 iteration cycles"* (`:318`), *"Max 3 revisions per page; then escalate"* (`:333`), refine-only — *"feed critique back... for one revision"* (`:330–332`).

**Change — ceiling.** For `design_quality: high`, replace the flat 3 with a **budget/turn-bounded ceiling toward the article's 5–15 range**:

```
ceiling = min(MAX_DESIGN_ITERS_HIGH, budget_remaining_iters)
  MAX_DESIGN_ITERS_HIGH default 10 (article ran 5–15; 10 is a cost-aware midpoint)
  budget_remaining_iters derived from agent-orchestration.md (per-skill advisory cap :201–212,
    1h-cache amortization :61 — a cached static prefix makes later iterations cheaper)
exit on: all 5 dims ≥7 (PASS) OR ceiling reached OR user escalation.
```

`standard` and `skip` tiers unchanged (`standard` runs once, `:335`; `skip` skips, `:316`).

**Change — refine-vs-pivot decision.** After each evaluation the generator makes the article's strategic choice (§5):

```
After evaluation N (scores S_N from design-critic):
  trend = S_N - S_{N-1}   (mean across 5 dims; first iter has no trend → REFINE)

  if verdict == PASS:                          → STOP (ship)
  elif trend > +REFINE_THRESHOLD:              → REFINE (scores improving; iterate current tone)
  elif N >= PIVOT_AFTER and trend <= STUCK_EPS: → PIVOT
  else:                                         → REFINE

REFINE: feed the critique back to Phase 4 IMPLEMENT for one revision of the CURRENT tone
        (today's behavior, :330–332).
PIVOT:  abandon the current tone. Re-enter Phase 3.0.1 and commit to a DIFFERENT tone from
        the 13-tone menu (:115–117) — one not yet tried this run. Regenerate from the new
        tone, carrying forward only structural/content decisions, not the failed aesthetic.
        Log the pivot (which tone → which, and why) to the activity feed.

  defaults: PIVOT_AFTER = 4, STUCK_EPS = +0.5, REFINE_THRESHOLD = +0.5
            (≈ "flat or improving by <0.5 over a dim-mean after 4 iters → try a different idea")
```

The pivot space is the existing 13-tone vocabulary (`:115–117`) — no new machinery. Track tried tones in run state so a pivot always chooses an untried tone; if all reasonable tones are exhausted, escalate to user (the bound, not a flat 3).

**Why:** unlocks the article's late creative leap (the Dutch-museum iteration-10 pivot). A refine-only loop can only polish the first idea; the pivot can find a better different idea.

---

## 3. Capability-relative evaluator trigger (Gap 4)

**Today.** `design_quality` ∈ skip/standard/high is page-category-based and fixed (`:315–318`).

**Change.** Keep the flag as the coarse tier, but make the **`standard` tier's evaluator run conditional** on edge-of-solo-capability signals (the article's dynamic-cost principle, §7):

```
high   → ALWAYS evaluate (customer-facing stakes justify it regardless of model capability).
skip   → never (unchanged).
standard → evaluate ONLY IF any edge-of-capability signal fires:
   (a) novel aesthetic   — committed tone not previously shipped in this project
                           (no prior page on that tone in DESIGN.md / run history);
   (b) interaction complexity — page has forms / multi-step flows / stateful widgets;
   (c) low generator self-confidence — generator self-reports uncertainty after Phase 4;
   (d) deterministic-lane findings present — npx impeccable detect returned design-pillar hits.
   else → ship solo (the evaluator is "unnecessary overhead", article §7).
```

**Living-decision discipline.** Annotate the trigger as re-examined each model release, cross-linked to Blitz's existing precedent for exactly this move on the *code* side:
- `docs/validation/v1.16.0/agents/critic.md:20` (A5 — critic detector re-justification, KEEP-vs-THIN per Opus-4.8 self-correction);
- `docs/audits/cohesion-2026-05/agents/critic.md:81` (4.8 honesty lens);
- `check-registry.json:482` (det-20 down-weighted under Opus 4.8).

Gap 4 is the same stress-test-and-strip discipline applied to the **design** evaluator trigger that v1.16.0 applied to **code** detectors. (Note: the brief attributed this to v2.0.0; it is v1.16.0/cohesion — see [`gap-fixes.md`](gap-fixes.md) Gap 4.)

**Why:** net token/wall-clock savings — stops paying for an evaluator pass on `standard` pages now within Opus 4.8 solo capability, freeing budget for Gap 1's live nav on `high` pages.

---

## 4. Combined loop (after all three changes)

```
Phase 3/4 GENERATE  ── carries the 5-dim rubric as steering (Gap 5) ──► output v1
                              │
                       trigger check (Gap 4): high → eval; standard → eval iff edge-signal; skip → ship
                              │ (evaluate)
        ┌─────────────────► design-critic (live nav, Gap 1) ──► scores + verdict
        │                         │
        │              ┌──────────┴───────────┐
     REFINE         PASS→ship            PIVOT (Gap 2: trend flat after PIVOT_AFTER)
   (current tone)                        (new tone from 13-tone menu)
        │                                       │
        └────────────── loop, bounded by ceiling=min(10, budget) ──────────┘
                              exit: PASS | ceiling | user escalation
```

---

## 5. Acceptance (grep-based)

```sh
# Gap 5 — generation prompt carries the 5-dim rubric + museum-quality steering
grep -iE "museum quality|generation rubric|graded on these 5 dimensions" skills/ui-build/SKILL.md

# Gap 2 — ceiling no longer a flat 3; refine-vs-pivot present
grep -iE "MAX_DESIGN_ITERS|up to (10|fifteen|15)|refine.{0,8}pivot|PIVOT_AFTER" skills/ui-build/SKILL.md
grep -iE "pivot to (a |an )?different (tone|aesthetic)" skills/ui-build/SKILL.md
! grep -E "Max 3 revisions per page" skills/ui-build/SKILL.md        # old flat cap removed for high tier

# Gap 4 — capability-relative trigger on standard tier
grep -iE "edge[- ]of[- ]capability|novel aesthetic|unnecessary overhead|capability-relative" skills/ui-build/SKILL.md
grep -iE "v1.16.0|cohesion-2026-05|det-20" skills/ui-build/SKILL.md   # cross-link to the precedent
```

Implementation is a follow-up sprint behind Blitz's gates. Sequencing in [`SYNTHESIS.md`](SYNTHESIS.md).
