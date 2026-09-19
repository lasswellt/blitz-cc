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

Run in order; each command is one finding on non-zero exit.

```bash
P="${CLAUDE_PLUGIN_ROOT:-.}"
bash "$P/scripts/validate-plugin-structure.sh"                         # D-101 plugin layout
jq -e . "$P/hooks/hooks.json" >/dev/null                               # D-102 hooks.json parses
jq -r '.. | .command? // empty' "$P/hooks/hooks.json" | grep -oE 'scripts/[^ "]+\.sh' | sort -u | while read -r s; do
  f="$P/hooks/$s"
  [ -f "$f" ] || { echo "MISSING $s"; continue; }
  [ -x "$f" ] || echo "NOT-EXECUTABLE $s"
  head -1 "$f" | grep -q '^#!' || echo "NO-SHEBANG $s"
done                                                                   # D-103 hook scripts
bash "$P/hooks/scripts/skill-frontmatter-validate.sh" --all </dev/null # D-104 SKILL.md lint (+ cumulative description budget)
bash "$P/hooks/scripts/agent-frontmatter-validate.sh" --all </dev/null # D-105 agents
bash "$P/hooks/scripts/markdown-link-validate.sh" </dev/null           # D-106 links
bash "$P/scripts/gen-catalog.sh" --check                               # D-107 catalog fresh, no dead /blitz: refs
for d in "$P"/skills/*/; do [ -f "$d/SKILL.md" ] || echo "NO-SKILL-MD $d"; done   # D-108
```

`D-103` misses are `FAIL` (`chmod +x hooks/scripts/<name>.sh` is the fix, `fix:auto`). `D-104`/`D-105` violations are `FAIL`; a cumulative-description figure above 14 000 chars is `WARN`. `D-107` is `WARN` (run `scripts/gen-catalog.sh`).

`detect-stack.sh` must print something (`D-109`): an empty result means stack-dependent skills (`build`, `check`) will guess commands.

---

## Phase 2: SESSION STATE

Everything under `.cc-sessions/` is hook-owned and untrusted (TB-2). Doctor counts, it does not repair unless `--fix`.

| Id | Check | Severity | Remediation |
|---|---|---|---|
| D-201 | `.cc-sessions/STOP` exists | **FAIL, printed first and last** | Kill switch is on: every tool call in every session under this root is denied by `kill-switch.sh`. `rm .cc-sessions/STOP` when you mean it. Doctor itself cannot run tools while it exists, so this finding normally arrives from a hook message. |
| D-202 | `status: active` records whose `last_activity` > 30 min with no live overlay row, or `started` > 4 h | WARN | The `SessionStart` sweep closes them on the next session; `--fix` runs `blitz_session_stale` per record now and marks them `failed/stale_session_cleanup`. |
| D-203 | `.cc-sessions/sessions/<sid>/gate.json` whose record is `state: ended` or missing | WARN | Orphan Stop gate: `rm` it (`fix:auto`). A gate for a live session is left alone. |
| D-204 | `inbox.jsonl` lines with `status: pending` — count, oldest age, `kind` histogram | WARN when >0; FAIL when any `kind: escalation` is older than 24 h | `/blitz:next` triages; `/blitz:sessions attention` lists them. |
| D-205 | `activity-feed.jsonl` > 500 lines | WARN (>1000: FAIL) | `/blitz:sessions prune`; retention rule in sessions.md §9. |
| D-206 | `quarantine/` non-empty | WARN | Review each file, then delete; never move it back without reading it. |
| D-207 | `HANDOFF.json` older than 24 h | INFO | `/blitz:sessions prune` removes it. |
| D-208 | legacy `.cc-sessions/<skill>-<8hex>.json` or `cli-<8hex>.json` records | WARN | `--migrate` removes them (Phase 5.3). |
| D-209 | `mailbox/<sid>.jsonl` whose target record is closed > 7 d | INFO | `/blitz:sessions prune`. |
| D-210 | `disableAgentView: true` in settings or `CLAUDE_CODE_DISABLE_AGENT_VIEW=1` | WARN | Conflict matrix and stale sweep degrade to records only. |

