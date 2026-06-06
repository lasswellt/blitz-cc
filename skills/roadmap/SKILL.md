---
name: roadmap
description: Generates phased implementation roadmaps from research documents. Extracts capabilities, assesses codebase state, clusters features into domains, resolves dependencies, and produces epic-ready implementation plans. Use when user says "generate roadmap", "plan phases", "roadmap status", "extend roadmap".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
argument-hint: "[full|refresh|extend|status]"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For capability schema, document classification, and Phases 5-8 procedures, see [references/main.md](references/main.md)
- For the carry-forward registry (written in Phase 1 from research doc scope: blocks; re-scanned in refresh mode), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For pipeline artifact contracts (`docs/roadmap/`, `capability-index.json` consumed by sprint-plan), see [/_shared/session-lifecycle.md](/_shared/session-lifecycle.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)

All generated epics and roadmap artifacts must satisfy the [Definition of Done](/_shared/sprint-contracts.md). No placeholder descriptions.


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Roadmap Generation Skill

Generate phased implementation roadmaps from research documents. Execute the appropriate mode based on arguments. Do NOT skip phases.

## Mode Routing

Parse `$ARGUMENTS`; default to `full` if absent.

| Argument | Mode | Phases run |
|----------|------|------------|
| `full` (default) | Full Generation | 0-8. Use when no roadmap exists. |
| `refresh` | Refresh | 0-4, then Phases 5-8 for changed domains only. Phase 1 re-scans carry-forward registry — see Phase 1.1.6 and `skills/_shared/sprint-contracts.md`. |
| `extend` | Extend | Phase 0; Phase 1 for new docs only (Phase 1.1.5 hard-fails on duplicate registry ids); Phase 4 for dependency re-resolution; Phases 5-8 for new domains only. |
| `status` | Status | Phase 0 load only → print status report → STOP. No generation. |

---

## Phase 0: CONTEXT — Load Project State

### 0.0 Register Session
Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Locate Registry Files
```
Glob: **/roadmap-registry.json, **/epic-registry.json, **/roadmap/**/*.md, **/docs/roadmap/**/*
```

### 0.2 Load Research Index
```
Glob: **/docs/_research/**/*.md, **/docs/research/**/*.md, **/research/**/*.md, **/_research/**/*.md, **/docs/audits/*-epics.md
```

Audit-derived docs (`*-epics.md` under `docs/audits/`) follow the same `scope:` block protocol — see `skills/audit/SKILL.md` Phase 3.3a. Only `*-epics.md` files are ingested; `audit-YYYYMMDD.md` and `audit-YYYYMMDD-index.json` are NOT consumed by `roadmap extend`.

If no research documents OR audit `-epics.md` files found:
```bash
echo "BLOCK: roadmap requires research documents in docs/_research/ OR audit -epics.md files in docs/audits/. Run /blitz:research or /blitz:audit first." >&2
exit 1
```

### 0.3 Build Codebase Inventory
```bash
find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
```
Read root `package.json` and workspace configs. Identify project structure (monorepo vs single), packages/modules and purposes, current dependencies.

### 0.4 Load Existing Roadmap (if any)
If a roadmap registry exists, read registry JSON; note completed/in-progress/pending epics; load capability index if present.

For `status` mode: print the status report now and STOP. Report = `# Roadmap Status Report` with: Last Updated, Total Capabilities, Total Epics; **Phase Summary** table (`| Phase | Epics | Completed | In Progress | Pending | Blocked |`); **Next Actions** (unblocked epics ready to start); **Blockers** (blocked epics + what they wait on).

**Gate:** `full` mode requires ≥1 research document. `refresh`/`extend` requires an existing roadmap.

---

## Phase 1: RESEARCH INGESTION — Extract Capabilities

### 1.1 Discover Research Documents

Read every file found in Phase 0.2. For each document:

1. **Classify** using the 8-type table from `references/main.md` (`product_definition`, `feature_spec`, `competitive_analysis`, `nfr`, `architecture`, `brand_ux`, `integration_spec`, `operational`).
2. **Extract capabilities** — discrete implementable units. Assign sequential IDs: `CAP-001`, `CAP-002`, etc.

### 1.1.5 Parse `scope:` YAML Frontmatter (Carry-Forward Registry Ingestion)

