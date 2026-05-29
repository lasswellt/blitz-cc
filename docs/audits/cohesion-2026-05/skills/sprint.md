---
unit: skills/sprint
kind: orchestrator-alias
verdict: needs-tightening
removable_lines: 22
created: 2026-05-28
---

# Audit: skills/sprint/SKILL.md

## A. Identity & Boundaries

**Purpose:** Thin orchestrator that sequences `sprint-plan → sprint-dev → sprint-review` and aliases `--loop` to `/blitz:next --loop`.

**Description vs body match:** Description accurate. Frontmatter says "backwards-compat alias" for `--loop`; body devotes 18 lines (38–55) to explaining the alias — disproportionate to the behavior (one `Skill()` call).

**Overlaps:**

| Skill/Agent | Nature |
|---|---|
| `skills/next` | `--loop` flag is a full alias-dispatch to `next`. True duplication if the alias section is counted as logic. Legitimate layering otherwise — `sprint` is the user-facing entry point, `next` owns the loop engine. |
| `skills/sprint-plan` | Phase 1 is a direct invocation stub; no duplication of planning logic. Legitimate layering. |
| `skills/sprint-dev` | Phase 2 is a direct invocation stub. Legitimate layering. |
| `skills/sprint-review` | Phase 3 is a direct invocation stub. Legitimate layering. |

No true duplication found — all apparent overlaps are thin delegation. The alias section for `--loop` is the closest thing to duplication; it does not replicate logic but it does over-explain the handoff.

---

## B. Cohesion

**Cited _shared protocols:**

| Protocol | Cited? | Followed or restated inline? |
|---|---|---|
| `verbose-progress.md` | Yes (line 18) | Cited; adds inline instruction to print `[sprint]` prefixes. Minor restatement — not drift-level. |
| `carry-forward-registry.md` | Yes (line 20) | Cited; defers to `next`. Correct. |
| `checkpoint-protocol.md` | Yes (line 29) | Cited via `--resume` flag description. Correct. |
| `definition-of-done.md` | Yes (line 77) | Cited correctly. |
| `session-protocol.md` | Not cited | Pre-Flight step 3 checks `.cc-sessions/*.json` for conflicts — inline restatement of session-protocol behavior without citation. **Drift risk.** |
| `state-handoff.md` | Not cited | Not cited anywhere. Skill produces/consumes no artifacts of its own (delegates entirely), so absence is acceptable but a note would help readers. |
| `story-frontmatter.md` | Not cited | Same rationale — delegation means no direct artifact production. Acceptable. |

**OUTPUT STYLE snippet (Invariant 5):** Present verbatim at lines 12–12. **Pass.**

**Cross-ref liveness:**
- `/_shared/checkpoint-protocol.md` — file exists at `skills/_shared/checkpoint-protocol.md`. **Live.**
- `/_shared/carry-forward-registry.md` — exists. **Live.**
- `/_shared/verbose-progress.md` — exists. **Live.**
- `/_shared/definition-of-done.md` — exists. **Live.**
- `skills/next/SKILL.md §Loop Mode` — file exists; §Loop Mode section existence not verified (next skill not read). **Inferred live** — high confidence given recent sprint-13 commit history.

**Pipeline chain (end-to-end trace):**

`/blitz:sprint` (no flags) →
1. Pre-Flight: reads `roadmap-registry.json` (state-handoff.md: produced by `roadmap`) ✓
2. Phase 1: invokes `sprint-plan` → produces `sprints/sprint-${N}/manifest.json` + stories
3. Phase 2: invokes `sprint-dev` → consumes manifest (Phase 0.0 hard-fail if absent per state-handoff.md) ✓
4. Phase 3: invokes `sprint-review` → consumes review-report, closes stories ✓

Chain is internally consistent with state-handoff.md. No invented artifact shapes.

---

## C. Conciseness

**Body line count:** 119 lines (including frontmatter). Under 500-line cap. **Pass.**

**Prose to delete — anti-laziness / defensive restatements:**

Lines 38–55 (18 lines): "Loop Mode (--loop) — Alias for /blitz:next --loop since v1.13.0" section.
```
## Loop Mode (--loop) — Alias for /blitz:next --loop since v1.13.0

When `--loop` is specified, this skill immediately dispatches `/blitz:next --loop` and exits. ...
**Why the move:** the reconciliation loop is a project-lifecycle engine, not a sprint-cycle engine. ...
**Backwards compatibility:** ...
**Reference**: full reconciliation spec in `skills/next/SKILL.md` §Loop Mode (Phases 3 + 4).
```
Failure mode guarded: early adopters invoking `--loop` on `sprint` after v1.13.0 migration; concerned those callers would be confused by the routing change.  
With 4.8 honesty: the alias pseudo-code in Flag Parsing (lines 42–47) already makes behavior clear. The full section repeats it at 3x length. **Mark for deletion: lines 38–55 (~18 lines).**

