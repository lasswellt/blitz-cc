# Doctor — reference

Check catalog, migration field maps, the `/verify` seed, and the conflict-catalog schema for `/blitz:doctor`. The SKILL.md body carries the phase order; this file carries the exact detectors and the migration mechanics.

---

## Check catalog

`fix:auto` marks a remediation `--fix` applies itself. Everything else is printed as a command or snippet. Ids are stable; the report table cites them.

### Plugin structure (Phase 1)

| Id | Detector | Severity | Remediation | Auto |
|---|---|---|---|---|
| D-101 | `scripts/validate-plugin-structure.sh` exit ≠ 0 | FAIL | Fix each listed path; the validator names it | no |
| D-102 | `jq -e . hooks/hooks.json` fails | FAIL | Repair the JSON; `config-change.sh` blocks commits on this too | no |
| D-103 | a script referenced by `hooks.json` is missing, not `-x`, or has no shebang | FAIL | `chmod +x hooks/scripts/<name>.sh`; a missing script is a broken install → reinstall the plugin | chmod only |
| D-104 | `skill-frontmatter-validate.sh --all` exit ≠ 0; cumulative descriptions > 14 000 chars | FAIL / WARN | Edit the named SKILL.md; the budget guard hard-fails at 14 500 | no |
| D-105 | `agent-frontmatter-validate.sh --all` exit ≠ 0 | FAIL | Edit the named agent file | no |
| D-106 | `markdown-link-validate.sh` reports broken links | WARN | Fix the link; hook mode only warns on commit | no |
| D-107 | `scripts/gen-catalog.sh --check` diff, dead `/blitz:<name>` reference, numeric inventory in prose | WARN | `scripts/gen-catalog.sh` and edit the prose it names | no |
| D-108 | `skills/<dir>/` without `SKILL.md` | WARN | Remove the stale directory or add the file | no |
| D-109 | `scripts/detect-stack.sh` prints nothing | WARN | Add the lockfile / manifest the detector keys on, or write stack commands into `verify[]` by hand | no |

### Session state (Phase 2)

| Id | Detector | Severity | Remediation | Auto |
|---|---|---|---|---|
| D-201 | `test -f .cc-sessions/STOP` | FAIL (verdict UNHEALTHY) | `rm .cc-sessions/STOP` — an operator put it there; confirm with them first | no |
| D-202 | `blitz_session_stale <record> "$VIEW"` true for a `status: active` record | WARN | next `SessionStart` sweep closes it; `--fix` closes it now (`status: failed`, `failed_reason: stale_session_cleanup`, `state: ended`) | yes |
| D-203 | `sessions/<sid>/gate.json` with record `state: ended` or no record | WARN | `rm .cc-sessions/sessions/<sid>/gate.json` | yes |
| D-204 | `jq 'select(.status=="pending")' inbox.jsonl` count; `kind: escalation` older than 24 h | WARN / FAIL | `/blitz:next` (triage) or `/blitz:sessions attention` | no |
| D-205 | `wc -l activity-feed.jsonl` > 500 / > 1000 | WARN / FAIL | `/blitz:sessions prune` | no |
| D-206 | `ls .cc-sessions/quarantine/` non-empty | WARN | read each file, delete; never restore unread | no |
| D-207 | `HANDOFF.json` `ts` older than 24 h | INFO | `/blitz:sessions prune` | no |
| D-208 | `ls .cc-sessions/*-????????.json` (skill-minted v2 records) | WARN | `--migrate` step 5.3 | no |
| D-209 | `mailbox/<sid>.jsonl` whose record closed > 7 d | INFO | `/blitz:sessions prune` | no |
| D-210 | `disableAgentView: true` or `CLAUDE_CODE_DISABLE_AGENT_VIEW=1` | WARN | remove the setting; without the overlay the conflict matrix only sees records | no |

### Project setup (Phase 3)

