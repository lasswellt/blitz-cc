---
name: sprint-dev
description: "Implements planned sprints with coordinated agent teams — spawns backend-dev/frontend-dev/test-writer in isolated worktrees, distributes stories as dependency-ordered waves, monitors via Monitor. Use for 'implement sprint', 'develop stories', 'start coding', 'work the sprint', 'resume sprint'. Hard-fails at Phase 0.0 if the manifest or stories are missing."
argument-hint: "[--sprint N | --resume] [--stories ID,ID] [--mode autonomous|checkpoint|interactive]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent, SendMessage, TaskCreate, TaskUpdate, TaskList
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
- For agent prompt templates, coordination patterns, and story distribution rules, see [references/main.md](references/main.md)
- For autonomy modes (low/medium/high/full), see [session-lifecycle.md](/_shared/session-lifecycle.md) §Autonomy Levels
- For checkpoint/resume + deviation handling + context hygiene, see [session-lifecycle.md](/_shared/session-lifecycle.md), [sprint-contracts.md](/_shared/sprint-contracts.md)
- For the carry-forward registry (Reader Algorithm + writer contract on story completion in Phase 3.1a), see [sprint-contracts.md](/_shared/sprint-contracts.md)
- For subagent spawning, agent output contract (success/failure/partial thresholds), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For package install policy (every dep added by backend-dev / frontend-dev / test-writer agents resolves to registry latest, no invented versions), see [security.md](/_shared/security.md). Sprint-dev injects this into every dev-agent prompt via the Dev Agent Prompt Specification in references/main.md.
- For output style (terse-technical, canonical exemptions), see [/_shared/terse-output.md](/_shared/terse-output.md)

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Sprint Development Skill

Implement a planned sprint by spawning coordinated agent teams in isolated worktrees, distributing stories as tasks with dependency ordering, and monitoring progress through completion. Execute every phase in order. Do NOT skip phases.

## Execution Mode

Read autonomy from `.cc-sessions/developer-profile.json` per [session-lifecycle.md](/_shared/session-lifecycle.md) §Autonomy Levels (default: `medium`). Map autonomy to `--mode` per the table below; an explicit `--mode` flag overrides only when autonomy is `low` or `medium`. **At autonomy `high` or `full`, force `autonomous` regardless of any `--mode` flag.**

| Autonomy (canonical) | Default mode | User `--mode` honored? |
|---|---|---|
| `low` | `interactive` | Yes |
| `medium` | `checkpoint` | Yes |
| `high` | `autonomous` | No (always autonomous) |
| `full` | `autonomous` | No (always autonomous) |

| Mode | Behavior |
|---|---|
| `autonomous` | Orchestrator manages everything. No pauses except for errors. |
| `checkpoint` | Pause after each wave completion. Present results, ask confirmation before next wave. |
| `interactive` | Present each story before assigning. Ask for approach confirmation. Pair-programming style. |

---

## Phase 0.0: INPUT GATE — Validate Pipeline Inputs

Hard-fail if required upstream artifacts are missing. Per [session-lifecycle.md](/_shared/session-lifecycle.md):

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
  echo "BLOCK: missing pipeline inputs (see /_shared/session-lifecycle.md §sprint-dev):" >&2
  printf '  - %s\n' "${PIPELINE_MISSING[@]}" >&2
  echo "Producer: /blitz:sprint-plan." >&2
  exit 1
