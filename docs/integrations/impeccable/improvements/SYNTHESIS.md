# SYNTHESIS.md — sequenced epics for the design-pillar reliability/precision pass

Severity-ordered. Each epic has grep-based acceptance and runs through Blitz's own gates (`sprint-review` Phase 3.6 invariants). The design-pillar tests (`hooks/tests/design-pillar.bats`) become a **permanent gate**. This is a fix-the-implementation pass — the normalized model, adapter abstraction, reconciliation table, Apache-2.0 attribution, and design-critic-as-semantic-lane split are preserved unchanged.

Verified counts that drive the epics (findings-confirmed.md): 57 design rows, all `lane: deterministic`; 42 `command` rows (41 `owner: impeccable` browser-rendered + 1 blitz `detect-stack|grep`); 4 provider-gated (`gpt-thin-border-wide-shadow`, `repeating-stripes-gradient`, `theater-slop-phrase`, `image-hover-transform`); 15 `regex` rows with **zero** exclusions; 0 design tests.

---

## EPIC DEP-1 — Dependency resolution + preflight (CRITICAL) — ✅ APPLIED

**Why first:** the worst outcome is a green design lane that never ran. Until the preflight exists, every other fix sits on a lane that can silently no-op.

**Layer note:** impeccable is a dependency of the **target project under review**, not of the Blitz plugin (its detector is browser/puppeteer-class). The plugin never installs it; the preflight resolves it from the target repo and recommends `npm i -D impeccable@2.3.2` to that project. (dependency-resolution.md §0–1.)

Stories:
1. Add `scripts/design/preflight.sh` (dependency-resolution.md §2) — resolves impeccable **from the target project** (`paths:[TARGET]`); emits `DESIGN_LANE_STATUS deterministic=… semantic=…`; prints `DESIGN_LANE_UNAVAILABLE: <reason + install hint>` to stderr when absent/mismatched; exits 0. **No plugin `package.json` dependency.**
2. Repoint `scripts/maint/design/gen-design-rows.mjs:24` off the `/tmp/impeccable-src` default to a required explicit arg (maintenance-only regen script).
3. Wire preflight into `skills/review/SKILL.md` (`--only design`) and `skills/audit/references/main.md` (Phase 1.D2): run first against the target repo, render lane-status banner, never silent green.
4. `skills/bootstrap` + `skills/setup`: recommend `npm i -D impeccable@2.3.2` to the target project when the design pillar is in use.

Acceptance:
- plugin tree stays clean: `! grep -rq '"impeccable"' --include=package.json .`
- `bash scripts/design/preflight.sh | grep -q '^DESIGN_LANE_STATUS'`
- impeccable absent in target → `bash scripts/design/preflight.sh 2>&1 | grep -q DESIGN_LANE_UNAVAILABLE` (with `npm i -D impeccable` hint).
- `! grep -q '/tmp/impeccable-src' scripts/maint/design/gen-design-rows.mjs`
- `design-pillar.bats` "preflight reports DESIGN_LANE_UNAVAILABLE" un-skips and passes.

---

## EPIC LANE-1 — Lane reclassification (HIGH — fixes the taxonomy) — ✅ APPLIED

Status: 41 vendored rows re-laned `deterministic → semantic`; 8 native deterministic static rules added (all grep, key-free/browser-free, each fires offline); `--gpt --gemini` already stripped (gemini pass). Result: `{ semantic: 41, deterministic: 24 }`, 0 deterministic design rows call npx, `design-pillar.bats` tests 7 & 8 hard-pass. `design-quasar-tailwind-coexist` left `type: command` (its `detect-stack.sh | grep` pipeline is a genuine command, already key-free — the "retype" suggestion was cosmetic).


