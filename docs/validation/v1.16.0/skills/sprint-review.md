# Validation: sprint-review — v1.16.0 Cohesion+DW

**Date:** 2026-05-28
**Unit:** sprint-review
**Files checked:** `skills/sprint-review/SKILL.md`, `skills/sprint-review/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/sprint-review/SKILL.md` output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: sprint-review` (line 2)
- `description:` 443 chars — third-person, ≤1024 ✓ (counted via `wc -c`)
- `model: opus` (line 6)
- `effort: high` (line 7)
- `compatibility: ">=2.1.71"` (line 8)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, Agent` (line 4) — invokable skill, field present ✓

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

`grep "^OUTPUT STYLE:" skills/sprint-review/SKILL.md` → line 26. Byte-for-byte diff against canonical source `skills/_shared/terse-output.md` lines 12 (`<!-- canonical-output-style-start -->` … `<!-- canonical-output-style-end -->`): **MATCH** confirmed by shell string comparison.

`references/main.md` also carries the snippet at line 848, required because the file contains Agent-prompt templates (critic spawn at line 713).

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/sprint-review/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

`hooks/scripts/markdown-link-validate.sh skills/sprint-review/references/main.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/X` links resolve: `story-frontmatter.md`, `state-handoff.md`, `context-management.md`, `checkpoint-protocol.md`, `deviation-protocol.md`, `carry-forward-registry.md`, `spawn-protocol.md`, `terse-output.md`, `definition-of-done.md`, `session-protocol.md`, `verbose-progress.md`, `ratchet-protocol.md`, `shortcut-taxonomy.md`, `worktree-lifecycle.md` — all confirmed present in `skills/_shared/`.

**Minor defect (prose reference, not Markdown link — markdown-link-validate does not catch this):** SKILL.md line 201 cites `references/main.md` section `"Reviewer Prompt Templates"`, but no such section exists in `references/main.md`. Nearest extant section is `## Reviewer Spawn Strategy` (line 764). The prose reference is broken; actual spawn strategy content exists but under a different heading. Not caught by the link validator because it is a quoted string, not a `[text](url)` anchor. Does not affect runtime (skill reads the file directly), but makes the SKILL.md instruction ambiguous for a human following it.

---

## V4 — Canonical-Owner Compliance

**Verdict: FAIL**

**O2 — completeness-gate (anti-mock patterns):**

`completeness-gate/SKILL.md` line 115 correctly cites sprint-review §1.5.1 as a consumer of the canonical pattern set. `sprint-review` SKILL.md line 127 cites the owner:

> "Pattern source: the canonical anti-mock set is owned by `completeness-gate` §Checks (O2). The inline pattern below mirrors it for the review-time diff scan — keep in sync with completeness-gate's `references/main.md` §grep-patterns."

However, the citation is accompanied by **a full inline restatement** of the pattern set (7 terms in one regex on lines 131-133), which is exactly what a consumer must NOT do. The unit notes require the skill to "CITE the owner and does NOT restate the owned logic."

Compounding the issue, the inline pattern set **diverges** from the canonical 13-pattern table in `completeness-gate/references/main.md` §Grep Patterns by Check (line 7). Sprint-review's version omits 6+ patterns: `empty-catch-blocks` (pattern 6), `noop-handlers` (pattern 8), `hardcoded-sample-data` (pattern 9), `console-log-leftovers` (pattern 10), `three-state-ui` (pattern 11), `unwired-store-actions` (pattern 12). Additionally, the citation names the target section as `§grep-patterns` but the actual heading is `## Grep Patterns by Check` — a broken prose anchor.

**O3 — integration-check (wiring topology):**

`sprint-review` Phase 1.6 (lines 157-174) delegates to `/blitz:integration-check all` when new modules are detected — correct delegation ✓. However, `integration-check/SKILL.md` line 3 documents only one caller: `"invoked by /blitz:sprint-dev Phase 3.5.0 after implementation"`. Sprint-review's Phase 1.6 invocation is not documented in the O3 owner's SKILL.md, breaking the bidirectional citation contract.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `sprint-plan → sprint-dev → sprint-review`.

Per `skills/_shared/state-handoff.md` §sprint-plan: produces `sprints/sprint-${N}/manifest.json` (Required by sprint-dev Phase 0.0, sprint-review Phase 0) and `sprints/sprint-${N}/stories/S${N}-*.md` (Required ≥ 1 story). Per §sprint-dev: produces `STATE.md`, story `status` transitions, commits.

