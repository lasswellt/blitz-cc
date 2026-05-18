# Proposed Epics — Audit 2026-05-17

Source: `docs/audits/audit-20260517.md`. Themes clustered by domain + pillar. Priority = impact ÷ effort (rough heuristic, security-weighted).

---

## EPIC-A01: Hook performance — async + scope guards

**Pillar**: Performance (primary), Robustness (secondary)
**Priority**: 39 (highest)
**Impact**: 39 (1 Critical + 5 High in performance + 2 High in robustness)
**Effort**: Small (3-5 hook scripts + 1 hooks.json edit + atomic-write helper)
**Findings**: 8 — perf-hooks #1-7, robust-hooks #1, #4

### Description
The Write|Edit hot path runs 3-11 s of synchronous hook latency per edit, dominated by a full `tsc --noEmit` (no async flag, no tsconfig scope filter, no `--incremental`) plus two `--all` frontmatter validators that re-scan all 39 SKILL.md and all 10 agent .md on every edit regardless of file type. Concurrent edits also race the typecheck baseline file, silently resetting the ratchet floor.

### Proposed Stories
1. Add `"async": true` to `post-edit-typecheck-block.sh` entry in `hooks/hooks.json`.
2. Switch `post-edit-typecheck-block.sh` to `tsc --incremental` and add a `tsc --listFilesOnly | grep -qF "$FILE_PATH"` pre-check to skip excluded files.
3. Make `typecheck-baseline.json` writes atomic (tmp+mv) with a `flock` around the read-tsc-write sequence.
4. Add file-path guard to `skill-frontmatter-validate.sh` and `agent-frontmatter-validate.sh`: exit 0 early unless edited path matches `skills/*/SKILL.md` (or `agents/*.md`). Mark both `async: true`.
5. Merge `post-edit-format.sh` + `post-edit-lint.sh` discovery (one `find_project_root` + one `package.json` parse, cache the toolchain in `.cc-sessions/toolchain-cache.json` invalidated on mtime).
6. Replace `post-edit-test.sh` python3 JSON extraction with `jq -r`.

### Success Criteria
- Cumulative PostToolUse latency on a non-TS markdown edit: <100 ms.
- Cumulative PostToolUse latency on a TS edit (warm tsc cache): <500 ms.
- Ratchet `type_errors` baseline survives concurrent Write A + Write B without clobber.

### Dependencies
None.

---

## EPIC-A02: Hook script standardization + JSON safety library

**Pillar**: Security (primary), Maintainability, Robustness
**Priority**: 33 (high; security-weighted)
**Impact**: 33 (3 High in security incl. prompt-injection chain + 2 High in maintainability + 1 High in robustness)
**Effort**: Medium (new `hooks/scripts/_lib/common.sh`, refactor 8-15 scripts, add bats tests)
**Findings**: 8 — sec-bash #1, #2, sec-bash Info, maint-bash #1, #2, #4, #5, robust-hooks #3

### Description
Three problems share a single root cause: 8-15 hook scripts hand-roll their own `extract()`, `find_project_root()`, session-id generation, and JSONL writes via `grep`/`sed` + bare `echo "{...$VAR...}"`. This produces (a) maintenance burden from triplicated code with already-visible divergence, (b) silent failures from missing `-e` in `set -uo pipefail` (8 scripts), and (c) a security-critical activity-feed corruption channel that chains into a persistent prompt-injection vector via `blitz-prompt-expansion.sh` re-injecting feed lines as `additionalContext`. Additionally, `session-start.sh:80` interpolates an attacker-influenced ISO string into `python3 -c "...'$iso'..."` → RCE.

