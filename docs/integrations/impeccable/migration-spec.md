# Migration Spec — absorbing the design pillar into Blitz

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0). Original Blitz authorship. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** doc #6 of 8. Disposition of every Blitz design-surface overlap: retire (with coverage proof), reconcile (adapter-aware), update (orchestrator + quality-matrix). Conformance checklist + merge gate.

---

## 1. Overlap map (disposition table)

| Blitz artifact | Lines | Disposition | Rationale |
|---|---|---|---|
| `skills/_shared/frontend-design-heuristics.md` | 122 | **RETIRE** (coverage-proven §2) | superseded by normalized-model + references-regrounded + Layer 0 detector + design-critic |
| `skills/ui-build/SKILL.md` | 409 | **RECONCILE** (adapter-aware §3) | already stack-aware (`detect-stack.sh` + UI Framework Variants); redirect aesthetic refs, delegate inline gates to design pillar |
| `skills/ui-audit/SKILL.md` | 176 | **KEEP** (clarify boundary §4) | runtime cross-page/cross-role — distinct tempo+mechanism from the static design pillar |
| `skills/design-extract/SKILL.md` | 189 | **RECONCILE** (adapter-aware §5) | already detects CSS framework; emit adapter-resolved tokens; redirect heuristics refs |
| `agents/design-critic.md` | 108 | **KEEP + rewire** (§6) | the semantic/vision lane; redirect heuristic source #2; stack-aware scoring |
| `skills/_shared/quality-matrix.md` | 91 | **UPDATE** (§8) | add the `design` pillar surface |
| `agents/orchestrator.md` §2 | — | **UPDATE** (§7) | route design-pillar commands |
| `skills/_shared/check-registry.json` | — | **EXTEND** (detector-rebuild §3) | new `design` pillar + `layer`/`adapter`/`reconciliation` fields |

**No new skill is added.** Per the quality-matrix four-question test, design folds into `/blitz:review --only design` (precision) + `/blitz:audit --pillar design` (recall) — a flag/pillar, not an 8th skill.

---

## 2. Retire `frontend-design-heuristics.md` — coverage proof

The file (122 lines, 9 sections + a NEVER list) retires only if every section has a new home. It does:

| heuristics § | Content | Covered by |
|---|---|---|
| §1 Core principle (intentionality) | normalized-model §1 + references-regrounded §0/§2 (color strategy) |
| §2 Aesthetic-decision (13-tone list) | **relocated** → references-regrounded §8 (register aesthetic lanes); the canonical 13-tone enum moves there |
| §3 Typography | references-regrounded §1 |
| §4 Color | references-regrounded §2 |
| §5 Motion | references-regrounded §4 |
| §6 Composition | references-regrounded §3 + §8 |
| §7 NEVER list (8 auto-fail) | Layer 0 detector: `gradient-text` (purple-on-white), `overused-font` (Inter/Roboto), `ai-color-palette` (default Tailwind palette), `border-accent-on-rounded`/over-round (all-rounded), `identical-card-grids` (cookie-cutter grid), `numbered-section-markers`/`repeated-section-kickers`, + design-critic dim 2.5 (all-centered, shadcn-defaults, same-design-3×) |
| §8 Dense info display | references-regrounded §3 (density mode) + product register |
| §9 Acceptance signals (5 dims) | `agents/design-critic.md` §2 (owns the 5-dimension score) |

**Consumers to redirect before deletion** (grep `frontend-design-heuristics`):
1. `agents/design-critic.md` §1 heuristic-source #2 → `references-regrounded.md` (+ DESIGN.md still #1).
2. `skills/design-extract/SKILL.md` §Resources, Phase 3 (tone inference §2), Phase 4 (NEVER list §7) → `references-regrounded.md` §1/§8.
3. `skills/ui-build/SKILL.md` §3.0.2 (via design-extract) → already has the 13-tone list **inline** in §3.0.1 (keep); §3.0.2 DESIGN.md handoff unchanged.

**Coverage gate:** `grep -rl "frontend-design-heuristics" skills/ agents/` returns empty before `git rm`. Retirement PR fails CI if any reference remains.

---

## 3. Reconcile `ui-build` (adapter-aware)

ui-build is already the most stack-aware skill (`detect-stack.sh` in Project Context; UI Framework Variants for Tailwind/Quasar/Vuetify). Changes:

- **Phase 1.1 / 3.0:** consume the `stack` signal ([`adapter-detection.md`](adapter-detection.md)) instead of ad-hoc Glob — research the *detected* stack's token surface + components (the pattern-research becomes adapter-resolved).
- **Phase 3.0.1/3.0.2:** redirect the aesthetic-direction refs to [`references-regrounded.md`](references-regrounded.md) + [`normalized-model.md`](normalized-model.md); keep the inline 13-tone list.
- **Implementation Gate:** the inline grep gates (banned fonts, hardcoded colors, `prefers-reduced-motion`) **delegate to `/blitz:review --only design`** (Layer 0/1 rows) — single source of truth, adapter-resolved (e.g., "hardcoded color" resolves to `raw-color-literal` per the detected stack; Quasar's `bg-primary` is not flagged).
- **UI Framework Variants:** map 1:1 to the adapter profiles; cite [`framework-profiles.md`](framework-profiles.md) rather than restating.

No phase removed; ui-build stays the generator, now backed by the shared design pillar instead of its own inline rules.

---

## 4. Keep `ui-audit` — boundary with the design pillar

`ui-audit` is **runtime, cross-page, cross-role** (browser value-registry + Phase 5 HEURISTICS). The design pillar is **static source + vision**. The four-question test (quality-matrix):

| | ui-audit | `audit --pillar design` |
|---|---|---|
| Scope | rendered pages × roles | source files |
| Tempo | loop/nightly cross-page | per-change / pre-release |
| Mechanism | Playwright runtime + registry | static AST/regex + screenshot vision |
| Domain | data-consistency + UX heuristics | design-system conformance + slop |

**Distinct on all four → both coexist** (ui-audit stays an orthogonal-domain skill). **Dedupe the pattern, not the tempo:** ui-audit Phase 5's a11y checks (contrast, reduced-motion) should cite the registry's `design-low-contrast` / `design-*` rows as the canonical detection, running them at *runtime* — the rule lives once in the registry, ui-audit and the static detector are two enforcement sites. Resolves the spec's "ui-audit vs audit": no merge; shared registry rows, different lanes.

---

## 5. Reconcile `design-extract` (adapter-aware)

- **Phase 1 source detection** already classifies Tailwind/Quasar/Vuetify/vanilla → upgrade to the `stack` signal (incl. variant: Tailwind v3/v4, Vuetify v3/v4/v0, MD3 markers).
- **Phase 2 token extraction** → emit **adapter-resolved** tokens: `@theme` vars (Tailwind), `--md-sys-*` (MD3), `createVuetify` `colors{}` (Vuetify), `quasar.variables.scss` `$vars` (Quasar) — DESIGN.md gains a `## Stack` section naming the adapter + variant.
- **Phase 3/4 refs** (tone §2, NEVER §7) → [`references-regrounded.md`](references-regrounded.md).
- DESIGN.md stays the brand↔implementation handoff; now carries the adapter so ui-build/design-critic read the same stack.

---

## 6. Keep + rewire `design-critic`

- Stays the **semantic/vision lane** (5 dimensions, screenshot-based). Unchanged scoring contract.
- Heuristic source priority: DESIGN.md (#1) → **`references-regrounded.md`** (#2, was frontend-design-heuristics) → ui-build §3.0.1 inline (#3).
- **Stack-aware scoring (new):** read the `stack` signal so dimension 2.5 (Creative Distinction) doesn't penalize *framework-prescribed* Material sameness on a Quasar/Vuetify/MD3 app the way it penalizes a bespoke page — the bar is "generic *within the stack's idiom*," and the deterministic Layer 2 conformance lane now backs it.

---

## 7. Orchestrator §2 routing updates

Add to `agents/orchestrator.md` §2 routing table:

| Intent | Route |
|---|---|
| "design slop", "AI-aesthetic tells", "design review of this change" | `/blitz:review --only design` |
| "comprehensive design audit", "design-system conformance" | `/blitz:audit --pillar design` |

- Note the design pillar is **stack-aware**: Layer 0 universal slop runs on any frontend; Layer 1/2 conformance gated by the detected adapter. Keep ui-build/ui-audit/design-extract Vue-conditional (already §59).
- `design-extract` stays in the "single-file/no-spawn" inline-capable list (§48).

---

## 8. Update `quality-matrix.md`

- **TL;DR symptom table:** add `"AI-aesthetic tells / design slop"` → `/blitz:review --only design`; `"design-system conformance / full design audit"` → `/blitz:audit --pillar design`.
- **Two consolidated entry points:** note both gained a `design` pillar (deterministic Layer 0/1/2 + semantic `design-critic`).
- **Orthogonal domains:** keep `ui-audit` (runtime cross-page) — add a one-line "vs design pillar (static+vision)" disambiguation.
- **Agents table:** `design-critic` already listed; note it's the design pillar's semantic lane.
- **Authoring guidance:** the design pillar is the worked example of "prefer a `--only`/`--pillar` flag over a new skill."

---

## 9. Conformance checklist (Blitz cohesion)

- [ ] No new SKILL.md (design folds into review/audit flags) → `skill-frontmatter-validate.sh` scope unchanged.
- [ ] If any vendored impeccable prose lands in a `references/*.md`, it carries the OUTPUT STYLE snippet + ≤500-line body + `/_shared/` citations + Apache-2.0 `source:` marking.
- [ ] `docs/integrations/impeccable/*.md` are spec docs (not skills) — exempt from frontmatter lint; subject to `markdown-link-validate.sh` (internal links relative; external research URLs de-linked per the prior `docs/_research` CI fix).
- [ ] Registry extension passes the registry derivation check (verdict_authority derivable; `reconciliation.cite` present for every relax).
- [ ] `grep -rl frontend-design-heuristics skills/ agents/` empty before deletion.
- [ ] `ATTRIBUTION.md` present + complete (merge-blocking, §11).

---

## 10. Out of scope (this pass)

Implementation (registry rows, `stack` probe code, skill edits, file deletion) is the follow-up sprint behind Blitz's gates ([`SYNTHESIS.md`](SYNTHESIS.md) sequences it). This doc specifies *what* changes and *why*; the sprint does it under sprint-review's 8-invariant gate.

---

## Acceptance (grep-checkable)

- 8 Blitz artifacts each have an explicit disposition (retire/reconcile/keep/update/extend).
- frontend-design-heuristics.md coverage table maps all 9 sections + names the 3 consumers to redirect.
- ui-audit kept with a four-question boundary vs the design pillar; "dedupe pattern not tempo" stated.
- ui-build/design-extract reconciliations are adapter-aware and cite the spine docs.
- orchestrator + quality-matrix edits enumerated.
- No new skill; design = review/audit flags. ATTRIBUTION merge gate referenced.