fi
```

Validate every story file against [sprint-contracts.md](/_shared/sprint-contracts.md) §Validation algorithm. Report ALL validation failures together.

## Phase 0: CONTEXT — Load Project State

0. **Register session** per [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and agent spawn/wave completion.
1. **Check for checkpoint (STATE.md).**
   ```bash
   SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
   cat "${SPRINT_DIR}/STATE.md" 2>/dev/null | head -5
   ```
   If STATE.md exists, follow the **resume flow** from [session-lifecycle.md](/_shared/session-lifecycle.md):
   - Validate staleness (>24h = warn user, ask whether to resume or start fresh). **If autonomy is `high` or `full`, skip the staleness prompt and auto-resume regardless of age.** Log a `decision` event.
   - Validate worktrees (`git worktree list`).
   - **Branch divergence gate** (prevents sprint-289-class dual-implementation conflicts per [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md)). For each expected `sprint-${N}/${role}` branch, count commits ahead of `git merge-base "$BRANCH" HEAD`. Full check script in `references/main.md` §**"Resume Divergence Gate"**. If any branch is DIVERGENT, stop and prompt the user with options: `rebase`, `abandon`, `inspect`. Never auto-merge. In `autonomy=full` loops, behavior is governed by `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`).
   - Rebuild `agent_tracker` from STATE.md tables. Skip to Phase 3 with remaining stories.
   - Log `decision` event: "Resuming sprint ${N} from checkpoint".

1b. **Check for incomplete sprints.** Check `sprint-registry.json` for sprints with `status: in-progress`. If one exists, resume it. Warn the user *(autonomy `high`/`full`: log and auto-resume)*.
2. **Build codebase inventory.**
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read root `package.json` and workspace config.
3. **Verify build health.**
   ```bash
   npm run type-check 2>&1 | tail -20  # or equivalent
   npm run build 2>&1 | tail -20       # or equivalent
   ```
   Record baseline error count. Pre-existing errors must be cataloged.
4. **Load detected stack.** Note framework, package manager, test runner, build system.

**Gate:** Build must succeed (or pre-existing errors cataloged) before spawning agents.

---

## Phase 0.5: DISCOVER — Learn Project Conventions

Read 2-3 representative files from each layer (backend, stores, pages/components, tests). Document: auth pattern, error format, response envelope, validation approach, component style, CSS approach, store pattern, loading UI, test structure, file naming. Then identify reusable assets:

```bash
find . -path '*/composables/*' -o -path '*/utils/*' -o -path '*/shared/*' -o -path '*/components/base/*' | grep -v node_modules | head -30
```

Produce a **REUSE THESE — do not recreate** list with file paths and what each provides. Load `.cc-sessions/KNOWLEDGE.md` into a slice for injection into dev-agent prompts (spec item 14, per [knowledge-protocol.md](/_shared/knowledge-protocol.md)). Full checklist + slicing procedure in `references/main.md` §**Project Conventions Discovery** and §**KNOWLEDGE.md Slice Procedure**.

**Gate:** Conventions guide complete before spawning agents.

---

## Phase 0.6: SPRINT-CONTRACT NEGOTIATION (generator ↔ evaluator) (E4)

Negotiate a sprint contract the evaluator co-owns — bridging planner stories and testable implementation. Concept: `docs/integrations/harness-design/` (Gap 3).

1. **Generator proposes**: for each story, propose what will be built and how the evaluator will verify it — concrete testable behaviors beyond the high-level `acceptance_criteria`/`done` in story frontmatter.
2. **Evaluator reviews** — spawn `agents/critic.md` (code/QA) and, for UI stories, `agents/design-critic.md`, to review and amend verification criteria.
3. **Converge** — iterate (bounded: **max 3 rounds**, else escalate to user) until both agree.
4. **Persist** — write agreed criteria to `${SESSION_TMP_DIR}/HANDOFF.json` as `scope.acceptance`; downstream verification (Phase 3.5, sprint-review) reads it.

Scope to the gap between high-level acceptance and testable behaviors — do NOT re-author what `sprint-plan` pinned. If stories already carry detailed testable criteria, evaluator co-signs. Skip for single-story trivial sprints. In `autonomy=high|full`, cap at 1 round and proceed with generator's proposal if no amendment; log a `decision` event.

**Gate:** Contract persisted (or explicitly skipped for trivial sprint) before spawning agents.

---

## Phase 1: LOAD SPRINT — Find and Parse Planned Sprint

### 1.1 Find Latest Planned Sprint

Read `sprint-registry.json`, find sprint with `status: planned` (or use user-specified number).

```bash
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
```

### 1.2–1.3 Load Manifest and Stories

Read `${SPRINT_DIR}/manifest.json`. Read every story in `${SPRINT_DIR}/stories/`, extracting: `id`, `title`, `assigned_agent`, `depends_on`, `priority`, `points`, `files`.

### 1.4 Build Dependency Graph and Compute Waves

Construct a DAG from story `depends_on` fields. Compute execution waves:

1. **Wave 0**: Stories with no dependencies.
2. **Wave N**: Stories whose dependencies are ALL in Waves 0..N-1.
3. **Critical path**: Longest dependency chain.

Print the wave execution plan:
```
[sprint-dev] Wave Execution Plan:
  Wave 0 (parallel): S${N}-001, S${N}-002, S${N}-008 (schemas + types)
  Wave 1 (parallel): S${N}-003, S${N}-004 (backend logic, depends on Wave 0)
  Wave 2 (parallel): S${N}-005, S${N}-007 (frontend + tests, depends on Wave 1)
  Critical path: S${N}-001 → S${N}-004 → S${N}-005 (3 waves minimum)
