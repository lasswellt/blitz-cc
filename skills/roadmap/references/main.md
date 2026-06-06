# Roadmap Skill — Reference Material

Schemas, templates, classification tables, detailed procedures for Phases 5-8 used by roadmap skill.

**Companion protocols:**
- [sprint-contracts.md](/_shared/sprint-contracts.md) — Append-only JSONL registry linking research-doc scope claims to delivered artifacts. Capability and Epic schemas below include fields that roll up to and from this registry.

---

## Capability Extraction Schema

```yaml
id: CAP-NNN            # Sequential ID, zero-padded to 3 digits
title: ""              # Short descriptive title (max 80 chars)
source_document: ""    # Relative path to the research doc
source_anchor: ""      # Heading anchor or line reference inside source_document (e.g., "#scope" or "L142")
document_type: ""      # One of the 8 classification types
description: ""        # 2-3 sentences describing the capability
user_value: ""         # Who benefits and how (1-2 sentences)
acceptance_criteria:   # List of testable criteria
  - ""
complexity: ""         # low | medium | high | very_high
domain_hint: ""        # Suggested domain cluster name
dependencies_hint:     # CAP-IDs this likely depends on
  - ""
research_needed: false # Whether additional research is required
research_triggers:     # Questions that need answering before implementation
  - ""
scope_metric:          # Optional quantified scope — required if source doc has a `scope:` YAML block
  unit: ""             # files | components | routes | tests | endpoints | ...
  target: 0            # Integer count of units promised by the research doc
  description: ""      # Human-readable scope description
  acceptance:          # Executable DoD checks — see sprint-contracts.md
    - grep_absent: ""
    - grep_present: { pattern: "", min: 0 }
registry_entry_id: ""  # Populated when roadmap-extend writes a carry-forward registry line
tags: []               # Freeform tags for cross-referencing
```

**Scope metric extraction:** When source research doc contains `scope:` YAML frontmatter block (see `skills/research/SKILL.md` Phase 3), every entry in that block becomes capability's `scope_metric` and must also be written to `.cc-sessions/carry-forward.jsonl` as registry entry with `status: active`. See [sprint-contracts.md](/_shared/sprint-contracts.md) for full schema and writer responsibilities.

If research doc contains quantified language (regex: `\d+\s+(files|components|modals|routes|tests|endpoints)`) but no `scope:` block, roadmap-extend step must warn user and either (a) prompt to add block or (b) write explicit `<!-- no-registry: <reason> -->` waiver. Enforced by `sprint-review` Invariant 1.

### Complexity Guidelines

| Complexity | Characteristics | Typical Effort |
|-----------|-----------------|----------------|
| `low` | Single file change, well-understood pattern, no new dependencies | 1-2 stories |
| `medium` | Multiple files, some new patterns, minimal new dependencies | 3-5 stories |
| `high` | Cross-module changes, new infrastructure, external integrations | 6-10 stories |
| `very_high` | Architectural changes, new systems, significant research needed | 10+ stories |

---

## Document Classification Table

| Type | Key Indicators | What to Extract |
|------|---------------|-----------------|
| `product_definition` | Vision statements, user personas, value props, business goals | High-level capabilities, user types, success metrics |
| `feature_spec` | User stories, wireframes, acceptance criteria, flow diagrams | Detailed capabilities with ACs, UI requirements |
| `competitive_analysis` | Competitor comparisons, market gaps, differentiators | Capabilities that fill market gaps, differentiation features |
| `nfr` | Performance targets, SLAs, compliance requirements, accessibility | Non-functional capabilities (perf budgets, a11y, security) |
| `architecture` | System diagrams, data models, API specs, infrastructure | Infrastructure capabilities, data model requirements |
| `brand_ux` | Design tokens, UX principles, component library specs, style guides | UI system capabilities, design constraints |
| `integration_spec` | API contracts, webhook specs, OAuth flows, protocol docs | Integration capabilities, external dependencies |
| `operational` | Deploy scripts, monitoring dashboards, runbooks, SLI/SLOs | DevOps capabilities, observability requirements |

### Classification Heuristics

