---
unit: skills/compress
kind: skill
verdict: needs-tightening
removable_lines: 28
created: 2026-05-28
---

# Compress Skill — Cohesion + Modernization Audit

## A. Identity & Boundaries

**Purpose:** Author-time markdown/text file rewriter that applies the Terse Output Protocol, writes a `.original` backup, and runs structural validation via `reference-compression-validate.sh`.

**Description ↔ body match:** VERIFIED. Frontmatter description ("Rewrites a markdown or plain-text file into terse form…") matches the four-phase body (validate → backup → compress → validate).

**Overlaps:**

| Skill/Agent | Nature | Duplication? |
|---|---|---|
| `_shared/terse-output.md` | Spec this skill implements; references it correctly | Legitimate layering — SKILL.md cites without restating rules (mostly) |
| `/simplify` (platform v2.1.154, platform-delta.md row 34) | Platform native: cleanup-only review with auto-apply on *code*; no file backup, no `.original` convention | Partial overlap on "reduce verbosity" intent but domain is code cleanup not markdown files; **not true duplication** |

No retire/delegate case for native `/simplify`: that skill targets code quality; `/blitz:compress` targets markdown prose token reduction + backup+validate pipeline. Domains diverge; contract (`.original`, validator hook) is blitz-specific.

## B. Cohesion

**_shared protocols cited:**
- `session-protocol.md` — cited Phase 0.1, correct usage (register, log `skill_start`/`skill_complete`)
- `verbose-progress.md` — cited Phase 0.1, correct
- `spawn-protocol.md §2 Output Size` — cited Phase 0.2 for single-Write vs sectioned-Edit routing; cross-ref is live and load-bearing
- `terse-output.md` — cited as spec; SKILL.md delegates compression rules to it rather than restating (good)

**Protocols NOT cited but relevant:**
- `story-frontmatter.md`, `state-handoff.md` — compress is a utility skill, not in the sprint pipeline. No produce/consume contract expected. VERIFIED correct omission.
- `knowledge-protocol.md` — not cited; compress has no cross-session learnings to persist. Acceptable omission.

**OUTPUT STYLE snippet — Invariant 5:** PRESENT at line 15, verbatim match confirmed against `terse-output.md` canonical snippet. ✓

**Inline restatement of `terse-output.md` rules (drift risk):** Phase 2.1–2.2 re-enumerates preservation rules already authoritative in `_shared/terse-output.md`. Specifically:
- Lines 52–62: "Drop articles, fillers… Preserve… Every line starting with ` ``` `… Every `http(s)://`… Every heading line…" — this is a mechanical restatement of `terse-output.md §Preservation boundary`. Creates drift risk if canonical spec changes.

**Pipeline chain:** compress is an author-time utility; its output (compressed `.md` + `.original` backup) feeds no downstream skill mechanically. The validator (`reference-compression-validate.sh`) is the exit gate. Chain verified: validator reads `<file>.original` + `<file>`, checks 4 structural invariants, exits 1 on drift. SKILL.md Phase 3.2 handles restoration correctly.

**Cross-refs live:**
- `/_shared/session-protocol.md` — live ✓
- `/_shared/verbose-progress.md` — live ✓
- `/_shared/terse-output.md` — live ✓
- `/_shared/spawn-protocol.md#output-size-and-single-write-budget` — INFERRED live (anchor format matches other spawn-protocol cross-refs in the codebase; not verified by reading spawn-protocol.md)
- `hooks/scripts/reference-compression-validate.sh` — live, read directly ✓

## C. Conciseness

**Body line count:** 149 lines. Well under 500-line cap. ✓

**Defensive/anti-laziness prose (mark for deletion):**

1. Lines 52–62 (Phase 2.1–2.2): Full restatement of `terse-output.md` preservation rules. The canonical spec is already cited at line 11. Guard rationale: fear model would skip the linked file. With 4.8 honesty, model reads cited specs. **~10 lines removable** — replace with: `Apply preservation rules per /_shared/terse-output.md §Preservation boundary.`

2. Lines 75: Inline anchor `"a single-Write compress on skills/ui-audit/references/main.md (70 KB) ran 7m36s with zero output before timing out. The successful skills/sprint-review/references/main.md pass (35 KB) used 20 Edits across 14 sections."` — historical operational note explaining *why* the routing rule exists. Useful for auditors; borderline dead weight for runtime execution. Keep as a comment or collapse to one line. **~1 line removable** if trimmed.

