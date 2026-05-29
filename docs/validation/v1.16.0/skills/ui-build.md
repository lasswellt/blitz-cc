# v1.16.0 Validation — skills/ui-build

**Date:** 2026-05-28
**Validator session:** val-ui-build-a1b2c3d4
**Files examined:**
- `skills/ui-build/SKILL.md` (409 lines)
- `skills/ui-build/references/main.md` (222 lines)
- `skills/_shared/terse-output.md` (canonical OUTPUT STYLE)
- `skills/_shared/state-handoff.md`
- `skills/_shared/story-frontmatter.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script: `hooks/scripts/skill-frontmatter-validate.sh skills/ui-build/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual cross-check of SKILL.md lines 1–14:
- `name: ui-build` ✓
- `description:` — 395 chars, third-person ("Researches the codebase's design patterns…"), ≤1024 ✓
- `model: opus` ✓
- `effort: high` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Glob, Grep, Bash, ToolSearch, AskUserQuestion` — skill is invokable and tools are listed ✓

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` markers. SKILL.md line 31 byte-compared:

```
CANONICAL: OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
SKILL:     OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
Result:    MATCH
```

Shell comparison: `[ "$canonical" = "$skill" ] && echo MATCH` → `MATCH`

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Script: `hooks/scripts/markdown-link-validate.sh skills/ui-build/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Internal `/_shared/` links found in SKILL.md:
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — file exists ✓
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` — file exists ✓
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` — file exists ✓
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` — file exists ✓

All four resolved.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Unit notes specify V4 is N/A unless own read finds otherwise. No O1–O5 owner citations found in SKILL.md; no delegation markers; no ownership claim. Not in the owner/consumer matrix.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `sprint-plan → [story files] → sprint-dev → ui-build → DESIGN.md, .vue files`

Key handoff: `story-frontmatter.md` line 85 documents `design_quality` field: producer = `sprint-plan` (UI stories only), consumer = `ui-build` Phase 5.4.2 (design-critic spawning). SKILL.md line 315 reads `Story frontmatter \`design_quality:\` controls this step` — directly consuming the field documented in `story-frontmatter.md` line 125.

ui-build produces: `.vue` components, TypeScript types, `DESIGN.md` (Phase 3.0.2). These are implementation artifacts consumed downstream by the user/repo, not by another blitz skill — consistent with ui-build's position as a leaf skill. `state-handoff.md` does not list ui-build as a node in the core pipeline (bootstrap→ship), which is correct — it is invoked by sprint-dev agents, not as a pipeline step itself. No I/O mismatch found.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Unit notes specify V6 applies only to `codebase-audit` and `research`. ui-build is neither.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A (not read-only-by-construction)**

`allowed-tools` declares `Write` and `Edit` — ui-build intentionally creates and modifies `.vue`, `.ts`, and `DESIGN.md` files. It is not read-only-by-construction. The disallowed-tools hardening requirement does not apply. No gap.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body lines (second `---` fence to EOF): **395**

`awk` count: `Body lines: 395` — within hard cap of 500, within target of 450. Total file is 409 lines (14-line frontmatter + 395-line body).

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not declare `TeamCreate` or `SendMessage`. SKILL.md uses an inline `Agent({…})` call at Phase 5.4.2 (design-critic spawn) which is the canonical pattern per `spawn-protocol.md`. No drift.

---

## Summary

| Check | Verdict | Evidence |
|-------|---------|----------|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → OK; all required fields present; desc 395 chars |
| V2 OUTPUT STYLE | PASS | Byte-identical match to canonical; SKILL.md:31 |
| V3 Link resolution | PASS | `markdown-link-validate.sh` → OK (397 links); all 4 `/_shared/` refs resolve |
| V4 Owner compliance | N/A | No O1–O5 delegation, no owner role |
| V5 Pipeline I/O | PASS | `story-frontmatter.md`:125 documents `design_quality` producer→consumer; SKILL.md:315 consumes it |
| V6 DW wiring | N/A | Not codebase-audit or research |
| V7 Disallowed-tools | N/A | Not read-only; Write+Edit in allowed-tools |
| V8 Body-line budget | PASS | 395 body lines (hard cap 500, target 450) |
| V9 Spawn-idiom | N/A | No TeamCreate/SendMessage; canonical Agent() used |

---

## Skill Verdict

**cohesive**

All applicable checks pass. No contract violations, no drift, no hardening gap.

## Highest-Leverage Fix

None required. If a future improvement is desired: body is at 395/450 target lines — approaching the soft limit. Extracting the UI-framework variant sections (Tailwind/Quasar/Vuetify, lines 341–373) into `references/main.md` would buy ~33 lines of headroom and improve navigability.
