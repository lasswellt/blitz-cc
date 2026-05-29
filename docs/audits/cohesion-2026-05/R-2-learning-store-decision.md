---
title: "R-2 decision — learning-store ownership + ratchet-vs-quality-metrics boundary (O16/O17)"
epic: E-033
created: 2026-05-28
verdict: OWNERSHIP ALREADY DEFINED — add cross-refs, no merge
---

# R-2: Coordinate developer-profile.json ↔ KNOWLEDGE.md, and ratchet vs quality-metrics

## Finding (verified)
The audit (O16) called these "uncoordinated," but `knowledge-protocol.md §7` already defines the split:

| Store | Owner doc | Content | Writer | Reader |
|---|---|---|---|---|
| `.cc-sessions/KNOWLEDGE.md` | `knowledge-protocol.md` | project-local durable LESSONS (failures/successes), append-only ≤500 lines, gitignored | retrospective; sprint-review compaction (§5) | autonomous loops (sprint/code-sweep --loop), sprint-dev |
| `.cc-sessions/developer-profile.json` | `session-protocol.md` (autonomy) + retrospective (writer) | per-developer STYLE/autonomy PREFERENCES | retrospective (`SKILL.md:339`) | sprint-dev, ask, conform |
| `.cc-sessions/activity-feed.jsonl` | `verbose-progress.md` | per-session event LOG | every skill | orchestrator, next |

Boundary is real and non-overlapping: **lessons vs preferences vs log.** `knowledge-protocol.md:59` explicitly says style prefs go in developer-profile, not KNOWLEDGE.

## ratchet vs quality-metrics (O17)
| Concern | Owner | Role |
|---|---|---|
| 8 monotonic GATE metrics | `ratchet-protocol.md` (`docs/sweeps/ratchet.json`) | enforced; sprint-review Phase 3.6 Inv 6 blocks on regression; auto-revert |
| metric TRENDS / dashboard | `quality-metrics` (`docs/metrics/`) | informational observability; does NOT gate |

Clear: ratchet = enforced gate, quality-metrics = observability. Dup risk only if ratchet later absorbs lint/type scores — revisit then (already noted in SYNTHESIS O17).

## Verdict: NO merge/retire. Ownership defined.
Gap is discoverability, not coordination. **Action (low-risk):** add an "ownership matrix" cross-ref block to `retrospective/SKILL.md` (the multi-store writer) pointing at `knowledge-protocol.md §7` for the lessons-vs-prefs split, so a future editor doesn't conflate them. O16/O17 resolved.
