# findings-confirmed.md — re-verification against live v2.1.0

Tree state: `git HEAD e8f1d18` (`chore(release): v2.1.0`). All evidence below was reproduced 2026-05-30 against the working tree. Each finding is marked **CONFIRMED**, **CONFIRMED (premise corrected)**, or **DROPPED**, with the exact command + output that demonstrates it.

Method note: there is **no root `package.json`** — the only one is `installer/package.json`. The registry lives at `skills/_shared/check-registry.json`. A manual impeccable checkout exists at `/tmp/impeccable-src` (this is what `gen-design-rows.mjs` defaults to). `npx --no-install impeccable` fails (`missing packages … impeccable@2.3.2`) — impeccable is not installed anywhere in the project.

---

## Finding 1 (CRITICAL) — undeclared hard dependency, silent no-op — **CONFIRMED**

**Claim.** The `command`-type design rows shell out to `npx impeccable detect …`, but impeccable is not declared, not installed, and not preflighted; on a clean checkout the lane silently produces nothing and `--only design` returns green.

**Evidence.**
- impeccable not declared: no root `package.json` exists; `installer/package.json` does not list it.
  ```
  $ find . -name package.json -not -path "*/node_modules/*"
  ./installer/package.json
  ```
- impeccable not installed / not resolvable:
  ```
  $ npx --no-install impeccable --version
  npm error npx canceled due to missing packages and no YES option: ["impeccable@2.3.2"]
  ```
- No preflight / availability check anywhere in `scripts/detect-stack.sh` (132 lines): grep for `impeccable|preflight|UNAVAILABLE|command -v|which |npx` → **zero matches**.
- Non-reproducible source path: `scripts/maint/design/gen-design-rows.mjs:24` defaults the impeccable antipatterns path to `'/tmp/impeccable-src/cli/engine/registry/antipatterns.mjs'`.

**Verdict. CONFIRMED — and slightly worse than stated:** impeccable is not present at *any* version (not 2.3.1, not 2.3.2). A clean checkout has no detector at all. The lane is 100 % dependent on a manual `/tmp` checkout that exists only on this machine.

---

## Finding 2 (HIGH) — rows mislabeled `lane: deterministic` but paid + semantic — **CONFIRMED (premise corrected, defect is broader)**

**Claim (as written).** "The only two `command`-type design rows — `design-bounce-easing` and `design-gpt-thin-border-wide-shadow` — invoke `--gpt --gemini` … both carry `lane: deterministic`."

**What actually reproduces.**

1. There are **42** `command`-type design rows, **not two**. Every one of the 57 design rows is tagged `lane: deterministic`:
   ```
   total design rows: 57
   by detection.type: Counter({'command': 42, 'regex': 15})
   by lane: Counter({'deterministic': 57})
   ```
   All 42 command rows share the identical invocation `npx impeccable detect --json --gpt --gemini ${TARGETS}` (verified at registry lines 710, 736, 762, 788, 814, 840 … through the whole vendored block).

2. **`bounce-easing` is NOT provider-gated.** In impeccable's source only **4** rules carry a `gated:` field:
   ```
   $ grep -n "gated:" /tmp/impeccable-src/cli/engine/registry/antipatterns.mjs
   gpt-thin-border-wide-shadow   gated: 'gpt'
   repeating-stripes-gradient    gated: 'gpt'
   theater-slop-phrase           gated: 'gpt'
   image-hover-transform         gated: 'gemini'
   ```
   `bounce-easing` (line 94) has `category: 'slop'` and no `gated:` field. The prompt's two-row enumeration is wrong on `bounce-easing`; the correct gated set is `{gpt-thin-border-wide-shadow, repeating-stripes-gradient, theater-slop-phrase, image-hover-transform}`.

