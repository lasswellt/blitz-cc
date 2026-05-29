# Skill Validation: release — v1.16.0 Cohesion+DW

**Validator:** Claude Code (claude-sonnet-4-6)  
**Date:** 2026-05-28  
**Files checked:** `skills/release/SKILL.md`, `skills/release/references/main.md`  
**Unit notes:** OWNER O1/O5 (canonical changelog). Bidirectional consumers: `doc-gen` + `ship`.

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script run: `hooks/scripts/skill-frontmatter-validate.sh skills/release/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual verification of each required field:
- `name: release` — present, line 2
- `description:` — 373 chars (limit 1024), third-person ("Manages…"), present, line 3
- `model: opus` — present, line 5
- `effort: medium` — present, line 6
- `compatibility: ">=2.1.71"` — present, line 7
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — present, line 4 (skill is invokable — field required and present)

Bonus fields present: `argument-hint` (line 8), `disable-model-invocation: true` (line 9).

Script verdict matches manual read. **PASS.**

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`):

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

`SKILL.md` line 21 contains byte-identical text. Shell comparison returned `EXACT MATCH`. **PASS.**

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Script run: `hooks/scripts/markdown-link-validate.sh skills/release/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links checked manually:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` EXISTS
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` EXISTS
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` EXISTS
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` EXISTS
- `references/main.md` → `skills/release/references/main.md` EXISTS

Script verdict: all 397 links valid. **PASS.**

---

## V4 — Canonical-Owner Compliance (Bidirectional)

**Verdict: PASS**

`skills/release` declares itself the canonical owner at `SKILL.md:119`:

> **Canonical changelog owner (O1/O5).** `skills/release` is the SINGLE source of the commit-type → changelog-section map and the Keep a Changelog emit logic. `doc-gen` (`changelog` mode) and `ship` (Phase 2) MUST delegate here — they do not restate this map.

Consumer citations verified:
- **doc-gen** `SKILL.md:178`: `"The commit-type → changelog-section map is owned by [skills/release](../release/SKILL.md) (O1)."` ✓
- **ship** `SKILL.md:159`: `"Delegate to release (O5). …owned by [skills/release](../release/SKILL.md) §changelog. ship does NOT restate the map…"` ✓

Bidirectional link verified: release names both consumers; both consumers cite back to release with O-number. Neither consumer duplicates the commit-type → section map as canonical logic. **PASS.**

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `sprint-review → ship → release`

Per `skills/_shared/state-handoff.md §ship` (lines 88-90):
- Producer: `ship Phase 2 (release)` → artifact: `CHANGELOG.md entry` → consumer: Public release notes
- Producer: `ship Phase 4` → artifact: `Tag v<X.Y.Z>` → consumer: npm/marketplace publish
- Producer: `ship` → artifact: `.cc-sessions/release-state.json` → consumer: rollback recovery

`ship` invokes release as a sub-step, passing `[version]` via `$ARGUMENTS`. `release Phase 0.1` parses mode and version from `$ARGUMENTS` — this matches exactly what ship provides (`/blitz:release prepare [version]`, ship SKILL.md line 177).

`release Phase 1` reads: `package.json` (version), `git describe --tags`, `lerna.json/plugin.json/marketplace.json`, commit history — all standard project artifacts, not pipeline artifacts requiring prior skill output.

Release produces: `CHANGELOG.md` entry (Phase 3.3), release branch (Phase 3.1), git tag (Phase 5.3). These match state-handoff.md §ship declarations. No mismatch between emitted and declared artifacts. **PASS.**

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

`release` is not `codebase-audit` or `research`. Dynamic-Workflows dispatch gate does not apply. **N/A.**

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`release` is not read-only-by-construction. It writes files (`CHANGELOG.md`, version files), creates git tags, pushes to remote, and creates GitHub releases. `disallowed-tools` enforcement is inapplicable — the skill legitimately needs Write/Edit. No gap. **N/A.**

---

## V8 — Body-Line Budget

**Verdict: PASS (WATCH)**

Total file lines: 487 (`wc -l skills/release/SKILL.md`)  
Frontmatter fences: line 1 (`---`) through line 10 (`---`)  
Body = 487 − 10 = **477 lines**

Hard limit: 500. Target: 450. Body is at 477 — within hard limit but 27 lines over target. Unit notes flagged `body-watch ~478`; actual count 477 confirms the watch warning. **PASS (at hard limit boundary — 23 lines of margin; target breached by 27).**

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — does NOT include `TeamCreate` or `SendMessage`. `release` does not spawn sub-agents; it executes git/gh commands directly via Bash. No spawn-idiom concern. **N/A.**

---

## Summary Table

| ID | Check | Verdict | Evidence (file:line or command) |
|----|-------|---------|----------------------------------|
| V1 | Frontmatter contract | PASS | `skill-frontmatter-validate.sh` → OK; all 6 required fields present at SKILL.md:2-8 |
| V2 | OUTPUT STYLE snippet | PASS | Shell byte-compare → EXACT MATCH; SKILL.md:21 vs terse-output.md canonical |
| V3 | Shared-protocol citations resolve | PASS | `markdown-link-validate.sh` → OK (397 links); all `/_shared/` refs resolve |
| V4 | Canonical-owner compliance (bidirectional) | PASS | release SKILL.md:119 declares O1/O5; doc-gen:178 + ship:159 cite back with O-number |
| V5 | Pipeline I/O composition | PASS | state-handoff.md:88-90 §ship; ship:177 passes `[version]`; release Phase 0.1 consumes it |
| V6 | Dynamic-Workflows wiring | N/A | Not codebase-audit or research |
| V7 | Disallowed-tools gap | N/A | Not read-only-by-construction; Write/Edit legitimately required |
| V8 | Body-line budget | PASS | 477 lines (hard 500 OK; target 450 breached by 27) |
| V9 | Spawn-idiom consistency | N/A | No TeamCreate/SendMessage in allowed-tools |

---

## Skill Verdict

**cohesive**

All contract checks pass. Bidirectional O1/O5 ownership is correctly wired — both consumers (`doc-gen`, `ship`) cite back without restating the canonical map. OUTPUT STYLE is byte-identical to canonical source. Link validation clean across 397 links.

## Highest-Leverage Fix

**Trim body by 27+ lines to meet the ≤450-line target.** At 477 lines the skill is within the 500-line hard cap but breaches the 450-line target. The rollback section (Phase 6, lines 396–456) and error-recovery section (lines 477–487) contain verbose prose and repeated bash snippets that partially duplicate `references/main.md §Rollback Procedure`. Delegating the manual rollback steps entirely to `references/main.md` (with a pointer) would reclaim ~20 lines and push the body below target.