| Id | Detector | Severity | Remediation | Auto |
|---|---|---|---|---|
| D-301 | conflict-catalog regex hit in a CLAUDE.md scope; `wc -l CLAUDE.md` > 200; procedural feed text | catalog severity / WARN | the catalog `fix`; trim CLAUDE.md to conventions | no |
| D-302 | a required tool in `permissions.deny`, or absent from a non-empty `permissions.allow` | FAIL / WARN | edit `permissions` in the settings file that carries it | no |
| D-303 | type-check / lint / test / build unresolvable | FAIL (type-check with tsconfig) / WARN | add the `package.json` script: `"typecheck": "tsc --noEmit"`, `"lint": "eslint ."`, `"test": "vitest run"`, `"build": "<bundler>"` | no |
| D-304 | `jq -r '.worktree.baseRef // "fresh"' .claude/settings.json` ≠ `head` | FAIL | `jq -s '.[0] * .[1]' .claude/settings.json <(echo '{"worktree":{"baseRef":"head"}}')` → write back | yes |
| D-305 | `subagentPromptCacheTtl` ≠ `"1h"` | WARN | merge `{"subagentPromptCacheTtl": "1h"}` | yes |
| D-306 | `crossSessionInbound` absent while `.claude/loop.md`, a `claude -p` loop script (`grep -rl 'claude -p' scripts/ *.sh` at the root), or a Routine prompt is present | WARN | `{"crossSessionInbound": "accept"}` for `-p` workers, `"hold"` for Routines | no |
| D-307 | Task tools; no detector beyond D-104/D-105 | INFO | none needed; `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` only for the platform checklist UI | no |
| D-308 | `command -v bash` fails, or `uname -s` is not Linux/Darwin/MINGW/MSYS/CYGWIN and hooks are configured | FAIL | Git for Windows or WSL; hooks fail open without bash | no |
| D-309 | `git check-ignore -q docs/sweeps/ratchet.json` | FAIL | delete the `docs/sweeps/` line from `.gitignore`; `git add docs/sweeps/ratchet.json` | yes |
| D-310 | `test -d docs/plans && test -d docs/solutions` | WARN | `mkdir -p docs/plans docs/solutions` | yes |
| D-311 | `git check-ignore -q .cc-sessions/x` fails | FAIL | append `.cc-sessions/` to `.gitignore` | yes |
| D-312 | `tasks.json`: `$schema` ≠ `blitz-tasks/1.0`; `status: done` without `passes ∧ last_verify.ok`; empty `verify[]` | FAIL | `tasks.sh set <plan> <id> status=open attempts=0` then `tasks.sh verify <plan> <id>`; re-add tasks with checks | no |
| D-313 | `origin` ∉ `{plan, audit, check, learn, issue:<n>}` | WARN | note the old value, re-add through `tasks.sh add … --origin plan` | no |

Settings precedence for D-304…D-306: `.claude/settings.local.json` over `.claude/settings.json` over `~/.claude/settings.json`; the finding names the file the key would be added to (project `.claude/settings.json` by default, so the whole team inherits it).

---

## Migration (`--migrate`)

All `tasks.json` writes go through `scripts/tasks.sh` with `BLITZ_TASKS_GUARD_OFF` unset. Doctor never opens `tasks.json` with `Write` or `Edit`.

### 5.1 Story → task

Input: every `sprints/sprint-N/stories/*.md` whose frontmatter `status` is not `done` or `dropped`. Parse the frontmatter with `awk '/^---$/{c++; next} c==1{print}'` and read fields with a YAML-aware step (python3 `yaml.safe_load` when present, else line-based for the flat keys used here).

