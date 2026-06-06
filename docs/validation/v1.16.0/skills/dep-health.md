---
unit: dep-health
validator: cli-a1b2c3d4
date: 2026-05-28
cohort: v1.16.0
verdict: cohesive
---

# dep-health — v1.16.0 Cohesion Validation

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/dep-health/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual verification of each required field:
- `name: dep-health` — present (line 2)
- `description:` — present (line 3); 362 chars (well under 1024-char cap); third-person ("Audits npm dependencies…")
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch` — present (line 4)
- `model: sonnet` — present (line 5)
- `effort: medium` — present (line 6)
- `compatibility: ">=2.1.71"` — present (line 7)
- `argument-hint:` — present (line 8; optional but populated)

All required fields valid. Script verdict and manual read agree.

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Byte-comparison of the OUTPUT STYLE line at SKILL.md:22 against the canonical from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` markers):

```
MATCH: YES
```

The line is verbatim-identical, not a near-copy.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/dep-health/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/` links verified to exist on disk:
- `skills/_shared/sprint-contracts.md` — OK
- `skills/_shared/session-lifecycle.md` — OK
- `skills/_shared/terse-output.md` — OK
- `skills/_shared/terse-output.md` — OK
- `skills/_shared/security.md` — OK

`references/main.md` also exists (308 lines, confirmed at `skills/dep-health/references/main.md`).

---

## V4 — Canonical-Owner Compliance

**PASS**

dep-health is classified as a **pure worker** (no spawning, no chaining) per `skills/_shared/agent-orchestration.md:28`. It is not an O1–O5 owner skill.

The skill cites `/_shared/security.md` as the canonical rule owner for upgrade-mode resolution (SKILL.md:18: "canonical rule for `upgrade` mode resolution"). `security.md:82` back-references dep-health as "periodic enforcer." Bidirectional citation confirmed. The skill does not restate the owned logic — it delegates to the reference file.

---

## V5 — Pipeline I/O Composition

**PASS**

dep-health is a standalone invocation skill, not part of the sprint pipeline. It has no upstream producer and no required story-frontmatter inputs. Its I/O contract is defined in `skills/_shared/session-lifecycle.md:146`:

```
| dep-health | — | ${SESSION_TMP_DIR}/dep-health-report.md |
```

Consumer side: no other skill declares dep-health's report as a required input in session-lifecycle.md — the report is a user-facing artifact. The SKILL.md body correctly produces this artifact at Phase 5.2. No pipeline mismatch.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

dep-health is not `codebase-audit` or `research`. The DW dispatch gate applies only to those two pilot skills per `skills/_shared/agent-orchestration.md`.

---

## V7 — Disallowed-Tools Gap

**PASS (documented exception)**

dep-health does **not** declare `disallowed-tools:` in its frontmatter. The omission is intentional and documented at SKILL.md:11:

```
<!-- no-disallowed-tools: not read-only — `upgrade` mode Edits package.json, `report` mode Writes CSV/JSON. disallowed-tools:[Edit,Write] would break those modes (S14-009 / audit §2 correction; only `health` qualified). -->
```

V7 asks: "if read-only-by-construction, does it declare disallowed-tools?" dep-health is **not** read-only-by-construction — `upgrade` mode modifies `package.json` and lock files, `report` mode writes CSV/JSON. The prose enforcement is:
- The write modes are explicitly named in frontmatter `allowed-tools`
- The `audit` mode read-only constraint is enforced procedurally (SKILL.md:41: "In `audit` mode, this skill is READ-ONLY")
- The comment cites the audit decision reference (S14-009) so the rationale is traceable

Unit notes say "PASS expected" — confirmed.

---

## V8 — Body-Line Budget

**PASS**

Body lines (line 10 through EOF = total 391 lines − 9 frontmatter lines): **382 lines**

- Hard cap: 500 — PASS (382 < 500)
- Target: 450 — PASS (382 < 450)

---

## V9 — Spawn-Idiom Consistency

**N/A**

`allowed-tools` does not include `TeamCreate` or `SendMessage`. dep-health is a pure worker slash-invoked skill per `agent-orchestration.md` — it does not spawn subagents. No drift from canonical Agent() pattern.

---

## Skill Verdict

**cohesive**

All applicable checks pass. The skill is well-structured: frontmatter valid, OUTPUT STYLE verbatim-matched, all shared-protocol links resolve, canonical-owner citations are bidirectional, pipeline I/O contract matches session-lifecycle.md, disallowed-tools omission is intentionally documented with a traceable audit reference, body at 382 lines is within budget, and no spawn-idiom drift.

## Highest-Leverage Fix

None required. The skill is cohesive. The one minor hygiene item worth noting: `audit` mode's read-only enforcement is procedural (prose rule, SKILL.md:41) rather than declarative (`disallowed-tools`). This is architecturally sound given the multi-mode design, but if a future refactor splits `audit` into its own skill, it should add `disallowed-tools: Edit, Write, NotebookEdit` at that point.
