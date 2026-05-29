---
name: ship
description: "Chains the full release workflow (sprint-review → review --only completeness → quality-metrics → release) with quality gates between each step. Use when the user says 'ship it', 'cut a release', 'release v1.X', or 'ready to ship'. Refuses to publish if any gate fails."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: low
compatibility: ">=2.1.71"
argument-hint: "[version] -- full release chain: review → review --only completeness → quality-metrics → release → notify; pass explicit version (e.g. 1.2.0) or omit to auto-bump from CHANGELOG"
disable-model-invocation: true
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Ship Workflow

You are the shipping orchestrator. You chain quality gates and release preparation into a single, safe workflow. Each step must pass before proceeding to the next. Execute every phase in order. Do NOT skip phases.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[ship]` prefixed status lines at every phase transition, gate result, and dispatch. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

**Pipeline artifacts.** Ship consumes the upstream sprint chain — see [/_shared/state-handoff.md](/_shared/state-handoff.md) for the producer/consumer matrix (`STATE.md`, `carry-forward.jsonl`, `review-report.md`). A clean ship requires the most recent sprint to be in a `complete` state per the handoff contract.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER push to remote without explicit user confirmation.** All push operations require a "Proceed? [y/n]" prompt.

2. **NEVER skip quality gates.** If any gate fails, STOP. Do not proceed to subsequent phases.

3. **NEVER proceed to release if completeness score is below C (70).** The completeness gate must pass before release preparation begins.

4. **NEVER auto-merge.** Always create a PR or ask user to confirm merge explicitly.

5. **NEVER leave placeholder code behind.** All release artifacts must be fully formed. See [Definition of Done](/_shared/definition-of-done.md).

---

## Phase 0: PARSE — Determine Version

### 0.0 Parse Version Argument

Extract from `$ARGUMENTS`:
- If user provides a version (e.g., `ship 2.0.0`), use it as the explicit version.
- If no version is provided, version will be calculated from conventional commits by the release skill.

### 0.1 Pre-Flight Check

Before starting the chain, verify all prerequisites:

```bash
# 1. Working tree is clean
git status --porcelain

# 2. On a feature branch (not main/master)
BRANCH=$(git branch --show-current)
echo "Current branch: $BRANCH"

# 3. Dependencies installed
[ -d "node_modules" ] && echo "DEPS: installed" || echo "DEPS: missing"

# 4. Upstream sprint-review artifact (state-handoff.md contract)
if [ -s "sprint-registry.json" ]; then
  SPRINT_NUMBER="${SPRINT_NUMBER:-$(jq -r '.current_sprint // empty' sprint-registry.json 2>/dev/null)}"
  SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
  [ -s "${SPRINT_DIR}/review-report.md" ] || {
    echo "BLOCK: ship requires ${SPRINT_DIR}/review-report.md. Run /blitz:sprint-review first." >&2
    exit 1
  }
fi
```

| Check | Condition | Action |
|-------|-----------|--------|
| Clean tree | `git status --porcelain` is empty | Proceed |
| Clean tree | Uncommitted changes exist | STOP — ask user to commit or stash |
| Branch | On `main` or `master` | STOP — ship must run from a feature branch |
| Branch | On any other branch | Proceed |
| Dependencies | `node_modules` exists | Proceed |
| Dependencies | `node_modules` missing | STOP — ask user to install dependencies |
| Review report | `${SPRINT_DIR}/review-report.md` present when sprint context exists | Proceed |
| Review report | Missing when sprint context exists | STOP — invoke `/blitz:sprint-review` first |

If any pre-flight check fails, report the issue and abort.

---

## Phase 1: QUALITY GATES — Run All Checks

### 1.1 Sprint Review (if sprint context exists)

Check for an active sprint:
```bash
[ -f "sprint-registry.json" ] && cat sprint-registry.json | head -20 || echo "NO SPRINT REGISTRY"
```

If a sprint registry exists with an in-progress sprint, dispatch to sprint-review:
```
Invoke: /blitz:sprint-review
```

Wait for completion.
- If review status is PASS or no critical findings: proceed.
- If review status is FAIL with critical findings: STOP and report.
- If no sprint registry exists: mark as SKIPPED.

### 1.2 Completeness Gate

Dispatch the completeness scan (consolidated front-door; completeness-gate folded into review Phase 1.5):
```
Invoke: /blitz:review --only completeness
```
The ≥C/70 release cutoff remains owned by ship (reads the completeness grade).

Wait for completion. Read the output:
- Score >= 70 (C grade or higher): PASS, proceed.
- Score < 70: FAIL, show top violations, STOP.

### 1.3 Quality Metrics Collection

Dispatch to quality-metrics:
```
Invoke: /blitz:quality-metrics collect
```

Wait for completion. This stores a snapshot for trend analysis.

### 1.4 Gate Summary

Print the combined gate results:

```
Ship Pre-flight:
  Sprint Review:     PASS/FAIL/SKIPPED
  Completeness Gate: PASS/FAIL (score/100)
  Quality Metrics:   Collected (overall: N/100)

  All gates passed. Proceeding to release preparation.
