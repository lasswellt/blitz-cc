---
title: Effectiveness Research — verified primary sources + corrections
status: spec input (every claim verified live 2026-05-29)
method: each cited source fetched and confirmed; claim-match graded YES | PARTIAL | HALLUCINATED
maps_to: critic-redesign.md, research-critic-redesign.md, review-spec.md, audit-spec.md, flaw-finding-proof.md
---

# Effectiveness Research (v2, corrected)

The v2 prompt grounded its three pillars in ~12 sources. All were probed live on 2026-05-29 (Pillar-C method, applied to our own basis), then **re-verified by a second independent reviewer**. **Most resolved on-claim. Five needed correction; one ("MisCiteBench") is a miscitation — a near-miss for a real but different benchmark, with numbers mis-attributed.** That an unverifiable citation reached the spec is the cautionary tale the whole effort addresses — it is reused as the worked example in `research-critic-redesign.md`. Note the second-order trap the first pass nearly fell into: search-engine summaries *fabricated confirmations* that "MisCiteBench" exists at that exact spelling; only direct `arxiv.org/abs/` fetches gave ground truth. This is precisely why the research-critic rule is **fetch, never trust**.

## Verified source table

| # | Source (corrected) | arxiv/URL | Date | Claim match | Used by |
|---|---|---|---|---|---|
| 1 | "Benchmarking and Studying LLM-based Code Review" (SWRBench) — Zeng, Shi, Han et al. | 2509.01494 | 2025-09-01 | **PARTIAL** — multi-review aggregation real, gain is **+43.67% F1**, NOT "~118% recall"; paper not titled "Multi-Review" | Pillar A aggregation |
| 2 | "On the Self-Verification Limitations of LLMs on Reasoning and Planning Tasks" — Stechly, Valmeekam, Kambhampati | 2402.08115 | 2024-02-12 | YES | Pillar B critic |
| 3 | "SELF-[IN]CORRECT: LLMs Struggle with Discriminating Self-Generated Responses" — Jiang, Zhang, Weller et al. | 2404.04298 | 2024-04-04 | YES | Pillar B ground-truth anchoring |
| 4 | "Merging Improves Self-Critique Against Jailbreak Attacks" — Gallego | 2406.07188 | 2024-06-11 | YES (external/merged critic improves robustness) | Pillar B CMC |
| 5 | "Refute-or-Promote: Adversarial Stage-Gated Multi-Agent Review" (CMC) — Agarwal | 2604.19049 | 2026-04-21 | YES (Cross-Model Critic is a named component) | Pillar B CMC routing |
| 6 | "Detecting and Correcting Reference Hallucinations…" (urlhealth) — Rao, Wong, Callison-Burch | 2604.03173 | 2026-04-03 | **PARTIAL** — real tool, taxonomy is **2-way** (hallucinated vs non-resolving), NOT the 4-way LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN | Pillar C URL liveness |
| 7 | "The Self-Critique Paradox: When AI Verification Fails" — snorkel.ai | snorkel.ai/blog | **2025-11-26** (not Dec) | YES — Sonnet 4.5 98.1%→56.9% (−41.2%), o4-mini 94.2%→78.4% (−15.8%); "15-40%" fair | Pillar B routing |
| 8a | "CiteME: Can LMs Accurately Cite Scientific Claims?" — NeurIPS **2024** | 2407.12861 | **2024** (not 2026) | YES — frontier 4.2–18.5% vs human 69.7%; CiteAgent 35.3% | Pillar C dual-critic |
| 8b | ~~"MisCiteBench"~~ → real artifact **MisciteBench** (BibAgent, Li et al.) and/or **CiteAudit** (substitute) | MisciteBench: 2601.16993 (Jan 2026); CiteAudit: 2602.23452 (Feb 2026) | 2026 | **MISCITATION** (not hallucination) — exact string "MisCiteBench" doesn't resolve, but lowercase **MisciteBench** (2601.16993, 6,350 samples/254 fields) is real; AND the ~4–18% / ~66–80% numbers actually trace to CiteME + CiteAudit/AttributionBench, not to either MisciteBench. So: wrong rendering AND wrong number-attribution. | Pillar C UNKNOWN state |
| 9 | "REFIND at SemEval-2025 Task 3: Retrieval-Augmented Factuality Hallucination Detection" | 2502.13622 | 2025-02 | YES — span/token-level claim-vs-evidence | Pillar C claim-grounding gate |
| 10 | "Citation Drift: Reference Stability in Multi-Turn LLM Conversations" — Seetha Ram | ACL 2025.wasp-main.20 | 2025-12 | YES — up to **85.6%** fabrication (~86%); 29% low-end plausible, not extracted | Pillar C carry-forward drift |
| 11 | "I Tested 15 LLMs on 38 Real Coding Tasks…" — Ian L. Paterson | ianlpaterson.com | 2026-03-08 (upd 2026-05-19) | YES — structural & semantic review catch **disjoint** classes; "neither alone sufficed" | Pillar A two-lane |
| 12 | "Code Review for Claude Code" — Anthropic | claude.com/blog, code.claude.com/docs | research preview ~2026-Q1 | YES — parallel per-issue-class agents + dedicated **validation agent** verifying findings against code, **<1% FP disagreement** | Pillar A FP-verification |

