# lane-reclassification.md — correcting the lane taxonomy for 42 vendored rows

Addresses **Finding 2 (HIGH)** and **N1 (HIGH)**. The registry currently tags all 57 design rows `lane: deterministic`. Verification (findings-confirmed.md §2, §N1) proves 42 of them are browser-rendered and 4 additionally need API keys. This doc gives the corrected classification, the proof that the corrected deterministic set is key-free/browser-free, and the audit of all 55 non-named rows.

---

## 1. Ground truth (from `/tmp/impeccable-src`)

- **Detection engine:** all 41 impeccable antipatterns are served by `cli/engine/detect-antipatterns-browser.js`, a `GENERATED` bundle loaded as `<script src=…>` into a rendered DOM. The static-source detector enumerates none of the design IDs. → impeccable detection is **browser-rendered**, not grep-static.
- **Provider-gated (need `--gpt`/`--gemini` + API key):** exactly 4 — `gpt-thin-border-wide-shadow` (gpt), `repeating-stripes-gradient` (gpt), `theater-slop-phrase` (gpt), `image-hover-transform` (gemini). `bounce-easing` is **not** among them.
- **Shared invocation:** all 42 command rows hard-code `npx impeccable detect --json --gpt --gemini ${TARGETS}` — so the provider flags are passed unconditionally, even though only 4 rows consume them.

