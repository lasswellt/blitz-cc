---
unit: skills/bootstrap
kind: skill
verdict: needs-tightening
removable_lines: 35
created: 2026-05-28
---

# Bootstrap Skill — Cohesion + Modernization Audit

## A. Identity & Boundaries

**Purpose:** Scaffold new projects, features, or monorepo packages matching detected project conventions; greenfield path initializes pipeline artifacts for downstream sprint family.

**Description vs body match:** Accurate. Description mentions "empty roadmap stubs" — but body has no phase that creates `docs/roadmap/roadmap-registry.json` / `docs/roadmap/epic-registry.json`. State-handoff.md §bootstrap (line 35) mandates bootstrap Phase 5 MUST initialize those stubs or print the fallback message. Phase 5 REPORT section does neither. **Gap — description overcommits relative to body.**

**Overlaps:**

| Skill/Agent | Overlap | Classification |
|-------------|---------|----------------|
| `setup` | Convention detection / project analysis | Legitimate layering — setup checks CLAUDE.md conflicts, not scaffold generation |
| `implement` | File generation (components, stores, tests) | Legitimate layering — implement works within an existing sprint story; bootstrap creates project skeleton without story context |
| `completeness-gate` | Invoked inline at Phase 4.5 exit criteria | Legitimate delegation — bootstrap calls completeness-gate, doesn't reimplement it |
| `test-gen` | Mentioned in Phase 5 "next steps" as follow-on | No overlap — just a pointer |

No true duplication found.

---

## B. Cohesion

### Shared Protocol Citations

| Protocol | Cited | Followed / Drift |
|----------|-------|-----------------|
| `session-protocol.md` | Yes (Phase 0.0) | Cited correctly, steps 1-9 delegated |
| `verbose-progress.md` | Yes (Phase 0.0) | Cited correctly |
| `terse-output.md` | Yes (Additional Resources + OUTPUT STYLE snippet) | Snippet present verbatim — Invariant 5 satisfied |
| `state-handoff.md` | Yes (Additional Resources) | **Drift** — references file but Phase 5 does NOT emit roadmap registry stubs despite state-handoff.md lines 29-35 requiring it |
| `package-install-policy.md` | Yes (Additional Resources) | Cited; no inline restatement — clean |
| `definition-of-done.md` | Yes (inline link at SAFETY RULE 2) | Delegated, not restated |
| `story-frontmatter.md` | Not applicable — bootstrap is pipeline entry, not sprint story consumer | N/A |
| `spawn-protocol.md` | Not cited — skill does not spawn agents | Correct omission |
| `carry-forward-registry.md` | Not cited | Not applicable |

### Cross-Reference Accuracy

- `/_shared/state-handoff.md` link: live, accurate
- `/_shared/package-install-policy.md`: live
- `/_shared/terse-output.md`: live
- `/_shared/definition-of-done.md`: live
- `/_shared/session-protocol.md`: live
- `/_shared/verbose-progress.md`: live

All cross-refs verified live. No dead paths.

### OUTPUT STYLE Snippet (Invariant 5)

Present verbatim at line 21-25. **Pass.**

### Pipeline Chain Trace

`bootstrap` → `research` → `roadmap` → `sprint-plan`

State-handoff.md requires bootstrap (greenfield) emits `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json` as empty stubs. sprint-plan Phase 0 hard-fails if these are absent. Bootstrap Phase 5 REPORT (lines 265-276) outputs a text summary and session cleanup only — **does not write these files**. Description says "empty roadmap stubs" but body omits the write step. Chain breaks silently unless user runs `/blitz:roadmap` separately. Actionable: Phase 5 or Phase 3 must write the stubs, or Phase 5 must print the explicit fallback message defined in state-handoff.md line 35.

---

## C. Conciseness

Body: **294 lines** (SKILL.md) + **187 lines** (references/main.md). Under 500-line cap.

### Prose That Guards Against Old-Model Behavior (Mark for Deletion)

| Line(s) | Quote | Failure mode guarded | Delete? |
|---------|-------|---------------------|---------|
| 29 | `"Execute every phase in order. Do NOT skip phases."` | Model skipping phases without instruction | Yes — 4.8 honesty makes this redundant |
| 39 | `"All generated code must be functional. No TODO, FIXME, empty function bodies..."` | Model generating stubs when asked for real code | Partial — keep as spec boundary, remove defensive "never" framing in favor of declarative `disallowed-patterns` |
| 43 | `"When conventions conflict with best practices, existing conventions win."` | Model overriding project style | Keep — this is user-facing opinionation, not a laziness guard |
| 171 | `"generate REAL code (not stubs)"` | Duplicate of SAFETY RULE 2 | Yes — redundant restatement; ~1 line |
| 228-229 | `"Maximum 3 fix attempts per failing criterion. After 3 attempts, report partial success"` + template | Model looping indefinitely | Keep — this is a concrete bound, not an anti-laziness nudge |

