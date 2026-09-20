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
Each protocol is a small contract file plus a reference loaded on demand. Read the contract; open the reference only for the row you need.

- Task file schema, `blocked_reason` vocabulary, structural rules: [loop.md](/_shared/loop.md) · gate arming, markers, `progress.md` ledger format: [loop.reference.md](/_shared/loop.reference.md)
- `dev` roster entry, model routing, when to spawn: [agents.md](/_shared/agents.md) · 11-item spawn spec, reply status enum, fix loop, deviation tiers, worktree platform facts, `--parallel` preconditions, `Workflow` contract: [agents.reference.md](/_shared/agents.reference.md)
- Structural done, the three verdicts: [quality.md](/_shared/quality.md) §Structural done · Definition of Done, anti-mock rows, ratchet: [quality.reference.md](/_shared/quality.reference.md)
- Session claim, conflict matrix: [sessions.md](/_shared/sessions.md) · feed schema, HANDOFF.json, mailbox: [sessions.reference.md](/_shared/sessions.reference.md)
- Trust boundaries, kill switch: [security.md](/_shared/security.md) · package install policy, TB-3 reply handling in full: [security.reference.md](/_shared/security.reference.md)
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
3. No new dependency, no new directory, no schema/auth/env change (Tier 4 in [agents.reference.md](/_shared/agents.reference.md) §9).

### 0.4 Parallel preconditions ([agents.reference.md](/_shared/agents.reference.md) §5.2)

Fall back to sequential, printing the reason, unless all hold: `worktree.baseRef: "head"`; no stale agent branch ahead of `origin/HEAD`; no `WorktreeCreate` hook in project settings; ≥3 open ready tasks with pairwise-disjoint `files`; no other live session on the plan; `--parallel` passed. Cap 4 per wave. Checks: [references/main.md](references/main.md) §0.4 Parallel preconditions.

## Inline mode

No plan, no agents: do the work on the main thread. Entry conditions are in Phase 0; the full I.0–I.4 procedure, including `--issue N` handling, is in [references/main.md](references/main.md) §Inline mode.

## Task mode

### T.1 Baseline and conventions (once per invocation)

Read once per invocation, not per task: stack profile, test command, never-edit additions. Commands: [references/main.md](references/main.md) §T.1 Baseline and conventions.

### T.2 The loop

One `dev` per open task in dependency order, fresh context each time, `tasks.sh verify` on the main thread between tasks. Dispatch, fix rounds, deviation handling and the per-task ledger writes: [references/main.md](references/main.md) §T.2 The loop.

### T.3 What `dev` never does

Edits `tasks.json` (`tasks-guard.sh` denies it) or `progress.md`; reads another task's files; weakens a test; installs a dependency the task did not name; commits with `--no-verify`. Main thread only writes plan state, on the main branch.

### T.4 Fix loop ([agents.reference.md](/_shared/agents.reference.md) §8)

Rounds 1–3 resume the same `dev` by name; 4–5 spawn fresh on opus; adjudicate at 5 with a `Ruling:` in `progress.md`. Round table and resume payload: [references/main.md](references/main.md) §T.4 Fix loop.

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

Armed only under `--autonomous` or when `next --loop` dispatched this skill (`BLITZ_AUTONOMOUS=1`); interactive runs never write the file. Contract: [loop.reference.md](/_shared/loop.reference.md) §Stop gate.

```bash
GATE_DIR=".cc-sessions/sessions/${CLAUDE_SESSION_ID}"; mkdir -p "$GATE_DIR"
SELECTED=$("${CLAUDE_PLUGIN_ROOT}/scripts/test-selector.sh" --base "${BLITZ_BASE:-origin/main}" 2>/dev/null | cut -f1 | tr '\n' ' ')
jq -n --arg sel "$SELECTED" --arg until "build ${SLUG} ${ID}" '{
  checks: [
    {name: "tsc",   cmd: "npx tsc --noEmit --pretty false", timeout: 180},
    {name: "tests", cmd: ("npx vitest run --reporter=dot " + $sel), timeout: 300}
  ], blocks: 0, max_blocks: 4, until: $until }' > "$GATE_DIR/gate.json"
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
