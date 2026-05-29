# Scheduling Reference

Skills can be run on a recurring schedule using Claude Code's built-in scheduling features.

## Methods

### /loop (Session-Scoped)

Runs a skill at a fixed interval within the current session. Tasks expire when the session closes or after 3 days.

```
/loop 2h /blitz:dep-health audit
/loop 1d /blitz:quality-metrics collect
/loop 30m /blitz:sprint --loop
/loop 10m /blitz:code-sweep --loop
```

### /schedule (Remote Triggers)

Creates persistent scheduled tasks that survive session closure. Uses CronCreate under the hood.

```
/schedule daily /blitz:dep-health audit
/schedule weekly /blitz:quality-metrics collect
```

## Recommended Schedules

| Skill | Interval | Mode | Rationale |
|-------|----------|------|-----------|
| `dep-health` | Weekly | `audit` | Catch vulnerabilities and outdated packages |
| `quality-metrics` | Daily | `collect` | Track quality trends over time |
| `/blitz:review --only completeness` | After each sprint | default | Catch placeholders before they age |
| `retrospective` | After each sprint | default | Auto-analyze completed sessions |
| `sprint` | 15-30m | `--loop` | Continuous sprint execution |
| `code-sweep` | 10m | `--loop` | Iterative code cleanup with auto-fix |
| `health` | Daily | default | Plugin integrity check |

## Loop-Compatible Skills

Skills that support `/loop` must be **idempotent** — safe to call repeatedly with the same result. The following skills are loop-compatible:

| Skill | Loop-Safe | Notes |
|-------|-----------|-------|
| `sprint --loop` | Yes | Reconciliation layer detects state, runs one phase per tick |
| `dep-health audit` | Yes | Read-only audit, no state changes |
| `quality-metrics collect` | Yes | Writes to date-stamped files, no conflicts |
| `health` | Yes | Read-only check |
| `/blitz:review --only completeness` | Yes | Read-only scan |
| `code-sweep --scan-only` | Yes | Read-only scan with state tracking |
| `code-sweep --loop` | Yes | One fix per tick, verify-before-commit, ratchet enforcement |
| `browse --loop` | Yes | One page per tick, discovers links from DOM, builds site hierarchy, auto-fixes up to 2 issues. Requires running dev server + auth. Circuit breaker on 3 fix failures. Max 500 pages / depth 8 |
| `next` | Yes | Read-only advisor |

Skills that modify code (sprint-dev, refactor, fix-issue, etc.) should NOT be used with `/loop` directly — use `/blitz:sprint --loop` or `/blitz:code-sweep --loop` to orchestrate them safely.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