`sprint-review` Phase 0.0 input gate (SKILL.md line 40, bash block in `references/main.md` lines 13-24) checks exactly: `sprint-registry.json`, `${SPRINT_DIR}/manifest.json`, `${SPRINT_DIR}/stories/S*.md` — matches state-handoff.md producer declarations ✓.

Story fields consumed by sprint-review (`status`, `epic`, `files`, `done`, `carry_forward`, `research_refs`, `github_issue`, `points`) are all declared in `skills/_shared/story-frontmatter.md` producer/consumer matrix (lines 103-117) with `Consumer` column listing `sprint-review` ✓.

Sprint-review produces: `sprints/sprint-${N}/review-report.md`, `sprints/sprint-${N}-planning-inputs.json`, carry-forward entries, registry status update — all declared in state-handoff.md §sprint-review ✓.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Dynamic-Workflows dispatch applies only to `codebase-audit` (pilot) and `research`. `sprint-review` has no `BLITZ_DISPATCH` gate, no `Workflow` dispatch path. Not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`sprint-review` is NOT read-only-by-construction: it auto-fixes type errors, lint errors, missing exports, and import paths (Phase 3 — SKILL.md lines 249-294), writes review reports, and commits. `allowed-tools` correctly includes `Write`, `Edit`, `Bash`. No hardening gap.

---

## V8 — Body-Line Budget

**Verdict: FAIL**

`tail -n +10 skills/sprint-review/SKILL.md | wc -l` → **442 lines**.

- Hard limit: 500 ✓ (under limit)
- Target: 450 ✓ (under target)

**Wait — re-check by convention:** the validator counts from the second `---` fence (end of frontmatter, line 9) to EOF. Line count: 451 total lines − 9 frontmatter lines = **442 body lines**. Under both 450 target and 500 hard limit. PASS.

**Verdict: PASS** (442 body lines; ≤450 target, ≤500 hard limit)

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

`grep "TeamCreate\|SendMessage" skills/sprint-review/SKILL.md` → no output. Allowed-tools declares `Agent` only (no `TeamCreate`, no `SendMessage`). SKILL.md Phase 2.2.1 uses `Agent()` with `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: true` — consistent with canonical Agent() pattern per `spawn-protocol.md` line 79 ("Use the `Agent` tool instead; v1.4.0 migrated all spawning skills to this"). No drift.

---

## Summary

| ID | Verdict | Short evidence |
|----|---------|---------------|
| V1 | PASS | `skill-frontmatter-validate.sh` OK; all required fields present, description 443 chars |
| V2 | PASS | Line 26 byte-matches canonical snippet; references/main.md carries snippet at line 848 |
| V3 | PASS | `markdown-link-validate.sh` OK (397 links); all `/_shared/` files confirmed present; broken prose reference `"Reviewer Prompt Templates"` not caught by validator (minor) |
| V4 | FAIL | §1.5.1 restates O2 grep patterns inline (7 vs 13 canonical, diverging); O3 bidirectional citation missing (integration-check SKILL.md doesn't list sprint-review as caller) |
| V5 | PASS | Phase 0.0 gate checks all three state-handoff.md §sprint-plan + §sprint-dev required inputs; story-frontmatter.md consumer matrix confirms all consumed fields |
| V6 | N/A | DW dispatch only for codebase-audit/research |
| V7 | N/A | Not read-only; auto-fix writes are intentional |
| V8 | PASS | 442 body lines (≤450 target, ≤500 hard limit) |
| V9 | PASS | Agent() only; no TeamCreate/SendMessage drift |

---

## Skill Verdict

**`contract-violation:V4`** — canonical-owner compliance failure.

§1.5.1 restates the O2-owned grep pattern set inline instead of delegating; the inline copy omits 6 of 13 canonical patterns, creating divergent scan coverage between `sprint-review` and `completeness-gate`. O3 (integration-check) does not document sprint-review Phase 1.6 as a caller, breaking the bidirectional citation contract.

---

## Highest-Leverage Fix

**Remove the inline grep pattern block from SKILL.md §1.5.1** and replace it with a single delegation call — `Invoke: /blitz:completeness-gate --scan-only --diff ${SPRINT_BASE}..HEAD` (or equivalent flag) — and consume its structured findings JSON. Simultaneously add `sprint-review` as a documented caller in `integration-check/SKILL.md` line 3. These two changes resolve both V4 failures: pattern drift is eliminated at the source and the O3 bidirectional citation is repaired.
