# Loop Protocol

The blitz loop is `research → plan → build → check → ship`, with `learn` feeding `docs/solutions/` back into `plan`. `ship` is slash-only and never dispatched automatically.
`/blitz:next --loop` is the autonomous entry point: one tick reads `docs/plans/*/tasks.json` and `.cc-sessions/inbox.jsonl`, reconciles them, dispatches at most one task-sized unit of work, commits, and exits so the scheduler can re-tick.
State lives in tracked files (`tasks.json`, `progress.md`) and git, never in the conversation; a fresh session per tick is the preferred runtime.
"Done" is structural: a task is `done` only when `scripts/tasks.sh verify` has recorded passing evidence, and a hook denies every other writer of `tasks.json`.
Siblings: [sessions.md](/_shared/sessions.md), [agents.md](/_shared/agents.md), [quality.md](/_shared/quality.md), [security.md](/_shared/security.md), [output.md](/_shared/output.md).

---

## Artifacts

| Path | Writer | Readers | Tracked |
|---|---|---|---|
| `docs/plans/<slug>/spec.md` | `plan` (`audit` for `audit-<date>` plans, paused); `next --loop` flips `status` | `build`, `check`, `next`, `ship`, `learn` | tracked |
| `docs/plans/<slug>/plan.md` | `plan` | `build`, `check`, `critic` | tracked |
| `docs/plans/<slug>/tasks.json` | **`scripts/tasks.sh` only** (called by `plan`, `build`, `check`, `audit`, `next`) | `next-state.sh`, `build`, `check`, `critic`, `learn`, `startup-validate.sh` | tracked |
| `docs/plans/<slug>/progress.md` | `build` (task boundaries), `check`, `next --loop` (rulings), main thread only | `build` (recovery map), `learn`, humans | tracked |
| `docs/plans/<slug>/check-report.md` | `check` | `next-state.sh` (row 3/4 freshness), `ship`, `learn` | tracked |
| `docs/plans/archive/<date>-<slug>/` | `ship` or `learn` (move on done) | `learn`, humans | tracked |
| `docs/plans/BACKLOG.md` | `todo` | `plan` | tracked |
| `docs/solutions/<slug>.md` | `learn` (idempotent); frontmatter `{tags, stack, files, symptoms}` | `plan` (cap 5), `startup-validate.sh` | tracked |
| `.cc-sessions/sessions/<sid>/gate.json` | the arming skill (`build`, `check --fix`, `next --loop`) | `stop-gate.sh` | runtime |
| `.cc-sessions/HANDOFF.json` | `pre-compact-snapshot.sh` (plan, task, gate path, never-edit list) | the session after compaction | runtime |
| `.cc-sessions/inbox.jsonl` | hooks (`notification-log`, `permission-denied`, `startup-validate`, `worktree-create`, `stop-failure`), skills via `blitz_inbox_append` | `next` triage, `sessions attention` | runtime |
| `.cc-sessions/STOP` | a human (`touch`) | `kill-switch.sh` (PreToolUse `*`) | runtime |

`tasks.json` and `docs/solutions/` are persistent memory that drives later work; they get provenance (`origin`), a startup shape/injection scan, and quarantine ([security.md](/_shared/security.md)).

---

## Schemas

### tasks.json

Top level: `"$schema": "blitz-tasks/1.0"`, `plan` (slug), `updated` (ISO-8601), `tasks[]`.

```jsonc
{ "id": "T-003", "title": "...", "role": "backend|frontend|infra|test", "files": ["src/..."],
  "depends_on": ["T-001"],
  "verify": [{ "cmd": "npx vitest run src/x.test.ts --reporter=dot", "timeout": 300 },
             { "cmd": "! grep -nE 'TODO|return \\{\\}' src/x.ts", "timeout": 10 }],
  "passes": false, "status": "open|in_progress|done|blocked",
  "blocked_reason": null,   // hard_spec|oracle-underivable|test-assertion-suspect|scope-expansion-needed|circuit-breaker|dependency-missing|ratchet:<metric>
  "attempts": 0, "last_verify": {"ts":"","ok":false,"failed":"","tail":""},
  "origin": "plan|audit|check|learn|issue:<n>", "notes": "" }
```

