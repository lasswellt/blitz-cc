---
title: agents/critic.md — Redesign Spec
target: agents/critic.md (247 lines today; sharpen, do not rewrite)
principle: critique anchored on external tools works; critique anchored on the model's opinion does not
status: spec (implementation = follow-up sprint, reviewed by this very critic)
---

# Critic Redesign

The critic is already good: §2.1–2.8 rest on `git`, `tsc`, ratchet arithmetic, reflog, and import resolution — ground truth, not opinion. The redesign **keeps the deterministic core intact** and makes three things explicit that are currently implicit: (1) per-detector ground-truth vs judgment classification, (2) the verdict-flip asymmetry, (3) principled CMC routing tied to the self-critique paradox. Plus housekeeping: the 19-vs-20 count.

## 1. Per-detector decision table

`keep` = full reject authority retained. `advisory` = may only append to `issues[]`, never flip verdict. `down-weight` = kept but flagged lower-yield under Opus 4.8 honesty (still advisory). Evidence column states *why* each lands where it does.

| Check | Anchor | Honesty-sensitive? | Decision | Evidence |
|---|---|---|---|---|
| det-01 deleted tests | git diff (ground truth) | No | **keep** | artifact, not self-report; committed under instruction pressure regardless of honesty |
| det-02 --no-verify | reflog (ground truth) | No | **keep** | deterministic artifact |
| det-03 mock count | grep count + ratchet | No | **keep** | arithmetic |
| det-04 as-any/@ts-ignore | grep + ratchet | No | **keep** | artifact; honesty-insensitive |
| det-05 swallow-catch | regex (intent-ambiguous) | Partial | **advisory** | rethrow-vs-swallow is judgment; regex can't tell |
| det-06 env fallback | grep + ratchet | No | **keep** (ratchet delta) | arithmetic on delta |
| det-07 hardcoded creds | grep + entropy | No | **keep** (FP-verify first) | artifact; verify before blocker |
| det-08 commented assertions | diff grep | Partial | **advisory** | could be legit cleanup |
| det-09 not-implemented | grep | No | **advisory** (review gate); hard gate in ship | high-base string artifact, but advisory *authority* in the sprint gate — a WIP stub mid-sprint isn't a sprint-blocker; `ship`'s ≥C/70 completeness gate makes it blocking |
| det-10 empty stubs | grep (high FP) | No | **advisory** | `return {}` legit in many contexts → FP-verify |
| det-11 hallucinated APIs | **tsc / import resolution** | No | **keep** | survey miscalled this "semantic"; it is tsc-anchored ground truth — strongest check |
| det-12 broken build | tsc count | No | **keep** | arithmetic |
| det-13 .skip/.only/xit | grep | No | **keep** | artifact |
| det-14 test renamed away | git --diff-filter=R | No | **keep** | artifact |
| det-15 hardcoded localhost | grep | No | **keep** (FP-verify) | artifact; config FP risk |
| det-16 orphaned files | import-graph | No | **advisory** | entrypoints legitimately unimported |
| det-17 infinite-fix loop | counter | No | **advisory** | operational signal, not a code defect |
| det-18 destructive SQL | command parse | No | **keep** | catastrophic class |
| det-19 git reset --hard | command parse | No | **keep** | catastrophic class |
| det-20 unverified audit claim | grep on Evidence field | **Yes** | **down-weight + advisory** | catches the model under-evidencing its own audit output — exactly the self-report surface Opus 4.8 improved on; keep as advisory, do not promote |

