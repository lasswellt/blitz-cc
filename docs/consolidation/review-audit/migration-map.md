---
title: Migration Map — current skills → consolidated entry points
status: spec (no files moved in this pass; this is the sequenced map)
backward-compat: every deleted entry point survives as `--only` flag or alias
---

# Migration Map

How each current skill/file moves into the two consolidated entry points + shared registry. Nothing is deleted without a surviving invocation path — the skill *count* drops; user-reachable capability does not.

## Skill disposition

| Current skill | Disposition | New invocation | Notes |
|---|---|---|---|
| `sprint-review` | **becomes review core** | `/blitz:review` | 8-invariant gate + reviewer agents + critic carry forward unchanged |
| `review` (60-line alias) | **promoted to canonical** | `/blitz:review` | the alias becomes the real entry point |
| `completeness-gate` | **folded → review Phase 1.5** | `/blitz:review --only completeness` | SKILL.md removed; O2 patterns move to registry (o2-*) |
| `integration-check` | **folded → review Phase 1.6** | `/blitz:review --only wiring` | SKILL.md removed; sprint-dev 3.5.0 calls the flag; O3 → registry (o3-*) |
| `codebase-audit` | **becomes audit core** | `/blitz:audit` | 5-pillar fan-out + gains aggregation/verify/det-lane/recall-instr |
| `code-doctor` | **folded (review 1.7 + audit 1.D) AND stays standalone** | `/blitz:review --only framework`, `/blitz:code-doctor --fix` | fw-* → registry; standalone retained for `--fix` deep dives |
| `code-sweep` | **Tier-1→review, Tier-2/3→audit, stays standalone** | `/blitz:code-sweep` (loop) | ratchet `/loop` is its distinct tempo — NOT folded; only its checks are shared via registry |
| `implement` (alias) | **unchanged** | `/blitz:implement` | not a quality skill; out of scope |
| `quality-metrics` | **orthogonal — unchanged** | `/blitz:quality-metrics` | audit Phase 4 *calls* it for a snapshot; not folded |
| `dep-health` | **orthogonal — unchanged** | `/blitz:dep-health` | distinct domain (CVE/license) |
| `ui-audit` | **orthogonal — unchanged** | `/blitz:ui-audit` | distinct domain (visual/data) |
| `perf-profile` | **orthogonal — unchanged** | `/blitz:perf-profile` | distinct domain (Lighthouse/bundle) |
| `browse` | **orthogonal — unchanged** | `/blitz:browse` | distinct domain (E2E smoke) |

## Agent disposition

| Agent | Disposition |
|---|---|
| `agents/critic.md` | **sharpened** per `critic-redesign.md` (keep deterministic core; add verdict-flip asymmetry, FP-verify substep, CMC routing, count reconcile, registry-driven §2.1) |
| `agents/research-critic.md` | **sharpened** per `research-critic-redesign.md` (keep deterministic core; promote §2.5 to graded gate, UNKNOWN state, scope-claim blocker, drift re-verify) |
| `agents/reviewer.md` | unchanged — ad-hoc reviewer, used by review Phase 2 |
| `agents/architect.md` | unchanged — used by audit Architecture pillar |

## Shared-protocol edits

| File | Edit |
|---|---|
| `skills/_shared/quality-engine.md` | title "19"→"20 Failure Modes (13 reject, 7 advisory)"; §1 table becomes a *view* of `check-provenance.json`; §3 greps move into registry `detection.command` (the canonical executable source) |
| `skills/review/SKILL.md` | **fix pre-existing bug**: arg-hint line 4 says "7 invariants"; sprint-review enforces **8**. Correct to 8 when promoting the alias to the canonical entry point. |
| `skills/_shared/quality-engine.md` | rewrite for the new 2-entry-point world; the "7 quality skills" framing → "2 review/audit + 5 orthogonal + 2 standalone-tools (code-sweep, code-doctor)" |
| `skills/_shared/agent-orchestration.md` | `codebase-audit` row → `/blitz:audit`; add aggregation + FP-panel as the named net-new patterns |
| new: `skills/_shared/check-registry.json` | the registry (this pass's `check-provenance.json` becomes the shipped artifact) |
| new: `skills/_shared/quality-engine.md` | = `registry-design.md` |

## Backward-compat guarantees

1. **Every removed `/blitz:<skill>` resolves to a `--only` flag** on the consolidated skill (completeness-gate, integration-check) OR stays a real skill (code-doctor, code-sweep). No user script breaks silently — removed names emit a deprecation shim pointing at the flag for ≥1 minor version.
2. **sprint-dev Phase 3.5.0** currently calls `integration-check`; it switches to `/blitz:review --only wiring`. One call-site edit.
3. **ship pipeline** currently chains `sprint-review → completeness-gate → quality-metrics → release`; becomes `review (incl. completeness phase) → quality-metrics → release`. The completeness *scan* runs as review Phase 1.5 (it emits the A–F grade, as completeness-gate does today). The **≥C/70 cutoff is owned by `ship`**, not completeness-gate — `ship` reads review's completeness-phase grade and refuses release below C(70), exactly as it reads completeness-gate's grade today. No threshold logic moves into review; only the *scan* does.
4. **Carry-forward registry + ratchet** are untouched — review Phase 3.6 keeps all 8 invariants. No registry-schema migration.

## Sequenced implementation (the follow-up sprint, behind the suite's own gates)

1. **Epic 1 — registry.** Ship `check-registry.json` + design doc; make `quality-engine.md` a view. No behavior change yet (acceptance: registry parses; every legacy grep has a registry row).
2. **Epic 2 — critic redesign.** Apply `critic-redesign.md` to `agents/critic.md`; registry-drive §2.1; add verdict-flip asymmetry + FP-verify substep. Acceptance: critic loads `reject_only` from registry; advisory finding cannot flip verdict (test).
3. **Epic 3 — research-critic redesign.** Apply `research-critic-redesign.md`. Acceptance: ungrounded `scope:` claim → CITATIONS_MISSING; inaccessible source → UNVERIFIED not PASS.
4. **Epic 4 — /blitz:review.** Fold completeness-gate + integration-check + code-doctor(fw) + code-sweep(T1) as phases; add `--only`; two-lane + FP-verify + confidence gate. Acceptance: `--only completeness` reproduces old completeness-gate output.
5. **Epic 5 — /blitz:audit.** Add aggregation + FP-panel + deterministic lane + recall instrumentation to codebase-audit; rename to `/blitz:audit`. Acceptance: ≥2-agreer finding → confidence:high; coverage_boundary emitted.
6. **Epic 6 — cleanup.** Delete folded SKILL.md files; add deprecation shims; rewrite quality-engine.md; update ship + sprint-dev call-sites.

Each epic's sprint-review runs the **redesigned critic on itself** — Epic 2's output is gated by Epic 2's own critic. The recursion is the point: the consolidation proves out by surviving its own gates.
