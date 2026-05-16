---
name: next
description: "Reads current project, sprint, and carry-forward state and tells the user what action to take next (run sprint-plan, resume sprint-dev, ship, address a registry escalation, etc.). With --loop, becomes the canonical autonomous reconciliation engine: auto-dispatches the recommended action via the Skill tool and exits cleanly so /loop or ScheduleWakeup can re-tick. Supersedes /blitz:sprint --loop (now a backwards-compat alias). Use when the user asks 'what should I do next?', 'where are we?', 'is anything blocked?', '/blitz:next', or invokes autonomous mode."
argument-hint: "[--loop] -- default: read state and suggest a command. --loop: auto-dispatch the recommended phase, commit/push, exit; designed for /loop /blitz:next --loop or self-scheduled ScheduleWakeup."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill, ScheduleWakeup
model: sonnet
effort: low
compatibility: ">=2.1.71"
---


<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For pipeline artifact contracts (which files indicate which next-action: `STATE.md`, `roadmap/`, `carry-forward.jsonl`, `review-report.md`), see [/_shared/state-handoff.md](/_shared/state-handoff.md)
- For carry-forward registry reads (`CF_ACTIVE`, `CF_ESCALATED`, `UNINGESTED_COUNT`), see [/_shared/carry-forward-registry.md](/_shared/carry-forward-registry.md)

---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Next Action Advisor + Autonomous Reconciliation Engine

Two modes:

1. **Default (read-only suggest)** — `/blitz:next` reads state and prints the recommended next blitz command. No dispatch, no writes. Lightweight survey.
2. **`--loop` (auto-dispatch reconciliation)** — `/blitz:next --loop` reads state, executes **one phase**, commits + pushes, and exits cleanly so `/loop` or `ScheduleWakeup` can re-tick. Sets autonomy to `full`. Canonical autonomous-loop entry point for blitz (supersedes `/blitz:sprint --loop` since v1.13.0).

**Session protocol**: skipped in default mode (read-only). Required in `--loop` mode (writes commits, dispatches sub-skills).

**Verbose progress**: skipped in default mode. `--loop` mode prints a concise per-tick reconciliation report (Observe → Diff → Act → Report).

---

## Flag Parsing

- `--loop`: Autonomous reconciliation mode. Reads state, dispatches one phase, commits/pushes, exits. Sets autonomy `full` — all sub-skill confirmation prompts auto-approved. Designed for use with `/loop <interval> /blitz:next --loop` or self-scheduled `ScheduleWakeup` under bypass permissions.

  **Scheduling tiers for `--loop`:**

  | Tier | How | Persistence | Min interval | Use case |
  |------|-----|-------------|--------------|----------|
  | `/loop` + CronCreate | Session-scoped | Requires active session | 1 min | Interactive dev sprints |
  | Desktop scheduled task | Survives session restart | Requires machine | 1 min | Overnight local runs |
  | Routine (cloud) | Machine-independent | Fully autonomous | 1 hour | Nightly CI, weekly sweeps |

  **Self-scheduling in loop mode:** After Step 3 (Act) completes, use `ScheduleWakeup` to register the next tick — keeps the loop alive through idle periods without requiring the user to keep a terminal open:
  ```
  ScheduleWakeup(
    delaySeconds: 270,   # under 5-min cache TTL; adjust per cadence
    prompt: "/blitz:next --loop",
    reason: "next reconciliation tick"
  )
  ```
  Do NOT use `ScheduleWakeup` if the user invoked `/loop <interval>` — that already handles scheduling. Detect via `CLAUDE_CODE_LOOP_MANAGED` env var: if `"1"`, skip `ScheduleWakeup`.

  **Session expiry:** CronCreate-backed sessions expire after 7 days. For longer runs use a cloud Routine (see `/schedule`).

If `--loop` is not specified, fall through to default suggest mode (Phase 2 only — no dispatch).

---

## Phase 0: READ STATE

### 0.1 Check Sprint Registry

```bash
cat sprint-registry.json 2>/dev/null || echo "No sprint registry"
```

If the registry exists, find the most recent sprint and its status.

### 0.2 Check for STATE.md (In-Progress Sprint)

If a sprint is `in-progress`, check for a checkpoint file:

```bash
SPRINT_DIR="sprints/sprint-${LATEST_SPRINT_NUMBER}"
cat "${SPRINT_DIR}/STATE.md" 2>/dev/null | head -20
```

If STATE.md exists, note the number of completed/remaining stories.

### 0.3 Check Activity Feed

Read the last 10 lines of the activity feed for recent context:

```bash
tail -10 .cc-sessions/activity-feed.jsonl 2>/dev/null
```

### 0.4 Check Git State

```bash
git status --porcelain 2>/dev/null | head -10
git branch --show-current 2>/dev/null
```

