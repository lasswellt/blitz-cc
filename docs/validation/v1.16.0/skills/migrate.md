---
unit: migrate
validator: cli-valid-mg01
date: 2026-05-28
verdict: needs-tightening
highest_leverage_fix: "Align SKILL.md body to write docs/migrations/<from>-<to>/{plan.md,STATE.md,report.md} and implement the --resume / BLOCK protocol declared in state-handoff.md §migrate; currently the body only writes to ${SESSION_TMP_DIR} and uses a different resume mechanism (migrate-progress.json), making the canonical pipeline I/O contract unimplemented."
---

# migrate — v1.16.0 Cohesion+DW Validation

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/migrate/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: migrate` ✓
- `description`: 371 chars (≤1024, third-person, begins "Handles…") ✓
- `model: opus` ✓
- `effort: high` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent` ✓
- `disable-model-invocation: true` ✓ (bonus field, not required)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

SKILL.md line 22 contains the canonical snippet. Shell comparison:
```
canonical == skill_line → MATCH
```
`terse-output.md` canonical-output-style-start block matches byte-for-byte. The trailing exemption at line 26 (`**Terse exemptions (LITE intensity):**`) is a permitted addendum per terse-output.md §"Agents may extend".

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/migrate/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Spot-checked cited shared files exist on disk:
- `skills/_shared/session-protocol.md` ✓
- `skills/_shared/verbose-progress.md` ✓
- `skills/_shared/package-install-policy.md` ✓
- `skills/_shared/definition-of-done.md` ✓
- `skills/migrate/references/main.md` ✓

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

migrate is not an O1–O5 canonical owner (not sprint-dev, sprint-plan, sprint-review, codebase-audit, or research). It is a standalone execution skill. No bidirectional owner check required.

---

## V5 — Pipeline I/O Composition

**Verdict: FAIL**

`skills/_shared/state-handoff.md` §migrate (lines 150–163) declares three canonical output artifacts and a strict resume contract:

**Declared outputs (state-handoff.md):**
- `docs/migrations/<from>-<to>/plan.md`
- `docs/migrations/<from>-<to>/STATE.md`
- `docs/migrations/<from>-<to>/report.md`

**Resume contract (state-handoff.md):** if STATE.md exists and `--resume` not passed → `BLOCK: migration STATE.md exists; pass --resume to continue, or move STATE.md aside to restart.` and exit 1.

**What SKILL.md body actually instructs:**
- Phase 1.1 writes `${SESSION_TMP_DIR}/migration-research.md` (line 125)
- Phase 4.2.1 writes `${SESSION_TMP_DIR}/migrate-progress.json` (line 334)
- Phase 4.2.2 reads `${SESSION_TMP_DIR}/migrate-progress.json` for resume (line 358)

The SKILL.md body contains zero references to `docs/migrations/`, `plan.md`, `STATE.md`, `report.md`, or `--resume`. The canonical pipeline I/O contract is declared in state-handoff.md but not implemented in the skill instructions. Consumer skills (fix-issue, sprint-plan) and operators expecting `docs/migrations/<from>-<to>/report.md` will find nothing.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

migrate is not `codebase-audit` or `research`. DW wiring check does not apply.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

migrate is a mutating execution skill (Write, Edit, Bash in allowed-tools by design). It is not read-only-by-construction. No disallowed-tools declaration is required.

---

## V8 — Body-Line Budget

**Verdict: FAIL (over target, within hard cap)**

Body line count: **461** (target ≤450, hard cap ≤500).

The body starts at line 11 (after the second `---` fence) and runs to line 470 EOF → 461 lines. Exceeds the 450-line target by 11 lines; within the 500 hard cap. Flagged as over-target.

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

`allowed-tools` does not include `TeamCreate` or `SendMessage`. No TeamCreate/SendMessage references found anywhere in the SKILL.md body (`grep TeamCreate|SendMessage` → no output). The v1.15.0 Agent() migration is complete; no residue detected. The single Agent reference at line 109 ("Spawn Research Agent") uses the correct pattern.

---

## Summary

| Check | Verdict | Evidence |
|-------|---------|----------|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → OK; all fields verified |
| V2 OUTPUT STYLE | PASS | Byte-identical match vs canonical; addendum permitted |
| V3 Link resolution | PASS | `markdown-link-validate.sh` → OK (397 links checked) |
| V4 Owner compliance | N/A | migrate is not an O1–O5 owner |
| V5 Pipeline I/O | FAIL | state-handoff.md declares docs/migrations/ outputs + --resume contract; SKILL.md body only writes ${SESSION_TMP_DIR}/* — contract unimplemented |
| V6 DW wiring | N/A | Not codebase-audit or research |
| V7 Disallowed-tools | N/A | Mutating skill; disallowed-tools not required |
| V8 Body-line budget | FAIL | 461 lines — 11 over 450-line target (under 500 hard cap) |
| V9 Spawn idiom | PASS | No TeamCreate/SendMessage; Agent() pattern clean |

**Skill verdict: needs-tightening**

**Highest-leverage fix:** Align SKILL.md body to write `docs/migrations/<from>-<to>/{plan.md,STATE.md,report.md}` and implement the `--resume` / BLOCK protocol declared in `state-handoff.md §migrate`. Currently the body only writes to `${SESSION_TMP_DIR}` (migration-research.md, migrate-progress.json) and handles resume via a different mechanism, making the canonical pipeline I/O contract a dead letter. Fixing this also shrinks body bloat: migrate-progress.json can collapse into STATE.md (one file instead of two), which may recover the 11 lines over target.
