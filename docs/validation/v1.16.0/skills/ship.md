---
unit: ship
validator: cli-ship-validate
date: 2026-05-28
verdict: needs-tightening
---

# Validation Report: skills/ship/SKILL.md — v1.16.0

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/ship/SKILL.md` → `OK: 1 SKILL.md files conform`

Fields confirmed by direct read (`skills/ship/SKILL.md` lines 1–10):

| Field | Value |
|---|---|
| `name` | `ship` |
| `description` | 259 chars (≤1024 ✓); third-person imperative ✓ |
| `model` | `opus` |
| `effort` | `low` |
| `compatibility` | `>=2.1.71` |
| `allowed-tools` | `Read, Write, Edit, Bash, Glob, Grep` |

`disable-model-invocation: true` and `argument-hint` are optional extras — not violations.

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Byte-exact match confirmed via shell diff:

```
CANONICAL == SKILL → MATCH
```

`skills/ship/SKILL.md` line 13 is verbatim identical to the `<!-- canonical-output-style-start -->` line in `skills/_shared/terse-output.md` line 12.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/ship/SKILL.md` → `OK (397 link(s) checked)`

Links verified:
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` ✓
- `/_shared/session-lifecycle.md` → `skills/_shared/session-lifecycle.md` ✓
- `/_shared/sprint-contracts.md` → `skills/_shared/sprint-contracts.md` ✓ (file exists)
- `../release/SKILL.md` → `skills/release/SKILL.md` ✓

No broken links.

---

## V4 — Canonical-Owner Compliance

**FAIL**

Ship is a consumer of release (O5), which is the documented canonical owner of changelog logic.

`skills/release/SKILL.md` line 119: "**Canonical changelog owner (O1/O5).** `skills/release` is the SINGLE source of the commit-type → changelog-section map and the Keep a Changelog emit logic. `doc-gen` (`changelog` mode) and `ship` (Phase 2) MUST delegate here — they do not restate this map."

Ship line 159 correctly states: "**Delegate to release (O5).** ... ship does NOT restate the map."

However, `skills/ship/SKILL.md` lines 163–168 (Phase 2.2) immediately contradict this delegation by listing changelog formatting instructions that are owned by release:

```markdown
release `prepare` writes the new version section (Keep a Changelog format) — ship does not hand-edit CHANGELOG.md.
- If `CHANGELOG.md` does not exist, create it with a standard header.
- Strip conventional commit prefixes from descriptions.
- Capitalize the first word of each description.
- Include short commit hash linked to GitHub (if remote is available).
- Remove empty sections.
```

These four bullet points restate formatting rules that live in `skills/release/SKILL.md` §Phase 2 (changelog generation). The opening sentence correctly defers, then the bullets immediately restate owned logic — a self-contradiction within the same section.

Bidirectional citation: `skills/release/SKILL.md` line 3 (description) explicitly says "Composed by /blitz:ship as the final step" — bidirectional reference exists at the description level. Release line 119 also names `ship` as a consumer. The ownership direction is clear; the problem is ship restating what it claims to delegate.

---

## V5 — Pipeline I/O Composition

**PASS**

Chain traced: `sprint-review → ship` (canonical final hop per `skills/_shared/session-lifecycle.md` line 6).

`session-lifecycle.md` §sprint-review producer table (lines 76–83): sprint-review produces `sprints/sprint-${N}/review-report.md` (Required by ship).

`skills/ship/SKILL.md` Phase 0.1 (lines 64–73) consumes exactly this artifact:

```bash
[ -s "${SPRINT_DIR}/review-report.md" ] || {
  echo "BLOCK: ship requires ${SPRINT_DIR}/review-report.md. Run /blitz:sprint-review first."
  exit 1
}
```

`sprint-registry.json` status `done` is also validated (lines 65–67 read `current_sprint` from registry). Both required inputs per the handoff contract are guarded at Phase 0. The ship producer outputs (`CHANGELOG.md`, tag `v<X.Y.Z>`, `.cc-sessions/release-state.json`) are delegated to release sub-invocations — consistent with O5 ownership.

One gap: `session-lifecycle.md` line 89 requires ship to produce `.cc-sessions/release-state.json` for rollback recovery, but `skills/ship/SKILL.md` never references this artifact. Release (`release publish` → Phase 5) may write it, but ship does not verify its production. Not a V5 violation since release is the writer, but worth noting.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

Ship is not `codebase-audit` or `research`. No DW dispatch gate present or required.

---

## V7 — Disallowed-Tools Gap

**N/A**

Ship declares `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — it is explicitly a write-capable skill (it invokes release which creates branches, writes CHANGELOG.md, creates tags). It is not read-only-by-construction, so the `disallowed-tools: [Edit, Write, NotebookEdit]` pattern (as seen in `skills/health/SKILL.md` line 6) does not apply.

---

## V8 — Body-Line Budget

**PASS**

Total lines in file: 276. Frontmatter occupies lines 1–10 (closing `---` fence on line 10). Body = lines 11–276 = **266 lines**.

266 ≤ 450 target ✓, 266 ≤ 500 hard limit ✓.

---

## V9 — Spawn-Idiom Consistency

**PASS**

`allowed-tools` does NOT declare `TeamCreate` or `SendMessage`. Ship uses skill-invocation syntax (`Invoke: /blitz:sprint-review`, `Invoke: /blitz:release prepare`) rather than `TeamCreate`/`Agent()` spawning. This is consistent with `skills/_shared/agent-orchestration.md` line 79: "`TeamCreate`+`SendMessage` does not accept `subagent_type` — … Use the `Agent` tool instead (v1.4.0 migrated all spawning skills to this)."

Ship's invocation model is slash-command chaining (not agent spawning), so no TeamCreate exception is needed and no drift exists.

---

## Summary

| ID | Verdict | Evidence |
|---|---|---|
| V1 | PASS | `skill-frontmatter-validate.sh` → OK; all 6 required fields present+valid |
| V2 | PASS | Byte-exact match against `terse-output.md` canonical snippet |
| V3 | PASS | `markdown-link-validate.sh` → OK (397 links checked) |
| V4 | FAIL | `ship/SKILL.md:163-168` restates changelog formatting rules owned by `release` (O5), contradicting the delegation stated at line 159 |
| V5 | PASS | Phase 0.1 guards `review-report.md`; sprint-registry `current_sprint` read matches session-lifecycle.md §sprint-review producer table |
| V6 | N/A | Not codebase-audit or research |
| V7 | N/A | Ship is write-capable by design; disallowed-tools pattern not applicable |
| V8 | PASS | 266 body lines (≤450 target, ≤500 hard limit) |
| V9 | PASS | No TeamCreate/SendMessage in allowed-tools; slash-command chaining pattern is consistent |

---

## Skill Verdict

**needs-tightening**

---

## Highest-Leverage Fix

Delete `skills/ship/SKILL.md` lines 163–168 (the four bullet points in Phase 2.2 that restate changelog formatting logic). The opening sentence of Phase 2.2 already correctly defers: "release `prepare` writes the new version section (Keep a Changelog format) — ship does not hand-edit CHANGELOG.md." The bullets that follow contradict this statement and duplicate logic canonically owned by `skills/release` §Phase 2 (per `release/SKILL.md:119`). Removing them closes the O5 delegation violation without requiring any other change.
