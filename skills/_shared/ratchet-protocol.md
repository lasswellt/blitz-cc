# Quality Ratchet Protocol

Authoritative protocol for monotonic quality metrics. The ratchet ensures **work compounds**: code quality only improves across sprints, never regresses. Sprint-review enforces ratchet invariants in Phase 3.6; auto-revert triggers on deterministic regressions.

**Why this doc exists**: `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 documented 19 shortcut signals and the ratchet pattern that proves work compounds across monotonic metrics (originally 7; expanded to 8 on 2026-05-17 with `stale_worktree_branch_count` per [worktree-lifecycle.md](worktree-lifecycle.md)). This is the canonical schema and enforcement contract.

---

## 1. The 7 Monotonic Metrics

Stored in `docs/sweeps/ratchet.json`, updated by `code-sweep` and `sprint-review`:

| Metric | Direction | Floor | Detector |
|---|---|---|---|
| `test_count` | ↑ | baseline | `grep -rcE '\b(it\|test)\(' --include='*.test.*' --include='*.spec.*' . \| awk -F: '{s+=$2} END {print s}'` |
| `type_errors` | ↓ | absolute 0 | `npx tsc --noEmit 2>&1 \| grep -cE 'error TS\d+'` |
| `as_any_count` | ↓ | baseline | `grep -rEn '\bas any\b' src/ --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ \| wc -l` |
| `lint_violations` | ↓ | baseline | `npx eslint --format=json . 2>/dev/null \| jq '[.[].errorCount] \| add // 0'` |
| `completeness_score` | ↑ | baseline | `/blitz:review --only completeness` (existing) |
| `mocks_in_src` | ↓ | baseline | `grep -rEn '\b(vi\.mock\|jest\.mock\|sinon\.stub)\b' src/ --exclude-dir=__tests__ \| wc -l` |
| `todo_count` | ↓ | baseline | `grep -rEn '\b(TODO\|FIXME)\b' src/ \| wc -l` |
| `stale_worktree_branch_count` | ↓ | baseline | `git for-each-ref --format='%(refname:short)' refs/heads/worktree-agent-* refs/heads/worktree-sprint-* refs/heads/sprint-*/backend refs/heads/sprint-*/frontend refs/heads/sprint-*/tests refs/heads/sprint-*/infra refs/heads/sprint-*/integration \| wc -l` |

`type_errors` is special: it has an **absolute floor of 0** in addition to the ratchet. Once a project hits 0, it cannot regress to 1.

`stale_worktree_branch_count` measures branches matching the spawn-protocol-controlled patterns from [worktree-lifecycle.md](worktree-lifecycle.md). Existing projects must run `code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix debt; otherwise the first sprint-review post-upgrade will fail Invariant 8 for projects with N>0 stale branches. After baselining, the ratchet tightens monotonically as `/blitz:worktree-prune` reduces the count.

---

## 2. File Schema

`docs/sweeps/ratchet.json`:

```json
{
  "$schema": "blitz-ratchet/1.0",
  "sprint": "sprint-N",
  "updated_at": "2026-05-01T00:00:00Z",
  "metrics": {
    "test_count":         {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "type_errors":        {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down", "absolute_floor": 0},
    "as_any_count":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "lint_violations":    {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "completeness_score": {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "mocks_in_src":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "todo_count":         {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "stale_worktree_branch_count": {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"}
  },
  "auto_revert": {"enabled": true, "needs_human_label": "ratchet-regression"},
  "history": [
    {"sprint": "sprint-1", "ts": "2026-04-01T00:00:00Z", "metrics": {"...": "..."}}
  ]
}
```

Key rules:
- `baseline` = value from end of previous sprint (frozen reference).
- `current` = value at last sprint-review run.
- `min_allowed` / `max_allowed` = enforcement threshold (= baseline by default; tightens when current beats baseline).
- `direction` = `up` (↑) or `down` (↓).
- `history[]` = append-only sprint-end snapshots; never rewritten.

---

## 3. Tighten-on-Improvement (the actual ratchet)

When a sprint-review run computes `current` better than `max_allowed`/`min_allowed`:

1. Update `current` to the new value.
2. Tighten threshold: `max_allowed = current` (for ↓ metrics) or `min_allowed = current` (for ↑ metrics).
3. Append snapshot to `history[]`.