### Proposed Stories
1. Create `hooks/scripts/_lib/common.sh` exporting: `blitz_find_root`, `blitz_extract` (jq-based), `blitz_session_id`, `blitz_log_event` (jq -n --arg builder), `blitz_atomic_write`.
2. Refactor 8-15 scripts to source `_lib/common.sh`. Delete inlined copies.
3. Replace all `echo "{...$VAR...}"` JSONL writes with `blitz_log_event`. Specifically: `post-edit-activity-log.sh:54-56`, `subagent-start.sh:32`, `subagent-stop.sh:31`, `task-completed-validate.sh:55`, `worktree-create.sh:45,54`.
4. Replace `python3 -c "...$iso..."` in `session-start.sh:80` with `python3 -c "..." "$iso"` (argv passing).
5. Add `set -euo pipefail` to all 8 scripts currently missing `-e`.
6. Add bats tests under `hooks/tests/`: `extract` edge cases (escaped quotes, embedded newlines, nested JSON), `find_project_root` boundary cases, blocker exit-2 paths for `block-no-verify.sh` + `block-destructive-git.sh`.
7. Strip `BLITZ_GEMINI_FLAGS` word-split in `critic-gemini.sh:39` — switch to `mapfile -t GEMINI_FLAGS < <(printf '%s\n' "${BLITZ_GEMINI_FLAGS:-}")` (one flag per line) and remove the shellcheck suppression.

### Success Criteria
- Activity-feed entries always valid JSONL even with filenames containing `"`, `\`, or newlines (verify via bats fuzz tests).
- `extract()` test fixtures cover nested-quote JSON values that today silently truncate.
- No `python3 -c "...$variable..."` patterns remain in `hooks/scripts/`.
- shellcheck (with `-e SC2086 -e SC2046`) passes on all hook scripts.

### Dependencies
Bats-core install path (declare in README or `installer/`).

---

## EPIC-A03: Installer correctness + supply-chain default

**Pillar**: Architecture (primary), Security
**Priority**: 28
**Impact**: 28 (2 High + 3 Medium spanning Architecture + Security)
**Effort**: Small (5 single-line/single-config changes)
**Findings**: 5 — arch-infra #1, #2, #6, sec-permissions #2, #3

### Description
The bash fallback installer clones `lasswellt/blitz.git` but the actual repo is `lasswellt/cc-plugin-suite`. The version-floor warning fires at <2.1.71 but the orchestrator main-thread agent (the v1.13+ headline feature) requires ≥2.1.117 — users on 2.1.71-2.1.116 install cleanly with no warning while orchestrator silently never activates. The installer writes `autoUpdate: true` unconditionally with no opt-in prompt — supply-chain risk if upstream is compromised. The pre-approved `Bash(git push *)` permission glob covers `--force` and `--force-with-lease`.

### Proposed Stories
1. Fix `installer/install.sh:13` `REPO_URL` → `https://github.com/lasswellt/cc-plugin-suite.git`.
2. Fix `installer/package.json:8` `repository.url` to match.
3. Update `installer/install.sh:66-73` version gate to ≥2.1.117 with a clear warn distinguishing "agent teams" (2.1.71) from "orchestrator main-thread agent" (2.1.117).
4. Change `autoUpdate` default to `false` in both `installer/src/marketplace.js:19` and `installer/install.sh:117`. Add an opt-in prompt ("Enable automatic updates from GitHub? [y/N]").
5. Narrow `Bash(git push *)` in `installer/src/constants.js:37` to `Bash(git push origin HEAD)` + `Bash(git push --no-force *)`. Add `Bash(git push --force *)` and `Bash(git push -f *)` to deny list.
6. Sync `installer/package.json` version + description to v1.14.0 / 39 skills. Add to release checklist.

### Success Criteria
- `bash install.sh` on a clean machine without Node clones the correct repo.
- A user on Claude Code 2.1.100 sees a clear "orchestrator not available" warning at install time.
- New installs do not silently subscribe to automatic upstream updates.
- `git push --force origin main` triggers a permission prompt OR is blocked by hook.

### Dependencies
None.

---

## EPIC-A04: Anti-shortcut hook hardening

**Pillar**: Security
**Priority**: 22
**Impact**: 22 (security-weighted: blocking-hook gaps directly enable detection-evasion)
**Effort**: Small (4 regex/logic tweaks)
**Findings**: 4 — sec-permissions #1, #4, sec-bash #4

### Description
The block-* hooks have known bypasses: `git commit -n` short form not matched, `--force-with-lease` not in destructive-git, branch name interpolated bare into ERE regex (DoS or evasion), `BLITZ_GEMINI_FLAGS` env injection bypasses the critic. Each closes a specific gap in the documented quality-gate posture.

