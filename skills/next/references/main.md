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
  │    `scripts/tasks.sh set checkout-v2 T-007 status=open blocked_reason=`
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
