# Sprint Plan Reference

Supporting schemas, templates, and logic for the sprint-plan skill.

**Companion protocols:**
- [carry-forward-registry.md](/_shared/carry-forward-registry.md) — The append-only JSONL registry. Sprint-plan reads it in Phase 0 for mandatory planning inputs and writes to it in Phase 4.1 when auto-waiving acceptance criteria.

---

## Story File Format

The story-frontmatter contract — schema, producer/consumer matrix, validation algorithm, body sections, and gap-closure template — lives in **[/_shared/story-frontmatter.md](/_shared/story-frontmatter.md)**. Sprint-plan, sprint-dev, and sprint-review all link to that single source.

This section previously duplicated the schema; the duplication caused producer/consumer drift (CAP-133 carry-forward incident traced partly to that duplication). Schema changes go into the shared doc only.

**Sprint-plan-specific responsibilities** when emitting story files:
- Phase 3.2 generates one `S${N}-${SEQ}-<slug>.md` per story under `sprints/sprint-${N}/stories/`.
- The `id:` field MUST equal the filename's `S${N}-${SEQ}` prefix.
- `status:` is always `"planned"` at creation.
- `github_issue:` is `null` until Phase 4.5 (post-issue-creation).
- `registry_entries:` is populated in Phase 4.1 from the auto-waiver / coverage-link logic; never inferred at planning time.
- For `--gaps` mode, set `type: "gap-closure"` and populate `source_finding:` per the shared schema's conditional-required rule.

---

## Story Partition Logic

Stories are assigned to agent roles based on the primary file types they touch.

### Assignment Rules Table

| File Pattern | Story Focus | Assigned Agent |
|---|---|---|
| `**/schemas/**`, `**/types/**`, `**/models/**` | Type definitions, validation schemas | `backend-dev` |
| `**/api/**`, `**/server/**`, `**/functions/**` | API routes, server handlers, cloud functions | `backend-dev` |
| `**/stores/**`, `**/composables/**`, `**/services/**` | State management, business logic, data services | `backend-dev` |
| `**/components/**`, `**/pages/**`, `**/layouts/**` | UI components, page views, layout templates | `frontend-dev` |
| `**/assets/**`, `**/styles/**`, `**/design-tokens/**` | Design tokens, CSS, static assets | `frontend-dev` |
| `**/*.test.*`, `**/*.spec.*`, `**/tests/**` | Unit tests, integration tests, e2e tests | `test-writer` |
| `**/firebase/**`, `**/infra/**`, `**/.github/**`, `**/ci/**` | Infrastructure, deployment, CI/CD config | `infra-dev` |
| `**/middleware/**`, `**/plugins/**` | Cross-cutting middleware, framework plugins | `backend-dev` |
| `**/config/**`, `**/env/**` | Configuration, environment setup | `infra-dev` |

### Conflict Resolution

When a story touches files matching multiple agents:
1. Assign to the agent whose files are **primary** (most lines changed).
2. If equal, prefer this priority: `backend-dev` > `frontend-dev` > `test-writer` > `infra-dev`.
3. Add a `coordination_note` to the story frontmatter naming the secondary agent.

### Balance Check

After partitioning, verify rough balance:
- No single agent has more than 50% of total story points.
- If imbalanced, consider splitting large stories or reassigning borderline stories.
- Test stories should be ~20-30% of total count (one test story per 2-3 implementation stories).

---

## Sprint Manifest JSON Schema

