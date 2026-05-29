# Skill Validation: quick — v1.16.0

**Date:** 2026-05-28  
**Validator:** cli-quick-v1  
**Unit file:** `skills/quick/SKILL.md` (76 lines; no `references/main.md`)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/quick/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present:

| Field | Value | Valid |
|---|---|---|
| name | quick | yes |
| description | 370 chars, third-person ("Makes a small…") | yes (≤1024) |
| model | sonnet | yes |
| effort | low | yes |
| compatibility | ">=2.1.71" | yes |
| allowed-tools | Read, Write, Edit, Bash, Glob, Grep | yes (invokable, field present) |

No disallowed or missing required fields detected.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Byte-identical match confirmed via shell comparison:

```
canonical=$(sed -n '/canonical-output-style-start/,/canonical-output-style-end/p' skills/_shared/terse-output.md | grep "^OUTPUT STYLE:")
skill=$(grep "^OUTPUT STYLE:" skills/quick/SKILL.md)
[ "$canonical" = "$skill" ] && echo MATCH
```

Result: `MATCH` — `skills/quick/SKILL.md:21` carries the verbatim canonical line from `skills/_shared/terse-output.md` lines 12–13.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/quick/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links verified to exist on disk:

- `/_shared/package-install-policy.md` → `skills/_shared/package-install-policy.md` — EXISTS
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — EXISTS
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` — EXISTS

No dead links.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Per unit notes: quick has no O1–O5 owner role and does not delegate to an owner. Single `<!-- import: -->` comment at line 11 is a project-context import marker, not an owner delegation. No owner/delegation references in body.

---

## V5 — Pipeline I/O Composition

**Verdict: N/A**

`quick` is a standalone ad-hoc skill. It is not listed in `skills/_shared/state-handoff.md` as either a producer or consumer in any sprint pipeline chain. No upstream producer or downstream consumer to trace. The skill explicitly states "No session protocol. No activity feed logging. No agents." — it operates outside the sprint pipeline I/O graph.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

DW wiring check applies only to `codebase-audit` and `research`. `quick` is neither.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`quick` is NOT read-only-by-construction. `allowed-tools` explicitly includes `Edit`, `Write`, and `Bash` — it is a write-capable skill by design (its purpose is making small targeted changes). The disallowed-tools hardening check only applies to skills that are "read-only-by-construction" (e.g., `health`). No gap here.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body lines (after second `---` frontmatter delimiter, to EOF): **67 lines**

- Hard limit: 500 — PASS (67 << 500)
- Target: 450 — PASS

Counted via: `awk` counting lines after the second `---` fence in `skills/quick/SKILL.md` (total file is 76 lines; frontmatter is 9 lines).

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not include `TeamCreate` or `SendMessage`. No agent spawn idioms present. Confirmed: `grep "TeamCreate\|SendMessage" skills/quick/SKILL.md` → not found.

---

## Skill Verdict

**cohesive**

All applicable checks pass. The skill is lean (67 body lines), correctly wired (canonical OUTPUT STYLE, valid frontmatter, all links resolve), appropriately scoped (no spawn, no pipeline role), and has no disallowed-tools obligation since it is write-capable by design.

---

## Highest-Leverage Fix

None required — skill is cohesive. If any improvement is warranted: the `<!-- import: from _shared/project-context.md §Canonical block -->` marker at line 11 references a template import that is not enforced at runtime (the `!`-prefixed shell expansion on line 13 handles actual injection); the comment is informational but could be removed to avoid implying a build-time import mechanism that doesn't exist. Low priority.
