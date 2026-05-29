---
name: sprint-dev
description: "Implements planned sprints with coordinated agent teams. Spawns backend-dev, frontend-dev, and test-writer agents in isolated worktrees, distributes stories as tasks with dependency-ordered waves, and monitors progress via the Monitor tool. Use when the user says 'implement sprint', 'develop stories', 'start coding', 'work the sprint', or 'resume sprint' (with STATE.md). Hard-fails at Phase 0.0 if the sprint manifest or stories are missing."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, TeamCreate, SendMessage, TaskCreate, TaskUpdate, TaskList
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For story YAML schema (canonical, producer/consumer matrix, validation algorithm), see [story-frontmatter.md](/_shared/story-frontmatter.md)
- For pipeline state contracts (which artifacts this skill produces and requires), see [state-handoff.md](/_shared/state-handoff.md)
- For agent prompt templates, coordination patterns, and story distribution rules, see [references/main.md](references/main.md)
- For autonomy modes (low/medium/high/full), see [session-protocol.md](/_shared/session-protocol.md) §Autonomy Levels
- For checkpoint/resume + deviation handling + context hygiene, see [checkpoint-protocol.md](/_shared/checkpoint-protocol.md), [deviation-protocol.md](/_shared/deviation-protocol.md), [context-management.md](/_shared/context-management.md)
- For the carry-forward registry (Reader Algorithm + writer contract on story completion in Phase 3.1a), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For subagent spawning, agent output contract (success/failure/partial thresholds), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For package install policy (every dep added by backend-dev / frontend-dev / test-writer agents resolves to registry latest, no invented versions), see [package-install-policy.md](/_shared/package-install-policy.md). Sprint-dev injects this into every dev-agent prompt via the Dev Agent Prompt Specification in references/main.md.
- For output style (terse-technical, canonical exemptions), see [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Sprint Development Skill

Implement a planned sprint by spawning coordinated agent teams in isolated worktrees, distributing stories as tasks with dependency ordering, and monitoring progress through completion. Execute every phase in order. Do NOT skip phases.

## Execution Mode

Read autonomy from `.cc-sessions/developer-profile.json` per [session-protocol.md](/_shared/session-protocol.md) §Autonomy Levels (default: `medium`). Map autonomy to `--mode` per the table below; an explicit `--mode` flag overrides only when autonomy is `low` or `medium`. **At autonomy `high` or `full`, force `autonomous` regardless of any `--mode` flag** — loop mode with bypass permissions cannot pause for confirmations.

| Autonomy (canonical) | Default mode | User `--mode` honored? |
|---|---|---|
| `low` | `interactive` | Yes |
| `medium` | `checkpoint` | Yes |
| `high` | `autonomous` | No (always autonomous) |
| `full` | `autonomous` | No (always autonomous) |

| Mode | Behavior |
|---|---|
| `autonomous` | Orchestrator manages everything. No pauses except for errors. |
| `checkpoint` | Pause after each wave completion. Present wave results to user, ask for confirmation before starting next wave. |
| `interactive` | Present each story to the user before assigning it to an agent. Ask for approach confirmation. Pair-programming style. |

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Before any other work, hard-fail if required upstream artifacts are missing. Per [state-handoff.md](/_shared/state-handoff.md):

```bash
PIPELINE_MISSING=()
[ -s "sprint-registry.json" ] || PIPELINE_MISSING+=("sprint-registry.json")
SPRINT_NUMBER="${SPRINT_NUMBER:-$(jq -r '.current_sprint // empty' sprint-registry.json 2>/dev/null)}"
[ -z "$SPRINT_NUMBER" ] && { echo "BLOCK: SPRINT_NUMBER is empty — cannot expand sprints/sprint-/ paths." >&2; exit 1; }
[[ "$SPRINT_NUMBER" =~ ^[0-9]{1,4}$ ]] || { echo "BLOCK: SPRINT_NUMBER must be 1-4 digits (got: $SPRINT_NUMBER)." >&2; exit 1; }
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
[ -s "${SPRINT_DIR}/manifest.json" ] || PIPELINE_MISSING+=("${SPRINT_DIR}/manifest.json")
ls "${SPRINT_DIR}/stories/"S*.md >/dev/null 2>&1 || PIPELINE_MISSING+=("${SPRINT_DIR}/stories/S*.md")
if [ "${#PIPELINE_MISSING[@]}" -gt 0 ]; then
  echo "BLOCK: missing pipeline inputs (see /_shared/state-handoff.md §sprint-dev):" >&2
  printf '  - %s\n' "${PIPELINE_MISSING[@]}" >&2
  echo "Producer: /blitz:sprint-plan." >&2
  exit 1
fi
```

Then validate every story file against [story-frontmatter.md](/_shared/story-frontmatter.md) §Validation algorithm. Report ALL validation failures together, do not abort on the first.

## Phase 0: CONTEXT — Load Project State

0. **Register session.** Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch (agent spawn, wave completion, etc.) per verbose-progress.md.
1. **Check for checkpoint (STATE.md).** Before anything else, check if the target sprint has a `STATE.md` file:
   ```bash
   SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
   cat "${SPRINT_DIR}/STATE.md" 2>/dev/null | head -5
   ```
   If STATE.md exists, follow the **resume flow** from [checkpoint-protocol.md](/_shared/checkpoint-protocol.md):
   - Validate staleness (>24h = warn user, ask whether to resume or start fresh). **If autonomy is `high` or `full` (e.g., loop mode), skip the staleness prompt and auto-resume regardless of age.** Log a `decision` event noting the auto-resume.
   - Validate worktrees (`git worktree list`).
   - **Branch divergence gate** (prevents sprint-289-class dual-implementation conflicts per [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md)). For each expected `sprint-${N}/${role}` branch, count commits ahead of `git merge-base "$BRANCH" HEAD`. Full check script in `references/main.md` section **"Resume Divergence Gate"**. If any branch is DIVERGENT, stop and prompt the user with reconciliation options: `rebase` (replay onto HEAD), `abandon` (delete branch + restart), `inspect` (open diff). Never auto-merge. In `autonomy=full` loops, behavior is governed by `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`).
   - Rebuild `agent_tracker` from STATE.md tables.
   - Skip to Phase 3 with remaining stories.
   - Log a `decision` event: "Resuming sprint ${N} from checkpoint".

   If STATE.md does not exist, continue with normal flow.

