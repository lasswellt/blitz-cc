---
name: sprint-plan
description: "Plans the next sprint from roadmap epics. Selects unblocked epics via dependency graph, spawns parallel research agents, generates story files with /_shared/sprint-contracts.md schema, creates GitHub issues. Use when the user says 'plan sprint', 'generate stories', or 'sprint planning'. --gaps generates gap-closure stories from the prior review report."
argument-hint: "[--sprint N] [--gaps]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For story YAML schema (canonical, producer/consumer matrix, validation algorithm), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For pipeline state contracts (which artifacts this skill produces and requires), see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For agent assignment rules and partition logic, see [references/main.md](references/main.md)
- For context window hygiene (research agents), see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For checkpoint awareness, see [session-lifecycle.md](/_shared/session-lifecycle.md)
- For the carry-forward registry (Reader Algorithm in Phase 0, writer contract in Phase 4.1), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For subagent spawning, agent output contract (success/failure/partial thresholds), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, canonical exemptions), see [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

All generated stories must satisfy the [Definition of Done](/_shared/sprint-contracts.md). No placeholder acceptance criteria.

---

# Sprint Planning Skill

Plan a sprint by selecting unblocked epics from the roadmap, conducting parallel research, generating implementation stories, and publishing to GitHub issues. Execute every phase in order. Do NOT skip phases.

## Mode Routing

Check for a `--gaps` flag. If present, run in **gap closure mode** instead of the normal epic-based flow:

### Gap Closure Mode (`--gaps`)

Instead of selecting epics, parse quality gaps from the most recent sprint:

1. **Read sprint review report** — find findings with severity >= high.
2. **Read completeness gate report** — find findings with severity >= medium.
3. **Read STATE.md** — find blocked stories and their reasons.
4. **Group gaps** by shared files and dependency order.
5. **Generate focused fix stories** — each story addresses one gap, referencing the existing code and the specific finding. Tag with `type: gap-closure` in frontmatter.
6. **Skip research phase** — gap closure stories don't need external research.
7. **Skip to Phase 3** (GENERATE STORIES) with the gap-derived stories, then continue normally through Phase 4 (VALIDATE AND PUBLISH).

### Normal Mode (default)

Execute all phases below in order.

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Before any other work, hard-fail if required upstream artifacts are missing. Per [session-lifecycle.md](/_shared/session-lifecycle.md):

```bash
PIPELINE_MISSING=()
for input in \
    "docs/roadmap/roadmap-registry.json" \
    "docs/roadmap/epic-registry.json"; do
  [ -s "$input" ] || PIPELINE_MISSING+=("$input")
done
if [ "${#PIPELINE_MISSING[@]}" -gt 0 ]; then
  echo "BLOCK: missing pipeline inputs (see /_shared/session-lifecycle.md §sprint-plan):" >&2
  printf '  - %s\n' "${PIPELINE_MISSING[@]}" >&2
  echo "Greenfield order: bootstrap → research → roadmap → sprint-plan." >&2
  exit 1
fi
```

The carry-forward registry (`.cc-sessions/carry-forward.jsonl`) is OPTIONAL at this gate — its absence is normal for greenfield projects. Step 8 below handles it.

## Phase 0: CONTEXT — Load Project State

0. **Register session.** Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch (agent spawn, wave completion, etc.) per terse-output.md.
1. **Locate registry files.** Search the repo for sprint/roadmap registry files:
   ```
   Glob: **/sprint-registry.json, **/roadmap-registry.json, **/epic-registry.json, **/epics/**/*.md
   ```
2. **Load the epic/roadmap registry.** Read whatever registry or epic index exists. If none found, inform the user that a roadmap must exist before sprint planning can proceed and STOP.
3. **Load the research index.** Search for `**/research-index.json` or `**/research/**/*.md`. Note which epics already have research.
4. **Build codebase inventory.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read the root `package.json` (if it exists) and any workspace config (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`) to understand project structure.
5. **Load sprint history.** Read `sprint-registry.json` (or equivalent) to determine the last completed sprint number. If no registry exists, this is Sprint 1.
6. **Check for incomplete stories.** Search for story files from previous sprints that have `status: incomplete` or `status: in-progress`. These carry forward.
7. **Check for STATE.md.** If a previous sprint has a `STATE.md` checkpoint file, read it for context on completed/blocked stories. Note blocked stories and their reasons — they may carry forward or inform planning. See [session-lifecycle.md](/_shared/session-lifecycle.md).
8. **Read the carry-forward registry** (`.cc-sessions/carry-forward.jsonl`). Reduce to latest-wins by `id`:
   ```bash
   jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.status == "active" or .status == "partial"))' \
     .cc-sessions/carry-forward.jsonl 2>/dev/null || echo '[]'
   ```
   Every entry returned is a **mandatory planning input** — this sprint MUST either include work against it OR the operator must explicitly transition it to `deferred` with a `notes` reason before planning continues.

   Also read `sprints/sprint-${SPRINT_NUMBER}-planning-inputs.json` if it exists — the previous sprint's review may have auto-injected entries into this sprint via Invariant 4. If present, every entry in that file MUST be addressed in the story set generated below.

   **Why this matters:** carry-forward state lives in the registry, not in `epic-registry.json`'s `status` field. A parent epic can read `status: done` while its child registry entries are still `active` or `partial`. This step is what catches the silent drop described in `docs/_research/2026-04-08_sprint-carryforward-registry.md`. See [sprint-contracts.md](/_shared/sprint-contracts.md) for the reader protocol.

   **Rollover escalation:** any registry entry with `rollover_count >= 3` must NOT be auto-injected. It escalates to mandatory human review — log a blocker to the activity feed and prompt the operator (or, in `autonomy=full`, log the escalation and exit cleanly so `/loop` does not bounce indefinitely). See Error Recovery below for the full escalation path.

**Gate:** You must have at least one epic available **or at least one `status ∈ {active, partial}` registry entry** AND a basic understanding of project structure before proceeding. An idle roadmap with a non-empty registry is NOT "nothing to do."

---

## Phase 1: INITIALIZE — Select Epics and Create Sprint

### 1.1 Topological Sort on Epic Registry

Parse the epic dependency graph. For each epic, check its `depends_on` field. Build a DAG and perform topological sort.

**Selection rules:**
- An epic is **unblocked** if all its dependencies have status `done` or `complete`.
- An epic is **in-progress** if it has stories in a previous sprint that are incomplete.
- Select **all unblocked epics** plus any **in-progress** epics (carry-forward).
- If the user specified particular epics, use those instead (but warn if they have unmet dependencies).
- Target 8-20 stories total per sprint. Select epics accordingly.

### 1.2 Determine Sprint Number

```
SPRINT_NUMBER = (last sprint number from registry) + 1
```

If no registry exists, `SPRINT_NUMBER = 1`.

### 1.3 Create Sprint Directory

```bash
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
mkdir -p "${SPRINT_DIR}/stories"
mkdir -p "${SPRINT_DIR}/research"
```

### 1.4 Write Sprint Manifest

Acquire `${SPRINT_DIR}/manifest.json.lock` per [session-lifecycle.md](/_shared/session-lifecycle.md) §File-Based Locking Protocol. Write `${SPRINT_DIR}/manifest.json` with: `sprint`, `status: planning`, `created`, `epics[]`, `carry_forward[]`, `story_count`.

### 1.5 Sync with GitHub Issues (if available)

`gh auth status` — if authenticated, note repo for later issue creation; otherwise skip GitHub integration.

---

## Phase 2: RESEARCH — Parallel Agent Investigation

### 2.1 Spawn Research Agents via Agent Tool

Spawn 3-4 named agents using the `Agent` tool, all in **a single assistant message** so they run concurrently. Each agent writes findings to `${SESSION_TMP_DIR}/` files incrementally.

Per-spawn parameters:
- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails the write)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from the Opus orchestrator)
- `description: sprint-<N> <agent-role>`
- `prompt`: the template from references/main.md "Agent Prompt Templates" filled with epic list, stack profile, and output path
- `run_in_background: true` (orchestrator polls output files in Phase 2.4)

Cross-cutting findings synthesized by orchestrator in Phase 2.4 from output files (not peer-to-peer, per [agent-orchestration.md](/_shared/agent-orchestration.md)).

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)). Each agent prompt MUST include: max 15 file reads, max 8 web searches (0 for codebase-analyst), max 250-line output, 5-minute wall-clock budget, write-as-you-go instruction.

**Required agents:**

| Agent Name | Role | Focus |
|---|---|---|
| `domain-researcher` | Domain & API Research | External APIs, protocols, standards relevant to selected epics |
| `library-researcher` | Library & Ecosystem Research | Package versions, migration guides, compatibility, best practices |
| `codebase-analyst` | Codebase Analysis | Existing patterns, reusable code, integration points, potential conflicts |

**Optional agent (spawn if backend/cloud services detected):**

| Agent Name | Role | Focus |
|---|---|---|
| `infra-analyst` | Infrastructure Analysis | Cloud config, security rules, deployment pipeline, environment setup |

### 2.2 Agent Prompt Content

Each agent prompt (filled from the template in references/main.md) contains:
1. The list of selected epics (IDs, titles, descriptions).
2. The agent's specific research focus.
3. Output file path: `${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-<agent-name>.md`.
4. The Medium-class budget block (file reads, web searches, wall-clock) and stub-then-append write instructions.

### 2.4 Collect Research

Wait for all agents to complete. **Run the canonical Agent Output Contract validator** from [agent-orchestration.md](/_shared/agent-orchestration.md) §8. The validator classifies each output as SUCCESS / PARTIAL / MALFORMED / EMPTY / MISSING / TIMEOUT and applies the standard gate threshold (N=3 → ABORT at MISSING_COUNT ≥ 2; N=4 → ABORT at MISSING_COUNT ≥ 2). Do NOT redefine thresholds inline.

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-domain-researcher.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-library-researcher.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-codebase-analyst.md"
)
# Add infra-analyst.md if it was spawned.

# Run /_shared/agent-orchestration.md §8 validator (classify_output + standard gate).
# On ABORT: stop Phase 2 and report.
# On survivor singleton: retry the failed agent once with narrower scope (one most-critical epic only).
# On PARTIAL: per §8, queue narrow retries for items in MISSING list.
```

If all classifications resolve to SUCCESS or post-retry SUCCESS, copy outputs into `${SPRINT_DIR}/research/`. Persist any PARTIAL annotations into the sprint manifest's `research_partials` field for sprint-review Invariant 1 cross-check.

---

## Phase 2.5: GOAL-BACKWARD ANALYSIS — Derive Stories from Outcomes

Before generating stories directly from epics, analyze what outcomes the sprint must achieve and work backward to required artifacts.

### 2.5.1 Define Observable Outcomes

For each selected epic, define 2-5 observable outcomes — concrete, testable statements of what a user or developer can do after the sprint. Example: "User can log in with email/password and see their dashboard."

### 2.5.2 Derive Required Artifacts

For each outcome, trace backward through stack layers to identify every artifact (file) required: page → store → schema → API handler → middleware → test.

### 2.5.3 Map Required Connections

For each pair of adjacent artifacts, note the connection that must exist:
- Page imports and calls store action
- Store action calls API function
- API handler validates against schema
- Middleware reads auth state from store

### 2.5.4 Build Coverage Matrix

Create a matrix mapping outcomes × artifacts. Any empty cells represent gaps — artifacts needed but not yet planned. These gaps become additional stories.

```markdown
| Outcome | Schema | API | Store | Page | Middleware | Test |
|---------|--------|-----|-------|------|------------|------|
| Login   | ✓ S-003 | ✓ S-004 | ✓ S-005 | ✓ S-008 | ✓ S-006 | ✓ S-012 |
| Redirect| — | — | ✓ S-005 | — | ✓ S-006 | ✗ GAP |
```

Gaps become stories in Phase 3. This ensures no outcome lacks full stack coverage.

---

## Phase 3: GENERATE STORIES — Create Implementation Stories

### 3.1 Story Generation Rules

For **each selected epic**, generate **5-15 stories** following these rules:

1. **Granularity**: Each story should be completable by one agent in one session (roughly 1-3 files changed, 50-300 lines).
2. **Ordering**: Stories within an epic must declare dependencies. Schema/type stories come first, then logic, then UI, then tests.
3. **Completeness**: Every acceptance criterion in the epic must map to at least one story.
4. **Research integration**: Each story must reference relevant research findings where applicable.

### 3.1.1 Bulk-Story Guard (SPIDR Check)

After drafting each story but **before** accepting it into the sprint, run the bulk-story guard. This catches the "migrate 130 files via glob" anti-pattern that collapsed S197-004 in the incident traced by `docs/_research/2026-04-08_sprint-carryforward-registry.md`.

**Reject or split** any story that matches **either** of these criteria:

1. **File-count heuristic** (two-band):
   - `story.files.length > 5` AND the story is not tagged `type: spike` — **mandatory split**. Six is the upper bound that fits one Heavy-class agent's tool-call budget when paired with 1-2 sibling stories in a wave (sprint-276 root cause: a 5-file story + two 1-file siblings = 7 files in one agent → exhaustion).
   - `story.files.length` in `{4, 5}` — **soft warn**: log a `decision` event ("planning: 4-5 file story; consider split"), but allow if standalone in its wave (no siblings in the same agent assignment). Sprint-dev's per-wave file cap (6) will block the over-allocation if it materializes.
   - `story.files.length` in `{1, 2, 3}` — **green** (matches §3.1 granularity target).

2. **Horizontal-scope language:** the story's title or description matches any of these regexes (case-insensitive):
   - `/all \w+ (files|components|modals|routes|tests|pages)/`
   - `/(via|using) (pattern|glob|regex)/`
   - `/across the codebase/`
   - `/every (file|component|store|route|test)/`
   - `/bulk (migrate|refactor|update|rename)/`

**Handling a match:**

- **Autonomy = low|medium:** pause. Offer SPIDR Data-axis split (by route/folder/prefix) or downgrade to `type: spike` (deliverable = split plan only).
- **Autonomy = high|full:** auto-split by nearest parent directory; recursively split if batches still > 8. If no concrete file list, downgrade to spike. Log `decision` event for each split.
- **Never auto-accept a bulk story.** Record splits in sprint manifest `spidr_splits` array.

### 3.2 Story File Format

Write each story to `${SPRINT_DIR}/stories/S${SPRINT_NUMBER}-XXX-<slug>.md` where XXX is a zero-padded sequence number.

Use the YAML frontmatter schema defined in `references/main.md`. Every story MUST include:
- `id`, `title`, `epic`, `status` (always `planned`), `priority`, `points`
- `depends_on` (list of story IDs this blocks on)
- `assigned_agent` (one of: `backend-dev`, `frontend-dev`, `test-writer`, `infra-dev`)
- `files` (list of file paths this story will create or modify)
- `verify` (list of shell commands that must pass for the story to be considered done)
- `done` (human-readable sentence defining what "done" means for this story)

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code snippets, file paths, YAML frontmatter, verify-command shells, grep patterns. Fragments OK in story bodies. Story titles and AC phrasing stay imperative and concrete.

Full story-body section detail: [references/main.md](references/main.md#story-body-sections).

### 3.3 Dependency Graph Validation

After generating all stories, validate:
- No circular dependencies.
- All `depends_on` references point to valid story IDs.
- At least one story per epic has no dependencies (can start immediately).

### 3.4 Story Numbering

Stories are numbered globally across the sprint: `S${SPRINT_NUMBER}-001`, `S${SPRINT_NUMBER}-002`, etc. Order by epic, then by dependency depth within epic.

---

## Phase 4: VALIDATE AND PUBLISH

### 4.1 Acceptance Criteria Coverage Check (Hard Gate)

For each epic, verify that every AC maps to at least one story. Write a coverage matrix:

```
${SPRINT_DIR}/ac-coverage.md
```

Format:
```markdown
| Epic | AC | Story | Covered |
|------|-----|-------|---------|
| E001 | AC1 | S1-003 | Yes |
```

**This is a hard gate: 100% AC coverage is required before proceeding.**

Print the coverage percentage: `AC Coverage: N/M (X%)`

If any AC is uncovered:
1. **Attempt 1:** Generate additional stories targeting uncovered ACs.
2. **Attempt 2:** If gaps remain, re-analyze the epic for implicit ACs that may need explicit stories.
3. **Attempt 3:** Final generation attempt with broader story scope.

If after 3 attempts any AC remains uncovered, report uncovered ACs and offer: (1) waive for this sprint, (2) retry with different approach, (3) abort. Do not proceed without 100% coverage or explicit user waiver.

*(Autonomy `high`/`full`: auto-waive uncovered ACs. Fix for the CAP-133 silent-drop in `docs/_research/2026-04-08_sprint-carryforward-registry.md`.)*

**Auto-waiver procedure (autonomy ∈ {high, full}):** Four writes are required — see `references/main.md` §Auto-Waiver Procedure for the full jsonl schemas.

1. Add uncovered ACs to `carry_forward` in sprint manifest + `waived_ac_count`/`reason_waivers` fields.
2. Append `auto_waived` + `progress` lines to `.cc-sessions/carry-forward.jsonl` for each parent registry entry. Precompute `coverage = actual / target`. Schema: [sprint-contracts.md](/_shared/sprint-contracts.md).
3. Record touched ids in manifest `registry_entries_touched` (sprint-review Invariant 2 cross-checks this).
4. Log `decision` event to activity feed.
5. Proceed to Phase 4.2.

**All four writes are required** — manifest carry_forward alone reintroduces the CAP-133 silent-drop.

### 4.2 Partition Stories to Agent Roles

Apply the partition rules from `references/main.md`:

| Story Type | Assigned Agent |
|---|---|
| Schema, types, validation | `backend-dev` |
| API routes, server functions, cloud functions | `backend-dev` |
| Stores, state management, composables | `backend-dev` |
| Components, pages, layouts | `frontend-dev` |
| UI integration, navigation, design tokens | `frontend-dev` |
| Unit tests, integration tests, e2e tests | `test-writer` |
| Infrastructure, deployment, CI/CD | `infra-dev` |

Update each story's `assigned_agent` field accordingly.

### 4.3 Write Sprint Summary

Write `${SPRINT_DIR}/summary.md` with:
- Sprint number, date, selected epics
- Story count by agent role
- Dependency graph (text format)
- Research highlights
- Carry-forward items
- Risk notes

### 4.4 Create GitHub Issues (if available)

If GitHub CLI is available, for each story:
```bash
gh issue create --title "S${SPRINT_NUMBER}-XXX: <story title>" \
  --body "<story body>" \
  --label "sprint-${SPRINT_NUMBER}" \
  --label "<epic-id>"
```

Record issue numbers back into story frontmatter as `github_issue: <number>`.

### 4.5 Update Sprint Registry

**Registry Lock — `sprint-registry.json`**: Before writing, acquire a file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `sprint-registry.json.lock` and append `lock_released` to the operation log.

Update `sprint-registry.json`:
```json
{
  "sprints": [
    {
      "number": <N>,
      "status": "planned",
      "planned_date": "<ISO-8601>",
      "epics": ["<epic-ids>"],
      "story_count": <N>,
      "stories": ["<story-ids>"]
    }
  ]
}
```

### 4.6 Git Commit

```bash
git add sprints/sprint-${SPRINT_NUMBER}/
git add sprint-registry.json
git commit -m "plan(sprint-${SPRINT_NUMBER}): generate ${STORY_COUNT} stories for epics ${EPIC_LIST}"
```

### 4.7 Final Output

Print a summary table to the user:

```
Sprint ${SPRINT_NUMBER} planned successfully.
- Epics: <list>
- Stories: <count> (backend: N, frontend: N, test: N, infra: N)
- GitHub issues: <created/skipped>
- Carry-forward: <count>
```

---

## Error Recovery

Full detail in `references/main.md` §"Error Recovery".

**Inline recovery rules**:
- **Research agent missing/timeout**: retry once with narrower scope; abort Phase 2 if still MISSING.
- **Registry/lock conflict** (sprint-registry.json.lock): retry 3× with 20s backoff; abort with `BLOCK:`.
- **Corrupt planning-inputs.json**: validate with `jq -e`; fallback to skipping (log `warning`, escalate to user).
- **Validation failures** (story frontmatter): run `/blitz:conform --fix` then re-validate; escalate if persist.
- **AC coverage < 100% after 3 attempts**: auto-waive if `autonomy ≥ high`; otherwise abort and ask user.
