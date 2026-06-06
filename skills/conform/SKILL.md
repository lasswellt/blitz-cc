---
name: conform
description: Conforms blitz runtime artifacts to current canonical schemas. Detects drift in `.cc-sessions/`, sprint dirs, roadmap JSON, and research `scope:` blocks. Schema-version aware — migrates story frontmatter additively (adds `registry_entries` when a project adopts the carry-forward registry; `epic`/`verify` are canonical, never renamed) preserving project extensions. Read-only by default; `--fix` applies idempotent migrations. Use after upgrading blitz, when sprint-dev/review complains about schema fields, or when a forked plugin needs structural alignment. `--scope plugin` targets SKILL.md + hooks rather than runtime artifacts.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: low
argument-hint: "[target-dir] [--fix|--report-only] [--scope project|plugin|all] [--sample-mode]"
disable-model-invocation: false
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Conform

You are the conformance auditor + migration runner. You bring an existing **project's** blitz runtime artifacts (or a plugin **fork's** structure) into spec with the current canonical schemas defined in `skills/_shared/`.

**Verbose progress is mandatory.** Follow [terse-output.md](/_shared/terse-output.md). Print `[conform]` prefixed status lines at every phase transition, finding, and dispatch. Log `skill_start`, `audit_complete`, `migration_applied`, and `skill_complete` events to `.cc-sessions/activity-feed.jsonl`.

**Read-only by default.** Never write to the target without an explicit `--fix` argument. If `--fix` is omitted, end at Phase 6 (REPORT) — no migration ever runs.

## Two scopes

| Scope | Target | Use case |
|---|---|---|
| **`project`** (default) | `.cc-sessions/`, `sprints/`, `docs/roadmap/`, `docs/_research/`, `STATE.md` | A repo that uses blitz to run sprints. Brings runtime artifacts into spec after a plugin upgrade. |
| **`plugin`** | `skills/*/SKILL.md`, `skills/_shared/`, `hooks/`, `.claude-plugin/` | A blitz fork. Brings structure into spec (frontmatter, companion files, hook wiring). |
| **`all`** | both | Full sweep — uncommon. |

**Boundary vs health.** conform **repairs** (schema-version drift migration via `--fix`); `/blitz:health` **asserts** (read-only structural + runtime probe, no mutation). The plugin-scope frontmatter + hook-wiring checks overlap health by design — same validators, different verb. Runtime probes (sessions, locks, activity-feed, background agents) stay in health.

## Additional Resources

- For per-artifact schema versioning rules + migration tables (story frontmatter `registry_entries` additive migration, STATE.md formats, roadmap canonical-vs-extension table, session model variants), see [references/main.md](references/main.md)
- For the carry-forward registry schema, see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For the activity-feed JSONL schema, see [terse-output.md](/_shared/terse-output.md)
- For the canonical story frontmatter, see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For pipeline state handoff + STATE.md required fields, see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For autonomy field schema, see [session-lifecycle.md](/_shared/session-lifecycle.md) §Autonomy Levels
- For plugin-mode migration scripts, see [scripts/maint/v1.9.0/README.md](../../scripts/maint/v1.9.0/README.md)

---

## Phase 0: PARSE — Determine Target, Mode, Scope

1. **Register session.** Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

2. **Resolve target directory.** Default to `pwd`. If first positional arg is a directory path, use it. Reject paths outside `${HOME}` unless explicit `--allow-system-paths` flag passed.

3. **Determine mode.** `--fix` → audit + migrate. `--report-only` (default) → audit only.

4. **Determine scope.** `--scope project` (default) | `--scope plugin` | `--scope all`.

5. **Sample-mode autodetect.** If sprints/ has >50 entries OR total stories >300, switch to sample mode unless `--full` passed. In sample mode: audit all in latest 3 sprints + a **random sample of 10 older stories drawn uniformly across all older sprints** (not file-system order — use `find ... | shuf -n 10`). Remainder gets `INFO: not sampled` line in report. After auditing the sample, **extrapolate finding counts**: e.g., "86/100 sample stories lack `registry_entries` → projected ~876 of 1018 → MIGRATE finding for the population (add `registry_entries: []`)."

6. **Sanity check target.** Refuse to proceed unless target contains at least one of `.cc-sessions/`, `sprints/`, `.claude-plugin/plugin.json`, or `skills/*/SKILL.md`. Else exit `NOT_A_BLITZ_DIR`.

