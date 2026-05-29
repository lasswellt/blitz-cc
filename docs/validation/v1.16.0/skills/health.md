# Skill Validation — health — v1.16.0

**Date:** 2026-05-28  
**Validator session:** cli-health-v1  
**Files inspected:** `skills/health/SKILL.md` (186 lines), no `references/main.md` exists.  
**Skill verdict:** cohesive

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/health/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual cross-check:
- `name: health` — present
- `description:` — 309 chars (≤1024 limit), third-person voice confirmed ("Validates plugin structural integrity…")
- `model: sonnet` — present
- `effort: low` — present
- `compatibility: ">=2.1.152"` — present
- `allowed-tools: Read, Bash, Glob, Grep` — present (invokable skill)
- `disallowed-tools: Edit, Write, NotebookEdit` — present (bonus hardening)

All six required fields present and valid; validator confirms.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` lines 12–13 (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`). Shell diff of canonical vs. actual line 20:

```
MATCH: OUTPUT STYLE snippet is verbatim
```

No drift. Exact byte-identical match confirmed.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/health/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

The `/_shared/terse-output.md` reference appears at line 20 (inside the OUTPUT STYLE directive) and line 185 (inside a code-fence example string — not a hyperlink, no resolution required). The `ls skills/_shared/*.md` reference at line 140 is a bash glob, not a markdown link. All real links pass.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

`health` is not an O1-O5 owner and does not delegate to one. `agent-routing.md` line 26 classifies it as a "single-spawn orchestrator" / standalone diagnostic. No O# ownership chain exists for this skill. Bidirectional check not applicable.

---

## V5 — Pipeline I/O Composition

**Verdict: N/A**

`state-handoff.md` contains zero occurrences of "health" — the skill is not in any producer/consumer chain. `scheduling.md` line 37 confirms: `health | Daily | default | Plugin integrity check` (standalone). The skill reads live filesystem state (hooks.json, .cc-sessions, skills/*/SKILL.md) and emits a terminal report; it produces no artifacts consumed downstream. No pipeline I/O contract to verify.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

`health` is not `codebase-audit` or `research`. DW dispatch gate check not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: PASS**

`disallowed-tools: Edit, Write, NotebookEdit` declared at SKILL.md line 6. This matches the reference implementation expectation stated in the unit notes. Read-only enforcement is structural (not just prose). `NotebookEdit` is also covered. No gap.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Total file lines: 186. Frontmatter ends at line 10 (second `---` fence). Body = lines 11–186 = **176 lines**. Well within both the 450-line target and 500-line hard cap.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools: Read, Bash, Glob, Grep` — neither `TeamCreate` nor `SendMessage` is declared. The skill does not spawn agents. No idiom drift possible. `agent-routing.md` classifies `health` as a "single-spawn orchestrator" candidate for future promotion, but current implementation is a pure slash-invoked skill with no spawning.

---

## Summary Table

| Check | Verdict | Evidence |
|---|---|---|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → `OK: 1 SKILL.md files conform`; 309-char third-person description |
| V2 OUTPUT STYLE | PASS | Shell diff → `MATCH: OUTPUT STYLE snippet is verbatim` |
| V3 Link resolution | PASS | `markdown-link-validate.sh` → `OK (397 link(s) checked)` |
| V4 Canonical-owner | N/A | Standalone diagnostic; no O# chain |
| V5 Pipeline I/O | N/A | `state-handoff.md` has 0 "health" occurrences; skill produces no pipeline artifacts |
| V6 DW wiring | N/A | Not `codebase-audit` or `research` |
| V7 Disallowed-tools | PASS | `disallowed-tools: Edit, Write, NotebookEdit` at line 6 — structural enforcement confirmed |
| V8 Body-line budget | PASS | 176 body lines (≤450 target, ≤500 hard cap) |
| V9 Spawn-idiom | N/A | No `TeamCreate`/`SendMessage` in `allowed-tools` |

---

## Skill Verdict

**cohesive**

All applicable checks pass. The skill is a clean, self-contained read-only diagnostic with proper frontmatter, verbatim OUTPUT STYLE, structural write-protection via `disallowed-tools`, and no pipeline entanglements.

## Highest-Leverage Fix

None required. The skill is fully compliant. If a future improvement were warranted, adding `health` to `session-protocol.md`'s skill-matrix table (currently only `dep-health` appears there) would complete the cross-reference picture, but this is documentation polish, not a contract violation.