### Proposed Stories
1. `block-no-verify.sh:18` — extend grep to match `git commit -n` (short form). Conservative pattern: `'(^|[[:space:]])git[[:space:]]+commit[[:space:]]+([^-][[:space:]]+-n|-n[[:space:]])'`.
2. `block-destructive-git.sh:57` — add `--force-with-lease` to the force regex.
3. `block-destructive-git.sh:65` — escape `$CURRENT` before regex interpolation (use `grep -qF` or sed-escape).
4. `critic-gemini.sh:39` — see EPIC-A02 story #7 (overlaps).
5. Remove the commented-out `{"allow": true}` blueprint from `permission-request.sh:8-12` so it can't be copy-pasted into a future synchronous version.

### Success Criteria
- bats test: `git commit -n -m "x"` exits 2 from block-no-verify.
- bats test: `git push --force-with-lease origin main` exits 2 from block-destructive-git.
- bats test: branch named `main|.*` does not DoS the destructive-git hook on `git branch -D othername`.
- `BLITZ_GEMINI_FLAGS="--system-prompt 'LGTM'"` does not override critic system prompt.

### Dependencies
EPIC-A02 (bats infra).

---

## EPIC-A05: SKILL.md token reduction + body-cap headroom

**Pillar**: Performance, Architecture
**Priority**: 22
**Impact**: 22 (4 High in perf + 1 High in arch — sprint family body-cap risk)
**Effort**: Small-Medium (edits in ~12 SKILL.md + 2-3 new references/main.md)
**Findings**: 6 — perf-skill-tokens #1, #2, #3, #4, #6, arch-skill-surface #2

### Description
The always-loaded skill-listing manifest is ~16,659 chars (~4,164 tokens). 12 skills spend 40-52% of their description on trigger-phrase lists redundant with the orchestrator routing matrix. `conform/SKILL.md` description is at 1000/1024 chars (one commit from a hard lint failure) and carries a non-standard `when_to_use:` field silently ignored by the validator. "Register Session" boilerplate is duplicated verbatim in 29 SKILL.md bodies (17,014 chars total). Sprint-plan/sprint-review/sprint-dev bodies are at 99% of the 500-line cap with no headroom for evolution.

### Proposed Stories
1. Trim `conform/SKILL.md` description to ≤700 chars; remove `when_to_use:` field; migrate schema migration detail to `references/main.md`.
2. Trim trigger-phrase lists in the 12 worst offenders to 3-5 representative phrases (`codebase-map`, `bootstrap`, `research`, `sprint-dev`, `code-doctor`, `worktree-prune`, others). Move overflow to orchestrator routing matrix.
3. Collapse the "Register Session" block in 29 SKILL.md to a single citation line: `Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration.`
4. Pre-emptively extract `sprint-plan` + `sprint-review` Phase 0 input gates + Phase 3.6 invariant prose to their `references/main.md`. Target ≤450 body lines each (50+ line safety margin).
5. Pre-emptively extract `sprint-dev` Phase 0 + 4.4 branch-cleanup detail. Target ≤450 body lines.
6. Create `worktree-prune/references/main.md` for skill-specific deep detail; trim SKILL.md description.

### Success Criteria
- Total description bytes <14,500 (≥10% reduction).
- All SKILL.md bodies ≤450 lines (50-line safety margin under cap).
- `skill-frontmatter-validate.sh --all` exits 0.
- `conform` description has no `when_to_use:` field.

### Dependencies
None — but coordinate with any in-flight sprint that touches sprint-plan/review/dev.

---

## EPIC-A06: Skill error-recovery + autonomous-loop robustness

**Pillar**: Robustness
**Priority**: 19
**Impact**: 19 (3 High + 4 Medium)
**Effort**: Medium (edits in 5-6 SKILL.md + STATE.md parser validator)
**Findings**: 7 — robust-skill #1, #2, #3, #4, #5, #6, #9

### Description
High-stakes sprint skills delegate Error Recovery entirely to `references/main.md` — under context compression in `--loop` mode, the recovery path may be skipped. `sprint-dev` SPRINT_NUMBER derivation can silently produce an empty string if `sprint-registry.json` lacks `.current_sprint`. STATE.md resume has no parser validation — corrupted/half-written/version-mismatched files can duplicate completed stories. `roadmap` Phase 0 is prose ("inform and STOP"), not a hard-fail bash gate. `sprint-review` re-run has no idempotency guard.