1b. **Check for incomplete sprints.** Search for `sprint-registry.json` and check for sprints with `status: in-progress`. If one exists, resume it (skip to Phase 1 with that sprint). Warn the user. *(If autonomy is `high` or `full`, log the warning and auto-resume without prompting.)*
2. **Build codebase inventory.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read root `package.json` and workspace config to understand structure.
3. **Verify build health.** Run a type-check and build to establish baseline:
   ```bash
   # Detect and run appropriate commands
   npm run type-check 2>&1 | tail -20  # or equivalent
   npm run build 2>&1 | tail -20       # or equivalent
   ```
   Record baseline error count. If baseline has errors, note them as pre-existing.
4. **Load detected stack.** Note framework, package manager, test runner, and build system from the stack profile above.

**Gate:** Build must succeed (or pre-existing errors must be cataloged) before spawning agents.

---

## Phase 0.5: DISCOVER — Learn Project Conventions

Before any agent writes code, build a conventions guide. Read 2-3 representative files from each layer (backend, stores, pages/components, tests) and document: auth pattern, error format, response envelope, validation approach, component style, CSS approach, store pattern, loading UI, test structure, file naming. Then identify reusable assets:

```bash
find . -path '*/composables/*' -o -path '*/utils/*' -o -path '*/shared/*' -o -path '*/components/base/*' | grep -v node_modules | head -30
```

Produce a **REUSE THESE — do not recreate** list with file paths and what each provides. Then load `.cc-sessions/KNOWLEDGE.md` into a slice for injection into dev-agent prompts (spec item 14, counters training-data bias per [knowledge-protocol.md](/_shared/knowledge-protocol.md)). Full checklist + slicing procedure in `references/main.md` §**Project Conventions Discovery** and §**KNOWLEDGE.md Slice Procedure**.

**Gate:** Conventions guide must be complete before spawning agents.

---

## Phase 1: LOAD SPRINT — Find and Parse Planned Sprint

### 1.1 Find Latest Planned Sprint

Read `sprint-registry.json` and find the sprint with `status: planned`. If the user specified a sprint number, use that instead.

```bash
# Find sprint directory
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
```

### 1.2 Load Sprint Manifest

Read `${SPRINT_DIR}/manifest.json` to get epic list and story count.

### 1.3 Load All Stories

Read every story file in `${SPRINT_DIR}/stories/`. For each story, extract:
- `id`, `title`, `assigned_agent`, `depends_on`, `priority`, `points`, `files`

