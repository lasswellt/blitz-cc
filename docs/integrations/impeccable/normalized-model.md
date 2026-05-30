# Normalized Design Model — the framework-adaptive spine

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0) + Anthropic `frontend-design` (Apache-2.0) + ehmo `typecraft-guide`. This document is original Blitz authorship; the design principles it normalizes are re-grounded from impeccable. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** spine doc #1 of 8. Spec-only pass; no implementation. Pairs with [`adapter-detection.md`](adapter-detection.md).
> **Version note:** the originating prompt cited impeccable `v3.5.0` and "7 references"; the live tree is `2.3.2` with 23 verb-commands + 27 reference files. This spec is grounded in the live tree.

---

## 1. Why a spine

Impeccable today encodes **one** aesthetic stack: hand-rolled CSS, OKLCH tokens, `@theme`-style custom properties, "no bounce" motion, radius caps, ghost-card bans. That guidance is correct for a bespoke-CSS project and wrong-in-the-details for a project on Vuetify, Quasar, or MD3 — where elevation, transitions, shape, and color are owned by the framework's token system.

The fix is **not** four parallel design skills. It is **one normalized design model** that all four stacks express, plus **pluggable adapters** that resolve the model to each stack's surface. The same principle ("every color is a role, not a hex") holds everywhere; only the *authoring surface* (`@theme` var vs SCSS `$var` vs JS theme config), the *token naming*, and the *conformance rules* resolve per framework.

This mirrors how impeccable already swaps defaults by **register** (brand vs product). A framework adapter is the same pattern, one level down: a profile that resolves the model to a stack.

**Two orthogonal profile dimensions** (§3): `register` (brand|product — token *strategy*) × `adapter` (tailwind|tailwind-md3|vuetify|quasar|… — token *surface*). Both load; they never collapse.

---

## 2. The seven facets

The normalized model is seven facets. Guidance and detector rules are written against these; adapters resolve them. Each facet below: the normalized concept, the impeccable rule(s) that target it (the coverage anchor), and the abstract expression every adapter must provide.

