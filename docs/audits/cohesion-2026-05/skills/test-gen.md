---
unit: test-gen
kind: skill
verdict: needs-tightening
removable_lines: 40
created: 2026-05-28
---

# Audit — `skills/test-gen/SKILL.md`

## A. Identity & Boundaries

**One-sentence purpose**: Generate tests for a named target file, discovering project conventions, writing AAA-style specs, running them to verify, and reporting coverage.

**Description vs body**: Match is good. Description mentions Vitest/Jest, AAA/BDD, factory patterns, edge cases, error paths — all present in body phases. No gap.

**Overlaps**:

| Other unit | Overlap type | True duplication? |
|---|---|---|
| `agents/test-writer.md` | Both write tests; test-writer has Spec Fix Mode for fixing *failing* specs; test-gen cites test-writer §Spec Fix Mode for recovery | Legitimate layering: test-gen = green-field generation (slash skill); test-writer = subagent invoked by sprint-dev for iteration/fix loops. No prose duplication. |
| `skills/sprint-dev` | sprint-dev spawns test-writer agent for sprint stories | Legitimate: sprint-dev delegates bulk sprint testing to test-writer agent; test-gen is user-facing for ad-hoc coverage gap work post-sprint. |

No true duplication found.

---

## B. Cohesion

### _shared protocols cited

| Protocol | Cited in SKILL.md | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Phase 0.0 — pointer to §Session Registration steps 1-9 | Delegates, no inline restatement. **Correct.** |
| `verbose-progress.md` | Phase 0.0 | Delegates. **Correct.** |
| `terse-output.md` | Additional Resources section + OUTPUT STYLE block | Delegates. **Correct.** |
| `definition-of-done.md` | Phase 3.4 | Delegates. **Correct.** |
| `deterministic-test-recipe.md` | Additional Resources | Pointer only — async/timer/mock patterns live there rather than inlined. **Good DRY.** |
| `state-handoff.md` | Not cited | Not a pipeline consumer/producer (pure worker per `agent-routing.md`). Acceptable. |
| `story-frontmatter.md` | Not cited | N/A — does not produce sprint stories. Acceptable. |
| `token-budget.md` | Not cited | token-budget.md classifies test-gen as Haiku-grade "mechanical worker". SKILL.md sets `model: sonnet`. **Mismatch** (see D). |
| `spawn-protocol.md` | Not cited | Correct — test-gen spawns nothing. |
| `shortcut-taxonomy.md` | Not cited | Not required for pure workers. |
| `ratchet-protocol.md` | Not cited | Not required for pure workers. |

### Cross-references live?

- `/_shared/session-protocol.md` — verified present.
- `/_shared/verbose-progress.md` — verified present.
- `/_shared/terse-output.md` — verified present.
- `/_shared/definition-of-done.md` — verified present.
- `/_shared/deterministic-test-recipe.md` — verified present.
- `references/main.md` — verified present.
- `agents/test-writer.md` §Spec Fix Mode — verified section exists (line 209).

All cross-refs are live. No dead paths.

### OUTPUT STYLE snippet (Invariant 5)

Present verbatim at lines 22-23. **Invariant 5 satisfied.**

### Pipeline chain trace

test-gen is a terminal node (pure worker). Downstream: user may follow with `browse` (visual regression) or `fix-issue` (bugs found). Neither consumes a structured artifact from test-gen — the test *file* is the artifact, consumed by the test runner. No pipeline contract issue.

---

## C. Conciseness

**Body line count**: 429 / 500 cap. Under cap, but dense.

### Prose compensating for old-model laziness (mark for deletion)

1. **Phase 0.0, end of sentence**: `"Execute every phase in order. Do NOT skip phases."` (line 28)  
   *Failure mode guarded*: older Sonnet skipping phases if target seemed simple. With Opus 4.8 honesty / Sonnet 4.6, instruction compliance is reliable. → **removable**

2. **Phase 3.3, rule 1**: `"A test can have multiple expect calls, but they should all verify the same behavior."` (line 237)  
   This is an explanatory aside that restates the rule already in the rule name "One assertion focus per test." → **tighten to one line**

3. **Phase 4.2 table**: `"The test is correct and found a real bug. Keep the test, note the bug."` — fine, non-redundant.

