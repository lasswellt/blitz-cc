# Validation Report: sprint-plan — v1.16.0 Cohesion+DW

**Date:** 2026-05-28
**Unit:** sprint-plan
**Files checked:** `skills/sprint-plan/SKILL.md`, `skills/sprint-plan/references/main.md`
**Verdict:** cohesive

---

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/sprint-plan/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields:
- `name: sprint-plan` (matches directory)
- `description:` 355 chars, third-person ("Plans the next sprint…"), ≤ 1024 ✓
- `model: opus` ✓
- `effort: high` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent` ✓ (skill is invokable)

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Canonical snippet from `skills/_shared/terse-output.md` (lines 12–13, between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`) found verbatim at `SKILL.md:25`:

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

Python byte-level comparison: `canonical in content` → `True`.

`references/main.md` also contains the snippet (lines 201–205, inside the agent prompt code block, word-wrapped). Semantic reconstruction matches canonical byte-for-byte. Invariant 5 satisfied for both files.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/sprint-plan/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

`hooks/scripts/markdown-link-validate.sh skills/sprint-plan/references/main.md` → `markdown-link-validate: OK (397 link(s) checked)`

Manual cross-check of all `/_shared/` targets:

| File | Exists |
|---|---|
| `skills/_shared/story-frontmatter.md` | ✓ |
| `skills/_shared/state-handoff.md` | ✓ |
| `skills/_shared/context-management.md` | ✓ |
| `skills/_shared/checkpoint-protocol.md` | ✓ |
| `skills/_shared/carry-forward-registry.md` | ✓ |
| `skills/_shared/spawn-protocol.md` | ✓ |
| `skills/_shared/terse-output.md` | ✓ |
| `skills/_shared/definition-of-done.md` | ✓ |
| `skills/_shared/session-protocol.md` | ✓ |
| `skills/_shared/verbose-progress.md` | ✓ |

---

## V4 — Canonical-Owner Compliance

**N/A**

Unit notes: sprint-plan has no special O1–O5 owner/consumer role. No owner delegation found on read.

---

## V5 — Pipeline I/O Composition

**PASS**

Chain: `roadmap → sprint-plan → sprint-dev`

Per `skills/_shared/state-handoff.md` §roadmap (lines 48–50):
- `docs/roadmap/roadmap-registry.json` — producer: `roadmap`; consumer: `sprint-plan Phase 0 step 2` (Required)
- `docs/roadmap/epic-registry.json` — producer: `roadmap`; consumer: `sprint-plan Phase 0 step 2` (Required)
- `.cc-sessions/carry-forward.jsonl` (`event: "created"`) — producer: `roadmap extend Phase 1.1.5`; consumer: `sprint-plan Phase 0 step 8`

Per `skills/_shared/state-handoff.md` §sprint-plan (lines 56–61), sprint-plan produces:
- `sprints/sprint-${N}/manifest.json` → consumed by `sprint-dev Phase 0.0` (Required)
- `sprints/sprint-${N}/stories/S${N}-*.md` → consumed by `sprint-dev` (Required ≥ 1)
- `sprint-registry.json` (entry added) → consumed by `sprint-dev`, `sprint-review`, `ship` (Required)

SKILL.md Phase 0.0 hard-fails on missing `roadmap-registry.json` and `epic-registry.json` (lines 63–74), citing `state-handoff.md §sprint-plan`. SKILL.md Phase 1.4 writes `manifest.json`, Phase 3.2 writes stories, Phase 4.5 writes `sprint-registry.json`. All match exactly.

Carry-forward optionality is correctly declared: OPTIONAL at Phase 0.0 gate (SKILL.md line 76), processed in Phase 0 step 8 (SKILL.md lines 95–106).

---

## V6 — Dynamic-Workflows Wiring

**N/A**

Unit notes: V6 applies only to `codebase-audit` and `research`. sprint-plan has no DW dispatch gate.

---

## V7 — Disallowed-Tools Gap

**N/A**

sprint-plan is not read-only by construction — it writes story files, manifest.json, sprint-registry.json, carry-forward.jsonl entries, and GitHub issues. `allowed-tools` correctly includes `Write`, `Edit`, and `Bash`. No `disallowed-tools` declaration is needed or appropriate.

---

## V8 — Body-Line Budget

**PASS**

Body definition: lines after second `---` fence (line 10) through EOF.

```
Total file lines: 450
Body lines (line 11 to EOF): 441
```

441 ≤ 450 target and ≤ 500 hard limit. ✓

(Python measurement: second `---` at 0-indexed line 9; body = `lines[10:]` = 441 lines.)

---

## V9 — Spawn-Idiom Consistency

**N/A**

`allowed-tools` does NOT declare `TeamCreate` or `SendMessage`. Sprint-plan uses the canonical `Agent` tool pattern for research agent spawning (SKILL.md lines 155–166). No drift from canonical Agent() pattern. No exception check needed.

---

## Skill Verdict

**cohesive**

All 5 applicable checks (V1, V2, V3, V5, V8) PASS. V4, V6, V7, V9 are N/A per unit notes.

## Highest-Leverage Fix

None required — skill is cohesive. If hardening is desired: the word-wrapped OUTPUT STYLE snippet in `references/main.md` (lines 201–205) will not be caught by the hash-compare validator (which checks SKILL.md, not references files). Adding a comment like `<!-- canonical-output-style: verbatim below, do not reformat -->` above that block would make future drift detectable by grep.
