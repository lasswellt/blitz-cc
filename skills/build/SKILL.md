---
name: build
description: "Implements work: a one-sentence change inline, or the next task from docs/plans/<slug>/tasks.json with a fresh dev agent per task, verify gate, and fix loop. Use for 'build', 'implement', 'fix issue #N', 'make this change', 'work the plan'. --parallel fans out disjoint tasks."
argument-hint: "[<slug>|<task-id>|--issue <n>|\"<change>\"] [--parallel] [--autonomous]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent, SendMessage, ListAgents, Monitor
model: inherit
compatibility: ">=2.1.271"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort high (the main thread routes; `dev` agents run on sonnet). Set once (`claude --model opus --effort high` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- Task file schema, `blocked_reason` vocabulary, `progress.md` format, gate arming, markers: [loop.md](/_shared/loop.md)
- `dev` roster entry, 11-item spawn spec, reply status enum, fix loop, deviation tiers, worktree platform facts, `--parallel` preconditions, `Workflow` contract: [agents.md](/_shared/agents.md)
- Structural done, Definition of Done, anti-mock rows: [quality.md](/_shared/quality.md) §Structural done
- Session claim, conflict matrix, feed schema, HANDOFF.json: [sessions.md](/_shared/sessions.md)
- Package install policy, TB-3 reply handling: [security.md](/_shared/security.md)
- Spawn prompt template, wave mechanics, integration checklist, selective re-verify, cleanup: [references/main.md](references/main.md)
- Role conventions inlined into every `dev` prompt: [references/backend.md](references/backend.md), [references/frontend.md](references/frontend.md), [references/infra.md](references/infra.md), [references/test.md](references/test.md)

---

# Build

One skill, three modes. `build` writes `tasks.json` only through `scripts/tasks.sh`, writes `progress.md` only on the main thread at task boundaries, and never lets a `dev` agent touch either. "Done" is a bit `tasks.sh verify` sets after reading evidence, never a sentence an agent writes.

---

## Phase 0: MODE SELECT

### 0.1 Preamble

1. Claim the session record per [sessions.md](/_shared/sessions.md) §2 (`skill: build`, `working_on: <mode> <target>`, `args`). Never mint an id.
2. `rm -f ".cc-sessions/sessions/${CLAUDE_SESSION_ID}/gate.json"` — a leftover gate from an aborted run blocks the next turn.
3. Run the conflict matrix ([sessions.md](/_shared/sessions.md) §6). `build` on the same plan, or `check --fix` on it, is **BLOCK** → `SendMessage(..., notify_when_idle: true)`, print `LOOP_DEFER`, exit. `build` on another plan with overlapping `files` is WARN.
4. Feed: `skill_start {args}`.

### 0.2 Parse the argument

| Argument | Mode |
|---|---|
| quoted `"<change>"`, or `--issue N` with no `docs/plans/*/tasks.json` carrying `origin: issue:N` | **inline** (§Inline), if §0.3 holds; otherwise say so and route to `/blitz:plan` |
| `<slug>` (a directory under `docs/plans/`) | **task** — loop over ready tasks |
| `<task-id>` (`T-nnn`; resolve the slug by grepping `docs/plans/*/tasks.json` for the id; ambiguous → ask) | **task** — that one task only |
| `<slug> --parallel` | **parallel** (§Parallel) if §0.4 holds; otherwise sequential with a one-line reason |
| none | `scripts/next-state.sh` → `active_plan`; none active → print `LOOP_DONE` and stop |

`--autonomous` (or `BLITZ_AUTONOMOUS=1`, set by `next --loop`) keeps looping without a review pause and arms the Stop gate (§Gate). Without it, every task boundary is a stopping point where the user may review.

### 0.3 Inline conditions (all three, else task mode via `plan`)

1. The diff is describable in one sentence.
2. ≤5 files change.
3. No new dependency, no new directory, no schema/auth/env change (Tier 4 in [agents.md](/_shared/agents.md) §9).

### 0.4 Parallel preconditions ([agents.md](/_shared/agents.md) §5.2)

```bash
BASE_REF=$(jq -r '.worktree.baseRef // "fresh"' .claude/settings.json 2>/dev/null)
[ "$BASE_REF" = "head" ] || echo "REFUSE --parallel: worktree.baseRef is '$BASE_REF' (needs \"head\"); run /blitz:doctor and set it in .claude/settings.json"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --status open --json | jq -r '.[] | .id + " " + (.files | join(","))'
```

Fall back to sequential, with the reason printed, when any of these fails: `worktree.baseRef ≠ "head"`; fewer than 3 open ready tasks with pairwise-disjoint `files` (exact path match; a shared barrel or config file disqualifies both); another live session on the plan; `--parallel` absent. Cap is 4 concurrent agents per wave.

---

## Inline mode

No agents, no plan. Do the work on the main thread.

### I.0 Understand

1. Parse the request into exactly what changes.
2. Locate the target files. More than 5 → stop, say so, suggest `/blitz:plan "<change>"`.
3. Baseline type-check so pre-existing errors are known:
   ```bash
   npm run type-check 2>&1 | tail -5
   ```

### I.1 `--issue N` (prepended when present)

Fetch and classify before touching code — salvaged from the retired fix-issue skill:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
[ -n "$REPO" ] || echo "ERROR: not a GitHub repo or gh not authenticated (gh auth login)"
gh issue view "$ISSUE_NUMBER" --json title,body,labels,assignees,comments,state,milestone
```

Record title, body, labels, comments, state (warn if closed), milestone. Classify: **Bug** (`bug`, "error", "crash", "broken"), **Regression** ("used to work", "since version"), **Performance** ("slow", "timeout", "memory"), **Feature gap** (`enhancement`, "should support"), **Configuration** ("config", "environment"). Extract reproduction steps, expected vs actual, stack traces, named files.

**Investigate.** Research is mandatory when the issue involves third-party behavior, the error is not traceable to project code, a version bump is the trigger, confidence is Medium/Low, or the issue is >7 days old. Otherwise skip and say why. When needed, spawn `general-purpose` (Light; it must Write `${SESSION_TMP_DIR}/issue-research.md`, stub first, append findings; max 5 searches, 8 reads, 150 lines, 3 min). Check `[ -s "$RESEARCH_FILE" ]` before reading; empty → confidence Low, do not implement on missing research; retry narrower or ask. Then write the root cause block:

```
Root Cause Analysis
Issue: #<n> — <title>
Cause: <1-2 sentences>
Location: <file:line>
Mechanism: <data flow / timing>
Confidence: High | Medium | Low
```

Low → say what would help and ask. Issue-scoped changes larger than §0.3 → `/blitz:plan --issue N` (task `origin: issue:N`), not inline.

### I.2 Implement

Edit the files directly, following existing patterns. Only what was asked: no adjacent refactors, no added comments, no "improvements". Add a regression test when the change is a bug fix and a matching test file exists.

### I.3 Verify

```bash
npm run type-check 2>&1 | tail -10
npm run test -- --run <matching-test-file> 2>&1 | tail -15    # when a matching test exists
```

On failure fix and re-run, **max 3 attempts**, then report the failure and stop (feed `verification {command, result}` each run). Commit when the change is complete or the user asked:

```bash
git add <changed-files>
git commit -m "fix(<scope>): <description>"     # `Task: issue:<n>` trailer for --issue
```

### I.4 `--issue N` closing comment (appended when present)

Terse-technical; labels verbatim (downstream parsers grep them), values as fragments, **Root Cause** at LITE intensity so the reasoning chain survives. No trailing "ready for review" filler.

```bash
gh issue comment "$ISSUE_NUMBER" --body "$(cat <<'MSG'
## Fix Applied

**Branch**: `<branch-name>`
**Root Cause**: <1 fragment with file:line; reasoning must survive>
**Fix**: <1 fragment + file:line refs>
**Files Changed**:
- `<file1>`: <what changed>

**Verification**:
- Type-check: PASS
- Tests: PASS (<N> passed)
- Build: PASS
MSG
)"
```

### Inline guardrails

- **Max 5 files.** More → `/blitz:plan`.
- **No new packages, no new directories.** Either → `/blitz:plan` (or `/blitz:research` first).
- **Definition of Done still applies** ([quality.md](/_shared/quality.md)): no placeholder returns, no TODO stubs, no empty handlers, no `vi.mock` of `src/`.
- **Never `--no-verify`.**

---

## Task mode

### T.1 Baseline and conventions (once per invocation)

1. Inventory: `find . -maxdepth 3 -name package.json -not -path '*/node_modules/*' | head -30`; read the root `package.json` and workspace config.
2. Build health; catalog pre-existing errors so agents are not blamed for them:
   ```bash
   npm run type-check 2>&1 | tail -20
   npm run build 2>&1 | tail -20
   ```
   **Gate:** build succeeds or pre-existing errors are cataloged before any spawn.
3. Conventions: read 2-3 representative files per layer the plan touches (backend, stores, components, tests). Note auth pattern, error format, response envelope, validation, component style, store pattern, loading UI, test structure, naming. List reusable assets (`composables/`, `utils/`, `shared/`, `components/base/`) as **REUSE THESE — do not recreate**. This block goes verbatim into every spawn prompt (item 3 of the spec; see [references/main.md](references/main.md) §Spawn prompt template).
4. Read `docs/plans/<slug>/plan.md` and the tail of `progress.md` (last 20 lines): they are the recovery map. Trust them and `git log --grep 'Task: <slug>/'` over any recollection, especially after compaction (`HANDOFF.json` names the plan, task, gate path, and never-edit list).

### T.2 The loop

```
while task := tasks.sh next <slug>        # first in_progress, else first open with deps done
  set status=in_progress → arm gate (autonomous only) → spawn ONE dev → read reply
  → tasks.sh verify → pass: progress line, commit, disarm | fail: fix loop (§T.4)
  → stop when: no ready task | --autonomous off | BLOCKED/ESCALATE with a Tier 3/4 reason
