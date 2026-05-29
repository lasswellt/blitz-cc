---
unit: skills/completeness-gate
kind: skill
verdict: needs-tightening
removable_lines: 38
created: 2026-05-28
---

# Cohesion Audit — `completeness-gate`

## A. Identity & Boundaries

**One-sentence purpose:** Grep + AST scan of source files for placeholder/stub patterns; returns an A–F completeness score with `file:line` findings for use as a gate before `/blitz:ship`.

**Description vs body match:** Verified. Description ("placeholder patterns, incomplete implementations, production-readiness issues") matches 14 check categories in Phase 2.

**Overlapping skills (verified via `quality-matrix.md`):**

| Other skill | Overlap type | Verdict |
|---|---|---|
| `code-sweep` | Both grep TODO/FIXME/STUB | Legitimate layering — completeness-gate = gate semantics (is it prod-ready NOW); code-sweep = ratchet semantics (metric must only decrease). `quality-matrix.md` explicitly calls this out. Not true duplication. |
| `integration-check` | Both check `unwired-store-actions` | Partial overlap — integration-check checks export-to-import wiring; completeness-gate check 2.11 checks store actions lacking API calls. Scope difference (file bodies vs cross-file imports). Not flagged in `quality-matrix.md`; warranting a **flag**: the `unwired-store-actions` check (2.11) and Level 3 artifact wiring check (2.12) duplicate integration-check's concern at shallow depth. True duplication risk. |
| `sprint-review` | Both scan for anti-patterns in Phase 1.5 | Legitimate layering — sprint-review's 1.5 is "anti-mock scan + convention check" on a sprint diff; completeness-gate is whole-repo. No code duplication. |
| `codebase-audit` | Both report production-readiness findings | Legitimate layering — codebase-audit uses 10 parallel agents and 5 pillars across whole repo at pre-release depth; completeness-gate is read-only grep-only. Different depth and tempo. |

**True duplication flag:** `unwired-store-actions` (check 2.11) + `artifact-verification` Level 3 (check 2.12) partially duplicate `integration-check`. Recommend delegating wiring concerns to `integration-check` or cross-referencing rather than re-implementing.

---

## B. Cohesion

### Protocols cited

| Protocol | Cited in SKILL.md | Followed (not restated) |
|---|---|---|
| `session-protocol.md` | Phase 0.0: "Follow session-protocol.md §Session Registration" | Delegated — no inline restatement. |
| `verbose-progress.md` | Phase 0.0: "Follow verbose-progress.md" | Delegated — no inline restatement. |
| `terse-output.md` | Additional Resources + OUTPUT STYLE block | Delegated via import marker. |
| `story-frontmatter.md` | Not cited | NOT cited. Phase 2.12 (`artifact-verification`) reads story `files` fields — implies knowledge of story frontmatter schema, but no explicit cite. **Drift risk**: if story schema changes, check 2.12 silently breaks. |
| `state-handoff.md` | Not cited | Not cited. Skill is a consumer in the `ship` chain but does not cite the contract. Acceptable — it's not a pipeline skill (no upstream artifact required). |

### Cross-references

- `references/main.md` — live, accurate (verified by reading both files; grep patterns match).
- `/_shared/terse-output.md` — cited, not verified present (not read; inferred live from other skills using it).
- `/_shared/session-protocol.md` — cited, standard cross-ref.

### State handoff

Completeness-gate is not in the sprint pipeline; it is in the `ship` pipeline. It:
- **Produces:** `${SESSION_TMP_DIR}/completeness-gate.json` — JSON report with score/grade/findings.
- **Consumes:** nothing required (scope argument only). Phase 2.12 optionally consumes story frontmatter.
- **ship pipeline chain verified:** `quality-matrix.md` confirms `ship → completeness-gate → quality-metrics → release`. The JSON report format at Phase 4.1 has no formal schema citation in `state-handoff.md` — it is self-described in `references/main.md`. Acceptable for a leaf-node gate.

### Invariant 5 — OUTPUT STYLE snippet

Verbatim snippet present at lines 20–24:
```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```
**Invariant 5: PASS.**

