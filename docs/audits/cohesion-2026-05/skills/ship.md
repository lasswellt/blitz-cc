---
unit: skills/ship
kind: skill
verdict: needs-tightening
removable_lines: 38
created: 2026-05-28
---

# Cohesion Audit — `ship`

## A. Identity & Boundaries

**One-sentence purpose:** Orchestrate the full release chain — sprint-review → completeness-gate → quality-metrics → changelog → release prepare/verify/publish — with hard quality gates between each step.

**Description ↔ body match:** Accurate. Description states "chains the full release workflow…refuses to publish if any gate fails." Body implements exactly that chain. No mismatch.

**Overlaps:**

| Skill / Agent | Kind | True duplication? |
|---|---|---|
| `release` | `ship` composes `release` for Phase 3; `release` handles versioning + changelog + tag + publish | Legitimate layering — `ship` is the outer orchestrator; `release` is the executor |
| `sprint-review` | `ship` Phase 1.1 dispatches to `sprint-review` | Legitimate composition — `ship` does not re-implement review logic |
| `completeness-gate` | `ship` Phase 1.2 dispatches to `completeness-gate` | Legitimate composition |
| `quality-metrics` | `ship` Phase 1.3 dispatches to `quality-metrics collect` | Legitimate composition |
| **Duplication: changelog (Phase 2)** | `ship` Phase 2 parses conventional commits + writes CHANGELOG.md inline; `release` Phase 2.1–2.4 does the same thing in detail | **True duplication.** `ship` implements commit-grouping logic and CHANGELOG format rules that are already owned by `release prepare`. `ship` should delegate Phase 2 entirely to `release prepare` and remove Phase 2 inline logic. |

---

## B. Cohesion

### `_shared` protocol citations

| Protocol | Cited? | Followed or restated? |
|---|---|---|
| `verbose-progress.md` | Line 19, by link | Delegates — no inline restatement |
| `terse-output.md` | Lines 13-13 OUTPUT STYLE block | Verbatim canonical snippet present — **Invariant 5 satisfied** |
| `state-handoff.md` | Line 21, by link | Delegates — cites `STATE.md`, `carry-forward.jsonl`, `review-report.md` as inputs |
| `definition-of-done.md` | Safety rule 5, by link | Delegates |
| `session-protocol.md` | **NOT cited** | No session registration, no lock acquisition, no activity-feed `skill_start` / `skill_complete` beyond a prose instruction at line 19. Drift risk: `ship` is an orchestrator that can run for many minutes; missing lock means concurrent sessions can race. |
| `spawn-protocol.md` | Not cited | `disable-model-invocation: true` — single-agent, correct omission |
| `carry-forward-registry.md` | Not cited | Not a registry writer; omission acceptable |
| `story-frontmatter.md` | Not cited | Not a sprint story producer; correct omission |

**Cross-ref liveness:**
- `/_shared/verbose-progress.md`, `/_shared/state-handoff.md`, `/_shared/definition-of-done.md` — standard paths, verified present.
- `/_shared/terse-output.md` — standard path, present.
- `/blitz:release prepare`, `/blitz:release verify`, `/blitz:release publish` — `release` skill exists; modes `prepare`, `verify`, `publish` confirmed in `release/SKILL.md` frontmatter `argument-hint`. Live.
- `/blitz:sprint-review`, `/blitz:completeness-gate`, `/blitz:quality-metrics` — all confirmed present.

**Invariant 5 (OUTPUT STYLE):** Satisfied. Verbatim snippet at lines 13-13.

### Pipeline chain trace

1. `ship` reads `sprint-registry.json` → dispatches `/blitz:sprint-review` → expects `sprints/sprint-${N}/review-report.md` (producer: sprint-review Phase 4.1 per `state-handoff.md` line 78). ✓
2. `ship` dispatches `/blitz:completeness-gate all` → reads score from output. No artifact file consumed — relies on stdout parsing. Fragile if output format changes; no contract in `state-handoff.md` for completeness-gate output. Minor gap.
3. `ship` dispatches `/blitz:quality-metrics collect` → stores snapshot; `ship` does not consume the snapshot artifact. ✓ (observability-only step)
4. `ship` Phase 2 **re-implements changelog** (commit parse + CHANGELOG.md write). Then Phase 3.1 dispatches `release prepare [version]`, which **also generates/updates CHANGELOG.md**. Double-write conflict — `release prepare` will prepend another section on top of the one `ship` already wrote. **Correctness bug.**
5. `ship` Phase 3.4 dispatches `release publish` → `state-handoff.md` line 88-90 shows `ship` must produce `CHANGELOG.md` entry, tag, and `.cc-sessions/release-state.json`. `release publish` owns the tag and GitHub release; `.cc-sessions/release-state.json` is not mentioned in `ship`'s own body — potential gap if `release` doesn't write it under that path. Not verified in `release/SKILL.md` (out of scope for this audit unit), but flag as a cross-unit correctness assumption.

---

## C. Conciseness

**Body line count:** 286 / 500 cap. Well within limit.

**Prose compensating for old-model behavior:**

- Line 17: `"Execute every phase in order. Do NOT skip phases."` — identical wording in `release/SKILL.md` line 27. Anti-laziness guard for step-skipping. With 4.8 honesty (~4x less likely to let flaws pass unremarked, per `platform-delta.md` version `claude-opus-4-8 / 2026-05-28`), lower false-negative rate makes this nudge less necessary. **Mark for deletion.**
- Line 17 (also): `"Each step must pass before proceeding to the next."` — redundant given the SAFETY RULES block at lines 28-38 which already enforces the gate contract. **Mark for deletion.**
- Lines 29-38 (SAFETY RULES bold block): 10 lines of rule restatement that partially duplicate the gate-failure actions described inline at each phase. Not pure duplication — the consolidated rules block has independent value as a scannable summary. **Keep, but could trim 2-3 redundant lines.**