Read first 50 lines and headings of each document. Match against:
- Contains "vision", "mission", "persona" → `product_definition`
- Contains "user story", "as a ... I want" → `feature_spec`
- Contains "competitor", "alternative", "market" → `competitive_analysis`
- Contains "performance", "SLA", "compliance", "accessibility" → `nfr`
- Contains "architecture", "data model", "schema", "API" → `architecture`
- Contains "design system", "brand", "typography", "color" → `brand_ux`
- Contains "integration", "webhook", "OAuth", "API contract" → `integration_spec`
- Contains "deploy", "monitor", "CI/CD", "runbook" → `operational`

If document matches multiple types, use primary focus. Note secondary types in metadata.

---

## Implementation Status Schema

```yaml
capability: CAP-NNN
status: not_started | partial | implemented | complete
evidence:
  - file: ""           # Relative path to evidence file
    relevance: ""      # What this file contributes to the capability
    lines: ""          # Relevant line range (optional)
coverage: 0.0          # 0.0 to 1.0 — fraction of ACs met by existing code
gaps:
  - ""                 # What's missing to reach full implementation
blockers:
  - ""                 # External blockers (missing APIs, pending decisions)
existing_patterns:
  - pattern: ""        # Pattern name (e.g., "composable data fetching")
    file: ""           # Example file using this pattern
    reuse: ""          # How this pattern applies to the capability
```

### Status Decision Rules

| Status | Criteria |
|--------|----------|
| `not_started` | No files in the codebase relate to this capability |
| `partial` | Some infrastructure exists (types, schemas, stubs) but core logic is missing |
| `implemented` | Core logic exists but does not fully match spec (missing ACs, different behavior) |
| `complete` | All acceptance criteria are met by existing code |

---

## Domain Document Templates

### Domain Overview (`docs/roadmap/domains/<slug>/overview.md`)

```markdown
# Domain: <Domain Name>

## Purpose
<1-2 sentences describing what this domain covers>

## Capabilities
| ID | Title | Complexity | Status | Phase |
|----|-------|-----------|--------|-------|
| CAP-NNN | <title> | <complexity> | <status> | <phase> |

## Feature Clusters

### Cluster: <cluster-name>
**Capabilities**: CAP-NNN, CAP-NNN
**Shared Data**: <entities this cluster operates on>
**User Journey**: <which user flow this cluster serves>
**Implementation Notes**: <key technical considerations>

## Data Model
<entities, relationships, and key fields relevant to this domain>

## Workflows
<primary user/system workflows within this domain>

## Integration Points
- **Inbound**: <what this domain receives from other domains>
- **Outbound**: <what this domain provides to other domains>
- **External**: <third-party services this domain interacts with>

## Technical Constraints
<known limitations, performance requirements, compatibility concerns>
```

### Feature Cluster Schema

```yaml
name: ""                    # Human-readable cluster name
slug: ""                    # kebab-case identifier
capabilities: []            # List of CAP-IDs
shared_data_entities: []    # Entity names this cluster reads/writes
user_journey: ""            # Which user flow this serves
primary_screens: []         # UI screens/pages involved
backend_services: []        # Backend services/functions needed
estimated_stories: 0        # Rough story count for the cluster
```

---

## Research Cache Schema

```json
{
  "generated": "<ISO-8601>",
  "entries": [
    {
      "id": "RC-NNN",
      "source": "context7|web",
      "query": "<search query used>",
      "related_capabilities": ["CAP-NNN"],
      "findings": [
        "<key finding as a bullet point>"
      ],
      "confidence": "high|medium|low",
      "url": "<source URL if web>",
      "library": "<library name if context7>",
      "cached_at": "<ISO-8601>",
      "expires_at": "<ISO-8601, 30 days from cached_at>"
    }
  ]
}
```

### Confidence Level Guidelines

| Level | Criteria |
|-------|----------|
| `high` | Official documentation, well-established best practice, verified by multiple sources |
| `medium` | Community best practice, single authoritative source, recently updated |
| `low` | Blog posts, opinions, outdated documentation, unverified claims |

---

## Phases 5-8 Detailed Procedures

### Phase 5: IMPLEMENTATION SPECS — Domain-Level Detail

