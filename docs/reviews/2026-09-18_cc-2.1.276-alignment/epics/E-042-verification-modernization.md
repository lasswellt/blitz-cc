---
id: E-042
title: "Verification modernization — /goal, Stop gate, /verify recipe"
status: planned
priority: P1
phase: 2
domain: quality
depends_on: [E-040]
cc_floor: "2.1.271"
estimated_stories: 6
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-042 Verification modernization

**Why.** Anthropic's best-practices page defines a verification ladder: a check in the prompt → a `/goal` condition re-evaluated after every turn by a fresh small model → a deterministic Stop hook that blocks the turn from ending → an adversarial subagent. blitz has the first and last rungs (deterministic recipe, critic Invariant 7) but not the two in the middle. Its autonomous loop (`/blitz:next --loop`) self-paces with `ScheduleWakeup`, which is not restored on resume and carries the whole conversation every tick.

**Verification stack (to document in `quality-engine.md`)**

| Layer | Mechanism | Owner | Decides |
|---|---|---|---|
| Deterministic gate | `stop-gate.sh` + `gate.json` | blitz hook | tsc / selected tests / ratchet quick-check pass |
| Goal evaluator | `/goal <sprint DoD>` | user (blitz prints the line) | condition met / not yet / impossible |
| Adversarial | `agents/critic.md` | sprint-review Invariant 7 | LGTM / REJECT |
| App-level | `/verify` recipe | bundled skill, recorded per project | app runs and behaves |

## Stories

### S1 `stop-gate.sh`
- **Files:** new `hooks/scripts/stop-gate.sh` (wired in E-040 S2); `hooks/tests/stop-gate.bats`.
- **Change:** reads `.cc-sessions/sessions/<sid>/gate.json` = `{checks:[{name,cmd,timeout}], blocks:0, max_blocks:6, until:"<phase>"}`. No-op (exit 0) when the file is absent, when stdin `stop_hook_active` is true, when `last_assistant_message` contains `LOOP_DONE|LOOP_ESCALATE|LOOP_DEFER|BLOCKED:|ESCALATE:`, or when `blocks >= max_blocks` (log `gate_exhausted`, stay under the platform's 8-consecutive cap). Otherwise run each check with `timeout`; on first failure increment `blocks`, exit 2 with the check name and a 200-char tail.
- **Acceptance:** bats: absent → 0; failing check → 2; `blocks>=max` → 0 + feed entry; `stop_hook_active` → 0; passing → 0 and `blocks` reset.

### S2 sprint-dev writes the gate
- **Files:** `skills/sprint-dev/SKILL.md` Phase 2.0 / 3.0 / 4.10.
- **Change:** in autonomous mode write `gate.json` at Phase 3 start (`tsc --noEmit`, E-043 selector-picked tests, ratchet quick-check); delete at 4.10. Phase 0 prints one recommended line for the user: `/goal sprint N: all stories in sprints/sprint-N/stories are status: done, tsc clean, sprint-review PASS; stop after 40 turns`. Note that `/goal` check-ins (30 min, doubling) match wave cadence.
- **Acceptance:** dry-run fixture shows gate.json created and removed; no gate file remains after a `LOOP_ESCALATE`.

### S3 `/blitz:next --loop` modernization
- **Files:** `skills/next/SKILL.md:47-61` and §Loop; `skills/_shared/session-lifecycle.md:941-989`.
- **Change:** write a phase-specific `gate.json` per tick; print the `/goal` line once (row 0). Rewrite the scheduling prose (C3): self-paced loops are per-session and lost on resume; for durable loops use `/loop` in a dedicated session, a Desktop scheduled task, or a Routine; CronCreate expires after 7 days with jitter; `.claude/loop.md` can carry the blitz maintenance prompt. Remove `CLAUDE_CODE_LOOP_MANAGED` unless verified live. Before `ship`, invoke `/verify` when `.claude/skills/verify/SKILL.md` exists.
- **Acceptance:** `skill-frontmatter-validate.sh`; no reference to a 3-day expiry remains.

### S4 sprint-review uses the recorded recipe
- **Files:** `skills/sprint-review/SKILL.md` Phase 1, Phase 2.
- **Change:** if `.claude/skills/verify/SKILL.md` exists, invoke it as 1.0 and merge its result into the gates JSON; else run 1.1–1.4 as today. Phase 2 note: the bundled `/code-review` covers diff correctness in a fresh context; blitz reviewers scope to registry consistency, pattern conformance, and security.
- **Acceptance:** fixture repo with a recorded recipe produces a `verify` row in the gates JSON.

### S5 `/blitz:setup` seeds the recipe
- **Files:** `skills/setup/SKILL.md`.
- **Change:** offer to seed `.claude/skills/verify/SKILL.md` from `scripts/detect-stack.sh` output using the recipe in `quality-engine.md` §Deterministic Test Recipe. Fix `REQUIRED_TOOLS` (C10) after live verification.
- **Acceptance:** seeded recipe passes `skill-frontmatter-validate.sh` (it is a project skill, so only the platform's fields apply).

### S6 Docs
- **Files:** `skills/_shared/quality-engine.md` (new "Verification stack" section); `CLAUDE.md` Quality Gates pointer; `README.md` §How review & audit work.

## Verification
- `bats hooks/tests/stop-gate.bats`; validator sweep.
- Manual: run `/blitz:next --loop` on a fixture with a failing `tsc`; confirm the turn is blocked with the tsc tail, fixed on the next turn, and the gate resets.

## Risks
- A user `/goal` and the blitz gate both fire after every turn. Gate is a strict no-op without `gate.json`; `max_blocks: 6` leaves headroom under the platform cap.
- `-p` sessions have a 10-minute Monitor deadline; gate checks must each finish well under the hook timeout.
