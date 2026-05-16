---
name: retrospective
description: "Analyzes completed sessions to identify improvement patterns. Reads activity-feed entries, session reports, and git diff to surface recurring friction. Generates proposals for plugin self-improvement classified by safety (auto-apply, propose-only, never-auto-apply). Use when the user says 'retrospective', 'what did we learn', 'session analysis', 'improve the plugin', 'find friction patterns'."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "(no arguments — runs analysis automatically)"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For pattern taxonomy, proposal templates, and safety classification rules, see [references/main.md](references/main.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Self-Improvement Retrospective

Analyze completed development sessions for patterns of failure, inefficiency, and success. Generate improvement proposals; auto-apply safe ones. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER apply proposals classified as "review" or "never-auto-apply" without user confirmation.** Only "safe" proposals can be auto-applied.

2. **NEVER modify skills in ways that remove safety rules.** Safety rules are sacrosanct. No proposal may weaken, delete, or circumvent them.

3. **NEVER reduce the number of verification gates in any skill.** Verification gates exist to catch regressions. Removing them is always unsafe.

4. **ALWAYS validate plugin structure after applying changes.** Run `./scripts/validate-plugin-structure.sh` after every applied proposal.

5. **Minimum 3 completed sessions required before running retrospective.** Insufficient data leads to bad conclusions.

6. **NEVER modify session data.** Session files are read-only input. Never edit, delete, or rewrite session JSONs or operation logs.

7. **NEVER leave placeholder code behind.** Any applied changes must be complete and functional. See [Definition of Done](/_shared/definition-of-done.md).

---

## Phase 0: COLLECT — Gather Session History

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Check Minimum Sessions

Count completed work signals from two sources: session JSON files (`.cc-sessions/*.json` with `status: completed`) AND `task_complete` events in the activity feed within the last 30 days. Projects that log via the activity-feed but don't register full session JSONs are valid retrospective input.

```bash
# Signal 1: completed session JSONs
COMPLETED_JSONS=$(find .cc-sessions -maxdepth 1 -name "*.json" -exec grep -l '"status": "completed"' {} \; 2>/dev/null | wc -l)

# Signal 2: task_complete events in activity-feed within the last 30 days
CUTOFF_DATE=$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d 2>/dev/null)
COMPLETED_EVENTS=0
if [ -f ".cc-sessions/activity-feed.jsonl" ] && [ -n "$CUTOFF_DATE" ]; then
  COMPLETED_EVENTS=$(awk -v cutoff="$CUTOFF_DATE" '
    /"event"[[:space:]]*:[[:space:]]*"task_complete"/ {
      if (match($0, /"ts"[[:space:]]*:[[:space:]]*"([^"]+)"/, t) && t[1] >= cutoff) print
    }' .cc-sessions/activity-feed.jsonl | wc -l)
fi

TOTAL_SIGNAL=$((COMPLETED_JSONS + COMPLETED_EVENTS))
echo "Session JSONs: ${COMPLETED_JSONS}  |  Activity-feed task_completes (30d): ${COMPLETED_EVENTS}  |  Total signal: ${TOTAL_SIGNAL}"

if [ "$TOTAL_SIGNAL" -lt 3 ]; then
  echo "ABORT: Insufficient data — need at least 3 combined signals (session JSONs + activity-feed task_complete events). Found ${TOTAL_SIGNAL}."
  exit 1
fi
```

If the combined signal is ≥ 3, proceed. If the signal is primarily activity-feed events (not session JSONs), note this in the analysis report — patterns derived from feed events have less structured metadata (no duration, no lock conflicts) than full session JSONs.

### 0.2 Gather Data Sources

Collect all available data for analysis:

| Source | Path | What It Contains |
|--------|------|-----------------|
| Session JSONs | `.cc-sessions/*.json` | Session metadata, skill, status, duration |
| Operation logs | `.cc-sessions/operations.log` | Lock operations, conflicts, state transitions |
| Review reports | `**/review-findings.md`, `**/review-report.md` | Quality gate results |
| Git history | `git log` | Commits, reverts, fixups |
| Quality metrics | `docs/metrics/*.json` | Trend data (if available) |
| Audit reports | `docs/audits/*.md` | Codebase health over time |

```bash
# Session data
ls -la .cc-sessions/*.json 2>/dev/null | wc -l

# Operation log
wc -l .cc-sessions/operations.log 2>/dev/null || echo "No operations log"

# Review reports
find . -name "review-findings.md" -o -name "review-report.md" 2>/dev/null | grep -v node_modules | head -20

# Recent git history
git log --oneline -50

# Quality metrics
ls docs/metrics/*.json 2>/dev/null || echo "No metrics files"
```

### 0.3 Parse Session Data

For each completed session JSON, extract:
- `session_id`: Unique identifier
- `skill`: Which skill was invoked
- `started` / `ended`: Timestamps (for duration calculation)
- `status`: Final status (completed, failed)
- `working_on`: What the session was doing

Build an in-memory dataset of sessions for analysis.

---

## Phase 1: IDENTIFY PATTERNS — Analyze History

### 1.1 Failure Analysis

Look for recurring failure patterns:

**Failed Sessions**
```bash
find .cc-sessions -maxdepth 1 -name "*.json" -exec grep -l '"status": "failed"' {} \; 2>/dev/null
```
For each failed session: which skill failed? What was it working on? Is there a pattern?

**Revert Commits**
```bash
git log --oneline --all | grep -i "revert" | head -20
```
What was reverted and why? Are certain skills producing code that gets reverted more often?

**Fixup Commits**
```bash
git log --oneline --all | grep -iE "fix\(|fixup|fix:" | head -20
```
Fixup commits shortly after feature commits suggest rushed implementation.

**Recurring Critical Findings**
Search review reports for repeated critical-severity findings:
```bash
grep -r "Critical" --include="*review*" --include="*findings*" -l . 2>/dev/null | grep -v node_modules | head -10
```

### 1.2 Efficiency Analysis

Look for wasted effort:

**Lock Conflicts**
```bash
grep '"conflict_detected"' .cc-sessions/operations.log 2>/dev/null | wc -l
```
Which skills compete for the same locks? Could the conflict matrix be improved?

**Long Sessions**
Compare session durations. Sessions significantly longer than average for the same skill suggest problems:
- Excessive research loops
- Repeated verification failures
- Tool availability issues

**Redundant Work**
Check if the same files are modified by multiple sessions in sequence (suggesting rework):
```bash
git log --oneline --name-only -30 | sort | uniq -c | sort -rn | head -20
```

### 1.3 Quality Analysis

Look for declining quality indicators:

**Recurring Lint/Type Failures**
```bash
grep -r "FAIL" --include="*review*" --include="*findings*" . 2>/dev/null | grep -v node_modules | head -10
```

**Test Coverage Trends**
If metrics files exist, compare coverage percentages over time.

**Completeness Gate Scores**
Search for completeness gate reports and track scores:
```bash
find . -name "*completeness*" -not -path "*/node_modules/*" -not -path "*/.git/*" | head -10
```

### 1.4 Coverage Analysis

Look for blind spots:

**Untested Directories**
```bash
# Find source directories with no corresponding test files
find . -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -path "*/node_modules/*" -not -path "*/.git/*" | sed 's|/[^/]*$||' | sort -u > /tmp/src-dirs.txt
find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | sed 's|/[^/]*$||' | sort -u > /tmp/test-dirs.txt
comm -23 /tmp/src-dirs.txt /tmp/test-dirs.txt | head -20
```

**Unused Skills**
Cross-reference all available skills with session history. Which skills are never invoked?

**Never-Spawned Agent Types**
Check if certain agent types in multi-agent skills are consistently skipped.

---

## Phase 2: GENERATE PROPOSALS — Categorized by Risk

### 2.1 Classify Each Proposal

Every proposal MUST be classified into exactly one category using the rules from `references/main.md`:

| Classification | Auto-Apply? | Examples |
|---------------|-------------|---------|
| **safe** | Yes | Adding a grep pattern to references/main.md, updating a template, adding a codemod to the registry, fixing a typo in a skill, adding a routing row to ask skill |
| **review** | No — needs user confirmation | Modifying a skill's phase structure, changing verification gates, updating agent instructions, adding new safety rules, changing model assignments |
| **never-auto-apply** | Never | Removing safety rules, reducing verification checks, changing session protocol, modifying lock behavior, altering conflict matrix |

### 2.2 Generate Proposals from Patterns

For each pattern identified in Phase 1, generate a concrete proposal:

**From Failure Patterns:**
- If a skill consistently fails at a specific phase → propose adding a pre-check or better error recovery
- If codemods are missing for common migrations → propose adding them to the codemod registry
- If review findings repeat → propose adding the pattern to the relevant checklist

**From Efficiency Patterns:**
- If lock conflicts are frequent → propose expanding the conflict matrix documentation
- If research queries repeat → propose caching results or adding to references/main.md
- If sessions are longer than expected → propose better entry-point guidance

**From Quality Patterns:**
- If certain file patterns are never tested → propose adding them to the test-gen target list
- If lint failures recur → propose adding pre-flight lint checks to relevant skills
- If completeness scores decline → propose tightening verification gates (classified as "review")

**From Coverage Patterns:**
- If skills are unused → propose better routing in the ask skill
- If directories are untested → propose test-gen targets

### 2.3 Write Proposals

Create the proposals document:

```bash
mkdir -p docs/retrospective
```

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Each proposal's field values (Pattern observed, Proposed change, Expected impact) use fragments, not full sentences. Field **labels** preserved verbatim (downstream parsers grep them). Preserve verbatim: file paths, grep patterns, session IDs, frontmatter. **LITE intensity** required for Classification rationale on "Never Auto-Apply" proposals — operator accepts/rejects based on reasoning chain; compression must not lose the why.

Write to `docs/retrospective/YYYY-MM-DD-proposals.md`:

```markdown
# Retrospective Proposals — YYYY-MM-DD

Based on N completed sessions analyzed.
Analysis period: <earliest-session-date> to <latest-session-date>

---

## Safe (auto-applicable)

### Proposal S1: <title>
- **Pattern observed**: <what was seen in the data>
- **Sessions affected**: <session-ids or count>
- **Proposed change**: <specific edit with file path>
- **Expected impact**: <what will improve>
- **File**: <path to file being changed>
- **Classification rationale**: <why this is safe>

### Proposal S2: <title>
...

---

## Review Required

### Proposal R1: <title>
- **Pattern observed**: <what was seen>
- **Sessions affected**: <session-ids or count>
- **Proposed change**: <specific edit>
- **Expected impact**: <what will improve>
- **File**: <path>
- **Classification rationale**: <why this needs review>
- **Risk if applied incorrectly**: <what could go wrong>

### Proposal R2: <title>
...

---

## Never Auto-Apply

### Proposal N1: <title>
- **Pattern observed**: <what was seen>
- **Proposed change**: <what a human might consider>
- **Why never auto-apply**: <specific safety concern>
- **Recommendation**: <what the user should evaluate>

### Proposal N2: <title>
...
```

---

## Phase 2.5: UPDATE DEVELOPER PROFILE

Generate or update a developer profile from the session history analyzed in Phase 1. This profile helps other skills adapt their behavior to the user's preferences.

### 2.5.1 Analyze Session Patterns

From the session data collected in Phase 0 and patterns from Phase 1, derive:

| Dimension | How to Derive | Values |
|---|---|---|
| **verbosity** | Did the user request more/less output? Did they skip clarification phases? | `concise` / `standard` / `detailed` |
| **autonomy** | How often did sessions complete without user intervention? Did the user confirm plans or say "just do it"? | `low` / `medium` / `high` |
| **commit_style** | How are commits structured in git log? Per-story, per-phase, or manual? | `atomic` / `batched` / `manual` |
| **pr_size** | Average lines changed per session or sprint | `small` (<200) / `medium` / `large` (>800) |
| **review_tolerance** | How did the user respond to review findings? Fixed all, or dismissed low-severity? | `lenient` / `standard` / `strict` |
| **framework_focus** | Which frameworks appear most in modified files? | e.g., `vue-nuxt`, `react`, `node` |
| **common_skills** | Top 3 most-invoked skills | e.g., `["fix-issue", "sprint-dev", "refactor"]` |
| **peak_hours** | When do sessions typically occur? | e.g., `"09:00-17:00"` |

### 2.5.2 Write Developer Profile

Write (or update) `.cc-sessions/developer-profile.json`:

```json
{
  "updated": "<ISO-8601>",
  "sessions_analyzed": <count>,
  "preferences": {
    "verbosity": "standard",
    "autonomy": "high",
    "commit_style": "atomic",
    "pr_size": "medium",
    "review_tolerance": "standard",
    "framework_focus": "vue-nuxt",
    "common_skills": ["fix-issue", "sprint-dev", "refactor"],
    "peak_hours": "09:00-17:00"
  },
  "patterns": {
    "avg_session_duration_minutes": 45,
    "most_common_first_action": "fix-issue",
    "typical_sprint_size": 12,
    "auto_fix_acceptance_rate": 0.85
  }
}
```

### 2.5.3 Profile Update Rules

- **First run**: Create the profile from scratch based on available data.
- **Subsequent runs**: Merge new data with existing profile. Weight recent sessions (last 30 days) more heavily than older ones.
- **Insufficient data**: If fewer than 5 sessions exist, mark the profile as `"confidence": "low"`. If 5-15, mark as `"medium"`. If 15+, mark as `"high"`.
- **Safety**: The profile is informational only. It MUST NOT override explicit user instructions. It SHOULD NOT change safety rules.

### 2.5.4 Report Profile Changes

If the profile was updated, note the changes:

```
[retrospective] Developer Profile updated:
  ├─ verbosity: standard → detailed (user requested more output in recent sessions)
  ├─ autonomy: medium → high (3 recent sessions completed without intervention)
  └─ common_skills: added "ui-build" (invoked 4 times in analysis period)
```

---

## Phase 3: APPLY SAFE IMPROVEMENTS

### 3.1 Apply Each Safe Proposal

For each proposal classified as "safe":

1. **Read the target file** to confirm it exists and the edit location is valid.
2. **Make the change** using the Edit tool.
3. **Validate plugin structure**:
   ```bash
   ./scripts/validate-plugin-structure.sh 2>&1
   ```
4. **If validation passes**: mark the proposal as "APPLIED" in the proposals document.
5. **If validation fails**: revert the change, reclassify the proposal as "review", and note the validation error.

### 3.2 Commit Applied Changes

After all safe proposals are applied and validated:

```bash
git add <changed-files> docs/retrospective/
git commit -m "improve: apply retrospective proposals — $(date +%Y-%m-%d)"
```

### 3.3 Handle Validation Failures

If `validate-plugin-structure.sh` does not exist:
- Skip post-apply validation.
- Warn the user that structural validation was not possible.
- Reclassify all remaining "safe" proposals as "review" out of caution.

---

## Phase 4: REPORT

### 4.1 Summary

Output a summary to the user:

```
Retrospective Analysis Complete
================================
Sessions analyzed: N (N completed, N failed)
Analysis period: YYYY-MM-DD to YYYY-MM-DD

Patterns Identified:
  Failure patterns:    N
  Efficiency patterns: N
  Quality patterns:    N
  Coverage patterns:   N

Proposals Generated: N total
  Safe (auto-applicable):  N
  Review required:         N
  Never auto-apply:        N

Safe Proposals Applied: N/M
  Applied successfully: N
  Reclassified to review: N (validation failures)

Key Findings:
  1. <most important finding>
  2. <second most important finding>
  3. <third most important finding>

Proposals document: docs/retrospective/YYYY-MM-DD-proposals.md
```

### 4.2 Highlight Review-Required Proposals

If there are "review" proposals, list them prominently:

```
Proposals Requiring Your Review:
  R1: <title> — <one-line summary>
  R2: <title> — <one-line summary>
  ...

To review: read docs/retrospective/YYYY-MM-DD-proposals.md
```

### 4.3 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`.
2. Release any held locks.
3. Append `session_end` to the operation log.

---

## Error Recovery

- **No session files exist**: Abort with message: "No session data found in `.cc-sessions/`. Run at least 3 skills with session registration before running retrospective."
- **Operations log is corrupted or missing**: Skip efficiency analysis (lock conflicts, timing). Use git log and session JSONs only. Note the gap in the report.
- **validate-plugin-structure.sh does not exist**: Skip post-apply validation. Warn user. Reclassify remaining safe proposals as review.
- **A safe proposal application breaks validation**: Revert the change immediately using `git checkout -- <file>`. Reclassify as "review" with the validation error noted.
- **Git state is dirty before starting**: Warn user. Suggest committing or stashing first. Proceed with analysis (read-only phases) but skip Phase 3 (apply) to avoid mixing changes.
- **Insufficient session diversity**: If all sessions used the same skill, warn that findings may be biased toward that skill's patterns.
- **Session JSON is malformed**: Skip that session. Log a warning. Do not abort the entire analysis for one bad file.
