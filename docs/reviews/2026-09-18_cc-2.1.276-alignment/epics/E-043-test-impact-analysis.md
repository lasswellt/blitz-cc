---
id: E-043
title: "Test impact analysis v0 — stateless listener + in-repo selector"
status: planned
priority: P1
phase: 2
domain: quality
depends_on: []
cc_floor: "2.1.71"
estimated_stories: 7
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-043 Test impact analysis v0

**Why.** Anthropic's CI post describes 25× job growth in six months once agents write most of the code, and the fix that held: a **listener** that records every test result into an append-only journal from stateless workers, and a **selector** that reads per-test history to pick what runs on a change. blitz today runs `npm test -- --changed` (sprint-review) and a filename-sibling matcher (`post-edit-test.sh`). Both miss transitive impact and neither learns from history.

**Design constraints carried over.** Append-only journal; stateless writers; no service, no singleton; observability = `runs_started == runs_recorded`; plan for 10–20× the current volume in v0. Stack scope: Vue / Nuxt with Vitest (Jest fallback). No new dependencies; the runner's own graph (`vitest related`, `jest --findRelatedTests`) is the import analysis.

## Stories

### S1 Listener
- **Files:** new `scripts/test-listener.sh`; `hooks/tests/test-listener.bats`; fixtures under `hooks/tests/fixtures/tia/`.
- **Change:** stdin = runner JSON (`vitest --reporter=json`, `jest --json`); args `--trigger post-edit|sprint-review|ci --changed <files> --selected-by <mode> --run-id <id>`. Appends one line per test file to `.cc-sessions/test-journal.jsonl`: `{ts, run_id, session, trigger, commit, changed:[…], test_file, result: pass|fail|skip, failed_names:[…], duration_ms, selected_by}`. Increments `runs_recorded` in `.cc-sessions/test-journal.meta.json`; the caller increments `runs_started` before running. Append under a `noclobber` lock.
- **Acceptance:** two concurrent invocations on the fixture produce no interleaved lines; `runs_started == runs_recorded` after a clean run.

### S2 Selector
- **Files:** new `scripts/test-selector.sh`; `hooks/tests/test-selector.bats`.
- **Change:** input = changed files (args or stdin). Output = test files, one per line, with a reason tag (`sibling`, `graph`, `recent-fail`, `co-change`). Union of: (1) sibling matcher moved out of `post-edit-test.sh`; (2) runner graph (`npx vitest related <files>` / `npx jest --findRelatedTests <files>`); (3) journal recent-fail (tests that failed in the last 5 runs); (4) journal co-change (tests that failed when any of these files changed). `--full` when the changed set touches config / lockfile / test setup, exceeds 40 files, or journal `escaped_failures` > 0 in the last 3 sprint-review runs.
- **Acceptance:** fixtures cover each source and the `--full` fallbacks; runs without a journal (cold start → sibling + graph only).

### S3 Post-edit path
- **Files:** `hooks/scripts/post-edit-test.sh`; `hooks/scripts/heartbeat.sh` (E-041 S1, `PostToolBatch`, `async` + `asyncRewake`).
- **Change:** `post-edit-test.sh` reduces to appending `file_path` to `.cc-sessions/sessions/<sid>/touched.txt` and exit 0. `heartbeat.sh` once per batch: if `touched.txt` non-empty → selector → run → listener; clear `touched.txt`; on failure emit a ≤ 10-line digest (which re-wakes the model via `asyncRewake`).
- **Acceptance:** editing one source file runs only its selected tests; failure digest appears as hook feedback.

### S4 Sprint-review calibration
- **Files:** `skills/sprint-review/SKILL.md` §1.3; `skills/sprint-review/references/main.md:233-241`.
- **Change:** run the selector over `git diff --name-only $SPRINT_BASE..HEAD`, run the selected set, then ONE full run (sprint close is the calibration point); the listener records both with `selected_by`. Compute `escaped_failures` = failures in the full run whose file was not selected; write to the gates JSON and the journal meta.
- **Acceptance:** fixture with an intentionally unselected failing test yields `escaped_failures: 1` and the selector's next run goes `--full`.

### S5 Advisory ratchet metrics
- **Files:** `skills/_shared/quality-engine.md` §Ratchet; `skills/_shared/check-registry.json`; `skills/quality-metrics/SKILL.md`.
- **Change:** add **advisory** metrics `tia_escaped_failures` (↓) and `tia_selection_ratio` (selected / total, informational). Do not change the "8-metric" count yet; promotion to metric 9 is a separate story because it touches the prose in six files.
- **Acceptance:** `check-registry-validate.sh` green; `/blitz:quality-metrics` shows the two metrics.

### S6 Journal maintenance
- **Files:** `scripts/test-listener.sh --prune`; `skills/health/SKILL.md`.
- **Change:** keep the last 5 000 lines or 30 days; health reports journal size and the in/out delta.

### S7 Consumer CI recipe (documentation)
- **Files:** `docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md` is the source; ship the snippet in `README.md` §Parallel Sessions or a new `docs/guides/tia.md`.
- **Snippet:** PR job: `runs_started++ → scripts/test-selector.sh $(git diff --name-only origin/main...) → npx vitest run <selected> --reporter=json | scripts/test-listener.sh --trigger ci`; nightly job: full run through the listener to measure escapes; `actions/cache` for the journal keyed on ref.

## Verification
- `bats hooks/tests/test-listener.bats hooks/tests/test-selector.bats`; `validate-plugin-structure.sh` (exec bits, shebangs); `check-count-sync.sh` (script count changes).
- Manual on cubeSP-style monorepo: selected set runs in under one third of full-suite time on a one-file change.

## Risks
- `vitest related` needs the project's vitest config; fall back to sibling matching when the runner is absent.
- Journal correctness depends on callers passing `--changed`; sprint-review and heartbeat are the only writers in v0.
