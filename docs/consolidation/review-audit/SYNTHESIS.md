---
title: SYNTHESIS — Review/Audit Consolidation v2
target: cc-plugin-suite (Blitz) @ v1.16.0
status: design complete (specs); implementation = sequenced follow-up sprint behind the suite's own gates
deliverables: 12 (8 from v1 + 4 from v2)
verified: all effectiveness claims fetched live 2026-05-29; 5 corrections + 1 hallucination caught
---

# Synthesis

Collapse 7 overlapping review/audit/quality skills into **two entry points** over **one shared rule registry**, and make the result definitive at finding flaws — grounded in verified May-2026 research, not theater.

## The shape

```
                       check-provenance.json  (one registry: lane + verdict_authority + base_confidence + provenance)
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
  /blitz:review                    /blitz:audit
  precision · per-change           recall · pre-release
  both lanes, semantic single-pass both lanes, semantic AGGREGATED
  --min-confidence high            --min-confidence low
  FP-verify inline                 FP-verify panel (refute + majority vote)
  critic in-Claude (ground-truth)  critic + dual (BLITZ_DUAL_CRITIC=1) + panel
        │                               │
        └──────────┬────────────────────┘
                   ▼
   agents/critic.md  +  agents/research-critic.md   (sharpened; deterministic cores kept)
   verdict-flip asymmetry: ground-truth → REJECT; judgment → advisory only
```

## The three pillars, resolved

**A — Definitive flaw-finding (recall × precision).** Two orthogonal lanes (deterministic: grep/tsc/git/import-graph, zero-FP; semantic: LLM reasoning) run in both skills, because they catch *disjoint* bug classes (ianlpaterson 38-task: "neither alone sufficed"). Audit aggregates the semantic lane (≥2 independent agreers → high confidence; SWRBench 2509.01494 **+43.67% F1** — *not* the prompt's unsupported "118% recall"). A mandatory FP-verification stage re-reads cited code and confirms the flaw reproduces (native `/code-review` validation agent, <1% FP) — the structural cure for the v1.16.0 inflated-count incident: no blocker without reproducing evidence. Audit records what it did NOT check (recall instrumentation). `flaw-finding-proof.md` works a structural-only bug (deleted test → deterministic catches, semantic blind) and a semantic-only bug (swapped answer key → aggregated semantic catches, deterministic blind), plus the declared recall ceiling.

**B — A critic that works (self-critique paradox is real).** Naive self-critique degrades high-confidence accuracy 15–41% when the verifier shares the generator's blind spots (Snorkel 2025-11-26; 2402.08115). The critic is sound precisely because §2.1–2.8 are ground-truth (git/tsc/reflog/ratchet) — kept intact. The redesign makes the verdict-flip asymmetry an invariant: **ground-truth checks may REJECT; judgment checks may only annotate, never flip the verdict** — neutralizing the paradox without losing the cheap-false-REJECT benefit on facts. Opus 4.8 honesty down-weights the three self-report detectors (det-05/08/20) but keeps all deterministic-artifact detectors (honesty-insensitive — a model still deletes tests under instruction pressure). CMC routing made principled: in-Claude for deterministic (no blind-spot risk), `BLITZ_DUAL_CRITIC=1` for semantic/judgment (where blind spots bite, 2604.19049). Detector count reconciled: **20 catalogued (det-01…20); 13 reject-authority, 7 advisory.** Severity ≠ verdict authority, and `reject` findings bypass the min-confidence gate (facts aren't confidence-triaged).

**C — Research that verifies its own claims (citation hallucination is the headline risk).** Citation attribution is the model's weakest skill (4–18%, CiteME 2407.12861). The deterministic research-critic core (URL liveness, Deterministic Quoting, date floor, diversity) is kept. The advisory §2.5 claim-grounding is **promoted to a graded gate** (span-level, REFIND 2502.13622): a quantified `scope:` claim with no resolvable/grounded citation is a **BLOCKER** (it sprintifies phantom work — most expensive false PASS in the suite). **UNKNOWN becomes first-class**: inaccessible source ≠ PASS (verification drops to ~66–80% on inaccessible sources, CiteAudit 2602.23452 — *replacing the miscited "MisCiteBench"*); UNKNOWN-rate is reported; high UNKNOWN → `UNVERIFIED` verdict. Carry-forward citations are re-verified across sprints (drift 29–86%, Ram 2025). Dual-critic recommended for citation attribution specifically.

