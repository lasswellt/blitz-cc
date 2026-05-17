---
name: worktree-prune
description: "Lists and safely deletes stale git worktrees + agent-spawned branches accumulated from `Agent({isolation: \"worktree\"})` calls. Default --dry-run mode is read-only and reports each branch with age, merge-status, divergence, and disk usage. --apply --merged-only deletes branches that are ancestors of origin/HEAD (safe). --apply --all-older-than 30d includes unmerged stale branches behind --force. Use when the user says 'worktree prune', 'clean up worktrees', 'delete stale branches', 'too many worktree-agent branches', 'free disk space', or notices 30+ leftover `worktree-agent-*` / `worktree-sprint-*` / `sprint-N/role` branches in `git branch`. Composes with the spawn-time collision guard in hooks/scripts/worktree-create.sh and the post-merge cleanup in sprint-dev Phase 4.4 per skills/_shared/worktree-lifecycle.md."
argument-hint: "[--dry-run|--apply] [--merged-only|--all-older-than <duration>] [--force]"
allowed-tools: Read, Bash, Glob, Grep
model: sonnet
effort: low
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.


# Worktree + Branch Prune

Inventory and safely delete stale git worktrees + agent-spawned branches that accumulate from blitz's `Agent({isolation: "worktree"})` usage and Claude Code harness auto-naming. Canonical contract: [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md).

**Default mode is `--dry-run`** — no mutation unless `--apply` is explicit.

## Modes

| Flag combination | Behavior |
|---|---|
| `--dry-run` (default) | List every matching worktree + branch with classification. No mutation. |
| `--apply --merged-only` | Delete branches that are ancestors of `origin/HEAD` (safe — these are merged or empty). |
| `--apply --all-older-than <duration>` | Include unmerged branches older than threshold. Requires `--force`. |
| `--apply --force` | Skip safety prompts. Use in scripted contexts. |

Duration parses as `30d`, `7d`, `12h`. Default threshold: `7d`.

---

## Phase 0 — Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration. Log start:
```
{"ts":"<ISO>","session":"<id>","skill":"worktree-prune","event":"session_start","message":"mode=<dry-run|apply>"}
```

## Phase 1 — Enumerate Worktrees and Branches

```bash
# All worktrees, machine-readable
git worktree list --porcelain > /tmp/wt-prune-list.txt

# All branches matching the prune-target patterns
git for-each-ref --format='%(refname:short)|%(committerdate:iso-strict)|%(committerdate:unix)' \
    refs/heads/worktree-agent-* \
    refs/heads/worktree-sprint-* \
    refs/heads/sprint-*/backend \
    refs/heads/sprint-*/frontend \
    refs/heads/sprint-*/tests \
    refs/heads/sprint-*/infra \
    refs/heads/sprint-*/integration \
    refs/heads/sprint-*/merged \
  > /tmp/wt-prune-branches.txt
```

Required regex coverage:
- `^worktree-agent-[0-9a-f]{8}$` — harness-spawned agent worktree branches
- `^worktree-sprint-[0-9]+(-plan)?$` — harness-spawned sprint-plan background branches
- `^sprint-[0-9]+/(backend|frontend|tests|infra|integration|merged)$` — blitz sprint-dev branches

## Phase 2 — Classify Each Branch

For each branch, compute:

| Field | How |
|---|---|
| `age_days` | `(now - committerdate_unix) / 86400` |
| `merged` | `git merge-base --is-ancestor <branch> origin/HEAD && echo true \|\| echo false` |
| `commits_ahead` | `git rev-list --count origin/HEAD..<branch>` |
| `worktree_path` | grep branch in `wt-prune-list.txt` → preceding `worktree` line |
| `worktree_exists` | `[ -d "$worktree_path" ]` |
| `disk_kb` | `du -sk "$worktree_path" 2>/dev/null \|\| echo 0` (skip if no worktree) |
| `action` | per matrix below |

**Action matrix:**