```bash
S=.cc-sessions; . "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/common.sh"
[ -f "$S/STOP" ] && echo "D-201 FAIL kill switch present"
VIEW=$(blitz_agent_view)
for r in "$S"/sessions/*.json; do [ -f "$r" ] && jq -e '.status=="active"' "$r" >/dev/null && blitz_session_stale "$r" "$VIEW" && echo "D-202 stale $r"; done
for g in "$S"/sessions/*/gate.json; do [ -f "$g" ] || continue; sid=$(basename "$(dirname "$g")")
  jq -e '.state!="ended"' "$S/sessions/$sid.json" >/dev/null 2>&1 || echo "D-203 orphan gate $g"; done
jq -c 'select(.status=="pending") | {kind, ts}' "$S/inbox.jsonl" 2>/dev/null | jq -s 'group_by(.kind) | map({kind: .[0].kind, n: length, oldest: (map(.ts)|min)})'
wc -l < "$S/activity-feed.jsonl" 2>/dev/null
ls "$S"/*-????????.json 2>/dev/null   # D-208 legacy records
```

---

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

Read `.claude/settings.json` (project) with `.claude/settings.local.json` overlaid, then `~/.claude/settings.json`.

| Id | Key | Expected | Severity | Remediation |
|---|---|---|---|---|
| D-304 | `worktree.baseRef` | `"head"` | **FAIL** when absent or `"fresh"` | `build --parallel` spawns `isolation: worktree` agents; the platform default branches them from `origin/<default>`, so every wave starts without the plan's own commits and the sequential merge conflicts. Add to `.claude/settings.json`: `{"worktree": {"baseRef": "head"}}` (`fix:auto`, merged with `jq -s '.[0] * .[1]'`). |
| D-305 | `subagentPromptCacheTtl` | `"1h"` | WARN | `build` and `check` spawn `dev` and `critic` repeatedly; the 1 h TTL keeps their system prompt cached across tasks. Add `{"subagentPromptCacheTtl": "1h"}` (`fix:auto`). |
| D-306 | `crossSessionInbound` | `accept` when `claude -p` loop workers are used; `hold` for Routines | WARN when a shell-loop script, a Routine prompt or `.claude/loop.md` exists and the key is absent | `-p` workers cannot read a held message before `dialogExpiry`, so a BLOCK from the conflict matrix never reaches them. Add `{"crossSessionInbound": "accept"}` for shell-loop workers, `"hold"` for Routine sessions ([sessions.md](/_shared/sessions.md) §5). Not auto-fixed: the right value depends on the runtime. |

### 3.5 Platform facts (D-307, D-308)

- **D-307 Task tools** — advisory `INFO` on current models: `TaskCreate/Get/Update/List` and `TodoWrite` are off unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. v3 never uses them (`docs/plans/<slug>/tasks.json` is the task list). Print the variable only as "set it if you want the platform's own checklist UI; blitz does not need it". A skill or agent in this checkout that lists a Task tool in `allowed-tools`/`tools` is `FAIL` (Phase 1 D-104/D-105 already catch it).
- **D-308 bash** — `command -v bash` must succeed. Hooks are bash scripts; on native Windows without Git Bash or WSL every hook fails **open** (the anti-shortcut guards, `tasks-guard.sh`, `stop-gate.sh` and the kill switch silently do nothing). `FAIL` on Windows (`uname -s` matches `MINGW|MSYS|CYGWIN` is fine; PowerShell-only is not; a PowerShell tool needs hook matcher `Bash|PowerShell`). Remediation: install Git for Windows or run under WSL; there is no PowerShell port of the hooks.

### 3.6 Repository layout (D-309…D-311)