## The meta-result

The Pillar-C verification pass, run on the prompt's *own* research basis, caught a miscited paper ("MisCiteBench" — wrong rendering of the unrelated real MisciteBench, with mis-attributed numbers), an unsupported statistic ("118% recall"), a misattributed taxonomy, and two wrong dates. **The system caught its own spec's errors** — and a *second* verification pass then corrected the *first* pass's over-call (hallucination → miscitation) and exposed search engines fabricating confirmations of the wrong spelling. That "verification needed verification" is not embarrassment; it is the dual-critic-for-citations thesis (CiteME 4–18%) demonstrated on our own work — single-pass citation checking is insufficient. R8 in `risks.md` records it; `effectiveness-research.md` carries every correction.

## Deliverables (12)

| # | File | What |
|---|---|---|
| 1 | `check-provenance.json` | the registry (30 rows: 20 detectors + 5 pillars + O2/O3/fw) |
| 2 | `registry-design.md` | lane / verdict-authority / confidence model |
| 3 | `review-spec.md` | precision entry point |
| 4 | `audit-spec.md` | recall entry point |
| 5 | `migration-map.md` | skill→entry-point map + sequenced epics + backward-compat |
| 6 | `reduction-ledger.md` | 7→2+2; 0 capabilities lost; 8 net-new |
| 7 | `risks.md` | R1–R9 ranked + mitigations |
| 8 | `SYNTHESIS.md` | this |
| 9 | `effectiveness-research.md` | verified sources + 5 corrections + claim→spec map |
| 10 | `critic-redesign.md` | per-detector keep/advisory + asymmetry proof + CMC routing |
| 11 | `research-critic-redesign.md` | claim-grounding gate + UNKNOWN + scope-blocker + drift |
| 12 | `flaw-finding-proof.md` | worked disjoint-bug examples + recall ceiling |

## Sequenced implementation (behind the suite's own gates)

1. **Registry** — ship `check-registry.json`; make `shortcut-taxonomy.md` a view; write the schema lint. No behavior change.
2. **Critic redesign** — apply `critic-redesign.md`; registry-drive §2.1; verdict-flip asymmetry + FP-verify substep.
3. **Research-critic redesign** — apply `research-critic-redesign.md`; scope-claim blocker; UNKNOWN state.
4. **/blitz:review** — fold completeness-gate + integration-check + code-doctor(fw) + code-sweep(T1); `--only`; two-lane + confidence gate.
5. **/blitz:audit** — add aggregation + FP-panel + deterministic lane + recall instrumentation; rename codebase-audit.
6. **Cleanup** — delete folded SKILL.md; deprecation shims; rewrite quality-matrix.md; migrate ship + sprint-dev call-sites.

**The recursion is the validation**: each epic's `sprint-review` runs the *redesigned critic on itself*. Epic 2 ships only if Epic 2's own critic emits LGTM. The consolidation proves out by surviving its own gates.

## Definition of done — checklist

- [x] v1's 8 outputs + v2's 4 = 12 deliverables
- [x] Critic: every detector labeled ground-truth|judgment + keep|advisory with evidence; CMC routing tied to paradox; verdict-flip asymmetry proven
- [x] Research-critic: claim-grounding as graded gate; refuse-without-evidence for scope claims; UNKNOWN first-class; drift re-verification
- [x] Flaw-finding: worked structural-only + semantic-only bugs; declared recall ceiling
- [x] Both specs select from registry, run both lanes, gate by confidence, invoke redesigned critics; precision/recall bias documented
- [x] Sequenced epic plan the suite runs on itself
- [x] Every effectiveness claim cites a verified primary source; corrections folded; UNVERIFIED ≠ PASS
