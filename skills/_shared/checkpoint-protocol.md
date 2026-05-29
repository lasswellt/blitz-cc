# Checkpoint Protocol

Shared reference for sprint checkpoint/resume. Skills that run multi-story implementations MUST write and read STATE.md files to enable session recovery.

**Companion protocols:**
- [session-protocol.md](session-protocol.md) — Session registration and file locking
- [verbose-progress.md](verbose-progress.md) — Activity feed logging

---

## When to Write STATE.md

Write (or update) `${SPRINT_DIR}/STATE.md` at these checkpoints:

1. **After each story completion** — Update completed/in-progress/ready tables.
2. **Before any long-running operation** — Merge, full build verification, E2E testing.
3. **On error recovery** — Before retrying or escalating.

---

## STATE.md Format

Write to `sprints/sprint-${SPRINT_NUMBER}/STATE.md`:

```markdown
# Sprint ${SPRINT_NUMBER} State

Last updated: <ISO-8601>
Session: <SESSION_ID>
Phase: <current phase number> (<PHASE_NAME>)

## Completed Stories

| ID | Agent | Commit | Status |
|---|---|---|---|
| S${N}-001 | backend-dev | abc1234 | done |
| S${N}-002 | backend-dev | def5678 | done |

## In-Progress Stories

| ID | Agent | Status | Blocker |
|---|---|---|---|
| S${N}-005 | frontend-dev | implementing | none |

## Blocked Stories

| ID | Reason | Since |
|---|---|---|
| S${N}-010 | circuit-breaker (3 failures) | <ISO-8601> |

## Ready Stories (unblocked, not started)

- S${N}-007 (depends on S${N}-005)
- S${N}-009 (no dependencies)

## Worktree Status

| Branch | Agent | Last Commit |
|---|---|---|
| sprint-${N}/backend | backend-dev | abc1234 |
| sprint-${N}/frontend | frontend-dev | ghi9012 |
| sprint-${N}/tests | test-writer | — |

## Wave Progress

| Wave | Stories | Status |
|---|---|---|
| 0 | S${N}-001, S${N}-002 | complete |
| 1 | S${N}-003, S${N}-005 | in-progress |
| 2 | S${N}-007, S${N}-009 | pending |

## Resume Instructions

To resume this sprint from a new session:
1. Read this STATE.md to rebuild the dependency graph.
2. Skip Phases 0-2 (context, discover, team creation).
3. Check worktree branches exist: `git worktree list`
4. For each worktree branch, verify last commit matches the table above.
5. Rebuild agent_tracker from the tables above.
6. Continue from Phase 3 with remaining stories.
7. Send UNBLOCK messages for any ready stories that have agents idle.
```

---

## How to Resume (sprint-dev Phase 0)

When sprint-dev starts, before the normal Phase 0 flow:

1. **Check for STATE.md** — Read `${SPRINT_DIR}/STATE.md` if it exists.
2. **Validate staleness** — If `Last updated` is more than 24 hours ago, warn the user and ask whether to resume or start fresh.
3. **Validate worktrees** — Run `git worktree list` and compare with the Worktree Status table. If any worktree is missing, note it as needing recreation.
4. **Rebuild tracker** — Populate `agent_tracker` from the Completed/In-Progress/Blocked/Ready tables.
5. **Skip to Phase 3** — With the tracker populated, skip Phases 0.5-2 and resume the monitoring loop.
6. **Log resume event** — Append to activity feed:
   ```jsonl
   {"ts":"<ISO-8601>","session":"<NEW_SESSION_ID>","skill":"sprint-dev","event":"decision","message":"Resuming sprint ${N} from STATE.md checkpoint","detail":{"resumed_from":"<OLD_SESSION_ID>","completed_stories":<count>,"remaining_stories":<count>}}
   ```

### STATE.md Parse-Failure Handling

If STATE.md exists but fails YAML/markdown parse (truncated, garbled by a hard-kill):

1. **Detect** (structural markdown validation — STATE.md has no YAML frontmatter, only markdown sections):
   ```bash
   STATE_FILE="${SPRINT_DIR}/STATE.md"
   CORRUPT=0
   grep -qE '^# Sprint [0-9]+' "$STATE_FILE" 2>/dev/null || CORRUPT=1
   grep -qE 'Last updated:' "$STATE_FILE" 2>/dev/null || CORRUPT=1
   ```
   Real STATE.md headers vary: `# Sprint N — STATE` (em dash) or `# Sprint N State`; "Last updated:" may be plain or bold (`**Last updated:**`). The grep patterns above tolerate both variants. Missing required content → corrupt.
