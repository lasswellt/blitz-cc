# Shared Check Registry

`check-registry.json` (schema `blitz-check-registry/2.0`) is the single source of truth for every check the review/audit family runs. It supersedes the prose detector table and grep patterns that were previously duplicated across `shortcut-taxonomy.md §1/§3`, `agents/critic.md §2.1`, and the quality skills. Consumers **select rows** from it; `agents/critic.md` and `agents/research-critic.md` **enforce rows** from it. Confidence math is defined once, here.

Status: shipped 2026-05-29 (sprint-18, migration-map Epic 1). The `/blitz:review` and `/blitz:audit` consolidations that select from it land in sprint-19 (Epics 4–6).

## The two axes

### Lane (detection mechanism)

| Lane | Mechanism | FP rate | base_confidence | Verification |
|---|---|---|---|---|
| `deterministic` | grep / AST / tsc / git / import-graph / npm-audit | ~0 | 0.6–1.0 | the mechanism *is* the verification (a `tsc` error reproduces by definition) |
| `semantic` | LLM agent reasoning about behavior/intent | high, sporadic | 0.45–0.55 single-pass | requires **aggregation** (≥2 agreers) AND **FP-verification** (re-read code, confirm reproduces) |

The lanes catch **disjoint** bug classes (ianlpaterson 38-task, 2026-03-08: "neither alone sufficed"), so a skill running only one lane ships errors.

### Verdict authority (ground truth vs judgment)

Derived deterministically from `lane`+`severity`, NOT decided per-run:

- **`reject`** — ground-truth-anchored (deterministic lane, severity P0/P1/P2). May flip a critic/gate verdict to REJECT. **Bypasses the min-confidence gate** (facts aren't confidence-triaged).
- **`advisory`** — opinion-anchored (semantic lane, or P3 deterministic checks). May ONLY append to `issues[]`. **Never flips a verdict.** Subject to min-confidence suppression.

Derivation: `reject iff (lane==deterministic AND severity ∈ {P0,P1,P2}); else advisory`. This codifies the self-critique paradox (Snorkel 2025-11-26; arxiv 2402.08115): opinion-anchored verification is structurally barred from rejection; ground-truth findings (`tsc`, reflog, ratchet arithmetic) carry no blind-spot risk and keep full reject authority. See [`agents/critic.md`](../../agents/critic.md) §4.

## Confidence model

```
effective_confidence = base_confidence × fp_verification_factor
```

- `base_confidence` — inverse-FP prior. Deterministic ≈ 0.6–1.0; semantic single-pass ≈ 0.5; **semantic rises to ≈0.85 only when ≥2 independent agents flag the same finding** (Multi-Review aggregation; SWRBench 2509.01494, +43.67% F1).
- `fp_verification_factor` — `reproduced → 1.0`, `not_reproduced → 0.0` (dropped), `inaccessible/unverifiable → 0.5`. **Maxes at 1.0 — FP-verification can only preserve or drop, never raise.** Only aggregation raises a semantic finding's confidence.

Gate (advisory findings only): `/blitz:review` → `--min-confidence high` (≥0.8, precision); `/blitz:audit` → `--min-confidence low` (≥0.0, recall). **`reject` findings bypass the gate** (`confidence_gate.reject_bypass`) — e.g. det-06 (env-fallback, base 0.75, reject-authority) surfaces despite being below the high band, because a fact is not confidence-triaged.

**Severity ≠ verdict authority.** A semantic check can carry high severity (sem-sec is P2) yet remain `advisory` — severity encodes ratchet/triage importance; `verdict_authority` encodes whether it may REJECT. Orthogonal, derived independently.

**Downgrade rule (anti-FP):** a semantic finding with no reproducing evidence is capped at `advisory` and can NEVER be a `blocker` regardless of confidence; `fp_verification_factor` defaults to 0 (dropped) until evidence is attached. This is the structural fix for the v1.16.0 inflated-count incident (counts reported as findings without sampled code).

## Detector-count reconciliation

**Canonical phrasing: "20 catalogued detectors (det-01…20; det-20 — audit-FP — appended 2026-05-16). 13 carry reject authority, 7 are advisory (det-05, det-08, det-09, det-10, det-16, det-17, det-20)."** The retired "19 blocking + 1 advisory" phrasing was wrong (6 of det-01…19 are advisory). `critic.md`'s LGTM summary "8 critic checks" counts the 8 reject-checklist *classes* §2.1–2.8, distinct from the 20 detectors.

## Selection contract

```
review_checks  = checks.filter(c => c.consolidated_target in {review, both})
audit_checks   = checks.filter(c => c.consolidated_target in {audit, both})
deterministic  = checks.filter(c => c.lane == 'deterministic')   # both skills, run first, fast, zero-FP
semantic       = checks.filter(c => c.lane == 'semantic')        # review: single-pass; audit: aggregated
reject_only    = checks.filter(c => c.verdict_authority == 'reject')   # critic may flip verdict; bypass min-confidence
```

Skills/critics cite `det-NN` / `sem-*` ids and run `detection.command` — no grep pattern lives in any skill or agent body. The schema lint ([`hooks/scripts/check-registry-validate.sh`](../../hooks/scripts/check-registry-validate.sh)) asserts the derivation invariant + `detection` presence/type at commit time (risks R2/R5).

## Out of scope

Orthogonal-domain checks are NOT in the registry: `dep-health`, `perf-profile`, `ui-audit`, `browse`, `quality-metrics` — distinct scope/tempo/downstream per [`quality-matrix.md`](quality-matrix.md). The registry is the review/audit shared core only.

## Related

- [`check-registry.json`](check-registry.json) — the data
- [`shortcut-taxonomy.md`](shortcut-taxonomy.md) — human-readable view of the `det-*` rows
- [`agents/critic.md`](../../agents/critic.md), [`agents/research-critic.md`](../../agents/research-critic.md) — enforcement engines
- `docs/consolidation/review-audit/` — full design specs (registry-design, review-spec, audit-spec, critic-redesign, research-critic-redesign, flaw-finding-proof, effectiveness-research)