#### 5.1 Spawn Domain Agents via Agent Tool

For each domain, spawn agent using `Agent` tool (all in single assistant message for parallelism):
- `subagent_type: general-purpose` (must Write; `Explore` cannot)
- `model: sonnet` (explicit — prevents `[1m]` inheritance)
- `description: roadmap-spec <domain-slug>`
- `prompt`: spec-generation template with domain overview, capabilities, stack profile
- `run_in_background: true`

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)) — max 15 file reads, 5-min wall-clock, stub-then-append write pattern. Previous `TeamCreate`+`SendMessage` spawn removed in v1.4.0.

Each agent receives:
- Domain overview document
- Capability details for capabilities in this domain
- Codebase state assessment for relevant capabilities
- Research cache entries related to this domain
- Detected stack profile

Each agent produces `docs/roadmap/domains/<slug>/spec.md` containing:

1. **Data Model Specification**
   - Entity definitions with TypeScript interfaces
   - Relationships (1:1, 1:N, N:N)
   - Indexes and constraints
   - Migration path from current state (if partial/implemented)

2. **API Contract Specification**
   - Endpoint/function signatures
   - Request/response types
   - Error responses
   - Auth requirements per endpoint

3. **Component Tree** (for domains with UI)
   - Page components
   - Composite components
   - Atom components
   - Props/emits for each

4. **Workflow Diagrams** (text-based)
   - User flow: step-by-step with decision points
   - System flow: data flow through services
   - Error flow: what happens when things go wrong

5. **Testing Strategy**
   - Unit test targets (functions, composables)
   - Integration test targets (API flows, store interactions)
   - E2E test targets (critical user journeys)

#### 5.3 Collect and Validate Specs

**Before reading any spec file, validate output presence**:

```bash
MISSING_COUNT=0
for domain in <list-of-domains>; do
  SPEC_FILE="docs/roadmap/domains/${domain}/spec.md"
  if [ ! -s "$SPEC_FILE" ]; then
    echo "MISSING: $SPEC_FILE" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # Log to .cc-sessions/activity-feed.jsonl
  fi
done
```

**Gate**: If any domain spec file missing or empty, retry that domain's agent once with narrower scope (fewer capabilities). If still failed, write explicit placeholder spec noting domain was not analyzed, flag in final summary, do NOT silently proceed.

Read all generated spec files. Validate:
- Every capability in domain is covered
- Data models consistent across domains (shared entities match)
- API contracts don't conflict

#### 5.4 Cross-Domain Consistency Check

Compare data models across domains. If entity `User` appears in Domain A and Domain B, definitions must match. Flag conflicts for manual resolution.

---

### Phase 6: CROSS-CUTTING SPECS — System-Wide Concerns

Generate specs for concerns that span all domains:

#### 6.1 Auth System Spec
Write `docs/roadmap/cross-cutting/auth-spec.md`:
- Auth flow (login, signup, session management)
- Role/permission model
- Route protection strategy (guards, middleware)
- Token management

#### 6.2 Error Handling Strategy
Write `docs/roadmap/cross-cutting/error-handling-spec.md`:
- Error type hierarchy
- Frontend error display patterns
- Backend error response format
- Logging and monitoring

#### 6.3 Testing Strategy
Write `docs/roadmap/cross-cutting/testing-spec.md`:
- Test framework and configuration
- Coverage targets
- Test data management
- CI integration

#### 6.4 CI/CD Pipeline
Write `docs/roadmap/cross-cutting/cicd-spec.md`:
- Build pipeline stages
- Environment management (dev, staging, production)
- Deployment strategy
- Rollback procedures

#### 6.5 Monitoring and Observability
Write `docs/roadmap/cross-cutting/monitoring-spec.md`:
- Logging strategy (structured logging, log levels)
- Metrics and alerting
- Health checks
- Performance monitoring

---

### Phase 7: EPIC GENERATION — Sprint-Ready Work Items

#### 7.1 Spawn Phase Agents via Agent Tool