```

If any required gate failed, STOP here. Do not proceed to Phase 2.

---

## Phase 2: CHANGELOG — Generate Changelog

### 2.1 Parse Conventional Commits

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  git log ${LAST_TAG}..HEAD --pretty=format:"%s"
else
  git log --pretty=format:"%s"
fi
```

**Delegate to release (O5).** The commit-type → changelog-section map + Keep a Changelog emit are owned by [`skills/release`](../release/SKILL.md) §changelog. ship does NOT restate the map — it invokes release `prepare` (the final step of the ship chain) which generates the changelog. The parse above is only to preview/auto-bump the version; the authoritative changelog is produced by release.

### 2.2 Update CHANGELOG.md

release `prepare` writes the new version section (Keep a Changelog format) — ship does not hand-edit CHANGELOG.md.
- release `prepare` owns the emit rules (create-if-missing header, prefix stripping, capitalization, hash-linking, empty-section omission) — see [`skills/release`](../release/SKILL.md) §changelog. ship does not restate or hand-edit these.

---

## Phase 3: RELEASE — Prepare Release

### 3.1 Dispatch to Release Skill

```
Invoke: /blitz:release prepare [version]
```

This handles:
- Version calculation (from commits or explicit version)
- Version bump in `package.json` and related files
- Changelog generation
- Release branch creation

### 3.2 Verify Release

```
Invoke: /blitz:release verify
```

Runs all quality gates on the release branch:
- Type-check
- Lint
- Tests
- Build
- Version consistency

If verification fails, STOP and report which gates failed.

### 3.3 Confirm with User

```
Ship Ready:
  Version: vX.Y.Z
  Changelog: N new entries
  Quality gates: ALL PASS

  Ready to publish? This will:
    1. Create tag vX.Y.Z
    2. Push release branch to remote
    3. Create GitHub release

  Proceed? [y/n]
```

Wait for explicit user confirmation. If declined, preserve the release branch for later.

### 3.4 Publish (if confirmed)

```
Invoke: /blitz:release publish
```

This handles:
- Tag creation
- Push to remote
- GitHub release creation
- Merge back to main

---

## Phase 4: REPORT

### 4.1 Output Summary

```
Ship Complete: vX.Y.Z
  Quality gates: ALL PASS
  Completeness: N/100
  Changelog entries: N
  Tag: vX.Y.Z
  Release: https://github.com/...

  Included changes:
    - N features
    - N fixes
    - N other changes
```

### 4.2 Push Completion Notification

After printing the summary, send a mobile push notification:

```
PushNotification(
  title: "Shipped vX.Y.Z ✓",
  message: "<N features> · <N fixes> · release at <release-url>",
  url: "<release-url>"
)
```

No-op if Remote Control is not configured.

---

## Error Recovery

- **Sprint-review fails**: Show findings and suggest fixing issues before retrying ship. The release branch is not created yet, so no cleanup is needed.
- **Completeness gate fails**: Show the top violations sorted by severity. Suggest fixing critical and high-severity items before retrying.
- **Release prepare fails**: Clean up the release branch if one was created. Report the error with context.
- **Release verify fails**: The release branch exists but is not tagged. Report which gates failed. User can fix issues on the release branch and re-run `release verify`.
- **Publish fails**: Release branch and tag are still valid locally. Suggest manual publish via `gh release create` or re-running `release publish`.
- **User cancels at confirmation**: Clean state, release branch is preserved. User can resume later with `release publish`.
- **Working tree not clean**: List uncommitted files. Suggest committing or stashing before retrying.
- **On main/master branch**: Suggest creating a feature branch first with `git checkout -b <branch-name>`.