```

Per iteration:

1. **Select.** `TASK_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" next "$SLUG")`; empty → §T.6. A `<task-id>` argument pins `TASK_JSON` to that task and exits after it. A cycle in `depends_on` (Kahn layering never empties while open tasks remain) is a hard failure: print the cycle, `BLOCKED: dependency cycle`, stop.
2. **Mark.** `tasks.sh set "$SLUG" "$ID" status=in_progress`; append `## <ISO> build <ID> start (attempt <attempts+1>)` to `progress.md`; feed `task_start {plan, task}`.
3. **Arm the gate** when `--autonomous` (§Gate).
4. **Spawn one `dev`** with fresh context — `Agent(subagent_type: "blitz:dev", name: "dev-<ID>", model: "sonnet", prompt: <11-item spec>)`. The spec ([agents.md](/_shared/agents.md) §3.1; template in [references/main.md](references/main.md)):

   | # | Item | Source |
   |---|---|---|
   | 1-2 | Task id, title | `tasks[].id`, `.title` |
   | 3 | `ROLE: <role>` + the full text of `skills/build/references/<role>.md` + the T.1 conventions block | `tasks[].role` |
   | 4 | `SCOPE_FILES:` exact `files[]`; edits outside it are `DONE_WITH_CONCERNS` at best, `ESCALATE: scope-expansion-needed` when >3 | `tasks[].files` |
   | 5 | `verify[]` commands verbatim with timeouts | `tasks[].verify` |
   | 6 | Never-edit: `docs/plans/*/tasks.json`, `docs/plans/*/progress.md`, `.cc-sessions/**`, test files unless `role: test`, project additions | this skill |
   | 7 | Reply contract + JSON block ([agents.md](/_shared/agents.md) §4.2) | agents.md |
   | 8 | `BUDGET (Heavy)`: 25 reads, 0 searches, 40 tool calls (finish at 35), 400 lines, 8 min | agents.md §3.3 |
   | 9 | Commit `feat(<slug>/<role>): <ID> <title>` + trailer `Task: <slug>/<ID>`; one commit; `fix(<slug>/<role>): … — during <ID>` for Tier-1 auto-fixes | this skill |
   | 10 | `Output: terse-technical per output.md; fragments OK; preserve code, paths, commands, JSON verbatim.` | output.md |
   | 11 | Stop conditions: reply when `verify[]` passes; `BLOCKED` on any `ESCALATE:`; stop before a new file at ≤3 calls left | agents.md |

   Banned: more than one task per prompt; a prompt without `SCOPE_FILES` or the never-edit list; retrying an identical prompt after `error_max_turns`.