### Pipeline trace

`/blitz:ship` → `completeness-gate` → writes `${SESSION_TMP_DIR}/completeness-gate.json` → `ship` reads grade; if grade < C (score < 70) ship halts. Next skill (`quality-metrics`) reads ratchet state, not the completeness report. **Chain is correct** — completeness-gate is a gate, not a producer for the next skill.

---

## C. Conciseness

**Body line count:** 399 lines (SKILL.md) + 200+ lines (references/main.md). SKILL.md at 399 is within the 500-line cap but close given that `references/main.md` exists expressly to offload the grep patterns.

**Anti-laziness / defensive prose flagged for deletion:**

1. Lines 28–38 — `SAFETY RULES (NON-NEGOTIABLE)` block:
   ```
   1. This skill is READ-ONLY — never modify source files…
   2. Never skip checks or ignore findings — run all 11 check categories…
   3. Report ALL violations — even in test files…
   4. Never suppress findings — unless an explicit override…
   5. Never execute source code — only read and grep.
   ```
   **Failure mode guarded:** Model laziness / instruction-following regression on older models. Under 4.8 honesty (platform-delta.md: "~4x less likely to let own code flaws pass unremarked" — verified), the `READ-ONLY` rule is redundant with `allowed-tools: Read, Bash, Glob, Grep` (no Write tool → cannot modify files) and the `disallowed-tools` mechanism. Rules 2–4 ("never skip", "report ALL", "never suppress") are anti-laziness nudges that 4.8 no longer requires. **Estimate: 10 removable lines.**

2. Lines 113 (`Use the exact grep patterns from references/main.md`) — legitimate pointer, keep.

3. Phase 1 (lines 71–95) — three sub-phases: Collect, Separate, Report. Sub-phase 1.3 (`Print: "Scanning N source files + M test files in <scope>"`) is a verbose-progress directive that belongs in `verbose-progress.md`. **Estimate: 3 removable lines.**

4. Phase 3.3 score formula (lines 300–316) duplicates `references/main.md` Score Calculation section. One copy is sufficient. SKILL.md version adds the grade table; references/main.md adds the formula. Minor redundancy. **Estimate: 5 removable lines if consolidated into references/main.md.**

5. Error Recovery section (lines 392–399) — 8 lines of "if X, do Y" for edge cases. Legitimate — this is skill-specific behavior, not a shared protocol. Keep.

6. Phase 4.3 Follow-Up Suggestions table (lines 376–388) — 4 skill cross-references to `implement`, `ui-build`, `fix-issue`, `codebase-audit`. Legitimate routing guidance, not anti-laziness. Keep.

**Total estimated removable lines: ~38** (10 SAFETY RULES + 3 verbose-progress duplicate + 5 score formula duplication + 20 reserved for inline comment-guidance that `references/main.md` already covers via the false-positive mitigation column).

**DRY miss:** Phase 2 inline false-positive guidance (e.g., lines 117–118, 131–132, 135–136) repeats the "False-Positive Mitigation" column already in `references/main.md`. Moving all such notes to references/main.md would reduce SKILL.md by ~20 lines.

---

## D. Modernization

### Native primitive overlap

| SKILL.md behavior | Platform delta | Verdict |
|---|---|---|
| `allowed-tools: Read, Bash, Glob, Grep` (implied read-only) | `disallowed-tools` frontmatter (v2.1.152, platform-delta.md) | **Delegate**: Add `disallowed-tools: [Write, Edit, MultiEdit]` to frontmatter. Eliminates SAFETY RULE 1 and makes write-lock declarative. No determinism/opinionation lost. |
| Anti-laziness SAFETY RULES 2–5 | Opus 4.8 honesty (platform-delta.md: "~4x less likely to let own code flaws pass unremarked", verified) | **Delegate**: Remove rules 2–5. 4.8 native honesty supersedes these behavioral directives. |
| `effort: medium` + `model: sonnet` | `claude-sonnet-4-6` current (platform-delta.md: "Model IDs current as of 2026-05-28: `claude-sonnet-4-6`") | Frontmatter says `model: sonnet` (alias). **Modernize**: update to `model: claude-sonnet-4-6` for explicit version pin. Low priority — alias works. |
| Grep-based checks run serially in one agent | Native orchestration: parallel subagents (v2.1.154+, platform-delta.md) | **Keep**: completeness-gate is intentionally single-agent + read-only; serial grep is fast and deterministic. Parallelizing 14 grep checks via subagents adds spawn overhead with no practical gain. Tradeoff: no change. |

