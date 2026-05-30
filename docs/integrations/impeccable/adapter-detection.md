# Adapter Detection — the deterministic selector

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0). Original Blitz authorship. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** spine doc #3 of 8. Pairs with [`normalized-model.md`](normalized-model.md) (the model this selector routes). Per-stack signals verified against the four research passes feeding [`framework-profiles.md`](framework-profiles.md).

---

## 1. What it does

A **deterministic, no-LLM** selector that maps project signals → a **primary adapter** (+ optional **secondary** rule sets) → emitted as a `stack` signal the SKILL routing, `/blitz:review`, and `/blitz:audit --pillar design` read. Universal slop (Layer 0) runs regardless; token-discipline (Layer 1) and conformance (Layer 2) rules select by the detected adapter. No cross-stack false positives: a Quasar rule never fires on a Tailwind project because the selector never emits `quasar` for it.

The selector **is** the stack-gate the migration spec calls for: it gates which rules fire.

---

## 2. Where it plugs in

Impeccable already has the mechanism. `skill/scripts/context-signals.mjs` gathers deterministic project signals — `setup` (PRODUCT/DESIGN/register via `context.mjs`), `critique`, `git`, `devServer`, and `scan` (the `.vue/.scss/.css/.tsx/...` targets it would point the detector at). Every probe is best-effort, never throws, and the output is always valid JSON.

The adapter selector adds **one probe** — `stack` — to `gatherSignals()`, honoring that same contract (wrapped, never-throw, valid-JSON-or-empty):

```jsonc
// gatherSignals() return, EXTENDED (new key: stack)
{
  setup: { hasProduct, hasDesign, hasCode, register },
  critique: { latest },
  git: { isRepo, branch, changedFiles, ... },
  devServer: { running, ports },
  scan: { targets, via },

  stack: {                                   // ← NEW
    primary: "quasar" | "vuetify" | "tailwind-md3" | "tailwind" | "none",
    secondary: [ "tailwind", ... ],          // layer-able rule sets the primary does not own
    variant:  { vuetify: "v3"|"v4"|"v0", tailwind: "v4"|"v3" },  // version-sensitive, only when detected
    incompatibilities: [ "quasar+tailwind", ... ],               // flagged conflicts, not clean layering
    signals:  { deps: [...], configFiles: [...], sourceHits: [...] },  // why it decided (auditable)
    confidence: "high" | "medium" | "low"
  }
}
```

Inputs the probe reads (all local, cheap, no network): `package.json` `dependencies`+`devDependencies` (one read), a bounded glob for config-file signatures, and a bounded grep over the already-enumerated `scan.targets` for source signatures. It does **not** run the antipattern detector (that stays opt-in via `detect.mjs`).

---

## 3. Detection table (first-match precedence)

Ordered most-distinctive / most-constraining first. The first adapter whose signal matches becomes `primary`; later matches that can coexist become `secondary` or `incompatibilities`.

| # | Adapter | Sufficient signal (any one, unless noted) | Source |
|---|---|---|---|
| 1 | **quasar** | dep `quasar` (`^2`); `quasar.config.{js,ts}`; `src/css/quasar.variables.scss` (or `.sass`); devDep `@quasar/app-vite` / `@quasar/app-webpack` / `@quasar/vite-plugin` | Quasar 2.19.3 pass |
| 2 | **vuetify** | dep `vuetify` (→ variant by range: `^3`→v3, `^4`→v4) **or** `@vuetify/v0` (→v0); `createVuetify(` in source; `src/plugins/vuetify.{js,ts}`; co-dep `@mdi/font`/`@mdi/js` (corroborating) | Vuetify 3.12.7 / 4.0.8 pass |
| 3 | **tailwind-md3** | `tailwind` detected **AND** any MD3 marker: `--md-sys-*` custom properties in CSS; dep `@material/*` / `material-color-utilities`; an MD3-mapped `@theme` (`--color-primary: var(--md-sys-color-primary)`); `<md-*>` web-component tags | Tailwind v4 pass (MD3 markers) + MD3 pass |
| 4 | **tailwind** | dep `tailwindcss` (→ variant by range: `^4`→v4, `^3`→v3); `@import "tailwindcss"` + `@theme {` (v4) **or** `@tailwind base` + `tailwind.config.{js,ts}` (v3) | Tailwind v4.3.0 pass |
| 5 | **none** | no recognized UI stack → Layer 0 universal slop only; recommend adopting a stack | — |

