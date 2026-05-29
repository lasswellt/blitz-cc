---
unit: skills/conform
kind: skill
verdict: needs-tightening
removable_lines: 30
created: 2026-05-28
---

# Conform — Cohesion + Modernization Audit

## A. Identity & Boundaries

**One-sentence purpose:** Detect and (with `--fix`) idempotently migrate blitz runtime artifacts (`.cc-sessions/`, sprint dirs, roadmap JSON, research scope-blocks) and plugin structure (SKILL.md frontmatter, hooks) to current canonical schemas.

**Description vs body match:** Verified. Description accurately scopes the two modes (project/plugin), mentions `--fix` and schema-version awareness, and matches Phase 0–6 pipeline. No inflation or omission.

**Overlaps — true duplication vs legitimate layering:**

| Skill / Agent | Overlap area | Classification |
|---|---|---|
| `/blitz:health` | Plugin-scope SKILL.md frontmatter validation (`skill-frontmatter-validate.sh`) | Legitimate layering — `health` is read-only probe, `conform --scope plugin --fix` mutates to repair. `health` is explicitly listed in `## Out of scope`. |
| `/blitz:setup` | `CLAUDE.md` conflict repair, hook wiring | Legitimate layering — `setup` handles initial installation; `conform` handles post-upgrade drift. `setup` excluded in `## Out of scope`. |
| `/blitz:bootstrap` | Creates `.cc-sessions/developer-profile.json` | Minimal overlap — `conform` only creates it when a consumer exists; `bootstrap` creates it as part of initial project setup. Different precondition. |
| `/blitz:sprint-review` Phase 3.6 | Story frontmatter validation | Legitimate layering — `sprint-review` validates as gate; `conform` migrates as repair. Referenced in `sprint-review` as recovery path. |

No true duplication found.

---

## B. Cohesion

### _shared protocols cited

| Protocol | Cited in SKILL.md | Followed or restated inline |
|---|---|---|
| `verbose-progress.md` | Line 20, 45, 84 | Followed — delegates event names (`skill_start`, `audit_complete`, `migration_applied`, `skill_complete`) to shared protocol; no inline restatement of schema. |
| `session-protocol.md` | Line 45, 38 | Followed — delegates to §Session Registration steps 1-9; §Autonomy Levels. |
| `carry-forward-registry.md` | Line 34 | Followed — delegates Reader Algorithm `MODE=audit` to shared doc. |
| `story-frontmatter.md` | Line 35 | Followed — references canonical schema; migration table in `references/main.md` augments (no duplicate schema). |
| `state-handoff.md` | Line 37 | Followed — references required fields; no inline restatement. |
| `token-budget.md` | NOT cited | N/A — single-agent skill, no subagent spawning; omission correct. |
| `spawn-protocol.md` | NOT cited | Correct — no agents spawned. |
| `ratchet-protocol.md` | NOT cited | Acceptable — conform is a migration tool, not a quality-gate runner. |
| `shortcut-taxonomy.md` | NOT cited | Acceptable — no agent output contract. |

No drift detected. Every protocol is cited by reference, not restated inline.

### Cross-reference liveness

- `/_shared/verbose-progress.md`, `/_shared/session-protocol.md`, `/_shared/carry-forward-registry.md`, `/_shared/story-frontmatter.md`, `/_shared/state-handoff.md` — all verified present at `/home/tom/development/blitz/skills/_shared/`.
- `references/main.md` — present, 288 lines. All section anchors referenced in SKILL.md (`§Schema Detection Rules`, `§Plugin-Scope Probes`, `§Plugin-Scope Validators`, `§Story Schema Versions`) verified present in references/main.md.
- `scripts/maint/v1.9.0/README.md` — path cited at SKILL.md line 39 as `/_shared/../../../scripts/maint/v1.9.0/README.md`. **Unverified** — did not read that path; could not confirm liveness.
- `scripts/maint/v1.9.0/blitz-fix-frontmatter.sh` et al. — cited in references/main.md §Plugin migration scripts. **Unverified** — did not walk `scripts/maint/v1.9.0/`.

### Produces/consumes per state-handoff.md

`conform` is not in the sprint pipeline (sprint-plan → sprint-dev → sprint-review → ship). It's a repair tool invoked out-of-band. It reads STATE.md and writes migrated stories/feed/locks. No pipeline contract breach. `## Out of scope` explicitly defers to the pipeline skills for continuation.

**Pipeline trace (conform --fix → sprint-dev):**
1. `conform --fix` migrates story v0.x → v1.9: `epic_id`, `acceptance_criteria`, `registry_entries: []`.
2. `sprint-dev` Phase 0.0 hard-fails if story frontmatter missing required fields (`epic_id`, `acceptance_criteria`). Post-conform, validation passes.
3. Confirmed: `sprint-dev/SKILL.md` line 442 references `/blitz:conform --fix` as the recovery path.
Chain is live and correct.

### OUTPUT STYLE snippet — Invariant 5

SKILL.md line 13: verbatim canonical snippet present. Invariant 5 satisfied.

---

## C. Conciseness

**Body line count:** 284 lines (SKILL.md) + 288 lines (references/main.md) = 572 total. SKILL.md body alone is under the 500-line cap. references/main.md is a separate file — does not count against cap per the `references/` convention. **No violation.**

**Anti-laziness / defensive prose candidates for deletion (30 lines estimated):**