The threshold can never loosen. Once `as_any_count` drops to 5, it must stay ≤5 forever.

---

## 4. Multi-Agent Worktree Merge

When two parallel sprint-dev waves modify ratchet metrics in separate worktrees, the merge takes the **min** of `max_allowed` and the **max** of `min_allowed` across both worktrees:

```bash
merge_ratchet() {
  local left="$1" right="$2" out="$3"
  jq -s '
    .[0] as $L | .[1] as $R |
    {
      sprint: $L.sprint,
      updated_at: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
      metrics: ($L.metrics | to_entries | map(
        .key as $k |
        .value as $lv |
        $R.metrics[$k] as $rv |
        {key: $k, value:
          if $lv.direction == "down"
          then $lv + {max_allowed: ([$lv.max_allowed, $rv.max_allowed] | min),
                      current:     ([$lv.current,     $rv.current]     | min)}
          else $lv + {min_allowed: ([$lv.min_allowed, $rv.min_allowed] | max),
                      current:     ([$lv.current,     $rv.current]     | max)}
          end
        }
      ) | from_entries),
      auto_revert: $L.auto_revert,
      history: ($L.history + $R.history)
    }' "$left" "$right" > "$out"
}
```

The intent: a parallel branch cannot "loosen" the ratchet by merging; it can only contribute improvements.

---

## 5. Auto-Revert Protocol (deterministic regressions only)

When a fix commit during sprint-dev causes a deterministic metric to regress, sprint-dev MUST:

```
after each fix commit:
  current = compute_metrics()
  for each metric where direction-violation detected:
    if metric in {type_errors, as_any_count, lint_violations, completeness_score, mocks_in_src, todo_count, stale_worktree_branch_count}:
      git reset --hard HEAD~1   # only the fix commit
      append to .cc-sessions/carry-forward.jsonl: {needs-human, reason: "ratchet:<metric>"}
      activity-feed: event=auto_revert detail={metric, old, new}
      stop further auto-fixes for this metric this sprint
    elif metric == "test_count":
      # flaky, do not auto-revert; flag for human
      append to carry-forward: {needs-human, reason: "test_count regression — possible flaky"}
```

`test_count` regression NEVER triggers auto-revert (could be flaky test removal); it only flags. All other metrics are deterministic.

---

## 6. Sprint-Review Enforcement (Phase 3.6 invariant)

`sprint-review` Phase 3.6 reads `docs/sweeps/ratchet.json`, computes current values, and:

1. Sprint **cannot reach PASS** if any metric violates direction with no carry-forward escalation.
2. Improvements are recorded automatically (tighten thresholds + history snapshot).
3. Regressions surfaced as Phase 3.6 BLOCKERs unless covered by an explicit carry-forward entry with `rollover_count <= 2`.

This integrates with the existing carry-forward registry (see [carry-forward-registry.md](./carry-forward-registry.md)).

---

## 7. Bootstrap (greenfield / first sprint)

Run once at project setup:

```bash
mkdir -p docs/sweeps
cat > docs/sweeps/ratchet.json <<'JSON'
{
  "$schema": "blitz-ratchet/1.0",
  "sprint": "sprint-0",
  "updated_at": "<TS>",
  "metrics": {
    "test_count":         {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "type_errors":        {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down", "absolute_floor": 0},
    "as_any_count":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "lint_violations":    {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "completeness_score": {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "mocks_in_src":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "todo_count":         {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "stale_worktree_branch_count": {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"}
  },
  "auto_revert": {"enabled": true, "needs_human_label": "ratchet-regression"},
  "history": []
}
JSON
```

First real `sprint-review` run will compute baselines from the codebase and tighten thresholds.

---

## 8. Disable / Override

`auto_revert.enabled: false` disables auto-revert (advisory mode). Set this for projects with very high test flakiness while flakiness is being addressed.

There is no override for the absolute floor on `type_errors`. Type-clean is non-negotiable.

---

## Related

- [`spawn-protocol.md`](./spawn-protocol.md) §8 — output contract integrates with ratchet metric reporting via `metrics:` field
- [`carry-forward-registry.md`](./carry-forward-registry.md) — ratchet violations create carry-forward entries
- `skills/sprint-review/SKILL.md` Phase 3.6 — runtime enforcement
- `skills/code-sweep/SKILL.md` — surfaces ratchet-tightening opportunities
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` — research basis