### 1.4 Build Dependency Graph and Compute Waves

Construct a DAG from story `depends_on` fields. Then compute execution waves:

1. **Wave 0**: All stories with no dependencies (can start immediately).
2. **Wave N**: All stories whose dependencies are ALL in Waves 0..N-1.
3. **Critical path**: Longest dependency chain (determines minimum wave count).

Print the wave execution plan:
```
[sprint-dev] Wave Execution Plan:
  Wave 0 (parallel): S${N}-001, S${N}-002, S${N}-008 (schemas + types)
  Wave 1 (parallel): S${N}-003, S${N}-004 (backend logic, depends on Wave 0)
  Wave 2 (parallel): S${N}-005, S${N}-007 (frontend + tests, depends on Wave 1)
  Critical path: S${N}-001 → S${N}-004 → S${N}-005 (3 waves minimum)
```

Also identify:
- **Ready stories**: Wave 0 stories (can start immediately).
- **Blocked stories**: Stories in Wave 1+ (have dependencies that are not yet complete).
- **Pre-flight complexity gate**: `complexity_score = story_count * 2 + est_loc / 100`. Warn >40, hard-stop >80 (escape: `BLITZ_SPRINT_COMPLEXITY_OVERRIDE=1`). Script in `references/main.md` §**Pre-Flight Complexity Gate**.

### 1.5 Load Carry-Forward Items

If the manifest has `carry_forward` entries, load those stories and add them to the graph.

### 1.6 Update Sprint Status

