---
unit: skills/fix-issue
kind: skill
verdict: needs-tightening
removable_lines: 38
created: 2026-05-28
---

# Audit — `fix-issue`

## A. Identity & Boundaries

**One-sentence purpose**: Resolves a single GitHub issue end-to-end — fetch, investigate, fix, verify, commit, and update the issue — outside the sprint pipeline.

Description matches body. No mismatch.

**Overlaps:**

| Skill/Agent | Overlap area | Classification |
|---|---|---|
| `quick` | Single-file targeted fixes | Legitimate layering — `quick` is for user-initiated ad-hoc changes; `fix-issue` adds GitHub integration, RCA structure, branch workflow |
| `refactor` | Follow-up suggestion at Phase 4.4 | Legitimate handoff, not duplication |
| `test-gen` | Follow-up suggestion at Phase 4.4 | Legitimate handoff |
| `completeness-gate` | Phase 3.3.5 calls `/blitz:completeness-gate` inline | True dependency — not duplication; but inline `/blitz:` invocation inside a skill body is unusual (skill-within-skill) |
| `orchestrator.md` | Routes `fix issue #N` → this skill | Legitimate — orchestrator is dispatcher |

No true duplication found.

---

## B. Cohesion

**Shared protocols cited:**

| Protocol | Cited? | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0) | Delegates via cross-ref |
| `verbose-progress.md` | Yes (Phase 0.0) | Delegates |
| `terse-output.md` | Yes (cross-ref block + verbatim OUTPUT STYLE snippet) | Verbatim snippet present — **Invariant 5 satisfied** |
| `spawn-protocol.md` | Yes (cross-ref block; Phase 1.4 weight class) | Phase 1.4 gives inline LIMITS block that partially restates spawn-protocol Light class; drift risk |
| `definition-of-done.md` | Yes (post-frontmatter line) | Cross-ref only |
| `state-handoff.md` | Not cited | `fix-issue` is not in the main pipeline table; only appears as an ad-hoc consumer in the migrate row — consistent with its "independent of sprint-dev" boundary |
| `story-frontmatter.md` | Not cited | Correct — not a sprint skill |
| `carry-forward-registry.md` | Not cited | Correct — one-off skill |

**Cross-refs:**
- `/_shared/definition-of-done.md` — live path, verified pattern across skills.
- `/_shared/spawn-protocol.md` — live.
- `/_shared/terse-output.md` — live.
- `/_shared/session-protocol.md` — live.
- `/blitz:completeness-gate` in Phase 3.3.5 — functional but unusual; slash-invocation inside skill body has no formal contract. No Phase 0 validation gate checks completeness-gate availability. Minor correctness risk if completeness-gate is unavailable.

**Produces/consumes per state-handoff.md:**
`fix-issue` is correctly outside the bootstrap→ship pipeline. It produces a git branch + commit + GitHub issue comment. Not tracked in state-handoff.md (consistent with its ad-hoc nature). No violation.

**OUTPUT STYLE snippet**: Present verbatim at line 21. Invariant 5 ✓.

**Pipeline trace (Phase 4 → `review`):**
`fix-issue` emits a branch `fix/<N>-<slug>`. The `review` skill reads a PR diff. Gap: `fix-issue` never creates a PR — it only commits and comments. The `review` skill therefore cannot be chained immediately without a manual `gh pr create` step. Phase 4.4 follow-up table omits `review` as a suggestion; this is a usability gap (not a correctness bug).

---

## C. Conciseness

Body: **382 lines** — within the 500-line cap.

**Prose compensating for old-model laziness (mark for deletion under 4.8 honesty):**

1. Line 27: `"Execute every phase in order. Do NOT skip phases."` — anti-laziness nudge. With Opus 4.8 honesty gains (platform-delta.md: `claude-opus-4-8 / 2026-05-28`), this is unnecessary scaffolding. **~1 line removable.**

2. Lines 173–187: The inline bash snippet + paragraph checking whether research output exists, ending "Do NOT proceed to Phase 2 implementation based on missing/empty research output" — defensive guard against a model that would silently continue on missing evidence. 4.8 will surface empty output without the guard. The bash block may still be useful as an explicit check; the trailing prose paragraph ("Either retry with narrower scope…") is the anti-laziness portion. **~6 lines removable.**

3. Lines 229–231: "Smallest possible change. If a one-line fix works, do not restructure the function." / "Do not add unrelated improvements. Even if you notice other issues, they are separate tasks." — restatements of SAFETY RULE 1 (line 35). **~3 lines removable.**

4. Lines 376–382 (Error Recovery): `"Do NOT guess and apply a speculative fix."` + `"Report findings so far and ask the user"` — 4.8 abstains-when-uncertain natively. **~2 lines removable.**

5. Phase 1.4 LIMITS block (lines 161–170): full restatement of spawn-protocol Light class weight. Should be replaced with `Weight class: Light — per spawn-protocol.md §Weight Classes.` **~8 lines removable.**

