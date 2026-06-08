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

Plan a sprint by selecting unblocked epics, conducting parallel research, generating implementation stories, and publishing to GitHub issues. Execute every phase in order. Do NOT skip phases.

## Mode Routing

Check for `--gaps` flag. If present, run **gap closure mode**:

### Gap Closure Mode (`--gaps`)

1. Read sprint review report (severity >= high) and completeness gate report (severity >= medium).
2. Read STATE.md — blocked stories and reasons.
3. Group gaps by shared files and dependency order.
4. Generate focused fix stories — each addresses one gap, references existing code + finding. Tag `type: gap-closure`.
5. Skip research phase. Skip to Phase 3; continue normally through Phase 4.

### Normal Mode (default)

Execute all phases below in order.

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Hard-fail if required upstream artifacts are missing. Per [session-lifecycle.md](/_shared/session-lifecycle.md):

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

`.cc-sessions/carry-forward.jsonl` is OPTIONAL (absence is normal for greenfield; Step 8 handles it).

## Phase 0: CONTEXT — Load Project State

0. **Register session.** Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and agent spawn.
1. **Locate registry files.**
   ```
   Glob: **/sprint-registry.json, **/roadmap-registry.json, **/epic-registry.json, **/epics/**/*.md
   ```
2. **Load epic/roadmap registry.** If none found, inform user and STOP.
3. **Load research index.** Search `**/research-index.json` or `**/research/**/*.md`. Note epics with existing research.
4. **Build codebase inventory.**
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read root `package.json` (if exists) and any workspace config (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`).
5. **Load sprint history.** Read `sprint-registry.json` to determine last completed sprint number. If none, this is Sprint 1.
6. **Check incomplete stories.** Search story files from previous sprints with `status: incomplete` or `status: in-progress`.
7. **Check STATE.md.** If a previous sprint has `STATE.md`, read it for blocked stories. See [session-lifecycle.md](/_shared/session-lifecycle.md).
8. **Read carry-forward registry** (`.cc-sessions/carry-forward.jsonl`). Reduce to latest-wins by `id`:
   ```bash
   jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x)) | map(select(.status == "active" or .status == "partial"))' \
     .cc-sessions/carry-forward.jsonl 2>/dev/null || echo '[]'
   ```
   Every returned entry is a **mandatory planning input** — this sprint MUST either include work against it OR operator must explicitly transition it to `deferred` with a `notes` reason before planning continues.

   Also read `sprints/sprint-${SPRINT_NUMBER}-planning-inputs.json` if it exists — previous sprint review may have auto-injected entries via Invariant 4. Every entry MUST be addressed in the story set.

   Carry-forward state lives in the registry, not `epic-registry.json`'s `status` field — a parent epic can be `done` while child entries are still `active` or `partial`. See [sprint-contracts.md](/_shared/sprint-contracts.md).

   **Rollover escalation:** `rollover_count >= 3` → MUST NOT auto-inject; escalate to human review (log blocker; autonomy=full: log and exit cleanly). See Error Recovery.

**Gate:** At least one epic **or** one `status ∈ {active, partial}` registry entry, plus basic project structure understanding.

---

## Phase 1: INITIALIZE — Select Epics and Create Sprint

### 1.1 Topological Sort on Epic Registry

Parse `depends_on` fields. Build DAG, topological sort. **Selection rules:**
- **Unblocked:** all dependencies `done`/`complete`.
- **In-progress:** stories from previous sprints still incomplete (carry-forward).
- Select all unblocked + in-progress. User-specified epics override (warn on unmet deps).
- Target 8-20 stories total.

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

Acquire `${SPRINT_DIR}/manifest.json.lock` per [session-lifecycle.md](/_shared/session-lifecycle.md) §File-Based Locking Protocol. Write `${SPRINT_DIR}/manifest.json`: `sprint`, `status: planning`, `created`, `epics[]`, `carry_forward[]`, `story_count`.

### 1.5 Sync with GitHub Issues

`gh auth status` — if authenticated, note repo for later; otherwise skip.

---

## Phase 2: RESEARCH — Parallel Agent Investigation

### 2.0 Select Dispatch Mode (capability gate)

Per [agent-orchestration.md](/_shared/agent-orchestration.md). Both paths produce identical findings files under `${SESSION_TMP_DIR}/`; only the orchestration mechanism differs. Flat 3-4 agent pool — no DAG, no worktree, no cross-session resume.

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;                 # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;                # auto: use Workflow iff tool present
esac
echo "[sprint-plan] dispatch=${BLITZ_DISPATCH:-auto} use_workflow=${USE_WORKFLOW}" >&2
```