3. **The mislabel is systemic, not limited to the gated rows.** All 41 impeccable antipatterns are detected through the **browser** path. `detect-antipatterns-browser.js` is generated from `cli/engine/browser/injected/index.mjs` and is loaded as `<script src=detect-antipatterns-browser.js>` into a rendered DOM. A scan of the static-source detector (`detect-antipatterns.mjs`) returned **zero** rule IDs from the design set, while the browser detector enumerates essentially all of them (`side-tab`, `gradient-text`, `low-contrast`, `line-length`, `gpt-thin-border-wide-shadow`, …). The engine map confirms multiple non-grep engines:
   ```
   RULE_ENGINE_SUPPORT = {
     regex:       Set('source','page-analyzer'),
     'static-html': Set('element','page'),
     browser:     Set('element','page','layout'),
     visual:      Set('visual-contrast'),
   }
   ```

**Verdict. CONFIRMED, premise corrected.** The defect is not "two rows are paid"; it is that **all 42 vendored `command` rows are mistagged `deterministic`**. They require (a) the impeccable npm package, (b) a rendered browser DOM, and (c) for 4 of them, an LLM provider API key. The shared command unconditionally passes `--gpt --gemini`, so even a run that wanted only the non-gated rows demands the provider flags. The only genuinely deterministic design rows are the **15 blitz-authored `regex` rows** (+ the one blitz-authored `command` row `design-quasar-tailwind-coexist`, which is a plain grep, not an impeccable call — see note). The lane taxonomy is corrupted for 42/57 rows.

> Note: `design-quasar-tailwind-coexist` is `detection.type: command` but `owner: blitz`; it does not call impeccable. It belongs with the deterministic regex set, not the vendored browser set.

---

## Finding 3 (HIGH) — L1/L2 regex rules false-positive on token definitions, no scoping — **CONFIRMED (count corrected: 16 rows, not 18)**

**Claim.** None of the L1/L2 rows carry an exclude/allowlist; `raw-color-literal` greps `#[0-9a-fA-F]{3,8}` across all `.vue`/`.css` and fires on the token *definitions* it is meant to protect; several color rules are near-duplicates.

**Evidence.**
- No exclusion field exists on any regex row. The only keys present in every `detection` block are `type` and `command`:
  ```
  detection keys used by regex rows: {'command', 'type'}
  design-raw-color-literal   exclude=None
  design-raw-radius          exclude=None
  … (all 15 regex rows: exclude=None)
  ```
- `design-raw-color-literal` (registry line 1779) command:
  ```
  grep -rnE '#[0-9a-fA-F]{3,8}' ${TARGETS} --include=*.vue --include=*.css --include=*.scss
  ```
  This matches raw hex everywhere — including `@theme` blocks, `tailwind.config.*`, `quasar.variables.scss`, Vuetify theme objects, SVG `fill`, and comments — i.e. the token-authoring surfaces where raw hex is **required**.
- Near-duplicate "raw color in a color context" rules, differing only by adapter tag: `design-raw-color-literal` (universal), `design-tw-arbitrary-color` (tailwind), `design-md3-role-conformance` (tailwind-md3), `design-vuetify-hardcoded-color` (vuetify), `design-quasar-inline-hex` + `design-quasar-color-outside-brand` (quasar). Six overlapping greps that must stay in sync.
- Other unscoped blunt greps confirmed in the regex set: `design-raw-radius` (`border-radius:\s*[0-9]+(px|rem)`), `design-md3-elevation-conformance` / `design-vuetify-important-override` / `design-md3-typescale-conformance` — none have a "is a token in use?" notion.

**Count correction.** The prompt says "18 Layer-1/Layer-2 rows." Actual: **15 `regex` rows + 1 blitz `command` row** (`design-quasar-tailwind-coexist`, L2) = **16** L1/L2 rows. The 18 figure does not reproduce.

**Verdict. CONFIRMED.** Zero exclusions on all 15 regex rows; `raw-color-literal` provably fires on token definitions; six near-duplicate color rules. Count is 16, not 18.

---

## Finding 4 (MEDIUM) — no test coverage for the design-pillar wiring — **CONFIRMED**

