---
unit: skills/ask
kind: skill
verdict: needs-tightening
removable_lines: 22
created: 2026-05-28
---

# Cohesion Audit — `skills/ask/SKILL.md`

## A. Identity & Boundaries

**Purpose (one sentence):** Intake router that classifies vague user requests and dispatches to the correct Blitz skill(s) via targeted clarification and a confirmed plan.

**Description vs body match:** Description says "routes…by classifying intent and asking targeted clarifying questions." Body implements exactly that in four phases. Match: ✓.

**Overlap analysis:**

| Overlapping unit | Nature |
|---|---|
| `agents/orchestrator.md` | **True partial duplicate.** Orchestrator §2 routing matrix maps identical intent keywords → skills. `ask` does the same in Phase 1 table. Orchestrator runs on freeform input; `ask` is slash-invoked. The distinction is call-site only — the routing tables themselves are independently maintained and will drift. |
| `skills/next/SKILL.md` (inferred) | `ask` routing table includes "next / what now / continue" → `next` skill. No logic beyond a pointer; legitimate thin layering, not duplication. |
| `skills/quick/SKILL.md` (inferred) | `ask` routes "just do it / trivial" → `quick`. Same — pointer only. |

**Verdict on orchestrator overlap:** Routing table in `ask` Phase 1 and orchestrator §2 are independently maintained duplicates of the same classification logic. One is slash-invoked, one is the main-thread agent, but both produce skill dispatch. True duplication of maintenance surface.

---

## B. Cohesion

**Shared protocols cited:**
- `/_shared/verbose-progress.md` — cited by name in Phase intro prose. Followed: `[ask]` prefix lines, `skill_start`/`skill_complete` events. ✓
- Activity-feed format — described inline rather than by `/_shared/verbose-progress.md` reference for the ephemeral-ID paragraph. Minor drift risk.
- `/_shared/session-protocol.md` — **not cited.** Skill deliberately opts out ("does not use the full session protocol"). The inline paragraph restates the opt-out rationale instead of referencing the protocol's exemption clause.
- `/_shared/state-handoff.md` — **not cited.** `ask` produces no artifact; it dispatches. No consume/produce contract violation, but the absence of an explicit "no artifact emitted" note means the handoff table gap is implicit.
- `/_shared/story-frontmatter.md` — not applicable; `ask` does not produce stories.

**Cross-refs:**
- `/_shared/verbose-progress.md` — live path, accurate. ✓
- `/_shared/terse-output.md` — not referenced in body, but OUTPUT STYLE snippet present. ✓

**OUTPUT STYLE (Invariant 5):** Present verbatim on line 12. Hash-comparable. ✓

**Pipeline chain trace:**
`ask` Phase 4 dispatches `sprint-plan` → `sprint-dev` → `sprint-review` (per routing table row "new page / new feature / add X"). `sprint-plan` requires `roadmap-registry.json` per `state-handoff.md`. `ask` passes only free-text args; the presence/absence of `roadmap-registry.json` is not checked before dispatch. If the user says "add feature X" in a project without a roadmap, `ask` dispatches `sprint-plan`, which hard-fails at Phase 0.0. `ask` should surface this guard or at least note it in the plan. **Gap: no pre-dispatch prerequisite check.**

---

## C. Conciseness

Body: 120 lines (well under 500-line cap). ✓

**Prose that compensates for old-model behavior (anti-laziness nudges):**

> "Be concise. Do not over-explain." (line 116)

> "If the user says 'just do it' or similar, skip clarification and proceed with reasonable defaults." (line 117)

> "Always respect the user's stated scope — do not expand beyond what was asked." (line 118)

These are behavioral nudges to prevent over-talking / scope creep — patterns guarded against in pre-4.8 models. With Opus 4.8 honesty improvements (platform-delta.md `claude-opus-4-8 / 2026-05-28`), these are less necessary. ~3 lines removable.

**Phase 3 plan template** (lines 92–99) restates the format of the confirmation prompt inline. This could be a reference to a shared confirmation boilerplate from `_shared/agent-prompt-boilerplate.md` (CONFIRMATION section). Inline restatement = drift risk. ~8 lines could be a reference.

