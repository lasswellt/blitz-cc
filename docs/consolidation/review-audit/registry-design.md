---
title: Shared Check Registry — Design
artifact: check-provenance.json (schema blitz-check-registry/2.0)
status: spec (implementation deferred to follow-up sprint)
pillars: A (two-lane + confidence), B (verdict authority), C (provenance for citations)
---

# Shared Check Registry

One data file (`check-provenance.json`) is the single source of truth for every check both consolidated skills run. It replaces the prose detector table in `quality-engine.md §1` and the grep patterns scattered across 7 quality skills. Both `/blitz:review` and `/blitz:audit` *select rows* from it; `agents/critic.md` and `agents/research-critic.md` *enforce rows* from it. Confidence math is defined once, here.

## Why a registry (not inline patterns)

The v1.16.0 inflated-count incident and the disjoint-bug-class evidence (ianlpaterson, 38 tasks) both point to the same root cause: detection logic was duplicated and drifted between skills, and the deterministic vs semantic split was implicit. A registry makes three things explicit and unduplicated:

1. **Lane** (`deterministic | semantic`) — Pillar A's orthogonal-detection axis. Both skills MUST run both lanes; the registry is what makes "both lanes" a selectable, auditable fact rather than a hope.
2. **Verdict authority** (`reject | advisory`) — Pillar B's ground-truth-vs-judgment distinction, pre-computed per check so the critic never has to decide at runtime whether a finding may flip a verdict.
3. **Provenance** (`owner`, `source`) — Pillar C applied internally: every check traces to the legacy skill that owned it and the primary source that justifies it, so the reduction is reversible and auditable.

## The two axes that drive everything

### Lane (detection mechanism)

| Lane | Mechanism | FP rate | base_confidence | Verification |
|---|---|---|---|---|
| `deterministic` | grep / AST / tsc / git / import-graph / npm-audit | ~0 | 0.6–1.0 | the mechanism *is* the verification (a `tsc` error reproduces by definition) |
| `semantic` | LLM agent reasoning about behavior/intent | high, sporadic | 0.45–0.55 single-pass | requires **aggregation** (≥2 agreers) AND **FP-verification** (re-read code, confirm reproduces) |

This table is the formal statement of the 38-task finding: the lanes catch **disjoint** bug classes, so a skill that runs only one ships errors. `flaw-finding-proof.md` works a bug from each lane the other cannot see.

### Verdict authority (ground truth vs judgment)

Derived deterministically from lane + severity, NOT decided per-run:

- **`reject`** — ground-truth-anchored (deterministic lane, or tsc/import-resolution-anchored). May flip a critic/gate verdict to REJECT. P0/P1/P2.
- **`advisory`** — opinion-anchored (semantic lane single-pass, or intent-ambiguous deterministic checks like empty-catch). May ONLY append to `issues[]`. P3. **Never flips a verdict.**

This is the codification of the self-critique paradox (Snorkel, 26 Nov 2025; arxiv 2402.08115): a critic anchored on its own opinion of code quality degrades accuracy when it shares the generator's blind spots, so opinion-anchored findings are structurally barred from rejection. Ground-truth findings (`tsc`, reflog, ratchet arithmetic) carry no blind-spot risk and keep full reject authority. See `critic-redesign.md` for the per-detector application.

## Confidence model (Pillar A, made arithmetic)

```
effective_confidence = base_confidence × fp_verification_factor
```

- `base_confidence` — inverse-FP prior stored per check. Deterministic ≈ 0.9–1.0; semantic single-pass ≈ 0.5; **semantic rises to ≈0.85 only when ≥2 independent agents/runs flag the same finding** (Multi-Review aggregation, registry note on `sem-*` rows).
- `fp_verification_factor` — `reproduced → 1.0`, `not_reproduced → 0.0` (dropped), `inaccessible/unverifiable → 0.5`.

