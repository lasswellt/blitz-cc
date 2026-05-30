# Deviation Handling Protocol

When an agent encounters something unexpected during implementation — a bug in existing code, a missing dependency, a design issue not covered by the story — follow these tiered rules to decide how to handle it.

**Companion protocols:**
- [definition-of-done.md](definition-of-done.md) — Quality standards that must not be compromised by deviations

---

## Tier 1: Auto-Fix (No Escalation Needed)

Handle these silently. Fix, commit separately, and continue.

| Situation | Action |
|---|---|
| Bug in existing code that blocks the current story | Fix it, add a comment explaining why, commit separately with `fix(scope):` prefix |
| Missing import or export in an existing file | Add it |
| Clear type mismatch in existing code | Fix the type definition if it's obviously wrong |
| Missing barrel file entry (`index.ts`) | Add the export |
| Broken test caused by your changes (not a regression) | Fix the test to match the new behavior |

**Commit format for auto-fixes:** `fix(sprint-${N}/<role>): fix <what> — discovered during S${N}-XXX`

---

## Tier 2: Auto-Add (Report to Orchestrator)

Handle these, but report what you did so the orchestrator can track scope changes.

| Situation | Action |
|---|---|
| Need a utility/helper function not in the story | Create it, report via DEVIATION message |
| Missing error handling in existing code that new code depends on | Add it, report via DEVIATION message |
| Need an additional type or interface not specified | Create it, report via DEVIATION message |
| Discovered a closely related issue worth fixing | Fix it if < 20 lines, report via DEVIATION message |

**Report format:**
```
DEVIATION: <what was added or changed>
  Reason: <why it was needed>
  Files: <list of files touched>
  Impact: <low — isolated to this story's scope>
```

---

## Tier 3: Escalate (Ask Orchestrator)

Do NOT proceed. Report to the orchestrator and wait for guidance.

| Situation | Action |
|---|---|
| Architectural change needed (new module boundaries, new shared packages) | ESCALATE and wait |
| Changes to public API contracts that other agents depend on | ESCALATE and wait |
| Changes affecting more than 3 files outside the agent's assigned stories | ESCALATE and wait |
| Story's acceptance criteria are contradictory or impossible | ESCALATE and wait |
| Need to modify another agent's worktree or branch | ESCALATE and wait |
| Performance concern that would require a different approach | ESCALATE and wait |

**Report format:**
```
ESCALATE: <what needs to change>
  Impact: <which agents/stories are affected>
  Options: <2-3 possible approaches if known>
  Blocked: <yes/no — can I continue other stories while waiting?>
```

---

## Tier 4: Never Auto-Fix

These changes MUST be escalated even if they seem simple. The orchestrator must involve the user.

- Security rules or authentication patterns
- Database schema migrations or Firestore security rules
- Breaking changes to shared APIs (used by multiple modules)
- Environment variable additions (require deployment coordination)
- Dependency additions (new packages in package.json)
- License-affecting changes

---

## Orchestrator Handling

When the orchestrator receives a deviation or escalation:

### For DEVIATION messages:
1. Log the deviation to the activity feed with `event: "decision"`.
2. Track cumulative deviations. If total deviations exceed 5 in a sprint, flag to the user.
3. Update STATE.md with deviation notes.

### For ESCALATE messages:
1. Log the escalation to the activity feed.
2. If the agent said `Blocked: no`, let them continue with other stories.
3. If the agent said `Blocked: yes`, check if other agents can take their ready stories.
4. Present the escalation to the user with the agent's options. Also fire a remote push so a user monitoring via `claude agents` is alerted off-screen (no-op if Remote Control unconfigured; gate on developer-profile `notify`):
   ```
   PushNotification(title: "Escalation — decision needed", message: "<skill>: <one-line what needs to change>")
   ```
5. After user decision, send resolution via `ASSIST:` message to the agent.

---

## Auto-Fix Priority Order

When multiple deviations or issues are discovered simultaneously, resolve them in this priority order:

| Priority | Category | Examples | Rationale |
|----------|----------|----------|-----------|
| **P1** | Bugs blocking current story | Type errors, import failures, runtime crashes | Unblocks the agent immediately |
| **P2** | Critical functionality gaps | Missing auth checks, broken API contracts | Prevents security/data issues |
| **P3** | Blockers for dependent stories | Missing exports, incomplete types, missing barrel entries | Unblocks downstream agents |
| **P4** | Architecture/convention issues | Wrong directory, inconsistent naming, missing error handling | Maintains codebase quality |

Within the same priority level, resolve issues affecting more files first (wider impact = earlier fix).

### Tier 2 Auto-Add Escalation Rule

If a Tier 2 auto-add exceeds **30 lines of new code**, it must be promoted to **Tier 3 (Escalate)**. The threshold exists because large auto-adds risk:
- Introducing scope creep that the orchestrator cannot track
- Creating merge conflicts with other agents' work
- Hiding significant design decisions in deviation reports

When promoting, include the completed work so far in the ESCALATE message so the orchestrator can decide whether to accept it as-is or request changes.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
