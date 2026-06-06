# Worktree + Branch Lifecycle Contract

Canonical contract for `Agent({isolation: "worktree"})` and harness-auto worktrees in the blitz plugin. Source of truth for all branch hygiene. Referenced from [sprint-dev/SKILL.md](../sprint-dev/SKILL.md), [agent-orchestration.md](agent-orchestration.md), and [session-lifecycle.md](session-lifecycle.md).

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

4. **Resume divergence gate** (`sprint-dev/SKILL.md` Phase 0.1, [session-lifecycle.md](session-lifecycle.md)). Before re-spawning on an existing `sprint-${N}/${role}` branch, check `git rev-list --count <merge-base>..<branch>`. If non-zero, stop and prompt: `rebase` / `abandon` / `inspect`. In `autonomy=full` loops, behavior governed by `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`).

5. **Manual prune skill** ([../worktree-prune/SKILL.md](../worktree-prune/SKILL.md)). `/blitz:worktree-prune --dry-run` lists every `worktree-*` and `sprint-*/{role}` branch with age, merge-status, divergence, disk usage. `--apply --merged-only` deletes ancestors of `origin/HEAD`. `--apply --all-older-than 30d --force` includes unmerged stale branches.

6. **Live background-session guard** (`hooks/scripts/_lib/common.sh` `blitz_live_worktree_paths`, prune Phase 1.5). Any worktree path returned by `claude agents --json` is classified `live-bg` and is never removed — overrides merge-status, age, and `--force`. Prevents destroying a live background session's uncommitted work in `.claude/worktrees/<id>`. Best-effort: no-op when the `claude` CLI / `--json` is unavailable. See §Interop above.

## Interop with native agent view (background sessions)

Claude Code's agent view (`claude agents`, CC >=2.1.139, research preview) runs **background sessions** dispatched via `claude --bg` / `/bg`. Before editing files, the platform **auto-isolates each background session into its own `.claude/worktrees/<id>` worktree** — the same directory blitz `Agent({isolation:"worktree"})` worktrees live in. Two systems now create worktrees under `.claude/worktrees/`; this section reconciles them. Dispatch + alert details: [agent-orchestration.md](agent-orchestration.md). Provenance: `docs/_research/2026-05-30_parallel-claude-sessions.md`.

**Branch-naming distinction:**
- blitz-controlled: `worktree-agent-<8hex>`, `worktree-sprint-*`, `sprint-${N}/{role}` (taxonomy above).
- platform background-session worktrees: created + named by the supervisor under `.claude/worktrees/`, distinct from the `worktree-agent-<8hex>` agent-subagent naming. The blitz collision guard (invariant 1) is scoped to `worktree-agent-<8hex>` and therefore **does not false-abort** native background dispatch.

**Live-session data-loss guard (invariant 6, below):** a background session's `.claude/worktrees/<id>` holds **uncommitted work**. `/blitz:worktree-prune` and any cleanup MUST query `claude agents --json` and skip any worktree path it returns — classified `live-bg`, never removed, even under `--force`. Helper: `blitz_live_worktree_paths` (`hooks/scripts/_lib/common.sh`); best-effort, no-op when the CLI/`--json` is absent (older CC, Bedrock/Vertex, agent view disabled). Prune detail: [worktree-prune/SKILL.md](../worktree-prune/SKILL.md) Phase 1.5.

**Ratchet interop:** `stale_worktree_branch_count` ([quality-engine.md](quality-engine.md) §1) counts blitz-controlled branch refs only. A transient live background-session worktree may briefly inflate the count; this is a measurement-timing artifact, not a leak — do not auto-prune to "fix" it (the live-session guard forbids removal anyway).

**Owning isolation end-to-end:** when a skill (e.g. sprint-dev) needs to control isolation itself with explicit `sprint-${N}/{role}` branches and is being run as a background session, set `worktree.bgIsolation: "none"` in `.claude/settings.json` (CC >=2.1.143) so the platform does not double-isolate. Whether sprint-dev should adopt this by default vs. lean on platform isolation is an open design question — see the research doc §7.

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
| `worktree.bgIsolation` (`.claude/settings.json`, not env) | platform default | `"none"` disables native background-session auto-isolation into `.claude/worktrees/` (CC >=2.1.143) — use when a skill owns isolation itself |

## Sprint-review enforcement

Two interlocking checks fire in sprint-review Phase 3.6:

- **Invariant 8 — per-sprint branch hygiene**: asserts every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch was deleted by sprint-dev Phase 4.4. Any survivor → FAIL. Detector + escape hatch in [`sprint-review/references/main.md`](../sprint-review/references/main.md) §Invariant 8 — Branch Hygiene.
- **Invariant 6 metric `stale_worktree_branch_count`** — cross-sprint cumulative count of `worktree-agent-*`, `worktree-sprint-*`, and `sprint-*/{role}` branches. Ratchet-tightened (only goes down). Detector + baseline procedure in [`quality-engine.md`](quality-engine.md) §1.

Existing projects must run `code-sweep --baseline stale_worktree_branch_count` once before the first post-upgrade sprint-review, otherwise N pre-existing stale branches will fail Invariant 6 immediately. After baselining, every subsequent sprint must monotonically reduce or hold the count — `/blitz:worktree-prune --apply --merged-only` is the canonical reduction path.

## Cross-references

- Research provenance: `docs/_research/2026-05-17_worktree-lifecycle.md`
- Upstream bugs: GH#26725 (open), GH#55435 (open), GH#51596 (closed), GH#27749 (closed-stale), GH#31969 (open)
- Spawn protocol: [agent-orchestration.md](agent-orchestration.md) §Agent isolation
- State handoff contract: [session-lifecycle.md](session-lifecycle.md) §Worktree artifacts
- Checkpoint protocol: [session-lifecycle.md](session-lifecycle.md) §Resume validation
- Sprint-review invariants: [sprint-review/SKILL.md](../sprint-review/SKILL.md) Phase 3.6 (Invariants 6 + 8)
- Ratchet protocol: [quality-engine.md](quality-engine.md) (8 monotonic metrics)
