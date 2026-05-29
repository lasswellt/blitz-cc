# Validation Report — integration-check (v1.16.0 Cohesion+DW)

**Date:** 2026-05-28  
**Validator:** cli-valid-ic01  
**Files checked:**
- `skills/integration-check/SKILL.md` (189 lines total)
- `skills/integration-check/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Evidence:
- `hooks/scripts/skill-frontmatter-validate.sh skills/integration-check/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`
- Fields present: `name: integration-check`, `description` (415 chars, third-person, ≤1024 ✓), `model: opus`, `effort: medium`, `compatibility: ">=2.1.71"`, `allowed-tools: Read, Write, Bash, Glob, Grep, Agent`
- `argument-hint` present (optional extension, valid)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Evidence:
- SKILL.md line 21: byte-identical match confirmed via shell comparison (`[ "$CANONICAL" = "$SKILL_LINE" ]` → `MATCH`)
- Agent prompt template in `references/main.md` lines 65–68: OUTPUT STYLE snippet present inline; multi-line form normalizes to canonical — confirmed match after `tr '\n' ' '` normalization
- `references/main.md` line 10 explicitly notes: "OUTPUT STYLE inline preservation is required by sprint-review Invariant 5"

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Evidence:
- `hooks/scripts/markdown-link-validate.sh skills/integration-check/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`
- Spot-checked key links directly:
  - `skills/_shared/session-protocol.md` → exists ✓
  - `skills/_shared/verbose-progress.md` → exists ✓
  - `skills/_shared/spawn-protocol.md` → exists ✓
  - `skills/_shared/terse-output.md` → exists ✓
  - `skills/_shared/definition-of-done.md` → exists ✓

---

## V4 — Canonical-Owner Compliance (O3)

**Verdict: PASS**

Evidence:
- SKILL.md line 29: "**Canonical owner of wiring topology (O3).** integration-check is the single owner of cross-module wiring checks…"
- Bidirectional: `completeness-gate/SKILL.md` line 200–204 delegates to integration-check for `unwired-store-actions` (§2.11) with explicit cite: "Wiring topology is owned by [`integration-check`](../integration-check/SKILL.md)"
- `completeness-gate/SKILL.md` line 221: L3 Wired delegated similarly: "orphan/importer (wired) detection is owned by [`integration-check`](../integration-check/SKILL.md)"
- `sprint-dev/SKILL.md` line 338–340: Phase 3.5.0 invokes `/blitz:integration-check` as mandatory step before completeness-gate
- No restated logic found in completeness-gate for owned checks — delegation is clean (checks cite integration-check; they do not re-implement patterns)

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Evidence:
- `skills/_shared/state-handoff.md` does not list integration-check as a pipeline artifact producer/consumer — this is correct because integration-check is a transverse analysis skill invoked in-sprint (not a pipeline handoff artifact producer)
- Chain traced: `sprint-dev Phase 3.5.0 → /blitz:integration-check → completeness-gate`
  - sprint-dev invokes integration-check against the live working-tree source files (no artifact handoff required; source files ARE the input)
  - integration-check emits a findings report to stdout and writes `${SESSION_TMP_DIR}/check-*.json` (ephemeral, cleaned up at Phase 4 end per SKILL.md line 181)
  - completeness-gate delegates wiring checks to integration-check rather than consuming its JSON output — the delegation model means no artifact handoff is needed
- `state-handoff.md` anti-pattern check: integration-check correctly does NOT consume sprint-plan artifacts (manifest, stories) — its input is source files, consistent with its design as a read-only source analyzer

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Evidence: integration-check is not `codebase-audit` or `research`; DW dispatch is not applicable to this skill per rubric.

---

## V7 — Disallowed-Tools Gap

**Verdict: FAIL / needs-hardening**

Evidence:
- `allowed-tools: Read, Write, Bash, Glob, Grep, Agent` (SKILL.md line 4)
- SKILL.md line 31: "**This skill is read-only. It does NOT modify any code.**"
- No `disallowed-tools:` declaration present in frontmatter
- Comparator `health/SKILL.md` line 6 explicitly declares: `disallowed-tools: Edit, Write, NotebookEdit`
- Analysis: `Edit` and `NotebookEdit` are absent from `allowed-tools` (correctly excluded), but this is enforcement by omission — not explicit declaration. The rubric states "prose 'read-only' is not enforcement."
- `Write` is legitimately in `allowed-tools`: the orchestrator writes to `.cc-sessions/` (activity feed, `SESSION_TMP_DIR` setup via Bash `mkdir`). `Write` cannot be added to `disallowed-tools` without breaking session logging.
- Gap: `disallowed-tools: Edit, NotebookEdit` is absent. These two tools are not in `allowed-tools` but are not formally blocked. Adding them makes source-file protection explicit and auditable.
- `TeamCreate` and `SendMessage` are also absent from `allowed-tools` (canonical — skill uses `Agent` idiom per spawn-protocol.md line 79 guidance) but not in `disallowed-tools`; lower priority than Edit/NotebookEdit.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Evidence:
- Total file lines: 189 (via `wc -l`)
- Body lines (between second `---` fence and EOF): 180 (via awk counting)
- Hard limit: 500 ✓; target: 450 ✓; actual: 180 — well within budget

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

Evidence:
- `allowed-tools` does NOT include `TeamCreate` or `SendMessage` (SKILL.md line 4)
- Spawn idiom: `Agent` tool, confirmed by SKILL.md lines 82–88 ("call the `Agent` tool with: subagent_type: general-purpose, model: sonnet…")
- This matches spawn-protocol.md line 79: "`TeamCreate`+`SendMessage` does not accept `subagent_type` — the SDK picks by heuristic. Use the `Agent` tool instead (v1.4.0 migrated all spawning skills to this)."
- Explicit `model: sonnet` on each Agent spawn (SKILL.md line 84) prevents `[1m]` inheritance from Opus orchestrator — compliant with MEMORY.md note

---

## Summary

| Check | Verdict | Key Evidence |
|-------|---------|-------------|
| V1 Frontmatter | PASS | frontmatter-validate.sh OK; 415-char third-person description |
| V2 OUTPUT STYLE | PASS | Byte-identical match in SKILL.md line 21; agent template in references/main.md confirmed |
| V3 Link resolution | PASS | markdown-link-validate.sh OK (397 links); key linked files confirmed |
| V4 O3 owner compliance | PASS | Bidirectional: completeness-gate lines 200–223 delegate; sprint-dev line 338–340 invokes |
| V5 Pipeline I/O | PASS | Transverse tool — no artifact handoff required; chain sprint-dev → integration-check → completeness-gate traced |
| V6 DW wiring | N/A | Not codebase-audit or research |
| V7 Disallowed-tools | FAIL | No `disallowed-tools: Edit, NotebookEdit` declaration; enforcement by omission only |
| V8 Body-line budget | PASS | 180 body lines (hard limit 500, target 450) |
| V9 Spawn idiom | PASS | Agent tool used; model: sonnet explicit; no TeamCreate/SendMessage |

---

## Skill Verdict

**needs-hardening**

## Highest-Leverage Fix

Add `disallowed-tools: Edit, NotebookEdit` to the SKILL.md frontmatter (after `allowed-tools` line 4). This makes source-file protection explicit and auditable rather than relying on enforcement-by-omission, bringing it to parity with `health`'s hardening pattern. `Write` should remain in `allowed-tools` (needed for session logging and tmp-file orchestration).