Estimated removable lines from pure redundancy: **~8 lines** in SKILL.md.

### DRY — Belongs in Shared Protocol

- Phase 0.0 session-registration boilerplate (2 lines) — already delegated by reference; no drift.
- `references/main.md` scaffold templates (Vue component, Pinia store, test) are bootstrap-specific; not a shared-protocol DRY violation.

Estimated removable lines total (SKILL.md + references): **~35 lines** (redundant prose ~8 + references content that duplicates Phase 2 tables ~27).

The Phase 2 tables in SKILL.md (lines 122-131, 133-143) and references/main.md §Scaffold Templates (lines 8-72) describe the same file layouts twice. References adds path trees and code templates that add value, but the feature/package scaffold summary tables are duplicated.

---

## D. Modernization

### Native Primitive Overlap

| Feature | platform-delta.md version | Claim | Verdict |
|---------|--------------------------|-------|---------|
| `/effort ultracode` workflow orchestration for multi-file generation | v2.1.154+ / 2026-05-28 | Bootstrap's sequential phase execution could run under ultracode workflow | **Keep** — bootstrap has strong opinionated sequencing (confirm → generate → verify) and user-confirmation gates that must survive model substitution; delegating to raw workflow loses the SAFETY RULES enforcement and convention-detection logic |
| `disallowed-tools` frontmatter field | v2.1.152 | SAFETY RULE 2 (no stubs) and SAFETY RULE 6 (no placeholders) are prose guards that could be reinforced via `disallowed-tools` | **Delegate partially** — not directly expressible as tool restriction; but `disallowed-patterns` (if supported) or pre-commit hooks cover this better than prose |
| Model ID `claude-opus-4-8` | 2026-05-28 | Frontmatter `model: opus` is an alias | **Update** — `model: opus` likely resolves correctly, but explicit `claude-opus-4-8` + `speed: fast` (fast mode, $10/$50 per MTok) could reduce cost for convention-detection phase (Phases 0-1) which is read-heavy not write-heavy |

### Model/Effort Sanity

- `model: opus`, `effort: medium` — reasonable for greenfield scaffold (substantial file generation, TypeScript correctness required).
- Fast mode (`claude-opus-4-8` + `speed: fast`) applicable for Phases 0-1 (read, detect); Phases 3-4 (generate + fix) benefit from full reasoning. Single model selection can't differentiate phases — **no change needed** but note the fast-mode opportunity for future phase-routing.
- 4.8 honesty gains: reduce need for defensive "Do NOT skip phases" guards.

---

## E. Correctness

| Issue | Detail | Severity |
|-------|--------|----------|
| Missing roadmap stub emission | Phase 5 does not create `docs/roadmap/roadmap-registry.json` or `docs/roadmap/epic-registry.json`; description says it does; state-handoff.md mandates it | **High** |
| `npx tsc` in Phase 4.1 | Should respect project's `npm run type-check` (as Phase 4.5 does); inconsistency — project may not have `tsc` on PATH | Medium |
| `npx eslint` in Phase 4.2 | Phase 4.5 uses `npm run lint`; inconsistency | Low |
| `model: opus` not pinned | Should be `claude-opus-4-8` per platform-delta.md 2026-05-28 | Low |
| `compatibility: ">=2.1.71"` | Stale; `disallowed-tools` (v2.1.152) and SessionStart hooks (v2.1.152) suggest minimum should be >=2.1.152 if those features are used; bootstrap doesn't use them so current value is technically correct — but `>=2.1.100` would be more conservative given session-protocol deps | Informational |
| `argument-hint` present | Correct — no issue |
| No `subagents-cannot-spawn-subagents` concern | Bootstrap is slash-invoked, single-agent; no Dynamic Workflows calculus change needed | Pass |

---

## F. Verdict

**`needs-tightening`**

### Top 3 Highest-Leverage Edits

1. **Add roadmap stub emission to Phase 3 or Phase 5.** Greenfield path must write `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json` as empty stubs (or print the explicit fallback from state-handoff.md line 35). Closes pipeline chain break to sprint-plan.

2. **Remove duplicate scaffold tables** between SKILL.md Phase 2 and references/main.md §Scaffold Templates. Keep one canonical location (references/main.md for templates; SKILL.md Phase 2 for path-only tables is fine). Estimated ~27 lines removable from references/main.md by collapsing the redundant feature/package tables.

3. **Replace anti-laziness prose guards with declarative or concrete spec.** Lines 29 ("Do NOT skip phases") and 171 ("generate REAL code (not stubs)") are redundant under 4.8 honesty. Delete line 29; replace line 171 with a concrete spec statement (e.g., list what constitutes a non-stub component). Net ~8 lines removed.
