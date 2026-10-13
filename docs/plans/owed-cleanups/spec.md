---
status: active
priority: P2
created: 2026-10-12
ship: manual
---
# Owed cleanups after 3.16.0

## Goal
Close the two items 3.16.0 left owed: bring `skills/_shared/agents.md` under the 8,000-byte head budget by moving detail into `agents.reference.md`, and widen `markdown-link-validate.sh --all` from `skills/` + `agents/` to `docs/` and both changelogs. Also the first end-to-end `next --loop` dogfood run of the 3.16.0 gates on this repo.

## Outcomes
- `wc -c skills/_shared/agents.md` < 8000, with the routing matrix and visibility sections intact in `agents.reference.md` → T-001
- Every `§` citation of the moved sections resolves (`scripts/check-section-refs.sh` exit 0) → T-002
- `markdown-link-validate.sh --all` checks `docs/**/*.md`, `CHANGELOG.md`, `CHANGELOG-ARCHIVE.md`, and a broken link there fails it → T-003
- `next --loop` Stop-gate checks resolve through `scripts/toolchain.sh`, so a non-TypeScript repo is not gated on `npx tsc` → T-004

## Out of scope
- Rewording the moved sections; they move verbatim.
- Rewriting historical CHANGELOG lines that cite old section numbers.
- Evals (`claude plugin eval --ablation`).

## Assumptions
- Move §1.3 (Model routing matrix) and §1.5 (Visibility) because they are the two largest sections; together they take `agents.md` from 14,860 to about 5,950 bytes. They become `agents.reference.md` §11 and §12.
- Trial widening on 2026-10-12 found 0 broken links in `docs/` and the changelogs (490 checked), so no separate stale-link fix task.

## Verification
- `bash /home/lasswellt/.claude/plugins/cache/blitz/blitz/3.16.0/scripts/tasks.sh verify owed-cleanups <id>` per task; `/blitz:check --scope plan owed-cleanups` before ship
- After the run, note in progress.md which 3.16.0 gates fired (toolchain table resolution, tasks-guard, pre-commit-validate, Stop gate).
