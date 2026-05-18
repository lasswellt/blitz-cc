---
name: roadmap
description: Generates phased implementation roadmaps from research documents. Extracts capabilities, assesses codebase state, clusters features into domains, resolves dependencies, and produces epic-ready implementation plans. Use when user says "generate roadmap", "plan phases", "roadmap status", "extend roadmap".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
argument-hint: "[mode] -- modes: full (default — generate from scratch) | refresh (re-read research, regenerate phases, preserve completed work) | extend (ingest new research docs, append capabilities) | status (report progress + blockers, no generation)"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For capability schema, document classification, and Phases 5-8 procedures, see [references/main.md](references/main.md)
- For the carry-forward registry (written in Phase 1 from research doc scope: blocks; re-scanned in refresh mode), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For pipeline artifact contracts (`docs/roadmap/`, `capability-index.json` consumed by sprint-plan), see [/_shared/state-handoff.md](/_shared/state-handoff.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)

All generated epics and roadmap artifacts must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder descriptions.


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Roadmap Generation Skill

Generate phased implementation roadmaps from research documents. Execute the appropriate mode based on arguments. Do NOT skip phases.

---

## Mode Routing

Parse `$ARGUMENTS` to determine execution mode:

| Argument | Mode | Description |
|----------|------|-------------|
| `full` (default) | Full Generation | Run all phases (0-8). Use when no roadmap exists. |
| `refresh` | Refresh | Re-read research docs, update capabilities, re-assess codebase state, regenerate phases. Preserves completed work. |
| `extend` | Extend | Add new capabilities from new research docs. Append to existing roadmap without disrupting current phases. |
| `status` | Status | Report current roadmap progress: completed/in-progress/pending epics, blockers, and next actions. |

If no argument is provided, default to `full`.

**For `status` mode**: Skip to Phase 0 context loading, then print a status report and STOP. Do not generate anything.

**For `refresh` mode**: Run Phases 0-4, then selectively re-run Phases 5-8 only for changed domains. Phase 1 also re-scans the carry-forward registry against existing research docs — see Phase 1.1.6 and the refresh-specific backfill path documented in `skills/_shared/carry-forward-registry.md`.

**For `extend` mode**: Run Phase 0, then Phase 1 for new documents only (including Phase 1.1.5 scope-block ingestion — hard-fails on duplicate registry ids), skip to Phase 4 for dependency re-resolution, then Phases 5-8 for new domains only.

---

## Phase 0: CONTEXT — Load Project State

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Locate Registry Files

Search for existing roadmap artifacts:
```
Glob: **/roadmap-registry.json, **/epic-registry.json, **/roadmap/**/*.md, **/docs/roadmap/**/*
```

### 0.2 Load Research Index

Search for research documents AND audit-derived `-epics.md` files:
```
Glob: **/docs/_research/**/*.md, **/docs/research/**/*.md, **/research/**/*.md, **/_research/**/*.md, **/docs/audits/*-epics.md
```

Audit-derived docs (filename `*-epics.md` under `docs/audits/`) follow the same `scope:` block protocol as research docs — see `skills/codebase-audit/SKILL.md` Phase 3.3a for the writer contract, and Phase 1.1.5 below for the ingestion path. Only `*-epics.md` files are ingested; the full audit report (`audit-YYYYMMDD.md`) and machine-readable index (`audit-YYYYMMDD-index.json`) are NOT consumed by `roadmap extend`.

If no research documents OR audit `-epics.md` files found:
```bash
echo "BLOCK: roadmap requires research documents in docs/_research/ OR audit -epics.md files in docs/audits/. Run /blitz:research or /blitz:codebase-audit first." >&2
exit 1
```

### 0.3 Build Codebase Inventory

Run:
```bash
find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
```

Read root `package.json` and workspace configs. Identify:
- Project structure (monorepo vs single package)
- Existing packages/modules and their purposes
- Current dependencies and versions

### 0.4 Load Existing Roadmap (if any)

If a roadmap registry exists:
- Read the registry JSON.
- Note completed epics, in-progress epics, and pending epics.
- Load the capability index if it exists.

For `status` mode: Print the status report now and STOP.

