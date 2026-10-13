# Loop Protocol

The blitz loop is `research → plan → build → check → ship`, with `learn` feeding `docs/solutions/` back into `plan`. `ship` is slash-only and never dispatched automatically.
`/blitz:next --loop` is the autonomous entry point: one tick reads `docs/plans/*/tasks.json` and `.cc-sessions/inbox.jsonl`, reconciles them, dispatches at most one task-sized unit of work, commits, and exits so the scheduler can re-tick.
State lives in tracked files (`tasks.json`, `progress.md`) and git, never in the conversation; a fresh session per tick is the preferred runtime.
"Done" is structural: a task is `done` only when `scripts/tasks.sh verify` has recorded passing evidence, and a hook denies every other writer of `tasks.json`.
Siblings: [sessions.md](/_shared/sessions.md), [agents.md](/_shared/agents.md), [quality.md](/_shared/quality.md), [security.md](/_shared/security.md), [output.md](/_shared/output.md).

---

> **Reference:** [loop.reference.md](loop.reference.md) carries the rest of this protocol: schema detail (`notes` tokens, `last_verify.runs[]`, a `progress.md` example), Scripts, the Stop gate, `next` rows and markers, running the loop, and the verification ladder. Load it when you need one of those; this file is the contract every consumer obeys.

## Artifacts

| Path | Writer | Readers | Tracked |
|---|---|---|---|
| `docs/plans/<slug>/spec.md` | `plan` (`audit` for `audit-<date>` plans, paused); `next --loop` flips `status` | `build`, `check`, `next`, `ship`, `learn` | tracked |
| `docs/plans/<slug>/plan.md` | `plan` | `build`, `check`, `critic` | tracked |
| `docs/plans/<slug>/tasks.json` | **`scripts/tasks.sh` only** (called by `plan`, `build`, `check`, `audit`, `next`) | `next-state.sh`, `build`, `check`, `critic`, `learn`, `startup-validate.sh` | tracked |
| `docs/plans/<slug>/progress.md` | `build` (task boundaries), `check`, `next --loop` (rulings), main thread only | `build` (recovery map), `learn`, humans | tracked |
| `docs/plans/<slug>/check-report.md` | `check` | `next-state.sh` (row 3/4 freshness), `ship`, `learn` | tracked |
| `docs/plans/<slug>/check-report.json` | `check` | CI, evals, `next` | tracked; schema `blitz-check-report/1.0` |
| `docs/plans/archive/<date>-<slug>/` | `ship` or `learn` (move on done) | `learn`, humans | tracked |
| `docs/plans/BACKLOG.md` | `todo` | `plan` | tracked |
| `docs/solutions/<slug>.md` | `learn` (idempotent); frontmatter `{tags, stack, files, symptoms}` | `plan` (cap 5), `startup-validate.sh` | tracked |
| `.cc-sessions/sessions/<sid>/gate.json` | the arming skill (`build`, `check --fix`, `next --loop`) | `stop-gate.sh` | runtime |
| `.cc-sessions/HANDOFF.json` | `pre-compact-snapshot.sh` (plan, task, gate path, never-edit list) | the session after compaction | runtime |
| `.cc-sessions/inbox.jsonl` | hooks, `scripts/test-listener.sh`, skills via `blitz_inbox_append` | `next` triage, `sessions attention` | runtime |
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
  "blocked_reason": null,   // vocabulary below
  "attempts": 0,
  "last_verify": null,      // after the first tasks.sh verify: {"ts","ok","failed","tail","runs":[{"cmd","exit","duration_ms","tail","recorded_at"}]}
  "origin": "plan|audit|check|learn|issue:<n>", "notes": "" }
```

| Field | Notes |
|---|---|
| `files` | the only paths a `dev` may touch for this task; disjointness gates `build --parallel` |
| `verify[]` | executable checks; `timeout` in seconds; `tasks.sh verify` runs them in order and stops at the first failure. `verify <plan> --changed <paths>` is the post-merge selective re-verify (reference §Scripts). `tasks.sh add-verify <plan> <id> 'cmd::timeout'` appends a check after `add`; it resets `passes` and reopens a `done` task; `tasks.sh set … depends_on=T-001,T-003` rewrites the edges (ids must exist, a cycle is refused). |
| `passes` | written only by `tasks.sh verify`; mirrors `last_verify.ok` |
| `last_verify.tail` | ≤200 chars of the failing command's output (evidence, not a summary) |
| `last_verify.runs[]` | one entry per command that ran (`cmd`, `exit`, `duration_ms`, `tail` ≤2 KB, `recorded_at`); the critic adjudicates from it instead of re-running the suite (reference §`last_verify.runs[]`) |
| `blocked_reason` | vocabulary below |
| `origin` | provenance; `tasks.sh add` and `startup-validate.sh` reject a value outside the enum above |
| `notes` | one free-text string of `key: value` (or `key:value`) tokens (newline- or `; `-separated; a reader matches its own key and ignores the rest). `tasks.sh add --notes` sets it; `tasks.sh set … notes="…"` replaces it whole, so a writer re-sends the existing text with its token appended. Vocabulary: reference §`notes` tokens. `build` passes it verbatim into the `dev` prompt, so `startup-validate.sh` injection-scans it with `title` at every session start. |

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
priority: P1        # P0 | P1 | P2 or a bare integer; next-state.sh sorts P0 first, then created, then slug
created: 2026-09-19
ship: manual        # auto | manual; auto skips ship's confirmation prompt, but the loop still never dispatches ship
---
```

### progress.md

Append-only ledger; `build`, `check`, and `next --loop` append, nobody rewrites. `## <ISO-8601> <event>` opens every entry; `Ruling: <decision>; <why>` lines record non-trivial choices and are what `learn` mines. Example: reference §progress.md example.

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
| Main thread only: `tasks.json` and `progress.md` are on every dev agent's never-edit list; `build` writes them at task boundaries on the main branch | `tasks-guard.sh` denies `tasks.json` from any context and `progress.md` from a subagent (stdin `agent_type` set), by file tool or shell; the hook-injected never-edit list ([spawn-invariant.md](spawn-invariant.md)) says why; `pre-compact-snapshot.sh` carries the list through compaction |
| `attempts` increments per failed build attempt; `blocked` at 3 or on `ESCALATE:` | `build` via `tasks.sh set … attempts=+1`; the breaker is skipped when the same call sets `status` or `blocked_reason` explicitly (unblock recipe: reference §Scripts) |
| Fix rounds ≤3 on the same `dev` (sonnet); rounds 4–5 spawn a fresh `dev` on opus only under `--autonomous` or `next --loop` while `BLITZ_FIX_ROUNDS_MAX` (default 5) allows, after `build` re-opens the task past the breaker; round 5 adjudicates to `blocked` with a `Ruling:` | `build` ([agents.reference.md](agents.reference.md) §8) |
| Kill switch: while `.cc-sessions/STOP` exists every tool call is denied | `kill-switch.sh` (PreToolUse `*`) |
| `tasks.json` and `docs/solutions/*.md` are scanned at startup (shape, ids, injection, quarantine) | `startup-validate.sh` |
| Parallel builds are opt-in: sequential `dev` per task by default; `--parallel` only when ≥3 open tasks have disjoint `files`, cap 4, worktree isolation, sequential merge behind `git merge-tree` | `build`; see [agents.md](/_shared/agents.md) |
| `next --loop` never dispatches `ship` (`disable-model-invocation: true`) | platform |

---