| Id | Check | Severity | Remediation |
|---|---|---|---|
| D-309 | `docs/sweeps/` is ignored (`git check-ignore -q docs/sweeps/ratchet.json`) | FAIL | `ratchet.json` is memory that compounds across plans and must be tracked. Remove the `docs/sweeps/` line from `.gitignore` (`fix:auto`), then `git add docs/sweeps/ratchet.json`. Missing `ratchet.json` is WARN → `/blitz:onboard` or the bootstrap snippet in [quality.md](/_shared/quality.md) §Ratchet. |
| D-310 | `docs/plans/` and `docs/solutions/` exist | WARN | `mkdir -p docs/plans docs/solutions` (`fix:auto`). `plan` creates them too; `next-state.sh` treats an absent `docs/plans/` as "nothing open". |
| D-311 | `.gitignore` covers `.cc-sessions/` | FAIL | Runtime state and session records would be committed. Append `.cc-sessions/` (`fix:auto`). |

### 3.7 tasks.json shape (D-312, D-313)

For every `docs/plans/*/tasks.json`:

```bash
for f in docs/plans/*/tasks.json; do [ -f "$f" ] || continue
  jq -e '."$schema"=="blitz-tasks/1.0"' "$f" >/dev/null || echo "D-312 $f: bad \$schema"
  jq -r '.tasks[] | select(.status=="done" and (.passes!=true or .last_verify.ok!=true)) | .id' "$f" | sed "s|^|D-312 $f done-without-evidence |"
  jq -r '.tasks[] | select(((.verify // []) | length)==0) | .id' "$f" | sed "s|^|D-312 $f empty-verify |"
  jq -r '.tasks[] | select((.origin // "") | test("^(plan|audit|check|learn|issue:[0-9]+)$") | not) | .id' "$f" | sed "s|^|D-313 $f unknown-origin |"
done
```

`D-312` is `FAIL`: a `done` task without `passes ∧ last_verify.ok` means something bypassed `tasks.sh` (`tasks-guard.sh` disabled, or a hand edit under `BLITZ_TASKS_GUARD_OFF=1`). Remediation: `scripts/tasks.sh set <plan> <id> status=open attempts=0` then `scripts/tasks.sh verify <plan> <id>`; doctor never rewrites `tasks.json` directly. `D-313` is `WARN`: `startup-validate.sh` rejects unknown `origin` values, so the task will be quarantined at the next start; set it with `tasks.sh set <plan> <id> notes="origin was <x>"` and re-add with a known origin.

---

## Phase 4: WRITERS

Each flag writes exactly one file, never overwrites without saying so, and prints the path. All are skipped without their flag.