Precedence rationale: Quasar is **first** because it owns components + theming **and** is Tailwind-hostile (§5) — detecting it early prevents mis-layering. Vuetify is likewise a component+theme authority. `tailwind-md3` precedes bare `tailwind` because MD3 is the stricter ruleset (role conformance) and must win when its markers are present.

---

## 4. Primary vs secondary resolution

Real projects mix utility CSS with a component framework. Rules:

- **Primary** = the component + token authority (owns color roles and ships components). Quasar and Vuetify, when present, are **always** primary — they own theming and components. Tailwind is primary **only** when no component framework is detected.
- **Secondary** = an additional ruleset layered for surfaces the primary doesn't own. Canonical case: **Vuetify (primary) + Tailwind (secondary)** — Tailwind utilities for layout/spacing, but **color stays Vuetify's** (the Tailwind Layer 2 color-conformance rules are *suppressed* under a Vuetify primary; layout/legacy-class rules still apply). The selector emits `secondary: ["tailwind"]` with a `color` carve-out.
- **`tailwind-md3`** is not a primary+secondary pair; it is a single composite adapter (Tailwind surface + MD3 role conformance layered on top).

---

## 5. The Quasar + Tailwind incompatibility (not a secondary)

Verified (Quasar pass): Quasar ships its own complete utility + component CSS and **does not use Tailwind**. Co-installing them is a conflict, not a layering:

- **Class collisions:** `.flex`, `.block`, `.hidden`, `.cursor-not-allowed`, `.order-first`, and other layout/display utilities exist in both with different implementations.
- **Specificity war:** both Quasar and Tailwind v4 emit *unlayered* CSS; neither reliably wins. Quasar component styles override Tailwind utilities on `<q-*>` components (`<q-card class="bg-red-900">` renders Quasar's surface, not Tailwind red).

So when the selector sees `quasar` **and** `tailwindcss` in `package.json`, it emits `incompatibilities: ["quasar+tailwind"]` (a WARNING) — **not** `secondary: ["tailwind"]`. The design pillar must not recommend Tailwind theming on a Quasar project; Quasar's SCSS variables + `setCssVar` are the correct surface.

---

## 6. Sub-variant detection (version-sensitive)

Token surfaces shifted across majors; conformance rules differ, so the selector resolves a `variant`:

| Stack | Variant | Discriminating signal | Rule impact |
|---|---|---|---|
| Vuetify | **v3** | `^3`; `--v-theme-*` vars; `elevation-0..24`; MD2 type classes (`text-h1`); `rgba(var(--v-theme-*), a)` valid | elevation 0–24, MD2 type scale |
| Vuetify | **v4** | `^4` (stable since 2026-02-23); MD3-aligned; `elevation-0..5`; MD3 type classes; `rgba(var(--v-theme-*),a)`→`color-mix()` | elevation 0–5, MD3 type, `color-mix` conformance |
| Vuetify | **v0** | `@vuetify/v0`; `--v0-*` prefix; `createThemePlugin`; **alpha** | distinct ruleset; do NOT apply v3/v4 rules |
| Tailwind | **v4** | `@theme`, `@import "tailwindcss"`, `bg-linear-*`, `bg-(--var)` | v4-idiomatic |
| Tailwind | **v3** | `tailwind.config.js`, `@tailwind base`, `bg-gradient-*` | if found in a `^4` project → legacy-class conformance (Layer 2) |

**Why mandatory, not optional:** the Vuetify research found v3 (3.12.7) and v4 (4.0.8) are *concurrently maintained* — v4 is the new stable, v3 is widely deployed. A selector that doesn't distinguish them would apply elevation-0–24 rules to a v4 project (where the ceiling is 5) and flag valid `color-mix()` usage. Variant detection is load-bearing.

> **Open decision (surfaced at checkpoint):** the originating spec said "Vuetify 3 stable, note v0," decided before v4's stable release was known. `framework-profiles.md` (next phase) must choose the canonical Vuetify profile target: v4-primary (current stable) with v3 + v0 as tracked variants, or keep v3-primary. The selector supports all three regardless; only the profile's *default guidance* depends on the choice.

---

## 7. Detection algorithm (deterministic)

Mirrors `context-signals.mjs` style — wrapped probes, never throws, valid JSON always:

```
function detectStack(cwd, scanTargets):
  pkg   = safeReadJson(cwd/package.json)            // {} on failure
  deps  = {...pkg.dependencies, ...pkg.devDependencies}
  files = safeGlob(cwd, CONFIG_SIGNATURES)          // quasar.config, vuetify plugin, *.css w/ @theme
  src   = safeGrep(scanTargets, SOURCE_SIGNATURES)  // createVuetify(, @import "tailwindcss", --md-sys-*, <q-*>, <md-*>

  for adapter in [quasar, vuetify, tailwindMd3, tailwind]:   // precedence order
     if adapter.matches(deps, files, src):
        primary = adapter.id
        variant = adapter.resolveVariant(deps, src)
        break
  else:
     primary = "none"

  secondary, incompat = resolveLayers(primary, deps, src)    // tailwind-on-vuetify; quasar+tailwind→incompat
  confidence = scoreConfidence(deps, files, src)             // dep+config+source = high; dep only = medium; source only = low

  return { primary, secondary, variant, incompatibilities: incompat, signals: {deps, files, src}, confidence }
```

No network, no LLM, no detector run. Cost ≈ one `package.json` read + a bounded glob + a grep over the already-collected `scan.targets`. Degrades to `{ primary: "none", confidence: "low" }` on any failure — never blocks the signals JSON.

---

## 8. How consumers use the `stack` signal

- **SKILL routing (impeccable setup):** after `context.mjs`, the no-arg path reads `stack` and tailors guidance to the surface (a Quasar project gets `quasar.variables.scss` guidance, not `@theme`).
- **`/blitz:review` / `/blitz:audit --pillar design`:** select registry rows by `lane` + `adapter ∈ {universal} ∪ {stack.primary} ∪ stack.secondary` (with the color carve-out for tailwind-secondary). Layer 0 (`adapter: universal`) always selected.
- **Confidence gates assertion vs suggestion:** `high` → assert the stack; `medium`/`low` → "looks like Vuetify v3 — confirm?" before applying conformance rules. Never silently apply a high-FP-risk conformance pass on a low-confidence detection.

---

## 9. Extensibility — adding a 5th adapter

The selector is **data-driven**: the precedence loop iterates an adapter list; each adapter declares a `{deps, configFiles, sourceSignatures, resolveVariant}` record. To add PrimeVue / Nuxt UI / shadcn-vue / Element Plus:

1. Add a detection record (deps + config + source signatures) at the right precedence slot.
2. Fill the adapter contract ([`normalized-model.md`](normalized-model.md) §4) — all seven facet resolvers + reconciliations.
3. Register Layer 2 rules tagged `adapter:<id>` in the check registry ([`detector-rebuild.md`](detector-rebuild.md)).

No engine change. The precedence list + first-match loop absorb the new row. This is the contract that keeps the spine stable as stacks proliferate.

---

## Acceptance (grep-checkable)

- `stack` signal shape defined: `primary`/`secondary`/`variant`/`incompatibilities`/`signals`/`confidence`.
- 5 precedence rows (quasar → vuetify → tailwind-md3 → tailwind → none), each with a cited research source.
- Quasar+Tailwind emitted as `incompatibilities`, never `secondary`.
- Vuetify {v3,v4,v0} + Tailwind {v3,v4} variant detection specified, with the v4-stable rationale.
- Extends `context-signals.mjs` `gatherSignals()` by exactly one `stack` key, preserving never-throw / valid-JSON.
- Adapter list is data-driven; adding an adapter touches data + registry, not the selector engine.