```markdown
# Roadmap Status Report

**Last Updated**: <date>
**Total Capabilities**: N
**Total Epics**: N

## Phase Summary
| Phase | Epics | Completed | In Progress | Pending | Blocked |
|-------|-------|-----------|-------------|---------|---------|

## Next Actions
<list unblocked epics ready to start>

## Blockers
<list blocked epics and what they are waiting on>
```

**Gate:** For `full` mode, you must have at least 1 research document. For `refresh`/`extend`, you must have an existing roadmap.

---

## Phase 1: RESEARCH INGESTION — Extract Capabilities

### 1.1 Discover Research Documents

Read every file found in Phase 0.2. For each document:

1. **Classify the document** using the 8-type classification table from `references/main.md`:
   - `product_definition` — Vision, goals, target users, value propositions
   - `feature_spec` — Detailed feature descriptions, user stories, acceptance criteria
   - `competitive_analysis` — Market research, competitor features, differentiators
   - `nfr` — Non-functional requirements (performance, security, accessibility)
   - `architecture` — System design, data models, API contracts, infrastructure
   - `brand_ux` — Design system, UX guidelines, brand voice, accessibility standards
   - `integration_spec` — Third-party integrations, API contracts, protocols
   - `operational` — Deployment, monitoring, CI/CD, runbooks

2. **Extract capabilities** from the document. A capability is a discrete unit of functionality that can be implemented. Assign sequential IDs: `CAP-001`, `CAP-002`, etc.

### 1.1.5 Parse `scope:` YAML Frontmatter (Carry-Forward Registry Ingestion)

Before extracting capabilities, check the research doc for a **`scope:` YAML frontmatter block**. This is the structured-scope contract emitted by `skills/research` Phase 3.1.1. Each entry in the block becomes both a capability `scope_metric` (see `references/main.md`) **and** an append-only line in `.cc-sessions/carry-forward.jsonl`. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the full registry protocol.

**Parse step (all modes):**

1. **Detect the block.** Read the top of the research doc. If it starts with `---` followed by a `scope:` key, extract the YAML between the `---` delimiters:
   ```bash
   # Rough shape — adapt to available tooling
   awk '/^---$/{f=!f; next} f' "${DOC_PATH}" > "${SESSION_TMP_DIR}/frontmatter.yaml"
   ```
   If no frontmatter or no `scope:` key exists, skip to the "quantified claim fallback" below.

2. **Parse each entry.** For every item under `scope:`, extract: `id`, `unit`, `target`, `description`, `acceptance[]`. All five fields are required; reject the entry with a loud error and skip it if any are missing.

3. **Dedup against existing registry.** Reduce `.cc-sessions/carry-forward.jsonl` with `jq -s 'group_by(.id) | map(max_by(.ts))'` and check each parsed `id`:
   - **`extend` mode** — Hard-fail on any duplicate id: print the offending id and the doc that introduced it, then STOP. The author must either rename the new entry or use `refresh` mode.
   - **`refresh` mode** — Duplicates are expected (re-ingest path). See Phase 1.1.6 below.
   - **`full` mode** — Treat duplicates as a registry conflict: warn the user, stop, and prompt for manual resolution. Full-mode runs usually start with an empty registry.

4. **Write registry lines.** For each new (non-duplicate) entry, append a `created` line to `.cc-sessions/carry-forward.jsonl`:
   ```jsonl
   {"id":"<id>","ts":"<ISO-8601>","event":"created","source":{"doc":"<doc-path>","anchor":"#scope"},"parent":{"capability":null,"epic":null},"scope":{"unit":"<unit>","target":<target>,"description":"<description>","acceptance":<acceptance-array>},"delivered":{"unit":"<unit>","actual":0,"last_sprint":null},"coverage":0.0,"status":"active","last_touched":{"sprint":null,"date":"<ISO-8601>"},"rollover_count":0,"notes":"Created by roadmap/SKILL.md Phase 1.1.5 during <extend|refresh|full> run"}
   ```
   The `parent.capability` and `parent.epic` fields are null here — they will be backfilled in Phase 7 once capabilities and epics are derived and their `registry_entries` arrays are written.

