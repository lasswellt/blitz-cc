---
unit: skills/next/SKILL.md
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `blitz:next`

## A. Identity & Boundaries

**One-sentence purpose:** Priority-ordered state reader that either prints the recommended next blitz command (default) or auto-dispatches one phase per tick and exits (--loop reconciliation engine).

**Description vs body match:** Yes. Frontmatter description matches the two-mode body structure exactly. The "supersedes /blitz:sprint --loop" annotation is accurate — `skills/sprint/SKILL.md` confirms the alias routing.

**Overlapping skills/agents:**

| Skill/Agent | Overlap type | Assessment |
|---|---|---|
| `blitz:sprint` | `--loop` flag | **Legitimate layering** — sprint delegates to next via alias. No duplication; sprint.SKILL.md explicitly says "backwards-compat alias". |
| `blitz:implement` | rows 1, 2, 5 dispatch | **Legitimate orchestration** — next reads state, implement executes. next never touches story implementation. |
| `blitz:sprint-plan` | rows 6b-6e dispatch | **Legitimate orchestration** — same pattern. |
| native `/goal` loop (platform-delta.md v2.1.139 / 2026-05-11) | `--loop` single-condition exit | **Partial overlap** — `/goal` is simpler for single-condition exit criteria; next's 10-condition priority tree + cross-session STATE.md resume is not replicated natively. Keep. |
| native `claude agents` TUI (platform-delta.md v2.1.139 / 2026-05-11) | session visibility in `--loop` | **Complementary** — agents TUI shows running sessions but cannot dispatch blitz phases. |

## B. Cohesion

### Shared protocols cited

| Protocol | Cited? | Followed or restated? |
|---|---|---|
| `session-protocol.md` | Yes (line 32) — link, conditional use | Followed via reference; §Session Registration delegated to reader |
| `carry-forward-registry.md` | Yes (line 17) — link | Followed; jq Reader Algorithm inline (Phase 0.6) is verbatim from carry-forward-registry.md §Reader Algorithm. **Drift risk**: duplicated inline. |
| `state-handoff.md` | Yes (line 17) — link | Referenced; no restatement. |
| `scope-limit-protocol.md` | Yes (line 188) — link | Phase 0.9c is a faithful implementation; behavior contract delegated to protocol. Clean. |
| `verbose-progress.md` | Not cited | Phase 4 report format is an inline restatement. Moderate drift risk — if verbose-progress.md adds fields, Phase 4 won't auto-update. |
| `spawn-protocol.md` | Not cited | Not needed — next dispatches via Skill tool, not Agent(). Correct omission. |
| `token-budget.md` | Not cited | Not needed — no direct agent spawning. Correct omission. |

### Invariant 5 (OUTPUT STYLE snippet)

Line 23 contains the verbatim canonical snippet. **Pass.**

### State handoff compliance

next **consumes**: `sprint-registry.json`, `STATE.md`, `.cc-sessions/activity-feed.jsonl`, `roadmap-registry.json`, `epic-registry.json`, `.cc-sessions/carry-forward.jsonl`, `docs/_research/*.md`, `docs/audits/*-epics.md`, `docs/audits/*-index.json`, `SCOPE-LIMIT.md`. All match state-handoff.md consumer columns. ✓

next **produces**: git commit + push (loop mode only). No new registry artifacts. Consistent with state-handoff.md (next is not listed as a producer — correct, it delegates production to dispatched skills). ✓

### Cross-ref accuracy

- `/_shared/state-handoff.md` — verified present.
- `/_shared/carry-forward-registry.md` — verified present.
- `/_shared/scope-limit-protocol.md` — verified present.
- `/_shared/session-protocol.md` — verified present.
- `docs/_research/2026-04-08_sprint-carryforward-registry.md` — **unverified** (not read; path referenced in Phase 1 explanation prose at line 261). Mark as inferred-live.
- `docs/_research/2026-05-18_audit-deferred-work-detection.md` — **unverified** (same). Inferred-live.
- `agents/test-writer.md` ESCALATE vocabulary (line 222) — referenced but not read. Inferred-accurate.