- **`USE_WORKFLOW` truthy AND `Workflow` tool available** → §2.1-W (Workflow path).
- **else, or on ANY `Workflow` failure** → fall back to §2.1 (`Agent()` path). Never hard-fail.
- Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`.
- All filesystem I/O (manifest, story files, GitHub sync, activity-feed) stays in this skill's main-thread Bash — the `Workflow` script touches none of it (hybrid wrapper boundary).

### 2.1-W Dispatch via Workflow (opt-in path)

Dispatch the research agents as one `parallel()` with `schema:` validation. The script owns dispatch only; this skill collects the validated return + the agents' findings files in §2.4 exactly as the `Agent()` path does.

```js
export const meta = { name: 'sprint-plan', description: 'Parallel sprint research agents (domain/library/codebase/optional infra)', phases: [{ title: 'Research' }] }
// args: { roster:[{name,prompt,semantic}], findingsSchema } — prompts embed OUTPUT STYLE + write-as-you-go
const found = await parallel(args.roster.map(a => () =>
  agent(a.prompt, { label: a.name, phase: 'Research',
    model: a.semantic ? 'sonnet' : 'haiku', schema: args.findingsSchema })))
return { found: found.map((f, i) => ({ name: args.roster[i].name, ok: f !== null, result: f })) }
```

- `codebase-analyst` → `semantic: true` (sonnet); retrieval agents → haiku per token-budget routing. Explicit `model` prevents `[1m]` inheritance.
- `infra-analyst` included in `args.roster` only when backend/cloud services detected (§2.1 optional row).
- Each `a.prompt` MUST embed the OUTPUT STYLE snippet (Invariant 5) + write-as-you-go rule.
- `schema` replaces the §2.4 `classify_output()` gate; `null` entries = failed agents. Apply the §2.4 abort threshold against the count of non-`null` results.
- After the workflow returns, proceed to §2.4 (collect) unchanged.

### 2.1 Spawn Research Agents via Agent Tool

Spawn 3-4 named agents in **a single assistant message** (concurrent). Each writes findings to `${SESSION_TMP_DIR}/` files incrementally.

Per-spawn parameters:
- `subagent_type: general-purpose`
- `model: sonnet` (explicit — prevents `[1m]` inheritance from Opus orchestrator)
- `description: sprint-<N> <agent-role>`
- `prompt`: template from references/main.md "Agent Prompt Templates" filled with epic list, stack profile, and output path
- `run_in_background: true`

Orchestrator synthesizes cross-cutting findings in Phase 2.4 (not peer-to-peer, per [agent-orchestration.md](/_shared/agent-orchestration.md)).

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)). Each prompt MUST include: max 15 file reads, max 8 web searches (0 for codebase-analyst), max 250-line output, 5-minute wall-clock budget, write-as-you-go instruction.

**Required agents:**

| Agent Name | Role | Focus |
|---|---|---|
| `domain-researcher` | Domain & API Research | External APIs, protocols, standards relevant to selected epics |
| `library-researcher` | Library & Ecosystem Research | Package versions, migration guides, compatibility, best practices |
| `codebase-analyst` | Codebase Analysis | Existing patterns, reusable code, integration points, potential conflicts |

**Optional (spawn if backend/cloud services detected):**

| Agent Name | Role | Focus |
|---|---|---|
| `infra-analyst` | Infrastructure Analysis | Cloud config, security rules, deployment pipeline, environment setup |

### 2.2 Agent Prompt Content

Each prompt (template in references/main.md): selected epics (IDs, titles, descriptions); agent's research focus; output path `${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-<agent-name>.md`; Medium-class budget block; stub-then-append write instructions.

### 2.4 Collect Research

Wait for all agents. **Run canonical Agent Output Contract validator** from [agent-orchestration.md](/_shared/agent-orchestration.md) §8 — classifies each output as SUCCESS / PARTIAL / MALFORMED / EMPTY / MISSING / TIMEOUT and applies standard gate threshold (N=3 → ABORT at MISSING_COUNT ≥ 2; N=4 → ABORT at MISSING_COUNT ≥ 2).

```bash
EXPECTED_OUTPUTS=(
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-domain-researcher.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-library-researcher.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-codebase-analyst.md"
)
# Add infra-analyst.md if spawned.

# Run /_shared/agent-orchestration.md §8 validator (classify_output + standard gate).
# On ABORT: stop Phase 2 and report.
# On survivor singleton: retry failed agent once with narrower scope (one most-critical epic only).
# On PARTIAL: per §8, queue narrow retries for items in MISSING list.
```

On SUCCESS, copy outputs into `${SPRINT_DIR}/research/`. Persist PARTIAL annotations into sprint manifest `research_partials` field for sprint-review Invariant 1 cross-check.

---

## Phase 2.5: GOAL-BACKWARD ANALYSIS — Derive Stories from Outcomes

For each selected epic:

1. **Define 2-5 observable outcomes** — concrete, testable statements of what a user/developer can do post-sprint.
2. **Derive required artifacts** — trace backward: page → store → schema → API handler → middleware → test.
3. **Map connections** between adjacent artifact pairs (page calls store, store calls API, handler validates schema, middleware reads auth store).
4. **Build coverage matrix** — outcomes × artifacts. Empty cells = gaps → additional stories.

```markdown
| Outcome | Schema | API | Store | Page | Middleware | Test |
|---------|--------|-----|-------|------|------------|------|
| Login   | ✓ S-003 | ✓ S-004 | ✓ S-005 | ✓ S-008 | ✓ S-006 | ✓ S-012 |
| Redirect| — | — | ✓ S-005 | — | ✓ S-006 | ✗ GAP |
```

Gaps become stories in Phase 3.

---

## Phase 3: GENERATE STORIES — Create Implementation Stories

### 3.1 Story Generation Rules

For **each selected epic**, generate **5-15 stories** — each completable by one agent in one session (1-3 files, 50-300 lines). Order: schema/types → logic → UI → tests (declare `depends_on`). Every epic AC maps to at least one story. Reference relevant research findings.

### 3.1.1 Bulk-Story Guard (SPIDR Check)

After drafting each story but **before** accepting it, run the bulk-story guard (catches the "migrate 130 files via glob" anti-pattern traced in `docs/_research/2026-04-08_sprint-carryforward-registry.md`).

**Reject or split** any story matching either criterion:

1. **File-count heuristic** (two-band):
   - `story.files.length > 5` AND not tagged `type: spike` — **mandatory split**.
   - `story.files.length` in `{4, 5}` — **soft warn**: log `decision` event; allow only if standalone in wave.
   - `story.files.length` in `{1, 2, 3}` — **green**.

2. **Horizontal-scope language** — title or description matches (case-insensitive):
   - `/all \w+ (files|components|modals|routes|tests|pages)/`
   - `/(via|using) (pattern|glob|regex)/`
   - `/across the codebase/`
   - `/every (file|component|store|route|test)/`
   - `/bulk (migrate|refactor|update|rename)/`

**Handling a match:**
- **Autonomy = low|medium:** pause. Offer SPIDR Data-axis split or downgrade to `type: spike`.
- **Autonomy = high|full:** auto-split by nearest parent directory; recursively split if batches still > 8. If no concrete file list, downgrade to spike. Log `decision` event per split.
- **Never auto-accept a bulk story.** Record splits in sprint manifest `spidr_splits` array.

### 3.2 Story File Format

Write each story to `${SPRINT_DIR}/stories/S${SPRINT_NUMBER}-XXX-<slug>.md` (XXX = zero-padded sequence).

Use YAML frontmatter schema from `references/main.md`. Every story MUST include:
- `id`, `title`, `epic`, `status` (always `planned`), `priority`, `points`
- `depends_on` (list of blocking story IDs)
- `assigned_agent` (one of: `backend-dev`, `frontend-dev`, `test-writer`, `infra-dev`)
- `files` (file paths to create or modify)
- `verify` (shell commands that must pass)
- `done` (human-readable sentence defining done)

Full story-body section detail: [references/main.md](references/main.md#story-body-sections).

### 3.3 Dependency Graph Validation

- No circular dependencies; all `depends_on` IDs valid.
- At least one story per epic has no dependencies.

### 3.4 Story Numbering

`S${SPRINT_NUMBER}-001`, `S${SPRINT_NUMBER}-002`, … — global, ordered by epic then dependency depth.

---

## Phase 4: VALIDATE AND PUBLISH

### 4.1 Acceptance Criteria Coverage Check (Hard Gate)

Verify every epic AC maps to at least one story. Write `${SPRINT_DIR}/ac-coverage.md`:

```markdown
| Epic | AC | Story | Covered |
|------|-----|-------|---------|
| E001 | AC1 | S1-003 | Yes |
```

**Hard gate: 100% AC coverage required.** Print: `AC Coverage: N/M (X%)`

If ACs uncovered: attempt generation 3×. If still uncovered, offer: (1) waive, (2) retry, (3) abort.

*(Autonomy `high`/`full`: auto-waive uncovered ACs. Fix for CAP-133 silent-drop in `docs/_research/2026-04-08_sprint-carryforward-registry.md`.)*

**Auto-waiver procedure (autonomy ∈ {high, full})** — all four writes required (jsonl schemas in `references/main.md` §Auto-Waiver Procedure); manifest carry_forward alone reintroduces CAP-133 silent-drop:

1. Add uncovered ACs to sprint manifest `carry_forward` + `waived_ac_count`/`reason_waivers`.
2. Append `auto_waived` + `progress` lines to `.cc-sessions/carry-forward.jsonl`. Precompute `coverage = actual / target`. Schema: [sprint-contracts.md](/_shared/sprint-contracts.md).
3. Record touched ids in manifest `registry_entries_touched` (sprint-review Invariant 2 cross-checks).
4. Log `decision` event to activity feed.

### 4.2 Partition Stories to Agent Roles

Apply partition rules from `references/main.md`. Update each story's `assigned_agent`:

| Story Type | Assigned Agent |
|---|---|
| Schema, types, validation | `backend-dev` |
| API routes, server functions, cloud functions | `backend-dev` |
| Stores, state management, composables | `backend-dev` |
| Components, pages, layouts | `frontend-dev` |
| UI integration, navigation, design tokens | `frontend-dev` |
| Unit tests, integration tests, e2e tests | `test-writer` |
| Infrastructure, deployment, CI/CD | `infra-dev` |

### 4.3 Write Sprint Summary

Write `${SPRINT_DIR}/summary.md`: sprint number, date, epics, story count by role, dependency graph (text), research highlights, carry-forward, risk notes.

### 4.4 Create GitHub Issues (if available)

```bash
gh issue create --title "S${SPRINT_NUMBER}-XXX: <story title>" \
  --body "<story body>" \
  --label "sprint-${SPRINT_NUMBER}" \
  --label "<epic-id>"
```

Record in story frontmatter as `github_issue: <number>`.

### 4.5 Update Sprint Registry

**Registry Lock — `sprint-registry.json`**: Before writing, acquire file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, write registry.
5. RELEASE — delete `sprint-registry.json.lock`, append `lock_released` to operation log.

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

- **Research agent missing/timeout**: retry once with narrower scope; abort Phase 2 if still MISSING.
- **Registry/lock conflict** (`sprint-registry.json.lock`): retry 3× with 20s backoff; abort with `BLOCK:`.
- **Corrupt planning-inputs.json**: validate with `jq -e`; fallback to skipping (log `warning`, escalate to user).
- **Validation failures** (story frontmatter): run `/blitz:conform --fix` then re-validate; escalate if persist.
- **AC coverage < 100% after 3 attempts**: auto-waive if `autonomy ≥ high`; otherwise abort and ask user.

## Gotchas

- Missing `roadmap-registry.json`/`epic-registry.json` → Phase 0.0 BLOCK. Run `/blitz:roadmap` first.
- 0 unblocked epics + non-empty carry-forward ≠ "nothing to do" — `status ∈ {active,partial}` registry entries are mandatory planning inputs (Phase 0 step 8).
- Bulk-story SPIDR guard: >5 files or horizontal-scope language ("all X files", "via glob", "across the codebase") → mandatory split (§3.1.1).
- AC coverage <100% blocks publish unless autonomy≥high auto-waives — and auto-waive needs all 4 registry writes or it reintroduces the CAP-133 silent-drop (§4.1).
- `roadmap-registry.json` epic_index status can lag `epic-registry.json` (the source of truth) — select epics from epic-registry.

---

Next: `/blitz:sprint-dev` to implement the generated stories (or `/blitz:implement`).