1. **Safety Rules section (lines 263–274), rules 2–10:** Rules 3, 4, 6, 7, 9, 10 restate behavior already encoded in Phase 4 (MIGRATE) prose — e.g., "Backup before mutating" (rule 3) is already specified at Phase 4, steps 1 and "Backup `.cc-sessions/activity-feed.jsonl.pre-conform.<ts>` before any in-place writes"; "Per-file isolation in MIGRATE" (rule 4) restated from Phase 4 para "Per-story migration is independent — failure on one story does not abort the batch." These are defensive anti-laziness nudges that 4.8 honesty gains make redundant. **~12 lines removable.**

2. **Phase 5 "Never auto-rollback" sentence** (line 205): Already implied by "Backup files preserve pre-migration state" and by Safety Rule 3 (backups) + Rule 6 (halt, not rollback). **~1 line removable.**

3. **Phase 3 PLAN sample table** (lines 121–134): 14-line illustrative example table. Useful for authoring but functions as a "don't skip the table format" nudge. Could move to `references/main.md`. **~14 lines removable if moved; ~0 if kept in place is preferred.**

4. No content identified that belongs in a new shared protocol — the migration algorithms are genuinely conform-specific.

**Estimated removable:** 13–27 lines (without table move), ~30 lines with table relocation to references. Marking 30 as upper bound.

---

## D. Modernization

### Native primitive overlap (platform-delta.md v2026-05-28)

| Claim | Platform-delta reference | Verdict |
|---|---|---|
| `disallowed-tools` frontmatter available | v2.1.152 (platform-delta.md row 9) | **Delegate partially.** Safety Rule 2 ("No writes to `.git/`, `node_modules/`") could be reinforced with `disallowed-tools` to prevent Write/Edit outside safe paths. Prose guard + `disallowed-tools` is better than prose alone. No full delegation — path-scoped write restrictions can't be expressed purely via tool removal. |
| Model IDs | platform-delta.md row "Model IDs current as of 2026-05-28" | `model: opus` in frontmatter is acceptable (`claude-opus-4-8`). Frontmatter does not specify model version string — just alias. Acceptable. |
| `/simplify` native | v2.1.154 (platform-delta.md row "`/simplify` reinstated") | No overlap — conform does schema migration, not code cleanup. |
| `/goal` loop | v2.1.139 (platform-delta.md row "`/goal` completion-condition loop") | No overlap — conform is not a loop/poll skill. |
| Dynamic Workflows (native orchestration) | v2.1.154+ (platform-delta.md row "Native orchestration") | No overlap — conform is single-agent; no subagent fan-out. |

**`disallowed-tools` recommendation (concrete):** Add `disallowed-tools: []` placeholder or document that adding `Write` to the deny list during report-only mode would be a declarative guard. Currently Safety Rule 1 ("No writes without `--fix`") is prose-only.

### Model/effort sanity

`model: opus`, `effort: low` — matches orchestrator pattern (MEMORY.md: "orchestrator pairs opus with effort: low"). Single-agent skill — no workers spawned. Opus at effort:low is correct for a careful read + targeted write skill. No change needed.

### Opus 4.8 honesty

The 4.8 honesty improvement (platform-delta.md) means the Safety Rules section defensive restatements have lower value — 4.8 is less likely to silently skip them. Supports removable_lines estimate.

---

## E. Correctness

**Stale version refs:**
- `scripts/maint/v1.9.0/` references are version-pinned and look intentional (these scripts exist for that specific migration, not for ongoing use). Not stale — correct use.
- Story schema "v1.9" matches `/_shared/story-frontmatter.md` version. Consistent.

**Broken paths (unverified):**
- `scripts/maint/v1.9.0/README.md` at `/_shared/../../../scripts/maint/v1.9.0/README.md` — path arithmetic resolves to `<repo>/scripts/maint/v1.9.0/README.md`. Did not verify file existence. **UNCERTAINTY: unverified.**
- All `/_shared/` references use the canonical prefix. No broken-path signal.

**Dead flags/env vars:** None detected. `--fix`, `--report-only`, `--scope`, `--sample-mode`, `--full`, `--allow-system-paths` are all referenced consistently across Phase 0–6.

**Subagents-cannot-spawn-subagents:** Not applicable — conform spawns no agents. Dynamic Workflows (platform-delta.md v2.1.154+) does not change this; conform is correctly slash-invoked and single-threaded.

**`compatibility: ">=2.1.71"`** — no newer minimum required by cited primitives. `disallowed-tools` (v2.1.152) is not yet used. If added, minimum should bump to `>=2.1.152`. No current violation.

---

## F. Top Edits (highest-leverage)

1. **Add `disallowed-tools`** to Safety Rule 1 enforcement: in report-only mode, declare `Write` and `Edit` as disallowed-tools so the constraint is declarative, not just prose. Requires `compatibility: ">=2.1.152"`. Tradeoff: slight complexity in how skill declares conditional tool availability; benefit: platform-enforced safety over prose-only.

2. **Remove Safety Rules 3, 4, 6, 7, 9, 10** (~12 lines) — each restates behavior already specified in Phase 4 body. Keep rules 1, 2, 5, 8 which add non-redundant constraints (mode gate, path exclusion, script scope, no auto-invoke). 4.8 honesty makes redundant restatements actively unhelpful (they inflate context without adding constraint).

3. **Move Phase 3 sample table** (lines 121–134, ~14 lines) to `references/main.md §Plan Phase Sample` — keeps SKILL.md lean; references/main.md is the appropriate home for illustrative data shapes.
