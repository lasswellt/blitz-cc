# Loop Protocol

The blitz loop is `research → plan → build → check → ship`, with `learn` feeding `docs/solutions/` back into `plan`. `ship` is slash-only and never dispatched automatically.
`/blitz:next --loop` is the autonomous entry point: one tick reads `docs/plans/*/tasks.json` and `.cc-sessions/inbox.jsonl`, reconciles them, dispatches at most one task-sized unit of work, commits, and exits so the scheduler can re-tick.
State lives in tracked files (`tasks.json`, `progress.md`) and git, never in the conversation; a fresh session per tick is the preferred runtime.
"Done" is structural: a task is `done` only when `scripts/tasks.sh verify` has recorded passing evidence, and a hook denies every other writer of `tasks.json`.
Siblings: [sessions.md](/_shared/sessions.md), [agents.md](/_shared/agents.md), [quality.md](/_shared/quality.md), [security.md](/_shared/security.md), [output.md](/_shared/output.md).

---


> **Reference:** [loop.reference.md](loop.reference.md) carries the rest of this protocol: Scripts, the Stop gate and its arming table, `next` decision rows and markers, running the loop headless, and the verification ladder. Load it when you need one of those; this file is the contract every consumer obeys.

## Artifacts

| Path | Writer | Readers | Tracked |
|---|---|---|---|
| `docs/plans/<slug>/spec.md` | `plan` (`audit` for `audit-<date>` plans, paused); `next --loop` flips `status` | `build`, `check`, `next`, `ship`, `learn` | tracked |
| `docs/plans/<slug>/plan.md` | `plan` | `build`, `check`, `critic` | tracked |
| `docs/plans/<slug>/tasks.json` | **`scripts/tasks.sh` only** (called by `plan`, `build`, `check`, `audit`, `next`) | `next-state.sh`, `build`, `check`, `critic`, `learn`, `startup-validate.sh` | tracked |
| `docs/plans/<slug>/progress.md` | `build` (task boundaries), `check`, `next --loop` (rulings), main thread only | `build` (recovery map), `learn`, humans | tracked |
| `docs/plans/<slug>/check-report.md` | `check` | `next-state.sh` (row 3/4 freshness), `ship`, `learn` | tracked |
| `docs/plans/<slug>/check-report.json` | `check` | CI, evals, `next` | tracked; schema `blitz-check-report/1.0`, the machine-readable sibling of the report so nothing has to parse prose |
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
  "attempts": 0,
  "last_verify": {"ts":"","ok":false,"failed":"","tail":"",
                  "runs":[{"cmd":"…","exit":0,"duration_ms":8421,"tail":"…","recorded_at":"…"}]},
  "origin": "plan|audit|check|learn|issue:<n>", "notes": "" }
```

| Field | Notes |
|---|---|
| `files` | the only paths a `dev` may touch for this task; disjointness gates `build --parallel` |
| `verify[]` | executable checks; `timeout` in seconds; `tasks.sh verify` runs them in order and stops at the first failure. `tasks.sh verify <plan> --changed <paths>` re-runs only the `done` tasks whose `files[]` those paths touch — the post-merge selective re-verify a parallel wave needs, since a clean textual merge is not a semantic one. |
| `passes` | written only by `tasks.sh verify`; mirrors `last_verify.ok` |
| `last_verify.tail` | ≤200 chars of the failing command's output (evidence, not a summary) |
| `last_verify.runs[]` | one entry per command that actually ran, in order: `cmd`, `exit`, `duration_ms`, `tail` (≤2 KB, `BLITZ_VERIFY_EVIDENCE_CAP`), `recorded_at`. This is what lets the critic adjudicate from the record instead of re-running the suite, and what makes `cannot_verify` a defensible reviewer answer. The run stops at the first failure, so a command after the failing one has no entry. |
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
