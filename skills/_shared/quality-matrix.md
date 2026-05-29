# Quality-Skill Decision Matrix

Updated 2026-05-29 (sprint-19 consolidation). The review/audit/quality surface is now **2 consolidated entry points** over a **shared check registry** ([`check-registry.json`](check-registry.json)), plus 2 standalone tools and 5 orthogonal-domain skills. This matrix is the single "which one do I want?" reference.

## TL;DR — pick by your symptom

| Symptom | Skill |
|---|---|
| "Is this change/sprint mergeable?" (per-change gate) | `/blitz:review` |
| "Comprehensive pre-release deep audit; find all tech debt" | `/blitz:audit` |
| "Just the placeholder/stub scan" | `/blitz:review --only completeness` |
| "Just the wiring/orphan-route/auth check" | `/blitz:review --only wiring` |
| "Vue/Firestore/Pinia framework misuse" | `/blitz:review --only framework`, or `/blitz:code-doctor --fix` |
| "Continuous ratchet that only goes forward" | `/blitz:code-sweep` (loop) |
| "Dependency CVEs / licenses" | `/blitz:dep-health` |
| "Bundle size / Lighthouse / runtime perf" | `/blitz:perf-profile` |
| "Cross-page UI consistency / data drift" | `/blitz:ui-audit` |
| "E2E smoke / console errors" | `/blitz:browse` |
| "Quality trend over time" | `/blitz:quality-metrics` |

## The two consolidated entry points

| | `/blitz:review` | `/blitz:audit` |
|---|---|---|
| Scope | one change / sprint | full codebase |
| Tempo | per-change gate | pre-release / quarterly |
| **Bias** | **precision** (low FP — runs constantly) | **recall** (catch everything — runs rarely) |
| Lanes | both (deterministic + single-pass semantic) | both (deterministic + **aggregated** semantic) |
| Aggregation | opt-in (`--aggregate`) | required (≥2 agreers → high confidence) |
| FP-verification | inline (re-read, reproduce) | adversarial panel (refute + majority vote) |
| Confidence gate | `--min-confidence high` (≥0.8) | `--min-confidence low` (≥0.0, ranked) |
| Critic | in-Claude default; `--dual` for semantic | `BLITZ_DUAL_CRITIC=1` default + FP-panel |
| Engine | `sprint-review` (8-invariant gate) | `audit` (5-pillar fan-out) |
| Output | PASS/FAIL + 8-invariant report + auto-fix | scorecard + ranked findings + roadmap epics + `coverage_boundary` |

Both select checks from [`check-registry.json`](check-registry.json) by `consolidated_target`. The registry carries each check's `lane` (deterministic|semantic), `verdict_authority` (reject|advisory), and `base_confidence`. **review suppresses what audit re-surfaces**: a single-pass semantic finding review drops as low-confidence is exactly what audit's aggregation lifts to high confidence — complementary, not redundant. See [check-registry.md](check-registry.md) for the confidence model + verdict-flip asymmetry.

## Folded into the entry points (deprecated standalone — sprint-19)

| Was standalone | Now | Invoke |
|---|---|---|
| `completeness-gate` | review Phase 1.5 (O2: `o2-*`, det-09/10) | `/blitz:review --only completeness` |
| `integration-check` | review Phase 1.6 (O3: `o3-*`, det-16) | `/blitz:review --only wiring` |

Both retain functional deprecation shims (slug + existing call-sites work) until the sprint-20 cutover. Canonical patterns live in the registry, not in the skill bodies.

## Standalone tools (NOT folded — distinct tempo/mechanism)

| Skill | Why standalone |
|---|---|
| `code-sweep` | continuous `/loop` ratchet + convention-discovered standards — a *tempo*, not a gate. Its checks (det-03/04/08/17) are registry-shared; the loop is not. |
| `code-doctor` | framework rule packs (F/V/P/G) + `--fix` auto-apply + `paths:` glob auto-load. review embeds the *scan* (`--only framework`); `--fix` stays here. |

## Orthogonal domains (out of review/audit scope)

Distinct scope + tempo + downstream + domain (the four-question test below). Invoked alongside, never inside, review/audit:

| Skill | Domain |
|---|---|
| `quality-metrics` | observability / trend (audit Phase 4 *calls* it for a snapshot; not absorbed) |
| `dep-health` | dependency CVE / license governance |
| `ui-audit` | cross-page visual + data-integrity |
| `perf-profile` | bundle / Lighthouse / runtime |
| `browse` | E2E smoke / console / network |

## The agents

| Agent | Role |
|---|---|
| `critic` | adversarial pre-PASS gate (review Invariant 7; audit critic). Registry-driven §2.1; verdict-flip asymmetry (ground-truth → REJECT, advisory → annotate). |
| `research-critic` | citation/claim gate for research docs (graded claim-grounding, UNVERIFIED verdict, scope-claim blocker). |
| `reviewer` | the 4 parallel reviewer agents review spawns (security/backend/frontend/patterns). |
| `architect` | audit Architecture pillar. |

## Authoring guidance — before adding an 8th quality skill

1. **Scope distinct?** (change vs repo vs file)
2. **Tempo distinct?** (per-change gate vs continuous loop vs pre-release)
3. **Downstream distinct?** (review.md vs ratchet.json vs roadmap doc vs exit code)
4. **Would a `--mode`/`--only` flag on review/audit do?** Usually yes — prefer flags over new skills.

If you can't answer all four with distinct values, don't add the skill — add a registry row or a `--only` mode instead.

## Cross-refs

- [`check-registry.json`](check-registry.json) / [`check-registry.md`](check-registry.md) — shared check source + confidence model
- [`shortcut-taxonomy.md`](shortcut-taxonomy.md) — human-readable view of `det-*` rows
- `skills/review/SKILL.md` — precision front-door · `skills/audit/SKILL.md` — recall entry point
- `skills/sprint-review/SKILL.md` — review engine (8-invariant gate) · `skills/audit/SKILL.md` — audit engine
- `agents/critic.md`, `agents/research-critic.md` — enforcement engines
- `docs/consolidation/review-audit/` — full design specs