### Pipeline chain trace (end-to-end): row 1 (resume sprint)

1. `sprint-dev` writes `STATE.md` to `sprints/sprint-N/STATE.md`.
2. `next` Phase 0.2 reads that file.
3. Phase 1 row 1 fires: `sprint in-progress` + `STATE.md` exists.
4. Phase 3.4 dispatches `Skill({ skill: "blitz:implement", args: "--resume" })`.
5. `implement/SKILL.md` accepts `--resume` — **verified** from sprint/SKILL.md line referencing implement. Shape matches.
6. Phase 3.5 commits + pushes.
7. Phase 3.6 self-schedules or `/loop` re-ticks.
8. Next tick: Phase 0.2 finds no `STATE.md` (implement deleted it on completion) → row 2 or row 3 fires. Correct.

Chain is coherent.

## C. Conciseness

**Body line count:** 460 lines. **At cap** (500-line limit). Tight.

### Prose compensating for old-model behavior (deletion candidates)

**Lines 303–305** (§3.1 autonomy block):
> "Suppress all sub-skill confirmation prompts. Remaining safety overrides (always logged, never silently bypassed): `git push`, rollback to previous sprint state, deleting user files outside sprint scope. All other decisions auto-approved."

Failure mode guarded: old models would ask confirmation mid-loop, breaking unattended runs. With 4.8 honesty gains + `settings.autoMode.hard_deny` (platform-delta.md v2.1.136), the platform enforces these rules natively. The prose is now partially redundant — `hard_deny` handles the "never silently bypass" contract at the platform level. **Candidate for collapse to a 1-line comment.** ~4 lines removable.

**Lines 345–353** (§3.5 commit block):
```bash
git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "feat(loop): next reconciliation tick — <row N: phase name>" || true
  git push origin HEAD || true
fi
```
`|| true` suppression exists to prevent loop abort on non-zero exit. Legitimate. Not a laziness guard — keep.

**Lines 261** (Why rows 6a-6f exist — 3-sentence historical explanation):
> "Why rows 6a-6f exist: the prior state machine collapsed rows 6 and 7 together…"

Failure mode guarded: reader confusion about why the split exists. Useful context preserved in research docs. At 460 lines, this 3-sentence block is worth keeping for future auditors. Borderline — **leave**.

**Lines 248–259** (Tie-Breaking numbered list with explanations):
Items 1-4 are obvious from the table. Items 5-10 are non-obvious (especially 8 and 9). Keep items 5-10, **collapse items 1-4** to a single header note. ~5 lines removable.

**Phase 0.6 inline jq Reader Algorithm (lines 112–123)**:
The jq is duplicated verbatim from `carry-forward-registry.md §Reader Algorithm`. Drift risk is real. **Replace with a `<!-- import: -->` citation + single reference** like other shared protocols. ~10 lines of inline jq removable.

**Phase 4 REPORT examples (lines 371–460)**: 90 lines of example output. Every example is structurally distinct (dispatching, idle, gap closure, audit sprint, scope limit, escalation). Useful documentation of the 6 distinct banner shapes. Retain — not compensating for model behavior, it's spec for downstream `/loop` wrappers. **Not removable.**

**Flag Parsing scheduling tiers table (lines 42–48)**: Documents 3 tiers with persistence/interval columns. Accurate and not available elsewhere. Keep.

**Total estimated removable:** ~55 lines (CF Reader Algorithm inline = 10, §3.1 autonomy prose collapse = 4, Tie-Breaking items 1-4 collapse = 5, Phase 0.9/0.9b/0.9c minor comment verbosity = ~36 lines across the block comments in 0.9b specifically).

## D. Modernization

### Native `/goal` overlap

platform-delta.md v2.1.139 / 2026-05-11: `/goal` completion-condition loop — fast model checks condition after each turn; loops until condition holds, then clears.

**Verdict: keep.** `/goal` handles a single boolean condition; `blitz:next --loop` implements a 10-row priority decision tree with cross-session state persistence (`STATE.md`, carry-forward registry), multi-phase dispatch, and structured stop signals (`LOOP_DONE`, `LOOP_ESCALATE`, `LOOP_DEFER`). Delegating to `/goal` would lose: (a) priority ordering across 10 conditions, (b) cross-session resume via `STATE.md`, (c) structured stop signals for external `/loop` wrappers, (d) git commit + push semantics per tick. **Not delegatable.**