**Conclusion.** `lane: deterministic` is false for all 42 command rows. Correct lane = `semantic` (they belong with `design-critic`'s rendered lane). The genuinely deterministic set is the 15 blitz `regex` rows + `design-quasar-tailwind-coexist` (a blitz grep, mis-typed as `command`).

---

## 2. The reclassification

### 2a. Re-lane all 42 vendored rows → `lane: semantic`

For every row with `owner: impeccable`:
- `lane: deterministic` → `lane: semantic`
- gains the semantic-lane treatment already defined in the v2.0.0 consolidation model: **costed**, **aggregated across the rendered run**, **FP-verified** before reporting, confidence-banded.
- the shared command **drops `--gpt --gemini`** → `npx impeccable detect --json ${TARGETS}` (key-free; **applied** in the registry + `gen-design-rows.mjs`). impeccable's own `--gpt`/`--gemini` providers are never invoked. The 4 provider-gated tells are instead judged in the `design-critic` semantic lane via the **critic's gemini CLI** — the same `@google/gemini-cli` binary + `BLITZ_GEMINI_BIN`/`BLITZ_GEMINI_MODEL` env the adversarial critic uses (no new key/provider). When `$BLITZ_GEMINI_BIN` is unavailable those 4 don't fire and the preflight/`coverage_boundary` reports the gap — never silent.

### 2b. Author native static approximations (new `lane: deterministic`, owner `blitz`)

For the subset that is **statically expressible from CSS/text source**, add new blitz `regex`/AST rows so the deterministic lane keeps recall without impeccable. Prioritized by FP-safety and the prompt's two named cases:

| New deterministic rule | Static signal (grep/AST) | Replaces (recall for) |
|---|---|---|
| `design-bounce-easing` (re-author as blitz regex) | `cubic-bezier(` with overshoot (4th param `>1` or `<0`), or `animation-timing-function`/`transition-timing-function` containing `bounce`/`elastic`/`back`/`ease-in-back` | vendored `bounce-easing` (was never gated — pure static win) |
| `design-thin-border-wide-shadow-static` | same CSS rule contains a hairline border (`border…1px`) **and** a wide-blur shadow (`box-shadow` with blur radius ≥ ~24px) | static approximation of gated `gpt-thin-border-wide-shadow` |
| `design-repeating-stripes-static` | `background[-image]?:\s*repeating-linear-gradient` | static approximation of gated `repeating-stripes-gradient` |
| `design-gradient-text-static` | `background-clip:\s*text` + `-webkit-text-fill-color:\s*transparent` (+ a `linear-gradient` background) | vendored `gradient-text` |
| `design-extreme-negative-tracking-static` | `letter-spacing:\s*-0?\.0[5-9]em` or `≤ -1px` | vendored `extreme-negative-tracking` |
| `design-tiny-text-static` | `font-size:\s*(0?\.[0-7]rem|[1-9]px|1[0-1]px)` in body context | vendored `tiny-text` |
| `design-all-caps-body-static` | `text-transform:\s*uppercase` on body/`p` selectors | vendored `all-caps-body` |
| `design-overused-font-static` | `font-family` listing Inter/Roboto/Geist/Fraunces/Plus Jakarta/Space Grotesk as the primary face | vendored `overused-font` |

These are **net-new blitz authorship** (`owner: blitz`, `source: blitz framework-adaptive design pillar`), not edits to the vendored rows. They run with `grep` only — proven key-free/browser-free below.

### 2c. Rows that **cannot** be made deterministic (stay `semantic`, no static twin)

Anything needing computed layout/contrast/network. These remain `lane: semantic` (browser/`design-critic` only): `low-contrast`, `gray-on-color` (computed contrast ratio), `line-length`, `text-overflow`, `clipped-overflow-container`, `cramped-padding`, `monotonous-spacing`, `flat-type-hierarchy` (computed sizes), `nested-cards`, `layout-transition`, `body-text-viewport-edge`, `broken-image` (network), `image-hover-transform` (gemini-gated, hover/render), `theater-slop-phrase` (gpt-gated, semantic text judgment). No deterministic claim is made for these — that is the honest classification.

---

## 3. Proof the corrected deterministic set is key-free + browser-free

Each new deterministic rule (§2b) and each existing regex rule (15) is a `grep -rnE` over source files. To prove offline operability:

- **No network:** `grep` reads local files only; no `npx`, no fetch. Verified by construction — the commands contain no `npx`/`curl`/`http`.
- **No browser:** no `puppeteer`/`<script src>`/DOM; pure text match.
- **No API key:** no `--gpt`/`--gemini`/provider env var.

**Offline acceptance run — APPLIED (LANE-1).** All 8 static rules + the 15 existing regex rows ran with no impeccable installed, no network, no API keys, against a slop fixture. Each of the 8 fired ≥1 (bounce 2, thin-border-wide-shadow 1, repeating-stripes 1, gradient-text 1, neg-tracking 1, tiny-text 1, all-caps 1, overused-font 1):
```
deterministic design rows: 24  (15 regex + 8 new static + 1 detect-stack|grep)
non-grep or npx rows: 0
lane distribution: { semantic: 41, deterministic: 24 }
```
Every deterministic design row's command contains `grep` and not `npx` — proven key-free + browser-free. The 41 vendored rows are now `lane: semantic`; tests 7 & 8 in `design-pillar.bats` flipped from skip to hard-pass.

---

## 4. Audit of all 55 non-named rows for the same defect

Method: for each design row, classify by `owner` + detection engine.

| Group | Count | Current lane | Correct lane | Key-free? | Browser-free? |
|---|---|---|---|---|---|
| Vendored impeccable, non-gated | 38 | deterministic ❌ | **semantic** | yes (after dropping flags) | **no** (browser) |
| Vendored impeccable, provider-gated | 4 | deterministic ❌ | **semantic** | **no** (needs key) | **no** (browser) |
| Blitz regex L1/L2 | 15 | deterministic ✓ | deterministic ✓ | yes | yes |
| Blitz `command` grep (`quasar-tailwind-coexist`) | 1 | deterministic (type:`command`) | deterministic ✓ (retype to `regex`/grep) | yes | yes |

**Finding of the audit:** the defect is not isolated to 2 rows — **42/57 rows are mistagged** (38 browser + 4 browser+key). Every vendored row must move to `semantic`. No blitz-authored row is mistagged. `design-quasar-tailwind-coexist` is correctly deterministic but mis-typed `command`; retype to a regex-style grep entry for consistency.

---

## 5. Registry edits (spec)

For each `owner: impeccable` row (42):
```diff
- "lane": "deterministic",
+ "lane": "semantic",
- "command": "npx impeccable detect --json --gpt --gemini ${TARGETS}",
+ "command": "npx impeccable detect --json ${TARGETS}",
```
The `--gpt --gemini` removal is **already applied** (this pass); the `lane` re-tag is the remaining LANE-1 step. impeccable's providers are never re-added — the gemini-gated tells route through `design-critic`'s gemini CLI (`BLITZ_GEMINI_BIN`/`BLITZ_GEMINI_MODEL`, the critic's env), not impeccable `--gemini`.

Add 8 new `owner: blitz` deterministic rows (§2b). Retype `design-quasar-tailwind-coexist` to the regex-grep form.

**Acceptance (grep-based):**
- `! grep -A20 '"owner": "impeccable"' skills/_shared/check-registry.json | grep -q '"lane": "deterministic"'` — no vendored row stays deterministic.
- `! grep -q -- '--gpt --gemini' skills/_shared/check-registry.json` — provider flags removed from the registry default.
- every `"lane": "deterministic"` row's `detection.command` contains `grep` and not `npx`.
