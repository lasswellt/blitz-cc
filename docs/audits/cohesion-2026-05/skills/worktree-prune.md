---
unit: skills/worktree-prune
kind: skill
verdict: needs-tightening
removable_lines: 12
created: 2026-05-28
---

# Audit: worktree-prune

## A. Identity & Boundaries

**Purpose:** Inventory and safely delete stale git worktrees + agent-spawned branches that accumulate from blitz `Agent({isolation: "worktree"})` and harness auto-naming.

**Description vs body match:** Accurate. Flags, modes, and branch patterns in description match body exactly. No drift.

**Overlaps:**

| Skill / Hook | Overlap area | Duplication vs layering |
|---|---|---|
| `hooks/scripts/worktree-remove.sh` | Best-effort single-branch cleanup on WorktreeRemove | Legitimate layering — hook is opportunistic, skill is on-demand batch |
| `sprint-dev` Phase 4.4 | Deletes `sprint-${N}/${role}` post-merge | Legitimate layering — sprint-dev handles known branches on clean path; skill catches missed/aborted branches |
| `sprint-review` Phase 3.6 Invariant 8 | Asserts sprint-dev Phase 4.4 cleaned up | Legitimate — review asserts; prune remediates |
| `ratchet-protocol.md` Invariant 6 `stale_worktree_branch_count` | Counts same branch patterns | Legitimate — ratchet measures; prune reduces |

No true duplication found. Every overlap is deliberate layering per `worktree-lifecycle.md`.

---

## B. Cohesion

**_shared protocols cited:**

| Protocol | Cited? | Followed or restated? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0) | Delegates via link — no inline restatement |
| `verbose-progress.md` | No explicit cite | Activity-feed log format in Phase 4 matches spec — implicit follow |
| `terse-output.md` | Yes — OUTPUT STYLE snippet present verbatim line 12 | Invariant 5 satisfied |
| `worktree-lifecycle.md` | Yes — §Composition + footer | Delegates; no restatement |
| `state-handoff.md` | Not cited | Skill is read-only except for deletions; no artifact produced — omission acceptable |
| `story-frontmatter.md` | Not cited | Correct — skill is operational, not sprint-pipeline |
| `ratchet-protocol.md` | Not cited | Acceptable — skill reduces the metric; it doesn't measure it |

**OUTPUT STYLE snippet:** Present verbatim at line 12. Invariant 5 — PASS.

**Cross-refs live:**
- `/_shared/worktree-lifecycle.md` — verified exists
- `/_shared/session-protocol.md` — verified exists
- `hooks/scripts/worktree-create.sh` — referenced in §Composition; path exists (verified via `ratchet-protocol.md` + `worktree-lifecycle.md` cites)

**Pipeline chain (dry-run → apply):**
- Produces: human-readable table + activity-feed `branch_deleted` events
- Consumes: git working tree state, `origin/HEAD`
- Downstream: `ratchet-protocol.md` Invariant 6 reads `stale_worktree_branch_count` from git — skill's deletions reduce that count directly. Chain is correct.

---

## C. Conciseness

**Body line count:** 160 — well under 500-line cap.

**Anti-laziness prose (candidates for deletion):**

Line 107: `"Run with '--apply --merged-only' to delete the 22 safe targets. No changes made."`
— Defensive "remind the user what to run" nudge. With Opus 4.8 honesty gains, the `--dry-run` mode's output table makes the next command self-evident. The dry-run call-to-action adds ~1 line of instruction that the model would emit anyway from context. Low value; mark for trimming.

Line 127–128 (`--apply --all-older-than`): `"Confirm count to user (one line, no AskUserQuestion in scripted contexts)."` — This is a defensive "don't use interactive prompts in automation" guard. With 4.8 reasoning fidelity, this is model-behavior nudging that the context (flags like `--force` + `--apply` already signal scripted mode) makes redundant. Removable.

**Content that belongs in shared protocol:**
- Phase 0 log format (lines 37-39) duplicates the format already specified in `verbose-progress.md`. Only the `skill` field value is skill-specific. ~3 lines redundant.
- Phase 4 `branch_deleted` log format (lines 132-134) — same issue, ~3 lines.

**Estimated removable lines:** ~12 (2 prose nudges + ~8 inline log format restatements that could reduce to "log per verbose-progress.md §event-types").

---

## D. Modernization

**Native primitive overlap (platform-delta.md citations):**

1. `git worktree prune` is a native git command (line 122). Blitz calls it as a cleanup step — correct delegation, not reimplementation.

2. `claude agents` TUI (platform-delta.md v2.1.139 / 2026-05-11): provides one-screen view of running/blocked/done sessions. Does NOT replace worktree-prune — the TUI shows live sessions, not stale leftover branches from terminated sessions. **Keep as-is.**

3. Native workflows (platform-delta.md v2.1.154+): parallel subagent orchestration. Worktree-prune is single-agent sequential — no native workflow would replace it. **No delegation target.**

4. `disallowed-tools` frontmatter (platform-delta.md v2.1.152): `allowed-tools: Read, Bash, Glob, Grep` is already minimal. Adding `disallowed-tools` would be redundant — the allowlist already locks the tool surface. No change needed.

**`model: sonnet` + `effort: low`:** Correct. Task is bash-heavy enumeration + table rendering, not reasoning. Sonnet at low effort is appropriate. No model upgrade warranted.

**No prose guards convertible to `disallowed-tools`:** The safety rules (never delete main, never delete open-PR branches) are behavioral logic, not tool lockdown. Cannot be replaced by frontmatter.

---

## E. Correctness

**Version ref `compatibility: ">=2.1.71"`:** No specific 2.1.71 feature relied on in the body. `git worktree list --porcelain` and `git for-each-ref` are standard git, not CC-version gated. The `>=2.1.71` floor is probably a blitz-default placeholder. Not harmful but imprecise.

**Branch patterns (lines 61-63):** Match `worktree-lifecycle.md` taxonomy exactly — VERIFIED.

**`git branch -d` safety:** Correct — lowercase `-d` refuses unmerged; `-D` only under `--force` path. Matches `worktree-lifecycle.md` Invariant 2 contract.

**`gh pr list` check (line 151):** Uses `--head <branch>` which requires the branch to exist on the remote. Local-only branches (never pushed) will return empty — PR check will silently pass. Minor gap but acceptable for the stated "best-effort" contract.

**`sprint-289/CAP-148` reference (line 158):** Internal incident reference — no stale version number, not a dead link. OK.

**Subagents-cannot-spawn-subagents constraint:** Skill does not spawn agents. Dynamic Workflows (platform-delta.md v2.1.154+) irrelevant here.

**Dead env vars:** `BLITZ_ALLOW_WORKTREE_COLLISION`, `BLITZ_SKIP_BRANCH_CLEANUP` defined in `worktree-lifecycle.md` and referenced only in §Composition — consistent. No dead vars.

---

## F. Verdict

`needs-tightening`

**Top edits (highest leverage):**

1. **Remove inline log-format restatements** (lines 37-39, 132-134). Replace with `"Log per verbose-progress.md §event-types; skill field = 'worktree-prune'."` Saves ~6 lines, eliminates drift risk.

2. **Drop anti-laziness nudges** (lines 107 and 127-128). The dry-run table and `--force` flag make these self-evident to Opus 4.8. Saves ~3-4 lines.

3. **Tighten `compatibility` floor or document why `>=2.1.71`**. If it's a placeholder, reset to `>=2.1.128` (zip support era) or document the actual dependency. Prevents false confidence in older CC installs.
