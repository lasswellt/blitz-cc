# References, Re-grounded — normalized guidance + adapter notes

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0) — `skill/SKILL.src.md` (General rules), `skill/reference/*.md` (27 files), register refs `brand.md`/`product.md`; incorporates ehmo `typecraft-guide` (typography) per NOTICE chain. Original Blitz authorship. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** doc #5 of 8. Re-grounds design guidance against [`normalized-model.md`](normalized-model.md); per-adapter notes resolve to [`framework-profiles.md`](framework-profiles.md).

---

## 0. Structure reality vs the spec's "7 references"

The originating spec assumed impeccable had **7 domain references** (typography, color-and-contrast, spatial-design, motion-design, interaction-design, responsive-design, ux-writing). The live `2.3.2` tree is organized differently: **cross-register guidance lives in `SKILL.src.md` "General rules"**, distributed across **23 verb-command references** (`typeset`, `colorize`, `layout`, `animate`, `shape`, `clarify`, `adapt`, …) + **register refs** (`brand.md`, `product.md`) + `interaction-design.md` + `codex.md`.

This doc keeps the spec's **7-domain framing as the organizing lens** (it maps cleanly to the normalized facets) and points each domain at its real impeccable source. Each domain: **normalized core** (stated against the model — survives any stack) + **adapter notes** (how it resolves per stack) + **kept vs replaced**.

| Domain | Normalized facet | impeccable source (live) |
|---|---|---|
| 1 Typography | type-scale | SKILL "Typography" + `typeset.md` + ehmo typecraft |
| 2 Color & contrast | color-roles + on-pairing | SKILL "Color"/"Color & Theme" + `colorize.md` |
| 3 Spatial design | spacing/density | SKILL "Layout" + `layout.md` |
| 4 Motion design | motion | SKILL "Motion" + `animate.md` |
| 5 Interaction design | (cross-facet) | `interaction-design.md` + SKILL "Interaction" |
| 6 Responsive design | (cross-facet) | SKILL `adapt` + register responsive notes |
| 7 UX writing | (none — copy) | SKILL "Copy" + `clarify.md` |

Plus the orthogonal **register** model (`brand.md`/`product.md`) and **shape** (`shape.md`) — covered in §8.

---

## 1. Typography (facet: type-scale)

**Normalized core** (stack-independent): modular scale (≥1.25 brand / 1.125–1.2 product), capped families ≤3 (display + body + optional mono), hierarchy via scale+weight; hero `clamp()` max ≤6rem; display tracking floor ≥−0.04em; body line-length 65–75ch; no all-caps body; `text-wrap: balance` on h1–h3, `pretty` on prose. ehmo additions: dark-mode weight/tracking compensation, `font-display: optional`, variable fonts for 3+ weights, optical sizing.

**Adapter notes:**
- **Tailwind:** `--text-*` (+ paired line-height), `--font-*`, `--tracking-*`, `--leading-*` in `@theme`. Fixed-vs-fluid is the author's call (register decides).
- **MD3:** the **15-role scale** (`--md-sys-typescale-<role>-<prop>`) is the type system — conform to it, don't invent sizes. Tracking unsupported on web.
- **Vuetify:** v4 MD3 type classes (`text-display-large`…); v3 MD2 (`text-h1..h6`). Roboto default.
- **Quasar:** `text-h1..h6`/`body1/2`/`caption`/`overline`; `$body-font-size 14px`.

**Kept:** all impeccable type rules (universal slop: `overused-font`, `single-font`, `flat-type-hierarchy`, `oversized-h1`, `extreme-negative-tracking`, `all-caps-body`, `wide-tracking`, `tight-leading`). **Replaced:** the "hand-roll `@theme --text-*`" assumption → adapter-resolved type surface.

---

## 2. Color & contrast (facets: color-roles + on-pairing)

**Normalized core:** every color is a **role**, never a raw literal; OKLCH for new palettes; dominant+accent (60-30-10) beats even distribution; pick a color *strategy* (restrained/committed/full/drenched) before colors; contrast verified (body ≥4.5:1, large ≥3:1, placeholders ≥4.5:1); gray-on-color is washed out (use a darker hue of the bg or transparency of the ink). Anti-cream / anti-AI-palette: the warm-neutral band + purple-on-white are saturated AI defaults.

**Adapter notes (the on-pairing split is the key resolution):**
- **Tailwind:** `--color-*` open convention; **no native `on-*`** → contrast is computed-fallback (the `visual` engine). Alias `--color-on-*` by hand.
- **MD3:** **49 closed roles**; **`on-<role>` enforced** at WCAG-AA — conformance is "use a role + its on-pair," not "pick a hex."
- **Vuetify:** named `colors{}` with **auto-generated `on-*`** per color; custom CSS uses `rgb(var(--v-theme-*))`.
- **Quasar:** **8 brand** + palette; no `on-*` token (component-internal) → computed-fallback.

