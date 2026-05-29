---
unit: skills/implement/SKILL.md
kind: orchestrator-thin-wrapper
verdict: needs-tightening
removable_lines: 12
created: 2026-05-28
---

# Cohesion Audit — `implement`

## A. Identity & Boundaries

**One-sentence purpose**: Thin orchestrator that validates pre-flight conditions then delegates to `sprint-dev` for actual implementation.

**Description vs body match**: Yes — description says "routing to sprint-dev"; body confirms all real work is dispatched. Accurate.

**Overlaps**:

| Skill | Nature |
|-------|--------|
| `sprint-dev` | Direct downstream delegate — legitimate layering; `implement` adds pre-flight and flag-parsing that sprint-dev skips |
| `sprint` | `sprint` calls the same `implement` phase inline; `implement` exists as a standalone entry-point for users who want plan-less invocation — legitimate separation |
| `blitz:next --loop` | `next` can dispatch `implement` as an action; no duplication — different scope levels |

No true duplication found.

---

## B. Cohesion

**_shared protocols cited**:

| Protocol | Cited | Followed or inline restatement |
|----------|-------|-------------------------------|
| `session-protocol.md` | Yes (§Session Registration) | Cited by reference — no inline restatement. OK. |
| `verbose-progress.md` | Yes | Cited by reference. OK. |
| `checkpoint-protocol.md` | Yes (`--resume` flag description) | Cited by reference. `checkpoint-protocol.md` §Orchestrator Support confirms `implement --resume` is the canonical path. OK. |
| `definition-of-done.md` | Yes (one inline sentence cite) | Cited by reference. OK. |
| `state-handoff.md` | **Not cited** | `implement` produces no artifacts itself — it is a pass-through. No produce/consume contract needed beyond what sprint-dev owns. Gap is acceptable but worth noting. |
| `story-frontmatter.md` | **Not cited** | Reads story files indirectly (Pre-Flight #2 verifies existence), but consumes no frontmatter fields itself — sprint-dev owns that. Acceptable. |

**Cross-refs**: All four linked protocols (`session-protocol.md`, `verbose-progress.md`, `checkpoint-protocol.md`, `definition-of-done.md`) exist and paths are valid. No dead links detected.

**Invariant 5 (OUTPUT STYLE snippet)**: Present verbatim at line 13. ✓

**Pipeline trace** (`implement → sprint-dev`):
- `implement` validates sprint exists in `sprint-registry.json`, stories exist in `sprints/sprint-${N}/stories/`, no conflicting sessions, build baseline.
- Dispatches sprint-dev with sprint number or story IDs.
- `sprint-dev` Phase 0.0 hard-fails if manifest or stories missing — redundant with `implement`'s Pre-Flight #1/#2, but defensive redundancy is acceptable (different error surfaces: implement = user-facing halt, sprint-dev = hard-fail).
- Output: sprint-dev produces STATE.md, worktree branches, commit history. `implement` claims a summary in "Progress Reporting" — but this section is vague (lines 57-60) and does not specify what data it reads from sprint-dev to generate the summary.

---

## C. Conciseness

**Line count**: 60 lines vs 500-line cap. Well within limits.

**Prose to cut** (anti-laziness nudges or defensive restatements that 4.8 honesty makes redundant):

```
Line 43: "All code produced must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations, no empty handlers, no stub returns."
```
- "No placeholder implementations, no empty handlers, no stub returns" restates what `definition-of-done.md` already enumerates in detail. The link alone is sufficient under 4.8 — the trailing sentence is a defensive nudge. **Removable** (~1 line of prose).

```
Lines 53-54: "The sprint-dev skill will handle the actual implementation work: reading story definitions, writing code, running tests, and verifying each story."
```
- Narrates what sprint-dev does — already conveyed by the skill's own description. Exists to reassure the model it doesn't need to do those things itself; 4.8 doesn't need this guard. **Removable** (~2 lines).

```
Lines 57-60 (Progress Reporting section): entire section is aspirational — "report which story is being worked on as implementation proceeds" is impossible for the orchestrator since sprint-dev runs in a sub-skill invocation; the orchestrator has no visibility into sprint-dev's per-story loop. Section either belongs in sprint-dev (where it already exists) or should be rewritten as "surface sprint-dev's final summary". As written: misleading and removable. (~4 lines)
```

**Total estimated removable lines**: ~12 (including the above + blank lines freed).

**DRY candidates**: None found that belong in a shared protocol — skill is thin enough.

---

## D. Modernization

**Native primitive overlap** (citing `platform-delta.md`):

1. **Native Workflows** (`platform-delta.md` v2.1.154+): The pre-flight + delegate pattern in `implement` is exactly a lightweight workflow gate. Native workflows support sequential subagent chains. However, `implement` adds cross-session resume detection (checks `.cc-sessions/*.json` for conflicts), sprint-registry validation, and build baseline — none of which are replicable in a pure native workflow without Blitz context. **Keep**: Blitz-specific pre-flight logic justifies the wrapper. Delegating to native would lose sprint-registry validation and session-conflict detection.

2. **`disallowed-tools` frontmatter** (`platform-delta.md` v2.1.152): `implement` only needs Read/Bash during pre-flight; Write/Edit are only used by sprint-dev workers. Could add `disallowed-tools: [Write, Edit, Agent]` and invoke sprint-dev as a skill (not via Agent tool) — but current `allowed-tools` includes Agent for the delegation call. No shortcut-taxonomy blocker applies here. Low-priority modernization.

3. **Model/effort**: `model: opus, effort: low` — correct per MEMORY.md feedback (effort: low + opus = orchestrator pattern). No change needed.

4. **`claude agents` TUI** (`platform-delta.md` v2.1.139): sprint-dev visibility is now partially served by native `claude agents` panel. The "Progress Reporting" section (lines 57-60) is further undermined — the TUI gives per-session status natively. Supports removing that section.

---

## E. Correctness

- `sprint-registry.json` path: not qualified with sprint dir — sprint-dev uses same unqualified reference. Consistent.
- `sprints/sprint-${N}/stories/` path: consistent with sprint-dev Phase 0 discovery.
- `.cc-sessions/*.json` conflict check: valid — matches session-protocol.md session file format.
- `--resume` description says "Equivalent to `--sprint NNN` where NNN is the in-progress sprint, but sprint-dev will skip to Phase 3 using STATE.md data" — accurate per `checkpoint-protocol.md` §How to Resume (sprint-dev Phase 0) step 5.
- No stale version refs, dead env vars, or wrong tool names found.
- `compatibility: ">=2.1.71"` — no newer feature is used that would require a higher floor. Correct.
- **Subagents-cannot-spawn-subagents**: `implement` is slash-invoked so it can spawn via Agent tool. Correct. Dynamic Workflows (`platform-delta.md` v2.1.154+) does not change this — slash skills remain the canonical spawn point.

---

## F. Verdict

**`needs-tightening`**

### Top Edits (highest leverage)

1. **Delete Progress Reporting section** (lines 57-60): section describes per-story visibility the orchestrator cannot have; sprint-dev already owns this; `claude agents` TUI (`platform-delta.md` v2.1.139) closes the gap natively. Replace with one line: "Surface sprint-dev's final phase summary to the user."

2. **Trim line 43 trailing sentence**: Remove "No placeholder implementations, no empty handlers, no stub returns." — redundant with `definition-of-done.md` link; 4.8 does not need the restatement.

3. **Delete lines 53-54** ("The sprint-dev skill will handle the actual implementation work…"): 4.8 honesty makes the anti-laziness narration unnecessary; sprint-dev's own description covers it.
