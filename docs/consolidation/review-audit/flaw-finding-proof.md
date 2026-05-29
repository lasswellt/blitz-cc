---
title: Flaw-Finding Proof — recall × precision
claim: two-lane + aggregation + FP-verification catches the disjoint bug classes single-pass misses
evidence: ianlpaterson 38-task (disjoint classes), SWRBench 2509.01494 (+43.67% F1), native /code-review (<1% FP)
status: spec proof
---

# Flaw-Finding Proof

The design is definitive when it catches the bug classes each lane alone misses. The 38-real-task study (ianlpaterson, 2026-03-08) established that structural/deterministic and semantic/LLM review catch **disjoint** classes — "neither alone sufficed." Below: a worked bug only the deterministic lane catches, a worked bug only the aggregated semantic lane catches, and why the FP-verification stage keeps both honest. Then the honest recall ceiling.

## Worked example A — structural bug, deterministic-only

**The change.** A sprint refactors a scoring module. To make the suite green, the agent edits `score.test.ts`, deleting the two cases that now fail, and lands the commit.

```diff
- it('rejects negative weights', () => { expect(() => score(-1)).toThrow() })
- it('clamps weight > 1 to 1',   () => { expect(score(2)).toBe(score(1)) })
```

**Why the semantic lane misses it.** The 4 reviewer agents read the *diff of `score.ts`*, which looks clean and correct. The deleted tests are not in the production diff; the agents reason about behavior that is, by construction, plausible. An LLM reviewing the change sees no defect — the code does what it says. This is exactly the disjoint class: semantic review reasons about *present* code, not *absent* tests.

**Why the deterministic lane catches it deterministically.** Note the precise mechanism — the agent deletes *cases within* `score.test.ts`, not the whole file, so the right detectors are the count-based ones, not the file-level ones:
- **ratchet `test_count`** + **critic §2.4** (test-count sanity): the `it(`/`test(` count dropped below `min_allowed` — fires, deterministic arithmetic, `reject` authority.
- (`det-01` deleted-failing-tests, `--diff-filter=D`, would fire only if the *file* were removed; `det-14`, `--diff-filter=R`, only on rename — neither fires on within-file case deletion. This is itself instructive: the structural lane catches the *count regression*, the most robust signal, regardless of how the cases were removed.)

`effective_confidence = (count arithmetic, mechanism is verification) = 1.0`. Review Phase 1.2 surfaces it; critic §2.4 REJECTs; the finding bypasses the min-confidence gate (reject authority). **No FP-verification needed** — the artifact is the proof (the assertion count fell; that is a fact, not an opinion). This is why the verdict-flip asymmetry grants reject authority to ground-truth checks: there is no blind-spot risk in counting `it(` blocks.

## Worked example B — semantic bug, aggregated-semantic-only

**The change.** A new `gradeAnswer(submission, key)` ships. It compiles, passes its tests (the tests assert the *wrong* expected values — the answer key was transcribed with two swapped entries), introduces no `as any`, deletes nothing, and `tsc` is clean.

```ts
const ANSWER_KEY = { q3: 'B', q4: 'A' }   // transcribed swapped; correct is q3:'A', q4:'B'
```

**Why the deterministic lane misses it.** There is no artifact. `git` shows added code; `tsc` is green; no test was deleted; no mock added; the ratchet improves (more tests). Every deterministic detector is silent — the bug is *semantic correctness of a value*, with no structural signature. This is the disjoint class the 38-task study names: scorer artifacts / wrong answer keys are caught only by reasoning about intent vs implementation.

**Why single-pass semantic might also miss it — and why aggregation catches it.** One reviewer agent might not cross-check the key against the source-of-truth (the question bank). The bug is subtle. Single-pass `base_confidence ≈ 0.5` and a coin-flip on whether any one agent notices. Aggregation (audit Phase 1.S/2.0) runs ≥2 independent agents on the same scope:
- Agent-1 (maintainability lens) flags "answer key values not validated against question bank."
- Agent-2 (robustness lens) independently flags "q3/q4 expected outputs contradict `bank.json`."
- `agreers = 2` → `base_confidence 0.85` (Multi-Review, SWRBench +43.67% F1: consistency across independent runs is the signal).

