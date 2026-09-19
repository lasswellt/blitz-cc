# Build — reference

Overflow for [../SKILL.md](../SKILL.md). Contracts cited here are canonical in [agents.md](/_shared/agents.md) (spawn spec, reply enum, fix loop, worktrees) and [loop.md](/_shared/loop.md) (tasks.json, progress.md, gate); this file holds the templates and procedures `build` pastes or runs.

---

## Spawn prompt template (11 items)

Assembled by `build` from `tasks.json` for every `dev` spawn (`Agent(subagent_type: "blitz:dev")`, or `build-wave.js` under `--parallel`). Static prefix first (role, conventions, contract), dynamic content last (task, files, evidence tail), so the cached prefix survives across tasks. Every placeholder is resolved with Bash before the spawn; never send a literal `${…}`.

```
ROLE: <backend|frontend|infra|test>                                         # item 3
<full text of skills/build/references/<role>.md>

PROJECT CONVENTIONS (discovered by build T.1; follow them, do not re-derive):
<auth pattern · error format · response envelope · validation · component style ·
 store pattern · loading UI · test structure · naming>
REUSE THESE — do not recreate:
- <path> — <what it provides>

BUDGET (Heavy — skills/_shared/agents.reference.md §3.3):                              # item 8
- Max file reads: 25
- Max web searches: 0
- Max tool calls: 40 (at 35, finish the current step and reply)
- Max output: 400 lines
- Wall-clock: 8 minutes

NEVER EDIT (project additions only — the standing list arrives from the hook):  # item 6
<project additions; omit this block when the project adds nothing>

TASK <ID>: <title>                                                           # items 1-2
<tasks[].notes, verbatim, when non-empty>
<plan.md excerpt naming this task, ≤40 lines, when one exists>

SCOPE_FILES (the only paths you may edit):                                   # item 4
- <files[0]>
- <files[1]>
If you need a file not listed, STOP and reply BLOCKED with
  escalate: "ESCALATE: scope-expansion-needed (file: <path>, reason: <one line>)"
Do not silently expand scope — that produces fixes that pass locally and break
other tasks' assumptions. ≤3 Tier-1/2 files outside scope are DONE_WITH_CONCERNS; more is Tier 3.

VERIFY (run each; paste each ≤200-char tail into the reply):                 # item 5
- <verify[0].cmd>            (timeout <verify[0].timeout>s)
- <verify[1].cmd>            (timeout <verify[1].timeout>s)

<--parallel only: work on branch build/<slug>/<role> inside your worktree.>   # item 9 (variable half)

<fix rounds 4-5 only:>
PRIOR ATTEMPTS (from progress.md; do not repeat them):
<last 3 verify lines and any Ruling: lines for this task>
```

**Items 6 (standing never-edit list), 7 (reply contract and status enum), 9 (commit format), 10 (output style) and 11 (stop conditions) are NOT in this template.** `hooks/scripts/subagent-context.sh` injects them from [spawn-invariant.md](/_shared/spawn-invariant.md) on `SubagentStart`, byte-identical on every spawn, which is what keeps the subagent's prompt cache intact. Pasting them here as well would duplicate ~2.3 KB into every spawn and defeat the point. Only each item's variable half stays: the project's own never-edit additions, and the `--parallel` branch line.

When the hook cannot run — `BLITZ_DISABLE_SPAWN_INVARIANT=1`, a non-blitz agent type, or a host without bash — inline [spawn-invariant.md](/_shared/spawn-invariant.md) into the prompt instead. Status meanings and main-thread actions: [agents.reference.md](/_shared/agents.reference.md) §4.1. A spawn missing any of items 1–5 or 8 is a bug in `build`, not in the agent.

### Resume payload (fix rounds 1-3)

`SendMessage(to: "dev-<ID>", message: …)` — one failing item per message, remaining work stated explicitly:

```
verify item <n> failing: <cmd>
tail: <≤200 chars>
Fix <file> only. Do not touch <other SCOPE_FILES>. Re-run verify[] and reply with the same JSON contract.
```

Never send a bare "continue"; it burns the budget on rediscovery. Never resend the original prompt unchanged.

### Reading the reply