Lines 20 (partial) — "Carry-forward awareness is mandatory in `--loop` mode." paragraph: now dead prose because `--loop` immediately exits to `next`. **Mark for deletion: 1 line net.**

**Content belonging in shared protocol:** Pre-Flight step 1b (uningested research detection, lines 64–72) is 9 lines of inline logic. The same detection logic appears in `next`'s loop (confirmed by description "Loop Step 1"). This is a **DRY violation** — belongs in `_shared/workflow-dispatch.md` or a new `_shared/preflight-checks.md`. Not counted in `removable_lines` (it would move, not delete), but flagged for extraction.

**Estimated removable lines:** 22 (18 alias section + ~4 now-dead carry-forward prose in loop context).

---

## D. Modernization

**Native primitives (per platform-delta.md):**

| Claim | platform-delta.md version | Keep/Delegate/Retire | Tradeoff |
|---|---|---|---|
| Multi-phase sequencing (plan→dev→review) via `Skill()` calls | v2.1.154+ / 2026-05-28 — native orchestration workflows fan across parallel subagents | **Keep** | Native workflows are parallel-fanout; sprint phases are strictly sequential with confirmation gates. Delegating to native loses the user-confirmation pause after Phase 1 and the conditional `--plan-only` / `--skip-review` / `--gaps` branching. Opinionated sequential control flow is the skill's value-add. |
| `--loop` alias dispatch | `/goal` loop (v2.1.139) + native workflows | **Keep alias, surface `/goal` as alternative in docs** | `/goal` checks a single completion condition; blitz loop is a multi-phase reconciliation engine. Not equivalent. Alias to `next --loop` remains correct. |

**`disallowed-tools` opportunity (platform-delta.md v2.1.152):** Skill orchestrates only via `Skill()` and reads state — could add `disallowed-tools: [mcp__*]` to prevent accidental MCP calls during coordination. Low priority but trivially safe.

**Model/effort sanity:** `model: opus`, `effort: low`. Correct per MEMORY.md guidance: orchestrator uses opus at `effort: low`; heavy work pushed to sonnet workers. **Pass.**

**Model ID currency:** frontmatter says `model: opus` (alias). platform-delta.md (2026-05-28) lists current ID as `claude-opus-4-8`. Alias resolution is platform-handled; no change required but `token-budget.md` routing matrix should map alias. **Low-severity.**

---

## E. Correctness

**Stale refs / broken paths:**
- `/_shared/checkpoint-protocol.md` referenced at line 29 — file exists. **OK.**
- `--resume` flag: claims "sprint-dev will detect STATE.md" — consistent with state-handoff.md contract. **OK.**
- `compatibility: ">=2.1.71"` — platform-delta.md minimum relevant version is v2.1.128 (zip) / v2.1.152 (disallowed-tools) / v2.1.154 (workflows). Skill itself uses no features newer than basic `Skill()` dispatch. Compatibility bound technically correct but very conservative — not a bug.

**Subagents-cannot-spawn-subagents:** Skill is slash-invoked; it spawns `sprint-plan`, `sprint-dev`, `sprint-review` as sub-skills. platform-delta.md v2.1.154+ native workflows change the calculus: parallel fan-out is now native, but this skill's chain is sequential+branching, not parallel. **Constraint still valid; slash-only correct.**

**Dead flag:** `--loop` section (lines 38–55) documents behavior that is trivially one call. The explanatory prose is not wrong but is defensive over-documentation for a migration that is now ~2 sprints old (v1.13.0). Effectively dead weight.

**Pre-Flight step 1b inline logic:** references "Loop Step 1" from `next` skill — couples `sprint` preflight to `next`'s internal step numbering. If `next` renumbers, this reference silently stales. Extract to shared preflight protocol to eliminate coupling. **Low-severity correctness risk.**

---

## F. Verdict

**`needs-tightening`**

Primary issues:
1. 18-line `--loop` alias rationale section is dead weight — migration complete, alias pseudo-code in Flag Parsing already sufficient.
2. Pre-Flight session-conflict check (step 3) restates `session-protocol.md` inline without citation — drift risk.
3. Pre-Flight step 1b uningested-research logic is duplicated from `next` — DRY violation, extract to shared preflight.

**top_edits:**
1. Delete lines 38–55 (Loop Mode section) and line 20's carry-forward paragraph; retain only the 4-line alias pseudo-code already in Flag Parsing.
2. Add `<!-- follows: /_shared/session-protocol.md -->` citation to Pre-Flight step 3, or replace inline check with a call to a shared preflight helper.
3. Add `disallowed-tools: [mcp__chrome-devtools__*, mcp__plugin_playwright_playwright__*]` to frontmatter — prevents accidental browser MCP calls during pure-orchestration phases.