**Evidence.**
```
$ ls hooks/tests/
_helpers.bash  audit-detection-roundtrip.bats  blitz-extract.bats
block-destructive-git.bats  block-no-verify.bats  block-test-deletion.bats
$ grep -rln "design" hooks/tests/
(no matches)
```
No design-pillar test exists. Adapter selection (`detect-stack.sh`), layer gating, `reconciliation.relaxFor` suppression, and FP exclusions (which don't exist yet) are all untested.

**Verdict. CONFIRMED.**

---

## Finding 5 (LOW / polish) — consistency + maintenance — **PARTIALLY CONFIRMED (one sub-claim dropped)**

- **Version coherence (2.3.1 vs 2.3.2) — DROPPED.** The prompt claims "the local package is `2.3.1`" while ATTRIBUTION + gen say `2.3.2`. No `2.3.1` reference exists anywhere. ATTRIBUTION.md (lines 17, 39, 52, 54), `gen-design-rows.mjs` (12, 67, 185), and every `source:` field all say `2.3.2`. The version strings are **coherent**. The real issue is upstream of versioning: there is **no installed/declared impeccable package at any version** (folded into Finding 1).
- **Repo-rename fallout — CONFIRMED.** 10 files still reference the old slug `cc-plugin-suite`:
  ```
  installer/src/plugin.js   installer/src/agents.js   installer/src/verify.js
  installer/src/detect.js   CHANGELOG.md   docs/consolidation/review-audit/SYNTHESIS.md  …
  ```
  The `installer/src/*.js` references are **live compatibility code** (intentional dual-key fallback: `cc-plugin-suite@cc-plugin-suite` kept "for compatibility" — `plugin.js:53-82`, `agents.js:12`, `verify.js:27,39`, `detect.js:73`). These are deliberate, not fallout. `CHANGELOG.md` history references are correct-as-history. Action item is narrow: sweep docs/READMEs for stale *URLs/paths*, leave the installer compat shims.
- **`--gpt --gemini` in the shared command — CONFIRMED.** All 42 command rows hard-code the two provider flags; dropping them is required to make any non-gated run key-free (see lane-reclassification.md).

**Verdict. PARTIALLY CONFIRMED.** Version-incoherence sub-claim dropped (strings agree); repo-rename and provider-flag sub-claims confirmed (with the installer shims reclassified as intentional).

---

## New finding (surfaced during verification)

**N1 (HIGH) — the entire vendored detector is browser-rendered, so "deterministic" is wrong even after dropping `--gpt --gemini`.** Removing the provider flags fixes the *4 gated* rows but the remaining 38 still require the impeccable package **and a rendered DOM** (`detect-antipatterns-browser.js`). A truly key-free, browser-free deterministic design lane can only be built from static CSS/text approximations (grep/AST) of the slop tells — not from `npx impeccable detect` at all. This reframes Finding 2's fix: reclassify the vendored rows to `lane: semantic` (they belong with `design-critic`'s rendered-screenshot lane), and *separately* author native static approximations for the subset that is statically expressible. See lane-reclassification.md.

---

## Summary table

| # | Severity | Status | Correction |
|---|---|---|---|
| 1 | CRITICAL | CONFIRMED | impeccable absent at any version, not just unpinned |
| 2 | HIGH | CONFIRMED, premise corrected | 42 command rows (not 2); `bounce-easing` not gated; 4 gated rows are gpt-thin-border / repeating-stripes / theater-slop / image-hover; whole set is browser-rendered |
| 3 | HIGH | CONFIRMED | 16 L1/L2 rows (not 18); 15 regex rows have zero exclusions |
| 4 | MEDIUM | CONFIRMED | — |
| 5 | LOW | PARTIAL | version-incoherence sub-claim DROPPED; installer slugs are intentional shims |
| N1 | HIGH | NEW | vendored lane is browser-rendered, not grep-static |
