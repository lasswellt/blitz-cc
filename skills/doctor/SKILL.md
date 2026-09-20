---
name: doctor
description: "Checks the plugin install and the project's setup, fixes drift, and writes helper files: hooks, session state, CLAUDE.md conflicts, worktree.baseRef, loop.md, REVIEW.md, CI workflow, v2 migration. Use for 'is blitz healthy', 'set up blitz', 'migrate from v2', 'hooks misfiring'."
argument-hint: "[--fix] [--migrate] [--loop-md] [--review-md] [--ci] [--verify-recipe]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
compatibility: ">=2.1.271"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort low. Set once (`claude --model opus --effort low` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

# Doctor

One skill for "is blitz installed correctly, is this project set up for it, and what should I fix". The surfaces:

| Surface | Phase | Writes |
|---|---|---|
| Plugin structure (hooks, frontmatter, validators) | 1 | never |
| Session state under `.cc-sessions/` | 2 | with `--fix` only |
| Project setup (CLAUDE.md, permissions, settings, stack, `docs/` layout, `tasks.json` shape) | 3 | with `--fix` only |
| Helper files (`.claude/loop.md`, `REVIEW.md`, CI workflow, `/verify` recipe) | 4 | with the named flag only |
| v2 → v3 migration (sprints, carry-forward, legacy records, ratchet) | 5 | with `--migrate` only |

Without flags `doctor` is read-only: it prints findings, a remediation per finding, and `Overall: HEALTHY|DEGRADED|UNHEALTHY`. Every remediation is a command or an exact JSON/YAML snippet, never "consider updating". The full check catalog with ids and detectors is in [references/main.md](references/main.md).

**Boundaries.** Runtime detail per session (who is blocked, inbox rows, dashboard) is `/blitz:sessions`; doctor only counts and flags. Code quality is `/blitz:check`; doctor never reads source. Project bootstrap (first `CLAUDE.md`, ratchet baseline, first plan) is `/blitz:onboard`; doctor verifies what onboard wrote.

---

## Phase 0: PREAMBLE

1. Claim the hook-created session record per [sessions.md](/_shared/sessions.md) §2 (`skill: doctor`, `working_on: "doctor <flags>"`); log `skill_start`. If `${CLAUDE_SESSION_ID}` is empty print `WARN: no native session id — running unregistered` and continue.
2. Run `startup-validate.sh` (sessions.md §2 step 5). Quarantined paths are surfaced as findings, never loaded.
3. Conflict matrix: doctor is read-only for the matrix (OK against everything). `--migrate` and `--fix` are the exceptions: BLOCK while any live `build`, `check --fix`, or `next --loop` record exists in this checkout — they read `tasks.json` and `.cc-sessions/` mid-flight.
4. Parse flags. Writers (`--loop-md`, `--review-md`, `--ci`, `--verify-recipe`) and `--migrate` run **after** Phases 1–3 so the report shows the state they started from. `--fix` applies the auto-fixable remediations marked `fix:auto` in the catalog and re-runs the affected check.
5. Findings accumulate as one record each: `{id, severity: FAIL|WARN|INFO, where, detail, fix}`. `FAIL` = a blitz skill will misbehave; `WARN` = degraded or advisory; `INFO` = a note. Text echoed from `.cc-sessions/`, CLAUDE.md or `tasks.json` is truncated to 200 chars and passed through `BLITZ_INJECTION_RX` ([security.md](/_shared/security.md) TB-1/TB-2). Never quote whole CLAUDE.md files: only the matched line.

---

## Phase 1: PLUGIN STRUCTURE

D-101…D-105: the plugin's own files load, hook scripts are executable, and no skill or agent lists a gated Task tool. Scans: [references/main.md](references/main.md) §Phase 1 PLUGIN STRUCTURE.

## Phase 2: SESSION STATE

D-201…D-203: session records parse and carry a known schema, no stale `active` record older than the timeout, no orphan `gate.json`. Scans and remediations: [references/main.md](references/main.md) §Phase 2 SESSION STATE.

## Phase 3: PROJECT SETUP

### 3.1 CLAUDE.md conflicts (D-301)

Scopes: `~/.claude/CLAUDE.md` (global), `./.claude/CLAUDE.md` (project-local), `./CLAUDE.md` (project); a missing file is not a finding. For each scope grep every `patterns[]` regex (case-insensitive) from `${CLAUDE_PLUGIN_ROOT}/skills/doctor/assets/conflict-catalog.json`; a hit is one finding `{id: <conflict id>, severity: <catalog severity>, where: <scope>:<line>, detail: <the matched line, sanitized>, fix: <catalog fix>}`. The match is heuristic; say so once in the report. `--fix` never edits CLAUDE.md (the rule is the user's; the fix is a usage choice). Also `WARN` when `./CLAUDE.md` exceeds 200 lines or contains procedural feed instructions (`grep -nE 'append.*activity-feed|jsonl line' CLAUDE.md`): steering guidance is that CLAUDE.md states conventions, hooks do procedure.

### 3.2 Tool permissions (D-302)

Read `permissions.allow` / `permissions.deny` from `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`. Required by blitz: `Agent`, `Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `Skill`, `ListAgents`, `SendMessage`, `ScheduleWakeup` (loop). `FAIL` when one is in `deny`; `WARN` when `allow` is non-empty and omits one (allowlist mode). Never list `TaskCreate`/`TodoWrite`: they are not required (3.5).

### 3.3 Stack commands (D-303)

From the Project Context block and `package.json` (or the detected equivalent), resolve the four commands blitz runs: type-check, lint, test, build. Each must resolve to a script or a known binary:

```bash
for s in typecheck type-check lint test build; do jq -e --arg s "$s" '.scripts[$s] // empty' package.json >/dev/null 2>&1 && echo "ok $s"; done
[ -f tsconfig.json ] && npx --no-install tsc --version >/dev/null 2>&1 || echo "tsc unresolved"
```

Missing type-check with a `tsconfig.json` is `FAIL` (the Stop gate arms `npx tsc --noEmit`); missing lint/test/build is `WARN` with the `package.json` script to add. A non-npm package manager (`pnpm-lock.yaml`, `bun.lockb`, `yarn.lock`) is `INFO`: verify commands are generated by `plan` from `packageManager`, so nothing breaks, but hand-written `verify[]` must use the same tool. UI stack without `impeccable` in `devDependencies` → `INFO` (`npm i -D impeccable@2.3.2` enables the rendered design lane in `check --only design`).

### 3.4 Settings for the loop (D-304…D-306)

`worktree.baseRef: "head"` (FAIL when absent), `subagentPromptCacheTtl: "1h"` (WARN), `crossSessionInbound` (WARN, value depends on the runtime). Rationale and the `jq` merges: [references/main.md](references/main.md) §3.4 Settings for the loop.

### 3.5 Platform facts (D-307, D-308)

- **D-307 Task tools** — advisory `INFO` on current models: `TaskCreate/Get/Update/List` and `TodoWrite` are off unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. v3 never uses them (`docs/plans/<slug>/tasks.json` is the task list). Print the variable only as "set it if you want the platform's own checklist UI; blitz does not need it". A skill or agent in this checkout that lists a Task tool in `allowed-tools`/`tools` is `FAIL` (Phase 1 D-104/D-105 already catch it).
- **D-308 bash** — `command -v bash` must succeed. Hooks are bash scripts; on native Windows without Git Bash or WSL every hook fails **open** (the anti-shortcut guards, `tasks-guard.sh`, `stop-gate.sh` and the kill switch silently do nothing). `FAIL` on Windows (`uname -s` matches `MINGW|MSYS|CYGWIN` is fine; PowerShell-only is not; a PowerShell tool needs hook matcher `Bash|PowerShell`). Remediation: install Git for Windows or run under WSL; there is no PowerShell port of the hooks.

### 3.6 Repository layout (D-309…D-311)

| Id | Check | Severity | Remediation |
|---|---|---|---|
| D-309 | `docs/sweeps/` is ignored (`git check-ignore -q docs/sweeps/ratchet.json`) | FAIL | `ratchet.json` is memory that compounds across plans and must be tracked. Remove the `docs/sweeps/` line from `.gitignore` (`fix:auto`), then `git add docs/sweeps/ratchet.json`. Missing `ratchet.json` is WARN → `/blitz:onboard` or the bootstrap snippet in [quality.reference.md](/_shared/quality.reference.md) §Ratchet. |
| D-310 | `docs/plans/` and `docs/solutions/` exist | WARN | `mkdir -p docs/plans docs/solutions` (`fix:auto`). `plan` creates them too; `next-state.sh` treats an absent `docs/plans/` as "nothing open". |
| D-311 | `.gitignore` covers `.cc-sessions/` | FAIL | Runtime state and session records would be committed. Append `.cc-sessions/` (`fix:auto`). |

### 3.7 tasks.json shape (D-312, D-313)

D-312 FAIL: a `done` task without `passes ∧ last_verify.ok` means something bypassed `tasks.sh`. D-313 WARN: unknown `origin`. Scan commands and remediation: [references/main.md](references/main.md) §3.7 tasks.json shape.

### 3.8 Worktree readiness (D-314, D-315)

`build --parallel` and `claude --worktree` both depend on platform-owned worktree creation. Blitz registers no `WorktreeCreate` hook ([agents.reference.md](/_shared/agents.reference.md) §6); a registered one replaces git creation entirely and skips `.worktreeinclude`.

```bash
# D-314 — stale agent branches ahead of origin/HEAD (GH#51596 collision source)
git for-each-ref --format='%(refname:short)' 'refs/heads/worktree-agent-*' 'refs/heads/worktree-build-*' |
  while read -r b; do
    n=$(git rev-list --count "origin/HEAD..$b" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] && echo "D-314 stale $b ($n ahead)"
  done

# D-315 — gitignored env files with no .worktreeinclude to carry them
git ls-files --others --ignored --exclude-standard -- '.env*' 'config/secrets*' 2>/dev/null | head -20
[ -f .worktreeinclude ] && echo "D-315 present"

# D-314b — a third-party WorktreeCreate hook in project settings takes over creation
jq -e '.hooks.WorktreeCreate' .claude/settings.json >/dev/null 2>&1 && echo "D-314 foreign WorktreeCreate hook"
```

| Id | Check | Severity | Remediation |
|---|---|---|---|
| D-314 | No `worktree-agent-*` / `worktree-build-*` branch is ahead of `origin/HEAD`, and no `WorktreeCreate` hook is configured in project settings | **WARN** (FAIL when `--parallel` is about to run) | A stale agent branch is silently reused by a colliding 8-hex id, carrying a prior session's commits into a new wave. Inspect with `/blitz:sessions worktrees`, remove with `--apply`, or set `BLITZ_ALLOW_WORKTREE_COLLISION=1` to proceed. A foreign `WorktreeCreate` hook must itself create the worktree and print its path, or every worktree in this project fails to create. |
| D-315 | `.worktreeinclude` exists when the repo has gitignored `.env*` or secrets files | WARN | A worktree is a fresh checkout, so gitignored config does not come with it and the isolated agent starts without credentials. Write `.worktreeinclude` listing the gitignored files found (`fix:auto`, never overwrites). `.gitignore` syntax; only files that match **and** are gitignored are copied. |

### 3.9 Toolchain and code intelligence (D-316, D-317)

```bash
# D-316 — which lanes actually resolve for this project's languages
bash "${CLAUDE_PLUGIN_ROOT}/scripts/toolchain.sh" lanes     # lane<TAB>stack<TAB>row-id
bash "${CLAUDE_PLUGIN_ROOT}/scripts/toolchain.sh" stacks

# D-317 — LSP binaries. The plugin configures the connection; the binary is
# yours to install. A server whose binary is missing shows as
# "Executable not found in $PATH" in the /plugin Errors tab.
for b in typescript-language-server pyright-langserver rust-analyzer gopls; do
  command -v "$b" >/dev/null 2>&1 && echo "D-317 ok $b" || echo "D-317 missing $b"
done
```

| Id | Check | Severity | Remediation |
|---|---|---|---|
| D-316 | Every detected stack resolves a `typecheck` row | **WARN** | A stack with no typecheck row has no diagnostic ratchet: `post-edit-typecheck-block.sh` cannot block a regression it cannot measure. Install the checker (`mypy`, `cargo`, `go`, `tsc`) or add a row to `templates/toolchain.default.json`. A stack with no `format`/`lint` row is `INFO`. |
| D-317 | Language-server binaries for the detected stacks are on `PATH` | **INFO** | Without one, the `LSP` tool stays inactive for that language and `research`/`onboard` fall back to grep. Install: `npm i -g typescript-language-server typescript`, `pip install pyright`, `rustup component add rust-analyzer`, `go install golang.org/x/tools/gopls@latest`. Two caveats: in **cloud sessions Claude Code does not start plugin language servers**, so LSP is inactive there whatever is installed; and when another enabled plugin declares the same extension, the first server registered wins and the other never starts (clear the matching `lsp_*` option in `/config` to yield). |

---

## Phase 4: WRITERS

Each flag writes exactly one file, never overwrites without saying so, and prints the path: `--loop-md`, `--review-md`, `--ci`, `--verify-recipe`, `--worktreeinclude`. Sources and overwrite rules: [references/main.md](references/main.md) §Phase 4 WRITERS.

## Phase 5: `--migrate` (v2 → v3)

Only with `--migrate`. Converts `sprints/<n>/stories/*.md` into `docs/plans/sprint-<n>/tasks.json` through `tasks.sh add`, carries forward active entries, removes legacy session records, and re-baselines the ratchet. Full conversion table: [references/main.md](references/main.md) §Phase 5 `--migrate`.

## Phase 6: `--fix`

Applies only remediations tagged `fix:auto` above (D-103 chmod, D-203 orphan gates, D-304/D-305 settings keys, D-309/D-311 `.gitignore`, D-310 mkdir, D-315 `.worktreeinclude`) and D-202 stale records. Each fix: backup where a file is rewritten (`<file>.pre-doctor.<ts>`), apply, re-run the check, log a feed `decision` `{choice: "fix D-nnn", reason}`. Settings edits merge with `jq` and preserve unknown keys; never touch `permissions`. Anything not tagged `fix:auto` stays a printed remediation.

---

## Phase 7: REPORT

```
Doctor — <project> (<plugin version>, CC <version>)
Plugin structure : PASS | FAIL (n)
Session state    : n active, n stale, inbox n pending, feed n lines, STOP: no
Project setup    : n FAIL, n WARN, n INFO
Writers          : loop.md written | REVIEW.md written | ci written | verify seeded | (none)
Migration        : n plans, n tasks, n legacy records removed | (not requested)

| Id | Severity | Where | Finding | Remediation |
|---|---|---|---|---|
| D-304 | FAIL | .claude/settings.json | worktree.baseRef absent | add {"worktree":{"baseRef":"head"}} |
| … |

Overall: HEALTHY | DEGRADED | UNHEALTHY
```

`UNHEALTHY` when any `FAIL` remains; `DEGRADED` when only `WARN`s; `HEALTHY` otherwise. `D-201` (kill switch) makes the verdict `UNHEALTHY` and is repeated as the last line before `Overall`. Ordered FAIL → WARN → INFO, then by id. Close the session record (`working_on: "done: <verdict>, n findings"`), log `skill_end` with `{status, summary}`.

**Next steps line** (one of): `Ready: /blitz:plan <goal>` (healthy, no plans), `Ready: /blitz:next` (healthy, plans exist), `Fix the FAIL rows, then re-run /blitz:doctor` (unhealthy).

---

## Additional Resources

- Check catalog (ids, detectors, `fix:auto` tags), migration field maps, verify-recipe seed, catalog schema: [references/main.md](references/main.md)
- Loop runtimes and headless rules: [/_shared/loop.md](/_shared/loop.md)
- Session records, inbox, mailbox, kill switch: [/_shared/sessions.md](/_shared/sessions.md)
- Ratchet schema and REVIEW.md export: [/_shared/quality.md](/_shared/quality.md)
- Trust boundaries for everything doctor reads: [/_shared/security.md](/_shared/security.md)
