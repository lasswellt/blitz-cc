# ATTRIBUTION — Apache-2.0 provenance chain (MERGE-BLOCKING)

> **This file blocks merge.** Vendoring Apache-2.0 work into MIT-licensed Blitz is permitted **only** if the Apache-2.0 §4 redistribution conditions below are satisfied. A PR that adds vendored impeccable/frontend-design/typecraft content without a complete ATTRIBUTION.md + companion license text fails review.

---

## 1. Provenance chain

The Blitz design pillar (specs in `docs/integrations/impeccable/`, and any vendored rules/references the implementation sprint produces) derives from three upstreams, each Apache-2.0 or merged at the author's request:

| Upstream | Work | License | Copyright | URL |
|---|---|---|---|---|
| **impeccable** | design skill: 23 commands, 27 reference files, 41-rule deterministic detector, register model | Apache License 2.0 | © 2025–2026 Paul Bakaus | https://github.com/pbakaus/impeccable |
| **Anthropic frontend-design** | the original frontend-design skill impeccable builds on | Apache License 2.0 | © 2025 Anthropic, PBC | https://github.com/anthropics/skills/tree/main/skills/frontend-design |
| **ehmo typecraft-guide** | tactical typography additions merged into impeccable's `typography` reference | see upstream repo | © ehmo | https://github.com/ehmo/typecraft-guide-skill |

Vendored at **impeccable `2.3.2`** (latest CLI release `cli-v2.3.2`, 2026-05-30). The originating prompt cited `v3.5.0`; the live tree is `2.3.2` — this attribution reflects what was actually read and vendored.

---

## 2. Apache-2.0 §4 conditions — how each is met

Redistribution of Apache-2.0 material requires (License §4):

- **(a) Give recipients a copy of the License.** → A verbatim copy of the Apache License 2.0 **MUST** be vendored at `docs/integrations/impeccable/LICENSE-APACHE-2.0.txt` (copied from the impeccable `LICENSE`). **This file is part of the merge gate** — its absence blocks merge. (Not inlined here; it is the full ~11KB Apache text.)
- **(b) Mark modified files.** → §3 below. Every vendored-and-modified artifact carries a prominent "changed by Blitz" notice + a `source:` tag.
- **(c) Retain notices.** → §1 retains all copyright/attribution notices from the upstreams.
- **(d) Reproduce the NOTICE.** → §4 reproduces impeccable's `NOTICE.md` verbatim.

**License interaction:** Blitz remains MIT-licensed as a whole. The vendored portions (design rules, re-grounded references) **retain Apache-2.0** for those files and carry this NOTICE; MIT and Apache-2.0 are compatible for this direction (Apache-2.0 components may be redistributed within an MIT project provided Apache §4 is honored for those components). Blitz's MIT `LICENSE` is unchanged; this file + `LICENSE-APACHE-2.0.txt` govern the vendored subset.

---

## 3. §4(b) — substantial-modification statement

The re-grounding is a **substantial modification**, not a verbatim copy. Modified artifacts must carry a header notice:

```
> Modified by the Blitz project from pbakaus/impeccable@2.3.2 (Apache-2.0).
> Re-grounded from a single hand-rolled-CSS aesthetic to a framework-adaptive
> model (normalized spine + Tailwind/MD3/Vuetify/Quasar adapters). See ATTRIBUTION.md.
```