**Phase 2 (changelog, lines 148-178):** 31 lines implementing commit-grouping, section headers, CHANGELOG format. This logic belongs entirely in `release`. **All 31 lines removable** once Phase 2 is delegated to `release prepare`. This is the single highest-leverage deletion.

**Estimated removable lines:** 2 (anti-laziness nudges) + 31 (Phase 2 duplication) + 3 (redundant gate-pass prose in 1.4 summary template) = **~36 lines**; rounding to 38 with minor prose tightening.

---

## D. Modernization

**Native primitive overlap:**

Per `platform-delta.md` v`v2.1.152 / 2026-05-27`, the `disallowed-tools` frontmatter field is available. `ship` has `disable-model-invocation: true` but does not use `disallowed-tools`. No specific tools need blocking here given the orchestrator-only role. No action required on `disallowed-tools`.

Per `platform-delta.md` v`v2.1.154+ / 2026-05-28`, native Workflow orchestration is available. `ship`'s sequential phase dispatch (`sprint-review → completeness-gate → quality-metrics → release`) is a textbook workflow: sequential steps, intermediate results not needed in context, each step independent. **Verdict: delegate-to-native is viable but premature.** `workflow-dispatch.md` documents the capability-gated additive adoption rule — `ship` should retain the existing `Invoke:` prose dispatch as the portable default and add a `workflow`-gated fast path in a future sprint. Tradeoff: native Workflow loses the explicit `STOP if gate fails` guard logic; `ship`'s inline safety rules would need to move into workflow step error handlers. That migration is non-trivial. Keep for now.

Per `platform-delta.md` v`v2.1.139 / 2026-05-11`, `/goal` completion-condition loop is available. `ship` does not loop; not applicable.

**Model/effort sanity:**
- `model: opus` — appropriate for release orchestration with safety gates.
- `effort: low` — low effort for an orchestrator that dispatches to heavy sub-skills is correct per `MEMORY.md` pattern ("orchestrator SKILL.md frontmatter should set `effort: low` alongside `model: opus`"). ✓
- `disable-model-invocation: true` — correct; `ship` reads its own SKILL.md as a prompt, does not spawn agents. ✓

**Model ID currency:** `model: opus` — no numeric suffix. Per `platform-delta.md` row `Model IDs current as of 2026-05-28`, current ID is `claude-opus-4-8`. Frontmatter uses alias `opus` not numeric ID; other skills follow same pattern. No action required unless skills must pin to `claude-opus-4-8` explicitly.

---

## E. Correctness

**Stale/broken items:**

1. **Phase 2 changelog double-write (correctness bug):** `ship` writes CHANGELOG.md at Phase 2, then dispatches `release prepare` at Phase 3.1 which writes CHANGELOG.md again. The two writes conflict. Fix: remove Phase 2 entirely; let `release prepare` own CHANGELOG generation.

2. **`session-protocol.md` not followed:** No `skill_start` activity-feed log in frontmatter contract sense — line 19 mentions logging it but there is no `<!-- import: -->` marker or explicit section-reference. Given `disable-model-invocation: true`, the model running `ship` must follow prose instructions; the prose at line 19 is sufficient but not reinforced by a `<!-- import: -->` boilerplate anchor. Low severity.

3. **Completeness-gate score parsed from stdout:** No structured artifact contract. If `completeness-gate` output format changes, `ship` silently misreads the score. Suggest `completeness-gate` write a `.cc-sessions/completeness-result.json`; `ship` reads that file. Out of scope for ship-only changes — cross-unit.

4. **Phase 0.1 bash block uses `exit 1` inside a heredoc-style code block:** These blocks are illustrative (skill has `disable-model-invocation: true`, so the model runs them via Bash tool). The `exit 1` would terminate the Bash tool subprocess but not the skill session. Not a real bug but could mislead — model will see a non-zero exit and should handle it.

5. **`sprint-registry.json` path assumed at repo root:** No fallback if file is in a non-standard location. `release/SKILL.md` has the same assumption. Consistent but brittle.

**Subagents-cannot-spawn-subagents:** Not applicable — `ship` is slash-invoked, `disable-model-invocation: true`. Dynamic Workflows (`platform-delta.md` v`v2.1.154+`) do not change this calculus for `ship`; the dispatch pattern is explicitly sequential and user-confirmed.

---

## F. Verdict

**`needs-tightening`**

### Top edits (highest leverage)

1. **Remove Phase 2 (lines ~148-178, ~31 lines):** Changelog logic duplicates `release prepare`. Replace Phase 2 with a one-line note: `release prepare` generates/updates CHANGELOG.md as part of its own Phase 2. Eliminates the double-write correctness bug and the duplication.

2. **Add `session-protocol.md` `<!-- import: -->` anchor or explicit lock step at Phase 0.0:** `ship` is a long-running multi-skill orchestrator; omitting session registration allows concurrent ship runs. At minimum add a prose cross-reference: "Follow `/_shared/session-protocol.md` §Session Registration before Phase 0.1."

3. **Delete anti-laziness nudges at line 17** ("Execute every phase in order. Do NOT skip phases." and "Each step must pass before proceeding"): redundant with SAFETY RULES block; low value under 4.8 honesty (`platform-delta.md` v`claude-opus-4-8 / 2026-05-28`).