Stories:
1. Re-lane all 41 `owner: impeccable` rows `deterministic → semantic`. (The `--gpt --gemini` removal from the shared command — `npx impeccable detect --json ${TARGETS}` — is **already applied**; impeccable's providers are never re-added. The 4 gemini/gpt-gated tells route through `design-critic`'s gemini CLI via the critic's `BLITZ_GEMINI_BIN`/`BLITZ_GEMINI_MODEL` env, not impeccable `--gemini`.)
2. Author 8 native blitz deterministic static rules (lane-reclassification.md §2b) — `bounce-easing` (cubic-bezier overshoot), `thin-border-wide-shadow-static`, `repeating-stripes-static`, `gradient-text-static`, `extreme-negative-tracking-static`, `tiny-text-static`, `all-caps-body-static`, `overused-font-static`. All `grep`-only.
3. Run each new rule offline (no impeccable, no keys, no browser) and paste before/after into lane-reclassification.md §3.
4. Retype `design-quasar-tailwind-coexist` consistently (it is already key-free: `detect-stack.sh | grep`).

Acceptance:
- `! jq -e '.. | objects | select(.owner=="impeccable" and .lane=="deterministic")' skills/_shared/check-registry.json` (no impeccable row deterministic).
- `[ "$(jq '[.. | objects | select(.pillar=="design" and .lane=="deterministic") | .detection.command] | map(select(test("npx"))) | length' registry)" = 0 ]`
- `! grep -q -- '--gpt --gemini' skills/_shared/check-registry.json`
- every `pillar==design, lane==deterministic` row's command contains `grep` and not `npx`.
- `design-pillar.bats` lane-integrity tests un-skip and assert hard.

---

## EPIC FP-1 — Token-definition exclusions + color-rule consolidation (HIGH — precision) — ✅ APPLIED

Status: top-level `design.exclude` added (files + contentGuards + lineGuards + appliesTo); review/audit wired to apply the two-step scoped filter + FP-verify. Color rules consolidated honestly — `design-raw-color-literal` **subsumes** the 5 others (it greps any hex in .vue/.css/.scss; the CSS/inline rules were strict subsets), so removed `tw-arbitrary-color` (its unique `*.html` coverage absorbed via `--include=*.html`), `md3-role-conformance`, `vuetify-hardcoded-color`, `quasar-inline-hex`, `quasar-color-outside-brand`. The canonical rule carries `perAdapter` messaging. Design rows 65→60, deterministic 24→19. `design-pillar.bats` adds 3 hard FP-1 tests (exclude set, perAdapter+exclude ref, 5 removals) — all pass. Proven FP 75%→0% on the universal fixture (fp-reduction.md §1).


Stories:
1. Add `design.exclude` glob set (fp-reduction.md §2): file globs (`tailwind.config.*`, `quasar.variables.*`, `*.tokens.*`, Vuetify theme files), content guards (`@theme`, `createVuetify(`), line guards (comments, SVG paint). Reference it from every L1/L2 regex row's `detection.exclude`.
2. Consolidate the six near-duplicate color rules into one `design-raw-color-literal` with per-adapter `perAdapter` messaging (−5 rows). Keep the Quasar brand-allowlist check only if it adds signal beyond "any raw hex."
3. Apply v2.0.0 FP-verify to design findings (re-read cited line; reject token-def/comment/SVG before reporting as blocker).
4. Produce per-adapter before/after FP counts on real fixtures; paste into fp-reduction.md §5.

Acceptance:
- every `pillar==design, lane==deterministic, detection.type==regex` row has `detection.exclude`.
- color rules consolidated (registry color-row count drops by 5).
- `design-pillar.bats` FP-exclusion tests pass (proven 75%→0% on the universal fixture).

---

## EPIC TEST-1 — Permanent design-pillar gate (MEDIUM) — ✅ APPLIED

Status: `detect-stack.sh` now emits a normalized `DESIGN_ADAPTER primary=… variant=… secondary=… incompat=… confidence=…` token (verified across tailwind / tailwind-md3 / vuetify v3+v4 / quasar / quasar+tailwind-incompat / vuetify+tailwind-secondary / none). `design-pillar.bats` grew from 12→**22 tests, all hard-pass, zero skips**: adapter-detection matrix (5), a selection harness mirroring `review --only design` (inclusion map + relaxFor) proving Layer-0-always / Layer-2-gated / reconciliation-suppression. review + audit reworded to parse the token + the inclusion map. The bats suite is wired into `hooks/tests/*.bats` (the CI/sprint-review run) — the permanent design gate.


Stories:
1. `scripts/detect-stack.sh` exposes a parseable design-adapter token (primary + variant + secondary) per `adapter-detection.md`, so tests 1–13 are assertable.
2. Un-skip `design-pillar.bats` adapter-detection + layer-gating tests; add the per-adapter FP fixtures.
3. Register `design-pillar.bats` in the CI/`sprint-review` bats run; FP-exclusion + lane-integrity become Phase 3.6 hard gates.

Acceptance:
- `bats hooks/tests/design-pillar.bats` green with no un-explained skips.
- a regression that re-tags a vendored row `deterministic` or re-introduces a token-file FP fails the suite.

---

## EPIC POLISH-1 — Consistency + maintenance (LOW) — ✅ APPLIED

Status: (1) version coherent — all impeccable refs `2.3.2`; preflight asserts the pin (the 2.3.1 sub-claim was dropped). (2) repo-rename — live config (`installer/install.sh` REPO_URL, `installer/package.json`, `.claude-plugin/plugin.json`) was already `blitz-cc`; fixed the 3 remaining live stale `lasswellt/blitz` refs (the curl install one-liner in `install.sh:7-8` — which 404'd as written — and the user-facing docs link in `installer/src/index.js:369`) → `blitz-cc`. The `cc-plugin-suite@cc-plugin-suite` keys in `installer/src/*.js` are intentional compat shims (left); dated `docs/_research`/`docs/audits` slug refs are historical (left). (3) offline key-free confirmed — `env -u OPENAI_API_KEY -u GEMINI_API_KEY` run of all 18 deterministic regex rows + preflight against a fixture with no impeccable: `deterministic=OK semantic=ABSENT (loud)`, 5 rows fired, **zero npx/network**.


Stories:
1. Confirm version coherence (all `2.3.2` — already coherent per findings §5; preflight asserts the pin). The 2.3.1 sub-claim was dropped.
2. Repo-rename sweep: docs/READMEs for stale `cc-plugin-suite` **URLs/paths** only. **Do not touch** `installer/src/*.js` — those `cc-plugin-suite@cc-plugin-suite` keys are intentional dual-key compat shims (`plugin.js:53-82`, `agents.js:12`, `verify.js:27,39`, `detect.js:73`). CHANGELOG history stays.
3. Confirm post-LANE-1 a `--only design` deterministic run is key-free: `env -u OPENAI_API_KEY -u GEMINI_API_KEY` run completes with impeccable uninstalled.

Acceptance:
- `! grep -rn 'cc-plugin-suite' docs/ README.md 2>/dev/null | grep -v CHANGELOG | grep -iE 'http|github.com/.*cc-plugin-suite'`
- deterministic design run passes offline with no API keys (pasted output).

---

## Sequence + gate summary

```
DEP-1 (preflight, never silent green)
  → LANE-1 (42 rows reclassified, deterministic set proven offline)
    → FP-1 (token-def exclusions, color consolidation, FP-verify; 75%→0% proven)
      → TEST-1 (design-pillar.bats becomes permanent Phase 3.6 gate)
        → POLISH-1 (slug sweep, offline key-free confirmation)
```

Each epic is gated by `sprint-review` Phase 3.6 (8 invariants incl. ratchet + critic LGTM). After TEST-1, `design-pillar.bats` is itself a permanent invariant: the suite runs on itself, and the design lane can no longer silently no-op, mislabel a paid/browser row as deterministic, or cry wolf on a token file without the gate catching it.

---

## What this pass deliberately did NOT do

- No redesign of the normalized model / adapters / reconciliation table (validated clean).
- No edits to the Apache-2.0 attribution (rigorous).
- No implementation — this is confirmed findings + specs + the test file. Implementation is the epics above, behind Blitz's gates, with `design-pillar.bats` added as a gate.
