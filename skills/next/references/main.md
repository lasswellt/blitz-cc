# next — Reference

## Tick report examples (--loop)

Every report opens with the Observe facts, states the row and reason from `scripts/next-state.sh`, and ends with a marker (or none when a skill was dispatched). `HEARTBEAT_OK` is printed beside the marker whenever the inbox is clean and nobody is `waitingFor`.

**Row 2 — build the next task:**
```
[next --loop] tick:
  ├─ plan:     checkout-v2 (P1, active); paused: audit-2026-09-12
  ├─ tasks:    4/9 done, 1 in_progress (T-005), 0 blocked
  ├─ inbox:    clean · sessions waiting: 0
  ├─ DECISION: row 2 — open work in checkout-v2
  ├─ gate:     armed (tsc + 3 selected tests) until "build checkout-v2 T-005"
  ├─ Dispatching: /blitz:build checkout-v2   (T-005 "cart store exposes useCart", attempt 2)
  ├─ Commit:   feat(loop): tick — row 2: build checkout-v2 T-005   (Task: checkout-v2/T-005)
  └─ Next tick re-evaluates from disk
HEARTBEAT_OK
```

**Row 3 — all tasks done, check report stale:**
```
[next --loop] tick:
  ├─ plan:     checkout-v2 (P1, active)
  ├─ tasks:    9/9 done · check-report.md: CONDITIONAL (older than tasks.json)
  ├─ inbox:    clean · sessions waiting: 0
  ├─ DECISION: row 3 — all tasks done; check report missing, stale, or not PASS
  ├─ gate:     armed (tsc + lint) until "check checkout-v2 fix"
  ├─ Dispatching: /blitz:check --scope plan checkout-v2 --fix
  ├─ Commit:   feat(loop): tick — row 3: check checkout-v2   (Task: checkout-v2/plan)
  └─ Next tick re-evaluates from disk
HEARTBEAT_OK
```

**Row 4 — check PASS, learn and archive (ship stays manual):**
```
[next --loop] tick:
  ├─ plan:     checkout-v2 (P1, active) · check-report.md: PASS 2026-09-19T15:00:00Z (fresh)
  ├─ inbox:    clean · sessions waiting: 0
  ├─ DECISION: row 4 — checkout-v2 verified PASS; mark done, learn, archive; ship is slash-only
  ├─ spec.md:  status active → done · progress.md ruling appended
  ├─ Dispatching: /blitz:learn checkout-v2   (2 solutions written: docs/solutions/cart-store-hydration.md, …)
  ├─ Archived: docs/plans/archive/2026-09-19-checkout-v2/
  ├─ Commit:   feat(loop): tick — row 4: learn+archive checkout-v2   (Task: checkout-v2/plan)
  └─ Ready: /blitz:ship --plan checkout-v2
HEARTBEAT_OK
```

**Row 5 — nothing open:**
```
[next --loop] tick:
  ├─ plan:     none active; paused: audit-2026-09-12; done, unarchived: none
  ├─ inbox:    clean · sessions waiting: 0
  ├─ DECISION: row 5 — no active plan with open work
  ├─ ScheduleWakeup stop:true   (self-paced only; no-op under /loop, Routine, or claude -p)
  └─ LOOP_DONE
HEARTBEAT_OK
```

**Row 1 — blocked task needs a human:**
```
[next --loop] tick:
  ├─ plan:     checkout-v2 (P1, active)
  ├─ tasks:    6/9 done, 1 blocked
  │    - T-007 blocked test-assertion-suspect (attempts 3)
  │      last_verify: npx vitest run src/cart/total.test.ts --reporter=dot
  │      tail: "expected 1999 to equal 19.99 — assertion mixes cents and dollars"
  ├─ inbox:    clean · sessions waiting: 0
  ├─ DECISION: row 1 — blocked task needs a human: checkout-v2/T-007 (test-assertion-suspect)
  │    Ruling needed: review src/cart/total.test.ts; fix the assertion or reword the spec, then
  │    `scripts/tasks.sh set checkout-v2 T-007 status=open blocked_reason= attempts=0`
  ├─ Notified:  PushNotification (no channel reply tool loaded)
  ├─ progress.md: Ruling line appended · Commit: feat(loop): tick — row 1: escalate checkout-v2 T-007
  └─ LOOP_ESCALATE
HEARTBEAT_OK
```

**Row 0 — inbox pending after triage:**
```
[next --loop] tick:
  ├─ inbox triage: 3 pending → 1 converted (hook_failure), 1 dismissed (needs_input on stopped session), 1 still pending
  │    WAITING: 8c1d…f0a2 permission prompt (build checkout-v2, live 4m ago)
  ├─ sessions waiting: 1
  ├─ DECISION: row 0 — inbox pending or a session is waiting for input
  └─ LOOP_DEFER
```

