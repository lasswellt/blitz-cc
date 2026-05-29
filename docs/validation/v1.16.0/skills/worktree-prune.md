---
unit: worktree-prune
cohort: v1.16.0
validator: claude-sonnet-4-6
date: 2026-05-28
verdict: needs-hardening
highest-leverage-fix: "Add `disallowed-tools: Edit, Write, NotebookEdit` to frontmatter (V7 FAIL) — enforces the read-only-by-construction guarantee that default --dry-run already implies, matching health skill precedent"
---

# worktree-prune — v1.16.0 Cohesion+DW Validation

Files validated:
- `skills/worktree-prune/SKILL.md` (161 lines total, 152 body lines)
- `skills/worktree-prune/references/main.md` — does not exist (no references dir)

---

## V1 — Frontmatter Contract

**PASS**

Command run: `bash hooks/scripts/skill-frontmatter-validate.sh skills/worktree-prune/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirmation:
- `name: worktree-prune` — present
- `description:` — 284 chars (≤1024 ✓), starts "Lists and safely deletes…" (third-person present verb ✓)
- `model: sonnet` — present
- `effort: low` — present
- `compatibility: ">=2.1.71"` — present
- `allowed-tools: Read, Bash, Glob, Grep` — present (skill is invokable)
- `argument-hint:` — present (optional, valid)

Validator exit 0 + manual read both confirm contract satisfied. SKILL.md line 2-8.

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Canonical line extracted from `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` markers.

SKILL.md line 12 (the OUTPUT STYLE line) matches canonical byte-for-byte — shell comparison returned `MATCH`.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

Command run: `bash hooks/scripts/markdown-link-validate.sh skills/worktree-prune/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

Manual spot-check on `/_shared/` citations in SKILL.md:
- `/_shared/worktree-lifecycle.md` → `skills/_shared/worktree-lifecycle.md` — file exists ✓ (line 17, 160)
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` — file exists ✓ (line 36)

Validator OK + both files confirmed present on disk.

---

## V4 — Canonical-Owner Compliance

**PASS**

`/_shared/worktree-lifecycle.md` defines the worktree lifecycle contract (canonical owner). `worktree-prune/SKILL.md` is the **manual prune skill** — a consumer/executor of that contract, not a restater.

Bidirectional check:
- `worktree-lifecycle.md` line 30: cites `../worktree-prune/SKILL.md` with link — ✓
- `worktree-prune/SKILL.md` lines 17 and 160: cites `/_shared/worktree-lifecycle.md` as "Canonical contract" — ✓

SKILL.md does not restate the lifecycle ownership logic; it delegates Phase 2 classification entirely to git commands and references the lifecycle doc for the full contract. No owned-logic restatement detected.

---

## V5 — Pipeline I/O Composition

**N/A**

`worktree-prune` is not in the `bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship` pipeline defined in `/_shared/state-handoff.md`. It is a standalone utility skill:

- Consumes: live git state (`git worktree list`, `git for-each-ref`, `git merge-base`) — no upstream skill artifact
- Produces: terminal output (table + summary) in `--dry-run`; git branch/worktree deletions in `--apply` — no artifact consumed by a downstream skill

`state-handoff.md` grep for "worktree-prune" returns zero hits (confirmed). Sprint-review Invariant 8 (`sprint-review/SKILL.md` line 311) cites `worktree-prune` as a *resolution command*, not a formal pipeline dependency — there is no artifact handoff contract to trace.

Pipeline I/O composition check is not applicable for standalone utility skills.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

`worktree-prune` is not `codebase-audit` or `research`. No `BLITZ_DISPATCH`, `Workflow`, or `dynamic-workflow` references found in SKILL.md (grep returned no output). DW wiring check does not apply.

---

## V7 — Disallowed-Tools Gap

**FAIL**

`worktree-prune` declares `allowed-tools: Read, Bash, Glob, Grep`. It never uses `Edit`, `Write`, or `NotebookEdit` — all mutations are performed exclusively via `Bash` git commands (`git worktree remove`, `git branch -d`, `git branch -D`). The skill's default mode is `--dry-run` (no mutation). Even `--apply` mode never touches the filesystem via the Edit/Write/NotebookEdit tools.

Precedent: `skills/health/SKILL.md` line 6 declares `disallowed-tools: Edit, Write, NotebookEdit` under identical conditions (Read + Bash + Glob + Grep allowed-tools, no file-write mutations via Claude tools).

Prose "Default mode is `--dry-run`" (SKILL.md line 19) is not tool-level enforcement. Missing `disallowed-tools` declaration leaves a gap: a model in a degraded or hijacked session could invoke Edit/Write.

**Fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to frontmatter (after line 5 `allowed-tools:`).

---

## V8 — Body-Line Budget

**PASS**

Body counted from the line after the second `---` fence (line 10) to EOF:
- Body line count: **152 lines** (≤450 target ✓, ≤500 hard limit ✓)

Evidence: `python3` body-counter script output: `Body line count: 152 / Total file lines: 161`.

---

## V9 — Spawn-Idiom Consistency

**N/A**

`allowed-tools` does not include `TeamCreate` or `SendMessage`. SKILL.md grep for both returns no output. `worktree-prune` does not spawn agents — it operates entirely via direct Bash git commands. No spawn-idiom consistency check needed.

---

## Summary

| Check | Verdict | Evidence |
|---|---|---|
| V1 Frontmatter contract | PASS | `skill-frontmatter-validate.sh` exit 0; 284-char third-person description; all 6 required fields present |
| V2 OUTPUT STYLE snippet | PASS | Shell byte-comparison returned MATCH against `terse-output.md` canonical |
| V3 Shared-protocol citations | PASS | `markdown-link-validate.sh` OK (397 links); spot-checked 2 `/_shared/` links — both files on disk |
| V4 Canonical-owner compliance | PASS | Bidirectional citation with `worktree-lifecycle.md` confirmed; no owned-logic restatement |
| V5 Pipeline I/O | N/A | Standalone utility; not in `state-handoff.md` pipeline; no artifact handoff contract |
| V6 Dynamic-Workflows wiring | N/A | Not `codebase-audit` or `research`; no DW references in SKILL.md |
| V7 Disallowed-tools gap | **FAIL** | Missing `disallowed-tools: Edit, Write, NotebookEdit`; health skill has it under same conditions |
| V8 Body-line budget | PASS | 152 body lines (target ≤450, hard ≤500) |
| V9 Spawn-idiom consistency | N/A | No `TeamCreate`/`SendMessage` in `allowed-tools`; does not spawn agents |

**Skill verdict: `needs-hardening`**

**Highest-leverage fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to `skills/worktree-prune/SKILL.md` frontmatter — enforces the read-only-by-construction guarantee that default `--dry-run` already implies in prose, matching the `health` skill precedent. One-line change; zero behavior impact.