4. **Phase 3.3 rule 7**: `"If the project uses factory functions, use them. If it uses inline objects, do the same."` — restates Phase 1.2 extraction. → **removable** (already covered by Phase 1.2's convention discovery).

5. **Error Recovery table** (lines 416-429): 10 rows, legitimately specific. Not laziness compensation — these are real failure modes with recovery paths. Keep.

Estimated removable lines: ~40 (Phase 2 tables are detailed but load-bearing; the main candidates are defensive prose scattered through Phase 3).

### DRY candidates

- **Phase 1.5 `find` command** (lines 139-141) is identical to Phase 1.2's Category C bash block (lines 92-95). Duplicate bash search. Combine into one.

---

## D. Modernization

### Model/effort frontmatter

`model: sonnet` — `token-budget.md` v1.11+ routing matrix explicitly classifies test-gen as a **Haiku-grade mechanical worker** ("pattern-following work"; 5× cheaper than Opus). The mismatch means every invocation burns Sonnet tokens unnecessarily.

**Claim**: delegate model to `haiku` (claude-haiku-4-5).  
**Tradeoff**: test-gen does require convention *discovery* (reading 6+ test files, synthesizing patterns, generating TypeScript). Haiku 4.5 handles pattern-following well but may degrade on novel framework setup (Quasar + Pinia + TypeScript simultaneously). A safe split: Haiku for Phase 1-2 (read/plan), Sonnet for Phase 3 (write). Since test-gen is a slash-skill (not spawning sub-agents), model switching mid-run is not available. **Verdict**: raise to `model: haiku` with escape hatch note, consistent with token-budget.md routing. If user needs higher fidelity, they can override effort. *(platform-delta.md model IDs 2026-05-28: `claude-haiku-4-5-20251001`)*

### Native primitive overlap

- **`disallowed-tools`** (platform-delta.md v2.1.152): test-gen's Phase 3.4 "BANNED" list (`it.skip`, `describe.skip`, no-op assertions) are enforced via prose. The `disallowed-tools` field cannot block *generated code patterns*, only tool calls — so this is not replaceable by frontmatter. No change needed.

- **`/simplify`** reinstated v2.1.154 (platform-delta.md 2026-05-28): not relevant — test-gen is not a cleanup skill.

- **Dynamic Workflows** (platform-delta.md v2.1.154+): test-gen is classified as pure worker, slash-only, no spawning. Workflows don't change this calculus — no parallelism gain for single-file test generation.

---

## E. Correctness

- `compatibility: ">=2.1.71"` — no stale version refs. Current platform is ≥2.1.154.
- No dead flags or env vars.
- `model: sonnet` — valid model alias; maps to `claude-sonnet-4-6` per platform-delta.md 2026-05-28. But misaligned with token-budget routing (see D).
- Phase 4.1 `<TEST_CMD>` placeholder is correct (test command is project-specific; user must supply or Phase 1.3 must populate it). No bug.
- Phase 1.5 duplicate bash block vs Phase 1.2 Category C: functional correctness not broken, just redundant.
- Reference to `agents/test-writer.md §Spec Fix Mode`: section exists at line 209 of that file. Live. Correct.

**Subagents-cannot-spawn-subagents**: not applicable — test-gen spawns nothing. Dynamic Workflows do not change the slash-only classification.

---

## F. Verdict

**`needs-tightening`**

### Top 3 highest-leverage edits

1. **`model: haiku`** — align with token-budget.md routing matrix (mechanical worker classification already exists there; this is just making SKILL.md consistent). Saves ~40% per invocation with acceptable quality for convention-following test generation. *(platform-delta.md model IDs 2026-05-28)*

2. **Deduplicate Phase 1.5 bash block** — identical to Phase 1.2 Category C. Remove Phase 1.5 `find` command and collapse into a note: "Re-use Category C results from 1.2." ~8 lines saved, no information loss.

3. **Delete 3 laziness-guard prose fragments** (~8 lines) — "Execute every phase in order. Do NOT skip phases." (line 28), rule-7 restatement of convention-following in Phase 3.3 (already covered by Phase 1.2), and the parenthetical in rule-1 of Phase 3.3. With Sonnet 4.6 / Haiku 4.5 instruction compliance, these add noise without changing behavior.
