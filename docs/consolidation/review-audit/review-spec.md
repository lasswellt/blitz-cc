---
title: /blitz:review — Consolidated Spec
bias: precision (low FP — runs constantly, per-change)
absorbs: sprint-review (core) + completeness-gate + integration-check + code-doctor(framework) + code-sweep Tier-1
registry: check-provenance.json (consolidated_target ∈ {review, both})
critic: agents/critic.md (redesigned), in-Claude default
status: spec
---

# /blitz:review

Per-change quality gate. Runs on every sprint, so its bias is **precision**: a false alarm is expensive because it interrupts constant work. Single-pass semantic lane (the diff is small and known), full deterministic lane, mandatory FP-verification, `--min-confidence high` default. It is the existing `sprint-review` with `completeness-gate`, `integration-check`, `code-doctor`, and `code-sweep` Tier-1 folded in as phases, all reading the shared registry.

## Bias contract (vs audit)

| Axis | /blitz:review |
|---|---|
| Tempo | per-change / per-sprint, gate |
| Bias | **precision** (suppress low-confidence; don't cry wolf) |
| Semantic lane | **single-pass** on the diff (4 reviewer agents + critic) |
| Confidence gate | `--min-confidence high` (≥0.8) default |
| Aggregation | optional (`--aggregate` for high-stakes sprints) |
| Critic | in-Claude (ground-truth checks have no blind-spot risk); `--dual` opt-in |
| Output | PASS / CONDITIONAL / FAIL + 8-invariant report + auto-fixes applied |

## Phase flow

```
Phase 0    context — load sprint state, register session, read registry review_checks
Phase 1    DETERMINISTIC LANE — registry.filter(lane=deterministic ∧ target∈{review,both})
           ├─ 1.1 tsc --noEmit + eslint + test + build  (det-11, det-12 anchors)
           ├─ 1.2 shortcut detectors det-01..19          (run each detection.command)
           ├─ 1.5 anti-mock O2 (was completeness-gate)   (o2-anti-mock, o2-artifact-l1l2)
           ├─ 1.6 wiring O3 (was integration-check)       (o3-wiring, o3-orphan-route) [conditional: new modules]
           └─ 1.7 framework rules (was code-doctor)        (fw-*) [conditional: Vue/Firestore/Pinia detected]
Phase 2    SEMANTIC LANE (single-pass) — 4 reviewer agents (security/backend/frontend/patterns)
Phase 2.5  FP-VERIFICATION — every semantic finding + every base_confidence<1.0 deterministic finding:
           re-read cited code, confirm reproduces, attach excerpt. No evidence → downgrade to advisory.
Phase 3    AUTO-FIX — safe categories only (types, lint, imports). Bounded attempts.
Phase 3.6  REGISTRY INVARIANTS — carry-forward hard gate (8 invariants), incl. Invariant 7 = critic LGTM
Phase 3.7  COVERAGE BOUNDARY — declare what was NOT checked (browser unavailable, no test runner, etc.)
Phase 4    REPORT — PASS/CONDITIONAL/FAIL + findings ranked by effective_confidence
```

## Two lanes, made explicit (Pillar A)

- **Deterministic lane (Phase 1)** runs first, always, fast, zero-FP. Every check is a registry row with `lane: deterministic`. These produce `reject`-authority findings (subject to FP-verify for `base_confidence<1.0`).
- **Semantic lane (Phase 2)** is single-pass here (unlike audit) — the diff is small and the bias is precision, so aggregation is opt-in (`--aggregate`). Single-pass semantic findings start at `base_confidence ≈ 0.5` and MUST pass Phase 2.5 FP-verification to **survive** (un-reproduced findings are dropped, precision bias). FP-verification cannot *raise* confidence (factor maxes at ×1.0) — only aggregation lifts a semantic finding's base (0.5→0.85), and review's semantic lane is single-pass by default. So a default-review semantic finding stays at ≈0.5, below the high band: it is logged as a sub-threshold advisory, never surfaced as a blocker. That is `/blitz:audit`'s job to re-surface with aggregation evidence.

The lanes catch disjoint bug classes (ianlpaterson 38-task). Running only Phase 1 would miss wrong-logic/scorer-artifact bugs; running only Phase 2 would miss deleted-test/ratchet/broken-build artifacts. `flaw-finding-proof.md` works one of each.

## Confidence gate (precision tuning)

`--min-confidence high` (≥0.8) by default — **and the gate applies to advisory findings only.** Two rules:

1. **`reject`-authority findings bypass the gate** (registry `confidence_gate.reject_bypass`). A ground-truth fact is not confidence-triaged. This matters: not all deterministic findings are base ≥0.8 — det-06 (env-fallback, 0.75), det-05 (0.7), det-10 (0.7), det-15 (0.8), det-16 (0.75) sit below the band, and det-06/det-15 are `reject`-authority. Without the bypass, a fact that can flip the verdict would be suppressed. With it, any `reject` check that fires (and FP-verifies where base<1.0) surfaces regardless of band.
2. **Advisory findings are gated.** Single-pass semantic findings (base ≈0.5) and advisory deterministic findings below 0.8 are suppressed from the gate output (still logged). A semantic finding can **never** be a blocker — it has no reject authority (registry downgrade rule); at most it surfaces as a gate-visible advisory, and only if its `effective_confidence ≥ 0.8`, which in default single-pass review it never reaches.

This is the structural cure for crying wolf: facts always surface, opinions must clear the bar. Override `--min-confidence low` to see all advisories (debugging). The phrasing "a semantic finding becomes a blocker" is explicitly **wrong** and avoided — semantic = advisory, always.

## Critic invocation

Phase 3.6 Invariant 7 spawns `agents/critic.md` (redesigned). Per the CMC routing rule: **in-Claude default** — review's reject-authority findings are all ground-truth (deterministic lane), no blind-spot risk, so a second model adds cost not signal. `--dual` (=`BLITZ_DUAL_CRITIC=1`) is opt-in for sprints touching security-sensitive code (sem-sec findings benefit from cross-model). The critic loads `reject_only` from the registry; advisory findings annotate but never flip PASS→FAIL (verdict-flip asymmetry).

## Folded-skill mapping (Pillar: reduction)

| Was | Now | Loss? |
|---|---|---|
| `/blitz:completeness-gate` (standalone) | Phase 1.5 (o2-* checks) | none — same patterns, registry-sourced. Still invokable as `/blitz:review --only completeness` |
| `/blitz:integration-check` (standalone) | Phase 1.6 (o3-* checks) | none — sprint-dev Phase 3.5.0 calls `/blitz:review --only wiring` |
| `/blitz:code-doctor` (framework) | Phase 1.7 (fw-* checks) | none — also stays standalone for deep framework dives (`--fix`) |
| `code-sweep` Tier-1 | Phase 1.2 lightweight pre-gate | code-sweep stays standalone for the continuous `/loop` ratchet |
| `/blitz:review` (thin alias today) | this skill (canonical) | the 60-line alias becomes the entry point |

`--only <lane|concern>` lets the embedded phases run individually, preserving the standalone entry points behind one skill. No capability is deleted; the skill *count* drops (completeness-gate + integration-check cease to be separate SKILL.md files).

## Recall note (honest boundary)

Review is precision-biased BY DESIGN — it deliberately suppresses low-confidence semantic findings to avoid noise. The recall safety net is `/blitz:audit` (run pre-release): findings review suppressed as low-confidence are exactly what audit's aggregation lane re-surfaces. The two are complementary, not redundant (`quality-engine.md` four-question test: distinct tempo + bias + downstream).
