# Validation Report: test-gen — v1.16.0 Cohesion+DW

**Date:** 2026-05-28  
**Unit:** `skills/test-gen/SKILL.md` + `skills/test-gen/references/main.md`  
**Validator:** cli-3ffa8b76 (freeform)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/test-gen/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present in frontmatter (lines 1–8):
- `name: test-gen` ✓
- `description`: 430 chars (≤1024, third-person "Generates tests for…") ✓
- `model: sonnet` ✓
- `effort: medium` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` ✓ (skill is invokable)

`argument-hint: "<file-path>"` present as optional field.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Byte-identical match confirmed via Python diff:

```
SKILL.md line 22: 'OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.'
Canonical:       [same]
Match: True
```

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/test-gen/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)` (full-tree scan confirmed no broken links in this file).

Own link audit for all 7 links in SKILL.md:

| Link | Resolved path | Status |
|---|---|---|
| `references/main.md` | `skills/test-gen/references/main.md` | OK |
| `/_shared/deterministic-test-recipe.md` | `skills/_shared/deterministic-test-recipe.md` | OK |
| `/agents/test-writer.md` | `agents/test-writer.md` (repo root, leading-/ convention) | OK |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | OK |
| `/_shared/session-protocol.md` | `skills/_shared/session-protocol.md` | OK |
| `/_shared/verbose-progress.md` | `skills/_shared/verbose-progress.md` | OK |
| `/_shared/definition-of-done.md` | `skills/_shared/definition-of-done.md` | OK |

Note: `markdown-link-validate.sh` resolves `/agents/test-writer.md` to `./agents/test-writer.md` (leading-/ → repo root), and `agents/test-writer.md` exists. The validator confirmed OK.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Unit notes: no special owner/DW/spawn role. `test-gen` is not in the O1–O5 owner list and does not delegate to one.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

`test-gen` is a standalone user-invoked skill, not in the core `bootstrap → sprint-plan → sprint-dev → sprint-review → ship` pipeline. No entry in `skills/_shared/state-handoff.md` (grep returned empty). The real chain it participates in is:

**sprint-dev** (produces source files) → **test-gen** (consumes: user-provided `<file-path>` pointing at sprint-dev output; produces: `*.test.ts` co-located or in `tests/`) → **sprint-review** (consumes test pass/fail status)

Per `state-handoff.md`, `test-gen` has no artifact-level pipeline contract (it's invoked ad-hoc). The skill correctly validates its own input at Phase 0.1 (`[ -f "<target-file>" ] && echo "FOUND" || echo "NOT FOUND"`). No upstream producer emits a formal artifact that `test-gen` structurally depends on — the input is always a user-supplied path. Composition is self-consistent.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Unit notes: DW wiring check applies only to `codebase-audit` and `research`. `test-gen` uses neither `Workflow` dispatch nor `BLITZ_DISPATCH`.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`test-gen` is NOT read-only-by-construction. `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` (SKILL.md line 4). Writing test files is the primary deliverable — `Write` and `Edit` are required. No `disallowed-tools` enforcement needed.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body calculated as lines after second `---` fence (line 9) through EOF:

```
Total file lines: 429
Body start: line 10 (immediately after second --- at line 9)
Body line count: 420
```

420 ≤ 500 (hard limit). Above 450 target — within hard budget but over the advisory target.

Evidence: `wc -l skills/test-gen/SKILL.md` → `429`; fence positions `[0, 8, 23, 29, 61, …]` (0-indexed); body = lines 10–429 = 420 lines.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

Unit notes: `allowed-tools` does not declare `TeamCreate` or `SendMessage`. No spawn idiom present. Skill operates as a single-thread execution.

---

## Skill Verdict

**cohesive**

All checks that apply PASS. The skill is well-structured: frontmatter validates cleanly, OUTPUT STYLE is byte-identical, all 7 internal links resolve, body is within the 500-line hard budget (420 lines), and the standalone pipeline position is coherent.

---

## Highest-Leverage Fix

**Body line count (420) exceeds the 450-line advisory target.** The "UI Framework Variants" section (lines 257–314 of SKILL.md) and the "Error Recovery" table (lines 415–429) together with the detailed `references/main.md` cross-reference suggest the skill body could shed ~20–30 lines by collapsing the Vue/Quasar/Vuetify mount snippets into a single composite example and moving framework-specific boilerplate entirely into `references/main.md`, where it already lives. No correctness issue — advisory tightening only.
