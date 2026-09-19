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