| Story field | Task field | Rule |
|---|---|---|
| `id` (`S1-003`, `G001`) | `--id` | verbatim; the plan slug is `sprint-N` |
| `title` | `--title` | verbatim, ≤80 chars |
| `files[]` | `--files a,b` | comma-joined; empty list → task gets `files: []` and a `notes` line "no files declared in v2" (build --parallel will exclude it) |
| `depends_on[]` | `--depends` | ids within the same sprint only; a cross-sprint id goes into `notes` |
| `assigned_agent` | `--role` | `backend-dev→backend`, `frontend-dev→frontend`, `infra-dev→infra`, `test-writer→test`; unknown → omitted |
| `verify[]` | `--verify-cmd "<cmd>::120"` | each entry verbatim, 120 s timeout (300 s when it matches the test-runner regex) |
| `acceptance_checks[]` | extra `--verify-cmd` | same translation table as carry-forward acceptance below (`file` scopes the grep) |
| `status` | `status` | `in-progress→in_progress`, `blocked→blocked` (with `blocked_reason: circuit-breaker` and the story's `blocker` text in `notes`), `planned→open` |
| `done`, `epic`, `points`, `research_refs`, `github_issue` | `notes` | one line each, so nothing is lost; `github_issue: N` also sets `--origin issue:N` |
| everything else | dropped | `registry_entries`, `design_quality`, `source_finding`, `carry_forward` |

Non-test rule: `tasks.sh add` refuses a `verify[]` made only of test runners. When the story's `verify` and `acceptance_checks` yield nothing else, derive one check from the title: take the first word of the title longer than 3 chars that is not in `{create, add, update, implement, fix, remove}` as `<kw>`, and add `--verify-cmd "grep -cE '<kw>' <first file> | awk '\$1>=1'::10"`. When there is no file to grep, pass `--test-only-ok` and write `notes: "v2 story had test-only verification; add a structural check"`.

`spec.md` for the plan:

```yaml
---
status: paused
priority: P1          # P0 when any story priority is high, P2 when all are low
created: <today>
ship: manual
---
# sprint-N (migrated from v2)
Stories migrated: <ids>. Review, then set `status: active` to let `next` pick it up.
```

`progress.md` gets one entry: `## <ts> doctor migrate — N stories → tasks`. A `plan.md` is not written; the v2 story bodies stay under `sprints/` (gitignored) and `notes` points at them.

### 5.2 Carry-forward → tasks

Reduce the registry first (field-merge, not `max_by`):

```bash
jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x)) | .[] | select(.status=="active" or .status=="partial")' \
  .cc-sessions/carry-forward.jsonl
```

Plan slug `carry-forward`, task ids `T-001`… in `ts` order, `--origin plan`, title = `scope.description` (fallback `id`), `notes` = `"<id> from <source.doc>#<source.anchor>; coverage <coverage>; parent <parent.capability>/<parent.epic>"`. `files` stays empty unless `scope.unit == files` and the description lists paths.

Acceptance translation (`<root>` = `src/` when it exists, else `.`):

| `scope.acceptance` entry | `verify[]` command |
|---|---|
| `{"grep_absent": "<regex>"}` | `! grep -rnE '<regex>' <root>` |
| `{"grep_present": {"pattern": "<regex>", "min": M}}` | `grep -rcE '<regex>' <root> \| awk -F: '{s+=$2} END {exit !(s>=M)}'` |
| `{"shell": "<command>"}` | `<command>` verbatim |
| `{"ast_absent": "<query>"}` | dropped; `notes` gains `"ast_absent not portable: <query>"` |
| story `acceptance_checks` with `file` | same, with `<file>` in place of `-r <root>`; `assert_eq: "0"` on a `shell` check becomes `test "$(<command>)" = "0"` |

An entry with no translatable check gets `--test-only-ok` plus a `notes` line; the report lists it under "needs a real check".

### 5.3 Legacy session records

`.cc-sessions/<skill>-<8hex>.json` and `cli-<8hex>.json` were skill-minted before hooks owned records. They are deleted after `jq -e .` confirms nothing in them is still `status: active` with a live overlay row (that case is reported, not deleted). The feed keeps their history; nothing rewrites feed `session` values in v3.

### 5.4 Ratchet re-baseline

```bash
R=docs/sweeps/ratchet.json; cp "$R" "$R.pre-migrate.$(date -u +%Y%m%dT%H%M%SZ)"
STALE=$(git worktree list --porcelain | awk '/^worktree .*\/.claude\/worktrees\//{w=1} /^branch /{if(w){print $2}; w=0}' | wc -l)
jq --arg ref "$(git rev-parse HEAD)" --argjson n "$STALE" '
  ."$schema" = "blitz-ratchet/1.0"
  | .ref = $ref | .plan = null | del(.sprint)
  | .metrics.stale_worktree_branch_count = {baseline:$n, current:$n, max_allowed:$n, direction:"down"}
  | .updated_at = (now|todate)' "$R" > "$R.tmp" && mv "$R.tmp" "$R"
```

Other metrics keep their `baseline`/`current`/threshold; `history[]` is not rewritten. Missing file → run the bootstrap snippet in [/_shared/quality.md](/_shared/quality.md) §Ratchet instead.

### 5.5 Registries and sprints/

`sprint-registry.json`, `roadmap-registry.json`, `epic-registry.json` and the `sprints/` tree are left untouched with one `INFO`. Deleting them is a human decision after the migrated plans are reviewed; no v3 skill reads them.

### Verification after migration

1. Phase 3.7 (D-312, D-313) on every written `tasks.json`.
2. `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/startup-validate.sh"` — quarantine of a migrated file means the story text tripped the injection scan; report the path, do not edit the quarantined copy.
3. `scripts/next-state.sh` must list the new plans under `paused_plans`.

Report: `Migration: <n> plans, <n> tasks (<n> test-only), <n> legacy records removed, ratchet re-baselined | partial: <ids>`.

---

## Verify recipe (`--verify-recipe`)

The bundled `/verify` (user-only, CC ≥2.1.200) records how to build, run, and check the project at `.claude/skills/verify/SKILL.md` on its first run and replays it afterwards; `check` reads that file for the app-level rung. Seeding it is optional and only done on request; never overwrite an existing file.

```bash
if [ ! -f .claude/skills/verify/SKILL.md ]; then
  STACK=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh" 2>/dev/null)
  PM=$(jq -r '.packageManager // "npm"' package.json 2>/dev/null | cut -d@ -f1)
  TEST_CMD=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
  BUILD_CMD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)
  DEV_CMD=$(jq -r '.scripts.dev // .scripts.start // empty' package.json 2>/dev/null)
  mkdir -p .claude/skills/verify
  cat > .claude/skills/verify/SKILL.md <<MD
---
name: verify
description: Build, run, and confirm this project's changes work (seeded by /blitz:doctor from stack detection; refine as the project changes).
disable-model-invocation: true
---
# Verify recipe

Stack: ${STACK:-unknown}

1. Typecheck: \`${PM:-npm} exec tsc --noEmit\` (skip when no tsconfig.json).
2. Tests: \`${PM:-npm} run ${TEST_CMD:+test}${TEST_CMD:-test} -- --reporter=dot\` — for a targeted subset use \`\${CLAUDE_PLUGIN_ROOT}/scripts/test-selector.sh <changed files>\`.
3. Build: \`${PM:-npm} run ${BUILD_CMD:+build}${BUILD_CMD:-build}\`.
4. Run: \`${PM:-npm} run ${DEV_CMD:+dev}${DEV_CMD:-dev}\` and open the printed URL; confirm the changed screen renders without console errors (Playwright MCP \`browser_snapshot\` when available).
5. Report the command outputs verbatim, not a summary.
MD
  echo "seeded .claude/skills/verify/SKILL.md — review and commit it"
fi
```

---

## Conflict catalog schema

File: `skills/doctor/assets/conflict-catalog.json`. Patterns are case-insensitive extended regexes applied line by line to each CLAUDE.md scope; `skills` names the v3 skills whose default behavior the rule collides with; `fix` is the remediation printed verbatim.

```json
{
  "type": "object",
  "required": ["version", "conflicts"],
  "properties": {
    "version": { "type": "string" },
    "conflicts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "patterns", "skills", "severity", "description", "fix"],
        "properties": {
          "id": { "type": "string" },
          "patterns": { "type": "array", "items": { "type": "string" } },
          "skills": { "type": "array", "items": { "type": "string" } },
          "severity": { "enum": ["HIGH", "MEDIUM", "LOW"] },
          "description": { "type": "string" },
          "fix": { "type": "string" }
        }
      }
    }
  }
}
```

Severity maps to the report as `HIGH → FAIL`, `MEDIUM → WARN`, `LOW → INFO`. Adding a conflict: one object, a `skills` list that names only skills present under `skills/`, and a `fix` that is a usage choice (doctor never edits CLAUDE.md).

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

## Phase 5: `--migrate` (v2 → v3)

Converts a v2 consumer project in place. Runs with `BLITZ_TASKS_GUARD_OFF` **unset**: every `tasks.json` write goes through `scripts/tasks.sh`, so the guard never needs to be lifted. Idempotent: a plan directory that already has `tasks.json` with the same ids is skipped, not duplicated. Step-by-step field mapping, the acceptance-check translation table and the ratchet re-baseline are in this file §Migration.

| Step | Input | Output |
|---|---|---|
| 5.1 Stories | `sprints/sprint-N/stories/*.md` with frontmatter `status ∉ {done, dropped}` | `docs/plans/sprint-N/spec.md` (`status: paused`, `priority` from the highest story priority, `created` today, `ship: manual`) and one `tasks.sh add sprint-N --id <story id> --title … --files … --depends … --origin plan --verify-cmd …` per story. `verify` comes from the story's `verify` list; when that list holds only test runners add `--verify-cmd "grep -cE '<title keyword>' <first file> \| awk '\$1>=1'"`, or pass `--test-only-ok` when no non-test check can be derived and say so in `notes`. |
| 5.2 Carry-forward | `.cc-sessions/carry-forward.jsonl` reduced by field-merge (`jq -s 'group_by(.id) \| map(sort_by(.ts) \| reduce .[] as $x ({}; . * $x))'`), entries with `status ∈ {active, partial}` | `docs/plans/carry-forward/{spec.md (paused), tasks.json}`, one task per entry (`--id T-<seq>`, title = `scope.description`, `--origin plan`, `notes` = `id` + `source.doc`), `verify` translated from `scope.acceptance`: `grep_absent` → `! grep -rnE '<regex>' <root>`, `grep_present` → `grep -rcE '<pattern>' <root> \| awk -F: '{s+=$2} END {exit !(s>=<min>)}'`, `shell` → as is, `ast_absent` → dropped with a `notes` line (no runner in v3). |
| 5.3 Legacy records | `.cc-sessions/<skill>-<8hex>.json`, `cli-<8hex>.json` | Removed (hook-owned records live at `.cc-sessions/sessions/<native id>.json`; the feed already carries the history). Count reported. |
| 5.4 Ratchet | `docs/sweeps/ratchet.json` with a `sprint` key | `sprint` → `ref` (`git rev-parse HEAD`) + `plan: null`; `stale_worktree_branch_count` recounted with the detector in quality.md and its `baseline`/`max_allowed` reset to that count; `"$schema": "blitz-ratchet/1.0"` set; `history[]` kept. Backup to `ratchet.json.pre-migrate.<ts>`. |
| 5.5 Registries | `sprint-registry.json`, `roadmap-registry.json`, `epic-registry.json`, `sprints/` | **Left in place.** Print one `INFO`: "v3 reads none of these; delete when the migrated plans have been reviewed. `sprints/` stays gitignored." |
| 5.6 Feed | `activity-feed.jsonl` | Untouched (schema unchanged). |

Before writing anything, print the plan of record: N stories → `docs/plans/sprint-N/` (M tasks), K carry-forward entries → `docs/plans/carry-forward/`, L legacy records to remove, ratchet keys to rewrite. Proceed without a prompt only when the invocation is autonomous (`next --loop` never calls doctor, so in practice ask once). After migration run Phase 3.7 on every new `tasks.json` and `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/startup-validate.sh"`; both must be clean or the migration reports `partial` with the failing ids. Migrated plans are `status: paused`: `next` ignores them until a human sets `status: active` in `spec.md`.

### 3.4 Settings for the loop (D-304…D-306)

Read `.claude/settings.json` (project) with `.claude/settings.local.json` overlaid, then `~/.claude/settings.json`.

| Id | Key | Expected | Severity | Remediation |
|---|---|---|---|---|
| D-304 | `worktree.baseRef` | `"head"` | **FAIL** when absent or `"fresh"` | `build --parallel` spawns `isolation: worktree` agents; the platform default branches them from `origin/<default>`, so every wave starts without the plan's own commits and the sequential merge conflicts. Add to `.claude/settings.json`: `{"worktree": {"baseRef": "head"}}` (`fix:auto`, merged with `jq -s '.[0] * .[1]'`). |
| D-305 | `subagentPromptCacheTtl` | `"1h"` | WARN | `build` and `check` spawn `dev` and `critic` repeatedly; the 1 h TTL keeps their system prompt cached across tasks. Add `{"subagentPromptCacheTtl": "1h"}` (`fix:auto`). |
| D-306 | `crossSessionInbound` | `accept` when `claude -p` loop workers are used; `hold` for Routines | WARN when a shell-loop script, a Routine prompt or `.claude/loop.md` exists and the key is absent | `-p` workers cannot read a held message before `dialogExpiry`, so a BLOCK from the conflict matrix never reaches them. Add `{"crossSessionInbound": "accept"}` for shell-loop workers, `"hold"` for Routine sessions ([sessions.reference.md](/_shared/sessions.reference.md) §5). Not auto-fixed: the right value depends on the runtime. |

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

## Phase 4: WRITERS

Each flag writes exactly one file, never overwrites without saying so, and prints the path. All are skipped without their flag.

| Flag | Writes | Source | Overwrite |
|---|---|---|---|
| `--loop-md` | `.claude/loop.md` | `cp "${CLAUDE_PLUGIN_ROOT}/templates/loop.md" .claude/loop.md` | Replaces an existing file only if it already contains `/blitz:next --loop`; otherwise prints the diff and asks. Bare `/loop` then runs the blitz tick ([loop.reference.md](/_shared/loop.reference.md) §Running the loop); a user-level `~/.claude/loop.md` loses to the project file. |
| `--review-md` | `REVIEW.md` | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-review-md.sh" --write REVIEW.md` | Always: the file is derived from `check-registry.json` P0/P1 rows ([quality.reference.md](/_shared/quality.reference.md) §REVIEW.md export); commit it. |
| `--ci` | `.github/workflows/blitz-check.yml` | `mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/blitz-check.yml" .github/workflows/blitz-check.yml` | Never overwrites; prints a diff when present. Then remind: add the `ANTHROPIC_API_KEY` secret (or swap in the OAuth token line per the file's comments); fork PRs get no secrets. |
| `--verify-recipe` | `.claude/skills/verify/SKILL.md` | the seeding snippet in this file §Verify recipe, filled from stack detection and `package.json` | Never overwrites. The bundled `/verify` records its own recipe on its first run, so seed only when the user asks for it before running `/verify`; `check` reads whichever exists. |

After each write: `INFO` finding with the path, and a feed `decision` line.

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

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