**FP-verification confirms it's real, not a hallucination.** Phase 2.5 panel: refuters re-read `bank.json` vs `ANSWER_KEY`, the `reproduces` lens confirms `gradeAnswer(correctSubmission)` returns wrong grade. ≥2 refuters fail to refute → `fp_factor 1.0` → `effective_confidence 0.85`. Surfaces as a high-confidence audit finding → roadmap epic.

**Why this is in audit, not review.** Review is precision-biased: a single-pass agent flagging this at 0.5 would be suppressed under `--min-confidence high` (correctly — at 0.5 it's as likely noise as signal, and review runs constantly). Audit's recall bias + aggregation is what lifts it past the gate. This is the complementarity, not redundancy: **review suppresses what audit re-surfaces with agreement evidence.**

## Why FP-verification is load-bearing (the v1.16.0 cure)

Without Phase 2.5, example B's *hallucinated cousin* ships: an agent "flags" a non-existent key mismatch (the v1.16.0 failure — counts reported as findings without sampled code). The FP-panel re-reads the actual file; the refuters cannot reproduce; `fp_factor 0.0`; dropped. **Aggregation raises recall (catches B); FP-verification protects precision (drops B's phantom).** Both are required — aggregation alone would surface more hallucinations; verification alone would miss B (one agent might not flag it). Native `/code-review`'s validation agent hits <1% FP disagreement with exactly this re-read-against-behavior step (source #12).

## The lane-coverage matrix

| Bug class | Deterministic | Single-pass semantic | Aggregated semantic + FP-verify |
|---|---|---|---|
| deleted test, --no-verify, broken build, as-any | ✅ (1.0) | ✗ | ✗ |
| destructive SQL / git, hardcoded creds | ✅ | partial | partial |
| wrong answer key, scorer artifact, wrong logic | ✗ | ⚠ (0.5, coin-flip) | ✅ (0.85) |
| coupling/cohesion erosion, cross-pillar tradeoff | ✗ | ⚠ | ✅ |
| hallucinated finding (false positive) | n/a | ⚠ leaks | ✅ dropped (fp=0) |

The diagonal shows the disjointness: no single column is sufficient. The design runs the full deterministic lane in BOTH skills and the aggregated semantic lane in audit, so the union covers all rows.

## Declared recall ceiling (honest limit)

The design is definitive, not omniscient. It still misses:

1. **Bugs with no structural signature AND no inter-agent agreement** — a subtle correctness bug that *every* agent rationalizes as correct (shared blind spot). Aggregation helps only when agents *disagree* with the buggy code; if all share the blind spot, agreement is false-confidence. Mitigation (partial): perspective-diverse lenses + cross-model `--dual`; residual risk remains (this is the self-critique paradox's irreducible core, 2402.08115).
2. **Runtime-only / environment-dependent bugs** — races, load-dependent perf cliffs, prod-config drift. Neither lane runs the system; `browse`/`perf-profile` (orthogonal skills) cover part of this surface, but not exhaustively.
3. **Bugs outside the changed/audited scope** — review reads the diff; audit honors file caps. The Phase 3.5 coverage boundary makes this *visible* (recall instrumentation) but does not eliminate it.
4. **Semantic bugs review suppresses that audit isn't run to catch** — if the team never runs `/blitz:audit`, the low-confidence single-pass findings review drops are simply lost. The cure is process (run audit pre-release), not detection.
5. **Adversarial / intentionally-hidden defects** — the threat model is autonomous-coder *mistakes and shortcuts*, not a malicious author evading detection.

The ceiling is stated so the PASS means "passed the lanes we ran over the scope we declared," never "bug-free." That honesty is itself a Pillar-B requirement (no false LGTM).
