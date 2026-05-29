# Skill Validation: implement — v1.16.0

**Date:** 2026-05-28  
**Validator:** cli-implement-validate-v16-001  
**Files examined:** `skills/implement/SKILL.md` (no `references/main.md` exists)

---

## V1 — Frontmatter Contract

**Verdict:** PASS

`hooks/scripts/skill-frontmatter-validate.sh skills/implement/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: implement`
- `description:` — 211 chars (well under 1024 limit); third-person ("Runs the implementation phase…")
- `model: opus`
- `effort: low`
- `compatibility: ">=2.1.71"`
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent`
- `disable-model-invocation: false` (optional field, present)
- `argument-hint:` (optional, present)

---

## V2 — OUTPUT STYLE Snippet

**Verdict:** PASS

Python byte-compare of `skills/implement/SKILL.md` line 13 against the canonical snippet in `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`): exact match confirmed. No drift.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict:** PASS

`hooks/scripts/markdown-link-validate.sh skills/implement/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All four `/_shared/` links in the file resolve to real files on disk:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` EXISTS
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` EXISTS
- `/_shared/checkpoint-protocol.md` → `skills/_shared/checkpoint-protocol.md` EXISTS
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` EXISTS

---

## V4 — Canonical-Owner Compliance

**Verdict:** N/A

Unit notes declare V4 N/A unless own read finds otherwise. `implement` is classified in `skills/_shared/agent-routing.md:26` as a "single-spawn orchestrator" skill — it delegates to sprint-dev but is not an O1-O5 owner and does not restate sprint-dev logic. The skill body (50 lines) contains only flag parsing, pre-flight validation, and a thin invocation directive. No owned logic restated.

---

## V5 — Pipeline I/O Composition

**Verdict:** PASS

Chain traced: `sprint-plan → implement → sprint-dev`

Per `skills/_shared/state-handoff.md`:
- sprint-plan (Phase 1.4) produces `sprint-registry.json` (entry added, line 59) — implement Pre-Flight step 1 reads and validates `status: planned|in-progress` (SKILL.md line 38). Match confirmed.
- sprint-plan (Phase 3.2) produces `sprints/sprint-${N}/stories/S${N}-*.md` (line 57) — implement Pre-Flight step 2 verifies story files exist in `sprints/sprint-${N}/stories/` (SKILL.md line 39). Match confirmed.
- implement then invokes sprint-dev, passing sprint number or story IDs — sprint-dev's Phase 0.0 consumes the same manifest and story files (state-handoff.md line 56). The handoff is a skill invocation (not a file artifact), so there is no intermediate file contract to break.

All upstream artifacts implement consumes are exactly what sprint-plan produces per state-handoff.md. Composition is sound.

---

## V6 — Dynamic-Workflows Wiring

**Verdict:** N/A

Unit notes declare V6 N/A for all skills except `codebase-audit` and `research`. `implement` has no DW dispatch gate.

---

## V7 — Disallowed-Tools Gap

**Verdict:** N/A

`implement` is not read-only-by-construction. `allowed-tools` declares `Write, Edit` — it writes to the repo as part of pre-flight (build baseline check) and delegates to sprint-dev which writes extensively. No disallowed-tools enforcement is needed or expected.

---

## V8 — Body-Line Budget

**Verdict:** PASS

Body line count (lines after second `---` fence to EOF): **50 lines**.

Hard limit: 500. Target: 450. 50 lines is well within budget (10% of hard cap).

---

## V9 — Spawn-Idiom Consistency

**Verdict:** N/A

`allowed-tools` does not include `TeamCreate` or `SendMessage`. `implement` invokes sprint-dev as a skill (not a team spawn). No spawn-idiom check required.

---

## Skill Verdict

**cohesive**

All checks pass or are correctly N/A. The skill is a clean thin-wrapper delegation pattern: flag parsing → pre-flight validation → sprint-dev invocation. No logic duplication, no broken links, no output style drift, body well within budget.

---

## Highest-Leverage Fix

The `--mode` flag is documented in Flag Parsing (SKILL.md line 30) but never mentioned in the Execution section (lines 45-54) as something that gets passed through to sprint-dev. The prose says "passed through to sprint-dev" in the flag description but the Execution section omits it from the invocation directive. Add one bullet to the Execution section: "If `--mode` was specified, pass it through to sprint-dev." This closes a minor ambiguity where a model executing this skill might drop the flag at the handoff boundary.
