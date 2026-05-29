---
unit: skills/refactor
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `skills/refactor`

## A. Identity & Boundaries

**One-sentence purpose:** Safe, incremental, test-verified structural refactoring of a target file or module — no behavior changes.

**Description vs body match:** Yes. Description accurately captures "NOT for behavior changes" boundary, atomic steps, test-revert loop. Body fully implements this contract.

**Overlapping skills:**

| Skill | Nature | Dup or Layer? |
|---|---|---|
| `quick` | Handles single-file renames and tiny edits; explicitly defers multi-file refactors to `refactor` | Legitimate layering — scope boundary is clear |
| `code-sweep` | Identifies refactoring candidates (duplication, complexity), then recommends `/blitz:refactor` | Legitimate layering — detection vs execution |
| `code-doctor` | Surfaces extraction candidates, routes to `/blitz:refactor` | Legitimate layering |
| `fix-issue` | Explicitly blocks `refactor` in session-protocol conflict matrix (`fix | refactor | BLOCK`) | Correctly enforced boundary |
| native `/simplify` (v2.1.154) | Cleanup-only review with auto-apply: reuse, simplification, efficiency — **verified in platform-delta.md v2.1.154/2026-05-28** | Partial overlap on "Simplify" refactoring type; native lacks snapshot/revert/metrics; see §D |

No true duplication found.

---

## B. Cohesion

**Cited `_shared` protocols:**
- `session-protocol.md` — cited at Phase 0.0 ✓
- `verbose-progress.md` — cited at Phase 0.0 ✓
- `terse-output.md` — cited via `## Additional Resources` link ✓
- `definition-of-done.md` — cited in Safety Rule 8 ✓

**Absent but applicable protocols:**
- `state-handoff.md` — not cited; `refactor` is a terminal skill (no downstream hand-off), so absence is acceptable
- `story-frontmatter.md` — not applicable (not sprint-family)
- `shortcut-taxonomy.md` — not cited; however, Safety Rules 1-7 manually restate several shortcut detectors inline (drift risk — see §C)
- `ratchet-protocol.md` — not cited; but `refactor` doesn't update ratchet metrics so absence is acceptable
- `token-budget.md` — not cited; single-agent skill, absence acceptable

**Cross-refs live/accurate:**
- `/_shared/session-protocol.md` ✓ (file exists)
- `/_shared/verbose-progress.md` ✓
- `/_shared/terse-output.md` ✓
- `/_shared/definition-of-done.md` ✓
- `/_shared/project-context.md` ✓ (import directive)

**OUTPUT STYLE snippet (Invariant 5):** Present verbatim at line 19. ✓

**Pipeline trace — Phase 4.5 git checkpoint:**
```
git add -A
git stash push -m "refactor-checkpoint-step-<N>"
git stash pop
```
This is a no-op pattern (stash then immediately pop). No useful checkpoint is created. Downstream skills (`codebase-audit`, `test-gen`) would consume the working tree state, which is unaffected by this pattern. Bug — see §F.

**State produced/consumed:** Refactor is consumer-only (reads working tree, emits diffs). No artifact for downstream skills beyond code changes. Consistent with state-handoff.md terminal-skill contract.

---

## C. Conciseness

**Body line count:** 425 lines vs 500-line cap — within limit.

**Prose guarding old-model behavior (mark for deletion):**

1. Lines 33-34: `"NEVER skip verification. Every refactoring step must be followed by type-check + test run. No exceptions."` — anti-laziness nudge; Opus 4.8 honesty gains make "No exceptions" reminder unnecessary. ~2 lines removable.

2. Lines 37: `"Do NOT skip phases."` in the skill header — defensive restatement; 4.8 won't skip phases without prompting. 1 line removable.

3. Lines 36-37: `"Each step is atomic and independently verifiable. If step 3 breaks, you can revert to the state after step 2."` — rationale padding; the revert protocol is already specified in Phase 4. ~5 lines removable.

4. Lines 46-47: Safety Rule 7 ABORT rule duplicates Regression Protocol §Hard abort at line 338. ~5 lines removable.

5. Phase 2.5 "RESEARCH PATTERNS" (lines 189-222) — 34 lines of exemplar-study scaffolding. Partially restates `_shared/project-context.md` stack detection intent. In practice the detect-stack import covers this. Candidate for significant reduction (~20 lines) or extraction to references/main.md.

