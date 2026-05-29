---
unit: skills/release
kind: skill
verdict: needs-tightening
removable_lines: 45
created: 2026-05-28
---

# Cohesion Audit — `release`

## A. Identity & Boundaries

**One-sentence purpose:** Manage semantic versioning, changelog generation, quality verification, tagging, and GitHub releases in four sequential modes (prepare / verify / publish / rollback).

**Description ↔ body match:** Accurate. Description lists the four modes, names `/blitz:ship` as the caller, and the body implements exactly those phases.

**Overlaps:**

| Skill / Agent | Kind | True duplication? |
|---|---|---|
| `ship` | Composes `release` as its final step; adds sprint-review → completeness-gate → quality-metrics chain upstream | Legitimate layering — `ship` is the orchestrator, `release` is the executor |
| `completeness-gate` | Phase 4.6 optionally invokes completeness-gate | Legitimate — `release` delegates, does not re-implement |
| `sprint-review` | `ship` also runs sprint-review before reaching `release` | No overlap inside `release` itself |

No true duplication found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited? | Followed or restated? |
|---|---|---|
| `session-protocol.md` | Phase 0.0 explicit | Delegates: "Follow … §Session Registration (steps 1-9)" — no inline restatement |
| `verbose-progress.md` | Phase 0.0 explicit | Delegates |
| `terse-output.md` | Line 21 OUTPUT STYLE snippet | Verbatim canonical snippet present — **Invariant 5 satisfied** |
| `state-handoff.md` | Not cited | `release` does not produce/consume sprint-pipeline artifacts; omission correct |
| `story-frontmatter.md` | Not cited | N/A — not a sprint story producer |
| `spawn-protocol.md` | Not cited | `release` is single-agent (`disable-model-invocation: true`); correct omission |
| `definition-of-done.md` | Safety rule 8 links it | Delegates |

**Cross-ref liveness:** All `/_shared/` references are standard paths. `references/main.md` is present and substantive. `SESSION_TMP_DIR` used at Phase 3.4 and 5.5 — matches canonical path `.cc-sessions/${SESSION_ID}/tmp/` defined in `session-protocol.md` §Session Registration step 8. No broken paths detected.

### Pipeline chain trace (prepare → verify → publish)

1. `release prepare` writes `CHANGELOG.md`, bumps `package.json`, commits on `release/vX.Y.Z` branch, writes `${SESSION_TMP_DIR}/release-notes.md`.
2. `release verify` reads `package.json` scripts, runs type-check/lint/test/build. No artifact consumed from step 1 beyond the branch state — coherent.
3. `release publish` reads `${SESSION_TMP_DIR}/release-notes.md` via `--notes-file`. Depends on artifact created in step 1 persisting across mode invocations. **Fragility:** if the user runs `verify` and `publish` in separate sessions, `SESSION_TMP_DIR` won't exist. SKILL.md does not warn about this. Minor correctness gap.
4. `/blitz:ship` invokes `release prepare [version]` then `release verify` then `release publish` in the same session — chain holds for ship's use case. Direct user invocations split across sessions are not guarded.

---

## C. Conciseness

**Body line count:** 485 / 500 cap. Near-cap — tightening advised before any feature additions.

**Prose that compensates for old-model behavior (anti-laziness nudges):**

- Line 27: `"Execute every phase in order. Do NOT skip phases."` — repeated in `ship/SKILL.md` line 17 with identical wording. Defensive instruction for models that skip steps. With 4.8 honesty, lower false-negative rate means this warning is less necessary. **Mark for deletion or reduction.**
- Lines 35–50 (SAFETY RULES block): All 8 rules are operationally valid and safety-critical (force-push tags, major bump confirmation, push confirmation). **Not anti-laziness prose — keep.** These enforce user-safety invariants that must remain explicit.
- Line 296–324 (`references/main.md` quality-gate thresholds table): Duplicates Phase 4 gate logic in SKILL.md. References file holds the canonical skip conditions; SKILL.md also describes skip conditions at Phase 4.4 ("warnings are acceptable"). Minor DRY violation — both files define the same lint pass condition. **Removable from SKILL.md body** (~6 lines).

