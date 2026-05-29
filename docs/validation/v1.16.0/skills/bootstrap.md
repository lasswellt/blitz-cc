# Skill Validation: bootstrap — v1.16.0 Cohesion+DW

**Date:** 2026-05-28  
**Unit:** bootstrap  
**Files:** `skills/bootstrap/SKILL.md`, `skills/bootstrap/references/main.md`  
**Validator:** automated rubric (V1–V9)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Run: `hooks/scripts/skill-frontmatter-validate.sh skills/bootstrap/SKILL.md`  
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present:
- `name: bootstrap` ✓
- `description`: 442 chars (≤1024), starts "Scaffolds new projects…" — third-person ✓
- `model: opus` ✓
- `effort: medium` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch` ✓ (skill is invokable, field present)
- Bonus: `argument-hint` present (valid optional field)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical line (from `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start/end -->`):

> `OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.`

`SKILL.md` line 21: byte-identical match confirmed by grep comparison. No drift.

The file also includes a valid LITE-intensity exemption block at lines 25–26 ("Terse exemptions (LITE intensity)"), which is a legal extension per the protocol.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Run: `hooks/scripts/markdown-link-validate.sh skills/bootstrap/SKILL.md`  
Output: `markdown-link-validate: OK (397 link(s) checked)`

Manual check of all `/_shared/` markdown links in SKILL.md:

| Link | Resolves to | Status |
|------|-------------|--------|
| `/_shared/definition-of-done.md` | `skills/_shared/definition-of-done.md` | OK |
| `/_shared/package-install-policy.md` | `skills/_shared/package-install-policy.md` | OK |
| `/_shared/session-protocol.md` | `skills/_shared/session-protocol.md` | OK |
| `/_shared/state-handoff.md` | `skills/_shared/state-handoff.md` | OK |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | OK |
| `/_shared/verbose-progress.md` | `skills/_shared/verbose-progress.md` | OK |

All 6 `/_shared/` links resolve. Validator ran 397 links total with no failures.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Unit notes state: "No special owner/DW/spawn role. V4 is N/A unless own read finds otherwise." No O1–O5 owner delegation found in SKILL.md.

---

## V5 — Pipeline I/O Composition

**Verdict: FAIL**

Chain: `bootstrap → research → roadmap → sprint-plan`

Per `skills/_shared/state-handoff.md` lines 25–35, the contract states:

> "bootstrap Phase 5 must: initialize `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json` as empty stubs even on greenfield, OR explicitly print 'Roadmap not initialized — run /blitz:roadmap before /blitz:sprint-plan'. Silent absence is the failure mode."

Checking Phase 5 in `skills/bootstrap/SKILL.md` (lines 262–282):
- Phase 5.1 output summary mentions only: files created count, type-check, lint, tests, and next steps.
- Phase 5.2 is session cleanup.
- **Neither phase initializes `docs/roadmap/roadmap-registry.json` or `docs/roadmap/epic-registry.json`, nor does either print the required fallback message.**

The description field (frontmatter line 3) mentions "empty roadmap stubs" as a greenfield behavior, but this is only in the marketing blurb — there is no corresponding phase instruction that executes the stub creation or prints the required message.

Downstream consumer `sprint-plan` Phase 0 hard-fails if these files are absent. The SKILL.md does not satisfy the contract's mandatory alternative ("OR explicitly print…").

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Unit notes state: "V6 is N/A" for bootstrap. Bootstrap is not `codebase-audit` or `research`. No DW dispatch gate present or required.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

Bootstrap is a write-heavy skill (scaffolds files, runs commands). It is not read-only-by-construction. `allowed-tools` correctly includes Write, Edit, Bash. No `disallowed-tools` enforcement gap applies.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Total file: 294 lines (confirmed via `wc -l`).  
Frontmatter: lines 1–9 (first `---` at line 1, closing `---` at line 9).  
Body: `294 - 9 = 285 lines` (confirmed via `awk 'NR>9' | wc -l`).

285 ≤ 450 target ✓, well within 500 hard cap ✓.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not declare `TeamCreate` or `SendMessage`. No spawn idioms present. No exception needed.

---

## Summary

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` OK; all fields confirmed |
| V2 OUTPUT STYLE | PASS | Byte-identical match with canonical at SKILL.md:21 |
| V3 Link resolution | PASS | `markdown-link-validate.sh` OK (397 links); all 6 `/_shared/` refs resolve |
| V4 Owner compliance | N/A | No owner delegation |
| V5 Pipeline I/O | FAIL | Phase 5 omits required roadmap stub init / fallback print per state-handoff.md:35 |
| V6 DW wiring | N/A | Not codebase-audit/research |
| V7 Disallowed-tools | N/A | Write-heavy skill, not read-only-by-construction |
| V8 Body lines | PASS | 285 lines (target ≤450, hard cap ≤500) |
| V9 Spawn idioms | N/A | No TeamCreate/SendMessage |

---

## Skill Verdict

**`needs-tightening`**

---

## Highest-Leverage Fix

Add a Phase 5.0 step to `skills/bootstrap/SKILL.md` that either (a) creates `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json` as empty JSON stubs (`{}`) on greenfield runs, or (b) emits the exact required message `"Roadmap not initialized — run /blitz:roadmap before /blitz:sprint-plan"` on non-greenfield runs — satisfying the `state-handoff.md:35` mandatory contract so `sprint-plan` Phase 0 does not hard-fail silently.