For each implementation phase (from Phase 4), spawn agent using `Agent` tool (all in single assistant message for parallelism):
- `subagent_type: general-purpose` (must Write epic files; `Explore` cannot)
- `model: sonnet` (explicit — prevents `[1m]` inheritance)
- `description: roadmap-epics phase-<N>`
- `prompt`: epic-generation template with phase plan, domain specs, cross-cutting specs, codebase state
- `run_in_background: true`

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)) — max 15 file reads, 5-min wall-clock, stub-then-append write pattern. Previous `TeamCreate`+`SendMessage` spawn removed in v1.4.0.

After spawning, validate each expected phase's epic directory was created and contains at least one epic file before proceeding to Phase 8.

Each agent receives:
- Phase plan (capabilities, domains, workstreams)
- Domain specs for domains in this phase
- Cross-cutting specs
- Codebase state assessment

Each agent produces epics in `docs/roadmap/epics/phase-N/`.

#### 7.3 Epic Format

Each epic file (`docs/roadmap/epics/phase-N/E<NNN>-<slug>.md`):

```markdown
---
id: E<NNN>
title: "<epic title>"
phase: <N>
domain: "<domain-slug>"
capabilities: [CAP-NNN]
status: planned
depends_on: [E<NNN>]
estimated_points: <N>
estimated_stories: <N>
---

# <Epic Title>

## Description
<2-3 sentences describing scope and purpose>

## Capabilities Addressed
| ID | Title | Coverage |
|----|-------|----------|
| CAP-NNN | <title> | <what this epic covers for this capability> |

## Acceptance Criteria
1. <testable criterion>
2. ...

## Technical Approach
<high-level implementation strategy, key decisions, patterns to use>

## Stories (Outline)
1. **<story-title>** — <1 sentence> (Points: N)
2. ...

## Dependencies
- **Requires**: <epic-ids or "None">
- **Enables**: <epic-ids that depend on this>

## Risk Factors
- <identified risks and mitigations>
```

#### 7.4 Epic Numbering

Epics numbered globally: `E001`, `E002`, etc. Numbering follows phase order, then domain order within phase, then dependency depth within domain.

#### 7.5 Validate Epic Graph

After all agents complete:
- Verify no circular dependencies between epics
- Verify all capability-to-epic mappings are complete
- Verify story count estimates are reasonable (5-15 stories per epic)
- Verify cross-phase dependencies are minimal (phases should be largely independent)

#### 7.6 Write Epic Registry

**Registry Lock — `docs/roadmap/epic-registry.json`**: Before writing, acquire a file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md):
1. CHECK if `docs/roadmap/epic-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `docs/roadmap/epic-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `docs/roadmap/epic-registry.json.lock` and append `lock_released` to the operation log.

Write/update `docs/roadmap/epic-registry.json` using Epic Registry JSON Schema defined below. Include all epics generated across all phases, their dependency graph, phase groupings.

---

### Phase 8: SUMMARY AND MANIFEST — Final Outputs

#### 8.1 Write Roadmap Summary

Write `docs/roadmap/SUMMARY.md`:

```markdown
# Implementation Roadmap Summary

**Generated**: <ISO-8601>
**Stack**: <detected stack>
**Research Documents**: <count>
**Capabilities Extracted**: <count>
**Domains Identified**: <count>
**Epics Generated**: <count>
**Estimated Total Stories**: <count>

## Phase Overview
| Phase | Name | Epics | Stories | Duration | Key Deliverables |
|-------|------|-------|---------|----------|-----------------|

## Domain Map
| Domain | Capabilities | Epics | Primary Phase |
|--------|-------------|-------|---------------|

## Critical Path
<ordered list of capabilities/epics on the longest dependency chain>

## Parallel Workstreams
<visual representation of what can be worked on simultaneously>

## Open Questions
<unresolved items that need product/architecture decisions>

## Risk Register
| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
```

#### 8.2 Update Indexes

**Registry Lock — `docs/roadmap/roadmap-registry.json`**: Before writing, acquire a file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md):
1. CHECK if `docs/roadmap/roadmap-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `docs/roadmap/roadmap-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `docs/roadmap/roadmap-registry.json.lock` and append `lock_released` to the operation log.