**Cut: none.** No detector is removed. Opus 4.8 honesty *down-weights* the three self-report detectors (det-05, det-08, det-20) but does not eliminate them — instruction-following pressure can still produce these even from an honest model, and the cost of keeping an advisory check is near-zero (it can't flip a verdict). Cutting would require per-detector evidence that the failure mode no longer occurs; we have evidence of *reduced self-misrepresentation*, not *zero artifact production*.

**Authority tally (corrected):** of the 20 detectors, **13 carry reject authority and 7 are advisory** (det-05, det-08, det-09, det-10, det-16, det-17, det-20). The decision table above marks exactly these 7 `advisory`; all other rows are `keep` (reject). This matches `check-provenance.json` row-for-row.

## 2. Verdict-flip asymmetry (the core proof)

The critic's §2.1–2.8 already halt-on-first-REJECT. The redesign states the invariant the code must satisfy:

```
verdict = REJECT   iff   ∃ check c : c.fired ∧ c.verdict_authority == 'reject'
advisory findings   →   issues[] only; NEVER change verdict
```

**Proof of soundness (no false REJECT from judgment):** every `reject`-authority check is ground-truth-anchored (deterministic lane, or tsc/reflog/git/ratchet). A ground-truth check firing is a *fact* (a test was deleted; `tsc` errors increased; a commit bypassed hooks), not an opinion. Therefore a REJECT is always backed by a reproducible artifact. The self-critique paradox (Snorkel 2025-11-26; arxiv 2402.08115) bites only opinion-anchored verification — which is structurally barred from the verdict here. **The "bias toward rejection — if unsure, REJECT" rule (§4 of critic.md) is therefore correct AND safe: it applies only to ground-truth checks, where "unsure" means "the artifact is ambiguous," and a false REJECT costs one re-run.** For advisory checks, an over-eager critic would hallucinate flaws (paradox), so they cannot flip the verdict — the asymmetry neutralizes the paradox without losing the cheap-false-REJECT benefit on facts.

**Edit to critic.md §4:** add one line — *"Bias toward rejection applies to §2.1–2.8 (ground-truth) only. §2.9 and any registry `advisory` check append to issues[] and never set verdict=REJECT."*

## 3. FP-verification (new sub-step, native /code-review parity)

Before emitting REJECT on a check whose `base_confidence < 1.0` (det-07, det-10, det-15, and any semantic finding handed up from review/audit), the critic runs a verification pass: re-read the cited file:line, confirm the flaw *reproduces against actual code behavior* (not just pattern presence), and attach the reproducing excerpt to the issue's `what`. A finding with no reproducing evidence is downgraded to `advisory` (cannot flip verdict). Mirrors native `/code-review`'s validation agent (<1% FP disagreement, source #12). Detectors with `base_confidence == 1.0` (tsc, reflog, git) skip this — the mechanism is the verification.

## 4. CMC routing rule (principled, paradox-tied)

Current §5 offers three modes via env var but no guidance on *when*. The redesign adds the rule:

| Finding class | Default critic | Rationale |
|---|---|---|
| Ground-truth checks (det-01..19 reject set) | **in-Claude** (cheapest) | no blind-spot risk — `tsc`/`git` don't share the generator's blind spots; a second model adds cost, not signal |
| Semantic / judgment findings (sem-* pillars, det-20, advisory set) | **`BLITZ_DUAL_CRITIC=1` recommended** | self-critique paradox: home-model blind spots bite hardest here; external/merged critic improves robustness (2406.07188, 2604.19049) |
| High-stakes release gate (audit pre-release) | **`BLITZ_DUAL_CRITIC=1`** | recall-biased context; cost of a false LGTM is highest |

**Edit to critic.md §5:** replace the bare mode table with the above routing rule, citing Snorkel + 2604.19049. Note 2406.07188's original domain (jailbreak) when citing it for the general principle.

## 5. Count reconciliation

Apply the canonical phrasing everywhere: **"20 catalogued detectors (det-01…20; det-20 appended 2026-05-16). 13 carry reject authority, 7 advisory (det-05/08/09/10/16/17/20)."** The retired "19 blocking + 1 advisory" phrasing was wrong (6 of det-01…19 are advisory too).
- `critic.md` description line "any of the 19 documented autonomous-coder failure modes" → "any of the 20 catalogued failure modes (13 reject-authority, 7 advisory; see check-provenance.json)."
- `critic.md §2.1` heading "Shortcut taxonomy (19 detectors)" → "(20 detectors; 13 reject, 7 advisory)."
- LGTM summary "No reject signals found across 8 critic checks" → keep "8" — it counts the 8 reject-checklist *classes* §2.1–2.8, which is distinct from the 20 detectors. Optionally append "(20 registry detectors; 13 reject-authority enforced via these 8 classes)."
- `quality-engine.md` title "19 Autonomous-Coder Failure Modes" → "20 Autonomous-Coder Failure Modes (13 reject, 7 advisory)."

## 6. Registry-driven, not inline

The critic's §2.1 grep block is replaced by *loading `reject_only` from check-provenance.json* and running each check's `detection.command`. No grep pattern lives in `critic.md` anymore — it cites `det-NN`. This removes the duplication between `critic.md §2.1`, `quality-engine.md §3`, and the hook scripts, killing the drift class. The eight checklist *sections* (§2.1–2.8) remain as the human-readable run order; their contents come from the registry.

## 7. What stays exactly as-is

- Read-only constraint, halt-on-first-REJECT, one-reject-reason, JSON reply contract (§3). All well-designed; untouched.
- §2.5 story `acceptance_checks` execution — already ground-truth (executes declared predicates). Keep.
- The "evidence over opinion" constraint (§4) — now formally enforced by the verdict-flip asymmetry.

**Note on critic.md section numbering:** the real `critic.md` already has **§2.1–§2.8** (the 8 reject-checklist *classes*, all ground-truth/reject-authority) **plus §2.9** ("Audit-finding integrity (detector #20, advisory)"). When this spec says "the 8 critic checks" it means §2.1–2.8; §2.9 already exists as the advisory section and is the home for det-20. §2.9 is not new — the redesign only re-points it at the registry. det-20's `enforcement: ["critic:2.9"]` therefore resolves to a real section.