5. **Activity-feed mirror.** For each registry line, also append an event to `.cc-sessions/activity-feed.jsonl`:
   ```jsonl
   {"ts":"<ISO-8601>","session":"${SESSION_ID}","skill":"roadmap","event":"registry_write","message":"Ingested scope entry <id> from <doc-path>","detail":{"registry_id":"<id>","unit":"<unit>","target":<target>}}
   ```

6. **Propagate to capability extraction.** Each parsed scope entry is attached to its derived capability in Phase 1.2 as the capability's `scope_metric` field, with `registry_entry_id` pointing at the line just written. See `references/main.md` Capability Extraction Schema.

### 1.1.6 Quantified-Claim Fallback Scan

Even if the doc has no `scope:` block, it may still contain prose-level quantified claims that should be registered (this is the CAP-133 drop mode — the original doc said "130 files" in prose and nothing caught it). Scan the document's Summary, Findings, and Recommendation sections for regex `\d+\s+(files|components|modals|routes|tests|endpoints|pages|views|tables|migrations|fields|records)`.

For every match:

- **Acceptable: `<!-- no-registry: <reason> -->` comment on the same line or immediately above** — this is an explicit author waiver. Record the waiver in the capability's `notes` field and continue.
- **Unacceptable: no waiver comment** — warn with a precise location: `"${DOC_PATH}:${LINE}: unregistered quantified claim '<match>'. Add a scope: YAML block or a <!-- no-registry: <reason> --> waiver."`. In `extend` mode this is a **HARD FAIL**; the operator must fix the research doc before re-running extend. In `refresh`/`full` mode, log the warning and continue (these modes are allowed to be lenient on legacy docs, but the warning is logged and sprint-review Invariant 1 will re-enforce it at sprint close).

### 1.2 Capability Extraction Rules

For each capability, capture:
```yaml
id: CAP-NNN
title: "<short descriptive title>"
source_document: "<relative-path>"
source_anchor: "<heading-anchor or line reference>"
document_type: "<classification>"
description: "Generates phased implementation roadmaps from research documents. Extracts capabilities and quantified scope: blocks, assesses codebase state, clusters features into epics, resolves dependencies, and writes roadmap-registry.json + epic-registry.json + carry-forward.jsonl 'created' lines. Use when the user says 'generate roadmap', 'plan phases', 'roadmap status', 'extend roadmap', or after /blitz:research produces a new doc. Required before /blitz:sprint-plan."
user_value: "<who benefits and how>"
acceptance_criteria:
  - "<testable criterion>"
complexity: low | medium | high | very_high
domain_hint: "<suggested domain cluster>"
dependencies_hint: ["<CAP-IDs this likely depends on>"]
research_needed: true | false
research_triggers: ["<questions that need answering>"]
scope_metric:                       # Populated from the scope: block if one exists
  unit: "<files|components|...>"
  target: <integer>
  description: "<human-readable>"
  acceptance: [ ... ]
registry_entry_id: "cf-<id>"        # Back-link to .cc-sessions/carry-forward.jsonl entry
```

### 1.3 Deduplicate Capabilities

After extracting from all documents:
- Compare capabilities by title similarity and description overlap.
- If two capabilities from different documents describe the same thing, merge them. Keep the richer description and combine acceptance criteria.
- Record the merge in a dedup log.

### 1.4 Write Capability Index

Write `docs/roadmap/capability-index.json`:
```json
{
  "generated": "<ISO-8601>",
  "source_documents": [
    { "path": "<relative>", "type": "<classification>", "capabilities_extracted": 0 }
  ],
  "capabilities": [ "<capability objects>" ],
  "dedup_log": [ { "merged": "CAP-XXX", "into": "CAP-YYY", "reason": "..." } ]
}
```

**Gate:** At least 5 capabilities must be extracted. If fewer, warn the user that research may be insufficient.

---

## Phase 1B: RESEARCH ENRICHMENT — Fill Knowledge Gaps

### 1B.1 Build Research Agenda

From the capability index, collect all capabilities where `research_needed: true`. Group their `research_triggers` by theme.

Prioritize research by:
1. Capabilities with `complexity: very_high` or `high`
2. Capabilities involving external integrations
3. Capabilities with security or compliance implications

