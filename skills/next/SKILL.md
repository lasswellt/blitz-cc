---
name: next
description: "Reads current project, sprint, and carry-forward state and tells the user what action to take next (run sprint-plan, resume sprint-dev, ship, address a registry escalation, etc.). Use when the user asks 'what should I do next?', 'where are we?', 'is anything blocked?', or just '/blitz:next'. Always cite the specific blitz command to run."
argument-hint: "(no arguments — reads state automatically)"
allowed-tools: Read, Bash, Glob, Grep
model: sonnet
effort: low
compatibility: ">=2.1.71"
---


## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For pipeline artifact contracts (which files indicate which next-action: `STATE.md`, `roadmap/`, `carry-forward.jsonl`, `review-report.md`), see [/_shared/state-handoff.md](/_shared/state-handoff.md)
- For carry-forward registry reads (`CF_ACTIVE`, `CF_ESCALATED`, `UNINGESTED_COUNT`), see [/_shared/carry-forward-registry.md](/_shared/carry-forward-registry.md)

---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Next Action Advisor

Read the current project state and determine the most logical next action. Suggest a concrete command the user can run.

**No session protocol required.** This skill is lightweight and read-only.

**Verbose progress exemption:** This skill intentionally skips verbose output. Freeform activity-feed logging from CLAUDE.md still applies.

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

### 0.7 Check for Uningested Research

```bash
UNINGESTED_COUNT=$(find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null | wc -l | tr -d ' ')
UNINGESTED_COUNT=${UNINGESTED_COUNT:-0}
```

---

## Phase 1: DETERMINE NEXT ACTION

Use this decision tree:

```
1. Is there an in-progress sprint with STATE.md?
   → YES: "Resume sprint N" — /blitz:implement --resume

2. Is there an in-progress sprint WITHOUT STATE.md?
   → YES: "Continue sprint N" — /blitz:implement --sprint N

3. Is there a sprint with status "review"?
   → YES: "Review sprint N" — /blitz:review --sprint N

4. Is there a sprint with status "reviewed" and passing quality?
   → YES: "Ship the sprint" — /blitz:ship

5. Is there a sprint with status "planned" (not yet started)?
   → YES: "Implement sprint N" — /blitz:implement --sprint N

6. Does a roadmap exist with unblocked epics?
   → YES: "Plan the next sprint" — /blitz:sprint-plan

7. Does a roadmap exist but all epics are blocked or done?
   → YES: "Extend the roadmap" — /blitz:roadmap extend

8. No roadmap exists?
   → "Create a roadmap first" — /blitz:roadmap full

8b. Does the carry-forward registry have escalated entries (rollover_count ≥ 3)?
    → YES: "Operator review needed — entries stuck for 3+ sprints"
           Print escalation banner with IDs — /blitz:sprint --gaps

8c. No roadmap, but docs/_research/ has files newer than roadmap-registry.json ($UNINGESTED_COUNT > 0)?
    → YES: "Ingest research and plan" — /blitz:sprint (auto-chains roadmap extend)

8d. No active sprint, roadmap exists, carry-forward registry has active/partial entries ($CF_ACTIVE > 0)?
    → YES: "Close carry-forward gaps" — /blitz:sprint

9. None of the above (no sprints, no roadmap)?
   → "Start with research or bootstrap" — /blitz:ask <describe your goal>
```

### Tie-Breaking

If multiple actions are possible (e.g., a reviewed sprint AND a planned sprint), prioritize:
1. Resume interrupted work (STATE.md exists)
2. Complete in-progress work
3. Ship reviewed work
4. Start planned work
5. Plan new work

---

## Phase 2: SUGGEST

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
