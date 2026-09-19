# Test impact analysis (TIA) — consumer guide

blitz ships a two-script test-impact layer (E-043): a **listener** that journals every test result and a **selector** that reads the journal plus the import graph to pick what to run on a change. No service, no daemon, no npm dependency — two bash scripts (`bash` + `jq` + `python3`), an append-only file, and the runner's own JSON reporter.

| Script | Role |
|---|---|
| `scripts/test-listener.sh` | stdin = Vitest (`--reporter=json`) or Jest (`--json`) report → one journal line per test file; bumps `runs_recorded` |
| `scripts/test-selector.sh` | changed files → impacted test files (`<path>\t<reason>`); `--full` when selection would be unsafe |

Inside a blitz session the wiring is automatic: `post-edit-test.sh` records every edited file, `heartbeat.sh` (PostToolBatch, async) runs selector → runner → listener once per tool batch and re-wakes the model with a ≤10-line failure digest, and `/blitz:check` runs the selected set and then ONE full run to measure what the selector missed. This guide covers the part you wire yourself: CI.

## The journal

`.cc-sessions/test-journal.jsonl` — append-only, one line per test file per run:

```json
{"ts":"2026-09-18T17:04:10Z","run_id":"67554bae","session":"s1","trigger":"post-edit","commit":"6977db1f…","changed":["src/b.ts"],"test_file":"tests/b.test.ts","result":"fail","failed_names":["b returns b"],"duration_ms":8,"selected_by":"selector"}
```

`.cc-sessions/test-journal.meta.json` — the only mutable state:

```json
{"runs_started":12,"runs_recorded":12,"last_run_id":"67554bae","escaped_failures_recent":[0,0,1,0]}
```

- `trigger`: `post-edit` (heartbeat), `check`, `ci`.
- `selected_by`: `selector` or `full` — lets you compare the two populations later.
- `runs_started == runs_recorded` is the health invariant. Every caller bumps `runs_started` (`--start`) before the runner and the listener bumps `runs_recorded` after parsing. Drift > 3 raises a `hook_failure` inbox item; `/blitz:doctor` reports the delta.
- Writers take a `noclobber` lock (5 s spin, stale after 60 s), so parallel CI shards can append to a shared journal without interleaving.
- Maintenance: `scripts/test-listener.sh --prune` keeps the last 5 000 lines / 30 days.
- A malformed or empty report never fails the caller: the listener logs a `warning` to the activity feed and exits 0 — the run shows up as started-but-not-recorded, which is the point.

## Selector sources

`scripts/test-selector.sh [--base <ref>] [--full] [--json] [files…]` (files from args, stdin, or `git diff --name-only <base>..HEAD` + staged + unstaged). Output is the union of:

| Reason | Source | Notes |
|---|---|---|
| `sibling` | `<name>.test.<ext>`, `<name>.spec.<ext>`, `__tests__/<name>.<ext>` | the old `post-edit-test.sh` matcher |
| `graph` | reverse import closure changed → test files | Vitest: static resolver (relative imports, `tsconfig` `paths`, Nuxt `~/` `@/` `~~/` `@@/`). Jest: `npx jest --findRelatedTests --listTests` |
| `recent-fail` | journal: test files that failed in the last 5 runs | |
| `co-change` | journal: test files that failed in any run whose `changed` intersects the current change | learns coupling the graph cannot see (fixtures, env, generated code) |
| `full` | every `**/*.{test,spec}.*` + `__tests__/**` | `--full`, or automatically when the change touches `package.json` / lockfiles / `vitest|vite|jest` config / `tsconfig*` / test setup files, exceeds 40 files, or `escaped_failures_recent` has a non-zero entry in the last 3 check runs |

Cold start (no journal) = sibling + graph. The selector never fails: any resolver error prints the `--full` set and a note on stderr. `--json` adds `selection_ratio` (selected / total) and the graph mode used.

Why a static graph instead of `vitest related`? `vitest related <files>` *executes* the related tests, and `vitest list --changed` only accepts a git ref, not a file list — so the selector resolves imports itself, deterministically, and hands the runner an explicit file list.

## PR job

