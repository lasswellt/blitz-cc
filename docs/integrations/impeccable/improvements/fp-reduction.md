# fp-reduction.md — token-definition exclusions + color-rule consolidation + FP-verify

Addresses **Finding 3 (HIGH)**. The 15 deterministic `regex` rows carry zero exclusions and fire on the token *definitions* they exist to protect. This doc gives the exclusion glob set, the consolidated color rule, the FP-verify hook, and a **measured** before/after on a real fixture (not an assertion).

---

## 1. Measured before/after (real grep run, not assertion)

Fixture (4 files): a `tailwind.config.js`, a `theme.css` with an `@theme` block, a `quasar.variables.scss`, and a `Card.vue` (component usage + a comment + an inline SVG). Raw hex in the first three is **correct** (token definitions); raw hex in `Card.vue`'s template/style is the **real** violation. The comment and SVG `fill` are noise.

**BEFORE** — current `design-raw-color-literal` (`grep -rnE '#[0-9a-fA-F]{3,8}' … --include=*.vue --include=*.css --include=*.scss`):
```
quasar.variables.scss:1  $primary: #1976d2;        ← FP (token def)
quasar.variables.scss:2  $secondary: #26a69a;      ← FP (token def)
theme.css:2  --color-brand: #1a73e8;               ← FP (@theme token def)
theme.css:3  --color-surface: #fafafa;             ← FP (@theme token def)
Card.vue:1  …style="color:#333333"…               ← TRUE positive (usage)
Card.vue:3  .card { background: #eeeeee; }          ← TRUE positive (usage)
Card.vue:4  /* legacy: #abcdef kept */              ← FP (comment)
Card.vue:6  <svg><path fill="#00ff00"/>             ← FP (SVG)
8 reported / 2 true-positive  → FP rate 75% (6/8)
```

**AFTER** — scoped rule (exclusions below):
```
Card.vue:1  …style="color:#333333"…
Card.vue:3  .card { background: #eeeeee; }
2 reported / 2 true-positive → FP rate 0%
```

**Result: 6 false positives eliminated, FP rate 75% → 0%, zero true-positive loss.** Commands and output reproduced in the session that produced this doc; re-runnable via the fixture in design-pillar-tests.md.