### 0.5 Check for Roadmap

```bash
cat roadmap-registry.json 2>/dev/null | head -5 || echo "No roadmap registry"
cat epic-registry.json 2>/dev/null | head -5 || echo "No epic registry"
```

### 0.6 Check Carry-Forward Registry

```bash
CF_ACTIVE=$(jq -s '
  group_by(.id) | map(max_by(.ts))
  | map(select(.status == "active" or .status == "partial"))
  | length
' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "0")

CF_ESCALATED=$(jq -s '
  group_by(.id) | map(max_by(.ts))
  | map(select((.status == "active" or .status == "partial") and (.rollover_count // 0) >= 3))
  | length
' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "0")
```

### 0.7 Check for Pending Planning Inputs (carry-forward Invariant 4 output)

```bash
NEXT_SPRINT=$((LATEST_SPRINT_NUMBER + 1))
CF_PENDING_INPUTS=$(test -f "sprints/sprint-${NEXT_SPRINT}-planning-inputs.json" && echo "1" || echo "0")
```

### 0.8 Check for Uningested Research (carry-forward-aware)

A research doc is "uningested" if it's newer than roadmap-registry.json AND its `scope:` IDs aren't yet in the carry-forward registry:

```bash
INGESTED_IDS=$(jq -rs '[group_by(.id)[] | max_by(.ts).id] | join("\n")' \
  .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "")
UNINGESTED=$(find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null \
  | while read f; do
      IDS=$(grep -o 'id: cf-[^ ]*' "$f" 2>/dev/null | awk '{print $2}')
      if [ -z "$IDS" ]; then echo "$f"; continue; fi
      for id in $IDS; do
        echo "$INGESTED_IDS" | grep -qx "$id" || { echo "$f"; break; }
      done
    done)
UNINGESTED_COUNT=$(echo "$UNINGESTED" | grep -c '.' 2>/dev/null || echo 0)
```

### 0.9 Check for Active Sessions (loop mode only)

```bash
ls .cc-sessions/*.json 2>/dev/null
```

### 0.10 Check for HARD_SPEC-Blocked Stories

Scan the in-progress sprint's STATE.md (and story frontmatter) for any story marked `blocked` with a `block_reason` that signals a hard-spec escalation. These reasons short-circuit auto-resume per row 1a:

```bash
HARD_SPEC_BLOCKERS=""
if [ -f "${SPRINT_DIR}/STATE.md" ]; then
  # block_reason field is recorded by sprint-dev when test-writer emits
  # ESCALATE: spec-investigation-budget-exhausted or ESCALATE: oracle-underivable.
  HARD_SPEC_BLOCKERS=$(grep -E 'block_reason:\s*(hard_spec|oracle-underivable|test-assertion-suspect|scope-expansion-needed)' \
    "${SPRINT_DIR}/STATE.md" "${SPRINT_DIR}/stories/"*.md 2>/dev/null || true)
fi
```

If `$HARD_SPEC_BLOCKERS` is non-empty, row 1a fires before row 1. The HARD_SPEC vocabulary is defined in `agents/test-writer.md` Spec Fix Mode + `skills/sprint-dev/SKILL.md` block_reason field.

---

## Phase 1: DETERMINE NEXT ACTION

Apply this priority-ordered decision tree (canonical — same logic used by `--loop` reconciliation and by suggest mode):

