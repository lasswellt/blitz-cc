---
unit: skills/review
kind: thin-wrapper
verdict: needs-tightening
removable_lines: 18
created: 2026-05-28
---

# Audit: skills/review

## A. Identity & Boundaries

**Purpose (one sentence):** Thin entry-point wrapper that parses `--sprint`/`--auto-fix` flags, validates sprint state exists, then delegates entirely to `/blitz:sprint-review`.

**Description vs body match:** Accurate. Description says "routing to sprint-review"; body does exactly that with pre-flight guard + delegation.

**Overlaps:**

| Skill/Agent | Relationship | Type |
|---|---|---|
| `sprint-review` | Wraps directly — 100% of substantive review work delegated | Legitimate layering (alias + flag-parser entry point; `quality-matrix.md` line 27 confirms) |
| `agents/reviewer.md` | Ad-hoc one-off code review outside sprint; distinct scope | No duplication |
| `/code-review` (native) | Native PR diff review; different target (diff vs sprint artifact set) | No duplication |

No true duplication found.

## B. Cohesion

**_shared protocols cited:**

| Protocol | Cited | Followed inline or delegated |
|---|---|---|
| `session-protocol.md` | Yes (line 19) | Cited correctly; no inline restatement |
| `verbose-progress.md` | Yes (line 21) | Cited correctly |
| `terse-output.md` | Yes (line 13) | OUTPUT STYLE snippet present verbatim — Invariant 5 satisfied |
| `state-handoff.md` | Not cited | Pre-flight checks (lines 38-42) duplicate artifact-existence logic that `state-handoff.md` already owns; drift risk |
| `story-frontmatter.md` | Not cited | No story shape produced/consumed directly — acceptable for a wrapper |
| `carry-forward-registry.md` | Not cited | Acceptable; delegated to sprint-review |

**Cross-refs:**
- `/_shared/session-protocol.md` — valid path
- `/_shared/verbose-progress.md` — valid path
- `/_shared/terse-output.md` — valid path
- `skills/sprint-review/SKILL.md` — referenced implicitly via "invoke the sprint-review skill"; no direct path link — minor (functional, not broken)

**State-handoff produce/consume:** Wrapper produces nothing directly; consumes `sprint-registry.json` only in pre-flight. All artifact production delegated to sprint-review. Consistent with `state-handoff.md` (verified from sprint-review SKILL.md §Phase 0.0).

**OUTPUT STYLE snippet:** Present verbatim on lines 13-13 (multiline). Invariant 5: PASS.

**Pipeline chain trace:**
```
/blitz:review --sprint 14 --auto-fix
  → pre-flight: reads sprint-registry.json, checks stories/ dir, checks .cc-sessions/*.json
  → delegates to sprint-review (Phases 0.0 through 4)
  → sprint-review emits: .cc-sessions/sprints/<N>/review.md, updates sprint-registry.json status
  → /blitz:ship consumes sprint-registry.json status=passed
```
Chain is coherent. review wrapper does not produce intermediate artifacts that could misshape sprint-review's input.

## C. Conciseness

Body: 60 lines. Well under 500-line cap.

**Prose for deletion — anti-laziness / defensive restatements:**

Lines 45-60 ("Execution" + "Output" sections):
```
The sprint-review skill will handle the actual review work: running quality
gates, checking for pattern violations, and producing a review report.
```
This restates what sprint-review's own SKILL.md describes. A model reading sprint-review directly does not need this. Failure mode guarded: pre-4.8 models that needed explicit reassurance they could stop after delegation. Removable under 4.8 honesty.

Lines 55-60 ("Output" section): Describes output format (severity buckets, auto-fix summary, pass/fail gate summary) but the authoritative format lives in `skills/sprint-review/references/main.md` and `skills/review/references/main.md` (caveman-review shape). This is a loose paraphrase — not the canonical contract. Drift risk if sprint-review output shape changes. Removable; replace with a single pointer to `references/main.md`.

**Estimated removable lines:** ~18 (lines 44-60, replaced by one pointer sentence).

**Content belonging in shared protocol:** Pre-flight logic (lines 37-42) partially duplicates session-conflict detection already in `session-protocol.md` §Session Registration. Consider a `state-handoff.md` entry for wrapper pre-flight pattern.

## D. Modernization

**Native primitives:**

| Claim | platform-delta.md version | Keep/Delegate/Retire | Tradeoff |
|---|---|---|---|
| Flag-parsing wrapper pattern | N/A — no native equivalent | Keep | Native skills have no conditional dispatch to another skill with pre-flight guard |
| Pre-flight session-conflict check | v2.1.152 `settings.autoMode.hard_deny` (platform-delta.md row 11) | Keep with note | `hard_deny` blocks at auto-mode level, not same-sprint session-conflict level — different granularity |
| `--auto-fix` passthrough | N/A | Keep | Pure delegation; no reimplementation |

No `disallowed-tools` candidates identified (wrapper has no tool-use risk pattern to lock down).

**Model/effort:** `model: opus, effort: low` — sane per MEMORY.md feedback ("orchestrator pairs opus with effort: low"). Wrapper itself does near-zero reasoning; opus is overkill for pre-flight + delegation but matches the convention and is consistent with spawn-protocol subagent routing.

**`disallowed-tools` opportunity:** Wrapper never uses `WebSearch`, `Agent`, `Write`, or `Edit` directly. Adding `disallowed-tools: [WebSearch, Agent, Write, Edit]` would prevent accidental heavy tool use. Low priority — skill is short and scope is clear.

## E. Correctness

- `compatibility: ">=2.1.71"` — no newer platform features used; no staleness issue
- No version refs to obsolete models in body
- `allowed-tools` includes `Agent` — wrapper does not spawn agents itself (sprint-review does). Including `Agent` enables the delegation call. Correct but slightly over-permissive; see disallowed-tools note above.
- Pre-flight checks `sprint-registry.json` for `status: review` or `status: in-progress` (line 38). sprint-review Phase 0 performs the same check (sprint-review SKILL.md lines 45-46). Mild duplication — consistent, not broken.
- "subagents-cannot-spawn-subagents" constraint: wrapper stays slash-only; sprint-review is also slash-only. Dynamic Workflows (platform-delta.md v2.1.154+) does not change this — sprint-review's complexity warrants explicit slash invocation, not workflow auto-dispatch. Constraint still valid.

## F. Verdict

`needs-tightening`

### Top 3 highest-leverage edits

1. **Delete lines 44-60** (Execution description + Output section) and replace with:
   ```
   Invoke `/blitz:sprint-review` with parsed flags. For output format, see [references/main.md](references/main.md) and `skills/sprint-review/references/main.md`.
   ```
   Saves ~18 lines; eliminates drift risk from paraphrased output contract.

2. **Add `disallowed-tools: [WebSearch, Agent, Write, Edit]`** to frontmatter. Declaratively enforces wrapper-only scope without prose guards.

3. **Add `state-handoff.md` pointer** in pre-flight section:
   ```
   Pre-flight artifact list per [state-handoff.md](/_shared/state-handoff.md) §Wrapper Pre-Flight.
   ```
   Anchors validation logic to the canonical contract instead of restating it inline.