| Flag | Writes | Source | Overwrite |
|---|---|---|---|
| `--loop-md` | `.claude/loop.md` | `cp "${CLAUDE_PLUGIN_ROOT}/templates/loop.md" .claude/loop.md` | Replaces an existing file only if it already contains `/blitz:next --loop`; otherwise prints the diff and asks. Bare `/loop` then runs the blitz tick ([loop.md](/_shared/loop.md) §Running the loop); a user-level `~/.claude/loop.md` loses to the project file. |
| `--review-md` | `REVIEW.md` | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-review-md.sh" --write REVIEW.md` | Always: the file is derived from `check-registry.json` P0/P1 rows ([quality.md](/_shared/quality.md) §REVIEW.md export); commit it. |
| `--ci` | `.github/workflows/blitz-check.yml` | `mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/blitz-check.yml" .github/workflows/blitz-check.yml` | Never overwrites; prints a diff when present. Then remind: add the `ANTHROPIC_API_KEY` secret (or swap in the OAuth token line per the file's comments); fork PRs get no secrets. |
| `--verify-recipe` | `.claude/skills/verify/SKILL.md` | the seeding snippet in [references/main.md](references/main.md) §Verify recipe, filled from stack detection and `package.json` | Never overwrites. The bundled `/verify` records its own recipe on its first run, so seed only when the user asks for it before running `/verify`; `check` reads whichever exists. |

After each write: `INFO` finding with the path, and a feed `decision` line.

---

## Phase 5: `--migrate` (v2 → v3)

Converts a v2 consumer project in place. Runs with `BLITZ_TASKS_GUARD_OFF` **unset**: every `tasks.json` write goes through `scripts/tasks.sh`, so the guard never needs to be lifted. Idempotent: a plan directory that already has `tasks.json` with the same ids is skipped, not duplicated. Step-by-step field mapping, the acceptance-check translation table and the ratchet re-baseline are in [references/main.md](references/main.md) §Migration.

| Step | Input | Output |
|---|---|---|
| 5.1 Stories | `sprints/sprint-N/stories/*.md` with frontmatter `status ∉ {done, dropped}` | `docs/plans/sprint-N/spec.md` (`status: paused`, `priority` from the highest story priority, `created` today, `ship: manual`) and one `tasks.sh add sprint-N --id <story id> --title … --files … --depends … --origin plan --verify-cmd …` per story. `verify` comes from the story's `verify` list; when that list holds only test runners add `--verify-cmd "grep -cE '<title keyword>' <first file> \| awk '\$1>=1'"`, or pass `--test-only-ok` when no non-test check can be derived and say so in `notes`. |
| 5.2 Carry-forward | `.cc-sessions/carry-forward.jsonl` reduced by field-merge (`jq -s 'group_by(.id) \| map(sort_by(.ts) \| reduce .[] as $x ({}; . * $x))'`), entries with `status ∈ {active, partial}` | `docs/plans/carry-forward/{spec.md (paused), tasks.json}`, one task per entry (`--id T-<seq>`, title = `scope.description`, `--origin plan`, `notes` = `id` + `source.doc`), `verify` translated from `scope.acceptance`: `grep_absent` → `! grep -rnE '<regex>' <root>`, `grep_present` → `grep -rcE '<pattern>' <root> \| awk -F: '{s+=$2} END {exit !(s>=<min>)}'`, `shell` → as is, `ast_absent` → dropped with a `notes` line (no runner in v3). |
| 5.3 Legacy records | `.cc-sessions/<skill>-<8hex>.json`, `cli-<8hex>.json` | Removed (hook-owned records live at `.cc-sessions/sessions/<native id>.json`; the feed already carries the history). Count reported. |
| 5.4 Ratchet | `docs/sweeps/ratchet.json` with a `sprint` key | `sprint` → `ref` (`git rev-parse HEAD`) + `plan: null`; `stale_worktree_branch_count` recounted with the detector in quality.md and its `baseline`/`max_allowed` reset to that count; `"$schema": "blitz-ratchet/1.0"` set; `history[]` kept. Backup to `ratchet.json.pre-migrate.<ts>`. |
| 5.5 Registries | `sprint-registry.json`, `roadmap-registry.json`, `epic-registry.json`, `sprints/` | **Left in place.** Print one `INFO`: "v3 reads none of these; delete when the migrated plans have been reviewed. `sprints/` stays gitignored." |
| 5.6 Feed | `activity-feed.jsonl` | Untouched (schema unchanged). |

Before writing anything, print the plan of record: N stories → `docs/plans/sprint-N/` (M tasks), K carry-forward entries → `docs/plans/carry-forward/`, L legacy records to remove, ratchet keys to rewrite. Proceed without a prompt only when the invocation is autonomous (`next --loop` never calls doctor, so in practice ask once). After migration run Phase 3.7 on every new `tasks.json` and `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/startup-validate.sh"`; both must be clean or the migration reports `partial` with the failing ids. Migrated plans are `status: paused`: `next` ignores them until a human sets `status: active` in `spec.md`.

---

## Phase 6: `--fix`

Applies only remediations tagged `fix:auto` above (D-103 chmod, D-203 orphan gates, D-304/D-305 settings keys, D-309/D-311 `.gitignore`, D-310 mkdir) and D-202 stale records. Each fix: backup where a file is rewritten (`<file>.pre-doctor.<ts>`), apply, re-run the check, log a feed `decision` `{choice: "fix D-nnn", reason}`. Settings edits merge with `jq` and preserve unknown keys; never touch `permissions`. Anything not tagged `fix:auto` stays a printed remediation.

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
