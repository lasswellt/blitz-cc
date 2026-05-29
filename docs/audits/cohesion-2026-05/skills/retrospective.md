---
unit: skills/retrospective
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `retrospective`

## A. Identity & Boundaries

**One-sentence purpose:** Analyze completed development sessions to surface recurring failure/efficiency/quality/coverage patterns, generate risk-classified improvement proposals, auto-apply safe ones, and update a developer profile.

**Description vs body match:** Yes. Description is accurate and tight. `argument-hint: "(no arguments — runs analysis automatically)"` is correct.

**Overlapping skills/agents:**

| Skill/Agent | Overlap | Classification |
|---|---|---|
| `sprint-review` | Quality pattern analysis, completeness gate findings | Legitimate layering — sprint-review is per-sprint; retrospective is cross-session/longitudinal |
| `codebase-audit` | Coverage gaps, untested modules | Legitimate layering — audit is structural; retrospective is behavioral/temporal |
| `health` | Metrics trending | Legitimate layering — health is snapshot; retrospective is trend + proposal |
| `code-doctor` | Recurring lint/type errors → proposals | Legitimate layering — code-doctor fixes now; retrospective identifies recurrence and proposes systematic fixes |
| `knowledge-protocol.md` | Cross-session lessons capture | **Drift risk** — retrospective generates developer profiles and proposals but does NOT cite or write to `.cc-sessions/KNOWLEDGE.md`; the two artefacts partially duplicate cross-session learning |