2. **Abort vs reset**: if `autonomy < high`, stop and prompt: "STATE.md is corrupt — resume from scratch (loses completed progress) or abort?". In `autonomy=full`, auto-reset and log a `warning` event with `{"reason":"corrupt_state_md","action":"reset_to_full_sprint"}`.
3. **On reset**: delete corrupt STATE.md, re-read sprint stories, restart from Phase 0 (all stories treated as `planned`). Log `decision` event noting the reset.
4. **Report**: include `state_md_reset: true` in the sprint report Phase 4 summary so sprint-review flags it.

---

## Orchestrator Support (sprint, implement)

The `sprint` and `implement` orchestrator skills support a `--resume` flag:

- `--resume`: Skip sprint-plan, go directly to sprint-dev. sprint-dev will detect STATE.md and resume.
- Without `--resume`: Normal flow. sprint-dev still checks for STATE.md at Phase 0 and offers to resume if found.

---

## STATE.md Lifecycle

1. **Created** by sprint-dev at first story completion.
2. **Updated** after each story completion, block, or unblock.
3. **Finalized** at Phase 4 completion — update phase to `4 (INTEGRATE)`, mark all stories final.
4. **Preserved** — STATE.md is NOT deleted after sprint completion. It serves as a historical record alongside the sprint manifest.

---

## HANDOFF.json — Cross-Session Continuity

STATE.md covers sprint-dev specifically. For other skills that may be interrupted or complete with follow-up work needed, use HANDOFF.json.

### When to Write HANDOFF.json

Write `${SESSION_TMP_DIR}/HANDOFF.json` when:
- The session is interrupted (user cancels, context limit reached, error forces stop)
- The skill completes but has follow-up work that another session should pick up
- A long-running skill reaches a natural checkpoint (e.g., migrate between steps)

### HANDOFF.json Format

```json
{
  "session_id": "<SESSION_ID>",
  "skill": "<skill-name>",
  "timestamp": "<ISO-8601>",
  "status": "interrupted | completed_with_followups",
  "progress": {
    "current_phase": "<phase name>",
    "completed_phases": ["phase1", "phase2"],
    "remaining_phases": ["phase3", "phase4"],
    "percentage": 60
  },
  "context": {
    "target": "<what was being worked on>",
    "key_decisions": [
      "Chose approach X over Y because Z"
    ],
    "files_modified": ["path/to/file1.ts", "path/to/file2.vue"],
    "commits_created": ["abc1234", "def5678"]
  },
  "resume_instructions": [
    "Read the research output at ${SESSION_TMP_DIR}/research.md",
    "Continue from Phase 3 — story generation",
    "The codebase inventory is already complete"
  ],
  "blockers": [
    {
      "description": "API endpoint returns 403 — needs auth token refresh",
      "severity": "high",
      "workaround": "Re-run with valid credentials"
    }
  ],
  "follow_ups": [
    {
      "skill": "test-gen",
      "target": "src/stores/auth.ts",
      "reason": "New store created but tests not yet generated"
    }
  ]
}
```

### Skills That Should Support HANDOFF.json

| Skill | When to Write |
|-------|--------------|
| `migrate` | Between migration steps (progress file also serves this role) |
| `refactor` | If refactoring spans multiple files and is interrupted |
| `doc-gen` (full mode) | If agent completion times out |
| `audit` | If audit is interrupted before all pillars complete |
| `sprint-plan` | If research phase completes but story generation is interrupted |

### How to Resume from HANDOFF.json

When a skill starts, check for existing handoff files:
```bash
find .cc-sessions/ -name "HANDOFF.json" -newer .cc-sessions/activity-feed.jsonl 2>/dev/null
```

If a relevant HANDOFF.json exists (same skill, matching target):
1. Display the handoff summary to the user.
2. Ask: "Resume from previous session or start fresh?"
3. If resuming, load context and skip to the indicated phase.
4. Log a `decision` event: "Resuming from HANDOFF.json (session: <old-session>)".


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