```yaml
# .github/workflows/test.yml (excerpt)
- uses: actions/checkout@v5
  with: { fetch-depth: 0 }
- uses: actions/cache@v4            # journal survives between runs, keyed on the branch
  with:
    path: .cc-sessions/test-journal*
    key: tia-journal-${{ github.ref }}-${{ github.run_id }}
    restore-keys: |
      tia-journal-${{ github.ref }}-
      tia-journal-refs/heads/main-
- run: npm ci
- name: Select + run + journal
  env: { BLITZ: node_modules/blitz-cc }   # or wherever the plugin is checked out
  run: |
    RUN_ID=${{ github.run_id }}-${{ github.run_attempt }}
    CHANGED=$(git diff --name-only origin/main...HEAD)
    SELECTED=$(printf '%s\n' "$CHANGED" | bash $BLITZ/scripts/test-selector.sh --base origin/main | cut -f1)
    bash $BLITZ/scripts/test-listener.sh --start --run-id "$RUN_ID"            # runs_started++
    [ -n "$SELECTED" ] && npx vitest run --reporter=json --outputFile=report.json $SELECTED || echo '{"testResults":[]}' > report.json
    bash $BLITZ/scripts/test-listener.sh --trigger ci --selected-by selector --run-id "$RUN_ID" \
      --changed "$(printf '%s\n' "$CHANGED" | paste -sd,)" < report.json           # runs_recorded++
    jq -e '.numFailedTests == 0' report.json > /dev/null
```

Jest: replace the runner line with `npx jest --json --outputFile=report.json $SELECTED`.

Restore the journal from `main` when the branch has none (the `restore-keys` fallback) so a fresh PR still benefits from `recent-fail` / `co-change` history.

## Nightly full run (measures escapes)

The selected run on PRs is only as good as its miss rate. Run the whole suite once a night through the same listener with `--selected-by full`, then count failures the selector would not have picked:

```yaml
- name: Full suite through the listener
  run: |
    RUN_ID=nightly-${{ github.run_id }}
    bash $BLITZ/scripts/test-listener.sh --start --run-id "$RUN_ID"
    npx vitest run --reporter=json --outputFile=full.json || true
    bash $BLITZ/scripts/test-listener.sh --trigger ci --selected-by full --run-id "$RUN_ID" < full.json
    # escaped = failed test files in full.json that today's selector would not have chosen
    SELECTED=$(git diff --name-only origin/main@{1.day.ago}...HEAD | bash $BLITZ/scripts/test-selector.sh | cut -f1 | sort)
    FAILED=$(jq -r '.testResults[] | select(.status=="failed") | .name' full.json | sed "s#^$PWD/##" | sort)
    ESCAPED=$(comm -23 <(echo "$FAILED") <(echo "$SELECTED") | grep -c . || true)
    jq --argjson n "$ESCAPED" '.escaped_failures_recent = ((.escaped_failures_recent // []) + [$n])[-10:]' \
      .cc-sessions/test-journal.meta.json > m.json && mv m.json .cc-sessions/test-journal.meta.json
    echo "escaped_failures=$ESCAPED" >> "$GITHUB_STEP_SUMMARY"
```

Any non-zero entry in the last three makes the selector go `--full` on subsequent PRs until three clean nightlies pass — the system degrades to "run everything" rather than to "miss things".

## Design rationale

Adapted from Anthropic's account of running CI once agents write most of the code: job volume grew ~25x in six months, and the change that held was **selection from history**, not a bigger fleet.

- **Stateless listener.** Every writer is a process that runs, appends, and exits. No daemon to keep alive, no singleton to shard around, nothing to restart. Scale by adding writers; the file is the coordination point (one lock, held for milliseconds).
- **Append-only journal.** Lines are never rewritten, so a partial write cannot corrupt history and any reader can reconstruct state from a prefix. Pruning is the only compaction and it is size/age based, never content based.
- **`in == out`.** The one number to watch is `runs_started - runs_recorded`. Zero means every run that began was journaled; anything else names the count of runs whose results are missing, which is exactly the failure mode a selector must not silently inherit.
- **Runner's own graph.** Import analysis is the test runner's problem (or, here, a 60-line static resolver with the same resolution rules); we do not add a second module system.
- **Calibration is mandatory.** Selection without a periodic full run drifts toward false confidence. Sprint close and the nightly job are the two points where the full population is measured and `escaped_failures` is written back into the selector's own inputs.

Related: `skills/_shared/quality.md` §Advisory metrics and §Verification stack; `skills/check/SKILL.md` §Tests; `hooks/scripts/heartbeat.sh`.
