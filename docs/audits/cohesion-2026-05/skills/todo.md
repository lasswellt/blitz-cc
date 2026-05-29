---
unit: skills/todo/SKILL.md
kind: skill
verdict: needs-tightening
removable_lines: 25
created: 2026-05-28
---

# Audit: `todo` skill

## A. Identity & Boundaries

**One-sentence purpose:** Append/list/check/resolve a project-scoped todo log stored in `.cc-sessions/todos.jsonl`.

Description matches body. No scope creep detected.

**Overlaps:**

| Skill/Agent | Overlap | Classification |
|---|---|---|
| `blitz:next` | surfaces deferred-work items from carry-forward registry | **legitimate layering** — `next` reads `carry-forward.jsonl`; `todo` reads `todos.jsonl`; different stores, different producer/consumer chains |
| `blitz:code-doctor` / `blitz:code-sweep` | both scan for TODO/FIXME in code | **legitimate layering** — those skills act on technical debt in source; `todo` tracks intentional follow-ups and cross-references them |
| `blitz:sprint-plan` | captures deferred epics | **legitimate layering** — roadmap-level deferred work vs. session-level ideas |

No true duplication found.

---

## B. Cohesion

### _shared protocols cited / followed

| Protocol | Cited | Followed / Drifted |
|---|---|---|
| `terse-output.md` | Yes (verbatim OUTPUT STYLE snippet present, lines 12–13) | Followed — Invariant 5 satisfied |
| `verbose-progress.md` | Referenced inline ("Verbose progress exemption") | Explicit opt-out documented; acceptable for lightweight skill |
| `session-protocol.md` | Referenced inline ("No session protocol required") | Opt-out; acceptable given append-only, single-file storage |

No other _shared protocols cited; none are required for this skill's scope.

### Cross-refs

No file-path cross-refs to verify beyond the exemptions above.

### state-handoff.md / story-frontmatter.md compliance

`todo` is **not** a pipeline skill. It neither produces nor consumes pipeline artifacts (manifests, stories, carry-forward). It produces `.cc-sessions/todos.jsonl` which is not consumed by any pipeline skill (verified by reading `state-handoff.md` — no entry for `todos.jsonl`). This is correct; the store is intentionally session-scoped and human-facing only.

### Invariant 5 (OUTPUT STYLE snippet)

**Present verbatim** (lines 12–13). Invariant 5 satisfied.

### Pipeline trace

Not applicable — `todo` is a leaf utility, not a pipeline stage.

---

## C. Conciseness

Body: **129 lines** (well under 500-line cap).

Prose guarding old-model behavior (anti-laziness nudges):

- **Line 107:** `"Would you like me to add these N untracked TODOs to the tracker?"` — interactive offer prompt. With Opus 4.8 honesty gains (platform-delta.md, `claude-opus-4-8 / 2026-05-28`), the model no longer needs a scripted hedging question before acting. Failure mode guarded: model silently ignoring untracked TODOs. Under 4.8, auto-add with one-line confirm is sufficient. **Mark for deletion / replace with deterministic action.**
- **Lines 41–55 (ADD mode):** step 4 "Check for duplicates" prescribes a >60% word-overlap heuristic in prose. This is opinionated logic that will produce inconsistent results across models. Either move to a shared utility or document the known approximation. Not removable but a **drift risk**.
- **Lines 86–88 (CHECK grep):** `--include="*.ts" --include="*.vue" --include="*.js"` — hardcoded extensions exclude `.tsx`, `.jsx`, `.py`, `.go`, etc. Not a defensive nudge, but a latent correctness bug (see §E).

**Estimated removable lines:** ~25 (interactive offer prose in CHECK mode output block, mode-routing table redundancy with argument-hint frontmatter, blank lines).

Content belonging in shared protocol: None. Storage path `.cc-sessions/todos.jsonl` is consistent with `session-protocol.md` `.cc-sessions/` layout — no drift.

---

## D. Modernization

### Native primitive overlap

**`/goal` loop** (platform-delta.md, `v2.1.139 / 2026-05-11`): no overlap — `todo` is synchronous, not a loop driver.

**`disallowed-tools`** (platform-delta.md, `v2.1.152`): `allowed-tools` is already minimal (`Read, Write, Edit, Bash, Glob, Grep`). No prose guard could be replaced declaratively — the skill legitimately needs Bash for grep.

**Workflows** (platform-delta.md, `v2.1.154+`): no subagent spawning; not applicable.

**`/simplify`** (platform-delta.md, `v2.1.154 / 2026-05-28`): not applicable.

**Verdict:** No native primitive reimplemented. **Keep.**

### model/effort frontmatter

`model: sonnet`, `effort: low` — correct for a lightweight CRUD skill. Current model IDs (platform-delta.md, `2026-05-28`): `claude-sonnet-4-6`. Frontmatter uses alias `sonnet`; acceptable if platform resolves alias, but should be verified. No change required unless platform demands explicit version.

---

## E. Correctness

1. **CHECK mode grep (line 87):** `--include="*.ts" --include="*.vue" --include="*.js"` — excludes `.tsx`, `.jsx`, `.py`, `.go`, `.rs`, `.rb`, `.css`, `.html`. Should be `--include="*"` or extended list. **Bug: stale/incomplete.**
2. **Storage format / RESOLVE rewrite (lines 116–117):** "Read all lines, modify the matching line … write back" — no atomicity guard. On concurrent sessions, last-writer-wins silently drops others' resolves. Low severity given single-user CLI context, but worth noting.
3. **`compatibility: ">=2.1.71"`** — no known flag introduced at that version relevant to this skill. Value appears vestigial/placeholder. **Stale.**
4. **No `references/` directory** — verified by `ls`. No dead cross-ref paths.
5. **Subagents-cannot-spawn-subagents:** Not applicable; skill does not spawn agents. Dynamic Workflows (platform-delta.md, `v2.1.154+`) does not change the calculus here.

---

## F. Verdict

**`needs-tightening`**

### Top edits (highest leverage)

1. **Fix CHECK grep extensions** (line 87): replace `--include="*.ts" --include="*.vue" --include="*.js"` with `--include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" --include="*.py" --include="*.go"` or use `-r` without extension filter and rely on `grep -v node_modules`.
2. **Replace interactive offer in CHECK mode** (line 107): remove the hedging question; replace with deterministic behavior: "Adds untracked TODOs automatically; prints `Added: TODO-NNN` per item." (4.8 honesty means the model won't silently skip — scripted offer is vestigial.)
3. **Update `compatibility`** to a meaningful minimum or remove: no capability at `>=2.1.71` is documented as required; set to `">=2.1.152"` (disallowed-tools era) or drop the field.
