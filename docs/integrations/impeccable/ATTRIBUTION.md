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

**`source:` tag convention** — every vendored registry row / reference file carries:
```
source: impeccable@2.3.2 <relative-path>#<rule-id> (re-grounded, framework-adaptive)
```
e.g. `source: impeccable@2.3.2 cli/engine/registry/antipatterns.mjs#gradient-text (re-grounded, framework-adaptive)`. The 39 Layer 0 rows are vendored-with-modification (re-tagged, re-fielded); the Layer 1/2 rows are new Blitz authorship inspired by impeccable's `conformanceRules` discipline.

---

## 4. NOTICE reproduction (impeccable `NOTICE.md`, verbatim)

```
Impeccable
Copyright 2025-2026 Paul Bakaus

## Anthropic frontend-design Skill
The `impeccable` skill in this project builds on Anthropic's original frontend-design skill.
Original work: https://github.com/anthropics/skills/tree/main/skills/frontend-design
Original license: Apache License 2.0
Copyright: 2025 Anthropic, PBC
This project extends the original with:
- 7 domain-specific reference files (typography, color-and-contrast, spatial-design, motion-design, interaction-design, responsive-design, ux-writing)
- 23 commands
- Expanded patterns and anti-patterns

## Typecraft Guide Skill
The `typography.md` reference incorporates tactical additions merged in from ehmo's `typecraft-guide-skill`
at the author's request: dark-mode weight/tracking compensation, font-display optional vs swap,
preload-critical-weight-only, variable fonts for 3+ weights, clamp() ratio bound, responsive measure,
text-wrap balance/pretty, font-optical-sizing auto, ALL-CAPS tracking, paragraph-rhythm rule.
Original work: https://github.com/ehmo/typecraft-guide-skill
Author: ehmo
```

> Note: impeccable's own NOTICE describes its prior "7 domain reference" structure. The live `2.3.2` tree has refactored these into verb-command references (see [`references-regrounded.md`](references-regrounded.md) §0); the NOTICE is reproduced as-is per §4(d) (retain notices verbatim) — the structural drift is documented separately, not by editing the upstream NOTICE.

---

## 5. Merge gate (checklist)

A vendoring PR merges only when **all** are true:

- [ ] `docs/integrations/impeccable/LICENSE-APACHE-2.0.txt` present (verbatim Apache-2.0).
- [ ] This `ATTRIBUTION.md` present + §1 chain complete (all 3 upstreams).
- [ ] Every vendored-and-modified file carries the §3 header notice.
- [ ] Every vendored registry row carries a `source:` tag (§3).
- [ ] §4 NOTICE reproduced verbatim.
- [ ] Blitz MIT `LICENSE` unchanged; no upstream copyright stripped.

Wire this as a CI check (`grep`-based: source-tag presence on `design-*` rows; `LICENSE-APACHE-2.0.txt` existence) in the implementation sprint.

---

## Acceptance (grep-checkable)

- 3-upstream chain with license + copyright + URL each.
- Apache §4 (a)/(b)/(c)/(d) each explicitly addressed.
- Substantial-modification statement + header-notice template + `source:` tag convention.
- NOTICE reproduced verbatim.
- Merge-gate checklist; MIT/Apache interaction stated.
