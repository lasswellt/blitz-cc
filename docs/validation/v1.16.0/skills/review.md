# v1.16.0 Cohesion+DW Validation — `review` skill

**Date:** 2026-05-28  
**Unit:** `review`  
**Files checked:** `skills/review/SKILL.md`, `skills/review/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script output: `hooks/scripts/skill-frontmatter-validate.sh skills/review/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present:
- `name: review` ✓
- `description`: 201 chars (≤1024) ✓, third-person phrasing ("Runs the review phase...") ✓
- `model: opus` ✓
- `effort: low` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent` ✓

No field is missing or invalid.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Python byte-compare confirms skill's OUTPUT STYLE line is identical to the canonical snippet from `skills/_shared/terse-output.md` (bounded by `<!-- canonical-output-style-start/end -->`). `Match: True`. Located at SKILL.md line 13.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/review/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links in SKILL.md:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` ✓
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` ✓

Link in `references/main.md`:
- `skills/sprint-review/references/main.md` → resolves (file exists) ✓

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

`review` is a thin wrapper/alias that delegates entirely to `sprint-review`. `references/main.md` lines 59–61 make the delegation explicit: "For all other templates, quality gates, auto-fix strategies, reviewer-specific checklists, and final-output formats, see `skills/sprint-review/references/main.md`. The wrapper does not duplicate that content — it only enforces the finding-format contract above."

`quality-matrix.md` line 27 documents the relationship: `review` is "(alias) — thin wrapper — flag-parses + forwards to sprint-review". Bidirectionality: `sprint-review/SKILL.md` does not explicitly cite `review` by name, but `quality-matrix.md` (the shared authority) documents the relationship bidirectionally. No owned logic is restated in the wrapper; finding-format in `references/main.md` is wrapper-specific, not a restatement of sprint-review internals.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `sprint-plan → sprint-dev → review → sprint-review`

Per `skills/_shared/state-handoff.md`:
- `sprint-registry.json` produced by sprint-plan Phase 4.5; consumed by sprint-review (line 59). Review skill reads `sprint-registry.json` to check `status: review|in-progress` (SKILL.md line 38). Confirmed: `sprint-registry.json` exists with `status` field present.
- Story files in `sprints/sprint-${N}/stories/` produced by sprint-plan; status transitioned to `done` by sprint-dev Phase 4.8 (state-handoff.md line 69). Review skill validates at least one story with `status: done` (SKILL.md line 39). Matches exactly.
- `.cc-sessions/*.json` session locks: reviewed by review skill for conflict detection (SKILL.md line 40); consistent with session-protocol.

All stated inputs match documented state-handoff.md producer outputs. No phantom consumption.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Unit notes specify V6 applies only to `codebase-audit` and `research`. `review` is not a DW pilot skill.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`review` is not read-only-by-construction. `allowed-tools` includes `Write`, `Edit`, `Bash` — the skill performs pre-flight reads, session checks, and delegates execution. No read-only claim made in prose or frontmatter. V7 hardening check does not apply.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body (lines after second `---` fence to EOF): **51 lines** (well under 450 target, hard cap 500). Confirmed by script: `Body line count: 51`, `Total lines in file: 61`.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` lists `Agent` but not `TeamCreate` or `SendMessage`. No parallel spawn pattern present in skill body — `Agent` is declared for potential use by sprint-review delegation. Unit notes specify V9 is N/A unless own read finds TeamCreate/SendMessage; neither is present.

---

## Skill Verdict

**cohesive**

All runnable checks pass. Frontmatter validated by hook script. OUTPUT STYLE matches canonical byte-for-byte. All links resolve. Delegation to sprint-review is clean and non-duplicating. Pipeline I/O aligns with state-handoff.md. Body is 51 lines (well under budget).

---

## Highest-Leverage Fix

`sprint-review/SKILL.md` does not cite the `review` wrapper by name; the bidirectional relationship exists only in `quality-matrix.md`. Adding a one-line note to `sprint-review/SKILL.md` (e.g., "Entry-point alias: `/blitz:review` (thin wrapper in `skills/review/SKILL.md`)") would make the delegation fully self-documenting without relying on the matrix as a cross-reference intermediary. Low-risk, no functional impact.