| # | Condition | Action | Dispatch (--loop) | Default suggest |
|---|-----------|--------|-------------------|-----------------|
| 0 | `$UNINGESTED_COUNT > 0` (research docs newer than roadmap, scope IDs not yet ingested) | Ingest research first | Invoke `/blitz:roadmap extend`, then exit so next tick re-enters | `/blitz:roadmap extend` |
| 1 | Sprint `in-progress` + STATE.md exists | Resume implementation | Invoke `/blitz:implement --resume` | `/blitz:implement --resume` |
| 1a | Sprint `in-progress` + any story `status: blocked` with `block_reason: hard_spec` or `block_reason: oracle-underivable` (see Phase 0.10) | HARD_SPEC blocked — operator pairing or ask-before-code needed; auto-resume would just thrash | Print HARD_SPEC escalation banner with the blocked story id + block_reason + last 3 hypotheses (from STATE.md); exit signal LOOP_ESCALATE | Print same banner; suggest `/blitz:ask` to investigate or operator pair on the blocked spec |
| 2 | Sprint `in-progress` + no STATE.md | Continue implementation | Invoke `/blitz:implement --sprint N` | `/blitz:implement --sprint N` |
| 3 | Sprint status `review` | Run review | Invoke `/blitz:review --sprint N` | `/blitz:review --sprint N` |
| 4 | Sprint status `reviewed` + quality passing | Ship | Invoke `/blitz:ship` | `/blitz:ship` |
| 5 | Sprint status `planned` | Start implementation | Invoke `/blitz:implement --sprint N` | `/blitz:implement --sprint N` |
| 6a | No active sprint + `$CF_ESCALATED > 0` | Escalate — operator review needed | Print escalation banner + exit cleanly | `/blitz:sprint --gaps` |
| 6b | No active sprint + `$CF_PENDING_INPUTS == 1` (planning-inputs file from prior review Invariant 4) | Plan gap-closure sprint against injected entries | Invoke `/blitz:sprint-plan` (honors planning-inputs file) | `/blitz:sprint-plan` |
| 6c | No active sprint + roadmap with unblocked epics | Plan next sprint | Invoke `/blitz:sprint-plan` | `/blitz:sprint-plan` |
| 6d | No active sprint + `$CF_ACTIVE > 0` (registry has active/partial entries even though epics look done) | Plan gap-closure sprint against registry | Invoke `/blitz:sprint-plan` (will re-select parent epics) | `/blitz:sprint-plan` |
| 7 | No active sprint + all epics blocked/done AND `$CF_ACTIVE == 0` AND `$CF_PENDING_INPUTS == 0` | Nothing to do | Print idle status + exit signal LOOP_DONE | `/blitz:roadmap extend` |
| 8 | No roadmap exists AND `$CF_ACTIVE == 0` | Cannot proceed | Print "No roadmap" + exit | `/blitz:roadmap full` |

### Tie-Breaking (if multiple conditions match)

1. Resume interrupted work (STATE.md exists)
2. Complete in-progress work
3. Ship reviewed work
4. Start planned work
5. Resolve carry-forward escalations (row 6a) — blocks all further progress until human review
6. Plan new work from injected inputs (row 6b) before roadmap epics (row 6c)
7. Plan carry-forward gap closure (row 6d) before declaring idle (row 7)
8. HARD_SPEC escalation (row 1a) short-circuits resume (row 1) — auto-resuming a sprint with a HARD_SPEC-blocked story burns tokens on the same failing attempt; the loop must escalate to operator instead.

**Why rows 6a-6d exist:** the prior state machine collapsed rows 6 and 7 together, so an idle roadmap with a non-empty carry-forward registry was indistinguishable from "nothing to do" — the silent-drop mode traced in `docs/_research/2026-04-08_sprint-carryforward-registry.md`. The four-way split makes registry state load-bearing: the loop cannot exit idle while there is pending carry-forward work, and row 6a short-circuits `rollover_count >= 3` to human escalation.

---

## Phase 2: SUGGEST (default mode)

If `--loop` was NOT specified, print the recommendation and exit. Do NOT dispatch.

Print a clear recommendation:

```
Next Action
===========
Based on current state:
  Sprint 3: in-progress (8/12 stories done, STATE.md checkpoint exists)
  Last activity: 2h ago — sprint-dev implementing S3-009

Recommendation:
  Resume sprint 3 implementation from checkpoint.

Command:
  /blitz:implement --resume

Alternative actions:
  - /blitz:sprint-review --sprint 2  (sprint 2 awaiting review)
  - /blitz:health                    (check plugin health)
```

If the git working tree has uncommitted changes, mention that first:

```
⚠ Uncommitted changes detected. Consider committing or stashing before proceeding.
```

---

## Phase 3: ACT (--loop only) — Auto-Dispatch + Commit + Exit

Only runs if `--loop` was specified. Implements the canonical Observe → Diff → Act → Report pattern (Phases 0 + 1 are Observe + Diff; this is Act + Report).

### 3.1 Set autonomy = full

Suppress all sub-skill confirmation prompts. Remaining safety overrides (always logged, never silently bypassed): `git push`, rollback to previous sprint state, deleting user files outside sprint scope. All other decisions auto-approved.

### 3.2 Session-conflict pre-check (loop-only soft fail)

If another sprint-plan / sprint-dev / sprint-review session is active (after stale cleanup per session-protocol §5a), do NOT abort — print a defer message and exit:

```
[next --loop] Reconciliation:
  ├─ Active session detected: sprint-dev-a3f7c1b2 (started 5m ago)
  ├─ DECISION: Defer — active session is still working
  └─ Will retry on next /loop tick
```

### 3.3 Dirty-tree pre-check (loop-only soft fail)

`git status --porcelain` — if non-empty, warn but do NOT stop. Uncommitted changes from the operator should not block reconciliation, but the loop reports them so the user can intervene if intentional.

### 3.4 Dispatch the recommended phase

Map the matched row to a Skill tool invocation. Pass `--mode autonomous` to any sprint-dev dispatch.