Before extracting capabilities, check the research doc for a **`scope:` YAML frontmatter block**. This is the structured-scope contract emitted by `skills/research` Phase 3.1.1. Each entry in the block becomes both a capability `scope_metric` (see `references/main.md`) **and** an append-only line in `.cc-sessions/carry-forward.jsonl`. See [sprint-contracts.md](/_shared/sprint-contracts.md) for the full registry protocol.

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

Compare capabilities across documents by title/description overlap. Merge duplicates: keep richer description, combine acceptance criteria, record in dedup log.

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
Collect capabilities where `research_needed: true`. Group `research_triggers` by theme. Prioritize: `complexity: very_high|high` → external integrations → security/compliance.

### 1B.2 Context7 Lookups (max 8)
Use ToolSearch to check for Context7 MCP tools. If available, look up docs for detected libraries/frameworks (APIs, migration guides, best practices for high-complexity capabilities). Cache in `${SESSION_TMP_DIR}/roadmap-research/context7/`.

### 1B.3 Web Research (max 12)
Use WebSearch for architectural best practices, third-party pricing/limits, security advisories, performance benchmarks. Cache in `${SESSION_TMP_DIR}/roadmap-research/web/`.

### 1B.4 Synthesize Research Cache
Write `docs/roadmap/research-cache.json` (schema from `references/main.md`). Each entry: source (context7|web), query, key findings, confidence (high|medium|low), related CAP-IDs.

---

## Phase 2: CODEBASE STATE ASSESSMENT — What Exists Today

### 2.1 Load Architecture Context
Read framework config files, type definitions/schemas, route definitions, state management files, database schemas.

### 2.2 Build Evidence Matrix
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
Status meanings: `not_started` = no related code; `partial` = infrastructure exists, feature incomplete; `implemented` = exists but may not match spec; `complete` = matches all acceptance criteria.

### 2.3 Gap Analysis
Write `docs/roadmap/gap-analysis.md` (terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md)):
- Greenfield capabilities (no codebase support)
- Partial capabilities (extend/refactor needed)
- Already implemented (verify/skip)
- Infrastructure gaps (missing packages, services, configs)

### 2.4 Carry-Forward Registry Coverage Recompute (`refresh` mode)

**This sub-phase runs in `refresh` mode only.** It re-verifies every carry-forward registry entry against the current codebase by executing the `scope.acceptance` checks stored on the entry, then appends `progress`/`complete` lines and propagates coverage to the epic-registry. This is how a sprint's actual progress gets reconciled with the registry without waiting for sprint-review.

Full Phase 2.4 procedure (load, acceptance-check, compute `delivered.actual`, append update lines, epic-registry propagation, report) + legacy-doc backfill path: [references/main.md](references/main.md#phase-24-carry-forward-registry-coverage-recompute-refresh-mode).

---

## Phase 3: DOMAIN ANALYSIS — Feature Clustering

### 3.1 Feature Clustering
Group capabilities into domains by: shared data models, shared workflows, shared infrastructure, UI proximity.

### 3.2 Architecture-Informed Mapping
Align domains to detected project structure. Map to existing packages/modules; identify new ones needed for unmapped domains; ensure each domain has a clear architectural owner.

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
Resolve dependencies per capability (data, infrastructure, UI, auth). Build a DAG; detect and report cycles.

### 4.2 Apply Sequencing Rules
1. Foundation first: auth, data models, shared infrastructure before features.
2. Backend before frontend: APIs/data layers before consuming UI.
3. Core before extensions: MVP before enhancements.
4. Independent domains in parallel: no cross-dependencies → simultaneous.
5. Testing alongside implementation: test infrastructure in same phase as code.

### 4.3 Calculate Critical Path
Identify the longest dependency chain — determines minimum number of phases.

### 4.4 Assign Implementation Phases
- **Phase 1**: Foundation (auth, data models, core infrastructure, project setup)
- **Phase 2**: Core features (MVP, primary user flows)
- **Phase 3**: Extended features (secondary capabilities, integrations)
- **Phase 4**: Polish (NFRs, optimizations, advanced features)
- **Phase 5+**: Future (nice-to-haves, stretch goals)

Each phase must be independently deployable.

### 4.5 Identify Parallel Workstreams
Within each phase, identify capabilities workable simultaneously by different developers/teams.

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