The per-sprint manifest lives at `sprints/sprint-${N}/manifest.json` and captures sprint-scoped state that is too volatile for the global `sprint-registry.json`. Sprint-plan writes this file at Phase 1.4; sprint-dev and sprint-review read and update it.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["sprint", "status", "created", "epics", "story_count"],
  "properties": {
    "sprint": { "type": "integer" },
    "status": {
      "type": "string",
      "enum": ["planning", "planned", "in-progress", "review", "reviewed", "done", "cancelled"]
    },
    "created": { "type": "string", "format": "date-time" },
    "epics": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Epic IDs selected for this sprint"
    },
    "carry_forward": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Story IDs carried forward from the previous sprint (incomplete stories)"
    },
    "story_count": { "type": "integer" },

    "waived_ac_count": {
      "type": "integer",
      "description": "Number of acceptance criteria auto-waived during Phase 4.1 under autonomy=high|full. Every waiver MUST also append a corresponding line to .cc-sessions/carry-forward.jsonl with event: 'auto_waived' — see skills/_shared/carry-forward-registry.md."
    },
    "reason_waivers": {
      "type": "string",
      "description": "Short phrase explaining why waivers were applied, e.g., 'autonomy=full'. Populated alongside waived_ac_count."
    },
    "registry_entries_touched": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of carry-forward registry ids (cf-*) that this sprint's stories advanced. Each entry MUST have been injected as a mandatory planning input OR explicitly claimed by a story in this sprint. Written during Phase 4.1 coverage check; audited in sprint-review Phase 3.6 Invariant 2."
    },
    "mandatory_planning_inputs_source": {
      "type": "string",
      "description": "Path to sprints/sprint-${N}-planning-inputs.json if the previous sprint-review auto-injected entries into this sprint. Empty when no carry-forward was pending."
    }
  }
}
```

**Waiver accounting:** `waived_ac_count` is the local mirror of what also gets written to the carry-forward registry. Sprint-review Phase 3.5 Invariant 2 cross-checks the two: for every `waived_ac_count > 0`, there MUST be a matching `event: "auto_waived"` line in `.cc-sessions/carry-forward.jsonl` for an entry whose parent epic appears in this manifest's `epics` field. Missing mirror → invariant failure.

---

## Sprint Registry JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "project": {
      "type": "string",
      "description": "Project name (auto-detected from package.json or directory)"
    },
    "current_sprint": {
      "type": "integer",
      "description": "The most recently planned sprint number"
    },
    "sprints": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["number", "status", "planned_date", "epics", "story_count", "stories"],
        "properties": {
          "number": { "type": "integer" },
          "status": {
            "type": "string",
            "enum": ["planned", "in-progress", "review", "done", "cancelled"]
          },
          "planned_date": { "type": "string", "format": "date-time" },
          "started_date": { "type": "string", "format": "date-time" },
          "completed_date": { "type": "string", "format": "date-time" },
          "epics": {
            "type": "array",
            "items": { "type": "string" }
          },
          "story_count": { "type": "integer" },
          "stories": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Story IDs (e.g., S1-001, S1-002)"
          },
          "carry_forward_from": {
            "type": "integer",
            "description": "Previous sprint number if stories were carried forward"
          },
          "agents": {
            "type": "object",
            "description": "Story count per agent role",
            "properties": {
              "backend-dev": { "type": "integer" },
              "frontend-dev": { "type": "integer" },
              "test-writer": { "type": "integer" },
              "infra-dev": { "type": "integer" }
            }
          },
          "github_milestone": {
            "type": "string",
            "description": "GitHub milestone URL if created"
          }
        }
      }
    }
  }
}
```

---

## Agent Prompt Templates

<!-- import: /_shared/agent-prompt-boilerplate.md -->
Canonical boilerplate (Generic Agent Preamble, Medium BUDGET, WRITE-AS-YOU-GO) is documented in [/_shared/agent-prompt-boilerplate.md](/_shared/agent-prompt-boilerplate.md). The inline opening block + per-researcher templates below remain the byte-stable spawn source — OUTPUT STYLE inline preservation is required by sprint-review Invariant 5.

**Workload class for all sprint-plan research agents**: Medium (per `skills/_shared/spawn-protocol.md`). Every agent prompt below must open with:

```
You are a general-purpose agent with Write access. Your task is INCOMPLETE
if your output file does not exist when you finish.

BUDGET:
- Max file reads: 15
- Max web searches: 8 (0 for codebase-analyst)
- Max tool calls: 25
- Max output: 250 lines
- Wall-clock: 5 minutes

WRITE-AS-YOU-GO: Stub your output file with `# IN PROGRESS` before your
first research step. After each epic analyzed, append findings to the
file immediately. Do NOT accumulate in memory and write at the end.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

### Domain Researcher