```
# Example dispatches per row
Row 0:  Skill({ skill: "blitz:roadmap", args: "extend" })
Row 1:  Skill({ skill: "blitz:implement", args: "--resume" })
Row 1a: # NO dispatch — print HARD_SPEC escalation banner + exit LOOP_ESCALATE
        # (banner content: blocked story id, block_reason, last 3 hypotheses)
Row 2:  Skill({ skill: "blitz:implement", args: "--sprint N" })
Row 3:  Skill({ skill: "blitz:review", args: "--sprint N" })
Row 4:  Skill({ skill: "blitz:ship" })
Row 5:  Skill({ skill: "blitz:implement", args: "--sprint N --mode autonomous" })
Row 6b: Skill({ skill: "blitz:sprint-plan" })   # honors planning-inputs.json
Row 6c: Skill({ skill: "blitz:sprint-plan" })
Row 6d: Skill({ skill: "blitz:sprint-plan" })   # re-selects parent epics
```

**Do NOT dispatch `/blitz:sprint --loop` from here.** That would recurse — sprint --loop is itself an alias for this skill since v1.13.0. Always dispatch the specific phase skill.

### 3.5 Commit + push the dispatched phase's output

Each tick runs in a fresh context; the next tick cannot see uncommitted work.

```bash
git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "feat(loop): next reconciliation tick — <row N: phase name>" || true
  git push origin HEAD || true
fi
```

### 3.6 Self-schedule next tick (if not /loop-managed)

```bash
if [ "${CLAUDE_CODE_LOOP_MANAGED:-0}" != "1" ]; then
  # User invoked /blitz:next --loop directly (no external /loop wrapper)
  # Schedule the next tick so the loop survives idle periods
  : # invoke ScheduleWakeup tool here per Flag Parsing §
fi
```

### 3.7 Exit immediately

Do NOT continue to another phase in the same tick. Single-tick semantics is load-bearing for state recovery between fresh-context invocations.

---

## Phase 4: REPORT (--loop only)

Print a concise reconciliation report. Examples:

**Dispatching a phase (rows 0-5, 6b-6d):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: in-progress (8/12 stories, STATE.md checkpoint exists)
  ├─ Carry-forward: 0 active, 0 escalated, 0 pending inputs
  ├─ DECISION: Resume implementation from checkpoint (row 1)
  │  Reason: STATE.md found with 4 remaining stories
  ├─ Dispatching: /blitz:implement --resume
  ├─ Commit: feat(loop): next reconciliation tick — row 1: resume sprint-dev
  └─ Next /loop tick will re-evaluate after completion
```

**Idle (row 7):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ Carry-forward: 0 active, 0 partial, 0 pending inputs
  ├─ All epics: done or blocked
  ├─ DECISION: Nothing to do (row 7) — LOOP_DONE
  └─ Idle — waiting for new epics or roadmap changes
```

**Carry-forward gap closure (row 6d):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ All epics: done in epic-registry.json
  ├─ Carry-forward: 2 active, 1 partial (NOT idle)
  │    - cf-2026-04-02-modal-consistency: partial, coverage 0.646
  │    - cf-2026-04-05-api-error-handling: active, coverage 0.0
  │    - cf-2026-04-07-auth-rate-limits: partial, coverage 0.33
  ├─ DECISION: Plan gap-closure sprint (row 6d)
  ├─ Dispatching: /blitz:sprint-plan
  └─ Next /loop tick will re-evaluate after planning
```

**Escalation (row 6a):**
```
[next --loop] Reconciliation:
  ├─ Sprint 3: reviewed (quality: CONDITIONAL)
  ├─ Carry-forward: 1 escalation (rollover_count >= 3)
  │    - cf-2026-04-02-modal-consistency: rollover_count=3
  │      Parent: CAP-133 / EPIC-105
  │      Last touched: sprint-197 (3 sprints ago)
  ├─ DECISION: Escalate to human review (row 6a) — LOOP_ESCALATE
  │    Loop cannot auto-advance while this entry is stuck. Resolve via:
  │      a) /blitz:sprint-plan with explicit split targeting this entry
  │      b) Append `deferred` event to .cc-sessions/carry-forward.jsonl
  │         with revisit date in notes
  │      c) Append `dropped` event with drop_reason + revival_candidate
  └─ Exiting — /loop will re-escalate on next tick until resolved
```

### Stop signals for /loop wrappers

The reconciliation banner emits one of these markers per tick:
- `LOOP_DONE` (row 7 idle) — external `/loop` wrappers MAY halt
- `LOOP_ESCALATE` (row 6a) — external `/loop` wrappers SHOULD halt (re-firing only re-prints the escalation)
- `LOOP_DEFER` (active session conflict — §3.2) — keep ticking; next tick may find the conflict resolved
- (no marker) — phase dispatched; next tick should re-evaluate state
