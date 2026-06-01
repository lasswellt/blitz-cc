# next — Reference

## Reconciliation Report Examples (--loop)

**Dispatching a phase (rows 0-5, 6b-6d):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: in-progress (8/12 stories, STATE.md checkpoint exists)
  ├─ Carry-forward: 0 active, 0 escalated, 0 pending inputs
  ├─ DECISION: Resume implementation from checkpoint (row 1)
  │  Reason: STATE.md found with 4 remaining stories
  ├─ Dispatching: /blitz:implement --resume
  ├─ Commit: feat(loop): next reconciliation tick — row 1: resume sprint-dev
  └─ Next /loop tick will re-evaluate after completion
```

**Idle (row 7):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ Carry-forward: 0 active, 0 partial, 0 pending inputs
  ├─ All epics: done or blocked
  ├─ DECISION: Nothing to do (row 7) — LOOP_DONE
  └─ Idle — waiting for new epics or roadmap changes
```

**Carry-forward gap closure (row 6d):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ All epics: done in epic-registry.json
  ├─ Carry-forward: 2 active, 1 partial (NOT idle)
  │    - cf-2026-04-02-modal-consistency: partial, coverage 0.646
  │    - cf-2026-04-05-api-error-handling: active, coverage 0.0
  │    - cf-2026-04-07-auth-rate-limits: partial, coverage 0.33
  ├─ DECISION: Plan gap-closure sprint (row 6d)
  ├─ Dispatching: /blitz:sprint-plan
  └─ Next /loop tick will re-evaluate after planning
```

**Audit-derived sprint (row 6e):**
```
[next --loop] Reconciliation:
  ├─ Sprint 12: done (audit-derived)
  ├─ Audit: docs/audits/audit-2026-05-17-index.json found (newer than last shipped)
  │    UNSPRINTIFIED_AUDIT_COUNT: 3 (EPIC-A07, EPIC-A09, EPIC-A12)
  ├─ Scope limit: not active
  ├─ DECISION: Plan audit-derived sprint (row 6e)
  ├─ Dispatching: /blitz:sprint-plan
  └─ Next /loop tick will re-evaluate after planning
```

**Scope-limit active (row 6f):**
```
[next --loop] Reconciliation:
  ├─ SCOPE-LIMIT.md: active (declared 2026-05-18, expires 2026-08-01)
  │    Reason: Diminishing returns past sprint 12 — pause for capability X
  │    Scope: full-codebase
  ├─ DECISION: Operator scope-limit (row 6f) — LOOP_ESCALATE
  │    Loop cannot auto-advance. Resolve via:
  │      a) Wait for expiry (auto-clear after expires_after)
  │      b) Delete SCOPE-LIMIT.md to lift override
  │      c) Edit SCOPE-LIMIT.md expires_after to a past date
  └─ Exiting — /loop will re-escalate on next tick until resolved
```

**Escalation (row 6a):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: CONDITIONAL)
  ├─ Carry-forward: 1 escalation (rollover_count >= 3)
  │    - cf-2026-04-02-modal-consistency: rollover_count=3
  │      Parent: CAP-133 / EPIC-105
  │      Last touched: sprint-197 (3 sprints ago)
  ├─ DECISION: Escalate to human review (row 6a) — LOOP_ESCALATE
  │    Loop cannot auto-advance while this entry is stuck. Resolve via:
  │      a) /blitz:sprint-plan with explicit split targeting this entry
  │      b) Append `deferred` event to .cc-sessions/carry-forward.jsonl
  │         with revisit date in notes
  │      c) Append `dropped` event with drop_reason + revival_candidate
  └─ Exiting — /loop will re-escalate on next tick until resolved
```