5. **Read the reply.** `jq` it first; unparsable → `MALFORMED`, counts as a failed round with a narrower re-spawn, never the same prompt. Cap interpolated fields at 200 chars and injection-scan them (TB-3). Then by status:

   | Status | Action |
   |---|---|
   | `DONE` | → step 6 |
   | `DONE_WITH_CONCERNS` | → step 6; each concern becomes a `Ruling:` candidate in `progress.md` (`severity: high` → write the ruling now) |
   | `NEEDS_CONTEXT` | answer once via `SendMessage(to: "dev-<ID>")` with the missing fact; no attempt consumed; wait for the next reply |
   | `BLOCKED` | `tasks.sh set … attempts=+1`; map `escalate` to `blocked_reason`; Tier 3/4 reason → §T.5 ruling now; else → §T.4 |

6. **Verify on main.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" "$ID"` — the only path to `status: done`. Pass → append `## <ISO> verify <ID> ok=true`, feed `verification {command: "tasks.sh verify <slug> <ID>", result: pass}`, `task_complete {summary}`; confirm the agent's commit carries the trailer (`git log -1 --grep "Task: $SLUG/$ID"`), else commit its files yourself with the item-9 format. Fail → `set attempts=+1`, append `## <ISO> verify <ID> ok=false failed="<cmd>" tail="<200 chars>"`, → §T.4.
7. **Disarm** the gate (`rm -f "$GATE_DIR/gate.json"`) before the next spawn or any exit.
8. **Continue** while `--autonomous`; otherwise print the task's row (§Report) and stop so the user can review — the next `/blitz:build <slug>` resumes from `tasks.sh next`.