```
You are the domain-researcher for Sprint ${SPRINT_NUMBER} planning.

[Include the workload class block above as the first lines of this prompt.]

RESEARCH FOCUS: External APIs, domain standards, protocols, and patterns relevant to the selected epics.

SELECTED EPICS:
${EPIC_LIST}

INSTRUCTIONS:
1. For each epic, identify external APIs, services, or protocols involved.
2. Research current best practices, authentication patterns, rate limits, and error handling.
3. Look for official documentation, migration guides, and known gotchas.
4. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-domain-researcher.md — stub the file first, then append as you go.

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### External Dependencies
- <API/service name>: <key findings>
### Patterns & Best Practices
- <pattern>: <recommendation>
### Risks & Gotchas
- <issue>: <mitigation>

```

### Library Researcher

```
You are the library-researcher for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Package ecosystem, library versions, compatibility, migration paths, and implementation examples.

SELECTED EPICS:
${EPIC_LIST}

DETECTED STACK:
${STACK_PROFILE}

INSTRUCTIONS:
1. For each epic, identify required packages and their current stable versions.
2. Check compatibility with the detected stack (especially framework version).
3. Find implementation examples, especially for complex integrations.
4. Note any required peer dependencies or breaking changes.
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-library-researcher.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Required Packages
| Package | Version | Purpose | Compat Notes |
|---------|---------|---------|--------------|
### Implementation Examples
- <pattern>: <code reference or link>
### Migration / Breaking Changes
- <package>: <notes>

```

### Codebase Analyst

```
You are the codebase-analyst for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Existing code patterns, reusable modules, integration points, and potential conflicts.

SELECTED EPICS:
${EPIC_LIST}

PROJECT STRUCTURE:
${CODEBASE_INVENTORY}

INSTRUCTIONS:
1. For each epic, search the codebase for related existing code.
2. Identify reusable patterns (composables, utilities, components, schemas).
3. Map integration points where new code must connect to existing code.
4. Flag potential conflicts (naming collisions, import cycles, shared state).
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-codebase-analyst.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Existing Patterns to Reuse
- <file path>: <what it provides>
### Integration Points
- <file path>: <how new code connects>
### Potential Conflicts
- <issue>: <description and suggestion>
### Suggested File Locations
- <new file path>: <rationale based on existing conventions>

```

### Infrastructure Analyst (Optional)

```
You are the infra-analyst for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Cloud configuration, security rules, deployment pipeline, environment variables, and infrastructure requirements.

SELECTED EPICS:
${EPIC_LIST}

INSTRUCTIONS:
1. Review existing infrastructure config (firebase.json, cloud functions, CI/CD).
2. Identify infrastructure changes needed for the selected epics.
3. Check security rules for required updates.
4. Note any environment variables or secrets that must be configured.
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-infra-analyst.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Infrastructure Changes Required
- <resource>: <change description>
### Security Rules Updates
- <rule>: <current state> -> <required state>
### Environment Configuration
- <variable>: <purpose and where to set it>
### Deployment Considerations
- <consideration>: <details>

```

---

## Error Recovery

- **No epics available**: All epics are blocked or done. Inform user and suggest updating the roadmap. *(If autonomy is `high` or `full`, log to activity feed and exit cleanly — the `/loop` reconciler will detect this state.)*
- **Research agent failure**: Retry once. If still failing, proceed with partial research and flag gaps in summary.
- **Circular dependencies detected**: Report the cycle and ask user to resolve before continuing. *(If autonomy is `high` or `full`, break the cycle by removing the weakest dependency edge — the one with the lowest story priority — log the decision to the activity feed, and proceed.)*
- **GitHub CLI unavailable**: Skip issue creation, note in summary. Stories are still valid without issues.

## Story Body Sections

The body must include:
- **Description**: 1-3 fragments on what and why (verb-first; drop articles). Example: "Add null guard on profile.load(). Prevents dashboard crash when user.profile undefined."
- **Acceptance Criteria**: Numbered list, each testable and specific.
- **Implementation Notes**: Key code patterns, imports, relevant research references.
- **Code Snippets**: Starter code where helpful (types, function signatures, test skeletons).
- **Dependencies**: Which stories or external things must be done first.