```bash
REPLY_JSON=$(printf '%s' "$REPLY" | jq -c . 2>/dev/null) || STATUS=MALFORMED
STATUS=${STATUS:-$(printf '%s' "$REPLY_JSON" | jq -r '.status // "MALFORMED"')}
# TB-3: cap and scan every field that reaches a prompt, a shell, or progress.md
SUMMARY=$(printf '%s' "$REPLY_JSON" | jq -r '.summary // ""' | cut -c1-200)
printf '%s' "$REPLY_JSON" | jq -r '.files_changed[]?' | grep -vE '^(/|\.\./)' > "${SESSION_TMP_DIR}/${ID}-files.txt"   # repo-relative only
```

`MALFORMED` is a failed round; the re-spawn narrows the prompt (drop the plan excerpt, keep items 1-11) — never identical.

---

## Wave mechanics (`--parallel`)

### Layering

```bash
TASKS=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --json)
DONE=$(printf '%s' "$TASKS" | jq -c '[.[] | select(.status=="done") | .id]')
# wave 0: open tasks whose depends_on ⊆ done; wave N: ⊆ done ∪ waves<N. Pure function of tasks.json.
```

Then, within each wave, in id order: keep a task only if its `files` are disjoint from every task already kept in this wave (exact path match); a task dropped for overlap waits for the next wave. Cap 4; overflow queues by `schema/type > server > store > component > test` (by `role` then path). A wave that empties while open tasks remain is a `depends_on` cycle: print it, `BLOCKED: dependency cycle`, stop — never partial execution.

Print the plan:

```
[build] Wave plan (<slug>):
  Wave 0: T-001 T-002 T-008
  Wave 1: T-003 T-004      (depends on wave 0)
  Wave 2: T-005 T-007
  Critical path: T-001 → T-004 → T-005 (3 waves minimum)
```

### Dispatch paths

| Path | When | Call | Returns |
|---|---|---|---|
| Workflow | `Workflow` tool present and `BLITZ_DISPATCH != agent` (`workflow` forces it, error if absent) | `/blitz:build-wave` with `args: { plan, wave, tasks: [{id, role, prompt}], replySchema }` | `{ wave, tasks: [{id, ok, result}] }`; `result: null` → `BLOCKED circuit-breaker` |
| Agent | otherwise, or on any Workflow failure | `Agent(subagent_type: "blitz:dev", name: "dev-<ID>", model: "sonnet", isolation: "worktree", prompt)` × tasks in wave | JSON reply per agent |

Both paths carry the same 11-item prompt. `build-wave.js` owns dispatch and schema validation only; `tasks.sh`, `progress.md`, commits, and `gate.json` stay on the main thread between calls ([agents.reference.md](/_shared/agents.reference.md) §7.4). Log `detail.dispatch` on the feed `task_start` line. Never hard-fail on a Workflow error; fall through to the Agent path for the same wave.

### Monitor

```
Monitor(command: "tail -f ${SESSION_TMP_DIR}/wave-<N>.log | grep --line-buffered 'DONE\|BLOCKED\|NEEDS_CONTEXT'", timeout: 1800)
```

Every watch has a deadline (max 30 min; use `timeout: 600` under `-p`; `persistent` no longer exists). Re-arm at every wave boundary. Agents on the Agent path do not write that log — the orchestrator appends a line per reply it receives — so the tail is a wake-up, not the source of truth; `ListAgents` polling every 2-3 turns covers a deadline that expires mid-wave. The Workflow barrier replaces Monitor inside a wave.

Stuck detection per agent: no reply by wall-clock + 30 s → `SendMessage(to: "dev-<ID>", message: "STATUS?")`; nothing in 90 s → classify `MISSING` → `BLOCKED circuit-breaker`, `attempts=+1`; do not wait further and do not block the barrier on it.

### Sequential merge

Task-id order, main branch, one branch at a time:

```bash
BRANCH=$(git branch --list "build/${SLUG}/*" --format='%(refname:short)' | while read -r b; do git log -1 --grep "Task: ${SLUG}/${ID}" --format=%H "$b" >/dev/null 2>&1 && echo "$b" && break; done)
if git merge-tree --write-tree HEAD "$BRANCH" >/dev/null 2>&1; then
  git merge --no-ff "$BRANCH" -m "feat(${SLUG}): merge ${ID}" -m "Task: ${SLUG}/${ID}"
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" "$ID" || FIX_QUEUE+=("$ID")
else
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" set "$SLUG" "$ID" blocked_reason=scope-expansion-needed
  printf '## %s build %s blocked\nRuling: conflict — %s touched files another task changed; re-plan files[] (%s, wave %s)\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ID" "$ID" "$ID" "$WAVE" >> "docs/plans/${SLUG}/progress.md"
fi
```