**Developer profile block** (Phase 1.5, lines 60–73) is 14 lines of inline policy that duplicates the autonomy-level rules from `session-protocol.md`. The profile reading itself is legitimate; the autonomy override logic should reference `session-protocol.md §autonomy` rather than restate it. ~6 lines removable if replaced with a citation.

**Routing table** (lines 27–56) — 30 lines of inline routing logic duplicated with `orchestrator.md §2`. Not removable from `ask` unilaterally (see E below), but is the largest single DRY violation.

**Estimated removable lines (excluding routing table):** ~17–22 lines.

---

## D. Modernization

**Native primitives:**

1. **`/goal` loop** (platform-delta.md `v2.1.139 / 2026-05-11`): `ask` Phase 4 manually chains skills and monitors findings. `/goal` provides a native completion-condition loop. Delegation is partial only — `ask`'s value is pre-dispatch clarification + plan presentation; `/goal` covers the post-dispatch loop. **Keep `ask`; optionally note `/goal` as available for single-condition exit after dispatch.**

2. **`disallowed-tools`** (platform-delta.md `v2.1.152`): `ask` uses `allowed-tools: Read, Bash, Glob, AskUserQuestion`. No write tools — correct for a router. No `disallowed-tools` needed currently, but if `Bash` is narrowed to read-only ops this frontmatter is already correct. ✓

3. **`AskUserQuestion`** tool: present in `allowed-tools`. This is the correct declarative primitive for Phase 2 clarification. ✓ (Already using native primitive.)

4. **Orchestrator as native router** (platform-delta.md `v2.1.154+`): the holistic-machine `orchestrator.md` is now the canonical freeform router. `ask` is slash-invoked by users who explicitly want routing help. The distinction is intentional. **Keep** — but the routing table duplication between the two must be DRY'd.

**Model/effort:** `model: opus`, `effort: low`. Routing + clarification is pattern-match + light reasoning; Sonnet would be sufficient and cheaper. Opus is justified only if `AskUserQuestion` generation quality matters significantly. **Inferred** (not verified by test data): Sonnet 4.6 likely adequate for this task. Flag for downgrade evaluation.

---

## E. Correctness

1. **Routing table `migrate` skill** (line 41): references `migrate` skill. No `skills/migrate/SKILL.md` found in standard skill list (not in the 39-skill catalog cited by CLAUDE.md). **Potentially stale/dead reference.** Needs verification.

2. **Routing table `ship` skill** (line 43): references `ship` skill. Not in the 39-skill catalog. Same concern.

3. **`/sprint cmd`** (line 35): routing table references `/sprint cmd` not `/blitz:sprint`. Inconsistent naming convention — all other Blitz skills are `/blitz:<name>`.

4. **`compatibility: ">=2.1.71"`**: `AskUserQuestion` tool availability should be checked against actual introduction version. If `AskUserQuestion` was introduced after 2.1.71 this floor is too low. **Inferred** — not verified.

5. **Subagent constraint:** `ask` is slash-invoked (bypasses orchestrator). Phase 4 dispatches via the Skill tool. If `ask` is ever called from within a subagent context, it would need the same "subagents-cannot-spawn-subagents" guard as orchestrator. Dynamic Workflows (platform-delta.md `v2.1.154+`) do not eliminate this constraint for in-process spawning; the constraint remains. No change needed, but the absence of a note makes this fragile.

6. **No `references/` directory** — verified by Bash: `NO_REFS`. All cross-refs are inline. ✓ (nothing to check for dead ref files).

---

## F. Verdict

**`needs-tightening`**

### Top Edits (highest leverage)

1. **DRY the routing table with `orchestrator.md`**: Extract routing table to `skills/_shared/routing-table.md` (or a referenced YAML file), import via `<!-- import: -->` marker in both `ask/SKILL.md` and `agents/orchestrator.md`. Eliminates the largest maintenance duplication surface (~30 lines stay but become a single-source reference).

2. **Verify + remove stale `migrate` and `ship` skill references** from the routing table (lines 41, 43). If those skills don't exist, replace with inline instructions or remove rows.

3. **Replace inline autonomy-override prose** in Phase 1.5 with a citation to `skills/_shared/session-protocol.md §autonomy`. Reduces inline restatement drift (~6 lines).