## Corrections folded into the specs

Each correction is a concrete edit obligation, not a footnote:

1. **Drop "~118% recall."** `audit-spec.md` and `flaw-finding-proof.md` state the aggregation benefit as **"+43.67% F1 (SWRBench, 2509.01494)"** and frame the mechanism (consistency across independent runs separates high- from low-confidence findings) rather than a specific recall multiplier. No claim of 118% appears anywhere in the deliverables.
2. **Do not attribute the 4-way URL taxonomy to 2604.03173.** `research-critic-redesign.md` keeps the 4-way LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN scheme but labels it **Blitz's own extension**, citing 2604.03173 only for the underlying hallucinated-vs-resolving distinction. The existing `research-critic.md` line "per the urlhealth taxonomy (arxiv 2604.03173)" is corrected to "extends the urlhealth hallucinated/non-resolving distinction (2604.03173) into a 4-way operational scheme."
3. **Replace MisCiteBench.** Two distinct errors in the original citation: (a) the name "MisCiteBench" is a miscitation of the real **MisciteBench** (2601.16993, BibAgent) — but (b) MisciteBench is not even the right source for the cited numbers. The ~4–18% citation-accuracy figure is **CiteME** (2407.12861); the ~66–80% accessible-vs-inaccessible figure is **CiteAudit (2602.23452)** / AttributionBench. `research-critic-redesign.md` cites those two directly and uses "MisCiteBench" as the quarantined worked **miscitation** example (real-artifact-wrong-rendering + wrong-attribution — the citation-drift class, not pure fabrication).
4. **Fix dates.** CiteME → 2024 (NeurIPS 2024). Snorkel → 2025-11-26. Applied wherever cited.
5. **Soften CMC claim scope.** 2406.07188 is specifically jailbreak-robustness; `critic-redesign.md` cites it for the general "merged/external critic beats self-critique" principle but notes the original domain, and leans on 2604.19049 + Snorkel for the code-review-specific routing rule.

## Claim → spec-change map (the load-bearing part)

| Research finding | Spec change | File |
|---|---|---|
| Lanes catch disjoint bug classes (ianlpaterson) | Both skills MUST run both lanes; registry `lane:` tag makes it selectable | registry-design.md, both specs |
| Aggregation separates high/low-confidence findings (SWRBench +43.67% F1) | `/blitz:audit` runs each semantic pillar with ≥2 independent agents; ≥2 agreers → `confidence:high` | audit-spec.md |
| Validation agent filters FP <1% (native /code-review) | Mandatory FP-verification stage before any blocker; re-read code, confirm reproduces | both specs, critic-redesign.md |
| Self-critique paradox: shared-blind-spot critic degrades 15–41% (Snorkel, 2402.08115) | Opinion-anchored checks → `advisory`, cannot flip verdict; ground-truth checks keep reject authority | critic-redesign.md |
| Self-improvement needs external ground truth (SELF-[IN]CORRECT, 2402.08115) | Keep all deterministic detectors (tsc/git/reflog/ratchet); they are the ground truth | critic-redesign.md |
| External/merged critic beats self-critique (2406.07188, 2604.19049) | `BLITZ_DUAL_CRITIC=1` recommended specifically for semantic/judgment findings | critic-redesign.md, research-critic-redesign.md |
| Citation attribution is model's weakest task: 4–18% (CiteME 2407.12861) | `scope:` claim with no resolvable cite = BLOCKER; dual-critic for citations high-value | research-critic-redesign.md |
| Span-level claim verification is gold standard (REFIND 2502.13622) | Promote claim-grounding advisory → graded gate; verify claim substance in fetched source | research-critic-redesign.md |
| Verification drops to ~66–80% on inaccessible sources (CiteAudit/AttributionBench) | UNKNOWN is first-class: inaccessible source ≠ PASS, ≠ REJECT; report UNKNOWN-rate | research-critic-redesign.md |
| Citation drift 29–86% across turns (Ram 2025) | Re-verify active carry-forward `scope:` citations periodically | research-critic-redesign.md |
| Opus 4.8: 0% uncritical-reporting, perfect lazy-investigation | Down-weight detectors catching model lying about its own work; KEEP deterministic-artifact detectors (honesty-insensitive) | critic-redesign.md |

## Opus-4.8 honesty caveat (explicit reasoning)

4.8's honesty scores lower the yield of detectors that catch *the model misrepresenting its own work* — these are the semantic self-report failures, already `advisory` in the registry (det-05, det-08, det-20). They are NOT cut, only down-weighted, and only with per-detector evidence in `critic-redesign.md`. Detectors that catch *deterministic artifacts the model commits under instruction-following pressure* (det-01 deleted tests, det-02 --no-verify, det-04 as-any, det-11/12 tsc, det-18/19 destructive ops) are **unaffected by honesty**: a more honest model still ships these when an instruction pushes it to. They are kept at full reject authority. The honesty improvement changes the *self-report* surface, not the *artifact* surface.
