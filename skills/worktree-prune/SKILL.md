---
name: worktree-prune
description: "Lists and safely deletes stale git worktrees + agent-spawned branches. --dry-run (default) reports age, merge-status, divergence, and disk usage. --apply --merged-only deletes origin-ancestor branches; --all-older-than 30d includes unmerged (requires --force). Use when the user says 'worktree prune', 'clean up worktrees', or notices leftover sprint-N/role branches."
argument-hint: "[--dry-run|--apply] [--merged-only|--all-older-than <duration>] [--force]"
allowed-tools: Read, Bash, Glob, Grep
disallowed-tools: Edit, Write, NotebookEdit
model: opus
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

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration. Log start:
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

### Phase 1.5 — Live background-session guard (DATA-LOSS PROTECTION)

Native agent view (`claude agents`, CC >=2.1.139) isolates each background session inside its own `.claude/worktrees/<id>` worktree, where **uncommitted work lives**. Those worktrees share the `.claude/worktrees/` dir with blitz `Agent({isolation:"worktree"})` worktrees, so a prune target may be a worktree a live session is actively using. Build the protected-path set BEFORE classifying:

```bash
# Absolute worktree paths owned by live background sessions. Best-effort:
# empty when `claude` CLI / --json absent (older CC, Bedrock/Vertex, agent view off).
LIVE_WT_PATHS=$(claude agents --json 2>/dev/null \
  | jq -r 'if type=="array" then .[]?.cwd // empty else empty end' 2>/dev/null || true)
# Hook scripts use the shared helper blitz_live_worktree_paths (_lib/common.sh).
```

Any branch whose `worktree_path` matches (equals or is under) a `LIVE_WT_PATHS` entry is classified `live-bg` (Phase 2) and is **never** removed — not by `--merged-only`, not by `--all-older-than --force`. See worktree-lifecycle.md §Interop.

## Phase 2 — Classify Each Branch

For each branch, compute:

| Field | How |
|---|---|
| `age_days` | `(now - committerdate_unix) / 86400` |
| `merged` | `git merge-base --is-ancestor <branch> origin/HEAD && echo true \|\| echo false` |
| `commits_ahead` | `git rev-list --count origin/HEAD..<branch>` |
| `worktree_path` | grep branch in `wt-prune-list.txt` → preceding `worktree` line |
| `worktree_exists` | `[ -d "$worktree_path" ]` |
| `live_bg` | `worktree_path` matches (equals or under) a `LIVE_WT_PATHS` entry (Phase 1.5) |
| `disk_kb` | `du -sk "$worktree_path" 2>/dev/null \|\| echo 0` (skip if no worktree) |
| `action` | per matrix below |

**Action matrix** (evaluated top-down; first match wins):

| live_bg | merged | worktree_exists | commits_ahead | age_days | Action |
|---|---|---|---|---|---|
| true | any | any | any | any | `live-bg` — owned by a live `claude agents` session; **never touch** |
| false | true | false | 0 | any | `safe-delete` — branch fully merged, no worktree |
| false | true | true | 0 | any | `remove-worktree-then-delete` — clean both |
| false | false | false | >0 | >threshold | `stale-orphan` — flag for review (no worktree, has commits) |
| false | false | true | >0 | >threshold | `stale-divergent` — flag for review (worktree exists, has unmerged commits) |
| false | false | true | >0 | <threshold | `active` — leave alone |

## Phase 3 — Render Report

Print one table (always, regardless of mode):

```
BRANCH                                  AGE     MERGED  AHEAD   WT      DISK    ACTION
sprint-289/backend                      14d     no      12      yes     412M    stale-divergent
sprint-289/frontend                     14d     no      8       no      —       stale-orphan
worktree-agent-aae6004a                 28d     yes     0       no      —       safe-delete
worktree-agent-7c5dcf5d                 1h      no      3       yes     180M    live-bg
worktree-sprint-291-plan                3d      yes     0       yes     220M    remove-worktree-then-delete
...

Summary: 48 branches matched | 18 safe-delete | 4 remove-worktree-then-delete | 23 stale-divergent | 2 active | 1 live-bg (protected)
Total disk reclaimable: 6.2 GB (live-bg worktrees excluded)
```

## Phase 4 — Apply (gated on `--apply`)

If `--dry-run` (default): print "Run with `--apply --merged-only` to delete the 22 safe targets. No changes made." and exit 0.

If `--apply --merged-only`:

```bash
# Safe path — only ancestors of origin/HEAD. action=live-bg rows are excluded
# by construction (never in {safe-delete, remove-worktree-then-delete}).
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
4. **Hard-skip `action=live-bg` rows even under `--force`** — `--force` overrides the age/merge gate, NOT the live-session guard. Removing a live background session's worktree destroys its uncommitted work.

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
- **Never remove a worktree owned by a live `claude agents` background session** (`action=live-bg`, Phase 1.5) — applies even under `--force`. Removing it destroys uncommitted work in `.claude/worktrees/<id>`.
- **Never delete `main`, `master`, `develop`, `release/*`, `hotfix/*`** — regex allowlist enforced.
- **Never delete a branch that has open PRs** — best-effort `gh pr list --head <branch> --state open` check; skip the branch with a warning if any PR is open.
- `git branch -d` (lowercase) refuses unmerged. Only `--apply --all-older-than` with `--force` uses `git branch -D`.

## Composition with the broader contract

- **Prevents recurrence:** spawn-time collision guard in `hooks/scripts/worktree-create.sh` blocks GH#51596 stale-branch reuse.
- **Reduces churn:** sprint-dev Phase 4.4 deletes `sprint-${N}/${role}` branches post-merge — this skill catches everything Phase 4.4 missed (mid-sprint aborts, harness branches outside blitz control).
- **Surfaces divergence:** `stale-divergent` rows are exactly the pattern that caused sprint-289/CAP-148 — review before deleting.

See [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md) for the full contract.
