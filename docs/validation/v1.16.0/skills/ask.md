# Skill Validation: ask — v1.16.0

**Date:** 2026-05-28  
**Validator:** automated rubric (claude-sonnet-4-6)  
**Verdict:** needs-tightening

---

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/ask/SKILL.md` → `OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: ask`
- `description`: 355 chars (≤1024), third-person phrasing "Routes a vague or underspecified request…"
- `model: opus`
- `effort: low`
- `compatibility: ">=2.1.71"`
- `allowed-tools: Read, Bash, Glob, AskUserQuestion`

No disqualifying drift. Script verdict aligns with manual check.

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Byte-identical match confirmed via shell comparison:

```
canonical == actual → MATCH: identical
```

Line at `skills/ask/SKILL.md:12` is verbatim against `skills/_shared/terse-output.md` canonical snippet (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`).

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/ask/SKILL.md` → `OK (397 link(s) checked)`

Links in SKILL.md:
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` — real file
- `../../agents/orchestrator.md` (relative) → `agents/orchestrator.md` — real file

Script verdict: no broken links.

---

## V4 — Canonical-Owner Compliance (O4 Consumer)

**PASS** (with drift note — see Highest-Leverage Fix)

`ask` is an O4 consumer of orchestrator §2. SKILL.md line 25 states:

> "Canonical routing table: `agents/orchestrator.md` §2 (O4). The table below MIRRORS the orchestrator's intent→skill map for standalone `ask` invocations. To add/change a route, edit orchestrator.md §2 first, then sync this mirror — do not maintain divergent mappings."

Owner-first note is present and correct. The skill does NOT restate logic as owned — it explicitly defers. Bidirectional link: `orchestrator.md` line 117 cites `/blitz:ask` as the routing skill for ambiguous intent.

However, the mirror is **materially stale**. The following skills appear as primary routes in orchestrator §2 but are absent from ask's routing table:

| Missing primary route | Orchestrator §2 entry |
|---|---|
| `code-doctor` | "check API misuse, framework anti-patterns" |
| `code-sweep` | "sweep code quality, cleanup, improve code" |
| `ui-audit` | "audit UI consistency, cross-page data drift" |
| `compress` | "shrink this doc, compress" |
| `conform` | "is the project drifted from blitz spec" |
| `worktree-prune` | "clean up worktrees, delete stale branches, prune worktrees" |
| `design-extract` | "extract design system, make DESIGN.md" |
| `implement` | "implement these stories (no sprint)" |

These divergences are non-blocking (owner-first note is present; the sync obligation is on the editor, not a hard fail), so V4 passes — but V4 contains a latent contract-violation risk every time orchestrator §2 is extended without syncing.

---

## V5 — Pipeline I/O Composition

**N/A**

`ask` is not a pipeline consumer or producer in the sprint artifact chain (`state-handoff.md` has no entry for ask). It is a meta-skill (classifier/router) with no artifact I/O contracts. No upstream producer, no downstream consumer per `skills/_shared/state-handoff.md`.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

`ask` is not `codebase-audit` or `research`. DW check does not apply.

---

## V7 — Disallowed-Tools Gap

**PASS**

`ask` is NOT read-only-by-construction: it writes to `.cc-sessions/activity-feed.jsonl` via Bash (per lines 19-21 — verbose progress logging is mandatory) and dispatches skills via the Skill tool. These are legitimate side-effects, not read-only behavior. The `disallowed-tools` declaration would be incorrect here.

`allowed-tools: Read, Bash, Glob, AskUserQuestion` matches the actual operations. No hardening needed — disallowed-tools would break the skill's mandatory activity-feed write obligation.

---

## V8 — Body-Line Budget

**PASS**

Body line count (between second `---` fence and EOF):

```
awk result: 113 body lines
```

113 ≤ 450 (target) ≤ 500 (hard cap). Well within budget.

---

## V9 — Spawn-Idiom Consistency

**N/A / PASS**

`allowed-tools` does not declare `TeamCreate` or `SendMessage`. No spawn-idiom drift. `ask` dispatches to skills via the Skill tool (a meta invocation, not a subagent spawn), which is the correct pattern. `spawn-protocol.md` line 79 confirms `TeamCreate`+`SendMessage` was deprecated (v1.4.0 migrated to `Agent` tool); `ask` correctly avoids both.

---

## Summary Table

| ID | Verdict | Evidence |
|---|---|---|
| V1 | PASS | `skill-frontmatter-validate.sh` → `OK: 1 SKILL.md files conform` |
| V2 | PASS | Shell byte-compare → `MATCH: identical` against canonical in terse-output.md |
| V3 | PASS | `markdown-link-validate.sh` → `OK (397 link(s) checked)` |
| V4 | PASS | Owner-first note present at SKILL.md:25; mirror is stale (8 missing routes) but obligation is on editor |
| V5 | N/A | ask has no pipeline artifact I/O; not in state-handoff.md |
| V6 | N/A | Not codebase-audit or research |
| V7 | PASS | Not read-only-by-construction (activity-feed writes via Bash required); disallowed-tools would be wrong |
| V8 | PASS | 113 body lines (limit: 500) |
| V9 | PASS | No TeamCreate/SendMessage in allowed-tools |

---

## Skill Verdict

**needs-tightening**

The skill is structurally sound, passes all hard checks, and correctly implements the owner-first delegation pattern. The tightening needed: the routing mirror (Phase 1 table) is 8 entries stale relative to orchestrator §2. Every orchestrator §2 addition since the last sync (code-doctor, code-sweep, ui-audit, compress, conform, worktree-prune, design-extract, implement) is missing. This will cause `ask` to respond "does not match any row → ask to clarify" for requests it should be routing.

---

## Highest-Leverage Fix

Sync the Phase 1 routing table (SKILL.md lines 29–57) against orchestrator §2 by adding the 8 missing primary routes: `code-doctor`, `code-sweep`, `ui-audit`, `compress`, `conform`, `worktree-prune`, `design-extract`, `implement`. Do NOT edit the orchestrator — the owner-first note at SKILL.md:25 is correct; only the mirror copy lags. A one-time diff of orchestrator §2 rows vs ask rows, then appending the deltas, is the complete fix. Add a CI check (grep count comparison) to detect future drift automatically.