### T.3 What `dev` never does

Edits `tasks.json` (`tasks-guard.sh` denies it) or `progress.md`; reads another task's files; weakens a test; installs a dependency the task did not name; commits with `--no-verify`. Main thread only writes plan state, on the main branch.

### T.4 Fix loop ([agents.md](/_shared/agents.md) §8)

| Round | Who | How |
|---|---|---|
| 1-3 | same `dev-<ID>` (sonnet) | `SendMessage(to: "dev-<ID>", message: "verify item <n> failing: <200-char tail>; fix <file> only")` — state remaining work explicitly, never a bare "continue"; one failing item per message |
| 4-5 | fresh `dev` on opus | new `Agent(subagent_type: "blitz:dev", model: "opus")`, full 11-item spec plus the `progress.md` tail (last 3 verify tails and rulings) |
| after 5 | main thread | adjudicate (§T.5) |

Each round: `set attempts=+1` on failure, re-run `tasks.sh verify`, append the verify line. At `attempts == 3` `tasks.sh set` flips the task to `blocked` with `circuit-breaker`; under `--autonomous` or `next --loop` the loop continues with rounds 4-5 only when `BLITZ_FIX_ROUNDS_MAX` (default 5) allows, else moves to the next ready task. Never retry an unchanged prompt; each round changes at least the evidence tail. Stuck: no reply within 8 min + 30 s → `SendMessage STATUS?`; no answer in 90 s → `MISSING`, treat as `BLOCKED circuit-breaker`.

### T.5 Circuit breaker and rulings

Vocabulary ([loop.md](/_shared/loop.md) §blocked_reason): `hard_spec` · `oracle-underivable` · `test-assertion-suspect` · `scope-expansion-needed` · `circuit-breaker` · `dependency-missing` · `ratchet:<metric>`.

- `scope-expansion-needed`: review the requested file; valid → re-dispatch once with `files` expanded (`tasks.sh set … notes="scope+<path>"`, prompt item 4 widened), invalid → block. Not a loop escalation.
- `dependency-missing`: block until the upstream task is `done`; `next` re-offers it.
- `hard_spec`, `oracle-underivable`, `test-assertion-suspect`: block now; `next --loop` row 1 escalates to a human.
- Round 5 exhausted or Tier 3/4 `ESCALATE:`: `tasks.sh set "$SLUG" "$ID" blocked_reason=<reason>` and append
  `Ruling: <descope|split|spec-defect|defer> — <why> (<ID>, round <n>)` to `progress.md`. `learn` mines these lines. Print `BLOCKED: <slug>/<ID> <reason>` (and `ESCALATE: <line>` when the agent raised one); `PushNotification` if available.