### Proposed Stories
1. Inline critical Error Recovery bullets directly in `sprint-dev/SKILL.md`, `sprint-review/SKILL.md`, `sprint-plan/SKILL.md` (agent-down, merge-conflict, registry-lock timeout, build-baseline-fail). Keep `references/main.md` as extended reference.
2. Add `[ -n "${SPRINT_NUMBER}" ]` guard in `sprint-dev/SKILL.md:60` Phase 0.0 gate.
3. Add STATE.md validator step to `_shared/checkpoint-protocol.md`: verify sprint number in heading matches `SPRINT_NUMBER`, require at least one `## Completed Stories` section, on parse failure treat as "no STATE.md" and restart fresh.
4. Replace `roadmap` Phase 0 prose with a bash hard-fail block matching sprint-plan's pattern.
5. Add idempotency check to `sprint-review` Phase 4.1: if `review-report.md` exists AND registry shows `status: reviewed` + `review_status: PASS`, prompt user (autonomy≥high: skip and print "already reviewed — rerun with --force").
6. Add corrupt-JSON validation cases to `sprint-plan` Error Recovery (`jq -e .` on roadmap/epic registries; clear hard-fail on stale registry locks).
7. Add a "schema drift → run `/blitz:conform --fix`" pointer in `sprint-dev`/`sprint-review` Error Recovery sections.

### Success Criteria
- `/blitz:next --loop` survives a corrupted STATE.md without duplicating completed stories.
- `roadmap` without research docs exits with non-zero status under autonomy=full.
- `sprint-review` re-run on a PASSed sprint doesn't re-apply auto-fixes.

### Dependencies
None.

---

## EPIC-A07: Orchestrator routing completeness

**Pillar**: Architecture
**Priority**: 18
**Impact**: 18 (3 High + 1 Medium)
**Effort**: Medium (orchestrator.md edits + 2 stack-detection bash blocks)
**Findings**: 4 — arch-skill-surface #1, #4, #6

### Description
Orchestrator subagent classification (§1 hard constraint) covers 26 of 39 skills — 12 are missing (`bootstrap`, `codebase-map`, `compress`, `implement`, `migrate`, `release`, `retrospective`, `roadmap`, `setup`, `ship`, `ui-build`, `worktree-prune`). Freeform requests matching these skills have no classification signal. `worktree-prune` is also missing from the routing matrix (§2). `perf-profile` + `code-doctor` are routed universally but hardwired to Vue/Nuxt/Firestore — silent degradation on non-Vue projects.

### Proposed Stories
1. Add the 12 missing skills to the appropriate orchestrator classification list.
2. Add a row to orchestrator routing matrix §2 for `worktree-prune`: "clean up worktrees" | "stale branches" | "prune branches" → `/blitz:worktree-prune`.
3. Add Phase 0 stack-detection gate to `perf-profile/SKILL.md` and `code-doctor/SKILL.md`: detect non-Vue stack and hard-fail with "This skill requires a Vue/Nuxt project. Detected: <X>. See /blitz:codebase-audit for a stack-agnostic audit."
4. Update orchestrator routing to conditionally route perf-profile/code-doctor only when stack detection confirms Vue/Nuxt.

### Success Criteria
- Freeform "clean up worktrees" routes to `/blitz:worktree-prune`.
- `/blitz:perf-profile` on a non-Vue project hard-fails with stack-detection message instead of producing empty findings.

### Dependencies
None.

---

## EPIC-A08: SKILL.md contract gaps

**Pillar**: Maintainability
**Priority**: 17
**Impact**: 17 (2 High + 4 Medium)
**Effort**: Small-Medium
**Findings**: 6 — maint-skill-md #1, #2, #3, #4, #5, #6

### Description
The `pre-commit-validate.sh` version-drift gate calls `scripts/check-version-sync.sh` which doesn't exist on disk — the `-x` guard makes it silently no-op. `ui-audit/SKILL.md` ships with hardcoded stale sprint-6/E-009/CAP-011/CAP-012 IDs and a Phase 5 "no-op stub". `compress/SKILL.md` references `references/main.md` 3× but the file doesn't exist. CLAUDE.md says 36 hook scripts; disk has 37. OUTPUT STYLE verbatim copy in 49 files has no content-drift detection. `agents/orchestrator.md` `model: sonnet` contradicts user memory note.