3. Lines 118–123 (Error recovery): Large block restates rules already in Phase 0–3. Specifically:
   - `"Target is a code or config file: reject with extension-based error. Do not attempt."` — already Phase 0.2
   - `"File exceeds 500KB: reject."` — already Phase 0.2
   - `"File 40-500KB: auto-route to sectioned-Edit mode (Phase 2.5). Do not attempt single-Write — it will time out with zero output."` — already Phase 0.2 + 2.5
   - `"Target already has .original sibling: skip with notice."` — already Phase 0.2
   Guard rationale: redundant restatement to prevent model from ignoring earlier phases. 4.8 honesty reduces need. **~12 lines removable.**

4. Lines 127–145 (Testing section): smoke-test shell block. Useful during development; not useful at runtime. **~18 lines removable** if moved to a dev-notes doc, but this is borderline — a one-shot smoke-test embedded in SKILL.md isn't harmful and provides documentation value. Mark as LOW priority.

**Estimated removable lines:** 28 (conservative: items 1+3 only; excludes testing section).

**Content belonging in shared protocol:** Phase 2.1–2.2 preservation rules belong exclusively in `_shared/terse-output.md` (already there). SKILL.md should cite, not restate.

## D. Modernization

**Native primitive overlap:**

- `/simplify` (platform-delta.md v2.1.154, 2026-05-28): handles code simplification with auto-apply. **Does NOT overlap** compress's domain (markdown prose + backup + validator). Keep compress as-is. Tradeoff: delegating to `/simplify` would lose the `.original` backup convention, the UNSAFE-marker classification, and validator integration — all blitz-specific contracts.

- `disallowed-tools` frontmatter (platform-delta.md v2.1.152): compress's UNSAFE classification in Phase 2.3 is a prose guard. Could reinforce with `disallowed-tools` but compress doesn't invoke dangerous tools anyway; no benefit. No change warranted.

**`output_intensity` frontmatter:** SKILL.md does not declare `output_intensity`. Default is `lite`. Compress produces terse summaries; `full` would be more appropriate. Minor gap — add `output_intensity: full` to frontmatter.

**Model/effort:** `model: sonnet`, `effort: low`. Correct under 4.8 + cheaper fast mode — single-file rewrite, no reasoning-heavy task. No change warranted. Verified: model ID not hardcoded in body; frontmatter uses alias `sonnet` (maps to `claude-sonnet-4-6` per platform-delta.md row for current model IDs — acceptable).

## E. Correctness

**Stale refs / dead flags:** None found. `compatibility: ">=2.1.71"` — conservative lower bound, no conflict with current features.

**Phase 0.2 size classifier anchor:** References `spawn-protocol.md §2 Output Size` and `spawn-protocol.md#output-size-and-single-write-budget`. These are the same section under different anchor syntax. Potential inconsistency — inline text says "§2" but the href uses a slug anchor. INFERRED issue (did not read spawn-protocol.md); flag for verification.

**UNSAFE marker list (Phase 2.3):** Three markers: `agent prompt template`, `Grep Patterns by Check`, `output_style: exact`. These appear hardcoded. If `terse-output.md` ever adds a fourth opt-out signal, compress won't catch it. Low risk today; acceptable.

**subagents-cannot-spawn-subagents:** Compress spawns no subagents. Not applicable.

**Dynamic Workflows (platform-delta.md v2.1.154+):** compress is a single-agent skill. No routing change needed.

## F. Verdict

**`needs-tightening`**

**Top edits (highest leverage):**

1. **Delete Phase 2.1–2.2 prose restatement** (~10 lines). Replace with: `Apply Terse Output Protocol at full intensity per /_shared/terse-output.md §Preservation boundary.` Eliminates drift risk with canonical spec.

2. **Delete Error recovery section lines 118–123** (~12 lines). Each bullet restates a Phase 0–3 rule. Compress to: `Error handling: see Phase 0–3 guards above. No additional recovery logic.`

3. **Add `output_intensity: full`** to frontmatter. Compress produces fragment-heavy summaries; `full` matches actual behavior and respects terse-output.md §Intensity levels.
