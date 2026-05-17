# Worktree + Branch Lifecycle Contract

Canonical contract for `Agent({isolation: "worktree"})` and harness-auto worktrees in the blitz plugin. Source of truth for all branch hygiene. Referenced from [sprint-dev/SKILL.md](../sprint-dev/SKILL.md), [spawn-protocol.md](spawn-protocol.md), and [state-handoff.md](state-handoff.md).

## Why this exists

Without enforced cleanup, every sprint leaks 4-5 `sprint-${N}/{backend,frontend,tests,infra,integration}` branches plus 1-N harness-generated `worktree-agent-<8hex>` and `worktree-sprint-*-plan` branches. Production blitz-style projects have accumulated 30+ stale branches and 11 GB of `.claude/worktrees/` in 9 days (GH#55435). The same 8-hex agentId prefix collision (GH#51596) silently reuses stale branches, causing dual-implementation merge conflicts (root cause of blitz's sprint-289/CAP-148 incident).

## Branch naming taxonomy

| Pattern | Source | Blitz controls? |
|---|---|---|
| `sprint-${N}/{backend,frontend,tests,infra}` | sprint-dev Phase 2.3 | Yes — named explicitly |
| `sprint-${N}/integration` | sprint-dev Phase 3.5.1 | Yes |
| `sprint-${N}/merged` | sprint-dev Phase 4.1 | Yes |
| `worktree-agent-<8hex>` | Claude Code harness on `Agent({isolation: "worktree"})` | No — name hardcoded by platform (GH#27749 closed-stale, GH#31969 open) |
| `worktree-sprint-*-plan` | Harness auto-assignment for sprint-plan's background agents | No — sprint-plan does NOT use `isolation: "worktree"`, but the harness creates worktree branches anyway when calling context is a worktree |
| `worktree-<name>` | `claude --worktree <name>` CLI flag | User |

## Lifecycle invariants

1. **Spawn-time collision guard** (`hooks/scripts/worktree-create.sh`). If a `worktree-agent-<8hex>` branch already exists with commits ahead of `origin/HEAD`, the WorktreeCreate hook aborts with exit 1. Escape hatch: `BLITZ_ALLOW_WORKTREE_COLLISION=1`. Rationale: prevents GH#51596 silent stale-branch reuse.

2. **Post-merge branch deletion** (`sprint-dev/SKILL.md` Phase 4.4). After `git worktree remove`, sprint-dev runs `git branch -d sprint-${N}/${role}` for each role + the integration branch. Uses `-d` (refuses unmerged) not `-D`. Escape hatch: `BLITZ_SKIP_BRANCH_CLEANUP=1` preserves branches for forensic inspection.

3. **Opportunistic remove-hook cleanup** (`hooks/scripts/worktree-remove.sh`). On every WorktreeRemove event, if the removed worktree's branch matches `^(worktree-agent-|worktree-sprint-)` AND is an ancestor of `origin/HEAD`, delete the branch. Best-effort; never blocks.

4. **Resume divergence gate** (`sprint-dev/SKILL.md` Phase 0.1, [checkpoint-protocol.md](checkpoint-protocol.md)). Before re-spawning on an existing `sprint-${N}/${role}` branch, check `git rev-list --count <merge-base>..<branch>`. If non-zero, stop and prompt: `rebase` / `abandon` / `inspect`. In `autonomy=full` loops, behavior governed by `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`).

5. **Manual prune skill** ([../worktree-prune/SKILL.md](../worktree-prune/SKILL.md)). `/blitz:worktree-prune --dry-run` lists every `worktree-*` and `sprint-*/{role}` branch with age, merge-status, divergence, disk usage. `--apply --merged-only` deletes ancestors of `origin/HEAD`. `--apply --all-older-than 30d --force` includes unmerged stale branches.

## Hook event semantics (Claude Code)

| Event | Blocking? | Use case |
|---|---|---|
| WorktreeCreate | Yes — any non-zero exit aborts creation | Collision guard, path override (stdout) |
| WorktreeRemove | No — exit codes ignored (GH#31969 open to add blocking) | Logging, opportunistic branch cleanup |

The WorktreeCreate hook **cannot** override the branch name — Claude Code determines it before the hook fires. It CAN override the path by printing one to stdout.

## Escape hatches

| Env var | Default | Effect |
|---|---|---|
| `BLITZ_ALLOW_WORKTREE_COLLISION` | `0` | When `1`, WorktreeCreate hook permits stale-branch reuse |
| `BLITZ_SKIP_BRANCH_CLEANUP` | `0` | When `1`, sprint-dev Phase 4.4 and WorktreeRemove hook skip branch deletion |
| `BLITZ_RESUME_ON_DIVERGENCE` | `halt` | `prompt` (interactive), `abandon` (auto-delete branch + restart), `halt` (refuse) |

## Sprint-review enforcement

Two interlocking checks fire in sprint-review Phase 3.6:

- **Invariant 8 — per-sprint branch hygiene**: asserts every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch was deleted by sprint-dev Phase 4.4. Any survivor → FAIL. Detector + escape hatch in [`sprint-review/references/main.md`](../sprint-review/references/main.md) §Invariant 8 — Branch Hygiene.
- **Invariant 6 metric `stale_worktree_branch_count`** — cross-sprint cumulative count of `worktree-agent-*`, `worktree-sprint-*`, and `sprint-*/{role}` branches. Ratchet-tightened (only goes down). Detector + baseline procedure in [`ratchet-protocol.md`](ratchet-protocol.md) §1.

Existing projects must run `code-sweep --baseline stale_worktree_branch_count` once before the first post-upgrade sprint-review, otherwise N pre-existing stale branches will fail Invariant 6 immediately. After baselining, every subsequent sprint must monotonically reduce or hold the count — `/blitz:worktree-prune --apply --merged-only` is the canonical reduction path.

## Cross-references

- Research provenance: [docs/_research/2026-05-17_worktree-lifecycle.md](../../docs/_research/2026-05-17_worktree-lifecycle.md)
- Upstream bugs: GH#26725 (open), GH#55435 (open), GH#51596 (closed), GH#27749 (closed-stale), GH#31969 (open)
- Spawn protocol: [spawn-protocol.md](spawn-protocol.md) §Agent isolation
- State handoff contract: [state-handoff.md](state-handoff.md) §Worktree artifacts
- Checkpoint protocol: [checkpoint-protocol.md](checkpoint-protocol.md) §Resume validation
- Sprint-review invariants: [sprint-review/SKILL.md](../sprint-review/SKILL.md) Phase 3.6 (Invariants 6 + 8)
- Ratchet protocol: [ratchet-protocol.md](ratchet-protocol.md) (8 monotonic metrics)
