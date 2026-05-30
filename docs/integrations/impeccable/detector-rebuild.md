# Detector Rebuild — the layered, adapter-aware deterministic lane

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0) — `cli/engine/registry/antipatterns.mjs` (41 rules), `cli/engine/rules/checks.mjs`, engines `{browser, regex, static-html, visual}`. Original Blitz authorship. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** doc #4 of 8 — **the keystone** (the deterministic design lane Blitz lacks). Consumes [`normalized-model.md`](normalized-model.md) facets + reconciliations, [`framework-profiles.md`](framework-profiles.md) conformance rules, [`adapter-detection.md`](adapter-detection.md) `stack` signal. Emits records into [`check-registry.json`](../../../skills/_shared/check-registry.json) under a new `design` pillar.

---

## 1. What impeccable ships today

A deterministic detector — **no LLM, no API key** — of **41 antipattern rules** across 4 engines:

| Engine | Rules (~) | Mechanism |
|---|---|---|
| `static-html` (jsdom) | 35 | parse DOM/CSS statically; no browser |
| `browser` (Puppeteer) | 18 | render + computed styles (URL targets) |
| `visual` | 6 | computed **contrast** (WCAG) |
| `regex` | 1 | source pattern |

Rule record (current): `{ id, category: 'slop'|'quality', name, description, skillSection, skillGuideline }`. **26 `slop`** (AI tells) + **15 `quality`** (a11y/readability). Run locally over `.html/.css/.scss/.vue/.jsx/.tsx/.astro/.svelte` via `detect.mjs --json <targets>`; `context-signals.mjs` surfaces the targets.

> The originating spec said "27-rule detector" — verified count is **41**. Spec figures were from an older impeccable; this rebuild is grounded in the live tree.

**The gap it fills:** Blitz's registry has deterministic lanes for shortcut/security/wiring/etc. but **no `design` pillar**. impeccable's engine is the missing deterministic design lane; `design-critic` is the semantic/vision lane. This doc restructures the 41 rules + adds Layer 1/2 rules as registry records, adapter-tagged.

---

## 2. The three layers

### Layer 0 — universal slop (framework-independent, always on)
Tells/quality that don't depend on the UI stack. **39 of the 41** impeccable rules are Layer 0 — they fire on every adapter (and on `none`):

`side-tab` · `border-accent-on-rounded` · `overused-font` · `single-font` · `flat-type-hierarchy` · `gradient-text` · `ai-color-palette` · `cream-palette` · `nested-cards` · `monotonous-spacing` · `dark-glow` · `icon-tile-stack` · `italic-serif-display` · `hero-eyebrow-chip` · `repeated-section-kickers` · `numbered-section-markers` · `em-dash-overuse` · `marketing-buzzword` · `aphoristic-cadence` · `oversized-h1` · `extreme-negative-tracking` · `repeating-stripes-gradient` · `theater-slop-phrase` · `image-hover-transform` · `broken-image` · `gray-on-color`¹ · `low-contrast`¹ · `layout-transition` · `line-length` · `cramped-padding` · `body-text-viewport-edge` · `tight-leading` · `skipped-heading` · `justified-text` · `tiny-text` · `all-caps-body` · `wide-tracking` · `text-overflow` · `clipped-overflow-container`.

¹ a11y-contrast rules (`low-contrast`, `gray-on-color`) — reject-eligible (see §4 verdict authority); the rest default advisory.

### Layer 1 — token-discipline (normalized, adapter-resolved)
The same normalized rule — **"use a design-system token, not a raw value"** — expressed against each adapter's surface. The **2 reconciled** impeccable rules live here (they flip per adapter), plus the NEW raw-value family:

- **`bounce-easing`** (impeccable slop) → fires under Tailwind + Vuetify; **suppressed** under MD3 (spring) + Quasar (Animate.css). [reconciliation]
- **`gpt-thin-border-wide-shadow`** (impeccable slop) → fires under `none`; **suppressed** under every adapter with an elevation system (all 4). [reconciliation]
- **`raw-color-literal`** (NEW) → raw `#hex`/`rgb()` where a color-role token exists; resolved per adapter (`bg-[#…]` Tailwind / `color:#…` vs `$primary` Quasar / hardcoded vs `rgb(var(--v-theme-*))` Vuetify / vs `--md-sys-color-*` MD3). KEPT everywhere.
- **`raw-radius`** / **`raw-spacing`** (NEW) → arbitrary radius/spacing where a scale token exists; defers to the stack's shape/spacing tokens.

### Layer 2 — adapter conformance (per-adapter, fires only for the detected stack)
NEW rules from each profile's `conformanceRules` ([`framework-profiles.md`](framework-profiles.md)). Fire **only** when `stack.primary`/`secondary` matches:

- **tailwind:** `legacy-v3-class` (`bg-gradient-to-*`→`bg-linear-*`, scale shifts, `bg-[--var]`→`bg-(--var)`, `!flex`→`flex!`, `@tailwind`→`@import`), `apply-overuse` (advisory), `arbitrary-value-where-token-exists`.
- **tailwind-md3:** all tailwind rules **+** `md3-role-conformance` (raw color vs `--md-sys-color-*`), `md3-typescale-conformance`, `md3-corner-conformance`, `md3-elevation-conformance` (levels 0–5; prefer tonal `surface-container-*`), `md3-theme-bridge-present`.
- **vuetify:** `hardcoded-color-in-component` (exempt theme `colors{}`), `important-override` (fighting component defaults — KEEP), `v4-rgba-theme-var-syntax` (→ `color-mix()`), variant-gated elevation ceiling.
- **quasar:** `inline-hex-outside-variables-scss`, `color-outside-brand-palette`, `quasar-tailwind-coexistence` (the §incompat WARNING), prescribed-class conformance (type/shape/elevation).

---

## 3. Registry record shape

Design rules are `check-registry.json` rows under a **new `pillar: "design"`**, extending the existing field contract with **two new fields** — `layer` and `adapter`:

```jsonc
{
  "id": "design-gradient-text",          // design-<impeccable-id> for vendored; design-<slug> for new
  "name": "Gradient text",
  "lane": "deterministic",                // the detector engine. design-critic rows are lane:"semantic"
  "pillar": "design",                     // NEW pillar
  "layer": 0,                             // NEW: 0 universal | 1 token-discipline | 2 adapter-conformance
  "adapter": "universal",                 // NEW: universal | tailwind | tailwind-md3 | vuetify | quasar
  "base_confidence": 0.9,                 // deterministic detector ~0.6–1.0
  "severity": "P3",                       // slop → P3 advisory; a11y-contrast → P2
  "verdict_authority": "advisory",        // derived: deterministic AND P0/P1/P2 → reject; else advisory
  "detection": {
    "type": "ast",                        // ast(static-html) | command(browser/visual) | regex
    "command": "node cli/engine/detect.mjs --json --rule gradient-text <targets>"
  },
  "enforcement": ["skill:review --pillar design", "hook:post-edit-design (optional)"],
  "owner": "impeccable",                  // provenance
  "consolidated_target": "both",          // review (precision) + audit (recall, --pillar design)
  "escape_hatch": "intentional brand system, documented in DESIGN.md",
  "reconciliation": null,                 // NEW (Layer 1 only): { relaxFor: ["tailwind-md3","quasar"], cite: "..." }
  "source": "impeccable@2.3.2 registry/antipatterns.mjs#gradient-text (re-grounded)"
}
```

**Representative records (one per layer/adapter):**

| id | layer | adapter | severity / authority | reconciliation |
|---|---|---|---|---|
| `design-gradient-text` | 0 | universal | P3 / advisory | — |
| `design-low-contrast` | 0 | universal | P2 / **reject** (a11y) | — |
| `design-bounce-easing` | 1 | universal | P3 / advisory | `relaxFor: [tailwind-md3, quasar]`, cite M3 Expressive spring / Animate.css |
| `design-ghost-card` | 1 | universal | P3 / advisory | `relaxFor: [tailwind, tailwind-md3, vuetify, quasar]`, cite elevation systems |
| `design-raw-color-literal` | 1 | universal | P3 / advisory | resolved per adapter; never relaxed |
| `design-tw-legacy-v3-class` | 2 | tailwind | P3 / advisory | — |
| `design-md3-role-conformance` | 2 | tailwind-md3 | P3 / advisory | — |
| `design-vuetify-important-override` | 2 | vuetify | P3 / advisory | — |
| `design-quasar-tailwind-coexist` | 2 | quasar | P1 / **reject** (build conflict) | — |

`detector_count` in the registry header gains a `design` block: `{ catalogued: 41 (vendored L0/L1) + N (new L2), by_layer: {0:39, 1:4, 2:N}, by_adapter: {...} }`.

---

## 4. Firing logic (the stack-gate)

A design rule fires iff:

```
fires(rule, stack) :=
   rule.lane == "deterministic"
   AND rule.adapter ∈ ( {"universal"} ∪ {stack.primary} ∪ stack.secondary )
   AND NOT ( rule.reconciliation AND stack.primary ∈ rule.reconciliation.relaxFor )
   AND ( rule.adapter != "tailwind" OR "quasar" ∉ stack.incompatibilities-as-primary )   // no TW color rules under Quasar
```