---

## Phase 1: DETECT — Inventory Target Artifacts

For each artifact, record **presence**, **count**, and **schema version** (where versioning applies). See `references/main.md` §Schema Detection Rules for the per-artifact version probes.

### Project-scope inventory

| Artifact | Probe | Optional? | Version probe |
|---|---|---|---|
| Activity feed | `.cc-sessions/activity-feed.jsonl` | yes | line schema (required fields present) |
| Carry-forward | `.cc-sessions/carry-forward.jsonl` | **yes** — only flag MISSING if other artifacts reference it | n/a |
| Developer profile | `.cc-sessions/developer-profile.json` | **yes** — only flag MISSING if a skill body or hook references it | autonomy field present? |
| Sessions | `.cc-sessions/<id>` (file OR dir) — accept both models | yes | dir vs file (record per session) |
| Orphan locks | `.cc-sessions/*.lock` not paired with active session | n/a | n/a |
| Sprints | `sprints/sprint-*/` | yes | manifest version field if present |
| Sprint manifests | `sprints/sprint-N/manifest.{json,md}` | per-sprint | shape |
| Stories | `sprints/sprint-N/stories/*.md` | per-sprint | **canonical = `epic`+`verify`(+`registry_entries`); pre-registry stories lack `registry_entries`** — see references/main.md §Story Schema Versions. `epic`/`verify` are canonical names, NOT renamed. |
| STATE.md | `sprints/sprint-N/STATE.md`, `STATE.md` (root) | per-sprint | **field-form vs table-form** — try both parsers |
| Roadmap (canonical) | the 6 files: `capability-index.json`, `epic-registry.json`, `phase-plan.json`, `domain-index.json`, `ROADMAP.md`, `gap-analysis.md` | yes | jq -e shape probes |
| Roadmap (extensions) | any other file in `docs/roadmap/` | n/a | INFO only — project-specific extensions are not drift |
| Research docs | `docs/_research/*.md` | yes | scope-block presence + ingestion status (only if carry-forward.jsonl exists) |

### Plugin-scope inventory (only if `--scope plugin` or `all`)

Same as before — frontmatter, companion file layout, hook wiring, version sync, legacy registry. See references/main.md §Plugin-Scope Probes.

Emit one verbose-progress line per category. Stash inventory + version-detection results in a temp file.

---

## Phase 2: AUDIT — Validate Against Canonical Schemas

For each artifact, validate against the schema **at its detected version** (don't apply v1.9 schema to a v0.x story — that's a migration target, not a drift finding).

Findings classified as:

- **MIGRATE** — auto-applicable schema-version migration (e.g., adding `registry_entries` when a project adopts the carry-forward registry). Additive only — conform never renames canonical fields.
- **MECHANICAL** — fixable by trivial inline edit (missing optional default, schema field truly absent at the detected version).
- **MANUAL** — needs human judgment (stale entries, contradictory state, ambiguous fix).
- **NO ACTION (INFO)** — informational (extension files, sample-mode skipped artifacts, optional features absent).

### Project-scope checks

| Check | Validator | Optional treatment |
|---|---|---|
| `activity-feed.jsonl` schema | line JSON parse + required-fields probe per terse-output.md | always run if file exists |
| `carry-forward.jsonl` Reader Algorithm | per sprint-contracts.md §Reader Algorithm `MODE=audit` | **skip** if file absent and no consumer found |
| `developer-profile.json` autonomy | `jq '.autonomy'` in `{low, medium, high, full}` | **skip** if file absent and no skill/hook references it |
| Story frontmatter | shape per sprint-contracts.md | field-presence check on canonical `epic`+`verify`; if `registry_entries` absent AND carry-forward in use → MIGRATE (add `[]`); else conformant |
| STATE.md required fields | per session-lifecycle.md, with table-form fallback parser | **try both formats** before flagging MANUAL |
| Active sessions older than 4h | compare `started`/dir mtime to now | works for both file + dir model |
| Orphan locks | set diff `*.lock` minus active sessions | works for both models |
| Roadmap canonical files schema | `jq -e .` + per-file required-fields | only the 6 canonical files; extensions get INFO line |
| Research docs scope-block ingestion | cross-reference scope IDs vs registry IDs | **skip** if carry-forward.jsonl absent |

