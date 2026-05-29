---
unit: compress
sprint: v1.16.0
validator: cli-a1b2c3d4
date: 2026-05-28
verdict: cohesive
highest_leverage_fix: "V5 — add a one-line pipeline-position note ('standalone utility, not in sprint pipeline') to state-handoff.md so the pipeline table is complete; compress is the only utility skill with explicit I/O docs in its SKILL.md but no entry in the handoff contract."
---

# Compress Skill — v1.16.0 Validation

## V1 Frontmatter Contract

**Verdict: PASS**

Evidence: `hooks/scripts/skill-frontmatter-validate.sh skills/compress/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: compress` ✓
- `description:` 398 chars (≤1024) ✓, third-person ("Rewrites…") ✓
- `model: sonnet` ✓
- `effort: low` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Grep, Glob` ✓ (skill is invokable, field required and present)

---

## V2 OUTPUT STYLE Snippet

**Verdict: PASS**

Byte-for-byte comparison via shell:

```
CANONICAL: OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles...
SKILL:     OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles...
MATCH
```

The OUTPUT STYLE line at SKILL.md:15 is identical to the canonical snippet bounded by `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` in `skills/_shared/terse-output.md`. No drift.

---

## V3 Shared-Protocol Citations Resolve

**Verdict: PASS**

Evidence: `hooks/scripts/markdown-link-validate.sh skills/compress/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/` links resolve to real files:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` ✓
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` ✓
- `/_shared/spawn-protocol.md` → `skills/_shared/spawn-protocol.md` ✓
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` ✓
- `hooks/scripts/reference-compression-validate.sh` → file exists ✓

No `references/main.md` exists for this skill (compress has no references subdirectory).

---

## V4 Canonical-Owner Compliance

**Verdict: N/A**

Per unit notes: compress has no O1–O5 owner role and does not delegate to one. No `owner`, `delegate`, or O-number tokens appear in the file.

---

## V5 Pipeline I/O Composition

**Verdict: PASS** (with minor gap noted)

Compress is a **standalone utility skill** — not part of the sprint pipeline (`bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review`). `skills/_shared/state-handoff.md` has no entry for compress (confirmed by grep). The skill's SKILL.md is self-documenting:

- **Input**: user-provided file path(s) (`.md`, `.txt`, `.rst`, extensionless text); validated in Phase 0.
- **Output**: compressed file (in-place) + `<file>.original` backup.
- **Upstream**: none (operator invocation only).
- **Downstream**: operator reviews diff; `hooks/scripts/reference-compression-validate.sh` runs as Phase 3 gate.

This is consistent with state-handoff.md's standalone pattern (the `migrate` skill has a parallel `standalone (not part of the sprint cycle)` declaration).

Minor gap: compress lacks a formal entry in state-handoff.md noting its standalone position. This mirrors how `migrate` is documented. Not a contract violation — compress predates the migrate entry convention and has no sprint-pipeline consumers requiring a handoff row.

---

## V6 Dynamic-Workflows Wiring

**Verdict: N/A**

Compress is not `codebase-audit` or `research`. No BLITZ_DISPATCH gate, no Workflow path. DW wiring check does not apply.

---

## V7 Disallowed-Tools Gap

**Verdict: N/A**

Compress is NOT read-only by construction. `allowed-tools` includes `Write` and `Edit`, which is correct: Phase 1 writes `.original` backups, Phase 2 writes/edits the compressed file. The V7 check (disallowed-tools enforcement for read-only skills) does not apply.

---

## V8 Body-Line Budget

**Verdict: PASS**

```
Total file lines:  149
Frontmatter:         8  (lines 1–8, first to second ---)
Body:              141  (lines 9–149)
```

141 < 450 (target) < 500 (hard cap). Passes both thresholds.

---

## V9 Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` contains no `TeamCreate` or `SendMessage`. Compress spawns no subagents; it operates entirely on the main thread. No spawn-idiom check required.

---

## Final Skill Verdict

**cohesive**

All applicable checks pass. Frontmatter validates clean via script. OUTPUT STYLE snippet is byte-identical to canonical. All shared-protocol links resolve. Body at 141 lines is well under budget. No O1–O5 owner conflicts, no DW wiring, no spawn tools. Only gap is absence of a state-handoff.md entry noting standalone position — a documentation completeness issue, not a contract violation.

## Highest-Leverage Fix

Add a one-line pipeline-position entry for compress in `skills/_shared/state-handoff.md` (standalone utility, not in sprint pipeline) — the same pattern as the `migrate` skill — so the handoff contract is complete for all skills with explicit I/O docs.