| Field | Notes |
|---|---|
| `files` | the only paths a `dev` may touch for this task; disjointness gates `build --parallel` |
| `verify[]` | executable checks; `timeout` in seconds; `tasks.sh verify` runs them in order and stops at the first failure |
| `passes` | written only by `tasks.sh verify`; mirrors `last_verify.ok` |
| `last_verify.tail` | ≤200 chars of the failing command's output (evidence, not a summary) |
| `blocked_reason` | see the vocabulary below; `ratchet:<metric>` names the quality metric that regressed |
| `origin` | provenance: `plan`, `audit`, `check`, `learn`, or `issue:<n>`; `tasks.sh add` and `startup-validate.sh` reject anything else |

### `blocked_reason` vocabulary

| Value | Set when | Routed by |
|---|---|---|
| `hard_spec` | test-writer classified the spec HARD_SPEC and the per-task budget is exhausted | `next` row 1 → `LOOP_ESCALATE` |
| `oracle-underivable` | expected output cannot be derived (assertions opaque) | `next` row 1 → `LOOP_ESCALATE` |
| `test-assertion-suspect` | the agent replied `ESCALATE:` because the test itself looks wrong | `next` row 1 → `LOOP_ESCALATE` (operator reviews the test) |
| `scope-expansion-needed` | the agent needs a file outside `files` | `build` re-dispatches with expanded `files` (not a loop escalation) |
| `circuit-breaker` | third failed attempt with no specific classifier | `check` surfaces it; the loop continues with the next task |
| `dependency-missing` | an upstream task did not deliver the expected exports | blocked until the dependency is `done` |
| `ratchet:<metric>` | the task's diff regressed a ratchet metric | `check --fix`, then `build` |

### spec.md frontmatter

```yaml
---
status: active      # active | paused | done
priority: P1        # P0 | P1 | P2 (next-state.sh sorts P0 first, then created, then slug; a bare integer is also accepted)
created: 2026-09-19
ship: manual        # auto | manual — auto lets ship run without a confirmation prompt; the loop still never dispatches ship
---
```

### progress.md

Append-only ledger; `build`, `check`, and `next --loop` append, nobody rewrites.

```
## 2026-09-19T14:02:11Z build T-003 start (attempt 2)
## 2026-09-19T14:19:40Z verify T-003 ok=false failed="npx vitest run src/x.test.ts" tail="…"
## 2026-09-19T14:20:02Z build T-003 blocked
Ruling: blocked circuit-breaker — three attempts failed on the same assertion; needs a human oracle
## 2026-09-19T15:00:00Z check PASS check-report.md
```

`## <ISO-8601> <event>` opens every entry; `Ruling: <decision> — <why>` lines record non-trivial choices and are what `learn` mines.

### Commit trailer

Every commit made for a task carries `Task: <slug>/T-003`. `learn` runs `git log --grep 'Task:'` to attribute changes; `check --scope plan` uses it to bound the diff.

---

## Structural rules

Hook- or script-enforced; prose alone is not a control.

