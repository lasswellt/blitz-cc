---
unit: setup
validated: 2026-05-28
validator: claude-sonnet-4-6
sprint: v1.16.0
verdict: needs-hardening
highest_leverage_fix: "Add `disallowed-tools: Edit, Write, NotebookEdit` to SKILL.md frontmatter — prose 'read-only by default' is not enforcement; the model can still call Edit/Write under Bash-only allowed-tools since Bash is present."
---

# Setup Skill — v1.16.0 Cohesion+DW Validation

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/setup/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: setup` — SKILL.md:2
- `description` — 349 chars, third-person, ≤1024 — SKILL.md:3
- `model: sonnet` — SKILL.md:5
- `effort: low` — SKILL.md:6
- `compatibility: ">=2.1.71"` — SKILL.md:7
- `allowed-tools: Read, Bash, Glob, Grep` — SKILL.md:4

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Canonical line extracted from `skills/_shared/terse-output.md` (between `canonical-output-style-start` / `canonical-output-style-end` markers) compared byte-identical to SKILL.md:22. Shell comparison: `MATCH`.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/setup/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/` links (`session-lifecycle.md`, `terse-output.md`, `terse-output.md`) and `references/main.md` resolve to real files. `references/main.md` confirmed at `skills/setup/references/main.md`.

**Minor observation (non-blocking):** Phase 2 inline bash references `${CLAUDE_PLUGIN_ROOT}/skills/setup/conflict-catalog.json` (missing `/assets/` subdirectory), while Error Recovery prose says `assets/conflict-catalog.json` (missing root path). Actual file is at `skills/setup/assets/conflict-catalog.json`. Neither path as written is fully correct. This is a runtime correctness issue, not a link-validation failure.

---

## V4 — Canonical-Owner Compliance

**N/A**

`setup` is a standalone diagnostic skill. It is not an O1–O5 pipeline owner and does not delegate to one. No bidirectional citation required. Confirmed: `skills/_shared/session-lifecycle.md` contains no pipeline chain referencing `setup` as producer or consumer.

---

## V5 — Pipeline I/O Composition

**N/A**

`setup` has no upstream producer and no downstream consumer in the sprint pipeline (`session-lifecycle.md` contains zero pipeline entries for `setup`). It is an advisory, read-only diagnostic invoked ad hoc. No I/O composition contract to validate.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

`setup` is neither `codebase-audit` nor `research`. Dynamic-Workflows dispatch gate is not applicable.

---

## V7 — Disallowed-Tools Gap

**FAIL**

`setup` is explicitly read-only by construction:
- SKILL.md:30: "**This skill is read-only by default.**"
- SKILL.md:36: "SAFETY RULES — 1. Read-only analysis. Do not modify the user's CLAUDE.md files."

`allowed-tools: Read, Bash, Glob, Grep` (SKILL.md:4) does NOT include Edit/Write/NotebookEdit, which is correct. However, the frontmatter does **not** declare `disallowed-tools: Edit, Write, NotebookEdit`.

Benchmark: `skills/health/SKILL.md:6` declares `disallowed-tools: Edit, Write, NotebookEdit` despite having the same `allowed-tools` set. Prose safety rules are advisory; the `disallowed-tools` frontmatter field is the enforced mechanical gate. Without it, the model can call Edit/Write at inference time (e.g., via a confused tool path through the Bash runner). Category: **needs-hardening**.

---

## V8 — Body-Line Budget

**PASS**

Body (lines 10–199, after frontmatter close fence at line 9): `awk 'NR>=10' skills/setup/SKILL.md | wc -l` → **190 lines**. Well within the 450-line target and 500-line hard cap.

---

## V9 — Spawn-Idiom Consistency

**N/A**

`allowed-tools: Read, Bash, Glob, Grep` — no `TeamCreate` or `SendMessage` declared. The occurrence of `TeamCreate` and `SendMessage` in the file (SKILL.md:101) is inside an inline bash snippet demonstrating which tools the skill *checks for* in the user's settings — not a declaration that this skill uses them. No spawn-idiom drift.

---

## Summary

| Check | Verdict | Evidence |
|---|---|---|
| V1 Frontmatter contract | PASS | `skill-frontmatter-validate.sh` OK; all 6 fields present, desc 349 chars |
| V2 OUTPUT STYLE snippet | PASS | Byte-identical match to canonical `terse-output.md` line |
| V3 Shared-protocol citations | PASS | `markdown-link-validate.sh` OK (397 links); `references/main.md` exists |
| V4 Canonical-owner compliance | N/A | Standalone diagnostic; no O1–O5 delegation chain |
| V5 Pipeline I/O composition | N/A | No pipeline chain; ad hoc diagnostic skill |
| V6 DW wiring | N/A | Not `codebase-audit` or `research` |
| V7 Disallowed-tools gap | FAIL | Prose says read-only; no `disallowed-tools: Edit, Write, NotebookEdit` in frontmatter |
| V8 Body-line budget | PASS | 190 lines (target ≤450, hard cap ≤500) |
| V9 Spawn-idiom consistency | N/A | No TeamCreate/SendMessage in allowed-tools |

**Skill verdict:** `needs-hardening`

**Highest-leverage fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to SKILL.md frontmatter (after the `allowed-tools` line). Mechanically enforces the read-only guarantee that is currently only stated in prose. Mirrors the pattern in `skills/health/SKILL.md:6`.