### T.6 Exit

Disarm the gate. Commit plan state (`progress.md`, `tasks.json`) on the main branch: `git add docs/plans/<slug> && git commit -m "chore(<slug>): progress <ID>" -m "Task: <slug>/<ID>"`; under `--autonomous` also push. Patch `working_on: "done: <n>/<total> tasks"`, feed `skill_end`. Then §Report. Nothing ready and nothing blocked → say `Ready: /blitz:check --scope plan <slug> --fix`.

---

## Parallel mode

Only after §0.4 passed. Everything in Task mode still applies per task; what changes is dispatch and merge. Mechanics in [references/main.md](references/main.md) §Wave mechanics.

### P.1 Waves

Kahn layering on `depends_on` over open tasks: wave 0 = no unmet deps; wave N = deps all in waves < N or already `done`. Print the plan (`Wave 0: T-001 T-002 T-008 · Wave 1: T-003 T-004 · critical path T-001 → T-004 → T-005`). Drop from a wave any task whose `files` intersect another task's in the same wave (the later id waits); cap 4 per wave, overflow queues by `schema/type > server > store > component > test`. The layering is a pure function of `tasks.json` — recomputing it after compaction gives the same waves.

### P.2 Dispatch one wave

Mark every task in the wave `in_progress` and append its start line. Then:

- **Workflow path** when the `Workflow` tool is present and `BLITZ_DISPATCH != agent`: call `/blitz:build-wave` with `args: { plan, wave, tasks: [{id, role, prompt}], replySchema }` — `prompt` is the 11-item spec, `replySchema` the §4.2 JSON. It returns `{ wave, tasks: [{id, ok, result}] }`; `result: null` = the agent died → treat as `BLOCKED circuit-breaker`. Any failure (tool absent, not allowed in `-p`, script error) → Agent path, never hard-fail. Feed `task_start.detail.dispatch: "workflow"|"agent"`.
- **Agent path**: one `Agent(subagent_type: "blitz:dev", name: "dev-<ID>", model: "sonnet", isolation: "worktree", prompt: <spec>)` per task, all launched before waiting. Item 9 adds: branch label `build/<slug>/<role>`; commit inside the worktree.

Arm the gate under `--autonomous` with `until: "build <slug> wave <N>"`.

### P.3 Wait

`Monitor(command: "tail -f ${SESSION_TMP_DIR}/wave-<N>.log | grep --line-buffered 'DONE\|BLOCKED\|NEEDS_CONTEXT'", timeout: 1800)` — every watch carries a deadline (30 min max; `timeout: 600` in `-p`), **re-armed at every wave boundary**. On expiry with agents outstanding, poll `ListAgents` every 2-3 turns until the barrier; the Workflow barrier replaces Monitor within a wave. Barrier: no wave N+1 task starts until every wave N agent replied. `NEEDS_CONTEXT` is answered in place; the wave keeps waiting.

### P.4 Sequential merge

In task-id order, on the main branch:

```bash
git merge-tree --write-tree HEAD "$BRANCH" >/dev/null 2>&1 \
  && git merge --no-ff "$BRANCH" -m "feat(<slug>): merge <ID>" -m "Task: <slug>/<ID>" \
  || { bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" set "$SLUG" "$ID" blocked_reason=scope-expansion-needed; echo "Ruling: conflict — <ID> touched files another task changed; re-plan files[] (<ID>, wave <N>)" >> "docs/plans/$SLUG/progress.md"; continue; }
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" "$ID"     # flips done only on main
```

A conflicting branch is never merged and never rebased by `build`; the task stays blocked with a ruling. Verify failures after a clean merge enter §T.4 with the agent resumed by name.

### P.5 Wave end

Append `## <ISO> build wave <N> <done>/<n> done` and the phase one-liner `build wave N/M · k/n done`, feed `task_complete` per merged task, commit `feat(<slug>): wave N` on main, push under `--autonomous`, re-arm Monitor, dispatch the next wave. Peer notice: if a `check` session for this plan is `waiting`, `SendMessage` one line (`build <slug> wave N merged — k/n`).

