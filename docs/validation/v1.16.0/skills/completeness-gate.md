# Validation Report: completeness-gate — v1.16.0

**Date:** 2026-05-28
**Validator:** Claude Code (automated rubric)
**Unit:** `skills/completeness-gate/SKILL.md` + `skills/completeness-gate/references/main.md`
**Unit notes:** OWNER O2 (anti-mock pattern set); CONSUMER O3 (delegates wiring to integration-check); read-only-by-construction (V7 candidate).

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script output: `hooks/scripts/skill-frontmatter-validate.sh skills/completeness-gate/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual verification:
- `name: completeness-gate` — present (SKILL.md:2)
- `description`: 396 chars (≤1024); third-person ("Scans code…"); present (SKILL.md:3)
- `allowed-tools: Read, Bash, Glob, Grep` — present (SKILL.md:4); skill is invokable
- `model: sonnet` — present (SKILL.md:5)
- `effort: medium` — present (SKILL.md:6)
- `compatibility: ">=2.1.71"` — present (SKILL.md:7)

All required fields present; validator confirmed OK.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

SKILL.md line 20 contains the OUTPUT STYLE directive. Byte-for-byte comparison with canonical (extracted from `<!-- canonical-output-style-start -->` block in `skills/_shared/terse-output.md`):

Both produce identical string:
`OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.`

No drift. Invariant 5 satisfied.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Script: `hooks/scripts/markdown-link-validate.sh skills/completeness-gate/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Citations in SKILL.md body:
- `/_shared/session-lifecycle.md` (SKILL.md:46) → `skills/_shared/session-lifecycle.md` — exists
- `/_shared/terse-output.md` (SKILL.md:46) → `skills/_shared/terse-output.md` — exists
- `references/main.md` (SKILL.md:16, 113) → `skills/completeness-gate/references/main.md` — exists
- `/_shared/terse-output.md` (SKILL.md:17) → `skills/_shared/terse-output.md` — exists
- `/_shared/quality-engine.md` (SKILL.md:115) → `skills/_shared/quality-engine.md` — resolves per validator
- `../integration-check/SKILL.md` (SKILL.md:202, 221) — resolves per validator

All 397 links checked by validator; no broken links reported.

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

### O2 Owner (completeness-gate owns anti-mock pattern set)

Bidirectional citation confirmed:

- `sprint-review` SKILL.md:127 cites: `"the canonical anti-mock set is owned by [completeness-gate](../completeness-gate/SKILL.md) §Checks (O2). The inline pattern below mirrors it for the review-time diff scan — keep in sync with completeness-gate's references/main.md §grep-patterns."`
- `code-sweep` SKILL.md:109 cites: `"The placeholder/anti-mock checks … source their patterns from the canonical set owned by [completeness-gate](../completeness-gate/SKILL.md) §Checks (O2). code-sweep applies them under its ratchet…"`
- completeness-gate SKILL.md:115 declares ownership: `"Canonical anti-mock pattern set (O2). completeness-gate owns the canonical placeholder/anti-mock pattern set…"`

### O3 Consumer (completeness-gate delegates to integration-check)

- SKILL.md §2.11 (line 200-204): explicitly delegates `unwired-store-actions` to `integration-check`, citing `../integration-check/SKILL.md`, stating "completeness-gate does NOT re-implement it"
- SKILL.md §2.12 Level 3 (line 221-223): explicitly delegates L3 wired-detection to `integration-check`
- `integration-check` SKILL.md:29 cites back: `"completeness-gate delegates its wiring checks (2.11 unwired-store-actions, 2.12 Level-3 Wired) here rather than re-implementing them"`

Bidirectional citation verified both ways. No logic duplication found.

**Minor observation:** `references/main.md` row 12 (grep-patterns table) still lists a full grep pattern for `unwired-store-actions`, contradicting the delegation claim in §2.11. The pattern catalog in references/main.md has not been cleaned up to reflect delegation — the row describes what integration-check owns. This is a documentation inconsistency (the check body correctly delegates; the reference table retains the orphan pattern row). Does not break functional behavior since the SKILL.md body prohibits completeness-gate from executing that check, but the catalog is misleading.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Traced chain: `sprint-dev → completeness-gate` (as mid-sprint gate at Phase 3.5):

**Sprint-dev produces (per SKILL.md:377):**
`git diff --name-only ${SPRINT_BASE}..HEAD -- '*.ts' '*.tsx' '*.vue'` — a list of changed source files passed as the scope argument.