**Registry Lock — `sprint-registry.json`**: Before writing, acquire a file-based lock per [session-protocol.md](/_shared/session-protocol.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `sprint-registry.json.lock` and append `lock_released` to the operation log.

Update `sprint-registry.json`: set sprint status to `in-progress`, record `started_date`.

---

## Phase 2: CREATE TEAM AND TASKS — Spawn Agents with Worktree Isolation

### 2.1 Create Development Team

Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-dev`.

### 2.2 Determine Required Agents

Based on story assignments, spawn only the agents that have stories:

| Agent Name | Role | Worktree Branch | MCP Scope |
|---|---|---|---|
| `backend-dev` | Schemas, APIs, stores, services, cloud functions | `sprint-${N}/backend` | Firestore, Firebase MCP only |
| `frontend-dev` | Components, pages, layouts, navigation, styles | `sprint-${N}/frontend` | Playwright MCP only |
| `test-writer` | Unit tests, integration tests, e2e tests | `sprint-${N}/tests` | Read-only tools only |
| `infra-dev` | Infrastructure, CI/CD, deployment (if stories exist) | `sprint-${N}/infra` | Full (infra-scoped) |

**Agent MCP scoping:** If the project has `.claude/agents/` definitions for `blitz-backend-dev`, `blitz-frontend-dev`, or `blitz-test-writer`, those definitions are used at spawn time and their `mcpServers` field restricts which MCP servers each agent can access — backend agents only get database/API MCPs, frontend gets Playwright/Figma, test-writer gets none. Check for these files before spawning:
```bash
ls .claude/agents/blitz-{backend,frontend,test}-dev.md 2>/dev/null
```
If missing, agents inherit the full session MCP set (existing behavior, safe fallback).

### 2.3 Spawn Agents with Worktree Isolation

Spawn each agent using the `Agent` tool with `isolation: "worktree"`. This gives each agent an isolated git worktree that is automatically cleaned up if no changes are made.

```
Agent(
  name: "<role>",
  subagent_type: "blitz:<role>",
  team_name: "sprint-${SPRINT_NUMBER}-dev",
  isolation: "worktree",
  prompt: "<agent instructions — see below>"
)
```

**Note:** The `isolation: "worktree"` parameter replaces manual `git worktree add` commands. Each agent gets its own branch and working directory automatically. Worktrees with no changes are auto-cleaned on agent completion; worktrees with changes are preserved for merging.

**Weight class**: Heavy (per [spawn-protocol.md](/_shared/spawn-protocol.md)). Dev agents implement multiple stories with reads+writes+verify per story.

**Per-wave caps (CRITICAL)** — whichever bites first: ≤**4 stories** AND ≤**6 affected files** per agent per wave (sum across stories). A 5-file story + two 1-file siblings = 7 files → split to next wave even with 3-story count. Each file averages 5-7 tool calls; 6 files fits Heavy-class, 8 exhausts mid-work (sprint-276 root cause).

**Agent prompt content** — the full 12-item prompt specification (role, stories, BUDGET block, project conventions, commit format, conventions guide, reusable assets, anti-mock rules, deviation protocol, wave assignment, context management, HEARTBEAT+PARTIAL protocol) is in `references/main.md` section **"Dev Agent Prompt Specification"**. Every spawn must include all 12 items.

### 2.5 Create Tasks with Dependency Ordering

For each story, create a task using `TaskCreate`:
- Title: `S${N}-XXX: <story title>`
- Assigned to: the appropriate agent
- Dependencies: mapped from story `depends_on`
- Status: `pending` (or `ready` if no dependencies)

### 2.6 Send Initial Instructions

Send each agent their first batch of **ready** stories (no unmet dependencies). Include full story content.

### 2.7 Track Agent State

Maintain an in-memory tracker:
```
agent_tracker = {
  "<agent-name>": {
    "agent_id": "<id>",
    "status": "active",       // active | stuck | completed
    "current_story": "S1-003",
    "completed": ["S1-001"],
    "failed_attempts": 0,     // circuit breaker counter
    "block_reason": null      // set when circuit breaker trips; see below
  }
}
```

Worktree paths are managed by the Agent tool's `isolation: "worktree"` parameter and do not need manual tracking.

**Circuit breaker + `block_reason` + per-story scope:** if an agent fails the same story 3 times OR emits `ESCALATE:`, mark `blocked` and set `block_reason` on the story (persist to STATE.md). Controlled vocabulary + SCOPE_FILES injection pattern in `references/main.md` sections **"`block_reason` Vocabulary"** and **"Per-Story Scope Constraint"**. `hard_spec`/`oracle-underivable`/`test-assertion-suspect` surface via `/blitz:next` row 1a → LOOP_ESCALATE; `scope-expansion-needed` re-spawns with expanded scope.

---

## Phase 3: IMPLEMENT — Monitor and Coordinate

### 3.1 Agent Work Loop

Each agent follows this loop for each assigned story:

1. **Read story** — Parse frontmatter and body. Note `verify` and `done` fields if present.
2. **Implement** — Create/modify files as specified. Follow implementation notes and code snippets. Follow the [Deviation Handling Protocol](/_shared/deviation-protocol.md) for unexpected issues.
3. **Verify** — Run the story's `verify` commands if defined. If no `verify` field, fall back to type-check:
   ```bash
   # If story has verify commands, run each one:
   cd <worktree> && <verify_command_1> && <verify_command_2> ...
   # Otherwise fall back to generic type-check:
   cd <worktree> && npm run type-check 2>&1
   ```
4. **Check done criteria** — Verify the story's `done` field is satisfied (all stated conditions are met).
5. **Commit** — If verification passes:
   ```bash
   git add -A && git commit -m "feat(sprint-${N}/<role>): S${N}-XXX <title>"
   ```
6. **Complete** — Update task status to `completed` via `TaskUpdate`.
7. **Next** — Request next story from orchestrator.

### 3.2 Orchestrator Monitoring Loop

The orchestrator (you) must:

1. **Monitor progress** (event-driven): start `Monitor(command: "tail -f ${PROGRESS_FILE} | grep --line-buffered 'done\\|blocked\\|wave_complete'", persistent: true)` before first wave. Fall back to `TaskList` polling (every 2-3 turns) if Monitor unavailable. On wave completion, print progress report and unblock Wave N+1 stories.
1a. **Write carry-forward registry progress on story `DONE:`.** When an agent signals `DONE:`, before updating STATE.md, follow the writer contract in [/_shared/carry-forward-registry.md](/_shared/carry-forward-registry.md) §Writers (sprint-dev): validate the story's `registry_entries` ids (per [story-frontmatter.md](/_shared/story-frontmatter.md)), compute `new_actual = current + delta` (clamp at `scope.target`), append a `progress` line transitioning to `partial` or `complete`, and log the activity-feed mirror. Apply the inference-fallback (parent-epic link with `delta: 1`) when the story omits `registry_entries`. No-op for stories whose epic also has no registry link.

1b. **Update STATE.md** — After each story completion (or at wave boundaries), update `${SPRINT_DIR}/STATE.md` per [checkpoint-protocol.md](/_shared/checkpoint-protocol.md). This enables session recovery if interrupted. Include wave progress.
1c. **Commit and push at wave boundaries** — `git add -A && git commit -m "feat(sprint-${N}): wave ${WAVE} complete — ${COMPLETED}/${TOTAL} stories" && git push origin HEAD`. Required for `/loop` mode resumability (next tick runs in fresh context). Also push after each integration fix round (Phase 4.3) and at sprint completion (Phase 4.9).
2. **Unblock stories** — When a dependency completes, send newly-ready stories to the appropriate agent.
3. **Coordinate via SendMessage** — When an agent completes a story that another agent depends on:
   ```
   SendMessage to <waiting-agent>:
   UNBLOCK: S${N}-XXX is complete. You can now start S${N}-YYY.
   Files created: <list>. Key exports: <list>.
   ```
4. **Handle stuck agents** — If an agent reports errors or makes no progress:
   - Send a `ASSIST:` message with hints from other agents' completed work.
   - If still stuck after 2 assists, invoke circuit breaker.
5. **Context hygiene** — Follow the [Context Management Protocol](/_shared/context-management.md):
   - Summarize agent completions (files + exports), don't relay full output.
   - Print compact progress at wave boundaries (every wave completion).
   - Offload progress to STATE.md rather than keeping it all in context.
   - If context monitor warns at ~60%+, write checkpoint and summarize.

### 3.3 Cross-Agent Communication Protocol

Agents communicate through the orchestrator using prefixed messages (DONE, BLOCKED, DEVIATION, ESCALATE, UNBLOCK, ASSIST, SYNC, HALT). Full direction/purpose table in `references/main.md` section **"Communication Prefix Table"**. See also [deviation-protocol.md](/_shared/deviation-protocol.md).

### 3.4 Story Distribution Rules

Stories are sent to agents in this priority order:

| Priority | Story Type | Rationale |
|---|---|---|
| 1 | Schema / type definitions | Everything else depends on types |
| 2 | Server functions / API routes | Backend logic before frontend |
| 3 | Stores / state management | Data layer before UI |
| 4 | Components / pages | UI after data layer exists |
| 5 | Navigation / layout integration | After components exist |
| 6 | Tests | After implementation is stable |

Within same priority, higher `priority` field stories go first, then lower `points` (smaller stories first).

---

## Phase 3.5: INTEGRATION CHECKS AND UI/UX PASS (MANDATORY)

This phase is **mandatory** and must not be skipped, even if no explicit UI stories exist.

### 3.5.0 Run Integration Check (Mandatory)

Run `/blitz:integration-check` to verify: export-to-import tracing, route coverage, store wiring. Fix high-severity findings before UI pass — cheaper here than at sprint-review Phase 1.6.

### 3.5.1 Spawn Integration Agent

Spawn `blitz:frontend-dev` (reused or fresh as `ui-integrator`) as a Medium-class agent on a dedicated `sprint-${N}/integration` worktree branch. Full spawn parameters, progress-file schema, HEARTBEAT inclusion, and the mandatory-fallback rule when the agent exits mid-checklist are in `references/main.md` section **"Integration Agent Spawn + Fallback"**. See also [spawn-protocol.md](/_shared/spawn-protocol.md).

### 3.5.2 Integration Checklist

The integration agent verifies and implements: **Navigation entries**, **Design tokens**, **Layout consistency**, **State wiring**, **Accessibility**, **Loading states**, **Route guards**. Full item definitions in `references/main.md` section **"Integration Checklist"**.

### 3.5.3 Integration Commit

```bash
git add -A && git commit -m "feat(sprint-${N}/integration): UI/UX integration pass"
```

---

## Phase 4: INTEGRATE — Merge and Verify

### 4.1 Merge Worktree Branches

Merge each agent's branch into the sprint branch:
```bash
git checkout -b sprint-${SPRINT_NUMBER}/merged
git merge sprint-${SPRINT_NUMBER}/backend --no-edit
git merge sprint-${SPRINT_NUMBER}/frontend --no-edit
git merge sprint-${SPRINT_NUMBER}/tests --no-edit
# Handle merge conflicts if any
```

### 4.2 Full Build Verification (Selective Re-Runs)

Run the initial full verification sweep (type-check, lint, test, build). On re-runs during Phase 4.3 fix iterations, use the selective re-verification strategy in `references/main.md` section **"Selective Re-Verification Strategy"**. The final fix round always gets one full sweep to catch cross-package regressions.

### 4.2.5 Completeness Gate

Run `/blitz:completeness-gate` on changed source files (`git diff --name-only ${SPRINT_BASE}..HEAD -- '*.ts' '*.tsx' '*.vue'`). Score < C (70) → flag critical findings in integration report; do not block (sprint review makes final call).

### 4.2.1 Cross-Phase Regression Testing

If `SPRINT_NUMBER > 1`, run regression tests from prior sprints. Full procedure (pre-existing test identification, selective run, fix rounds, report schema) in `references/main.md` section **"Cross-Phase Regression Testing"**.

### 4.3 Fix Integration Issues

If verification fails:
1. Categorize errors (type errors, import errors, test failures, build errors).
2. Fix systematically — types first, then imports, then logic, then tests.
3. Max 5 fix iterations. If still failing, report remaining issues.
4. Commit each fix round:
   ```bash
   git commit -m "fix(sprint-${N}): resolve integration issues — round ${ROUND}"
   ```

### 4.4 Clean Up Worktrees and Branches

Canonical contract: [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md). Worktrees with no changes auto-clean on agent completion. After Phase 4.1 merge succeeds, sprint-dev MUST explicitly remove worktrees AND delete the underlying agent branches (the platform leaves branches behind even after `git worktree remove`). Full cleanup script in `references/main.md` section **"Worktree + Branch Cleanup (Phase 4.4)"** — covers roles `{backend,frontend,tests,infra}` plus the Phase 3.5.1 integration branch, uses `git branch -d` (safe: refuses unmerged), and logs failures as `warning` events. Escape hatch: `BLITZ_SKIP_BRANCH_CLEANUP=1` preserves branches for forensic inspection.

### 4.5 E2E Verification (Best-Effort)

If Playwright MCP available: start dev server, smoke-test first 10 changed routes. 0 Critical + 0 Error = PASS; 1+ Critical = CONDITIONAL (include in report); 1+ Error = PASS with notes. Skip gracefully if unavailable.

### 4.6 Shutdown Team

Send `HALT:` to remaining agents.

### 4.7 Update Sprint Registry

Acquire `sprint-registry.json.lock` per [session-protocol.md](/_shared/session-protocol.md) §File-Based Locking Protocol (the canonical acquire/verify/release sequence lives there — do not restate it). Update sprint status to `review` with `completed_date`, `stories_completed`, `stories_blocked`, `integration_issues`.

### 4.8 Update Story Statuses

Update each story frontmatter `status`: `done` (passes verification), `incomplete` (partial / failing tests), `blocked` (circuit breaker triggered). Acquire per-file lock before write.

### 4.8.5 Blocked Story Accountability

For every story marked `blocked`:

1. **Document WHY** it was blocked (circuit breaker details, specific errors, missing dependencies).
2. **Document what work WAS completed** and what REMAINS.
3. **Create carry-forward entry** in the manifest's `carry_forward` array.
4. **Sprint summary MUST include a prominent warning** with blocked count and story IDs.

**Never silently drop blocked stories.** They must be visible in the sprint report and carry forward to the next sprint.

### 4.9 Final Commit and Push

```bash
git add -A
git commit -m "feat(sprint-${N}): complete sprint implementation — ${COMPLETED}/${TOTAL} stories"
git push origin HEAD
```

### 4.10 Final Output and Error Recovery

Print the summary block per `references/main.md` §"Final Output Template".

**Inline recovery rules** (see `references/main.md` §"Error Recovery" for full detail):
- **Agent timeout/OOM**: escalate story to `blocked`; send `HALT:` to agent; fallback to next story in wave.
- **Malformed agent output**: retry with narrower scope (one story, reduced file count); abort agent after 3 retry failures.
- **Lock-acquisition failure** (sprint-registry.json.lock): retry 3× with 20s backoff; abort with `BLOCK: lock conflict` if still held.
- **STATE.md corrupt on resume**: recover per [checkpoint-protocol.md](/_shared/checkpoint-protocol.md) §STATE.md Parse-Failure Handling (abort vs auto-reset).
- **Validation failures** (story frontmatter): run `/blitz:conform --fix` then re-validate; escalate if persist after conform.

### 4.11 Push Completion Notification

After the final commit and push, send a mobile push notification if Remote Control is enabled:

```
PushNotification(
  title: "Sprint ${N} complete ✓",
  message: "${COMPLETED}/${TOTAL} stories · ${BLOCKED} blocked · review ready",
  url: "https://github.com/<repo>/tree/sprint-${N}"
)
```

Call this unconditionally — if Remote Control is not configured the tool is a no-op. Do not gate on user confirmation; this is informational only.