- **Layer 0** (`adapter: universal`, `reconciliation: null`) → always fires. No false positives across stacks because they're stack-independent by construction.
- **Layer 1 reconciled** → fires unless the detected primary is in `relaxFor`. `bounce-easing` fires on Tailwind/Vuetify, suppressed on MD3/Quasar. Every `relaxFor` carries a `cite` (the prescription) per the [`normalized-model.md`](normalized-model.md) §4 contract — a bare relax is rejected at registry-lint.
- **Layer 2** → fires only when its `adapter` matches the detected stack. A Quasar rule never fires on a Tailwind project. The Vuetify-secondary case suppresses tailwind **color** rules (Vuetify owns color) but keeps tailwind layout/legacy rules.

**Verdict authority** (derived, per existing registry contract): deterministic AND severity ∈ {P0,P1,P2} → `reject`; else `advisory`. Design is **advisory by default** (aesthetic judgment shouldn't hard-block a merge) with two reject-eligible classes: **a11y-contrast** (`low-contrast`, `gray-on-color` → P2) and **build-breaking** (`quasar-tailwind-coexist` → P1). This matches the registry's verdict-flip asymmetry: facts (a11y failure, build conflict) can flip a gate; taste (gradient text) only annotates. Because the derivation makes any deterministic P2 a `reject`, advisory design rules are pinned at **P3**; P2/P1 are reserved for the two reject-eligible classes. Enforced by `hooks/scripts/check-registry-validate.sh`.

---

## 5. Engine → detection mapping; the two lanes

| impeccable engine | registry `detection.type` | lane | notes |
|---|---|---|---|
| `static-html` (jsdom) | `ast` | deterministic | the default — static, fast, no browser |
| `regex` | `regex` | deterministic | source-pattern rules |
| `visual` (computed contrast) | `command` | deterministic | WCAG contrast; `low-contrast`/`gray-on-color` |
| `browser` (Puppeteer) | `command` | deterministic | render-dependent; URL targets; heavier/opt-in |
| **design-critic** (vision agent) | `semantic` | **semantic** | screenshots → 5-dim score; the aesthetic-judgment lane |

The deterministic lane is **zero-FP, no-LLM** (registry Pillar A definition). `design-critic` ([`agents/design-critic.md`](../../../agents/design-critic.md)) stays as the semantic lane and is now **backed by** the adapter-aware deterministic lane: deterministic catches mechanical tells (gradient-text, legacy classes, raw literals) at author-time; design-critic judges what only vision can (does it look generic?). Same complementarity as review (precision) vs audit (recall).

---

## 6. Selection by review / audit

- **`/blitz:review --only design`** (or design rows auto-selected when changed files are `.vue/.css/.scss`): deterministic Layer 0/1/2 filtered by the detected `stack`, FP-verified, `--min-confidence high`. Precision tempo.
- **`/blitz:audit --pillar design`**: recall tempo — all design rows ranked, aggregated; `design-critic` invoked on rendered screenshots as the semantic aggregator. `coverage_boundary` notes which adapters/engines ran (e.g., browser engine skipped if no dev server).
- Both select via the firing logic (§4). Layer 0 always; Layer 1/2 by stack. No design rule fires on a stack it doesn't apply to.

---

## 7. Build sequence (for the implementation sprint)

1. Add `design` to the registry `pillar` enum + the `layer`/`adapter`/`reconciliation` fields to `field_contract`.
2. Vendor the 39 Layer 0 rules as `design-*` rows (`adapter: universal`, provenance `source:`), Apache-2.0 marked.
3. Add the 4 Layer 1 rows (2 reconciled + raw-value family) with `reconciliation` blocks.
4. Add Layer 2 rows per adapter from the profiles.
5. Extend `detect.mjs`/`context-signals.mjs` with the `stack` probe ([`adapter-detection.md`](adapter-detection.md)).
6. Wire `/blitz:review --only design` + `/blitz:audit --pillar design` selection.

---

## Acceptance (grep-checkable)

- 41 impeccable rules accounted for: 39 Layer 0 + 2 reconciled Layer 1.
- New `pillar: "design"` + `layer` + `adapter` + `reconciliation` fields specified with a concrete record + 9 representative rows.
- Firing logic gates by `adapter ∈ {universal} ∪ stack`; reconciled rules suppress on `relaxFor`; every relax cites a prescription.
- Verdict: advisory default; a11y-contrast + build-conflict reject-eligible.
- 4 engines mapped to `detection.type`; deterministic lane no-LLM; `design-critic` = semantic lane, retained.
- `bounce-easing` fires Tailwind/Vuetify, suppressed MD3/Quasar — the cross-stack-FP test.
