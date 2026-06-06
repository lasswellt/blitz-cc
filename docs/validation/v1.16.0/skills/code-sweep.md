---
unit: code-sweep
cohort: v1.16.0
validator: cli-sonnet
date: 2026-05-28
verdict: needs-tightening
highest-leverage-fix: "references/main.md §Check Summary Table restates grep patterns for placeholder-throw/placeholder-returns/todo-fixme independently — diverged from O2 (completeness-gate) canonical set; replace with cross-reference + sync marker."
---

# code-sweep Validation Report — v1.16.0

Files validated:
- `skills/code-sweep/SKILL.md` (250 lines total; 240 body lines)
- `skills/code-sweep/references/main.md` (exists)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Run: `hooks/scripts/skill-frontmatter-validate.sh skills/code-sweep/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual field check:
- `name: code-sweep` — present
- `description`: 263 chars (under 1024 cap); third-person ("Iterative code-quality improvement...") — valid
- `model: opus` — present
- `effort: high` — present
- `compatibility: ">=2.1.71"` — present
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent` — present (invokable skill, tools declared)

Evidence: `hooks/scripts/skill-frontmatter-validate.sh skills/code-sweep/SKILL.md` → `OK: 1 SKILL.md files conform`

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->` markers. Byte-exact comparison with `SKILL.md` line 22 confirmed MATCH.

Evidence: `[ "$CANONICAL" = "$SKILL_LINE" ] && echo "MATCH"` → `MATCH` (bash comparison of extracted canonical vs SKILL.md line 22)

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Run: `hooks/scripts/markdown-link-validate.sh skills/code-sweep/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/X` links verified to resolve: `/_shared/session-lifecycle.md`, `/_shared/terse-output.md`, `/_shared/terse-output.md`, `/_shared/quality-engine.md`. Relative link `../completeness-gate/SKILL.md` also resolves.

Evidence: `markdown-link-validate.sh skills/code-sweep/SKILL.md` → `OK (397 link(s) checked)`

---

## V4 — Canonical-Owner Compliance (O2 Consumer)

**Verdict: FAIL**

Unit notes designate code-sweep as "CONSUMER O2 — must cite completeness-gate anti-mock set, not restate."

SKILL.md line 109 correctly cites the owner:
> "The placeholder/anti-mock checks (`placeholder-throw`, `placeholder-returns`, `todo-fixme`) source their patterns from the canonical set owned by [`completeness-gate`](../completeness-gate/SKILL.md) §Checks (O2)."

However, `references/main.md` restates independent diverged patterns:

| Check | code-sweep references/main.md pattern | completeness-gate canonical (O2) |
|-------|---------------------------------------|----------------------------------|
| `todo-fixme` | `(TODO\|FIXME\|HACK\|XXX\|TEMP\|WORKAROUND)(\(.*?\))?:?\s` | `//\s*(TODO\|FIXME\|PLACEHOLDER\|STUB\|HACK\|XXX):?\s` |
| `placeholder-throw` | `throw\s+new\s+Error\s*\(\s*['"](?:not implemented\|TODO\|not yet\|NYI\|FIXME\|PLACEHOLDER)` | identical modulo case sentinel; same |
| `placeholder-returns` | `return\s*\{\s*\}` and `return\s*\[\s*\]` | not independently listed in O2 — O2 owns via §2.1 |

Divergence: code-sweep adds `TEMP` and `WORKAROUND`; excludes `PLACEHOLDER` and `STUB` from the todo pattern. This is not a sync'd copy — it is a forked, independently maintained pattern. SKILL.md's citation in prose is correct, but `references/main.md` restates rather than delegating. The operative grep patterns that agents actually run live in `references/main.md`, not the SKILL.md prose citation. The O2 ownership contract is therefore violated at the execution layer.

Evidence: `grep "todo-fixme" skills/code-sweep/references/main.md` → line 95 shows `WORKAROUND` not in completeness-gate; `grep "todo-fixme-comments" skills/completeness-gate/references/main.md` → line 15 shows `STUB|PLACEHOLDER` absent from code-sweep.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

code-sweep is a standalone continuous loop skill, not part of the sprint pipeline. It appears in `session-lifecycle.md` only as a listed consumer of the story `files` field (`sprint-contracts.md` line 112: `files | string[] | sprint-plan Phase 3.2 | … code-sweep | R`).