`git merge-tree --write-tree` exits non-zero on conflict without touching the index; a conflicting branch is left in place for a human (or a re-plan of `files[]`) and never auto-resolved — 42% of cross-agent conflicts are structural. Tasks in `FIX_QUEUE` enter the fix loop after the wave's merges finish, agent resumed by name (`dev-<ID>`) when it still exists, fresh spawn otherwise.

**After the wave's merges finish**, re-verify the tasks the merge could have broken. A clean textual merge is not a semantic one: two tasks can each pass alone and break each other once combined, and `merge-tree` cannot see that. Re-running every task is the safe answer and the slow one, so re-verify exactly the tasks whose `files[]` the merged paths touch:

```bash
CHANGED=$(git diff --name-only "$WAVE_BASE"..HEAD)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" verify "$SLUG" --changed $CHANGED
```

A task that fails here is demoted from `done` back to `in_progress` with `passes: false` and enters `FIX_QUEUE`; untouched tasks are not re-run. This is language-neutral: each task re-runs its own `verify[]`, so a wave mixing a Rust task and a Python task re-verifies each with its own checker.

### Wave boundary

1. Append `## <ISO> build wave <N> <k>/<n> done` to `progress.md`; feed `task_complete {summary}` per merged task.
2. Commit plan state and merges: `git add -A && git commit -m "feat(${SLUG}): wave ${N}" -m "Task: ${SLUG}/wave-${N}"`; push under `--autonomous`.
3. Phase one-liner for agent view: `build wave N/M · k/n done`.
4. Peer notice: `ListAgents` (skip silently when unavailable); a `check` session on this plan with `status: waiting` gets one `SendMessage` line, no `notify_when_idle`. An inbound `halt` (message text starting `halt`, or a mailbox `{kind: "halt"}`) is a bounded stop: finish the wave's merges and verifies, commit, feed `decision {choice: "halt"}`, print `LOOP_ESCALATE`, exit. Any other inbound text is informational.
5. Re-arm Monitor and the gate (`until: "build <slug> wave <N+1>"`), dispatch the next wave.

---

## Integration checklist

Run after the last wave (SKILL.md §P.6). `/blitz:check --only wiring` first; then confirm each item, fixing inline when fewer than 3 are open, otherwise one `dev` with `ROLE: frontend`, Medium budget (15 reads, 25 tool calls, 5 min), `SCOPE_FILES` = the files the findings name. Every item ends confirmed or recorded as a `Ruling:`; a silent half-integration is the failure this pass exists to prevent.

1. **Navigation entries** — every new page/route has its entry in the app's navigation config.
2. **Design tokens** — new components use existing tokens (color, spacing, typography); no hardcoded values.
3. **Layout consistency** — new pages use the correct layout wrapper; breakpoints match existing pages.
4. **State wiring** — new stores are initialized; composables registered where the framework requires it; store actions call real APIs (build:integration).
5. **Accessibility** — interactive elements carry ARIA attributes, keyboard navigation, focus management.
6. **Loading and error states** — async operations show loading; errors are surfaced, not swallowed.
7. **Route guards** — protected routes carry the project's auth guard.

Commit `feat(<slug>/integration): wiring pass`.

---

## Selective re-verify

