# perf-profile — v1.16.0 Cohesion + DW Validation

**Unit:** `perf-profile`
**Files checked:** `skills/perf-profile/SKILL.md`, `skills/perf-profile/references/main.md`
**Date:** 2026-05-28
**Validator session:** `cli-perfprof-val`

---

## V1 — Frontmatter Contract

**Verdict:** PASS

**Evidence:**
- `hooks/scripts/skill-frontmatter-validate.sh skills/perf-profile/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`
- `name: perf-profile` at line 2
- `description:` 308 chars (≤1024 limit) at line 3 — third-person phrasing: "Profiles bundle size…"
- `model: opus` at line 5
- `effort: medium` at line 6
- `compatibility: ">=2.1.71"` at line 7
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch` at line 4 — skill is invokable, field present

All required fields present and valid. Validator agrees.

---

## V2 — OUTPUT STYLE Snippet (Invariant 5)

**Verdict:** PASS

**Evidence:**
- Canonical line from `skills/_shared/terse-output.md` (between `canonical-output-style-start` and `canonical-output-style-end` markers) matches byte-for-byte with `SKILL.md` line 25.
- Shell comparison: `[ "$canonical" = "$actual" ] && echo "MATCH"` → `MATCH`

No drift. Verbatim one-line directive present in body.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict:** PASS

**Evidence:**
- `hooks/scripts/markdown-link-validate.sh skills/perf-profile/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`
- Internal links verified: `/_shared/session-protocol.md` (line 57), `/_shared/verbose-progress.md` (line 57), `/_shared/terse-output.md` (line 24), `references/main.md` (line 21) — all resolve to real files.

All links pass.

---

## V4 — Canonical-Owner Compliance

**Verdict:** N/A

**Evidence:**
- `grep -n "O[1-5]\|owner\|delegates\|delegation\|spawn-protocol\|TeamCreate\|SendMessage" SKILL.md` → `No delegation/spawn markers found`
- perf-profile does not delegate to an O1-O5 owner; it is a self-contained analytical skill.
- No bidirectional ownership relationship to verify.

---

## V5 — Pipeline I/O Composition

**Verdict:** N/A

**Evidence:**
- `skills/_shared/state-handoff.md` does not list perf-profile in its pipeline table; the skill is standalone (not part of the sprint cycle: bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship).
- No upstream producer artifact required; no downstream consumer of its output declared in any handoff contract.
- Skill produces reports exclusively to `${SESSION_TMP_DIR}` (ephemeral, cleaned on session end). No persistent cross-skill artifact produced.

Pipeline I/O composition check: N/A (standalone skill).

---

## V6 — Dynamic-Workflows Wiring

**Verdict:** N/A

**Evidence:**
- Dynamic-Workflows dispatch (BLITZ_DISPATCH gate, Workflow + Agent() dual paths) applies only to `codebase-audit` and `research` per `/_shared/workflow-dispatch.md` (pilot scope: Phase 1.0/1.1-W).
- perf-profile is not a DW-wired skill. No `BLITZ_DISPATCH` gate, no Workflow block, no dual-path assertion needed.

---

## V7 — Disallowed-Tools Gap

**Verdict:** FAIL (needs-hardening)

**Evidence:**
- Safety Rule 1 at SKILL.md line 39: `This skill is READ-ONLY — never modify source files, test files, or configuration files.`
- `allowed-tools` (line 4) includes `Edit` — zero uses of the Edit tool appear anywhere in the SKILL.md body (confirmed: `grep -n "\bEdit\b" SKILL.md` returns only line 4, the frontmatter declaration).
- `Write` is present in `allowed-tools` and legitimately used (lines 192, 276, 362, 389) to write temp reports to `${SESSION_TMP_DIR}`. Those writes are intentional and safe.
- Comparator: `skills/health/SKILL.md` line 6 declares `disallowed-tools: Edit, Write, NotebookEdit` — a fully read-only skill. perf-profile is not fully read-only (it writes temp reports), but `Edit` is undeclared-needed: it is in `allowed-tools` yet never invoked in the body. `Edit` being available creates an unguarded pathway to accidentally mutate source files, contradicting the prose safety rule.
- Fix: remove `Edit` from `allowed-tools` (no body usage), add `disallowed-tools: Edit, NotebookEdit` to explicitly enforce the source-read-only contract. `Write` remains in `allowed-tools` for the SESSION_TMP_DIR report writes.

---

## V8 — Body-Line Budget

**Verdict:** PASS (over target, under hard limit)

**Evidence:**
- Total file lines: 481 (`wc -l skills/perf-profile/SKILL.md`)
- Frontmatter: lines 1–14 (opening `---` at line 1, closing `---` at line 14) = 14 lines
- Body: 481 − 14 = **467 lines**
- Hard limit: 500 → PASS (467 ≤ 500)
- Target: 450 → OVER (467 > 450 by 17 lines)

Unit notes flagged "body-watch ~468" — actual count 467, consistent. Hard limit passes; target exceeded by 17 lines (no ratchet failure, but worth trimming).

---

## V9 — Spawn-Idiom Consistency

**Verdict:** N/A

**Evidence:**
- `allowed-tools` does not include `TeamCreate` or `SendMessage` (line 4 lists: `Read, Write, Edit, Bash, Glob, Grep, ToolSearch`).
- No team-spawn or send-message pattern found in body.
- No Agent() call or spawn idiom present — skill runs single-threaded.

No spawn-idiom to validate.

---

## Summary Table

| Check | Verdict | Key Evidence |
|-------|---------|--------------|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → OK; all 6 required fields present; desc 308 chars |
| V2 OUTPUT STYLE | PASS | Byte-identical match to canonical terse-output.md snippet; line 25 |
| V3 Link resolve | PASS | `markdown-link-validate.sh` → OK (397 links) |
| V4 Owner compliance | N/A | No delegation or O1-O5 ownership relationship |
| V5 Pipeline I/O | N/A | Standalone skill; not in state-handoff pipeline table |
| V6 DW wiring | N/A | Not a DW-wired skill (only codebase-audit/research in scope) |
| V7 Disallowed-tools | FAIL | `Edit` in `allowed-tools` with zero body uses; no `disallowed-tools` declaration despite source-read-only safety rule |
| V8 Body lines | PASS | 467 lines — under 500 hard limit; over 450 target by 17 |
| V9 Spawn idiom | N/A | No TeamCreate/SendMessage in allowed-tools |

---

## Skill Verdict

**`needs-hardening`**

One gap: V7. The skill correctly enforces source-read-only via prose (Safety Rule 1) but `Edit` in `allowed-tools` provides an unguarded escape path to source mutation. `Write` must stay (temp report writes). `Edit` and `NotebookEdit` should be removed from `allowed-tools` and added to `disallowed-tools`.

---

## Highest-Leverage Fix

**Remove `Edit` from `allowed-tools` and add `disallowed-tools: Edit, NotebookEdit`** in the frontmatter (SKILL.md line 4). The `Edit` tool has zero body invocations; its presence contradicts Safety Rule 1's source-read-only declaration and provides an unguarded pathway to accidental source mutation. This single frontmatter change hardens the enforcement from prose-only to machine-checked.
