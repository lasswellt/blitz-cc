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
5. **NEVER auto-apply a proposal that authors or edits a SKILL.md (skill-authoring).** Such proposals are propose-only / human-curated regardless of apparent safety class. Rationale: SkillsBench (arXiv:2602.12670) measured Claude-self-generated skills at zero average benefit — the +16.2pp accuracy gain comes only from human-curated skills, so the model cannot reliably author the procedural knowledge it benefits from consuming. Surface skill-authoring proposals to the user; do not self-apply.
6. **Minimum 3 completed sessions required before running retrospective.** Insufficient data leads to bad conclusions.
7. **NEVER modify session data.** Session files are read-only input. Never edit, delete, or rewrite session JSONs or operation logs.
8. **NEVER leave placeholder code behind.** Any applied changes must be complete and functional. See [Definition of Done](/_shared/sprint-contracts.md).

---

## Phase 0: COLLECT — Gather Session History

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Check Minimum Sessions

Count completed work signals from two sources: session JSON files (`.cc-sessions/*.json` with `status: completed`) AND `task_complete` events in the activity feed within the last 30 days.

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

If signal ≥ 3, proceed. If signal is primarily feed events (not session JSONs), note it in the report — feed-derived patterns lack duration/lock-conflict metadata.

### 0.2 Gather Data Sources

| Source | Path | What It Contains |
|--------|------|-----------------|
| Session JSONs | `.cc-sessions/*.json` | Session metadata, skill, status, duration |
| Operation logs | `.cc-sessions/operations.log` | Lock operations, conflicts, state transitions |
| Review reports | `**/review-findings.md`, `**/review-report.md` | Quality gate results |
| Git history | `git log` | Commits, reverts, fixups |
| Quality metrics | `docs/metrics/*.json` | Trend data (if available) |
| Audit reports | `docs/audits/*.md` | Codebase health over time |

```bash
ls -la .cc-sessions/*.json 2>/dev/null | wc -l
wc -l .cc-sessions/operations.log 2>/dev/null || echo "No operations log"
find . -name "review-findings.md" -o -name "review-report.md" 2>/dev/null | grep -v node_modules | head -20
git log --oneline -50
ls docs/metrics/*.json 2>/dev/null || echo "No metrics files"
```

### 0.3 Parse Session Data

For each completed session JSON extract: `session_id`, `skill`, `started`/`ended`, `status`, `working_on`. Build an in-memory dataset for analysis.

---

## Phase 1: IDENTIFY PATTERNS — Analyze History

### 1.1 Failure Analysis

**Failed sessions:**
```bash
find .cc-sessions -maxdepth 1 -name "*.json" -exec grep -l '"status": "failed"' {} \; 2>/dev/null
```

**Revert commits:**
```bash
git log --oneline --all | grep -i "revert" | head -20
```

**Fixup commits** (rushed implementation signal):
```bash
git log --oneline --all | grep -iE "fix\(|fixup|fix:" | head -20
```

**Recurring critical findings:**
```bash
grep -r "Critical" --include="*review*" --include="*findings*" -l . 2>/dev/null | grep -v node_modules | head -10
```

### 1.2 Efficiency Analysis

**Lock conflicts:**
```bash
grep '"conflict_detected"' .cc-sessions/operations.log 2>/dev/null | wc -l
```

**Redundant work** (same files modified repeatedly):
```bash
git log --oneline --name-only -30 | sort | uniq -c | sort -rn | head -20
```

Compare session durations per skill. Outliers suggest excessive research loops, repeated verification failures, or tool issues.

### 1.3 Quality Analysis

**Recurring lint/type failures:**
```bash
grep -r "FAIL" --include="*review*" --include="*findings*" . 2>/dev/null | grep -v node_modules | head -10
```

**Completeness gate reports:**
```bash
find . -name "*completeness*" -not -path "*/node_modules/*" -not -path "*/.git/*" | head -10
```

If metrics files exist, compare coverage percentages over time.

### 1.4 Coverage Analysis

**Untested directories:**
```bash
find . -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -path "*/node_modules/*" -not -path "*/.git/*" | sed 's|/[^/]*$||' | sort -u > /tmp/src-dirs.txt
find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | sed 's|/[^/]*$||' | sort -u > /tmp/test-dirs.txt
comm -23 /tmp/src-dirs.txt /tmp/test-dirs.txt | head -20
```

Cross-reference all available skills with session history — identify unused skills and consistently skipped agent types.

---

## Phase 2: GENERATE PROPOSALS — Categorized by Risk