### 2.1 Color roles
**Concept:** every color is a semantic *role*, never a raw literal. Core roles: `primary`, `accent`, `surface` (+ container/raised variants), `ink`/`on-surface`, `muted`, and semantic `positive`/`negative`/`info`/`warning`. A role is referenced by name; a raw `#hex`/`rgb()` in a component is a smell.
**Impeccable anchors:** `ai-color-palette`, `cream-palette` (detector); `skill-color-use-oklch`, `skill-color-strategy-commitment`, `skill-color-anti-cream`, `skill-color-tinted-neutrals-chroma` (skill).
**Adapter must provide:** the role→token-name map, and whether roles are a closed set (MD3, Vuetify, Quasar's 8 brand) or open convention (Tailwind `--color-*`).

### 2.2 On-* pairing (contrast)
**Concept:** every background role has a paired foreground (`on-<role>`) at verified contrast — body ≥4.5:1, large (≥18px / bold ≥14px) ≥3:1, placeholders ≥4.5:1.
**Impeccable anchors:** `skill-color-verify-contrast`, `skill-color-gray-on-color`; detector `visual` engine (computed contrast).
**Adapter must provide:** `onPairing: enforced-by-role | computed-fallback`. MD3 and Vuetify expose `on-*` roles → enforce by token. Plain Tailwind and Quasar lack a complete `on-*` system → computed-contrast fallback (the `visual` engine).

### 2.3 Type scale
**Concept:** a modular scale (steps related by ratio, not arbitrary), capped family count (≤3: display + body + optional mono), hierarchy via scale + weight. Register sets the ratio and fluid-vs-fixed (brand: fluid `clamp()`, ≥1.25; product: fixed `rem`, 1.125–1.2). Hero ceiling `clamp()` max ≤6rem; display tracking floor ≥-0.04em; body line-length 65–75ch.
**Impeccable anchors:** `overused-font`, `single-font`, `flat-type-hierarchy` (detector); `skill-typo-*` (scale-ratio, font-count, hero-ceiling, tracking-floor, line-length, font-pairing-contrast, no-all-caps-body, text-wrap-balance); `product-typo-fixed-rem-scale`, `brand-typo-modular-scale`.
**Adapter must provide:** the type-token surface (`--text-*` / MD3 15-role scale / Roboto + Material classes / Quasar `text-h*`) and whether the scale is fixed by the framework.

### 2.4 Shape / radius
**Concept:** a radius *scale token*, not arbitrary values. Cards top out 12–16px; full-pill for tags/buttons only; ≥32px on a card is an over-round tell.
**Impeccable anchors:** `skill-ban-codex-over-round` (≥32px), `border-accent-on-rounded` (detector).
**Adapter must provide:** the radius-token surface and a **reconciliation**: where the stack defines shape tokens (MD3 corner tokens, Vuetify/Quasar `$generic-border-radius` + `rounded` props), the hard 32px cap **defers** to the stack's shape scale.

### 2.5 Motion
**Concept:** intentional motion; default vocabulary is ease-out exponential (no bounce/elastic), `prefers-reduced-motion` mandatory, no animating layout props, reveal-safety (never gate content on a transition). Register sets tempo (product 150–250ms state-motion; brand orchestrated page-load).
**Impeccable anchors:** `skill-motion-*` (ease-out-exp, reduced-motion, no-layout-animate, reveal-safety, materials-palette), `product-motion-quick-transitions`, `brand-motion-one-page-load`.
**Adapter must provide:** the motion-token surface and a per-adapter **reconciliation** (verified non-uniform): the "no bounce/elastic" rule **relaxes** under MD3 (M3 Expressive prescribes spring; `emphasized-*` curves overshoot) and Quasar (Animate.css `bounceIn/Out` are first-class vocabulary), but is **kept** under Tailwind (default `--ease-*` are ease-out; bounce is an opt-in keyframe) and Vuetify (built-ins use MD-canonical standard/decelerated/accelerated curves — no bounce/spring). Prescribed transition components (Vuetify `v-*-transition`, Quasar Animate.css) are never flagged as author motion. See §5.1.

### 2.6 Spacing / density
**Concept:** a spacing scale on a 4/8px grid; a density *mode* tied to register (brand: generous whitespace; product: controlled density — compressed type, single-px separators, color-encodes-meaning). Also the semantic **z-index scale** (dropdown→sticky→modal→toast→tooltip), never arbitrary `9999`.
**Impeccable anchors:** `skill-layout-vary-spacing`, `skill-layout-z-index-scale`; product density vs brand fluid-spacing guidance.
**Adapter must provide:** the spacing-token surface and the density-mode default (often register-driven, but Quasar/Vuetify ship density props).

### 2.7 Elevation
**Concept:** a semantic elevation *scale*, not arbitrary shadows. The "ghost-card" (1px border + ≥16px soft shadow as decoration) is banned for bespoke CSS.
**Impeccable anchors:** `skill-ban-codex-ghost-card` (1px border + box-shadow ≥16px).
**Adapter must provide:** the elevation surface and a **reconciliation**: where the stack owns elevation (MD3 levels 0–5 + tonal `surface-container-*` preferred over shadow, Vuetify `elevation` prop 0–24 v3 / 0–5 v4, Quasar `shadow-1..24`), the ghost-card ban **relaxes** — using the prescribed elevation system is correct, not a tell. The bespoke-CSS `none` adapter has no elevation system → the ban is **kept**.

---

## 3. Register × adapter orthogonality

Impeccable's setup loads exactly one **register** reference (`brand.md` when design IS the product — marketing/landing/campaign/portfolio; `product.md` when design SERVES the product — app/admin/dashboard/tool). Register decides token **strategy and permission**:

| | brand register | product register |
|---|---|---|
| Color | Committed / Full / Drenched permitted | Restrained floor; accent for actions/state only |
| Type | fluid `clamp()`, ≥1.25, display+body pairing | fixed `rem`, 1.125–1.2, one family often right |
| Motion | orchestrated first-load reveals | 150–250ms state-motion, no page-load sequence |
| Density | generous, single-purpose viewports | dense, all-states components, consistent vocabulary |

The **adapter** decides token **surface** (where/how you write the token) and **conformance** (which raw-value misuse to flag). These are independent axes:

```
profile = register × adapter          # 2 × N, fully orthogonal
e.g.  (brand, quasar)      # a Quasar marketing microsite
      (product, tailwind-md3)  # an MD3 admin dashboard on Tailwind
      (product, vuetify)   # a Vuetify internal tool
```

Both dimensions are loaded at setup. A detector rule is selected by **adapter** (which surface to check) and tuned by **register** where a threshold differs (e.g. fluid-clamp expected under brand, flagged under product). Neither dimension is derivable from the other.

---

## 4. The adapter contract

Every adapter is a profile filling this exact shape. The contract is the extensibility guarantee: a 5th adapter (PrimeVue, Nuxt UI, shadcn-vue, Element Plus) is added by filling this shape — **the spine never changes**.

```jsonc
Adapter := {
  id:        "tailwind" | "tailwind-md3" | "vuetify" | "quasar" | <new>,
  primaryOf: ["component-authority"] ,        // can this be the primary stack?
  secondaryAllowed: boolean,                   // can it layer onto another primary? (e.g. Tailwind utilities on Vuetify)

  detection: {                                 // consumed by adapter-detection.md selector
    deps:             [<package.json dep names>],
    configFiles:      [<glob signatures>],
    sourceSignatures: [<regex/import signatures>],
  },

  facets: {                                    // one resolver per §2 facet
    colorRoles:   { surface, naming, closedSet: boolean },
    onPairing:    "enforced-by-role" | "computed-fallback",
    typeScale:    { surface, fixedByFramework: boolean },
    shape:        { surface },
    motion:       { surface, springPrescribed: boolean },
    spacing:      { surface, densityProp: boolean },
    elevation:    { surface, levels }
  },

  runtimeThemingApi: <how themes switch at runtime>,
  darkMode:          <mechanism>,

  conformanceRules: [<registry rule ids tagged adapter:id>],   // Layer 2 (detector-rebuild.md)

  reconciliations: {                           // which universal/bespoke bans relax, and why
    bounceEasing:        "keep" | "relax",      // relax under MD3 spring
    ghostCardElevation:  "keep" | "relax",      // relax where stack owns elevation
    radiusCap:           "keep" | "defer",      // defer to stack shape tokens
    rawColorLiteral:     "keep"                 // KEPT everywhere — satisfied by adopting role/brand tokens
  }
}
```

**Contract invariants** a new adapter must satisfy:
1. Resolves **all seven** facets (no `null` resolvers — a stack with no elevation system declares `levels: 0` + `ghostCardElevation: keep`).
2. Declares its `detection` triple so the selector (§ adapter-detection.md) is deterministic.
3. `rawColorLiteral: keep` is non-negotiable — the anti-cream / anti-AI-palette discipline is system-independent; an adapter satisfies it by adopting the stack's role/brand tokens, never by exemption.
4. Each `relax`/`defer` reconciliation cites the stack feature that justifies it (MD3 spring, Vuetify elevation prop, Quasar shadow class). A bare `relax` with no cited prescription is rejected.

---

## 5. The resolution matrix

How each facet resolves per adapter — **verified** against the four research passes (Tailwind v4.3.0, Quasar 2.19.3, Vuetify 3.12.7 / 4.0.8, MD3 `material-web` main; all 2026-05-30). [`framework-profiles.md`](framework-profiles.md) carries the version-cited primary sources.

| Facet (normalized) | Tailwind v4.3 | Tailwind + MD3 | Vuetify 3.12 / 4.0 | Quasar 2.19 |
|---|---|---|---|---|
| **Authoring surface** | `@theme` CSS vars (CSS-first; no JS config) | `@theme` aliasing `--md-sys-*` | `createVuetify({ theme })` JS/TS | `quasar.variables.scss` SCSS `!default` |
| **Color roles** | `--color-*` (open convention; palette only, **no semantic roles**) | 49 MD3 sys roles: `primary`/`on-primary`/`*-container`, secondary, tertiary, error, surface + `surface-container-{lowest…highest}`, outline, inverse | `primary`/`secondary`/`surface`/`background`/`error`/`info`/`success`/`warning` + auto `*-darken/lighten`; **no `accent`** (v2 concept) | 8 brand: `$primary`/`$secondary`/`$accent`/`$dark`/`$positive`/`$negative`/`$info`/`$warning` (+ `$dark-page`; 24×14 palette) |
| **Color output** | `:root` CSS vars + generated utils; runtime-overridable | `--md-sys-color-*` on `:root` (via material-color-utilities) | `--v-theme-*` (RGB triplet) + `text-*`/`bg-*`/`text-on-*` classes | `--q-*` on `document.body` + `bg-*`/`text-*` classes |
| **On-* pairing** | computed-fallback (no native `on-*`) | **enforced-by-role** (`on-<role>`, WCAG-AA guaranteed) | **enforced-by-role** (auto-generated `on-*` per color) | computed-fallback (no `on-*` token; component-internal) |
| **Type scale** | `--text-*` (xs…9xl) + paired line-height | 15-role MD3 scale `--md-sys-typescale-<role>-<prop>` (display/headline/title/body/label × L/M/S); tracking unsupported on web | v3: MD2 `text-h1..h6`/`subtitle-1/2`/`body-1/2`; v4: MD3 names (`text-display-large`…) | `text-h1..h6`/`subtitle1/2`/`body1/2`/`caption`/`overline`; `$body-font-size 14px` |
| **Shape / radius** | `--radius-*` (xs…4xl; v3→v4 scale shift) | 7 MD3 corners `--md-sys-shape-corner-{none…full}` (0/4/8/12/16/28dp/pill) | `rounded` prop (0/sm/md/lg/xl/pill/circle) + `rounded-*`; `$border-radius-root 4px` | `$generic-border-radius 4px` + `.rounded-borders` |
| **Motion** | `--ease-*` (in/out/in-out; ease-out default; bounce = opt-in keyframe) | `--md-sys-motion-easing-*` + `-duration-*`; M3 Expressive **spring prescribed** (web CSS spring tokens pending) | MD-canonical `$standard`/`$decelerated`/`$accelerated` (no bounce); 15 `v-*-transition` | Animate.css (`bounceIn/Out`, …); `$animate-duration .3s` |
| **Spacing / density** | `--spacing` scalar → all spacing utils | MD3 + spacing utils | `density` prop + spacing classes | `$space-*` + `dense` props |
| **Elevation** | `shadow-*` utils (no semantic elevation abstraction) | levels 0–5; tonal `surface-container-*` **preferred** over `--md-elevation-level` shadow | `elevation` prop + `elevation-*`: **0–24 (v3) / 0–5 (v4, MD3)** | `shadow-1..24` + `shadow-up-*` (MD 24-level) |
| **Runtime theming** | CSS-var override / `[data-theme]`; `getComputedStyle` (no `resolveConfig` in v4) | material-color-utilities `applyTheme()` (dynamic color) | `useTheme()` (`theme.global.name`, `.toggle/.change/.cycle`) | `setCssVar()`/`getCssVar()`/`getPaletteColor()` |
| **Dark mode** | `dark:` — `prefers-color-scheme` default or `@custom-variant dark` | MD3 dark scheme (sys→ref remap) | per-theme `dark:true/false`; `'system'` reserved; default `light` (v3) / `system` (v4) | `$q.dark` plugin; `body--dark` class |

> **Verification note.** Cells are verified to the dates above. The Vuetify column spans **v3 and v4** where they diverge (elevation, type scale, `--v-theme-*` alpha syntax) — see [`adapter-detection.md`](adapter-detection.md) §6 for the variant split and the open v4-vs-v3 profile decision. MD3 spring *motion tokens* are spec'd but **not yet CSS-implemented on web** (`material-web` ships easing+duration); the spring reconciliation applies to the `emphasized-*` overshoot curves today.

### 5.1 Per-adapter reconciliation (the filled contract)

The `reconciliations` field (§4) resolved from the research. **Not uniform** — the bounce/easing rule is the clearest case:

| Ban (universal / bespoke) | `none` (bespoke CSS) | Tailwind v4 | Tailwind + MD3 | Vuetify 3/4 | Quasar 2 |
|---|---|---|---|---|---|
| **`rawColorLiteral`** — no raw hex; use a role token | keep | keep (`[#hex]` arbitrary = advisory) | keep | keep¹ | keep² |
| **`bounceEasing`** — no bounce/elastic | keep | **keep** (ease-out default) | **relax** (M3 Expressive spring / `emphasized-*`) | **keep** (MD-canonical; built-ins never bounce) | **relax** (Animate.css `bounceIn/Out`) |
| **`ghostCardElevation`** — 1px border + ≥16px shadow | keep | relax (border + `shadow-md` idiomatic) | relax (MD3 elevation / tonal surface) | relax (`elevation` prop) | relax (`shadow-1..24`) |
| **`radiusCap`** — ≤16px on cards | keep | defer → `--radius-*` | defer → `--md-sys-shape-corner-*` (≤28dp + pill) | defer → `rounded` scale | defer → `$generic-border-radius` |

¹ Vuetify: literals are legitimate **only** inside `createVuetify({ theme: { colors } })`; literals in components/templates still flagged (use `rgb(var(--v-theme-*))`).
² Quasar: legitimate inside `quasar.variables.scss`; raw inline hex in templates still flagged (use `bg-primary` / `setCssVar`).

Per the §4 contract, every `relax`/`defer` cites a prescription: `bounceEasing: relax` cites M3 Expressive spring (MD3) / Animate.css (Quasar) — Tailwind + Vuetify have **no** such prescription → `keep`. `ghostCardElevation`/`radiusCap` cite the stack's elevation / shape system; the `none` adapter has neither → `keep`. `rawColorLiteral: keep` is invariant everywhere — satisfied by adopting tokens, never by exemption.

---

## 6. Layered-detector relationship (forward reference)

The detector ([`detector-rebuild.md`](detector-rebuild.md)) targets this model in three layers:

- **Layer 0 — universal slop:** framework-independent tells (gradient-text, nested-cards, cream-palette, em-dash-overuse, broken-image, oversized-h1, low-contrast, line-length, …). Run on **every** adapter; target facets stack-independently.
- **Layer 1 — token-discipline:** the *same* normalized rule resolved per adapter ("use a role token, not a raw value") — §2.1/2.4/2.6 expressed against each adapter's surface.
- **Layer 2 — adapter conformance:** stack-specific rules (Tailwind `@apply`/legacy-v3 classes; MD3-role conformance; Vuetify `!important`-override anti-pattern; Quasar Tailwind-coexistence flags). Fire **only** for the detected adapter(s).

The reconciliations in §4 (`bounceEasing`/`ghostCardElevation`/`radiusCap`) are applied per adapter at this boundary: a Layer 0/1 rule that a stack legitimately overrides is suppressed for that adapter, with the cited prescription as justification.

---

## 7. Anti-scope (what the spine must NOT contain)

To keep adapters pluggable and the model stable:
- **No per-stack rules.** A rule hardcoded to `bg-[#...]` belongs in the Tailwind adapter (Layer 2), not the spine.
- **No aesthetic content.** Font pairings, color strategies, register voice → `references-regrounded.md`. The spine is structure, not taste.
- **No detection logic.** Selector signals → `adapter-detection.md`. The spine only declares the `detection` *shape* a contract.
- **No license/provenance prose.** → `ATTRIBUTION.md`.

A change that adds a stack-specific value to this file is the anti-pattern the architecture exists to prevent.

---

## Acceptance (grep-checkable)

- Seven facets, each with an impeccable coverage anchor: `grep -c '^### 2\.' normalized-model.md` → 7.
- Adapter contract present with all seven facet resolvers + four reconciliation keys.
- Resolution matrix covers 4 adapters × 11 rows.
- Register × adapter declared orthogonal (2×N), both loaded.
- Zero per-stack literals outside §5 matrix / §6 examples (anti-scope §7).