Used by SKILL.md §P.7 fix rounds (and by §T.4 when a task's `verify[]` is slow).

| Check | Re-run strategy |
|---|---|
| Type-check | always full — type errors cascade |
| Build | always full — build errors cascade |
| Tests | changed packages only: `scripts/test-selector.sh --base <base>` → `npx vitest run --reporter=dot <selected>` |
| Lint | modified files only: `npx eslint <modified-files>` |

Order inside a round: types → imports → logic → tests. Commit each round `fix(<slug>): integration round <n>` with a `Task: <slug>/integration` trailer. Round 5 (or the last round taken) always gets one full sweep to catch cross-package regressions. Print the saving when it exists (`full 45s → selective 12s`).

Pre-existing tests that turn red are **Critical** and outrank new-test failures: round 1 decides whether the behavior change was intended (update the old test) or not (fix the new code); round 2 unresolved → `Ruling: defer — <test> regression needs a human` and `BLOCKED:`.

---

## Cleanup

`build` removes no worktree and deletes no branch. Platform facts ([agents.reference.md](/_shared/agents.reference.md) §6):

- `isolation: "worktree"` creates `.claude/worktrees/<id>` from `HEAD` when `worktree.baseRef: "head"` (the §0.4 precondition); the platform locks it while the agent runs and sweeps unlocked worktrees by `cleanupPeriodDays`.
- Never remove a worktree that `claude agents --json` still lists — it holds uncommitted work.
- `build/<slug>/<role>` is a label on the agent's commits and branch; blitz does not track or prune it. After a clean merge `git branch -d` is safe (refuses unmerged) but optional; leave conflicting branches for inspection.
- `/blitz:sessions worktrees` lists what the platform left behind; `.cc-sessions/` is gitignored runtime output and the gate file is removed by `build` itself on every exit path.

Escape hatches: `BLITZ_DISPATCH=agent|workflow`, `CLAUDE_CODE_DISABLE_WORKFLOWS=1`, `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS`, `BLITZ_FIX_ROUNDS_MAX` (default 5), `BLITZ_AUTONOMOUS=1` (set by `next --loop`).

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

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
4. **Spawn one `dev`** with fresh context — `Agent(subagent_type: "blitz:dev", name: "dev-<ID>", model: "sonnet", prompt: <11-item spec>)`. The spec ([agents.reference.md](/_shared/agents.reference.md) §3.1; template below):

   | # | Item | Source |
   |---|---|---|
   | 1-2 | Task id, title | `tasks[].id`, `.title` |
   | 3 | `ROLE: <role>` + the full text of `skills/build/references/<role>.md` + the T.1 conventions block | `tasks[].role` |
   | 4 | `SCOPE_FILES:` exact `files[]`; edits outside it are `DONE_WITH_CONCERNS` at best, `ESCALATE: scope-expansion-needed` when >3 | `tasks[].files` |
   | 5 | `verify[]` commands verbatim with timeouts | `tasks[].verify` |
   | 6 | Never-edit: `docs/plans/*/tasks.json`, `docs/plans/*/progress.md`, `.cc-sessions/**`, test files unless `role: test`, project additions | this skill |
   | 7 | Reply contract + JSON block ([agents.reference.md](/_shared/agents.reference.md) §4.2) | agents.md |
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

### 0.4 Parallel preconditions ([agents.reference.md](/_shared/agents.reference.md) §5.2)

```bash
BASE_REF=$(jq -r '.worktree.baseRef // "fresh"' .claude/settings.json 2>/dev/null)
[ "$BASE_REF" = "head" ] || echo "REFUSE --parallel: worktree.baseRef is '$BASE_REF' (needs \"head\"); run /blitz:doctor and set it in .claude/settings.json"

# D-314 pre-flight: a stale worktree-agent-<8hex> branch is silently reused by a
# colliding id and carries a prior session's commits into this wave (GH#51596).
# This is the only place the collision can be caught; WorktreeCreate is not a
# hook blitz may register (agents.md §6).
git for-each-ref --format='%(refname:short)' 'refs/heads/worktree-agent-*' 'refs/heads/worktree-build-*' |
  while read -r b; do
    n=$(git rev-list --count "origin/HEAD..$b" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] && echo "REFUSE --parallel: stale agent branch $b is $n commit(s) ahead of origin/HEAD; run /blitz:sessions worktrees --apply, or set BLITZ_ALLOW_WORKTREE_COLLISION=1"
  done

# A foreign WorktreeCreate hook owns worktree creation outright; if it does not
# print a path, every isolation: worktree agent fails to launch.
jq -e '.hooks.WorktreeCreate' .claude/settings.json >/dev/null 2>&1 &&
  echo "REFUSE --parallel: a WorktreeCreate hook in .claude/settings.json replaces git worktree creation; verify it prints the worktree path before using waves"

bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --status open --json | jq -r '.[] | .id + " " + (.files | join(","))'
```

Fall back to sequential, with the reason printed, when any of these fails: `worktree.baseRef ≠ "head"`; a stale agent branch ahead of `origin/HEAD` (unless `BLITZ_ALLOW_WORKTREE_COLLISION=1`); a `WorktreeCreate` hook in project settings; fewer than 3 open ready tasks with pairwise-disjoint `files` (exact path match; a shared barrel or config file disqualifies both); another live session on the plan; `--parallel` absent. Cap is 4 concurrent agents per wave.