### 1B.2 Context7 Lookups (max 8)

Use ToolSearch to check for Context7 MCP tools. If available:
- Look up documentation for detected libraries/frameworks.
- Focus on APIs, migration guides, and best practices relevant to high-complexity capabilities.
- Cache results in `${SESSION_TMP_DIR}/roadmap-research/context7/`.

### 1B.3 Web Research (max 12)

Use WebSearch for:
- Best practices for identified architectural patterns.
- Pricing/limits for third-party services referenced in capabilities.
- Security advisories for planned integrations.
- Performance benchmarks for chosen technologies.

Cache results in `${SESSION_TMP_DIR}/roadmap-research/web/`.

### 1B.4 Synthesize Research Cache

Write `docs/roadmap/research-cache.json` using the schema from `references/main.md`. Each entry includes:
- Source (context7 or web)
- Query used
- Key findings (bulleted)
- Confidence level (high, medium, low)
- Related capabilities (CAP-IDs)

---

## Phase 2: CODEBASE STATE ASSESSMENT — What Exists Today

### 2.1 Load Architecture Context

Read key architectural files:
- Framework config files
- Type definitions and schemas
- Existing route definitions
- Store/state management files
- Database schemas or rules

### 2.2 Build Evidence Matrix

For each capability, assess the current codebase state:

| Status | Meaning |
|--------|---------|
| `not_started` | No related code exists |
| `partial` | Some infrastructure exists but feature incomplete |
| `implemented` | Feature exists but may not match spec |
| `complete` | Feature matches all acceptance criteria |

For each capability, record:
```yaml
capability: CAP-NNN
status: not_started | partial | implemented | complete
evidence:
  - file: "<path>"
    relevance: "<what this file contributes>"
coverage: 0.0  # 0.0 to 1.0
gaps:
  - "<what's missing>"
```

### 2.3 Gap Analysis

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Bullet lists only. Format: `<capability-or-module> — <status> — <1-fragment rationale>`. Preserve verbatim: capability IDs, file paths, module paths, JSON records, registry IDs. No prose preamble. Phase + domain docs stay as structured registries, not narrative reports.

Write `docs/roadmap/gap-analysis.md`:
- Capabilities with no codebase support (greenfield)
- Capabilities with partial support (extend/refactor)
- Capabilities already implemented (verify/skip)
- Infrastructure gaps (missing packages, services, configs)

### 2.4 Carry-Forward Registry Coverage Recompute (`refresh` mode)

**This sub-phase runs in `refresh` mode only.** It re-verifies every carry-forward registry entry against the current codebase by executing the `scope.acceptance` checks stored on the entry. This is how a sprint's actual progress gets reconciled with the registry without waiting for sprint-review.

**Procedure:**

1. **Load the registry.** Reduce `.cc-sessions/carry-forward.jsonl` to latest-wins:
   ```bash
   jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl > "${SESSION_TMP_DIR}/registry-latest.json"
   ```

2. **For every entry with `status ∈ {active, partial}`**, run each `scope.acceptance` check against the live codebase. Each acceptance entry is one of:
   - `grep_absent: <pattern>` — run `git grep -c <pattern>` under the project root. Passes if count is 0.
   - `grep_present: { pattern: <p>, min: <n> }` — run `git grep -c <p>`. Passes if count ≥ `min`.
   - `shell: <command>` — run the command. Passes if exit code is 0.
   - `ast_absent: <query>` — run the project's AST tool if available (e.g., `ast-grep`). Passes if the query returns no matches.

3. **Compute `delivered.actual`.** For unit-counted scopes (files, components, routes, tests), derive the current actual:
   - If all acceptance checks pass → `actual = target`, `coverage = 1.0`, `status = complete`.
   - If the entry has a `scope.baseline_count` hint in its metadata (optional), compute `actual = scope.baseline_count - (current grep count)`.
   - Otherwise, count matching files via the `grep_present` / `grep_absent` checks:
     ```bash
     # Example: "migrate modals to @mbk/ui" — count files that import the new component
     NEW_COUNT=$(git grep -l 'from.*@mbk/ui.*Modal' | wc -l)
     ACTUAL=$NEW_COUNT
     COVERAGE=$(echo "scale=3; $ACTUAL / $TARGET" | bc)
     ```

