# Verbose Progress Protocol

All skills MUST emit verbose progress output so the user always knows what is happening. This protocol defines the standard format for progress reporting and cross-instance activity logging.

---

## Console Output (User-Facing)

Every skill MUST print status lines at each phase transition, substep, and decision point. Use these exact formats:

### Phase Entry

```
[<skill-name>] Phase <N>: <PHASE_TITLE>
```

Example:
```
[sprint-plan] Phase 0: CONTEXT — Loading project state
[sprint-plan] Phase 1: INITIALIZE — Selecting epics and creating sprint
```

### Substep Progress

```
[<skill-name>]   ├─ <action-in-progress>...
[<skill-name>]   ├─ <action-completed> ✓ (<detail>)
[<skill-name>]   └─ <final-substep> ✓
```

Examples:
```
[sprint-plan]   ├─ Searching for registry files...
[sprint-plan]   ├─ Found roadmap-registry.json ✓ (12 epics, 4 in-progress)
[sprint-plan]   ├─ Loading research index...
[sprint-plan]   ├─ Research index loaded ✓ (8 documents, 3 epics covered)
[sprint-plan]   ├─ Building codebase inventory...
[sprint-plan]   ├─ Inventory complete ✓ (42 source files, 3 packages)
[sprint-plan]   └─ Phase 0 complete ✓
```

### Decision Points

When a skill makes a non-trivial decision, explain WHY:

```
[<skill-name>]   ├─ DECISION: <what was decided>
[<skill-name>]   │  Reason: <why this was chosen>
```

Examples:
```
[sprint-plan]   ├─ DECISION: Selected epics EP-003, EP-004, EP-007
[sprint-plan]   │  Reason: EP-001, EP-002 are done. EP-005 blocked by EP-003. EP-006 blocked by EP-004.
[sprint-dev]    ├─ DECISION: Spawning 3 agents (no infra stories)
[sprint-dev]    │  Reason: 5 backend stories, 4 frontend stories, 3 test stories, 0 infra stories
```

### Agent Spawning

```
[<skill-name>]   ├─ SPAWNING: <agent-name> — <role description>
[<skill-name>]   │  Working on: <list of assigned items>
[<skill-name>]   │  Worktree: <path> (if applicable)
```

### Agent Progress (Orchestrator Relaying)

```
[<skill-name>]   ├─ [<agent-name>] <status message>
```

Examples:
```
[sprint-dev]   ├─ [backend-dev] Implementing S1-003: Create registration Cloud Function
[sprint-dev]   ├─ [backend-dev] S1-003 type-check PASS ✓
[sprint-dev]   ├─ [backend-dev] S1-003 committed ✓
[sprint-dev]   ├─ [frontend-dev] Implementing S1-007: User registration form
[sprint-dev]   ├─ UNBLOCK: S1-008 now ready (depends on S1-003 ✓)
```

### Warnings and Errors

```
[<skill-name>]   ⚠ WARNING: <message>
[<skill-name>]   ✖ ERROR: <message>
```

### Session Registration

```
[<skill-name>] Session registered: <SESSION_ID>
[<skill-name>]   ├─ Checking for conflicts...
[<skill-name>]   ├─ No conflicts found ✓  (or: Found active session <X>, proceeding with caution)
```

### Phase Completion

```
[<skill-name>] Phase <N> complete ✓ (<summary>)
```

### Skill Completion

```
[<skill-name>] Complete ✓ — <one-line summary>
  Duration: <elapsed>
  Activity logged to .cc-sessions/activity-feed.jsonl
```

---

## Activity Feed (Cross-Instance)

All skills MUST write to the activity feed so other Claude Code instances can see what's happening. This is the mechanism for multi-instance awareness.

### File Location

```
.cc-sessions/activity-feed.jsonl
```

### Entry Format

One JSON object per line, append-only:

```json
{"ts":"<ISO-8601>","session":"<SESSION_ID>","skill":"<skill-name>","event":"<event-type>","message":"<human-readable message>","detail":{}}
```

### Required Events

Every skill MUST log these events to the activity feed:

| Event Type | When | Detail Fields |
|---|---|---|
| `skill_start` | Skill begins execution | `{ "args": "<parsed arguments>", "phase": 0 }` |
| `phase_start` | Each phase begins | `{ "phase": <N>, "title": "<phase title>" }` |
| `decision` | Non-trivial decision made | `{ "choice": "<what>", "reason": "<why>" }` |
| `agent_spawn` | Agent spawned | `{ "agent": "<name>", "role": "<role>", "items": ["<assigned items>"] }` |
| `agent_progress` | Agent completes a unit of work | `{ "agent": "<name>", "item": "<story/task>", "status": "done|blocked|error" }` |
| `registry_update` | Any registry file modified | `{ "file": "<path>", "change": "<summary>" }` |
| `phase_complete` | Each phase completes | `{ "phase": <N>, "summary": "<result>" }` |
| `skill_complete` | Skill finishes | `{ "status": "success|partial|failed", "summary": "<result>" }` |
| `warning` | Non-fatal issue encountered | `{ "message": "<detail>" }` |
| `error` | Fatal or significant error | `{ "message": "<detail>", "recoverable": true|false }` |