**Row 0 — kill switch:**
```
[next --loop] tick:
  ├─ kill switch: .cc-sessions/STOP present (every tool call denied until removed)
  ├─ DECISION: row 0 — kill switch
  └─ LOOP_DEFER
```

**Row 0 — live session conflict (§3.3):**
```
[next --loop] tick:
  ├─ Live session: 8c1d…f0a2 build checkout-v2 (working, 5m ago; waitingFor: none)
  ├─ DECISION: Defer — peer notified via SendMessage, idle notice requested
  └─ LOOP_DEFER
HEARTBEAT_OK
```

## Suggest mode examples (default)

```
[next] row 2: open work in checkout-v2
  plan:    checkout-v2 (P1); paused: audit-2026-09-12
  task:    T-005 cart store exposes useCart (attempt 2)
  blocked: T-003 circuit-breaker
  → /blitz:build checkout-v2
Builds T-005 with one dev agent, verifies through scripts/tasks.sh, marks it done on pass.
```

```
[next] row 4: checkout-v2 verified PASS; mark done, learn, archive; ship is slash-only
  plan:    checkout-v2 (P1)
  → Ready: /blitz:ship --plan checkout-v2
Run /blitz:next --loop to mark the plan done, mine solutions, and archive it first.
```

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

## Flag Parsing

- `--loop`: one autonomous tick. Reads state, triages the inbox, dispatches one row, commits/pushes, exits. Sets autonomy `full` — all sub-skill confirmation prompts auto-approved. Designed for `/loop <interval> /blitz:next --loop` **in a dedicated session**, a Routine, or a `claude -p` shell loop.
- `--plan <slug>`: restrict rows 2–4 to that plan (still evaluates rows 0 and 1 globally). Default: the plan `next-state.sh` selects (first `status: active` by `priority`, then `created`).

**Scheduling tiers for `--loop`** (facts per [loop.reference.md](/_shared/loop.reference.md) §Running the loop):

| Tier | How | Persistence | Min interval | Use case |
|------|-----|-------------|--------------|----------|
| `/loop 15m /blitz:next --loop` | Dedicated `claude` session, CronCreate-backed | CronCreate tasks expire after **7 days** (recurring fires jitter up to 30 min late); the loop dies with the session | 1 min | Interactive dev runs, day-long runs |
| `/loop /blitz:next --loop` (self-paced) | Same session, `ScheduleWakeup` between ticks | **Not restored on `--resume`** — lost with the process | model-paced | Short attended runs only |
| Bare `/loop` | Reads `.claude/loop.md`, written by `/blitz:doctor --loop-md` (`/blitz:next --loop`) | as above | as above | Same semantics as the two rows above |
| Desktop scheduled task | Claude Desktop, local machine | Survives session restart; needs the machine on | 1 min | Overnight local runs |
| Routine (cloud) | Fresh session per fire, no permission prompts | Machine-independent | **1 hour** | Nightly CI, weekly sweeps — pair with `crossSessionInbound: hold` (TB-5) |
| Shell loop | `while :; do claude -p "/blitz:next --loop" \| tee -a loop.log \| grep -q LOOP_DONE && break; done` | Fresh context per tick; keyed on markers | as scheduled | **Preferred for long runs**; `crossSessionInbound: accept` for `-p` workers |

**Fresh session per tick is preferred.** Every model degrades with context length and compaction can erase constraints; `tasks.json`, `progress.md`, and git are the memory. A Routine, the shell loop, or a Projects thread beats one long `/loop` session. Inside a long session, `pre-compact-snapshot.sh` writes `HANDOFF.json` (plan, task, gate path, never-edit list) so a compacted session resumes the same task.

**Self-scheduling is per-session and lost on resume.** A `ScheduleWakeup` this skill registers (§3.6) only bridges ticks *inside the current process*; it is never the keep-alive for unattended work. Durable loops are `/loop` in its own session (re-arm after any `--resume`), a Desktop task, a Routine, or the shell loop. Do NOT call `ScheduleWakeup` when `/loop` manages the cadence (`CLAUDE_CODE_LOOP_MANAGED=1`).

**`/goal` companion.** On the **first tick only** (no prior `skill_start` from this session in the feed), print the recommended goal line once so the operator can paste it — blitz never sets it itself; it turns the session's `Stop` hook into a condition evaluator with check-ins that double from 30 min during background work:
```
/goal <slug>: every task in docs/plans/<slug>/tasks.json is status: done, tsc clean, check-report.md PASS; stop after 40 turns
```

If `--loop` is not specified, fall through to suggest mode (Phases 0, 0.5, 1, 2 — no dispatch).