| Rule | Enforced by |
|---|---|
| `verify[]` non-empty; behavior tasks carry at least one non-test check (grep, shell, e2e) beside the test command | `plan` rejects the task; `tasks.sh add` refuses an empty list; `startup-validate.sh` flags it |
| Only `scripts/tasks.sh` writes `tasks.json` | `tasks-guard.sh` (PreToolUse) denies `Edit`/`Write` on `docs/plans/*/tasks.json` |
| `status: done` ⇒ `passes == true` ∧ `last_verify.ok == true` | `tasks.sh set … status=done` refuses otherwise; `tasks.sh verify` is the only path that flips `passes` |
| Main thread only: `tasks.json` and `progress.md` are on every dev agent's never-edit list; `build` writes them at task boundaries on the main branch | `dev` frontmatter + `pre-edit-guard.sh`; `pre-compact-snapshot.sh` carries the never-edit list through compaction |
| `attempts` increments per failed build attempt; `blocked` at 3 or on `ESCALATE:` | `build` via `tasks.sh set … attempts=+1`; the breaker is skipped when the same call sets `status` or `blocked_reason` explicitly (the unblock recipe is `set … status=open attempts=0`) |
| Fix rounds ≤3 on the same `dev` (sonnet); rounds 4–5 spawn a fresh `dev` on opus; round 5 adjudicates to `blocked` with a `Ruling:` | `build` |
| Kill switch: while `.cc-sessions/STOP` exists every tool call is denied | `kill-switch.sh` (PreToolUse `*`) |
| `tasks.json` and `docs/solutions/*.md` are scanned at startup (shape, ids, injection, quarantine) | `startup-validate.sh` |
| Parallel builds are opt-in: sequential `dev` per task by default; `--parallel` only when ≥3 open tasks have disjoint `files`, cap 4, worktree isolation, sequential merge behind `git merge-tree` | `build`; see [agents.md](/_shared/agents.md) |
| `next --loop` never dispatches `ship` (`disable-model-invocation: true`) | platform |

---

## Scripts

### `scripts/tasks.sh`

Atomic (write to temp, `mv`). Exit 0 ok, 1 verify failed, 2 usage or contract error, 3 plan or task not found. Timeouts ride on the command as `cmd::<seconds>` (default 120). `BLITZ_PLANS_DIR` overrides `docs/plans`.

| Command | Effect |
|---|---|
| `tasks.sh init <plan>` | creates an empty `tasks.json` (`blitz-tasks/1.0`) for the slug |
| `tasks.sh list <plan> [--status s] [--json]` | prints tasks (id, status, pass/fail, attempts, title), filtered by status when given; `--json` prints the array |
| `tasks.sh add <plan> --id T-004 --title "…" --files a.ts,b.ts --verify-cmd "<cmd>[::<seconds>]" [--verify-cmd …] [--depends T-001,T-002] [--role r] [--origin o] [--notes …] [--test-only-ok]` | appends a task; refuses an empty `verify[]`, a duplicate id, a bad role or origin, and a test-only `verify[]` without `--test-only-ok` |
| `tasks.sh set <plan> <id> key=value …` | updates `status`, `blocked_reason`, `notes`, `title`, `role`, `attempts=N` or `attempts=+1`; refuses `status=done` unless `passes ∧ last_verify.ok`; refuses `passes` and `last_verify`; bumps `updated` |
| `tasks.sh verify <plan> <id> [--dry]` | runs `verify[]` in order under each timeout; writes `passes` and `last_verify {ts, ok, failed, tail}`; flips `status` to `done` on pass and back to `in_progress` when a previously done task fails; exit 0 when all pass, 1 otherwise |
| `tasks.sh next <plan>` | prints the first `in_progress` task, else the first `open` task whose `depends_on` are all `done`, as one JSON object; empty when none |

`<plan>` is the slug (`docs/plans/<slug>/tasks.json`). Everything else — skills, `critic`, `check`, humans — goes through this script.

### `scripts/next-state.sh`

Prints one JSON object and exits 0; no side effects.

```json
{ "row": 2, "reason": "open work in <slug>",
  "active_plan": "<slug>|null", "plan_priority": 1,
  "next_task": {"id":"T-003","title":"…","role":"backend","files":[…],"verify":[…],"attempts":0},
  "in_progress": ["T-003"],
  "blocked": [{"plan":"<slug>","id":"T-002","reason":"hard_spec"}],
  "escalate": [{"plan":"<slug>","id":"T-002","reason":"hard_spec"}],
  "paused_plans": ["audit-2026-09-19"], "done_plans_unarchived": [],
  "check_stale": true, "check_result": "none",
  "inbox_pending": 0, "sessions_waiting": 0, "kill_switch": false }
```