Write/update `docs/roadmap/roadmap-registry.json`:
```json
{
  "generated": "<ISO-8601>",
  "mode": "full|refresh|extend",
  "research_documents": <count>,
  "capabilities": <count>,
  "domains": <count>,
  "phases": <count>,
  "epics": <count>,
  "estimated_stories": <count>,
  "critical_path_length": <count>,
  "phase_summary": [
    {
      "phase": 1,
      "name": "<name>",
      "epic_count": 0,
      "story_estimate": 0,
      "status": "planned"
    }
  ]
}
```

#### 8.3 Generate Tracker

Write `docs/roadmap/tracker.md`:

```markdown
# Roadmap Tracker

> Auto-generated. Update epic statuses as work progresses.

| Epic | Title | Phase | Domain | Status | Depends On | Points |
|------|-------|-------|--------|--------|-----------|--------|
| E001 | ... | 1 | ... | planned | - | N |
```

#### 8.4 Write Manifest

Write `docs/roadmap/manifest.json` — single file linking to every generated artifact:
```json
{
  "generated": "<ISO-8601>",
  "artifacts": {
    "capability_index": "docs/roadmap/capability-index.json",
    "research_cache": "docs/roadmap/research-cache.json",
    "gap_analysis": "docs/roadmap/gap-analysis.md",
    "domain_index": "docs/roadmap/domain-index.json",
    "phase_plan": "docs/roadmap/phase-plan.json",
    "summary": "docs/roadmap/SUMMARY.md",
    "registry": "docs/roadmap/roadmap-registry.json",
    "tracker": "docs/roadmap/tracker.md",
    "domains": "docs/roadmap/domains/",
    "epics": "docs/roadmap/epics/",
    "cross_cutting": "docs/roadmap/cross-cutting/"
  }
}
```

#### 8.5 Final Output

Print summary to user:

```
Roadmap Generation Complete.
=============================
Mode: <full|refresh|extend>
Research Documents: <count>
Capabilities Extracted: <count>
Domains Identified: <count>
Phases Planned: <count>
Epics Generated: <count>
Estimated Total Stories: <count>
Critical Path: <count> epics

Artifacts written to: docs/roadmap/
Registry: docs/roadmap/roadmap-registry.json
Summary: docs/roadmap/SUMMARY.md
Tracker: docs/roadmap/tracker.md
```

---

## Epic Template (Machine-Readable)

```json
{
  "id": "E<NNN>",
  "title": "",
  "phase": 0,
  "domain": "",
  "capabilities": ["CAP-NNN"],
  "status": "planned|in_progress|done|blocked",
  "depends_on": ["E<NNN>"],
  "blocks": ["E<NNN>"],
  "estimated_points": 0,
  "estimated_stories": 0,
  "acceptance_criteria": [""],
  "stories_outline": [
    {
      "title": "",
      "description": "",
      "points": 0,
      "assigned_role": "backend-dev|frontend-dev|test-writer|infra-dev"
    }
  ],
  "risks": [
    {
      "description": "",
      "impact": "high|medium|low",
      "mitigation": ""
    }
  ]
}
```

---

## Epic Registry JSON Schema

```json
{
  "epics": [
    {
      "id": "E<NNN>",
      "title": "",
      "phase": 0,
      "domain": "",
      "status": "planned",
      "depends_on": [],
      "estimated_stories": 0,

      "source_research_doc": "docs/_research/YYYY-MM-DD_<slug>.md",
      "registry_entries": ["cf-YYYY-MM-DD-<slug>"],
      "acceptance_criteria_count": 0,
      "acceptance_criteria_met": 0,
      "acceptance_criteria_waived": 0,
      "coverage": 0.0,
      "carry_forward_count": 0,
      "last_touched_sprint": "sprint-<N>"
    }
  ],
  "dependency_graph": {
    "E001": ["E003", "E004"],
    "E002": []
  },
  "phases": {
    "1": { "name": "", "epics": ["E001", "E002"], "status": "planned" },
    "2": { "name": "", "epics": ["E003"], "status": "planned" }
  }
}
```

### Carry-Forward Integration Fields