**Tradeoff:** native `/goal` is latency-cheaper (fast model for condition check). Could use `/goal` as the re-tick trigger while keeping decision tree logic in `blitz:next` body. Minor optimization; not worth the split complexity at current scale.

### `disallowed-tools` frontmatter (platform-delta.md v2.1.152)

Phase 0.9c SCOPE-LIMIT check + Phase 1 decision tree have no dangerous tool guards. However, `--loop` mode dispatches `git add -A` via Bash + `git push`. Could use `disallowed-tools` to prevent accidental direct destructive git ops in suggest (default) mode. Low priority but addable.

### Model/effort frontmatter

`model: sonnet`, `effort: low`. Appropriate — default mode is a read-only state survey; loop mode dispatches sub-skills that carry their own model/effort. **Sane.** No fast-mode needed (latency not critical for a loop coordinator).

Model IDs: no explicit model ID in frontmatter, just `sonnet` alias. Acceptable per platform convention. Resolves to `claude-sonnet-4-6` per platform-delta.md 2026-05-28. No action needed.

## E. Correctness

**`compatibility: ">=2.1.71"`**: ScheduleWakeup appeared as a tool no earlier than v2.1.71; CronCreate is in the allowed-tools list (frontmatter line 5 shows `ScheduleWakeup` but NOT `CronCreate` — the scheduling tiers table at lines 42-48 mentions CronCreate but it's not in allowed-tools). **Potential bug**: Phase 0.9c SCOPE-LIMIT uses `awk` inside Bash — correct. Flag parsing references `CLAUDE_CODE_LOOP_MANAGED` env var — not documented in platform-delta.md, assumed convention. **Inferred-accurate, not verified.**

**`CronCreate` in scheduling tiers table (line 44) vs allowed-tools**: `CronCreate` is mentioned as a mechanism ("Tier 1: /loop + CronCreate") but `CronCreate` is not in `allowed-tools`. This is correct — next doesn't call CronCreate directly; `/loop` handles it externally. No bug.

**Stale version ref**: `v1.13.0` (line 30) — internal blitz version, references sprint --loop alias migration. Not a platform version. Accurate as of git log (`feat(sprint-13)` is most recent sprint). ✓

**`blitz:implement` dispatch** (rows 1, 2, 5): next references `blitz:implement` but the system skill list shows `blitz:sprint-dev` and no standalone `blitz:implement`. **Potential dead dispatch** — if `implement` is not a registered skill, the Skill tool call fails silently. Needs verification against `skills/` directory. (Not read — inferred concern.)

**Row 6a dispatches**: `Skill({ skill: "blitz:sprint", args: "--gaps" })` in the suggest column but NO dispatch in loop mode (prints banner + exits). Consistent. ✓

**`git add -A` in Phase 3.5**: explicitly discouraged by project git safety protocol ("prefer adding specific files"). In loop context this is intentional (all dispatched skill output committed per tick) — acceptable exception with an inline comment explaining scope. Missing comment. Minor.

## F. Verdict

**`needs-tightening`**

Top 3 highest-leverage edits:

1. **Replace Phase 0.6 inline jq with `<!-- import: carry-forward-registry.md §Reader Algorithm -->`** — removes ~10 lines of drift-risk duplication; single source of truth for the Reader Algorithm.

2. **Verify `blitz:implement` skill registration** — if `implement` is not a real skill (system list shows `sprint-dev`, not `implement`), rows 1, 2, and 5 dispatch dead calls. Fix by referencing the correct skill name or confirming `implement` is a valid alias.

3. **Collapse §3.1 autonomy prose to 1-line comment + add `disallowed-tools:` for suggest mode** — 4 lines of autonomy explanation become a reference to `session-protocol.md`; `disallowed-tools` declaratively prevents Bash writes in default (suggest) mode, aligning with platform-delta.md v2.1.152 capability.