**Kept:** `ai-color-palette`, `cream-palette`, `gray-on-color`, `low-contrast`, OKLCH + strategy guidance (all system-independent — satisfied by adopting the stack's role/brand tokens). **Replaced:** "hardcode OKLCH in `@theme`" → the adapter's role surface; contrast enforcement split enforced-by-role vs computed-fallback.

---

## 3. Spatial design (facet: spacing/density)

**Normalized core:** spacing on a 4/8px grid, varied for rhythm (generous separations + tight groupings); cards are the lazy answer (nested cards always wrong); flexbox 1D / grid 2D (`repeat(auto-fit, minmax(280px,1fr))` for breakpoint-free grids); semantic z-index scale (dropdown→sticky→modal→toast→tooltip), never `9999`. Density mode by register (brand generous / product controlled).

**Adapter notes:** Tailwind `--spacing` scalar + utilities; MD3 inherits Tailwind spacing (no separate web scale); Vuetify `density` prop + spacing classes; Quasar `q-pa-*`/`q-gutter-*` + `$space-*` + `dense`.

**Kept:** `nested-cards`, `monotonous-spacing`, `cramped-padding`, `body-text-viewport-edge`, z-index-scale guidance. **Replaced:** raw spacing values → the stack's spacing scale (Layer 1 `raw-spacing`).

---

## 4. Motion design (facet: motion)

**Normalized core:** intentional motion; ease-out exponential by default (no bounce/elastic *in bespoke CSS*); don't animate layout props; `prefers-reduced-motion` mandatory; reveal-safety (never gate content visibility on a transition); staggering one list is fine, the uniform section-fade reflex is the tell; premium materials (blur/mask/clip-path/glow) are part of the palette. Register tempo: product 150–250ms state-motion; brand orchestrated first-load.

**Adapter notes (the reconciliation domain):**
- **Tailwind:** `--ease-*` (ease-out default); bounce is opt-in → **rule kept**.
- **MD3:** `--md-sys-motion-easing-*`/`-duration-*`; M3 Expressive **spring prescribed** → **bounce rule relaxed** (cite spring / `emphasized-*` overshoot). Web spring tokens pending.
- **Vuetify:** MD-canonical curves, no bounce in built-ins → **rule kept** (no exemption); prescribed `v-*-transition` components not flagged as author motion.
- **Quasar:** Animate.css (`bounceIn/Out`) is vocabulary → **bounce rule relaxed** (cite Animate.css).

**Kept:** `reduced-motion`, `layout-transition`, reveal-safety, no-section-fade. **Reconciled:** `bounce-easing` per adapter ([`normalized-model.md`](normalized-model.md) §5.1). **Replaced:** uniform "no bounce" → per-adapter reconciliation.

---

## 5. Interaction design (cross-facet)

**Normalized core:** dropdowns in `overflow:hidden/auto` get clipped — use native `<dialog>`/popover/`position:fixed`/portal; never animate `<img>` on hover (no-information motion tell); product components ship all states (default/hover/focus/active/disabled/loading/error); skeletons over spinners; empty states teach.

**Adapter notes:** mostly framework-independent. Component-state coverage is **owned by the component framework** (Quasar `<q-*>`/Vuetify `<v-*>` ship states; Tailwind hand-rolls them). `clipped-overflow-container` + `image-hover-transform` are universal (Layer 0).

**Kept as-is** — `interaction-design.md` is framework-independent. Adapter note added: state coverage delegates to the component framework where one is present.

---

## 6. Responsive design (cross-facet)

**Normalized core:** test heading copy at every breakpoint (text-overflow is a ban — the viewport is part of the design); responsive behavior is **structural** in product (collapse sidebar, responsive table) vs **fluid** in brand (`clamp()` that breathes).

**Adapter notes:** Tailwind breakpoint prefixes (`sm:`…) + first-class container queries (`@container`); MD3 inherits Tailwind; Vuetify `<v-row>/<v-col>` grid + display utilities; Quasar `$breakpoint-*` + responsive visibility classes.

**Kept:** `text-overflow`, responsive-structural-vs-fluid (register). **Replaced:** breakpoint mechanism → adapter-resolved.

---

## 7. UX writing (copy) — framework-independent, kept verbatim

**Normalized core (no adapter resolution — copy is stack-independent):** every word earns its place (no restated headings); **no em dashes** (and not `--`); no aphoristic-cadence as default voice; **no marketing buzzwords** (streamline/empower/supercharge/leverage/seamless/world-class/…); button labels verb+object ("Save changes" > "OK"); link text standalone ("View pricing" > "Click here").

**Kept entirely** — `clarify.md` + SKILL "Copy" + the detector rules `em-dash-overuse`, `marketing-buzzword`, `aphoristic-cadence`, `theater-slop-phrase` carry over unchanged as Layer 0. **No adapter notes** — this domain never resolves per stack.

---

## 8. Register (orthogonal) + shape

- **Register** (`brand.md` vs `product.md`) composes orthogonally with the adapter ([`normalized-model.md`](normalized-model.md) §3). Re-grounded unchanged: brand = design IS the product (committed/drenched palettes, fluid type, orchestrated motion, imagery-required, reflex-reject font/aesthetic lanes); product = design SERVES (restrained, fixed rem, state-motion, all-states components, familiar affordances). A `(brand, quasar)` or `(product, tailwind-md3)` profile loads both.
- **Shape** (`shape.md` + the `border-radius` facet): radius scale + caps re-grounded as defer-to-stack-tokens (Layer 1 `raw-radius`).

### 8.1 Aesthetic direction — the 13-tone palette (canonical home)

Relocated from the retired `frontend-design-heuristics.md` §2/§7 (see [`migration-spec.md`](migration-spec.md) §2). The **tone** is the one-word aesthetic commitment made before any code (impeccable `brand.md` register; `ui-build` Phase 3.0.1 keeps an inline mirror). Pick exactly one; do not blend:

`brutalist/minimal` · `maximalist` · `retro-futuristic` · `organic/natural` · `luxury/refined` · `playful/toy-like` · `editorial/magazine` · `art-deco` · `soft/pastel` · `industrial` · `dark/moody` · `lo-fi/zine` · `handcrafted/artisanal`

**The NEVER list** (auto-fail aesthetic tells) is no longer prose — it is the **Layer 0 deterministic detector**: `overused-font` (Inter/Roboto), `ai-color-palette` (purple-on-white / default Tailwind palette), `gradient-text`, `border-accent-on-rounded` (all-rounded), `identical-card-grids` (cookie-cutter grid), `repeated-section-kickers` / `numbered-section-markers`, plus `agents/design-critic.md` dimension 2.5 (all-centered, shadcn-defaults, same-design-3×). Consumers (`design-extract` tone inference, `design-critic` aesthetic-fit, `ui-build` tone selection) read THIS section + the registry, not the retired heuristics file.

---

## 9. Setup flow (re-grounded, adapter-aware)

impeccable's setup (run `context.mjs` → load register ref → read existing tokens → palette for greenfield) gains a **stack-detect step first**:

1. `context.mjs` + the new `stack` probe ([`adapter-detection.md`](adapter-detection.md)) → resolve adapter(s).
2. Load the matching **adapter profile** ([`framework-profiles.md`](framework-profiles.md)) — Quasar project gets `quasar.variables.scss` guidance, not `@theme`.
3. Load the **register** ref (orthogonal).
4. Read existing tokens (identity-preservation wins).
5. **Greenfield, no stack detected:** stay stack-agnostic (universal slop + `@theme` defaults) **or** recommend a stack — never silently assume one.

---

## 10. What's kept vs replaced (summary)

| Kept (system-independent) | Replaced (was single-aesthetic → now adapter-resolved) |
|---|---|
| All Layer 0 slop bans (39 rules) | "hand-roll OKLCH in `@theme`" → adapter color surface |
| UX-writing domain (copy) — verbatim | uniform "no bounce" → per-adapter reconciliation |
| Register model (brand/product) | type/spacing/radius hardcoding → defer to stack tokens |
| Contrast floors (WCAG) | contrast mechanism → enforced-by-role vs computed-fallback |
| Color strategy / anti-cream philosophy | elevation bans → defer to stack elevation system |

**Coverage guarantee:** every section of the retired [`frontend-design-heuristics.md`](../../../skills/_shared/frontend-design-heuristics.md) maps into this doc + the normalized model + the Layer 0 detector (proven in [`migration-spec.md`](migration-spec.md) §coverage).

---

## Acceptance (grep-checkable)

- 7 domains, each with normalized core + (where applicable) adapter notes + kept/replaced.
- UX-writing marked framework-independent (no adapter notes) and kept verbatim.
- Motion domain carries the per-adapter `bounce-easing` reconciliation.
- Register declared orthogonal; setup flow detects stack before loading guidance.
- Maps the spec's 7-domain framing onto the live impeccable file structure (no claim of "7 reference files").