6. `references/main.md` §Commit Strategy (lines 135-145) — commit message format duplicates what `verbose-progress.md` + conventional-commit hooks already enforce. ~10 lines removable if deferred to hook.

**Estimated removable lines:** ~55 (combining above).

**Content belonging in shared protocol:** Phase 4.5 git checkpoint pattern is generic enough for `_shared/` but too buggy to promote without fix (see §F).

---

## D. Modernization

**Native `/simplify` overlap (platform-delta.md v2.1.154/2026-05-28):**
- Native `/simplify`: cleanup-only, auto-apply, no snapshot/revert/metrics
- `refactor` skill adds: baseline snapshot, per-step type-check + test verification, regression revert, metrics comparison (before/after line count, complexity, exports)

**Verdict: KEEP** with targeted delegation opportunity: for "Simplify" type (Phase 0.3 row 2, risk=Low), could delegate to native `/simplify` and skip Phases 1-4 when test suite is absent. Tradeoff: losing metrics comparison. Not worth full delegation — the verification loop is the skill's core value.

**`disallowed-tools` opportunity (platform-delta.md v2.1.152):** Skill uses `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` but does not set `disallowed-tools`. Could add `disallowed-tools: [WebFetch, WebSearch]` to prevent model from wandering. Low priority; tool set is already tight.

**Model/effort (`model: opus`, `effort: medium`):** Single-agent, no subagents. Opus is expensive for a skill that primarily executes bash + edit loops. Under 4.8 honesty gains, `model: sonnet` with `effort: medium` is sufficient for the structured phase execution. Opus justified only for novel refactoring strategy formation (Phase 3). Suggest `model: sonnet` — saves cost, no loss of correctness. *(Verified: `claude-sonnet-4-6` is current sonnet ID per platform-delta.md 2026-05-28.)*

**Dynamic Workflows (platform-delta.md v2.1.154+):** Refactor is single-agent sequential — workflows don't apply. Subagents-cannot-spawn-subagents constraint irrelevant here.

---

## E. Correctness

**Stale items:**
- `compatibility: ">=2.1.71"` — no reason to hold the old floor; update to `>=2.1.152` to enable `disallowed-tools`. Low priority.
- `model: opus` — should reference `claude-opus-4-8` or switch to `claude-sonnet-4-6` (see §D). Current `opus` alias resolves but is ambiguous across model generations per platform-delta.md 2026-05-28.

**Bug — Phase 4.5 git checkpoint (lines 315-319):**
```bash
git add -A
git stash push -m "refactor-checkpoint-step-<N>"
git stash pop
```
`stash push` followed immediately by `stash pop` is a no-op — no checkpoint is preserved. Correct pattern is either:
- `git commit -m "refactor-checkpoint-step-<N>"` (actual commit), or
- omit the pop and document as a named stash for manual recovery.
This is a correctness bug: the skill claims to provide per-step revert capability but the mechanism doesn't work.

**No dead flags/env vars.** `$ARGUMENTS`, `$CLAUDE_PLUGIN_ROOT` are live.

**No broken paths** in cross-refs (verified above).

**No multi-agent subagent constraint** concerns (single-agent skill).

---

## F. Verdict

**`needs-tightening`**

**Top 3 highest-leverage edits:**

1. **Fix Phase 4.5 git checkpoint bug** — replace stash push/pop no-op with `git commit -m "refactor-checkpoint-step-<N>"` (or remove and revert to `git stash` without pop). Current code silently fails to create checkpoints.

2. **Switch `model: opus` → `model: sonnet`** — single-agent structured execution; Opus adds cost with no correctness benefit under 4.8. Update model frontmatter to `claude-sonnet-4-6` per platform-delta.md 2026-05-28.

3. **Trim Phase 2.5 and Safety Rule redundancy** (~55 lines) — collapse Phase 2.5 to a 3-line note deferring to references/main.md patterns; remove Safety Rule 7 ABORT text (duplicates Regression Protocol); remove "No exceptions" / "Do NOT skip phases" anti-laziness nudges — all guarded behavior the 4.8 model no longer requires forcing.