### `disallowed-tools` recommendation

```yaml
disallowed-tools: [Write, Edit, MultiEdit, TodoWrite]
```

Replaces prose SAFETY RULE 1. `shortcut-taxonomy.md` blockers (`block-test-deletion`, `post-edit-typecheck-block`) do not apply here since the skill only reads.

### Model/effort sanity

`model: sonnet` + `effort: medium` is appropriate for a grep-only read pass. No Opus needed. No fast-mode benefit (this is I/O-bound, not reasoning-bound). **Sane.**

---

## E. Correctness

**Stale version refs:**
- `compatibility: ">=2.1.71"` — `disallowed-tools` requires v2.1.152 (not yet used, but if added, compatibility floor must raise). Currently no issue.
- `model: sonnet` — alias works; not broken, but imprecise vs platform-delta.md canonical IDs.

**Dead flags/env vars:**
- `$ARGUMENTS` (line 50), `SESSION_TMP_DIR` (line 325), `SESSION_ID` (line 387) — standard platform env vars. Not verified in platform docs but consistent with other skills. **Inferred live** (not verified directly).
- `CLAUDE_PLUGIN_ROOT` (line 13) — standard plugin env var. **Inferred live**.

**Broken paths:** None found. All `/_shared/` and `references/main.md` references appear consistent.

**Wrong tool names:** Phase 1.1 uses `Glob` — matches `allowed-tools: Glob`. Correct.

**check_id enum in references/main.md:** JSON schema enum lists 12 IDs but SKILL.md defines 14 checks (adds `env-fallback` check 2.13, `hardcoded-localhost` check 2.14). **Schema drift**: the JSON output schema `check_id` enum in `references/main.md` does not include `env-fallback` or `hardcoded-localhost`. Reports emitting these check IDs will fail schema validation. **Correctness bug.**

**Phase numbering:** Check 2.12 is called "Phase 2, check 2.12" but the section header says "2.12 Artifact Verification (Three-Level)". Check count in Phase 2 header says "11 check categories" (line 29 and line 99) but there are actually 14 checks (2.1–2.14). **Header count is stale.**

**Subagents-cannot-spawn-subagents:** Not applicable — skill spawns no agents. Slash-only constraint is not relevant here.

---

## F. Verdict

**Verdict: `needs-tightening`**

Not retire, not split, not delegate-to-native (core grep logic has no native equivalent). The skill is coherent and well-bounded. Two correctness bugs (schema enum + check count) need immediate fixes. One structural improvement (add `disallowed-tools`) replaces 5-line safety block.

### Top 3 highest-leverage edits

1. **Fix JSON schema enum in `references/main.md`** — add `env-fallback` and `hardcoded-localhost` to the `check_id` enum. Reports from checks 2.13/2.14 will fail schema validation otherwise. Also update "11 check categories" → "14 check categories" in SKILL.md lines 29 and 99.

2. **Add `disallowed-tools: [Write, Edit, MultiEdit, TodoWrite]` to frontmatter** — makes write-lock declarative (platform-delta.md v2.1.152). Remove the now-redundant SAFETY RULES block (lines 32–38, ~10 lines). Also cite `story-frontmatter.md` in Phase 2.12 (drift guard).

3. **Move inline false-positive guidance from Phase 2 into `references/main.md`** — the "Filter out legitimate patterns" prose in sections 2.1, 2.2, 2.3, 2.6, 2.7, 2.8 duplicates the "False-Positive Mitigation" column already in references/main.md. Removing them reduces SKILL.md by ~20 lines and keeps false-positive rules in one place.