4. **Append update lines.** For each entry whose computed `actual` or `status` differs from the latest registry state, append a `progress` line:
   ```jsonl
   {"id":"<id>","ts":"<ISO-8601>","event":"progress","delivered":{"unit":"<unit>","actual":<computed>,"last_sprint":"<latest-sprint-from-activity>"},"coverage":<computed>,"status":"<complete|partial|active>","last_touched":{"sprint":"<latest-sprint>","date":"<ISO-8601>"},"notes":"Coverage recomputed by roadmap refresh Phase 2.4"}
   ```
   If the recompute transitions an entry to `status: complete`, also log a companion activity-feed event:
   ```jsonl
   {"ts":"<ISO-8601>","session":"${SESSION_ID}","skill":"roadmap","event":"registry_complete","message":"Entry <id> recomputed to complete (coverage 1.0)","detail":{"registry_id":"<id>","parent_epic":"<E-NNN>"}}
   ```

5. **Propagate to epic-registry.** For each entry whose status changed, recompute the parent epic's `coverage`, `acceptance_criteria_met`, and `carry_forward_count` fields in `docs/roadmap/epic-registry.json` (see `references/main.md` Epic Registry JSON Schema). If all of an epic's `registry_entries` are now `complete`, the epic is eligible to transition to `status: done` — but DO NOT auto-transition here; that's the operator's call via `sprint-review` invariant 3 or manual update.

6. **Report.** Print a refresh summary:
   ```
   [roadmap:refresh] Registry coverage recompute:
     Scanned: 12 entries
     Unchanged: 7
     Advanced: 3 (cf-2026-03-01-*, cf-2026-04-02-*, cf-2026-04-07-*)
     Completed: 2 (cf-2026-02-14-*, cf-2026-03-21-*)
     Failed DoD check: 0
   ```

**Backfill path for legacy research docs:** If a consumer project has pre-existing research docs that predate the scope-block convention (e.g., `docs/_research/2026-04-02_modal-consistency.md` from before the registry feature shipped), the canonical backfill procedure is:

1. **Edit the legacy doc.** Add a `scope:` YAML frontmatter block at the top of the file with best-guess `unit`, `target`, and `acceptance` values. Set `delivered.actual: 0` to start — the recompute in step 2.4 will correct it.
2. **Run `/blitz:roadmap refresh`.** Phase 1.1.5 ingests the new block as a registry line (duplicate check passes since this is a new id). Phase 2.4 runs the acceptance checks against the current codebase and writes a `progress` line with the real `delivered.actual` and `coverage`.
3. **Verify.** Read the latest-wins registry state. The entry should reflect the true current coverage, not zero.

If the actual coverage is already 1.0 at backfill time (legacy work was already fully shipped), the recompute will mark the entry `complete` on the first pass, and the epic-registry rollup will mark the parent epic ready to close. No silent drops possible: the registry state and the code state are reconciled.

See `skills/_shared/carry-forward-registry.md` for the full protocol.

---

## Phase 3: DOMAIN ANALYSIS — Feature Clustering

### 3.1 Feature Clustering

Group capabilities into domains based on:
- **Shared data models**: Capabilities that read/write the same entities
- **Shared workflows**: Capabilities that belong to the same user journey
- **Shared infrastructure**: Capabilities that need the same backend services
- **UI proximity**: Capabilities that appear in the same screens/sections

### 3.2 Architecture-Informed Mapping

Align domains to the detected project structure:
- Map domains to existing packages/modules where applicable.
- Identify new packages/modules needed for unmapped domains.
- Ensure each domain has a clear owner in the architecture.

### 3.3 Write Domain Index

For each domain, write `docs/roadmap/domains/<domain-slug>/overview.md` using the template from `references/main.md`.

Write `docs/roadmap/domain-index.json`:
```json
{
  "domains": [
    {
      "slug": "<domain-slug>",
      "name": "<Domain Name>",
      "description": "<1-2 sentences>",
      "capabilities": ["CAP-NNN"],
      "existing_modules": ["<paths>"],
      "new_modules_needed": ["<proposed-paths>"],
      "estimated_complexity": "low|medium|high|very_high"
    }
  ]
}
```