### Message length (soft rule)

The `message` field SHOULD be ≤200 characters. The JSONL envelope (all keys except `message`) is a preservation boundary — parsers depend on its shape — but the `message` string is compression-eligible prose.

If the message would exceed 200 chars, move detail into the `detail` object. Keep the `message` a one-line human-readable summary.

**Sprint-review grep audit** (non-BLOCKER warning):

```bash
# Flag any message field over 300 chars
grep -E '"message":".{300,}"' .cc-sessions/activity-feed.jsonl
```

300 chars is the hard audit threshold (soft target is 200). A hit prints a warning but does not fail the sprint. Persistent offenders (same pattern across multiple sprints) may warrant an update to the emitting skill.

### Reading the Activity Feed

At session start (during the session protocol preamble), skills MUST:

1. Read the last 20 lines of `.cc-sessions/activity-feed.jsonl` (if it exists).
2. Print a summary of recent activity:

```
[<skill-name>] Recent activity (last 30 minutes):
  ├─ [sprint-dev-a3f7c1b2] sprint-dev: Implementing sprint 3 — 8/12 stories done (15m ago)
  ├─ [research-b4e8f2a1] research: Completed auth-strategy research (28m ago)
  └─ No conflicts detected ✓
```

3. If any active session is working on conflicting resources, warn before proceeding.

### Writing to the Activity Feed

Use append mode. Example bash implementation:

```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","session":"'"${SESSION_ID}"'","skill":"<skill-name>","event":"skill_start","message":"Starting <skill-name>","detail":{"args":"<args>","phase":0}}' >> .cc-sessions/activity-feed.jsonl
```

Or use the Write tool with append semantics (read existing content, add new line, write back) if bash append is not available.

### Feed Maintenance

The activity feed is append-only and grows over time. To prevent unbounded growth:
- Skills MAY truncate entries older than 7 days when the file exceeds 500 lines.
- Truncation should preserve the most recent 200 entries.
- Only one session should truncate at a time (use a brief lock if needed).

---

## Sprint Selection Verbosity (Special Case)

Sprint-family skills (sprint, sprint-plan, sprint-dev, sprint-review, implement, review, ship) require structured decision-tree output at key moments. Use the formats below — adapt the data, keep the shape.

| Trigger | Format | Required content |
|---|---|---|
| Epic selection (sprint-plan) | Tree (`├─ EP-XXX "title" — STATUS → action`) | Every candidate epic + status + reason + selection verdict |
| Story distribution (sprint-dev) | Tree grouped by agent role | Every story + priority + points + dependencies per agent |
| Wave progress (sprint-dev) | `Wave N: <progress-bar> N/M stories <state>` per wave | All waves + completion fraction + critical-path note |
| Sprint dashboard (sprint-dev, every 3 completions or wave boundary) | Box-drawing dashboard with stories %/points %/per-agent rows | Stories, points, per-agent progress, ready/blocked/in-progress lists |

Canonical examples (copy + adapt):

```
[sprint-plan] Epic Selection:
  ├─ EP-003 "Dashboard" — UNBLOCKED (deps: EP-001 ✓, EP-002 ✓) → SELECTED
  ├─ EP-005 "Admin Panel" — BLOCKED (deps: EP-003 pending) → skip
  └─ EP-007 "API Keys" — UNBLOCKED (no deps) → SELECTED
  Selected: 3 epics; estimated stories: 12-18

[sprint-dev] Wave Progress:
  Wave 0: ████████████████████ COMPLETE (3/3)
  Wave 1: ██████████░░░░░░░░░░ 2/4 in progress
  Critical path: on track (Wave 1 ETA: ~2 more stories)

[sprint-dev] Progress Dashboard:
  Stories 6/12 (50%) · Points 19/41 (46%) · Wave 2 of 4
  backend 3/5 · frontend 1/4 · test 2/3
  Ready: S3-010, S3-011 · Blocked: S3-012 (waits S3-008) · In-progress: S3-004
```

Box-drawing dashboards (`┌─┐│└─┘`) are acceptable when terminal width permits but not required — the inline form above conveys the same information.

---

## Integration with Existing Session Protocol

This protocol extends (not replaces) the session-protocol.md. Specifically:

1. **Session registration** now includes activity feed write (skill_start event).
2. **Session cleanup** now includes activity feed write (skill_complete event).
3. **Lock operations** already logged in operations.log — activity feed logs higher-level events only.
4. **Conflict detection** now also reads the activity feed for recent context.

All skills that reference session-protocol.md should also follow this verbose-progress protocol.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
