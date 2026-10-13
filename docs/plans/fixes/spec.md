---
status: active
priority: P1
created: 2026-10-12
ship: manual
---
# Fixes from the owed-cleanups dogfood run

## Goal
The first end-to-end `next --loop` run on this repo (owed-cleanups, 2026-10-12) surfaced defects in the loop machinery itself: skill-argument substitution corrupting embedded bash, a CONDITIONAL verdict the loop cannot leave, the session's own idle notices blocking it, missing `tasks.sh` edit verbs, registry rows that assume `src/`, a force-push guard that reads across commands, and two check advisories. Fix them so an unattended loop runs on a plain bash/markdown repo without hand intervention.

## Outcomes
- No SKILL.md body carries positional `$N`; build's gate and ship's spec/report parsing see their own values → T-001
- The skill validator fails any SKILL.md body that reintroduces `$N` → T-002
- A fresh CONDITIONAL with nothing open is row 1, not row 3; row 0 still reports the active plan → T-003
- `check` at plan scope turns each fileable advisory into an `origin: check` task, so the loop builds it and re-checks → T-004
- The session's own `needs_input` lines no longer hold the loop after the user answers → T-005
- `tasks.sh set … depends_on=` and `tasks.sh add-verify` exist → T-006
- Registry rows det-01/05/07/09/10 and `check:test-tamper` run and report correctly without `src/` → T-007
- `git push …; rm -f x` is not a force-push to the guard → T-008
- `check-section-refs.sh` resolves relative and skill-local numbered citations → T-009
- The row-3 Stop gate lints changed files when the lint row is per-file → T-010

## Out of scope
- Installing `bats` on this host (mise shim has no version); verify uses the npx shim.
- Rewriting CHANGELOG history.

## Assumptions
- User ruling 2026-10-12: CONDITIONAL → advisories become tasks; row 1 only when none are fileable.
- T-005 hooks the dismissal onto PostToolBatch (`heartbeat.sh`): the first tool batch after a reply is proof the user answered; no new hook event needed.

## Verification
- `bash /home/lasswellt/.claude/plugins/cache/blitz/blitz/3.16.0/scripts/tasks.sh verify fixes <id>` per task; `/blitz:check --scope plan fixes` before ship
- Re-run `/blitz:next --loop` on this repo after ship: no manual inbox triage, no hand-ordering, no gate errors.