| merged | worktree_exists | commits_ahead | age_days | Action |
|---|---|---|---|---|
| true | false | 0 | any | `safe-delete` — branch fully merged, no worktree |
| true | true | 0 | any | `remove-worktree-then-delete` — clean both |
| false | false | >0 | >threshold | `stale-orphan` — flag for review (no worktree, has commits) |
| false | true | >0 | >threshold | `stale-divergent` — flag for review (worktree exists, has unmerged commits) |
| false | true | >0 | <threshold | `active` — leave alone |

## Phase 3 — Render Report

Print one table (always, regardless of mode):

```
BRANCH                                  AGE     MERGED  AHEAD   WT      DISK    ACTION
sprint-289/backend                      14d     no      12      yes     412M    stale-divergent
sprint-289/frontend                     14d     no      8       no      —       stale-orphan
worktree-agent-aae6004a                 28d     yes     0       no      —       safe-delete
worktree-sprint-291-plan                3d      yes     0       yes     220M    remove-worktree-then-delete
...

Summary: 47 branches matched | 18 safe-delete | 4 remove-worktree-then-delete | 23 stale-divergent | 2 active
Total disk reclaimable: 6.2 GB
```

## Phase 4 — Apply (gated on `--apply`)

If `--dry-run` (default): print "Run with `--apply --merged-only` to delete the 22 safe targets. No changes made." and exit 0.

If `--apply --merged-only`:

```bash
# Safe path — only ancestors of origin/HEAD
for ROW in <classified rows where action ∈ {safe-delete, remove-worktree-then-delete}>; do
  if [ "$worktree_exists" = "true" ]; then
    git worktree remove "$worktree_path" --force \
      || { echo "FAIL worktree remove: $worktree_path"; continue; }
  fi
  git branch -d "$branch" \
    || { echo "FAIL branch -d: $branch"; continue; }
  echo "PRUNED: $branch (worktree=$worktree_path, $disk_kb KB reclaimed)"
done
git worktree prune  # cleans up admin metadata
```

If `--apply --all-older-than <dur>`:
1. Require `--force` flag — abort if absent with message "destructive: requires --force".
2. Confirm count to user (one line, no AskUserQuestion in scripted contexts).
3. Use `git branch -D` (force delete) ONLY for `stale-divergent` / `stale-orphan` branches that exceed the age threshold.

Log every deletion to activity feed:
```
{"ts":"<ISO>","session":"<id>","skill":"worktree-prune","event":"branch_deleted","detail":{"branch":"...","reason":"safe-delete|forced-stale"}}
```

## Phase 5 — Report and Exit

```
worktree-prune complete: <N> branches deleted, <M> worktrees removed, <X> GB reclaimed
<P> branches preserved (stale-divergent or stale-orphan; rerun with --all-older-than to include)
```

Exit codes:
- `0` — success (including `--dry-run`)
- `1` — at least one deletion failed
- `2` — invalid arguments (e.g., `--apply --all-older-than` without `--force`)

## Safety rules

- **Never delete the current branch** (`git branch --show-current`).
- **Never delete `main`, `master`, `develop`, `release/*`, `hotfix/*`** — regex allowlist enforced.
- **Never delete a branch that has open PRs** — best-effort `gh pr list --head <branch> --state open` check; skip the branch with a warning if any PR is open.
- `git branch -d` (lowercase) refuses unmerged. Only `--apply --all-older-than` with `--force` uses `git branch -D`.

## Composition with the broader contract

- **Prevents recurrence:** spawn-time collision guard in `hooks/scripts/worktree-create.sh` blocks GH#51596 stale-branch reuse.
- **Reduces churn:** sprint-dev Phase 4.4 deletes `sprint-${N}/${role}` branches post-merge — this skill catches everything Phase 4.4 missed (mid-sprint aborts, harness branches outside blitz control).
- **Surfaces divergence:** `stale-divergent` rows are exactly the pattern that caused sprint-289/CAP-148 — review before deleting.

See [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md) for the full contract.
