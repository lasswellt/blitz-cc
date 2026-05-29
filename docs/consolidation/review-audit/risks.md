---
title: Risks
status: spec
---

# Risks

Ranked by expected cost. Each has a mitigation already encoded in the specs or a flagged residual.

## R1 — Aggregation amplifies a shared blind spot (HIGH)

If ≥2 agents share the same blind spot, agreement produces *false* high-confidence (the self-critique paradox's irreducible core, 2402.08115). Aggregation assumes independent errors; correlated errors break it.
- **Mitigation**: perspective-diverse lenses (not N identical agents) in both aggregation and the FP-panel; `--dual` cross-model agreers for security; FP-verification re-reads actual code so a *hallucinated* agreement still gets dropped (`fp_factor 0`).
- **Residual**: a *correct-looking-but-wrong* finding all agents rationalize as fine — declared in `flaw-finding-proof.md` recall ceiling #1. Unfixable by more agents of the same family.

## R2 — Registry becomes a new single point of drift (MEDIUM-HIGH)

Centralizing 20 detectors in one JSON means an error there propagates to both skills + both critics + hooks.
- **Mitigation**: the registry is *data*, validated by a schema lint at commit (acceptance check: every legacy grep has a row; every row's `detection.command` is executable). Hooks keep their own hard-coded P0 patterns as defense-in-depth (the registry drives critic/skills, not the PreToolUse blockers) — so a registry bug cannot disable a P0 hook.
- **Residual**: schema-lint coverage gaps. Flag: write the lint before Epic 1 ships.

## R3 — FP-verification cost (MEDIUM)

The FP-panel adds N refuter agents per surviving finding. On a large audit this multiplies token spend.
- **Mitigation**: panel runs only on *survivors* of aggregation (already filtered); deterministic findings (`base_confidence 1.0`) skip it; `parallel()` caps at 16 concurrent. Review's single-pass lane verifies inline (no panel).
- **Residual**: a recall-biased audit with many low-confidence findings could fan out wide. Cap via `--max-verify N` (rank by base_confidence, verify top-N, log the rest as `unverified` in coverage_boundary — *never silently drop*).

## R4 — Workflow preview dependency (MEDIUM)

Audit's aggregation/FP-panel are described as `Workflow` `parallel()`. `Workflow` is a research preview, Enterprise-disabled.
- **Mitigation**: `workflow-dispatch.md` capability gate + `Agent()` fallback is mandatory (already specified). The aggregation/panel logic must work under both dispatch paths — same findings files, different orchestration.
- **Residual**: API churn before GA. Confine all `Workflow` calls behind the gate.

## R5 — Verdict-flip asymmetry mis-classifies a check (MEDIUM)

If a genuinely ground-truth check is tagged `advisory` (or vice-versa) in the registry, the critic either can't reject a real defect or can reject on opinion.
- **Mitigation**: `verdict_authority` is *derived* from `lane`+`severity`, not hand-set — a deterministic P0/P1/P2 is `reject`, a P3 or semantic is `advisory`. The derivation is auditable. det-11 (tsc-anchored, survey miscalled "semantic") is the one to watch — explicitly classified deterministic with a note.
- **Residual**: a future check added with a wrong lane tag. Schema lint should assert `lane==deterministic ⟹ detection.type ∈ {git,regex,tsc,ast,import-graph,counter,command}` and `lane==semantic ⟹ detection.type == semantic`. (The full allowed `detection.type` set is `{git,regex,tsc,ast,import-graph,counter,command,semantic}`.)

## R6 — Backward-compat shim rot (LOW-MEDIUM)

Removed entry points (completeness-gate, integration-check) become `--only` flags via deprecation shims. Shims that linger or break confuse users.
- **Mitigation**: shims emit a deprecation notice pointing at the flag; scheduled removal after ≥1 minor version. sprint-dev 3.5.0 + ship call-sites migrated in Epic 6 (not left to shims).
- **Residual**: external user scripts calling the old names after removal. Document in CHANGELOG/migration guide.

## R7 — Citation drift re-verification cost/noise (LOW)

Re-verifying carry-forward citations every 2 sprints adds WebFetch load and could flag transient DEADs (rate limits).
- **Mitigation**: "slow/timeout → UNKNOWN not DEAD" rule (already in research-critic); re-verify only `scope:` claims (sprint-driving), only when >2 sprints old.
- **Residual**: a flaky source flapping LIVE/UNKNOWN. UNKNOWN doesn't block, only surfaces.

## R8 — Our own research basis had a miscitation (REALIZED, mitigated)

The prompt cited "MisCiteBench" (a miscitation — wrong rendering of the unrelated real **MisciteBench** 2601.16993, AND credited with numbers that are actually CiteME's + CiteAudit's) plus an unsupported "118% recall." This *already happened* — caught by the Pillar-C verification pass and re-verified by a second independent reviewer.
- **Mitigation**: corrections folded into `effectiveness-research.md`; the miscitation is quarantined as the worked example. This is the system working as designed (the research-critic redesign would block exactly this in a `scope:` claim — an unverifiable citation → UNKNOWN/UNCITED, forcing correction to the real source).
- **Second-order lesson (the important one)**: the *first* verification pass called it "LIKELY_HALLUCINATED"; the *second* pass found the real MisciteBench and that search engines were fabricating confirmations of the wrong spelling. So even verification needed verification — which is the dual-critic-for-citations rationale (CiteME 4–18%) realized on our own work. Single-pass citation checking is not enough; **fetch, never trust, and cross-check.**

## R9 — Scope creep: orthogonal skills pulled in (LOW)

Pressure to fold quality-metrics/dep-health/ui-audit/perf-profile/browse into audit "since they're quality too."
- **Mitigation**: `quality-matrix.md` four-question test — they have distinct scope/tempo/downstream/domain. Audit *calls* quality-metrics for a snapshot but does not absorb it. Hold the line.
- **Residual**: none if the matrix is enforced at authoring time.