### P.6 Integration pass (after the last wave, mandatory)

1. `/blitz:check --only wiring` on `git diff --name-only <base>..HEAD` — export→import tracing, route coverage, store wiring. Fix high-severity findings before anything else.
2. Walk the integration checklist ([references/main.md](references/main.md) §Integration checklist): nav entries, design tokens, layout wrapper, state wiring, accessibility, loading/error states, route guards. Fewer than 3 open items → fix inline; more → one `dev` (`ROLE: frontend`, Medium budget, `SCOPE_FILES` = the files named by the findings). Do not skip a half-integration: every item is confirmed done or recorded as a `Ruling:`.
3. Commit `feat(<slug>/integration): wiring pass`.

### P.7 Selective re-verify and fix rounds

Full sweep once (type-check, build, selected tests, lint). Failing → fix rounds ≤5, types first, then imports, then logic, then tests; re-runs use the selective strategy in [references/main.md](references/main.md) §Selective re-verify (tsc and build always full; tests and lint scoped to changed packages/files); the final round gets one full sweep. Commit each round `fix(<slug>): integration round <n>`. Still red after 5 → `BLOCKED: <slug> integration` with the remaining errors listed.

### P.8 Cleanup

Blitz removes nothing. The platform locks a worktree while its agent runs and sweeps unlocked ones by `cleanupPeriodDays`; `/blitz:sessions worktrees` lists what is left. Never delete a worktree that `claude agents --json` still reports.

---

## Gate

Armed only under `--autonomous` or when `next --loop` dispatched this skill (`BLITZ_AUTONOMOUS=1`); interactive runs never write the file. Contract: [loop.md](/_shared/loop.md) §Stop gate.

```bash
GATE_DIR=".cc-sessions/sessions/${CLAUDE_SESSION_ID}"; mkdir -p "$GATE_DIR"
SELECTED=$("${CLAUDE_PLUGIN_ROOT}/scripts/test-selector.sh" --base "${BLITZ_BASE:-origin/main}" 2>/dev/null | cut -f1 | tr '\n' ' ')
jq -n --arg sel "$SELECTED" --arg until "build ${SLUG} ${ID}" '{
  checks: [
    {name: "tsc",   cmd: "npx tsc --noEmit --pretty false", timeout: 180},
    {name: "tests", cmd: ("npx vitest run --reporter=dot " + $sel), timeout: 300}
  ], blocks: 0, max_blocks: 6, until: $until }' > "$GATE_DIR/gate.json"
```

Skip the `tests` check when the selector returns nothing. The hook stands down on `LOOP_DONE`, `LOOP_ESCALATE`, `LOOP_DEFER`, `BLOCKED:`, `ESCALATE:`. **Disarm (`rm -f "$GATE_DIR/gate.json"`) after every `tasks.sh verify`, before every marker, and on every early exit** — a leftover gate blocks the next unrelated turn until `max_blocks`. Never wire a prompt-type Stop hook; a user `/goal` is one already.

---

## Recovery

STATE.md no longer exists. After a crash, `--resume`, or compaction: `tasks.sh list <slug>` + the `progress.md` tail + `git log --grep 'Task: <slug>/'` are the whole truth. A task `in_progress` with a trailer commit but `passes: false` → run `tasks.sh verify` before anything else; `in_progress` with no commit → its agent is gone, re-spawn (attempts already recorded). Never reconstruct state from recollection; never edit `tasks.json` by hand to "fix" it.

---

## Report

Print once per invocation (and per task boundary when not autonomous):

```
build <slug> — <mode> · <done>/<total> done · <blocked> blocked
| Task | Status | Attempts | Last verify |
|---|---|---|---|
| T-001 | done | 1 | ok 14:19 |
| T-003 | blocked circuit-breaker | 3 | FAIL vitest src/x.test.ts :: <tail ≤80> |
Next: /blitz:build <slug> | /blitz:check --scope plan <slug> --fix | Ready: …
```

Last line is a marker when applicable: `BLOCKED: <slug>/<ID> <reason>` for every blocked task this run, `ESCALATE: <line>` when an agent raised one, `LOOP_DEFER` on a conflict. Gate disarmed before the marker.