The following epic fields link roadmap to carry-forward registry described in [sprint-contracts.md](/_shared/sprint-contracts.md). They are rollup view of registry from epic's perspective — authoritative per-entry state lives in `.cc-sessions/carry-forward.jsonl`, not here.

| Field | Purpose | Written by |
|---|---|---|
| `source_research_doc` | Back-link to the research doc that originated the epic's scope. Enables `sprint-review` Invariant 3 to verify that roadmap "N/N complete" claims match registry coverage. | `roadmap` phases 1 and 7 (ingest + epic generation) |
| `registry_entries` | List of carry-forward registry ids whose parent is this epic. One epic can have multiple registry entries if its research doc had multiple quantified scope claims. | `roadmap extend` when it writes a new registry line |
| `acceptance_criteria_count` | Total ACs across all stories in all sprints for this epic. | `sprint-plan` Phase 4.1 |
| `acceptance_criteria_met` | Count of ACs whose executable DoD checks passed in `/blitz:review --only completeness`. | `sprint-review` Phase 3.5 |
| `acceptance_criteria_waived` | Count of ACs auto-waived by `sprint-plan` Phase 4.1 in `autonomy ∈ {high, full}`. | `sprint-plan` Phase 4.1 |
| `coverage` | `acceptance_criteria_met / acceptance_criteria_count`. Never set manually. | `sprint-review` Phase 3.5 |
| `carry_forward_count` | Sum of `rollover_count` across all child registry entries. When any child crosses `rollover_count >= 3`, this also crosses 3 and the epic is flagged for mandatory human review. | `sprint-review` Phase 3.5 |
| `last_touched_sprint` | The most recent sprint that shipped a story against this epic. Used by `sprint --loop` to distinguish stalled epics from completed ones. | `sprint-dev` on story completion |

**Epic completion gate:** epic's `status` cannot transition to `done|complete` while any of its `registry_entries` have `status ∈ {active, partial}` in carry-forward registry. Enforced by `sprint-review` Invariant 3 and `sprint --loop` Step 2 row 7.

---

## Autonomous Execution Rules

1. **Never ask for confirmation between phases.** Execute all phases in sequence. Only stop if gate condition fails.
2. **Write artifacts incrementally.** Do not accumulate everything in memory. Write each document as completed.
3. **Prefer specificity over abstraction.** Generated specs should reference actual file paths, function names, types from codebase.
4. **Respect existing code.** If codebase already has pattern for something, roadmap should use that pattern, not invent new one.
5. **Cap research time.** Context7 lookups: max 8. Web searches: max 12. Do not spend more than 20% of total execution on research.
6. **Handle missing data gracefully.** If research document is vague, extract what you can and flag gaps. Do not stop pipeline.
7. **Maintain traceability.** Every epic must trace back to capabilities. Every capability must trace back to source document.
8. **Phase gates are strict.** If gate fails, stop and report why. Do not proceed with insufficient data.
9. **Parallelize where possible.** When spawning agents (Phases 5, 7), run concurrently.
10. **Produce machine-readable outputs.** Every phase writes both human-readable markdown and machine-readable JSON. JSON feeds downstream skills (sprint-plan, sprint-dev).

---

## Error Recovery

- **No research documents found**: Inform user. Suggest creating research docs in `docs/_research/`; provide 8-type classification table.
- **Existing roadmap found on `full` mode**: Warn user this will overwrite. Suggest `refresh` or `extend` instead. Proceed only if user confirms (or rename existing to `.bak`).
- **Circular dependencies detected**: Report cycle with involved capabilities. Suggest breaking cycle by splitting capability. Do not proceed with phase assignment until resolved.
- **Agent failure in Phases 5/7**: Retry once. If still failing, generate specs manually for that domain; note reduced quality.
- **Insufficient capabilities**: If fewer than 5 capabilities extracted, warn roadmap may be too thin. Proceed but flag in summary.
- **Conflicting research**: If two documents contradict, flag conflict in capability notes; use more recent document as primary source.

---

## Phase 2.4: Carry-Forward Registry Coverage Recompute (`refresh` mode)

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

See `skills/_shared/sprint-contracts.md` for the full protocol.