---

## Phase 4: DEPENDENCY RESOLUTION — Sequencing

### 4.1 Build Dependency Graph

For each capability, resolve dependencies:
- **Data dependencies**: A depends on B's data model
- **Infrastructure dependencies**: A needs B's service to exist
- **UI dependencies**: A's screen requires B's component
- **Auth dependencies**: A needs B's auth/permission system

Build a directed acyclic graph (DAG). Detect and report cycles.

### 4.2 Apply Sequencing Rules

1. **Foundation first**: Auth, data models, shared infrastructure before features.
2. **Backend before frontend**: APIs and data layers before UI that consumes them.
3. **Core before extensions**: MVP features before enhancements.
4. **Independent domains in parallel**: Domains with no cross-dependencies can run simultaneously.
5. **Testing alongside implementation**: Test infrastructure in the same phase as the code it tests.

### 4.3 Calculate Critical Path

Identify the longest dependency chain. This determines the minimum number of phases.

### 4.4 Assign Implementation Phases

Group capabilities into phases:
- **Phase 1**: Foundation (auth, data models, core infrastructure, project setup)
- **Phase 2**: Core features (MVP capabilities, primary user flows)
- **Phase 3**: Extended features (secondary capabilities, integrations)
- **Phase 4**: Polish (NFRs, optimizations, advanced features)
- **Phase 5+**: Future (nice-to-haves, stretch goals)

Each phase should be independently deployable.

### 4.5 Identify Parallel Workstreams

Within each phase, identify capabilities that can be worked on simultaneously by different developers/teams.

### 4.6 Write Phase Plan

Write `docs/roadmap/phase-plan.json`:
```json
{
  "phases": [
    {
      "number": 1,
      "name": "<Phase Name>",
      "description": "<goal of this phase>",
      "capabilities": ["CAP-NNN"],
      "domains": ["<domain-slugs>"],
      "parallel_workstreams": [
        { "name": "<workstream>", "capabilities": ["CAP-NNN"] }
      ],
      "estimated_duration": "<weeks>",
      "entry_criteria": ["<what must be true to start>"],
      "exit_criteria": ["<what must be true to finish>"]
    }
  ],
  "critical_path": ["CAP-NNN -> CAP-NNN -> ..."],
  "total_estimated_duration": "<weeks>"
}
```

---

## Phases 5-8: IMPLEMENTATION SPECS, CROSS-CUTTING, EPICS, SUMMARY

These phases are loaded on demand from `references/main.md` to keep this skill file lean. Read the "Phases 5-8 Detailed Procedures" section from `${CLAUDE_SKILL_DIR}/references/main.md` before executing.

**Phase 5**: Spawn agents per domain to generate implementation specs (data models, API contracts, component trees, workflow diagrams).

**Phase 6**: Generate cross-cutting specs (auth system, error handling strategy, testing strategy, CI/CD pipeline, monitoring).

**Phase 7**: Spawn agents per phase to convert specs into epics with stories, acceptance criteria, and effort estimates. **Phase 7 also backfills `parent.capability` and `parent.epic` on every carry-forward registry entry created in Phase 1.1.5.** For each registry entry, look up the capability whose `registry_entry_id` matches, then find the epic that contains that capability, and append a `correction` event line to `.cc-sessions/carry-forward.jsonl`:
```jsonl
{"id":"<registry-id>","ts":"<ISO-8601>","event":"correction","parent":{"capability":"CAP-NNN","epic":"E<NNN>"},"notes":"Parent backfilled by roadmap Phase 7 after epic generation"}
```
Also write the registry entry's id into the epic's `registry_entries` array in `docs/roadmap/epic-registry.json` (see `references/main.md` Epic Registry JSON Schema).

**Phase 8**: Write summary, update indexes, generate tracker, write manifest. **In `refresh` mode, Phase 8 also runs the registry coverage recompute** — see the refresh-mode addendum below.

---

## Autonomous Execution Rules and Error Recovery

See `references/main.md` sections **"Autonomous Execution Rules"** and **"Error Recovery"**.
