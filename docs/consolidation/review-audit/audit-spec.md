---
title: /blitz:audit — Consolidated Spec
bias: recall (catch everything — runs rarely, pre-release)
absorbs: codebase-audit (core, 5-pillar) + code-sweep Tier-2/3 + code-doctor-at-scale + quality-metrics snapshot
registry: check-provenance.json (consolidated_target ∈ {audit, both})
critic: agents/critic.md (redesigned) + adversarial-verify panel; BLITZ_DUAL_CRITIC=1 default
dispatch: Workflow (pilot, WIRED) with Agent() fallback per workflow-dispatch.md
status: spec
---

# /blitz:audit

Pre-release deep audit. Runs rarely, so its bias is **recall**: a missed bug is expensive because it ships. Full deterministic lane, **aggregated** multi-pass semantic lane (Multi-Review), mandatory FP-verification via an adversarial-verify panel, `--min-confidence low` default (report everything, ranked). It is the existing `codebase-audit` 10-agent fan-out plus the aggregation + active-verification + deterministic-lane + recall-instrumentation that it currently lacks.

## Bias contract (vs review)

| Axis | /blitz:audit |
|---|---|
| Tempo | pre-release / quarterly, deep |
| Bias | **recall** (report everything, ranked — don't silently drop) |
| Semantic lane | **aggregated** — each pillar by ≥2 independent agents (Multi-Review) |
| Confidence gate | `--min-confidence low` (≥0.0) default; rank by effective_confidence |
| Aggregation | **required** for semantic findings |
| Critic | `BLITZ_DUAL_CRITIC=1` default + adversarial-verify panel (recall context, highest stakes) |
| Output | 5-pillar scorecard + ranked findings + roadmap epic proposals + coverage boundary |

## Phase flow

```
Phase 0    setup — inventory, register session, read registry audit_checks
Phase 1.0  dispatch-mode gate (Workflow|Agent) per workflow-dispatch.md
Phase 1.D  DETERMINISTIC LANE — registry.filter(lane=deterministic ∧ target∈{audit,both})
           run det-* + o3-* + fw-* across whole codebase; zero-FP, fast, no aggregation needed
Phase 1.S  SEMANTIC LANE (AGGREGATED) — 5 pillars × ≥2 independent agents = ≥10 agents (Workflow parallel())
           each agent reasons independently; findings tagged by agent id
Phase 2.0  AGGREGATION (Multi-Review) — group semantic findings by (file, line-range, claim):
           flagged by ≥2 independent agents → confidence:high (base 0.85)
           flagged once                     → confidence:low  (base 0.50)
Phase 2.5  FP-VERIFICATION PANEL — per finding, N adversarial refuters (parallel, majority vote):
           re-read cited code, attempt to REFUTE; ≥majority refute → drop. Survivors get reproducing excerpt.
Phase 2.6  CONFIDENCE FILTER — effective_confidence = base × fp_factor; rank, do NOT drop (recall)
Phase 3    5-pillar scorecard + roadmap epic proposals (scope: frontmatter) + index.json
Phase 3.5  COVERAGE BOUNDARY (recall instrumentation) — declare what was NOT checked
Phase 4    quality-metrics snapshot (observability delta) + report
```

## Aggregation (Pillar A, the net-new core)

`codebase-audit` today runs 2 agents/pillar but with **different scopes** (frontend vs backend) — there is no agreement signal. The redesign runs **≥2 agents on the SAME scope independently**, so cross-agent agreement becomes the high/low-confidence separator:

```
for finding f in semantic_findings:
    agreers = count(distinct agent_id that independently flagged f)
    f.base_confidence = 0.85 if agreers >= 2 else 0.50
```

This is SWRBench's multi-review aggregation (2509.01494, **+43.67% F1** — *not* the unsupported "118% recall" from the prompt). The mechanism: consistency across independent runs separates real issues (consistently flagged) from sporadic hallucinations (flagged once). Aggregating across runs of one model OR across different models both work; audit uses ≥2 independent agents per pillar, and `--dual` adds cross-model agreers for security.

## FP-verification panel (Pillar A + native /code-review parity)

Every surviving finding faces an adversarial refuter panel (native `/code-review`'s validation agent, <1% FP, source #12 — implemented as the "net-new adversarial-verify panel" `workflow-dispatch.md` already names):

```js
// per finding, parallel refuters with diverse lenses, majority vote
const votes = await parallel(['correctness','security','reproduces'].map(lens => () =>
  agent(`Re-read ${f.file}:${f.line}. Via the ${lens} lens, attempt to REFUTE: ${f.claim}.
         Default refuted=true if you cannot reproduce the flaw against actual behavior.`,
        {phase:'Verify', schema: VERDICT})))
f.fp_factor = votes.filter(v=>!v.refuted).length >= 2 ? 1.0 : 0.0  // survivors keep, refuted dropped
```

Perspective-diverse lenses (not N identical refuters) catch failure modes redundancy can't. A finding that survives gets its reproducing excerpt attached — this is the structural cure for the v1.16.0 inflated-count incident: **no finding is reported as a blocker without reproducing evidence** (registry downgrade rule).

## Confidence gate (recall tuning)

`--min-confidence low` (≥0.0) by default: report EVERYTHING, ranked by `effective_confidence`, nothing silently dropped (recall bias). The ranking does the user's triage; suppression is the user's choice via `--min-confidence`. Contrast review (suppresses <0.8 by default). Refuted findings (fp_factor=0) ARE dropped even in audit — those aren't low-confidence, they're disproven.

## Recall instrumentation (Pillar A #4, made first-class)

Audit MUST record what it did NOT check, so missed-bug surface is visible not silent. Phase 3.5 emits a coverage boundary:
- agents that failed / timed out (existing: <7/10 warning)
- registry checks skipped (no test runner, no framework, file caps hit) — listed by `det-NN`/`sem-*` id
- files over the per-agent cap that went unread
- lanes not run (e.g. `--only semantic`)

`"coverage_boundary"` is a required field in the report JSON. A clean PASS with a large boundary is honestly labeled "passed what we checked," not "passed everything."

## Critic invocation

`BLITZ_DUAL_CRITIC=1` is the **default** for audit (recall context, pre-release stakes — the false-LGTM cost is highest). The critic + the FP-panel are complementary: the panel verifies individual findings; the critic checks the audit *output itself* for det-20 (unverified pattern-match claims) and cross-pillar integrity. Per CMC routing, semantic/security findings route cross-model.

## Folded-skill mapping

| Was | Now | Loss? |
|---|---|---|
| `/blitz:codebase-audit` | this skill (canonical 5-pillar core) | none — gains aggregation + verify + deterministic lane |
| `code-sweep` Tier-2/3 | Phase 1.D + 1.S deep checks (orphans, dead exports, n+1) | code-sweep stays standalone for continuous `/loop` ratchet |
| `code-doctor`-at-scale | Phase 1.D fw-* across codebase | code-doctor stays standalone for `--fix` |
| `quality-metrics` snapshot | Phase 4 observability delta | quality-metrics stays standalone (dashboard/trend/compare modes) |

`codebase-audit` is renamed/aliased to `/blitz:audit`; the 10-agent fan-out, confidence-filter, detector-#20, Workflow dispatch, and roadmap-epic emission all carry forward unchanged. The folds are *additive phases*, not rewrites.

## Precision note (honest boundary)

Audit is recall-biased BY DESIGN — it reports low-confidence findings the user must triage. It is NOT a merge gate; findings drive `/blitz:roadmap`, not PASS/FAIL. The precision counterpart is `/blitz:review` (the per-change gate). Running audit's recall output as a hard gate would cry wolf — that's review's job, at high confidence.
