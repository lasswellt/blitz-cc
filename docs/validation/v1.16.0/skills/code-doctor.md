# Validation Report — code-doctor (v1.16.0)

**Date:** 2026-05-28
**Unit:** skills/code-doctor/SKILL.md (+ skills/code-doctor/references/main.md)
**Validator:** cohesion+DW rubric V1..V9

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Command run: `bash hooks/scripts/skill-frontmatter-validate.sh skills/code-doctor/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present at SKILL.md lines 2–14:
- `name: code-doctor` (line 2)
- `description`: 307 chars, third-person, within 1024-char limit (line 3)
- `model: opus` (line 5)
- `effort: low` (line 6)
- `compatibility: ">=2.1.71"` (line 7)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent` (line 4) — skill is invokable, field present

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` lines 12–13 matches SKILL.md line 28 verbatim. Both read:

> OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

No drift detected.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Command run: `bash hooks/scripts/markdown-link-validate.sh skills/code-doctor/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

SKILL.md cites:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` — resolves
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — resolves
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` — resolves
- `references/main.md` → `skills/code-doctor/references/main.md` — resolves (file confirmed present)

All links validated by the script.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Unit notes for code-doctor: "No special owner/DW/spawn role. V4/V6/V9 are N/A unless your own read finds otherwise."

Own read confirms: no O1–O5 owner references, no delegation pattern, no consumer pointing back. This skill is a standalone auditor with no ownership chain.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

`quality-matrix.md` line 24 defines code-doctor's position: "invokes other skills: none; invoked by: manual". This is a terminal skill — no upstream producer that must emit inputs, no downstream consumer that must receive outputs. The skill's own I/O:
- Consumes: source files matching `paths:` globs (Vue/Firestore/Pinia files), optional `.code-doctor.json` config
- Produces: `docs/_audits/YYYY-MM-DD_code-doctor.md` (Phase 3.2), `.cc-sessions/code-doctor-ledger.jsonl` (Phase 3.4)

`state-handoff.md` has no code-doctor entry (confirmed: no output from `grep -n "code-doctor" skills/_shared/state-handoff.md`), consistent with its manual/standalone invocation mode — it is not in a pipeline chain that state-handoff tracks.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Per rubric: "ONLY codebase-audit/research; else N/A". code-doctor is neither. Own read confirms no `BLITZ_DISPATCH`, no `Workflow`, no dynamic-workflow references in SKILL.md.

---

## V7 — Disallowed-Tools Gap

**Verdict: FAIL (needs-hardening)**

code-doctor is documented as "read-only by default" (SKILL.md line 38: "Default mode is read-only (`--scan`)"). Safety Rule 1 (line 44) states: "Never modify files in `--scan` mode (the default)."

However, `allowed-tools` at line 4 includes `Write` and `Edit` with no `disallowed-tools` declaration. This means the model can invoke Write/Edit at any time — prose safety rules are not enforcement. Comparison:
- `blitz:health` declares `disallowed-tools: [Edit, Write, NotebookEdit]` (the hardened pattern)
- `blitz:code-doctor` declares `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent` — Edit and Write available unconditionally

The `--fix` mode legitimately needs Edit/Write, but in `--scan` mode (the default) these tools should be locked out by platform enforcement, not prose instruction. The current design relies entirely on the model following "Safety Rule 1" — which is a shortcut (prose-only enforcement), not a contract.

**Highest-leverage fix:** Either (a) split into two sub-skills (`code-doctor` read-only with `disallowed-tools: [Edit,Write,NotebookEdit]` and `code-doctor-fix` with Edit/Write), or (b) keep one skill but add a runtime guard at Phase 0 that detects `--scan` mode and instructs the model to treat Edit/Write as forbidden — and document the trade-off. Option (a) matches the hardened pattern used by `health`.

---

## V8 — Body-Line Budget

**Verdict: PASS**

`wc -l skills/code-doctor/SKILL.md` → 279 total lines. Frontmatter closes at line 15 (second `---` fence). Body = lines 16–279 = **264 lines**. Well within 450-target and 500-hard limit.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

Per unit notes: "N/A unless your own read finds otherwise." `allowed-tools` contains `Agent` but NOT `TeamCreate` or `SendMessage`. The Agent spawn in Phase 2 (LLM judge) is a single sequential Agent() call (SKILL.md lines 156–169), which is the canonical pattern. No TeamCreate/SendMessage drift.

---

## Skill Verdict

**needs-hardening**

The skill is otherwise well-formed (frontmatter passes validator, OUTPUT STYLE matches canonical, all links resolve, body within budget, canonical Agent() spawn pattern), but V7 identifies a real enforcement gap: Write/Edit are available unconditionally despite the skill being documented as read-only-by-default. Prose safety rules ("Never modify files in --scan mode") are not a substitute for platform-level tool restriction.

## Highest-Leverage Fix

Remove `Write` and `Edit` from `allowed-tools` in the default skill, and add `disallowed-tools: [Edit, Write, NotebookEdit]` — then add a separate `code-doctor --fix` invocation path (either a sub-skill or a gated tool-unlock) so fix mode has access. This converts a prose promise into a platform contract, matching the hardened pattern demonstrated by `blitz:health`.