6. Phase 4.2 output-style preamble block (lines 318–319): inline output-style prescription restated locally, diverges from canonical pattern of a single cross-ref. **~2 lines removable.**

7. Phase 3.3.5 (lines 276–282): invokes `/blitz:completeness-gate` inline. This is the only place in any skill that slash-invokes another skill from within the body. It has no corresponding contract in state-handoff.md. Consider converting to a Bash call to the completeness-gate script directly, or documenting the dependency. Not a removal candidate — a refactor candidate.

**Content that belongs in a shared protocol (DRY):**
- Root cause analysis template in `references/main.md` (bug-pattern tables, regression test template) — this is reference material, not protocol. It is not shared across skills and is correctly scoped.
- The inline subagent prompt at Phase 1.4 — the boilerplate sections (BUDGET, WRITE-AS-YOU-GO) are covered by `agent-prompt-boilerplate.md`; however the skill uses a minimal inline prompt. Low drift risk given Light class.

**Estimated removable lines: 38** (anti-laziness prose + LIMITS restatement + local output-style override).

---

## D. Modernization

**Native primitive overlap (platform-delta.md citations):**

1. **`disallowed-tools` frontmatter** (platform-delta.md v2.1.152): SAFETY RULE 1 (no unrelated changes), RULE 2 (no test modification) are enforced in prose. These could be partially reinforced by adding `disallowed-tools: []` constraints, though the safety rules are behavioral, not tool-based — no direct mapping. **Verdict: keep prose; `disallowed-tools` not applicable here.**

2. **`/goal` completion-condition loop** (platform-delta.md v2.1.139): fix-issue is a one-shot skill, not a loop. Not applicable.

3. **`/code-review --fix`** (platform-delta.md v2.1.152): Phase 3 verify steps (type-check, tests, build) are correctly separate from code review. The skill does not perform a code review pass on its own fix — adding `code-review --fix` as an optional Phase 3.5 would catch self-introduced issues. **Verdict: opportunity, not blocking.**

4. **Opus 4.8 honesty gains** (platform-delta.md `claude-opus-4-8 / 2026-05-28`): several anti-laziness guardrails in phases 1–2 (identified above in §C) can be removed. Model `opus` frontmatter is already correct for this skill. `effort: medium` is sane.

5. **Model ID currency**: `model: opus` — not a pinned version ID. Platform-delta.md specifies `claude-opus-4-8` as current. The alias `opus` will resolve to current Opus, so this is not broken, but an explicit ID would be more predictable during model transitions. **Low priority.**

6. **Native Workflows** (platform-delta.md v2.1.154+): fix-issue spawns at most one Light subagent. No multi-agent fan-out. Native workflows not applicable; spawn-protocol overhead is minimal for this skill.

---

## E. Correctness

- `compatibility: ">=2.1.71"` — does not gate on `disallowed-tools` (v2.1.152) or native workflows (v2.1.154). Acceptable since neither is used.
- `$SESSION_TMP_DIR` referenced in Phase 1.4 subagent prompt and Phase 1.4 validation bash block — not defined anywhere in the skill. No setup step establishes this variable. **Bug**: the validation block will silently evaluate `RESEARCH_FILE="/issue-research.md"` if `SESSION_TMP_DIR` is unset.
- Phase 3.3.5: `git diff --name-only HEAD~1` — assumes exactly one prior commit; on first commit of the branch, `HEAD~1` may not exist. Safer: `git diff --name-only $(git merge-base HEAD main) HEAD`.
- Phase 4.3 output summary block references `<commit hash>` — the skill never captures the commit hash into a variable. Minor: the operator can run `git log -1 --format=%h`, but it should be explicit.
- No stale flags or dead env vars beyond `SESSION_TMP_DIR` above.
- `subagents-cannot-spawn-subagents` constraint: still applies. fix-issue spawns one Light subagent but is itself slash-invoked (not spawned by another subagent in the normal path). No calculus change from Dynamic Workflows — slash-only is correct.

---

## F. Verdict

**`needs-tightening`**

**Top 3 highest-leverage edits:**

1. **Fix `SESSION_TMP_DIR` undefined bug** (Phase 1.4 + validation block): add a Phase 0 setup step that sets `SESSION_TMP_DIR=$(mktemp -d)` or references the session-protocol definition. Currently the research output file path silently collapses to a root path.

2. **Delete anti-laziness prose** (~38 lines): lines 27, 173–187 paragraph tail, 229–231 redundant rules, 376–382 speculative-fix prohibition, Phase 1.4 LIMITS restatement — all compensate for pre-4.8 model laziness; safe to remove under Opus 4.8 honesty gains (platform-delta.md `claude-opus-4-8 / 2026-05-28`).

3. **Add `review` to Phase 4.4 follow-up table** + note that `gh pr create` is a prerequisite: the pipeline gap (fix-issue never opens a PR) leaves `review` unreachable from the suggested follow-ups.