```

**Pre-flight complexity gate**: `complexity_score = story_count * 2 + est_loc / 100`. Warn >40, hard-stop >80 (escape: `BLITZ_SPRINT_COMPLEXITY_OVERRIDE=1`). Script in `references/main.md` §**Pre-Flight Complexity Gate**.

### 1.5 Load Carry-Forward Items

If the manifest has `carry_forward` entries, load those stories and add them to the graph.

### 1.6 Update Sprint Status

**Registry Lock — `sprint-registry.json`**: acquire file-based lock per [session-lifecycle.md](/_shared/session-lifecycle.md) §File-Based Locking Protocol (canonical acquire/verify/release sequence lives there). Update sprint status to `in-progress`, record `started_date`.

---

## Phase 2: CREATE TEAM AND TASKS — Spawn Agents with Worktree Isolation

### 2.1 Create Development Team

Group agents into team `sprint-${SPRINT_NUMBER}-dev` by passing `team_name` to each `Agent()` spawn in Phase 2.3 — team forms implicitly on first spawn per [/_shared/agent-orchestration.md](/_shared/agent-orchestration.md).

### 2.2 Determine Required Agents

Spawn only agents that have stories:

| Agent Name | Role | Worktree Branch | MCP Scope |
|---|---|---|---|
| `backend-dev` | Schemas, APIs, stores, services, cloud functions | `sprint-${N}/backend` | Firestore, Firebase MCP only |
| `frontend-dev` | Components, pages, layouts, navigation, styles | `sprint-${N}/frontend` | Playwright MCP only |
| `test-writer` | Unit tests, integration tests, e2e tests | `sprint-${N}/tests` | Read-only tools only |
| `infra-dev` | Infrastructure, CI/CD, deployment (if stories exist) | `sprint-${N}/infra` | Full (infra-scoped) |

**Agent MCP scoping:** Check for `.claude/agents/` definitions; if present, `mcpServers` restricts each agent's access:
```bash
ls .claude/agents/blitz-{backend,frontend,test}-dev.md 2>/dev/null
```
If missing, agents inherit the full session MCP set (safe fallback).

### 2.3 Spawn Agents with Worktree Isolation

Spawn each agent using the `Agent` tool with `isolation: "worktree"`:

```
Agent(
  name: "<role>",
  subagent_type: "blitz:<role>",
  team_name: "sprint-${SPRINT_NUMBER}-dev",
  isolation: "worktree",
  prompt: "<agent instructions — see below>"
)
```

`isolation: "worktree"` gives each agent an isolated git worktree; worktrees with no changes auto-clean on completion.

**Weight class**: Heavy per [agent-orchestration.md](/_shared/agent-orchestration.md).

**Per-wave caps (CRITICAL)** — whichever bites first: ≤**4 stories** AND ≤**6 affected files** per agent per wave (sum across stories). A 5-file story + two 1-file siblings = 7 files → split to next wave even with 3-story count.

**Agent prompt content** — full 12-item prompt specification (role, stories, BUDGET block, project conventions, commit format, conventions guide, reusable assets, anti-mock rules, deviation protocol, wave assignment, context management, HEARTBEAT+PARTIAL protocol) is in `references/main.md` §**"Dev Agent Prompt Specification"**. Every spawn must include all 12 items.

### 2.5 Create Tasks with Dependency Ordering

For each story, create a task via `TaskCreate`:
- Title: `S${N}-XXX: <story title>` · Assigned to: appropriate agent · Dependencies: from `depends_on` · Status: `pending` or `ready`

### 2.6–2.7 Send Initial Instructions and Track Agent State

Send each agent their first batch of **ready** stories (no unmet dependencies) with full story content.

Maintain in-memory tracker:
```
agent_tracker = {
  "<agent-name>": {
    "agent_id": "<id>",
    "status": "active",       // active | stuck | completed
    "current_story": "S1-003",
    "completed": ["S1-001"],
    "failed_attempts": 0,     // circuit breaker counter
    "block_reason": null      // set when circuit breaker trips
  }
}
```

**Circuit breaker**: if an agent fails the same story 3 times OR emits `ESCALATE:`, mark `blocked` and set `block_reason` on the story (persist to STATE.md). Controlled vocabulary + SCOPE_FILES injection pattern in `references/main.md` §**"`block_reason` Vocabulary"** and §**"Per-Story Scope Constraint"**.

---

## Phase 3: IMPLEMENT — Monitor and Coordinate

### 3.1 Agent Work Loop
Each agent follows a per-story loop: read → implement → verify → check done → commit → complete → next. Full detail: [references/main.md](references/main.md#agent-work-loop).

### 3.2 Orchestrator Monitoring Loop

1. **Monitor progress** (event-driven): start `Monitor(command: "tail -f ${PROGRESS_FILE} | grep --line-buffered 'done\\|blocked\\|wave_complete'", persistent: true)` before first wave. Fall back to `TaskList` polling (every 2-3 turns) if Monitor unavailable.
1a. **Write carry-forward registry progress on story `DONE:`.** Before updating STATE.md, follow the writer contract in [/_shared/sprint-contracts.md](/_shared/sprint-contracts.md) §Writers (sprint-dev): validate story `registry_entries` ids, compute `new_actual = current + delta` (clamp at `scope.target`), append a `progress` line transitioning to `partial` or `complete`, log the activity-feed mirror. Apply inference-fallback (parent-epic link with `delta: 1`) when story omits `registry_entries`.
1b. **Update STATE.md** after each story completion or wave boundary per [session-lifecycle.md](/_shared/session-lifecycle.md). Include wave progress.
1c. **Commit and push at wave boundaries**: `git add -A && git commit -m "feat(sprint-${N}): wave ${WAVE} complete — ${COMPLETED}/${TOTAL} stories" && git push origin HEAD`. Also push after each integration fix round (Phase 4.3) and at sprint completion.
2. **Unblock stories** — when a dependency completes, send newly-ready stories to the appropriate agent.
3. **Coordinate via SendMessage** — when an agent completes a story another depends on:
   ```
   SendMessage to <waiting-agent>:
   UNBLOCK: S${N}-XXX is complete. You can now start S${N}-YYY.
   Files created: <list>. Key exports: <list>.
   ```
4. **Handle stuck agents** — send `ASSIST:` message with hints; invoke circuit breaker if still stuck after 2 assists.
5. **Context hygiene** per [session-lifecycle.md](/_shared/session-lifecycle.md): summarize completions (files + exports only), print compact progress at wave boundaries, offload progress to STATE.md, write checkpoint if context monitor warns at ~60%+.

### 3.3 Cross-Agent Communication Protocol

Agents communicate through the orchestrator using prefixed messages (DONE, BLOCKED, DEVIATION, ESCALATE, UNBLOCK, ASSIST, SYNC, HALT). Full direction/purpose table in `references/main.md` §**"Communication Prefix Table"**.

### 3.4 Story Distribution Rules

Dependency-layer priority order (schemas → server → stores → components → nav → tests); within same priority, higher `priority` field first, then smaller `points`. Full table: [references/main.md](references/main.md#story-distribution-rules).

---

## Phase 3.5: INTEGRATION CHECKS AND UI/UX PASS (MANDATORY)

This phase is **mandatory** and must not be skipped, even if no explicit UI stories exist.

### 3.5.0 Run Integration Check (Mandatory)

Run `/blitz:review --only wiring` to verify: export-to-import tracing, route coverage, store wiring. Fix high-severity findings before UI pass.

### 3.5.1 Spawn Integration Agent

Spawn `blitz:frontend-dev` (reused or fresh as `ui-integrator`) as a Medium-class agent on dedicated `sprint-${N}/integration` worktree branch. Full spawn parameters, progress-file schema, HEARTBEAT inclusion, and mandatory-fallback rule in `references/main.md` §**"Integration Agent Spawn + Fallback"**.

### 3.5.2 Integration Checklist

Integration agent verifies and implements: **Navigation entries**, **Design tokens**, **Layout consistency**, **State wiring**, **Accessibility**, **Loading states**, **Route guards**. Full item definitions in `references/main.md` §**"Integration Checklist"**.

### 3.5.3 Integration Commit

```bash
git add -A && git commit -m "feat(sprint-${N}/integration): UI/UX integration pass"
```

---

## Phase 4: INTEGRATE — Merge and Verify

### 4.1 Merge Worktree Branches

```bash
git checkout -b sprint-${SPRINT_NUMBER}/merged
git merge sprint-${SPRINT_NUMBER}/backend --no-edit
git merge sprint-${SPRINT_NUMBER}/frontend --no-edit
git merge sprint-${SPRINT_NUMBER}/tests --no-edit
# Handle merge conflicts if any
```

### 4.2 Full Build Verification (Selective Re-Runs)

Run full verification sweep (type-check, lint, test, build). On re-runs during Phase 4.3 fix iterations, use selective re-verification strategy in `references/main.md` §**"Selective Re-Verification Strategy"**. Final fix round always gets one full sweep.

### 4.2.5 Completeness Gate

Run `/blitz:review --only completeness` on changed source files (`git diff --name-only ${SPRINT_BASE}..HEAD -- '*.ts' '*.tsx' '*.vue'`). Score < C (70) → flag critical findings in integration report; do not block.

### 4.2.1 Cross-Phase Regression Testing

If `SPRINT_NUMBER > 1`, run regression tests from prior sprints. Full procedure in `references/main.md` §**"Cross-Phase Regression Testing"**.

### 4.3 Fix Integration Issues

If verification fails:
1. Categorize errors (type errors, import errors, test failures, build errors).
2. Fix systematically — types first, then imports, then logic, then tests.
3. Max 5 fix iterations; if still failing, report remaining issues.
4. Commit each fix round: `git commit -m "fix(sprint-${N}): resolve integration issues — round ${ROUND}"`

### 4.4 Clean Up Worktrees and Branches

Canonical contract: [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md). After Phase 4.1 merge succeeds, sprint-dev MUST explicitly remove worktrees AND delete the underlying agent branches (`git branch -d`, safe: refuses unmerged). Full cleanup script in `references/main.md` §**"Worktree + Branch Cleanup (Phase 4.4)"** — covers roles `{backend,frontend,tests,infra}` plus the Phase 3.5.1 integration branch; logs failures as `warning` events. Escape hatch: `BLITZ_SKIP_BRANCH_CLEANUP=1` preserves branches for forensic inspection.

### 4.5 E2E Verification (Best-Effort)

If Playwright MCP available: start dev server, smoke-test first 10 changed routes. 0 Critical + 0 Error = PASS; 1+ Critical = CONDITIONAL; 1+ Error = PASS with notes. Skip gracefully if unavailable.

### 4.6 Shutdown Team

Send `HALT:` to remaining agents.

### 4.7 Update Sprint Registry

Acquire `sprint-registry.json.lock` per [session-lifecycle.md](/_shared/session-lifecycle.md) §File-Based Locking Protocol. Update sprint status to `review` with `completed_date`, `stories_completed`, `stories_blocked`, `integration_issues`.

### 4.8 Update Story Statuses

Update each story frontmatter `status`: `done` (passes verification), `incomplete` (partial / failing tests), `blocked` (circuit breaker triggered). Acquire per-file lock before write.

### 4.8.5 Blocked Story Accountability

For every story marked `blocked`:
1. Document WHY (circuit breaker details, specific errors, missing dependencies).
2. Document what work WAS completed and what REMAINS.
3. Create carry-forward entry in the manifest's `carry_forward` array.
4. Sprint summary MUST include a prominent warning with blocked count and story IDs.

**Never silently drop blocked stories.** They must be visible in the sprint report and carry forward.

### 4.9 Final Commit and Push

```bash
git add -A
git commit -m "feat(sprint-${N}): complete sprint implementation — ${COMPLETED}/${TOTAL} stories"
git push origin HEAD
```

### 4.10 Final Output and Error Recovery

Print summary block per `references/main.md` §"Final Output Template".

**Inline recovery rules** (full detail in `references/main.md` §"Error Recovery"):
- **Agent timeout/OOM**: escalate story to `blocked`; send `HALT:`; fallback to next story in wave.
- **Malformed agent output**: retry with narrower scope (one story, reduced file count); abort after 3 retry failures.
- **Lock-acquisition failure**: retry 3× with 20s backoff; abort with `BLOCK: lock conflict` if still held.
- **STATE.md corrupt on resume**: recover per [session-lifecycle.md](/_shared/session-lifecycle.md) §STATE.md Parse-Failure Handling.
- **Validation failures** (story frontmatter): run `/blitz:conform --fix` then re-validate; escalate if persist.

### 4.11 Push Completion Notification

```
PushNotification(
  title: "Sprint ${N} complete ✓",
  message: "${COMPLETED}/${TOTAL} stories · ${BLOCKED} blocked · review ready",
  url: "https://github.com/<repo>/tree/sprint-${N}"
)
```

Call unconditionally — no-op if Remote Control not configured.

## Gotchas

- Missing/locked `manifest.json` or unset `SPRINT_NUMBER` → Phase 0.0 hard-fail. Run `/blitz:sprint-plan` first.
- Per-wave caps: >4 stories OR >6 files per agent/wave exhausts a Heavy-class agent mid-work (sprint-276 root cause). Split to next wave.
- Ratchet regression (`type_errors` floor, `stale_worktree_branch_count`) blocks PASS without a carry-forward entry (Invariant 6).
- Undeleted `sprint-N/{backend,frontend,tests,infra}` branches fail Invariant 8 — Phase 4.4 must `git branch -d` them.
- Agent-wave timeout → mark story `blocked` + carry forward (Phase 4.8.5); never silently drop.

Detail: [references/main.md](references/main.md#gotchas).
