# Validation Report — skills/browse — v1.16.0

**Date:** 2026-05-28
**Validator:** cohesion+DW suite
**File:** skills/browse/SKILL.md
**Reference:** skills/browse/references/main.md (exists)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/browse/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: browse` — present (line 2)
- `description:` — 347 chars (≤1024), third-person, invocation triggers listed (line 3)
- `model: opus` (line 5)
- `effort: high` (line 6)
- `compatibility: ">=2.1.71"` (line 7)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch` (line 4, skill is invokable so required)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Exact byte-for-byte match confirmed via shell diff against canonical in `skills/_shared/terse-output.md §canonical-output-style-start`:

```
MATCH (diff returned empty)
```

Snippet at SKILL.md line 26.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/browse/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All five links extracted from SKILL.md verified to exist on disk:
- `skills/browse/references/main.md` — OK
- `skills/_shared/terse-output.md` — OK
- `skills/_shared/session-protocol.md` — OK
- `skills/_shared/verbose-progress.md` — OK
- `skills/_shared/definition-of-done.md` — OK

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Per unit notes: no O1–O5 ownership role. Browse is a standalone utility skill with no pipeline delegation chain. No owner citation required; no consumer back-references expected.

---

## V5 — Pipeline I/O Composition

**Verdict: N/A**

`grep -n "browse" skills/_shared/state-handoff.md` returned no results. Browse is not listed in the `state-handoff.md` pipeline (bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship). It is an ad-hoc utility skill invoked directly, not as a pipeline stage. No upstream producer / downstream consumer chain to verify.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Per unit notes: DW wiring check applies only to `codebase-audit` and `research`. Browse is neither.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

Browse is NOT read-only-by-construction. `allowed-tools` declares `Write` and `Edit` (used for auto-fix mode in Phase 5 and report writing in Phase 6). Hardening check does not apply.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Total file: 387 lines. Frontmatter occupies lines 1–9 (9 lines). Body = 387 − 9 = **378 lines**.

Hard limit: 500. Target: ≤450. 378 is within target.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`grep "TeamCreate\|SendMessage" skills/browse/SKILL.md` returned nothing. Browse does not declare TeamCreate or SendMessage in allowed-tools; it is not a spawn-dispatching skill.

---

## Skill Verdict

**cohesive**

All applicable checks pass. Frontmatter is valid, OUTPUT STYLE snippet is verbatim-canonical, all links resolve, body is within budget (378/500), no spawn drift, and the skill correctly scopes allowed-tools to match its write-capable (fix-mode) nature.

---

## Highest-Leverage Fix

None required. If a hardening opportunity is desired: the body is at 378/500 lines (76% of hard cap) — the loop-mode procedure delegated to `references/main.md` effectively keeps this below the ceiling. No action needed.