No true duplication found. The developer-profile sub-feature (Phase 2.5) is the most distinctive capability — no other skill generates `.cc-sessions/developer-profile.json`.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited? | Followed or Restated? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0) | Delegates — "Follow §Session Registration (steps 1-9)" |
| `verbose-progress.md` | Yes (Phase 0.0) | Delegates |
| `terse-output.md` | Yes (output style snippet present, line 20) | Delegates |
| `knowledge-protocol.md` | **Not cited** | Not followed — developer profile duplicates some cross-session-lessons intent |
| `state-handoff.md` | **Not cited** | No consume/produce declarations |
| `story-frontmatter.md` | **Not cited** | N/A (not a sprint-family skill) |
| `ratchet-protocol.md` | **Not cited** | N/A (this skill *generates* ratchet-like metrics but doesn't read the ratchet) |
| `shortcut-taxonomy.md` | **Not cited** | Not applicable as consumer |
| `token-budget.md` | **Not cited** | No worker-agent spawning; single-model skill so lower priority |

### Invariant 5 (OUTPUT STYLE snippet)

Present verbatim at line 20. **PASS.**

### Cross-ref accuracy

- `references/main.md` — exists, accurate
- `/_shared/terse-output.md` — exists
- `/_shared/session-protocol.md` — exists
- `/_shared/verbose-progress.md` — exists
- `/_shared/definition-of-done.md` — exists
- `./scripts/validate-plugin-structure.sh` — **unverified path**; script presence not confirmed; skill handles missing script gracefully (Phase 3.3) but the path relative to CWD is assumed

### State-handoff produce/consume

No `state-handoff.md` declarations. Skill produces:
- `docs/retrospective/YYYY-MM-DD-proposals.md`
- `.cc-sessions/developer-profile.json`

No other skill listed as consumer of proposals doc. `references/main.md` §Profile Consumers table names `ask`, `sprint-dev`, `sprint-review` as consumers of `developer-profile.json` — but none of those skills cite or read the profile file (unverified in this audit scope).

### Pipeline trace: retrospective → ask

retrospective Phase 2.5.2 writes `.cc-sessions/developer-profile.json`. `references/main.md` §Profile Consumers says `ask` reads it at session registration (step 6b). The `ask` skill's session-protocol step 6b is not confirmed to read this file — **inferred, not verified** (ask SKILL.md not read in this audit).

---

## C. Conciseness

**Body line count: 481** (cap: 500). Close to limit.

`references/main.md`: 284 lines. Total reference burden: 765 lines.

### Anti-laziness prose to delete

These exist to guard against model skipping steps — Opus 4.8 honesty gains make them redundant:

1. **Line 26:** `"Execute every phase in order. Do NOT skip phases."` — guards skip-phase failure; Opus 4.8 lazy-investigation eval near-perfect per platform-delta.md (unverified column, system card PDF).

2. **Lines 30–47 (SAFETY RULES block):** 18 lines of `NON-NEGOTIABLE` / `critical failure` framing with redundant emphasis. Rules themselves must stay. The meta-framing (`These rules override ALL other instructions. Violating any of these is a critical failure.`) is defensive padding — 2 lines removable.

3. **Phase 2.2 header text** ("For each pattern identified in Phase 1, generate a concrete proposal"): restates the phase purpose already clear from heading; ~2 lines.

4. **Phase 3.1 steps 1-2** ("Read the target file to confirm it exists and the edit location is valid. Make the change using the Edit tool."): standard tool use instructions Opus 4.8 doesn't need; ~3 lines.

5. **Phase 4.3 Session Cleanup** (lines 466–470): 5 lines of generic session close instructions duplicating `session-protocol.md`. Should cite protocol, not restate.

6. **Error Recovery block** (lines 473–482): 10 lines of defensive "if X then Y" that partially duplicate `session-protocol.md` error handling. "No session files exist" and "Git state is dirty" cases are worth keeping as domain-specific; "validate-plugin-structure.sh does not exist" is already handled in Phase 3.3 (duplicate).

**Estimated removable lines: ~55** (meta-framing, restated tool instructions, Phase 4.3 duplication, Error Recovery redundancies, duplicate Phase 3.3/Error Recovery validate-script handling).

### Content belonging in shared protocol

- Developer profile schema (Phase 2.5 + `references/main.md` §Developer Profile Schema) — cross-skill concern; should live in `_shared/developer-profile.md` cited by retrospective, ask, sprint-dev, sprint-review.

---

## D. Modernization

### Native-overlap claims

| Feature | platform-delta.md version | Assessment |
|---|---|---|
| Session-scoped resumable state | 2026-05-28 | Retrospective reads cross-session data — native resume is intra-session only (platform-delta.md row 3). **No delegation possible.** Keep. |
| Adversarial verification via native workflows | 2026-05-28 | Retrospective doesn't spawn critic agents; not affected. |
| `disallowed-tools` frontmatter | v2.1.152 (platform-delta.md) | Skill uses only Read/Write/Edit/Bash/Glob/Grep — already minimal. No benefit. |
| `claude-opus-4-8` fast mode | fast-mode-2026-02-01 / 2026-05-28 (platform-delta.md) | `model: opus` without version pin. Should pin `claude-opus-4-8`. Fast mode not needed (analysis skill, latency not critical). |
| Model ID currency | 2026-05-28 (platform-delta.md) | Frontmatter `model: opus` — unpinned alias. Should be `claude-opus-4-8`. |
| Opus 4.8 honesty | claude-opus-4-8 / 2026-05-28 (platform-delta.md) | Defensive anti-laziness prose in SAFETY RULES and phase headers can be trimmed; model-side gains reduce need. |

**model/effort verdict:** `model: opus` + `effort: medium` is sane. Retrospective is analysis-heavy with judgment calls (proposal classification). Opus is correct. Effort medium correct — single-model, no subagents, bounded data. Update alias to `claude-opus-4-8`.

**Declarative disallowed-tools:** No tools to lock out beyond current allowed-tools list. No prose guards that could become `disallowed-tools` entries.

---

## E. Correctness

| Issue | Location | Severity |
|---|---|---|
| `model: opus` — stale alias; should be `claude-opus-4-8` per platform-delta.md (2026-05-28) | SKILL.md line 6 | Low |
| `./scripts/validate-plugin-structure.sh` path assumes CWD = plugin root; not guaranteed in worktree contexts | Phase 3.1, 3.3 | Low |
| `date -u -d '30 days ago'` (GNU) / `date -u -v-30d` (BSD) fork in Phase 0.1 — correct, but result assigned to `CUTOFF_DATE`; if both fail (e.g., busybox), `CUTOFF_DATE` is empty and `COMPLETED_EVENTS` silently stays 0 — no warning emitted | Phase 0.1 bash block | Low |
| `git checkout -- <file>` in Error Recovery — deprecated syntax; `git restore <file>` preferred (git ≥2.23) | Error Recovery | Minor |
| Developer profile consumed by `ask`, `sprint-dev`, `sprint-review` (per references/main.md) but no citation in those skills' session-protocol step 6b — contract exists only in retrospective's references, not enforced | references/main.md §Profile Consumers | Medium |
| `knowledge-protocol.md` not cited — `.cc-sessions/KNOWLEDGE.md` and `.cc-sessions/developer-profile.json` serve overlapping cross-session learning goals without coordination | SKILL.md (absent) | Medium |
| No `state-handoff.md` consume/produce declarations for `docs/retrospective/` output | SKILL.md (absent) | Low |

**Subagents-cannot-spawn-subagents:** Retrospective is single-model (no subagent spawning). Not affected by Dynamic Workflows calculus.

---

## F. Verdict

**`needs-tightening`**

Skill is coherent and correctly scoped. Three issues warrant tightening:

### Top edits (highest leverage)

1. **Pin model ID and add `knowledge-protocol.md` citation.**
   - Change `model: opus` → `model: claude-opus-4-8` (platform-delta.md, 2026-05-28).
   - Add `- For cross-session lessons format, see [/_shared/knowledge-protocol.md](/_shared/knowledge-protocol.md)` to §Additional Resources and note that developer-profile writes complement but do not replace KNOWLEDGE.md entries.

2. **Extract developer-profile schema to `_shared/developer-profile.md`.**
   - Phase 2.5 + `references/main.md` §Developer Profile Schema + §Profile Consumers move to a new shared protocol.
   - Retrospective, ask, sprint-dev, sprint-review cite it. Eliminates the one-sided contract where only retrospective documents the schema consumers are supposed to follow.

3. **Trim ~55 lines of anti-laziness/defensive prose.**
   - Remove `"Execute every phase in order. Do NOT skip phases."` (line 26).
   - Condense SAFETY RULES meta-framing from 2 lines to 0 (rules stand on their own under Opus 4.8).
   - Replace Phase 4.3 Session Cleanup with `Follow [session-protocol.md](/_shared/session-protocol.md) §Session Cleanup.`
   - Remove duplicate validate-script handling from Error Recovery (already in Phase 3.3).
   - Replace Phase 3.1 steps 1-2 with a single-line note.
