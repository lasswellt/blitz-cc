---
unit: design-extract
cohort: v1.16.0
date: 2026-05-28
validator: claude-sonnet-4-6
verdict: needs-hardening
highest_leverage_fix: "V7 — drop Edit from allowed-tools; idempotent re-run uses Write (full overwrite) instead, eliminating broad Edit permission that allows unintended source-file mutations."
---

# design-extract — v1.16.0 Cohesion+DW Validation

## Files Checked

- `skills/design-extract/SKILL.md` (190 lines)
- `skills/design-extract/references/main.md` — does not exist (no references dir)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Evidence: `hooks/scripts/skill-frontmatter-validate.sh skills/design-extract/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: design-extract` (line 2)
- `description:` 359 chars — well under 1024 cap (line 3)
- `model: sonnet` (line 6)
- `effort: low` (line 7)
- `compatibility: ">=2.1.117"` (line 8)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` (line 5)
- Description is third-person ("Extracts design tokens…")

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Evidence: bash diff of `grep "^OUTPUT STYLE:" SKILL.md` vs canonical from `terse-output.md` between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->` → `MATCH` (byte-identical).

SKILL.md line 14 carries the verbatim canonical snippet.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Evidence: `hooks/scripts/markdown-link-validate.sh skills/design-extract/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links checked include:
- `/_shared/frontend-design-heuristics.md` (lines 23, 97)
- `/_shared/token-budget.md` (line 24)
- `/_shared/definition-of-done.md` (line 25)
- `/_shared/session-protocol.md` (line 37)

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

design-extract does not delegate to an O1–O5 canonical owner; there is no O-owner system covering design-token extraction in the shared protocols. The skill is a standalone producer (of `DESIGN.md`), not a delegator. No bidirectional check required.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `design-extract` → `DESIGN.md` → `ui-build` (consumer) + `agents/design-critic.md` (consumer).

Producer side: Phase 4 (SKILL.md line 107) writes `DESIGN.md` at repo root. Phase 5 verifies its presence and section count.

Consumer evidence:
- `skills/ui-build/SKILL.md:130` — "For brownfield projects without DESIGN.md, run `/blitz:design-extract` first to read the existing tokens and emit the file."
- `agents/design-critic.md:6` — "the project's DESIGN.md (or frontend-design heuristics if no DESIGN.md)"
- `agents/design-critic.md:41` — reads `Project's DESIGN.md if present in the repo root`

Note: `DESIGN.md` is NOT listed in `skills/_shared/state-handoff.md` (confirmed by grep — zero matches). This is a gap in state-handoff documentation but not a functional defect in the skill itself; the artifact and its consumers are internally consistent.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

design-extract is not `codebase-audit` or `research`. DW wiring check does not apply.

---

## V7 — Disallowed-Tools Gap

**Verdict: FAIL (needs-hardening)**

Unit note flags design-extract as a read-only candidate. Analysis:

- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` (SKILL.md line 5)
- DoD at line 189: "No source files modified — this skill is read-only on the codebase"
- The only intended write target is `DESIGN.md` (one output artifact).
- `Write` is necessary (creates DESIGN.md on first run).
- `Edit` is claimed for idempotent re-run ("surface drift, propose updates", line 31), but:
  - The body never instruments `Edit` explicitly — re-run logic is handled by reading existing DESIGN.md (Phase 1 reads it, Phase 4 overwrites with `Write`).
  - `Edit` in allowed-tools grants ability to make surgical edits to ANY file, including codebase source files, which directly contradicts the DoD claim.
- `NotebookEdit` is correctly absent.

Reference: `skills/health/SKILL.md` — the strictly read-only pattern — declares `disallowed-tools: Edit, Write, NotebookEdit` (confirmed at line 6).

design-extract's case differs (it does produce one output file), so `disallowed-tools: Edit, Write, NotebookEdit` would break functionality. The hardening path is narrower: drop `Edit` from `allowed-tools` and change idempotent re-run to use `Write` (full overwrite of DESIGN.md), eliminating the broad edit vector.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Evidence: `awk 'NR>=10' skills/design-extract/SKILL.md | wc -l` → `180` lines.

180 ≤ 450 target ≤ 500 hard limit. Well within budget.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not declare `TeamCreate` or `SendMessage`. design-extract spawns no agents. No spawn-idiom check required.

---

## Summary

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| V1 Frontmatter | PASS | validate script OK; all fields present; description 359 chars |
| V2 OUTPUT STYLE | PASS | byte-identical match vs canonical |
| V3 Link resolution | PASS | markdown-link-validate OK (397 links) |
| V4 Owner compliance | N/A | no O-owner delegation |
| V5 Pipeline I/O | PASS | DESIGN.md consumed by ui-build:130 + design-critic:6,41 |
| V6 DW wiring | N/A | not codebase-audit/research |
| V7 Disallowed-tools | FAIL | Edit in allowed-tools contradicts DoD "read-only on codebase" claim |
| V8 Body-line budget | PASS | 180 lines (hard limit 500) |
| V9 Spawn-idiom | N/A | no TeamCreate/SendMessage declared |

**Skill verdict: needs-hardening**

**Highest-leverage fix:** Drop `Edit` from `allowed-tools`; rewrite idempotent re-run path in Phase 4 to use `Write` (full overwrite of DESIGN.md). This closes the contradiction between the DoD "read-only on the codebase" claim and the current broad Edit permission, without breaking the single legitimate write target (`DESIGN.md`).