The chain traced: sprint-plan Phase 3.2 writes story files with `files: string[]` → code-sweep Phase 0.2 reads scope from `.code-sweep.json` (which can include story-scoped paths). Primary self-chain: code-sweep produces `docs/sweeps/YYYY-MM-DD.json` + `sweep-ledger.jsonl` (Phase 5) → code-sweep Phase 1 (next run) reads them as snapshot + ledger. State-handoff.md does not document code-sweep's own artifacts (correct — standalone skills with self-referential state are excluded from the sprint-pipeline table by design).

No upstream producer emits a mandatory artifact that code-sweep would fail Phase 0 without — Phase 0.3 only requires at least one source directory exists. Composition is sound.

Evidence: `skills/_shared/session-lifecycle.md` has no code-sweep entry (confirmed by `grep -n "code-sweep" session-lifecycle.md` → empty); `skills/_shared/sprint-contracts.md` line 112 lists code-sweep as optional consumer of `files`.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

code-sweep is not `codebase-audit` or `research`. DW dispatch is not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

code-sweep is not read-only by construction. It has `--fix` and `--fix-all` modes that invoke Write/Edit on source files. Declaring `disallowed-tools: [Edit, Write, NotebookEdit]` would be incorrect. The health skill comparison (`allowed-tools: Read, Bash, Glob, Grep` + `disallowed-tools: Edit, Write, NotebookEdit`) applies only to genuinely read-only skills. No gap here.

Evidence: `grep "allowed-tools" skills/code-sweep/SKILL.md` → `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent`; SKILL.md Phase 4 ACT describes Write/Edit fix operations.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body line count (lines between second `---` fence and EOF): **240 lines**.

Hard cap: 500. Target: 450. Both met with margin.

Evidence: `awk '/^---$/{count++; if(count==2){start=1; next}} start{lines++} END{print lines}' skills/code-sweep/SKILL.md` → `240`

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

`allowed-tools` does NOT declare `TeamCreate` or `SendMessage`. The skill uses the canonical `Agent` tool pattern (SKILL.md Phase 2.2, lines 156–168: "call the `Agent` tool with: `subagent_type: general-purpose`, `model: sonnet`…"). agent-orchestration.md §79 confirms: "`TeamCreate`+`SendMessage` does not accept `subagent_type` — the SDK picks by heuristic. Use the `Agent` tool instead (v1.4.0 migrated all spawning skills to this)." No exception needed because the correct idiom is already used.

Evidence: `grep "allowed-tools" skills/code-sweep/SKILL.md` → `Agent` present, no `TeamCreate`/`SendMessage`; SKILL.md line 156 → `Agent tool with: subagent_type: general-purpose, model: sonnet`.

---

## Summary

| Check | Verdict | Short Evidence |
|-------|---------|----------------|
| V1 Frontmatter contract | PASS | `skill-frontmatter-validate.sh` → `OK: 1 SKILL.md files conform` |
| V2 OUTPUT STYLE snippet | PASS | Byte-exact match vs canonical `terse-output.md` |
| V3 Shared-protocol links | PASS | `markdown-link-validate.sh` → `OK (397 link(s) checked)` |
| V4 Canonical-owner compliance | FAIL | `references/main.md` restates diverged patterns for O2-owned checks |
| V5 Pipeline I/O composition | PASS | Standalone skill; self-referential state; optional story `files` consumer per frontmatter.md:112 |
| V6 DW wiring | N/A | Not codebase-audit/research |
| V7 Disallowed-tools gap | N/A | Not read-only by construction; fix modes require Edit/Write |
| V8 Body-line budget | PASS | 240 lines (hard cap 500, target 450) |
| V9 Spawn-idiom consistency | PASS | Uses canonical `Agent` tool; no `TeamCreate`/`SendMessage` |

## Skill Verdict

**needs-tightening**

One check fails (V4). The SKILL.md prose citation of O2 is correct, but `references/main.md` maintains independent grep pattern definitions that have drifted from the completeness-gate canonical set. Agents executing tier scans read `references/main.md` directly, so the operative patterns are the forked ones — the SKILL.md citation is decorative at runtime.

## Highest-Leverage Fix

Replace the standalone pattern table rows for `placeholder-throw`, `placeholder-returns`, and `todo-fixme` in `skills/code-sweep/references/main.md` §Check Summary Table with a cross-reference directive: `<!-- patterns: import from completeness-gate/references/main.md §grep-patterns — do not maintain separately -->` plus a note to sync if completeness-gate patterns change. Add a lint step or comment block that makes the dependency machine-visible so drift is caught by future sweeps.