### Plugin-scope checks

(unchanged from previous version — see references/main.md §Plugin-Scope Validators)

---

## Phase 3: PLAN — Categorize Findings

Build a migration plan as a table (sample shape — actual will reflect target):

| Finding | Scope | Category | Fix approach | Idempotent? |
|---|---|---|---|---|
| 312 stories lacking `registry_entries` (project uses carry-forward) | project | MIGRATE | inline transform: add `registry_entries: []` only; never rename `epic`/`verify` (those are canonical); preserve all fields | yes |
| 47 activity-feed entries missing `detail` field | project | MECHANICAL | inline Edit: append `"detail":{}` | yes |
| `carry-forward.jsonl` absent + no consumer | project | NO ACTION | feature not in use | n/a |
| `developer-profile.json` absent + no consumer | project | NO ACTION | feature not in use | n/a |
| 162 session directories (dir-model) | project | NO ACTION | INFO: dir model detected; staleness checked via mtime | n/a |
| 24 roadmap extension files (`.bak`, `_TRACKER.md`, etc.) | project | NO ACTION | INFO: project-specific extensions, not drift | n/a |
| 4 sprints below latest 3 + 5 random | project | NO ACTION | INFO: not sampled (--full to override) | n/a |
| 1 stale active session (>4h) | project | MANUAL | requires user disposition | no |
| 8 SKILL.md missing OUTPUT STYLE snippet | plugin | MECHANICAL | run scripts/maint/v1.9.0/blitz-fix-frontmatter.sh | yes |

Print plan as verbose-progress table. If `--report-only`, skip to Phase 6.

---

## Phase 4: MIGRATE (only if `--fix`) — Apply Mechanical Fixes

### Story-frontmatter `registry_entries` migration

**Canonical field names are `epic` + `verify`** ([/_shared/sprint-contracts.md](/_shared/sprint-contracts.md)) — NOT `epic_id`/`acceptance_criteria`. Never rename them; the only additive field is `registry_entries`. A story with `epic` + `verify` + `registry_entries` is conformant.

For each story flagged MIGRATE (lacks `registry_entries` AND project uses carry-forward registry):

1. Backup: copy file to `<file>.pre-conform.<ts>`.
2. Parse YAML frontmatter.
3. Transform — **add only**:
   - If `registry_entries:` missing, add `registry_entries: []` (empty array — populated later by carry-forward integration if/when the project adopts it).
   - Do NOT rename `epic`/`verify`/`done` — they are canonical; renaming de-conforms the story and breaks sprint-review Invariant 3 (`epic`) + the done gate (`verify`).
4. Preserve all other fields verbatim (`epic`, `verify`, `priority`, `points`, `depends_on`, `assigned_agent`, `files`, `done`, `commit`, etc.).
5. Write back. Verify YAML parses.

Per-story migration is independent — failure on one story does not abort the batch. Failed stories logged to `migration-failures.log`.

### Activity-feed normalization

For each malformed line:
- Missing `detail` field → append `"detail":{}`
- Missing `event` field → flag MANUAL (cannot infer)
- Message > 300 chars → truncate, move overflow into `detail.full_message`
- Backup `.cc-sessions/activity-feed.jsonl.pre-conform.<ts>` before any in-place writes.

### Carry-forward dedup (only if file exists)

- Keep most-recent entry per `(id, event)` pair by timestamp
- For older duplicates, append a synthetic `dropped` event with reason `"deduped by /conform <ts>"`

### `developer-profile.json` (only if a consumer exists but file is absent)

Create with safe defaults:
```json
{
  "autonomy": "medium",
  "_created_by": "/blitz:conform",
  "_created_at": "<ISO-now>",
  "_note": "review and adjust autonomy based on developer preference per session-lifecycle.md §Autonomy Levels"
}
```

### Orphan lock cleanup

Delete each confirmed-orphan lock (no live session pid in any active session JSON).

### STATE.md repair

If field-form STATE.md missing required fields, derive from sprint manifest + carry-forward state and insert under canonical headings. If table-form, leave alone (already informationally complete; emit INFO that table-form is supported but not normalized to field-form).

### Plugin-scope migrations