**completeness-gate consumes:**
- Scope argument: path or `all` (SKILL.md §0.1) — matches what sprint-dev provides
- Story `files` fields from frontmatter (SKILL.md §2.12): consumed when sprint context is provided — matches `sprint-contracts.md` field `files` (string[], producer: sprint-plan Phase 3.2, confirmed at `_shared/sprint-contracts.md:112`)

**completeness-gate produces:**
- `${SESSION_TMP_DIR}/completeness-gate.json` (SKILL.md §4.1) — JSON with findings, score, grade

**Downstream consumer:** sprint-review (SKILL.md:127 confirms it reads the O2 pattern set; sprint-dev Phase 3.5 line 377 notes score < C flags findings in integration report for sprint-review's final call).

State-handoff.md does not have a dedicated completeness-gate row (the artifact is transient / SESSION_TMP_DIR-scoped), but the sprint-dev §sprint-dev table covers the sprint-dev → sprint-review chain. The SESSION_TMP_DIR artifact is consistent with the ephemeral-artifact convention used by other non-pipeline skills.

I/O composition is coherent with `_shared/session-lifecycle.md` and `_shared/sprint-contracts.md`.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

completeness-gate is not `codebase-audit` or `research`. Confirmed: no `BLITZ_DISPATCH`, `Workflow`, or `dynamic-workflow` references in SKILL.md. DW check not applicable to this unit.

---

## V7 — Disallowed-Tools Gap

**Verdict: FAIL**

SKILL.md:34 declares: `"This skill is READ-ONLY — never modify source files, test files, or configuration files."` — prose safety rule.

SKILL.md frontmatter (lines 1-9): `allowed-tools: Read, Bash, Glob, Grep` — no `disallowed-tools:` field present.

Comparison: `skills/health/SKILL.md` (also read-only-by-construction) declares `disallowed-tools: Edit, Write, NotebookEdit` at frontmatter line 6.

Prose "READ-ONLY" in SAFETY RULES is not enforcement — the platform ignores it. `Edit`, `Write`, and `NotebookEdit` are not blocked at the tool-call level. The skill is a read-only candidate per unit notes but is missing the hardening declaration.

**Required fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to frontmatter (after `allowed-tools` line).

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body line count (between second `---` fence and EOF, computed with awk):

```
awk '/^---$/{count++; if(count==2){body=1; next}} body{lines++} END{print lines}' SKILL.md
```

Result: **387 body lines** (hard limit: 500; target: 450). Within both limits.

Total file lines: 396 (`wc -l`). Frontmatter occupies 9 lines.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools: Read, Bash, Glob, Grep` — `TeamCreate` and `SendMessage` are NOT declared. This skill does not spawn agents. No spawn-idiom check required; the allowed-tools set is consistent with a single-agent read-only scanner.

---

## Summary Table

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → OK; all 6 required fields verified at SKILL.md:2-7 |
| V2 OUTPUT STYLE | PASS | SKILL.md:20 byte-identical to canonical terse-output.md canonical block |
| V3 Link resolution | PASS | `markdown-link-validate.sh` → OK (397 links checked) |
| V4 Owner compliance | PASS | O2 bidirectional: sprint-review:127 + code-sweep:109 cite back; O3 bidirectional: integration-check:29 cites back |
| V5 Pipeline I/O | PASS | sprint-dev Phase 3.5 provides changed-files scope; story-frontmatter `files` field matches §2.12 consumption; SESSION_TMP_DIR artifact is ephemeral per convention |
| V6 DW wiring | N/A | Not codebase-audit or research; no DW references in SKILL.md |
| V7 Disallowed-tools | FAIL | No `disallowed-tools:` in frontmatter; prose SAFETY RULES:34 "READ-ONLY" not enforced; health skill shows correct pattern |
| V8 Body-line budget | PASS | 387 body lines (hard limit 500, target 450) |
| V9 Spawn idiom | N/A | No TeamCreate/SendMessage in allowed-tools |

---

## Skill Verdict

**needs-hardening**

The skill is functionally coherent — correct O2 ownership, correct O3 delegation, correct OUTPUT STYLE, all links resolve, pipeline I/O is sound. The single gap is enforcement: the read-only guarantee is prose-only and not backed by a `disallowed-tools` declaration.

**Highest-leverage fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to the frontmatter block (after `allowed-tools: Read, Bash, Glob, Grep`). One line. Closes V7 and hardens the read-only invariant at the platform level.

**Secondary observation (non-blocking):** `references/main.md` grep-patterns table row 12 retains a full pattern definition for `unwired-store-actions` despite §2.11 delegating that check to integration-check. The table row should be replaced with a delegation note (e.g., "See integration-check/references/main.md §unwired-store-actions") to avoid confusion about which skill runs the check.