### 2.1 Classify Each Proposal

Every proposal MUST be classified into exactly one category (rules from `references/main.md`):

| Classification | Auto-Apply? | Examples |
|---------------|-------------|---------|
| **safe** | Yes | Adding a grep pattern to references/main.md, updating a template, adding a codemod to the registry, fixing a typo in a skill, adding a routing row to ask skill |
| **review** | No — needs user confirmation | Modifying a skill's phase structure, changing verification gates, updating agent instructions, adding new safety rules, changing model assignments |
| **never-auto-apply** | Never | Removing safety rules, reducing verification checks, changing session protocol, modifying lock behavior, altering conflict matrix |

### 2.2 Generate Proposals from Patterns

- **Failure patterns:** recurring phase failures → pre-check or error recovery; missing codemods → codemod registry; repeated review findings → relevant checklist
- **Efficiency patterns:** frequent lock conflicts → conflict matrix docs; repeated research queries → cache or references/main.md; long sessions → better entry-point guidance
- **Quality patterns:** untested file patterns → test-gen targets; recurring lint failures → pre-flight lint checks in relevant skills; declining completeness scores → tighten verification gates (classified "review")
- **Coverage patterns:** unused skills → better routing in ask skill; untested dirs → test-gen targets

### 2.3 Write Proposals

```bash
mkdir -p docs/retrospective
```

Output style: terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Field values use fragments; field **labels** preserved verbatim (downstream parsers grep them). **LITE intensity** required for Classification rationale on "Never Auto-Apply" proposals.

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

---

## Never Auto-Apply

### Proposal N1: <title>
- **Pattern observed**: <what was seen>
- **Proposed change**: <what a human might consider>
- **Why never auto-apply**: <specific safety concern>
- **Recommendation**: <what the user should evaluate>
```

---

## Phase 2.5: UPDATE DEVELOPER PROFILE

Derive profile dimensions (verbosity, autonomy, commit_style, pr_size, review_tolerance, framework_focus, common_skills, peak_hours) from session patterns. Write/merge `.cc-sessions/developer-profile.json`. Profile is informational only — MUST NOT override explicit user instructions or change safety rules. Confidence: <5 sessions `low`, 5-15 `medium`, 15+ `high`.

Full derivation table, JSON payload, update rules, change-report format: [references/main.md](references/main.md#developer-profile-derivation).

---

## Phase 3: APPLY SAFE IMPROVEMENTS

### 3.1 Apply Each Safe Proposal

1. **Read the target file** to confirm it exists and the edit location is valid.
2. **Make the change** using the Edit tool.
3. **Validate plugin structure:**
   ```bash
   ./scripts/validate-plugin-structure.sh 2>&1
   ```
4. **If validation passes:** mark proposal "APPLIED" in the proposals document.
5. **If validation fails:** revert the change, reclassify as "review", note the validation error.

### 3.2 Commit Applied Changes

```bash
git add <changed-files> docs/retrospective/
git commit -m "improve: apply retrospective proposals — $(date +%Y-%m-%d)"
```

### 3.3 Handle Validation Failures

If `validate-plugin-structure.sh` does not exist: skip post-apply validation, warn user, reclassify all remaining "safe" proposals as "review".

---

## Phase 4: REPORT

### 4.1 Summary

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

If "review" proposals exist, list them:

```
Proposals Requiring Your Review:
  R1: <title> — <one-line summary>
  R2: <title> — <one-line summary>

To review: read docs/retrospective/YYYY-MM-DD-proposals.md
```

### 4.3 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`.
2. Release any held locks.
3. Append `session_end` to the operation log.

---

## Error Recovery

- **No session files:** Abort — "No session data found in `.cc-sessions/`. Run at least 3 skills with session registration before running retrospective."
- **Operations log corrupted/missing:** Skip efficiency analysis (lock conflicts, timing). Use git log and session JSONs only. Note gap in report.
- **validate-plugin-structure.sh missing:** Skip post-apply validation. Warn user. Reclassify remaining safe proposals as review.
- **Safe proposal breaks validation:** Revert immediately via `git checkout -- <file>`. Reclassify as "review" with validation error noted.
- **Git state dirty before starting:** Warn user. Suggest committing or stashing. Proceed with read-only phases; skip Phase 3 to avoid mixing changes.
- **All sessions used same skill:** Warn that findings may be biased toward that skill's patterns.
- **Session JSON malformed:** Skip that session. Log warning. Do not abort entire analysis.
