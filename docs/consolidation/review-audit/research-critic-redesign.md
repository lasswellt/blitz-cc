---
title: agents/research-critic.md — Redesign Spec
target: agents/research-critic.md (236 lines today; sharpen, do not rewrite)
principle: fetch, never trust; inaccessible ≠ pass; ungrounded scope-claim = blocker
status: spec (implementation = follow-up sprint)
---

# Research-Critic Redesign

The deterministic core (§2.1 URL liveness, §2.2 Deterministic Quoting, §2.3 date floor, §2.4 source diversity, §2.6 schema presence) is correct and grounded — **keep it.** The redesign promotes the one weak, advisory, highest-yield check (§2.5 claim grounding) into a graded gate, makes UNKNOWN first-class, adds refuse-without-evidence for `scope:` claims, and adds carry-forward drift re-verification. Citation attribution is the model's single weakest skill (4–18%, CiteME 2407.12861), so this is where rigor pays most.

## 1. Promote §2.5 claim-grounding: advisory → graded gate

Today §2.5 picks 3 random claims, checks noun-phrase overlap, flags advisory-only. The gold standard is span-level claim-to-evidence verification (REFIND, 2502.13622). The redesign:

- **Scope expands from quotes to all quantified/declarative claims.** Deterministic Quoting (§2.2) already verifies `> "..."` spans are substrings of source. §2.5 extends this from *quotes* to *claims*: every claim matching `\b(found|showed|measured|achieves|reduces|improves|lifts|N%|N×)\b` must (a) cite a source AND (b) have its substance appear in the fetched source content.
- **Graded outcomes** (not binary advisory):

| Outcome | Condition | Authority |
|---|---|---|
| `GROUNDED` | claim substance present in accessible cited source | pass |
| `UNGROUNDED` | source accessible, claim substance absent | **blocker** if claim is in a `scope:` block; major otherwise |
| `UNKNOWN` | cited source inaccessible (4xx/timeout/paywall) | neither pass nor reject; counts toward UNKNOWN-rate |
| `UNCITED` | quantified claim with no citation at all | **blocker** if `scope:`; major otherwise |

- **Cross-model recommended here.** Citation verification on accessible sources is near-perfect, but the *attribution* judgment (does this source actually support this claim) is the 4–18% weak task — `BLITZ_DUAL_CRITIC=1 --mode research` is high-value, not theater, for §2.5 specifically.

## 2. Refuse-without-evidence for `scope:` claims (new blocker class)

`scope:` claims flow into the carry-forward registry and *drive real sprints* (acceptance checks gate work). An ungrounded `scope:` claim is the most expensive false PASS in the suite — it sprintifies phantom work. Therefore:

```
∀ claim c in any scope: block :
    c.citation == none           → CITATIONS_MISSING (blocker)
    c.citation inaccessible      → UNKNOWN (block cleanup; surface to user, do NOT auto-pass)
    c.substance ∉ fetched(c.cite)→ CITATIONS_MISSING (blocker)
```

This is stricter than body claims (which can be `major`) because of the downstream blast radius. Cites the v1.16.0 inflated-count incident and CiteME's 4–18% baseline as justification.

## 3. UNKNOWN as a first-class verdict state

Today verdict ∈ {PASS, CITATIONS_MISSING}. Inaccessible sources are silently lumped into UNKNOWN classification but the doc can still PASS. The redesign:

- **UNKNOWN ≠ PASS.** Verification accuracy drops to ~66–80% on inaccessible sources (CiteAudit 2602.23452 / AttributionBench — *replacing the miscited "MisCiteBench," which is a wrong-rendering of the unrelated MisciteBench 2601.16993 and was credited with numbers that are actually CiteME's + CiteAudit's*). A doc whose citations the critic could not actually fetch is **not verified**, and saying PASS overstates confidence.
- **UNKNOWN-rate is a reported metric** in the JSON reply: `"unknown_rate": <fraction of citations classified UNKNOWN>`. A doc with `unknown_rate > 0.3` gets verdict `UNVERIFIED` (new state), not PASS — the user inspects the inaccessible sources before the findings dir is cleaned up.
- Verdict enum becomes `{PASS, UNVERIFIED, CITATIONS_MISSING}`. `UNVERIFIED` blocks cleanup like `CITATIONS_MISSING` but signals "couldn't check" vs "checked and failed."

## 4. 4-way taxonomy: correct the attribution

Keep the 4-way LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN operational scheme — it's useful. But **correct §2.1's citation**: 2604.03173 (Rao/Wong/Callison-Burch) uses a **2-way** hallucinated-vs-non-resolving distinction. Edit the line to: *"extends the urlhealth hallucinated/non-resolving distinction (2604.03173) into a 4-way operational scheme (Blitz)."* The 4-way scheme is Blitz's own; don't misattribute it.

## 5. Carry-forward drift re-verification (new periodic check)

Citations mutate 29–86% across turns even on a fixed topic (Ram 2025, ACL 2025.wasp-main.20; up to 85.6% fabrication). A `scope:` claim cited correctly in sprint-3 can rot by sprint-6. The redesign adds:

- When a `scope:` claim is **re-cited across sprints** (carry-forward registry propagation), the research-critic re-runs §2.1 (liveness) + §2.5 (grounding) on that claim's source. A once-LIVE, once-GROUNDED citation that now resolves DEAD or UNGROUNDED → flag `drift_detected` (major), surface in the carry-forward escalation.
- Cadence: triggered when `/blitz:next` detects an active carry-forward entry whose `scope:` citation is older than 2 sprints, OR on demand via `--reverify-carryforward`.
- This is a *re-verification*, not a re-research — it only re-probes existing citations, cheap.

## 6. Dual-critic-for-citations rationale (explicit)

`BLITZ_DUAL_CRITIC=1 --mode research` already exists. Make the recommendation principled: citation *attribution* is the task where a single model is provably weakest (CiteME: 4.2–18.5% single-model, vs 35.3% tool-augmented, vs 69.7% human). A different-model critic on the §2.5 attribution judgment is exactly the high-value case the self-critique paradox predicts — not optional theater. Recommend dual specifically for any doc with `scope:` claims (sprint-driving), keep single-model for liveness-only re-checks (deterministic, no attribution judgment).

## 7. What stays exactly as-is

- §2.1 URL liveness mechanism, §2.2 Deterministic Quoting, §2.3 date floor, §2.4 source diversity, §2.6 schema presence — all deterministic, all kept verbatim (only §2.1's citation line corrected).
- Read-only, one-reject-reason, "be patient with WebFetch → slow = UNKNOWN not HALLUCINATED," JSON reply + `citation_health[]` array. Untouched.
- The §2.4 source-diversity note cites arxiv 2604.02923 (agent-agreement bias) — left as-is (out of scope for this pass; not re-verified, flag for a future liveness check).

## 8. Registry tie-in

The research-critic's reject set is the `reject`-authority subset relevant to research docs: UNCITED/UNGROUNDED `scope:` claims (blocker), LIKELY_HALLUCINATED URLs (blocker), failed Deterministic Quotes (blocker). UNKNOWN/advisory findings annotate but yield `UNVERIFIED` not `CITATIONS_MISSING`. Same verdict-flip asymmetry as `critic.md`: ground-truth (HTTP status, substring match) flips verdict; attribution judgment (§2.5 grounding) flips only for `scope:` claims (high blast radius), is `major`-advisory elsewhere.