Flags: `--plans-dir <dir>`, `--sessions-dir <dir>`, `--no-agent-view` (skip `claude agents --json`; bats and CI use it).

| Field | Meaning |
|---|---|
| `row`, `reason` | the lowest matching row (table below) and why |
| `active_plan`, `plan_priority` | first `spec.md` with `status: active` (by `priority`, then `created`, then slug); priority is `null` on rows 0, 1, 5 |
| `next_task` | first `in_progress` task, else first `open` task whose `depends_on` are all `done`, as an object; `null` off row 2 |
| `in_progress` | ids in progress in the active plan |
| `blocked`, `escalate` | every `blocked` task across active plans with its reason; `escalate` is the subset whose reason needs a human |
| `paused_plans`, `done_plans_unarchived` | plans `next` skips (`audit` output stays paused until a human activates it); done plans still under `docs/plans/` |
| `check_stale`, `check_result` | no `check-report.md` with PASS at or after the last task change; the report's `result` or `none` |
| `inbox_pending` | pending `inbox.jsonl` lines after triage |
| `sessions_waiting` | live session records with `waitingFor ≠ null` ([sessions.md](/_shared/sessions.md)) |
| `kill_switch` | `.cc-sessions/STOP` exists |

---

## Stop gate

`hooks/scripts/stop-gate.sh` (Stop event) is a strict no-op unless the session has written `.cc-sessions/sessions/<sid>/gate.json`:

```json
{ "checks": [ {"name": "tsc", "cmd": "npx tsc --noEmit", "timeout": 120} ],
  "blocks": 0, "max_blocks": 4, "until": "<phase label>" }
```

`last_failed` is hook-owned: `stop-gate.sh` writes the failing check's name and tail on a block and clears it on pass.

Armed, every check runs in order; the first failure blocks the turn from ending (exit 2, reason plus a 200-char output tail on stderr) and increments `blocks`. When every check passes, `blocks` resets to 0 and the turn ends. The gate stands down (exit 0) when no gate file exists, stdin `stop_hook_active` is true, `last_assistant_message` carries a terminal marker (`LOOP_DONE | LOOP_ESCALATE | LOOP_DEFER | BLOCKED: | ESCALATE:`), or `blocks ≥ max_blocks` (logged `gate_exhausted`). `max_blocks` defaults to 4: the platform stops honoring Stop-hook blocks after 5 in a row (`stopHookBlockCap`, `CLAUDE_STOP_HOOK_BLOCK_CAP`), and a user `/goal` shares that count, so the gate always exhausts first and logs it.

### Arming table

