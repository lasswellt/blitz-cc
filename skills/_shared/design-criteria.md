# Design Criteria — shared rubric (generator + evaluator single source)

Canonical definitions of the 5 design dimensions, used **both** as generation steering
(`skills/ui-build/SKILL.md` Phase 3) and as the scoring rubric
(`agents/design-critic.md` §2). Handing the same criteria to the generator that the
evaluator grades against produces measurable first-iteration lift before any evaluator
cycle runs — the criteria themselves steer the model off generic defaults.

Origin concept: anthropic.com/engineering/harness-design-long-running-apps (2026-03-24);
integration map: `docs/integrations/harness-design/`.

---

## The 5 dimensions (0–10 each; PASS = all five ≥7)

**The best designs are museum quality. Build to that bar from the first pass.**

- **Prompt Adherence** — deliver the genre the user asked for. A landing page looks like a
  landing page; an admin table looks like an admin table. No feature-creep, no wrong genre.
- **Aesthetic Fit** — fully embody the ONE committed tone (from the 13-tone palette). No tonal
  drift: a `luxury/refined` tone with chunky brutalist borders fails; a `playful/toy-like` tone
  rendered grayscale-corporate fails.
- **Visual Polish** — spacing rhythm, alignment, typography hierarchy, color cohesion, contrast.
  No misaligned baselines, inconsistent gutters, mixed radii without intent, flat type scale.
- **UX** — clear primary action, scan-ability, real empty/loading/error states, genuinely usable
  at 375px (not a compressed desktop), keyboard-reachable, no broken wiring (controls respond).
- **Creative Distinction** — a point of view, not generic AI output. **THE HARDEST BAR.** If it
  could come from any AI tool circa 2025, it fails. Avoid: banned fonts (Inter/Roboto/Arial/
  system-ui/Space Grotesk as primary), purple-on-white gradients, all-rounded corners,
  all-centered layouts, dashboard sameness.

## Weighting emphasis

Grade hardest where the model is weakest. **Creative Distinction** and **Aesthetic Fit** are the
two dimensions a competent model still gets generically wrong by default — score and steer them
most ruthlessly. Visual Polish, UX, and Prompt Adherence the model already handles well.
Numeric scoring stays equal-weight (flat ≥7 gate); the emphasis is in attention, not arithmetic.

## "Museum quality" steering note

The phrase "the best designs are museum quality" pushes output toward a distinctive visual
convergence. It helps gallery/editorial/luxury/minimal tones; for `playful/toy-like`,
`lo-fi/zine`, or `handcrafted/artisanal` it may pull the wrong way — prefer tone-conditional
phrasing ("the best designs are unmistakably *intentional*") when the committed tone is informal.
