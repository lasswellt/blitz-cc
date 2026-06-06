# conform — Reference

Detailed schema-migration tables, version probes, and validator inventory referenced from `SKILL.md`. Loaded on demand during Phase 1 (DETECT) and Phase 2 (AUDIT).

## Table of Contents

1. [Schema Detection Rules](#schema-detection-rules)
2. [Story Schema Versions (`registry_entries` additive migration)](#story-schema-versions)
3. [STATE.md Format Variants](#statemd-format-variants)
4. [Roadmap Canonical-vs-Extension Inventory](#roadmap-canonical-vs-extension-inventory)
5. [Session Model Variants](#session-model-variants)
6. [Optional Feature Reference Detection](#optional-feature-reference-detection)
7. [Plugin-Scope Probes](#plugin-scope-probes)
8. [Plugin-Scope Validators](#plugin-scope-validators)

---

## Schema Detection Rules

For each artifact category that supports multiple schema versions, conform must DETECT the version before validating. Don't apply v1.9 expectations to a v0.x artifact — that's a migration target, not a violation.

| Artifact | Version probe | Versions |
|---|---|---|
| Story frontmatter | YAML keys present | pre-registry: `epic` + `verify`, no `registry_entries`. current: `epic` + `verify` + `registry_entries` (canonical field names per `/_shared/sprint-contracts.md`). The only additive field is `registry_entries`; `epic`/`verify` are canonical — NOT renamed. |
| STATE.md | first heading after `# Sprint N — STATE` | field-form (one bullet per field) vs table-form (markdown table with one row per field) |
| Sprint manifest | `version` field if present, else infer from key set | `manifest.json` v1+ has `points_total`, `story_count_required`. Older manifests may lack these. |
| Activity feed line | required-field probe | v1: `ts`, `session`, `skill`, `event`, `message`, `detail` (current). Older lines may lack `detail`. |

---

## Story Schema Versions

**Canonical field names are `epic` and `verify`** (per [`/_shared/sprint-contracts.md`](/_shared/sprint-contracts.md) — `epic` required, `verify` required, `registry_entries` optional). There is **no** `epic_id`/`acceptance_criteria` rename — earlier drafts of this skill described one, but the canonical schema never adopted it. The only real schema evolution is the **additive `registry_entries`** field (added in the carry-forward-registry era). Do NOT rename `epic`→`epic_id` or `verify`→`acceptance_criteria`; doing so de-conforms an already-conformant story and breaks `sprint-review` Invariant 3 (which reads `epic`) and the `done` gate (which reads `verify`).

### pre-registry (older stories, before carry-forward integration)

```yaml
---
id: S200-001
title: 'EngagementTier type + classifyTier + decayFactor pure functions'
epic: EPIC-104                         # canonical field name
status: incomplete
priority: 1
points: 1
depends_on: []
assigned_agent: backend-dev
files:
  - packages/domain/src/types/engagement-score.ts
verify:                                # canonical field name
  - 'pnpm --filter @mbk/domain build'
commit: 'feat(sprint-200/backend): ...'
---
# ← lacks `registry_entries` (the one additive field)
```

### current canonical (per `/_shared/sprint-contracts.md`)

```yaml
---
id: S200-001
title: 'EngagementTier type + classifyTier + decayFactor pure functions'
epic: EPIC-104                         # unchanged — canonical
status: incomplete
verify:                                # unchanged — canonical
  - 'pnpm --filter @mbk/domain build'
registry_entries: []                   # additive: links story to carry-forward.jsonl entries
priority: 1
points: 1
depends_on: []
assigned_agent: backend-dev
files: [...]
commit: '...'
---
```

### Migration algorithm

A story is flagged MIGRATE **only** if it lacks `registry_entries` AND the project uses the carry-forward registry (`.cc-sessions/carry-forward.jsonl` exists). A story already carrying `epic` + `verify` + `registry_entries` is **conformant** — emit NO finding. For each genuine MIGRATE:

1. Backup: `cp <story>.md <story>.md.pre-conform.<ts>`
2. Parse YAML frontmatter into a dict.
3. **Add only**: if `registry_entries` absent → `dict['registry_entries'] = []`.
4. **Preserve all other fields verbatim** — never rename `epic`/`verify`/`done`. No fields removed.
5. Write back. Re-parse to verify YAML validity.
6. If parse fails after write, restore backup and log to `migration-failures.log`.

**Idempotency**: rerunning on a conformant story is a no-op (`registry_entries` already present). **Caveat**: if the project does not use the carry-forward registry, absence of `registry_entries` is NOT drift — it is an optional field (Safety Rule 9). Emit INFO, not MIGRATE.

---

## STATE.md Format Variants

### Field-form (canonical per session-lifecycle.md)

```markdown
# Sprint N — STATE

- sprint: N
- phase: implementation
- last_completed: S<N>-007
- current_session: sprint-dev-N-<hash>
- cf_active_count: 0
```

### Bold-prefix-line form (most common in legacy / atp-style projects)

```markdown
# Sprint 266 — STATE

**Last updated:** 2026-04-19T15:10:00Z
**Status:** in-progress
**Type:** hygiene (events domain)
**Session:** sprint-dev-266-3a46d3a9
```

Probe: at least 3 lines matching `^\*\*[A-Z][^*]+\*\*[:\s]+\S` near the top. Each line is a `key: value` pair encoded as bold-prefix.

### Table-form (less common variant)

```markdown
# Sprint 266 — STATE

## Wave Progress

| Wave | Status   | Stories | Notes |
| ---- | -------- | ------- | ----- |
| 0    | complete | ...     | ...   |
```

Probe: presence of a markdown table with a `Wave` or `Phase` column header.

### Format-aware extraction

Try in order: field-form → bold-prefix-line → table-form. The first parser that returns ≥2 required fields wins. If all three fail, classify MANUAL.

- Required fields can be extracted from `**Field:** value` lines or markdown table rows
- Map: `Status` → `phase`, `Session` → `current_session`, infer `sprint` from heading, etc.

If both parsers fail to extract the required field set, classify MANUAL.

`--fix` mode does NOT normalize table-form to field-form. Both formats are accepted by current sprint-review and ship workflows.

---

## Roadmap Canonical-vs-Extension Inventory

### Canonical files (the 6 expected by sprint-plan)

| File | Schema check |
|---|---|
| `docs/roadmap/capability-index.json` | top-level `capabilities` array, each entry has `id`, `title`, `status` |
| `docs/roadmap/epic-registry.json` | top-level `epics` array, each entry has `id`, `capability_id`, `status` |
| `docs/roadmap/phase-plan.json` | top-level `phases` array |
| `docs/roadmap/domain-index.json` | top-level `domains` array |
| `docs/roadmap/ROADMAP.md` | non-empty markdown |
| `docs/roadmap/gap-analysis.md` | non-empty markdown |

### Project-specific extensions (NEVER deleted, always INFO)

Examples seen in real projects:
- `roadmap-registry.json`, `roadmap-registry.legacy.json` — atp's variant of capability-index
- `*.bak`, `*.pre-refresh-*.bak` — backup artifacts from prior refresh runs
- `_CAPABILITY_TRACKER.md`, `_PHASE_PLAN.md`, `_AGENTIC_MANIFEST.json` — atp-specific tracking layers
- `tracker.md`, `manifest.json` — project-level summaries
- `cross-cutting/`, `domains/`, `epics/`, `sprints/` — subdirectories (skip walking unless explicitly enabled)

These are INFO findings only. The skill prints them so the user knows they exist; never proposes deletion or migration.

---

## Session Model Variants

### File-style (current canonical)

```
.cc-sessions/
├── cli-a3f7c1b2.json    ← single JSON file per session, status field inside
├── sprint-dev-266-3a46d3a9.json
└── audit-cd844142.json
```

Staleness probe: `jq '.started'` → compare to now.

### Directory-style (common in legacy / atp-style projects)

```
.cc-sessions/
├── cli-a3f7c1b2/        ← directory per session
│   ├── status.json      ← optional
│   ├── tmp/
│   └── checkpoints/
├── sprint-dev-266-3a46d3a9/
└── audit-cd844142/
```

Staleness probe: `stat -c %Y <dir>` (mtime of directory itself, or newest file inside) → compare to now.

### Detection

Walk `.cc-sessions/`:
- For each entry, classify as file (`.json` suffix) or dir (no suffix, is a directory)
- Track both populations independently
- Both models support staleness check via different probes

`--fix` mode does NOT normalize one model to the other. Both are valid; the canonical writer (session-lifecycle.md) uses file-style, but reader skills accept both.

---

## Optional Feature Reference Detection

These artifacts are OPTIONAL — absence alone is not drift. Only flag MISSING if the project has another artifact that **references** the absent feature.

### `carry-forward.jsonl`

Consumers in this plugin: `sprint-plan` (Phase 1, Phase 2.4), `sprint-dev` (Phase 0.0, Phase 3.1a registry write), `sprint-review` (Phase 3.6 Reader Algorithm), `next` (Phase 0.6 CF_ACTIVE/CF_ESCALATED), `roadmap` (Phase 1.1.5 scope ingestion).

A project consumes carry-forward if ANY of:
- File exists at `.cc-sessions/carry-forward.jsonl`
- Any sprint manifest has a **non-empty** `carry_forward: [<at least one item>]` array (empty arrays `[]` and `null` do NOT count — they're defensive defaults)
- Any story has **non-empty** `registry_entries: [<at least one item>]`
- Any research doc has a `scope:` block with `cf-` prefixed IDs
- Any `STATE.md` has `cf_active_count > 0` (numeric, > 0) or mentions a specific `cf-` ID

**Signal counting algorithm (use this exact logic in Phase 2)**:

```bash
# Count manifests with truly non-empty carry_forward
non_empty_count=0
for m in sprints/*/manifest.json; do
  len=$(jq -r '.carry_forward // [] | length' "$m" 2>/dev/null || echo 0)
  [ "$len" -gt 0 ] && non_empty_count=$((non_empty_count + 1))
done
```

If file absent AND zero signals → **NO ACTION** (project doesn't use the feature).
If file absent BUT signals exist → **MANUAL** (the project has carry_forward references in manifests/stories but no registry file. This is a real gap — likely indicates a partial adoption or a lost file. Do NOT auto-create an empty file; require user disposition because the manifest entries reference IDs that may no longer be reconstructable.)

### `developer-profile.json`

Consumers: `sprint-dev` (Execution Mode reads autonomy), `sprint-review` (autonomy reads), `code-sweep` (Phase 0.5 reads), `bootstrap` (Phase 1 may write), per session-lifecycle.md §Autonomy Levels.

A project consumes developer-profile if ANY of:
- File exists at `.cc-sessions/developer-profile.json`
- Any session JSON references `autonomy` field
- The user has invoked sprint-dev with no `--mode` arg (the canonical fallback reads developer-profile)

If file absent AND no consumer signal → **NO ACTION**.
If file absent BUT consumers exist → **MECHANICAL** (`--fix` creates file with `autonomy: medium` safe default).

---

## Plugin-Scope Probes

(Only relevant when `--scope plugin` or `--scope all`.)

| Inventory item | Probe |
|---|---|
| SKILL.md files | `find <target>/skills -maxdepth 2 -name SKILL.md` |
| Companion file layout | per skill: glob legacy `reference.md`, `CHECKS.md`, `PATTERNS.md`, `*.json` outside `assets/` |
| Hook scripts | `find <target>/hooks/scripts -name '*.sh' -o -name '*.py'` |
| Hooks wired | parse `<target>/hooks/hooks.json`; diff against scripts present |
| Version files | `<target>/.claude-plugin/plugin.json`, `marketplace.json`, `installer/install.sh` |
| Legacy registry | `<target>/.claude-plugin/skill-registry.json` (deleted in v1.9.0) |
| Shared protocols | `find <target>/skills/_shared -name '*.md'` |

---

## Plugin-Scope Validators

| Validator | Source |
|---|---|
| `hooks/scripts/skill-frontmatter-validate.sh skills/*/SKILL.md` | repo |
| `hooks/scripts/markdown-link-validate.sh` | repo |
| `hooks/scripts/reference-compression-validate.sh` | repo |
| `scripts/check-version-sync.sh` | repo |
| Companion file layout (no legacy `reference.md`/`CHECKS.md`/`PATTERNS.md` outside `references/` or `assets/`) | filesystem walk |
| Hook scripts vs `hooks.json` wiring (no orphans, no missing wires) | parse + diff |

### Plugin migration scripts (run by Phase 4 only when `--fix --scope plugin|all`)

In dependency order:

1. `scripts/maint/v1.9.0/blitz-fix-frontmatter.sh` — adds missing `effort:` + OUTPUT STYLE snippet. Idempotent.
2. `scripts/maint/v1.9.0/blitz-restructure.py` — companion file rename (two-phase). Idempotent.
3. `scripts/maint/v1.9.0/blitz-trim-preamble.py` — verbose-preamble trim. Idempotent.
4. `scripts/maint/v1.9.0/blitz-rewrite-desc.py` — **only canonical 36-skill names**; external skills skipped.
5. `scripts/maint/v1.9.0/blitz-xref-audit.py` — read-only verification.