| Skill | Arms | `until` | Disarm |
|---|---|---|---|
| `build` (autonomous or under `next --loop`) | `tsc` + selected tests from `scripts/test-selector.sh` (skip `tests` when the selector returns nothing) | `build <slug> T-nnn` | after `tasks.sh verify`, before the status enum reply and on every early exit |
| `check --fix` | `tsc` + lint | `check <slug> fix` | before writing `check-report.md` |
| `next --loop` | per dispatched skill (the row's skill arms its own gate) | that skill's label | `rm -f` before every marker |
| `research`, `plan`, `audit`, `learn`, `ship` | never (`rm -f` any leftover) | — | — |

```bash
GATE_DIR=".cc-sessions/sessions/${CLAUDE_SESSION_ID}"; mkdir -p "$GATE_DIR"
SELECTED=$("${CLAUDE_PLUGIN_ROOT}/scripts/test-selector.sh" --base "${BLITZ_BASE:-origin/main}" 2>/dev/null | cut -f1 | tr '\n' ' ')
jq -n --arg sel "$SELECTED" --arg until "build ${SLUG} ${TASK}" '{
  checks: [
    {name: "tsc",   cmd: "npx tsc --noEmit --pretty false", timeout: 180},
    {name: "tests", cmd: ("npx vitest run --reporter=dot " + $sel), timeout: 300}
  ], blocks: 0, max_blocks: 4, until: $until }' > "$GATE_DIR/gate.json"
# … work …
rm -f "$GATE_DIR/gate.json"   # before any LOOP_* marker or early return
```

Interactive runs never write the file. Never wire a prompt-type Stop hook in the plugin: a user `/goal` is itself a prompt-type Stop hook and the two would fight; the gate already stands down on `stop_hook_active`. `/goal` is the loop controller (a separate evaluator judging the transcript); the gate is the evidence layer (commands that must pass). Both count against the platform's 5-block cap.

---

## `next` decision rows

`scripts/next-state.sh` supplies the facts; `next` picks the lowest matching row (0 > 1 > … > 5). Default mode prints the row's command and stops; `--loop` executes it.

| # | Condition | Default prints | `--loop` does |
|---|---|---|---|
| 0 | `kill_switch`, or `inbox_pending > 0` after triage, or `sessions_waiting > 0` | the pending items | `LOOP_DEFER` |
| 1 | a task is `blocked` with reason ∈ {`hard_spec`, `oracle-underivable`, `test-assertion-suspect`} | the escalation | notify, then `LOOP_ESCALATE` |
| 2 | active plan has an `in_progress` task or an `open` task whose deps are `done` | `/blitz:build <slug>` | dispatch `build <slug>` for `next_task` |
| 3 | all tasks `done` and `check_stale` | `/blitz:check --scope plan <slug> --fix` | dispatch `check` |
| 4 | `check-report.md` PASS and fresh | `Ready: /blitz:ship --plan <slug>` | set spec `status: done`, dispatch `learn <slug>`, archive the plan, print `Ready: /blitz:ship --plan <slug>` |
| 5 | nothing open | `LOOP_DONE` | `ScheduleWakeup stop:true` (self-paced only) + `LOOP_DONE` |

Every tick: triage the inbox first (`blocked` older than 24 h → one escalation line; `quarantine` → surface the path, never load it; items older than 7 d fold into one "needs triage" line; `needs_input`/`permission` for a session whose state ∈ {done, failed, stopped} are dismissed), then evaluate rows, then commit with the `Task:` trailer and push. Row 4 archives to `docs/plans/archive/<date>-<slug>/` after `learn` returns.

### Markers

The tick's last line is one of these; outer wrappers key on it and `stop-gate.sh` stands down on it.

| Marker | Meaning | Wrapper action |
|---|---|---|
| `LOOP_DONE` | row 5: nothing open | MAY halt |
| `LOOP_ESCALATE` | row 1: a human must rule | SHOULD halt (re-firing only re-prints the escalation) |
| `LOOP_DEFER` | row 0: inbox or live-session conflict | keep ticking; the next tick may find it resolved |
| `HEARTBEAT_OK` | inbox clean, nobody `waitingFor`; printed beside whichever marker applies | "nothing needs a human" |
| (none) | a skill was dispatched | re-tick and re-evaluate |

### Escalation notification order

Row 1 notifies through the first available channel, then prints `LOOP_ESCALATE`:

1. A channel `reply` tool (Telegram/Discord/iMessage channel attached to the session) — reply with plan, task id, `blocked_reason`, and `last_verify.tail`.
2. `PushNotification`.
3. An `inbox.jsonl` line, `kind: escalation`, `source: skill`.

`ship` is never in a row's dispatch column: it is slash-only (`disable-model-invocation: true`), pinned to its own model, and a scheduled fire cannot invoke it. Row 4 prints the ready line and stops.

---

## Running the loop

| Runtime | Command | Persistence | Min interval | Notes |
|---|---|---|---|---|
| `/loop` fixed interval | `/loop 15m /blitz:next --loop` in **its own session** | CronCreate task: expires 7 days after creation, recurring fires jitter up to 30 min late; dies with the session | 1 min | Re-create weekly; re-arm after any `--resume`. `CLAUDE_CODE_LOOP_MANAGED=1` is set: the skill never calls `ScheduleWakeup` |
| `/loop` self-paced | `/loop /blitz:next --loop` | `ScheduleWakeup` between ticks; row 5 ends it with `stop:true`; **not restored on `--resume`**; 20-min fallback wake when the model sets none | model-paced | Short attended runs only |
| Bare `/loop` | `/loop` | reads `.claude/loop.md`, written by `doctor --loop-md` (`/blitz:next --loop`) | as above | Same semantics as the two rows above |
| Desktop scheduled task | Claude Desktop task running `/blitz:next --loop` | survives session restart; needs the machine on | 1 min | Overnight local runs |
| Routine (cloud) | Routine prompt `/blitz:next --loop` | fresh cloud session per fire, no permission prompts, commits on `claude/` branches | 1 hour | Nightly and weekly; pair with `crossSessionInbound: hold` |
| Shell loop | `while :; do claude -p "/blitz:next --loop" \| tee -a loop.log \| grep -q LOOP_DONE && break; done` | fresh context per tick; keyed on markers | as scheduled | **Preferred for long runs**; set `crossSessionInbound: accept` for `-p` workers |
| Claude Projects | coordinator thread runs `next`; one thread per task on its own branch and PR | machine-independent | event-driven | Plugin loads into threads from `.claude/settings.json` or project settings |

A skill's own `ScheduleWakeup` is per-session and disappears with the process; it is never the keep-alive for unattended work. Durable loops are `/loop` in a dedicated session, a Desktop task, a Routine, or the shell loop.

### Headless rules

- No `AskUserQuestion` (`next --loop` declares `disallowed-tools: AskUserQuestion`; `-p` disables it anyway); a question becomes a `blocked_reason` and row 1.
- No Task tools (`TaskCreate/Update/List`, `TodoWrite`); `tasks.json` is the task list.
- `-p` workers set `crossSessionInbound: accept`; Routines set `hold`; both carry the messaging auth line on Windows and PID-1 containers ([sessions.md](/_shared/sessions.md), [security.md](/_shared/security.md)).
- Every tick commits and pushes before printing its marker, so a killed session loses nothing.

### `/goal` companion

On the first tick of a session (no prior `skill_start` from this session in the feed), `next --loop` prints the goal line once; the operator pastes it, blitz never sets it itself:

```
/goal <slug>: every task in docs/plans/<slug>/tasks.json is status: done, tsc clean, check-report.md PASS; stop after 40 turns
```

### Fresh session per tick

Every model degrades with context length and compaction can erase constraints. Prefer a fresh session per tick (Routine, shell loop, Projects thread) over one long `/loop` session; `tasks.json`, `progress.md`, and git are the memory. Inside a long session, `pre-compact-snapshot.sh` writes `HANDOFF.json` with the plan, task, gate path, and never-edit list so a compacted session resumes the same task.

---

## Verification ladder

Each rung has one owner and one kind of verdict; they compose, none replaces another. Details in [quality.md](/_shared/quality.md).

| Rung | Mechanism | Owner | Verdict |
|---|---|---|---|
| Prompt-level check | the skill's own checklist and `tasks.sh verify` output read before claiming done | the running skill | claim |
| `/goal` | prompt-type Stop hook: a separate evaluator judges the transcript each turn; counts against the platform's 5-block cap; survives compaction; works under `-p` | user pastes the line; blitz prints it | condition met / not yet / impossible |
| `stop-gate.sh` | deterministic: `gate.json` checks (tsc, selected tests, lint) | blitz Stop hook | pass / block (≤4) |
| `critic` | fresh-context evaluator, no `Write`/`Edit`, `omitClaudeMd`; `--mode reject` (opus) for gates, `--mode survey` (sonnet) for `check`; runs `tasks[].verify[]` through `tasks.sh` | `check`, `build` fix rounds | LGTM / REJECT, JSON findings |
| Bundled `/verify` | the platform's user-only skill; its recorded recipe lives at `.claude/skills/verify/SKILL.md` and `check` reads it for the app-level run | user | the app runs and behaves |

Tests alone are gamed: every behavior task pairs its test command with a non-test check, and `check` runs `tasks.sh verify` for every task in scope before `critic` reads the diff.
