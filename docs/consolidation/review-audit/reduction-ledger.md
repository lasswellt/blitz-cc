---
title: Reduction Ledger — what shrinks, what is preserved
status: spec accounting
principle: definitive ≠ noisy; fewer skills must catch ≥ the same bugs, never fewer
---

# Reduction Ledger

The consolidation is only valid if the smaller surface catches **at least** what the larger one did. This ledger accounts for every unique capability and proves none is lost.

## Headline counts

| | Before | After | Δ |
|---|---|---|---|
| Quality-class entry points | 7 (sprint-review, review-alias, completeness-gate, integration-check, codebase-audit, code-doctor, code-sweep) | **2 consolidated** (`/blitz:review`, `/blitz:audit`) + 2 standalone tools (`code-doctor`, `code-sweep`) | −3 SKILL.md files |
| SKILL.md files removed | — | completeness-gate, integration-check, review-alias | −3 |
| Orthogonal skills (untouched) | 5 (quality-metrics, dep-health, ui-audit, perf-profile, browse) | 5 | 0 |
| Detector definitions (duplicated across skills + hooks + critic) | ~20 patterns × ~4 copies | **1 registry** (`check-provenance.json`, 30 rows) | dedup ~3× |
| Agent files | 2 critics | 2 critics (sharpened, not added) | 0 |

Net: **7 quality entry points → 2 + 2**, with the detection logic de-duplicated into one registry. The reduction is in *surface and duplication*, not in *coverage*.

## Unique-capability preservation audit

Every unique check the survey found, and where it lives now. "Lost?" must read **none** on every row.

| Unique capability | Owner (was) | New home | Lost? |
|---|---|---|---|
| 8-invariant carry-forward gate (ratchet, branch hygiene, critic LGTM) | sprint-review | review Phase 3.6 | none |
| auto-fix loop with attempt budgets | sprint-review | review Phase 3 | none |
| 4 parallel reviewer agents | sprint-review | review Phase 2 | none |
| 5-pillar cross-reasoning (sec×perf, maint×robust) | codebase-audit | audit Phase 1.S | none |
| confidence-threshold filter + detector-#20 | codebase-audit | audit Phase 2.6 + registry det-20 | none (now gate, not just filter) |
| roadmap epic generation + scope: frontmatter | codebase-audit | audit Phase 3 | none |
| anti-mock pattern set (O2) | completeness-gate | registry o2-* / review Phase 1.5 | none |
| artifact verification L1/L2/L3 | completeness-gate | review Phase 1.5 + delegates L3 to o3-wiring | none |
| export→import tracing, orphan routes, auth coverage (O3) | integration-check | registry o3-* / review Phase 1.6 | none |
| unwired-store-actions | integration-check | o3-wiring | none |
| framework rule packs F/V/P/G + paths: auto-load | code-doctor | registry fw-* / review 1.7 + standalone | none |
| dead-export + duplication detection | code-doctor | review 1.7 + audit 1.D | none |
| ratchet (8 monotonic metrics) | code-sweep | review Phase 3.6 (enforce) + code-sweep (drive) | none |
| Tier-3 deep analysis (orphans, dead exports, n+1, XSS, nesting) | code-sweep | audit Phase 1.D/1.S | none |
| standards discovery + file-queue prioritization | code-sweep | code-sweep standalone (distinct tempo) | none |
| fix circuit-breaker (det-17) | code-sweep | registry det-17 | none |

**Result: 0 capabilities lost.** Three skills' worth of behavior become phases/flags; two skills (code-sweep, code-doctor) keep distinct standalone tempos and are NOT folded, only registry-linked.

## Net-new capabilities (the consolidation *adds* coverage)

The reduction is net-positive — the consolidated skills catch *more* than the originals:

| New capability | Why it's new | Pillar |
|---|---|---|
| Multi-Review aggregation (≥2 agreers → high confidence) | codebase-audit's 2 agents had different scopes, no agreement signal | A |
| Active FP-verification panel (re-read, refute, majority vote) | only had a passive confidence threshold + advisory #20 | A |
| Explicit deterministic lane in audit | audit was all-semantic; no grep/tsc/import lane | A |
| Recall instrumentation (coverage_boundary required field) | coverage gaps were partially logged, not first-class | A |
| Verdict-flip asymmetry (advisory cannot REJECT) | was implicit; now proven invariant | B |
| Principled CMC routing (dual for semantic, not deterministic) | env vars existed, no when-to-use rule | B |
| Claim-grounding graded gate + UNKNOWN state + scope-claim blocker | §2.5 was advisory-only; inaccessible could PASS | C |
| Carry-forward citation drift re-verification | no drift guard existed (Ram 86%) | C |

## "Definitive ≠ noisy" accounting

More findings is not the goal; *more real findings + fewer false alarms* is. The two skills are tuned opposite ways to achieve both:
- **Review precision** ↑ via `--min-confidence high` + FP-verify dropping un-reproduced semantic findings → fewer false alarms than the old multi-skill chain (which surfaced raw completeness-gate/integration-check greps without verification).
- **Audit recall** ↑ via aggregation + deterministic lane + recall instrumentation → catches the disjoint structural+semantic classes the old single-lane codebase-audit missed.

The v1.16.0 inflated-count incident is the regression this prevents: under the old design, audit agents reported counts as findings (noise ↑, precision ↓). The registry downgrade rule (`fp_factor` defaults to 0 until evidence attached) makes that specific failure structurally impossible.