### Proposed Stories
1. Restore `scripts/check-version-sync.sh` from git history OR remove all references and explicitly accept manual sync. Remove the `-x` guard so missing scripts fail loudly.
2. Strip sprint-6/E-009/CAP-011/CAP-012 references from `ui-audit/SKILL.md`. Either implement Phase 5 heuristics (move catalog from `references/patterns.md` if present) or remove the phase.
3. Fix `compress/SKILL.md` — either create `references/main.md` with the cited anchor procedure + large-file timeout lesson, or inline content into SKILL.md and remove the dead references.
4. Update CLAUDE.md hook-script count to match reality (37 or 36 after step 1).
5. Add OUTPUT STYLE content-drift detection: `skill-frontmatter-validate.sh` checksum-compares the snippet against canonical hash from `terse-output.md`. Optionally adopt marker-based transclude that `conform` can update.
6. Reconcile `agents/orchestrator.md` `model:` field with user memory note. Add comment explaining model choice rationale.

### Success Criteria
- `pre-commit-validate.sh` fails loudly when `check-version-sync.sh` is missing OR all references removed.
- `/blitz:ui-audit` does not advertise heuristics it cannot deliver.
- CLAUDE.md script count = actual disk count.
- Drift in OUTPUT STYLE block fails `skill-frontmatter-validate.sh`.

### Dependencies
None.

---

## EPIC-A09: Spawn-API + allowed-tools consistency

**Pillar**: Architecture, Maintainability
**Priority**: 9
**Impact**: 9 (3 Medium + 1 Low)
**Effort**: Small (3 SKILL.md edits + 1 doc update)
**Findings**: 4 — arch-skill-surface #5, #7, #8, #9

### Description
`doc-gen` still declares the v1 spawn API (`TeamCreate` + `SendMessage`) removed in v1.4.0 per `roadmap/references/main.md`. `ui-build` uses `AskUserQuestion` not declared in `allowed-tools`. `migrate` allowed-tools has `SendMessage` instead of `Agent` and is absent from `state-handoff.md`. `implement` and `review` thin aliases not consistently documented.

### Proposed Stories
1. Migrate `doc-gen/SKILL.md` to `Agent({subagent_type: ...})`; remove `TeamCreate`/`SendMessage` from allowed-tools; update spawn instructions per `_shared/spawn-protocol.md`.
2. Add `AskUserQuestion` to `ui-build/SKILL.md` allowed-tools.
3. Reconcile `migrate/SKILL.md` allowed-tools (`SendMessage` → `Agent`). Add `migrate` section to `state-handoff.md` documenting rollback branch + checkpoint artifacts. Add `migrate` to orchestrator spawn list (overlaps with EPIC-A07).
4. Document `implement` + `review` aliases in `_shared/quality-matrix.md` consistently, or deprecate `implement` if redundant.

### Success Criteria
- `doc-gen` successfully spawns workers under Claude Code ≥2.1.117.
- `ui-build` can call `AskUserQuestion` without runtime denial.
- `/blitz:next` can recommend `migrate` as a valid spawn-aware skill.

### Dependencies
None.

---

## Out-of-scope (low-priority observations)

- README hook blocking-scripts list (line 132) stale — quick doc fix.
- `UserPromptExpansion` matcher `blitz:.*` skips freeform orchestrator flows — design question, not necessarily a defect.
- `block-test-deletion.sh` wired twice intentionally — add an inline `_comment` for clarity.
- `_shared/` optional protocols not listed in CLAUDE.md dependency sections — discoverability improvement.

---

## Cross-Epic Notes

- EPIC-A02 and EPIC-A04 share the bats-test infrastructure dependency. Ship A02 first; A04's tests slot into the same harness.
- EPIC-A05 (token reduction) is best done alongside EPIC-A07 (orchestrator routing matrix) because trigger-phrase trimming moves content from descriptions into the routing table.
- EPIC-A03 (installer correctness) is the only epic that requires no in-repo skill work — can be done in parallel with everything else.