**Nature of the modifications** (why "substantial"):
- The single-aesthetic guidance is restructured into a **normalized design model + pluggable framework adapters** (`normalized-model.md`).
- The 41-rule detector is restructured into a **layered, adapter-tagged registry** (Layer 0 universal / Layer 1 token-discipline / Layer 2 conformance) with **per-adapter reconciliation logic** (`detector-rebuild.md`) — new authorship.
- A **deterministic adapter selector** (`adapter-detection.md`) is added (extends impeccable's `context-signals.mjs`).
- References are re-expressed as **normalized core + per-adapter notes** (`references-regrounded.md`).

**`source:` tag convention.** Every vendored registry row carries:
```
source: impeccable@2.3.2 <relative-path>#<rule-id> (re-grounded, framework-adaptive; Apache-2.0, see docs/integrations/impeccable/ATTRIBUTION.md)
```
e.g. `source: impeccable@2.3.2 cli/engine/registry/antipatterns.mjs#gradient-text (re-grounded, framework-adaptive; Apache-2.0, see docs/integrations/impeccable/ATTRIBUTION.md)`. A vendored row is one with `owner: impeccable`, whose detection runs `impeccable detect`. `hooks/scripts/check-registry-validate.sh` requires this tag shape on every such row, requires the version in the tag to match the registry's `attribution.notice`, and recomputes `detector_count.design.vendored` from the rows, so a vendored row cannot land untagged and the count cannot drift. The Layer 0 rows, plus the Layer 1 rows that keep an impeccable rule id (`design-bounce-easing`, `design-gpt-thin-border-wide-shadow`), are vendored-with-modification (re-tagged, re-fielded); the remaining Layer 1/2 rows are new Blitz authorship inspired by impeccable's `conformanceRules` discipline.

**Where the header notice lives.** The registry is the only vendored-and-modified file in the tree (the documents in this directory are Blitz authorship describing the re-grounding), and JSON cannot carry a blockquote, so `skills/_shared/check-registry.json` carries the notice above as one line in its top-level `attribution.notice` field, next to `attribution.license` (the path of the vendored Apache text) and `attribution.upstream` (the pinned tag). The validator fails when the block is missing or the notice stops naming the upstream, the version or the license.

---

## 4. NOTICE reproduction (impeccable `NOTICE.md`, verbatim)

Copied byte for byte from `NOTICE.md` at tag `cli-v2.3.2` (`https://raw.githubusercontent.com/pbakaus/impeccable/cli-v2.3.2/NOTICE.md`, checked 2026-10-12). Re-fetch and re-copy whenever the pinned version changes; never edit the text inside the fence.

```
# Notice

Impeccable
Copyright 2025-2026 Paul Bakaus

## Anthropic frontend-design Skill

The `impeccable` skill in this project builds on Anthropic's original frontend-design skill.

**Original work:** https://github.com/anthropics/skills/tree/main/skills/frontend-design
**Original license:** Apache License 2.0
**Copyright:** 2025 Anthropic, PBC

This project extends the original with:
- 7 domain-specific reference files (typography, color-and-contrast, spatial-design, motion-design, interaction-design, responsive-design, ux-writing)
- 23 commands
- Expanded patterns and anti-patterns

## Typecraft Guide Skill

The `typography.md` reference in this project incorporates a set of tactical additions merged in from ehmo's `typecraft-guide-skill` at the author's request: dark-mode weight/tracking compensation, `font-display: optional` vs `swap`, preload-critical-weight-only guidance, variable fonts for 3+ weights, `clamp()` max-to-min ratio bound, responsive measure/container coupling, `text-wrap: balance` / `pretty`, `font-optical-sizing: auto`, ALL-CAPS tracking quantification, and the paragraph-rhythm rule (space OR indent, never both).

**Original work:** https://github.com/ehmo/typecraft-guide-skill
**Original license:** see upstream repo
**Author:** ehmo
```

> Note: impeccable's own NOTICE describes its prior "7 domain reference" structure. The live `2.3.2` tree has refactored these into verb-command references (see [`references-regrounded.md`](references-regrounded.md) §0); the NOTICE is reproduced as-is per §4(d) (retain notices verbatim) — the structural drift is documented separately, not by editing the upstream NOTICE.

---

## 5. Merge gate (checklist)

A vendoring PR merges only when **all** are true:

- [x] `docs/integrations/impeccable/LICENSE-APACHE-2.0.txt` present (verbatim Apache-2.0): byte-identical to impeccable's `LICENSE` at `cli-v2.3.2` (checked 2026-10-12); CI fails when the file is absent.
- [x] This `ATTRIBUTION.md` present + §1 chain complete (all 3 upstreams).
- [x] Every vendored-and-modified file carries the §3 header notice: the registry carries it in `attribution.notice` (§3, "Where the header notice lives"); the validator fails without it.
- [x] Every vendored registry row carries a `source:` tag (§3): required by `check-registry-validate.sh` on every `owner: impeccable` row; CI fails when the tag count drops to zero.
- [x] §4 NOTICE reproduced verbatim: copied byte for byte from the pinned tag (§4).
- [x] Blitz MIT `LICENSE` unchanged; no upstream copyright stripped: `LICENSE` has not changed since the commit that added this file, and §1 keeps every upstream copyright line.

Wired as CI checks: the `impeccable attribution` step in `.github/workflows/ci.yml` requires `LICENSE-APACHE-2.0.txt` and a non-zero count of `"source": "impeccable@` tags in the registry; `scripts/ci-local.sh` mirrors the step and `hooks/tests/ci-local.bats` fails when the two drift; `hooks/scripts/check-registry-validate.sh` (its own CI step) checks the tag shape, the version pin and the `attribution` block, with `hooks/tests/check-registry-validate.bats` covering each failure mode.

---

## Acceptance (grep-checkable)

- 3-upstream chain with license + copyright + URL each.
- Apache §4 (a)/(b)/(c)/(d) each explicitly addressed.
- Substantial-modification statement + header-notice template + `source:` tag convention.
- NOTICE reproduced verbatim.
- Merge-gate checklist; MIT/Apache interaction stated.