**The min-confidence gate applies to ADVISORY findings only.** `reject`-authority findings (ground-truth facts) **bypass the gate entirely** — a fact is not confidence-triaged. This closes a hole: det-06 (env-fallback) is `reject`-authority but `base_confidence 0.75`; without the bypass, `--min-confidence high (≥0.8)` would suppress a finding that has power to flip the verdict. The rule: *if a `reject` check's deterministic detector fires (and FP-verify reproduces, where `base<1.0`), it surfaces and may REJECT regardless of band.* Confidence triage is for opinions, not facts.

Gate defaults split by skill bias (advisory findings only):
- `/blitz:review` → `--min-confidence high` (≥0.8). Precision: it runs every change, so a false advisory is expensive. Low-confidence advisories are suppressed (still logged, not surfaced). `reject` findings always surface.
- `/blitz:audit` → `--min-confidence low` (≥0.0). Recall: it runs rarely, so a missed bug is expensive. Everything is reported, ranked by `effective_confidence`.

**FP-verification cannot raise confidence.** `fp_verification_factor` maxes at 1.0, so it only PRESERVES (×1.0) or DROPS (×0.0) a finding. Only **aggregation** (semantic base 0.5 → 0.85 on ≥2 agreers) raises confidence. Therefore a single-pass semantic finding in default review (no aggregation) can never reach the 0.8 band — it stays a sub-threshold advisory unless audit's aggregation lane lifts it. This is the precise mechanism of "review suppresses what audit re-surfaces."

**Downgrade rule (anti-v1.16.0):** a semantic finding with no reproducing evidence is capped at `advisory` and can NEVER be a `blocker` regardless of confidence (it has no reject authority; high aggregated confidence raises only its RANK). This is the structural fix for "audit agents reported grep counts as findings without sampled code" — `fp_verification_factor` defaults to 0 (dropped) until evidence is attached.

**Severity ≠ verdict authority.** A semantic check can carry a high severity (sem-sec is P2) yet remain `advisory`, because semantic findings never flip a verdict. Severity encodes ratchet-tracking / triage importance; `verdict_authority` encodes whether the check may REJECT. The two are orthogonal and derived independently.

## Detector-count reconciliation (Pillar B housekeeping)

The taxonomy title says "19"; the registry holds 20 detector rows (`det-01`…`det-20`). **Canonical phrasing going forward: "20 catalogued detectors (det-01…20; det-20 — audit-FP — appended 2026-05-16). Among them, 13 carry reject authority and 7 are advisory (det-05, det-08, det-09, det-10, det-16, det-17, det-20)."**

The earlier "19 blocking + 1 advisory" phrasing was **wrong** and is retired: it conflated "det-20 appended late" with "only one advisory detector," but 6 of det-01…19 are also advisory (det-05/08/09/10/16/17). Do not call det-01…19 "blocking-class." `critic.md`'s description ("19 documented failure modes"), `quality-engine.md`'s title, and the critic's LGTM summary ("8 critic checks" = the 8 reject-checklist *classes* §2.1–2.8, distinct from the 20 detectors) are reconciled to this phrasing in `critic-redesign.md`.

## What the registry does NOT cover

Orthogonal-domain checks stay out: `dep-health` (npm-audit/CVE governance), `perf-profile` (Lighthouse/bundle), `ui-audit` (cross-page visual/data), `browse` (E2E smoke), `quality-metrics` (observability trend). They have distinct scope/tempo/downstream (per `_shared/quality-engine.md` four-question test) and are invoked alongside, not inside, review/audit. The registry is the review/audit shared core only.

## Selection contract (how skills read it)

```
review_checks  = registry.checks.filter(c => c.consolidated_target in {review, both})
audit_checks   = registry.checks.filter(c => c.consolidated_target in {audit, both})
deterministic  = checks.filter(c => c.lane == 'deterministic')   # both skills, run first, fast, zero-FP
semantic       = checks.filter(c => c.lane == 'semantic')        # review: single-pass; audit: aggregated
reject_only    = checks.filter(c => c.verdict_authority == 'reject')   # critic may flip verdict on these
```

The critic and research-critic load `reject_only` as their hard-gate set and everything else as advisory. No grep pattern is duplicated in a skill body — skills cite `det-NN` / `sem-*` ids.