(unchanged — runs scripts/maint/v1.9.0/* in dependency order)

After each fix, append `migration_applied` event with finding name + count.

---

## Phase 5: VERIFY — Re-run Validators

Re-run all Phase 2 checks against migrated tree. Compare exit codes + finding counts:

- All clean → SUCCESS, transition to REPORT
- Finding count strictly decreased but residue remains → classify residue as MANUAL/INFO, transition to REPORT
- New findings appeared (regression) → **HALT** with diff vs Phase 2 audit; do not continue

Never auto-rollback. Backup files (`.pre-conform.<ts>`) preserve pre-migration state.

---

## Phase 6: REPORT

Write to stdout (and `${TARGET}/.cc-sessions/conform-report.md` if `--fix` was passed). Sample shape:

```
# Conform Report — <target> — <ISO-date>

Mode: report-only | fix
Scope: project | plugin | all
Sample mode: on (auditing latest 3 + 5 random; <N> sprints not sampled) | off

## Inventory
  Activity feed: <N> entries (<size>)
  Carry-forward: <N> entries  |  not in use (file absent, no consumer)
  Developer profile: present (autonomy=<value>)  |  not in use
  Sessions: <N> file-style + <M> dir-style (<stale>)
  Sprints: <N> (latest: sprint-<X>)
  Stories: <N> total (<with registry_entries>/<without>)
  Roadmap canonical: <N>/6 present  |  Extensions (INFO): <N>
  Research docs: <N> (<scope-blocks>)

## Findings (Phase 2)
  MIGRATE: <count> (auto schema-version migrations)
  MECHANICAL: <count> (auto-fixable)
  MANUAL: <count> (require human review)
  INFO: <count> (informational, no action)

## Migrations applied (Phase 4) — only if --fix
  Story registry_entries add: <N> migrated, <N> failed (see migration-failures.log)
  Activity-feed normalization: <N> lines
  Carry-forward dedup: <N> entries  |  skipped (no file)
  Orphan lock cleanup: <N>
  STATE.md repair: <N>  |  skipped (table-form left as-is)

## Verification (Phase 5)
  Activity-feed schema: PASS | FAIL
  Carry-forward Reader Algorithm: PASS | SKIP | ESCALATION
  Story-frontmatter validation: PASS | FAIL
  STATE.md required-fields: PASS | FAIL

## Manual follow-ups
  - <file>:<line>  <issue>  <suggested action>

## Deferred to other skills
  - <N> un-ingested research docs → /blitz:roadmap extend
  - <N> carry-forward escalations → /blitz:next triage

Final state: CONFORMANT | DRIFT_REMAINING | REGRESSED
```

Append `task_complete` event with `summary: "conform <mode> <scope> <target> — <final state>"`.

---

## Safety Rules (NON-NEGOTIABLE)

1. **No writes without `--fix`.** Default mode is read-only.
2. **No writes to `.git/`, `node_modules/`, or any path matching `pre-edit-guard.sh` protected list.**
3. **Backup before mutating** any `.jsonl`, `.md` story file, or `STATE.md`. Backups go to `<file>.pre-conform.<ts>`.
4. **Per-file isolation in MIGRATE.** A failure on story N does not prevent stories N+1...M from migrating. Log failures, continue batch.
5. **No script execution outside `scripts/maint/v1.9.0/`** during plugin-mode MIGRATE.
6. **Halt on first regression in VERIFY**. Do not continue migrating after a validator regression.
7. **Activity-feed audit trail required**. Every migration must log a `migration_applied` event with finding name + count.
8. **Never auto-invoke other blitz skills** from MIGRATE. Emit a TODO and let the user decide.
9. **Optional features stay optional.** Never create `carry-forward.jsonl` or `developer-profile.json` from scratch unless a consumer demands them.
10. **Project-specific extensions stay.** Files outside the canonical roadmap-6 list (e.g., `roadmap-registry.json`, `_TRACKER.md`) are NEVER deleted — they're INFO findings only.

## Out of scope

- Code-level refactoring (`/blitz:refactor`)
- Stack/framework migrations (`/blitz:migrate`)
- Bootstrapping (`/blitz:bootstrap`)
- CLAUDE.md conflicts (`/blitz:setup`)
- Runtime health probe (`/blitz:health`)
- Triage of carry-forward escalations (`/blitz:next`)
- Re-ingesting research docs (`/blitz:roadmap extend`)