**Content belonging in shared protocol:**
- Phase 1.1–1.4 (current version, latest tag, commit-log bash snippets) — repo-discovery boilerplate. Could move to a `_shared/release-context.md` if other skills need it. Currently no other skill does, so premature extraction.

**Estimated removable lines:** ~45 (line 27 + anti-laziness duplicate in Phase 0, 6-line gate-threshold duplication, ~35 lines of verbose Error Recovery section that partially mirrors `references/main.md` rollback procedure).

---

## D. Modernization

### Native primitives (platform-delta.md citations)

| Claim | platform-delta.md entry | Verdict |
|---|---|---|
| `disable-model-invocation: true` in frontmatter | v2.1.152 `disallowed-tools` field (different feature, same version band) | **Keep** — `disable-model-invocation` suppresses model call entirely for orchestrator-dispatched invocation; not the same as `disallowed-tools` |
| Quality gates (type-check, lint, test, build) reimplemented as bash | No platform-delta entry covers native gate primitives | **Keep** — no native equivalent |
| `gh release create` usage | No platform-delta entry | **Keep** — correct delegation to gh CLI |
| `/blitz:completeness-gate` invocation in Phase 4.6 | No native completeness primitive in platform-delta.md | **Keep** |

No `delegate-to-native` candidates found in platform-delta.md v2026-05-28.

**`disallowed-tools` opportunity (platform-delta.md v2.1.152):** `release` only needs `Read, Write, Edit, Bash, Glob, Grep`. It already lists these in `allowed-tools`. The `disallowed-tools` field could reinforce shortcut-taxonomy blockers (e.g., block `WebFetch` to prevent external network calls during release). Low priority but zero-cost.

**Model/effort frontmatter:** `model: opus, effort: medium`. Under 4.8 + fast mode (platform-delta.md `fast-mode-2026-02-01`): release is a sequential, low-reasoning workflow. Opus is over-spec'd; `sonnet` would suffice for all phases. However, CLAUDE.md memory note states `model: sonnet/haiku` skills crash from `[1m]` parents — opus + disable-model-invocation is the safe combination here since `ship` inherits context. **Keep opus until MEMORY note is resolved.**

---

## E. Correctness

**Stale version refs:** Frontmatter `compatibility: ">=2.1.71"` — no features used require anything beyond 2.1.71. Compatible.

**Model IDs:** Frontmatter uses `model: opus` (alias), not `claude-opus-4-8`. platform-delta.md (2026-05-28) lists canonical ID as `claude-opus-4-8`. Alias likely resolves correctly but should use canonical ID per audit standard.

**`SESSION_TMP_DIR` cross-session fragility:** documented in §B above. `publish` mode should validate the notes file exists and fall back to regenerating it from CHANGELOG.md.

**Phase 4.7 grep command:** `grep -r "X.Y.Z" package.json plugin.json marketplace.json` — grep `-r` on individual files is a no-op (recursive has no effect on explicit file args) but harmless. Minor.

**Phase 5.6 merge-back push:** `git push origin main` after `git merge release/vX.Y.Z --no-edit` has no confirmation gate. Safety Rule 6 ("NEVER push to remote without user confirmation") is violated here — no prompt before `git push origin main`. **Correctness bug.**

**Subagents-cannot-spawn-subagents:** N/A — `disable-model-invocation: true`, single-agent execution. Dynamic Workflows (platform-delta.md v2.1.154+) don't affect this skill.

---

## F. Verdict

`needs-tightening`

### Top edits (highest leverage)

1. **Fix Safety Rule 6 violation in Phase 5.6:** Add explicit `"Merge to main and push? [y/n]"` prompt before `git push origin main`. Current code pushes without confirmation, violating the skill's own non-negotiable safety rule.

2. **Guard cross-session `SESSION_TMP_DIR` in publish mode:** Phase 5.1 pre-publish validation should check `${SESSION_TMP_DIR}/release-notes.md` exists; if not, regenerate from the CHANGELOG.md section for the release version. Failing silently on a missing notes file produces a `gh release create` error with no user-facing guidance.

3. **Remove ~45 lines of anti-laziness / duplicate-threshold prose:** Line 27 `"Do NOT skip phases"`, the Error Recovery entries that mirror `references/main.md` rollback procedure verbatim, and the lint-pass-condition restatement. Trim body below 450 lines to create headroom.
