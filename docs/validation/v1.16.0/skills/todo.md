# Skill Validation: todo — v1.16.0

**Date:** 2026-05-28
**Validator:** cli-todo-v1160
**Files examined:** `skills/todo/SKILL.md` (no `references/main.md` exists)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/todo/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Independent read confirms all required fields present:
- `name: todo` — present
- `description:` — 386 chars (≤1024), third-person ("Tracks…"), invocation triggers listed — PASS
- `model: sonnet` — valid
- `effort: low` — valid
- `compatibility: ">=2.1.71"` — present
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — present (skill is invokable, field required and present)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Byte-identical comparison: `grep "^OUTPUT STYLE:" skills/todo/SKILL.md` vs canonical in `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` markers → `MATCH`.

Snippet at `skills/todo/SKILL.md:12` (immediately after the opening `---` fence, before first heading). No drift.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/todo/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

The skill body cites `/_shared/terse-output.md` (line 12 via the OUTPUT STYLE line) and resolves correctly. No broken relative links.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Per unit notes: `todo` has no owner/consumer role in the O1–O5 hierarchy. Not a pipeline owner skill; does not delegate to one. `skills/ask/SKILL.md:54` routes "todo/note/remember" triggers to this skill (inbound routing reference only — not an ownership claim). No bidirectional check required.

---

## V5 — Pipeline I/O Composition

**Verdict: N/A**

`todo` is a standalone utility skill; it is not in the sprint pipeline defined by `skills/_shared/state-handoff.md`. It produces/consumes only `.cc-sessions/todos.jsonl` (not a pipeline artifact). The state-handoff table has no entry for `todo`. No upstream producer → this skill → downstream consumer chain exists to trace.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Per rubric: DW check applies only to `codebase-audit` and `research`. `todo` is neither.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`todo` is NOT read-only-by-construction. `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` intentionally includes `Write` and `Edit` — the skill must rewrite `.cc-sessions/todos.jsonl` on `resolve`. No `disallowed-tools` hardening needed or expected.

---

## V8 — Body-Line Budget

**Verdict: PASS**

`awk '/^---$/{count++; if(count==2){found=1; next}} found{lines++} END{print "Body lines:", lines}' skills/todo/SKILL.md` → `Body lines: 120`

Total file lines: 129. Body at 120 lines is well within the 500-line hard cap and 450-line target.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` contains no `TeamCreate` or `SendMessage`. Skill does not spawn agents. No drift from canonical `Agent()` pattern; nothing to check.

---

## Skill Verdict

**cohesive**

All applicable checks pass. Frontmatter validated by script and independent read. OUTPUT STYLE snippet byte-identical to canonical. Links resolve cleanly. Body at 120 lines (24% of hard cap). No spawn tools, no pipeline entanglement, no DW concern.

## Highest-Leverage Fix

None required. If hardening is desired, consider adding `output_intensity: lite` to frontmatter (the skill omits this optional field; default `lite` applies but is implicit rather than declared).