Note the `tailwind.config.js` hex was already missed by the current rule (it's `.js`, outside `--include`) — a *recall* gap, not an FP. The scoped rule should add `.js/.ts` config scanning **with** the token-def exclusion so it gains that recall without re-introducing the FP.

---

## 2. The `design.exclude` glob set (shared by all L1/L2 rules)

A single shared exclusion set, applied to every deterministic regex rule via a new `detection.exclude` field. "Literal *outside* the token-definition surface," not "literal anywhere."

```jsonc
"design.exclude": {
  "files": [
    "**/tailwind.config.*",
    "**/quasar.variables.{scss,sass}",
    "**/*.tokens.*",
    "**/vuetify*.{js,ts}",          // createVuetify theme files
    "**/theme.{js,ts}",
    "**/*.stories.*",
    "**/dist/**", "**/*.min.*"      // generated
  ],
  "contentGuards": [
    "@theme",                        // Tailwind v4 token block → skip whole file
    "createVuetify(",                // Vuetify theme object
    "defineTheme("
  ],
  "lineGuards": [
    "^[0-9]+:[[:space:]]*(/\\*|//|\\*)",                 // comment lines
    "<(svg|path|rect|circle|polygon|stop)[^>]*(fill|stroke)=" // SVG paint
  ]
}
```

Application order (two-step, proven in §1):
1. **File filter** — drop files matching `design.exclude.files`.
2. **Content guard** — if a surviving file contains any `contentGuards` token, skip it (it is a token-authoring surface).
3. **Line guard** — within remaining files, drop lines matching `lineGuards` (comments, SVG paint).

This is expressible today with `grep -rl … | grep -v <files> | while read f; grep -q <guard> && continue; grep -n … | grep -v <lineGuards>`. Where the FP rate stays high (mixed token+usage files), gate via the detector's AST/selector path instead of a line grep — but the glob+guard set above already takes the fixture to 0% FP.

---

> **APPLIED (FP-1).** `design.exclude` added to the registry; review/audit apply the two-step scoped filter + FP-verify; the 5 duplicate color rules removed and folded into `design-raw-color-literal` (perAdapter + `--include=*.html`). Design rows 65→60, deterministic 24→19. Honest correction to the §3 plan below: only 3 of the 6 were byte-identical greps, but `raw-color-literal` (any hex in .vue/.css/.scss) **subsumes all 5** CSS/inline variants, so all 5 were removed (not just consolidated-with-messaging), with `tw-arbitrary-color`'s unique `*.html` scan absorbed.

## 3. Consolidate the six near-duplicate color rules

Today six rows are "raw color in a color context," differing only by adapter tag:
`design-raw-color-literal` (universal), `design-tw-arbitrary-color` (tailwind), `design-md3-role-conformance` (tailwind-md3), `design-vuetify-hardcoded-color` (vuetify), `design-quasar-inline-hex` (quasar), `design-quasar-color-outside-brand` (quasar).

**Consolidate to one normalized rule** `design-raw-color-literal` with per-adapter `reconciliation`/messaging:
```jsonc
{
  "id": "design-raw-color-literal",
  "adapter": "universal",
  "detection": { "type": "regex", "command": "…shared hex grep…", "exclude": "design.exclude" },
  "perAdapter": {
    "tailwind":     { "cite": "use a theme() color or @theme token, not an arbitrary hex" },
    "tailwind-md3": { "cite": "use an MD3 role token (--md-sys-color-*), not a raw hex" },
    "vuetify":      { "cite": "use a theme color key, not a hardcoded hex" },
    "quasar":       { "cite": "use a Quasar brand color / $primary, not an inline hex" }
  }
}
```
The adapter resolved by `scripts/detect-stack.sh` selects the `perAdapter` message at firing time. One pattern to maintain instead of six. Net registry reduction: −5 rows. (The Quasar-specific *brand-allowlist* check — "hex not in the brand palette" — is genuinely distinct from "any raw hex" and stays as its own rule if it adds signal; the plain inline-hex duplicate folds in.)

Same consolidation principle applies to the radius/spacing/typescale/elevation families where the only difference is the adapter tag — but color is the proven-FP case, so it leads.

---

## 4. Apply v2.0.0 FP-verify to design findings

v2.0.0 made FP-verification mandatory before a finding is reported as a `blocker`. Adapter-gating only prevents *cross-stack* FPs (a Vuetify rule firing on a Tailwind repo); it does nothing for *within-stack* FPs on token files — which is exactly what §1 showed. So design findings must pass the same FP-verify stage:

For each candidate design finding, before reporting:
1. **Re-read the cited line** (`file:line`) in context (±3 lines).
2. **Confirm it is real usage**, not: a token definition (inside `@theme`/config/theme object), a comment, an SVG paint attribute, or a string literal in a non-style context.
3. Only findings surviving (2) are reported; survivors get the row's `base_confidence`, banded into the high/medium/low confidence tiers `review` already uses.

Wiring: `skills/review/SKILL.md` `--only design` and `skills/audit/references/main.md` Phase 1.D2 run design candidates through the existing FP-verify pass (the same one applied to semantic findings), not a separate path. The exclusions in §2 cut the candidate volume *before* FP-verify so the verify stage isn't swamped; FP-verify is the backstop for what the globs can't express.

---

## 5. Per-adapter fixture matrix (recall + precision proof, executed in the test epic)

before/after FP counts to be produced on a real fixture per adapter (Tailwind, Tailwind+MD3, Vuetify v3/v4, Quasar). Each fixture pairs a token-definition file (hex must NOT fire) with a component file (hex MUST fire). The §1 run is the universal/Tailwind+Quasar case (75%→0%). The test epic pastes the remaining adapters' numbers here; design-pillar.bats asserts them so they can't regress.

**Acceptance (grep-based):**
- every `lane: deterministic` regex row has a `detection.exclude` referencing `design.exclude`.
- the six color rules are consolidated to one `design-raw-color-literal` with `perAdapter` (registry row count for color drops by 5).
- `design-pillar.bats` "raw hex inside @theme does NOT fire; same hex in a component DOES" passes.
