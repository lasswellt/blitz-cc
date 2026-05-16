---
name: release
description: "Manages semantic versioning, changelogs, and GitHub releases. Modes: prepare (compute version + draft CHANGELOG), verify (run all gates), publish (tag + push + npm publish if configured), rollback (revert + delete tag). Use when the user says 'release v1.X', 'cut a release', 'publish release', 'tag and ship', 'rollback release'. Composed by /blitz:ship as the final step."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<mode> [version] -- prepare (bump version + draft CHANGELOG) | verify (validate tag, working tree, registry consistency) | publish (git tag + GitHub release + npm publish if configured) | rollback (revert + delete tag)"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For conventional commit patterns, changelog templates, and rollback procedures, see [references/main.md](references/main.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Release Management

Handle semantic versioning, changelog generation, quality verification, tagging, and GitHub releases. Version calculation follows conventional commits. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER publish a release that fails quality gates.** If any gate in Phase 4 fails, the release MUST NOT proceed to Phase 5.

2. **NEVER force-push tags.** If a tag already exists, suggest incrementing the patch version instead.

3. **NEVER modify published releases.** Create patch releases instead. Published releases are immutable.

4. **NEVER skip the verify step before publish.** Phase 4 (VERIFY) must complete successfully before Phase 5 (PUBLISH) can begin.

5. **Major version bumps ALWAYS require explicit user confirmation.** Do not auto-approve major bumps even if the conventional commits indicate breaking changes.

6. **NEVER push to remote without user confirmation.** All push operations require an explicit "Proceed? [y/n]" prompt.

7. **NEVER delete remote tags without user confirmation.** Rollback of remote tags is destructive and requires explicit consent.

8. **NEVER leave placeholder code behind.** All release artifacts must be fully formed. See [Definition of Done](/_shared/definition-of-done.md).

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode and Version

Extract from `$ARGUMENTS`:

| Mode | Description |
|------|-------------|
| `prepare` (default) | Calculate version, generate changelog, create release branch |
| `verify` | Run all quality gates on current state |
| `publish` | Tag, push, create GitHub release (requires prior prepare + verify) |
| `rollback` | Revert a failed release |

Optional explicit version override: `prepare 2.0.0`

If no mode is provided, default to `prepare`. If mode is `publish`, verify that a release branch exists and verification has passed before proceeding.

---

## Phase 1: CONTEXT — Gather Release State

### 1.1 Current Version

Read version from the project's version source:
```bash
# Check package.json first
node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0"
```

Also check: `lerna.json`, `plugin.json`, `marketplace.json`, `version.txt`.

### 1.2 Latest Tag

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"
```

### 1.3 Registry State

Check if this is a publishable package (`private` field in `package.json`). If `private: true`, this package will not be published to npm — tag and GitHub release only.

### 1.4 Commit History Since Last Tag

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  git log ${LAST_TAG}..HEAD --pretty=format:"%H|%s|%an|%ai"
else
  git log --pretty=format:"%H|%s|%an|%ai"
fi
```

### 1.5 Unreleased Changes Check

If no commits exist since the last tag, inform the user: "No unreleased changes found since the last tag. Nothing to release." and stop.

---

## Phase 2: CALCULATE — Determine Version Bump

### 2.1 Parse Conventional Commits

Categorize commits since last tag using patterns from `references/main.md`:

| Commit Prefix | Bump | Changelog Section |
|---------------|------|-------------------|
| `feat:` or `feat(scope):` | minor | Added |
| `fix:` or `fix(scope):` | patch | Fixed |
| `BREAKING CHANGE:` in body | major | Breaking Changes |
| `!` after type (e.g., `feat!:`) | major | Breaking Changes |
| `refactor:` | none (included in changelog) | Changed |
| `perf:` | none (included in changelog) | Changed |
| `docs:` | none (included in changelog) | Documentation |
| `chore:`, `ci:`, `build:` | none (included in changelog) | Other |
| `style:` | none (excluded from changelog) | — |
| `test:` | none (excluded from changelog) | — |

### 2.2 Calculate New Version

Apply semver rules:
1. If any commit triggers a major bump → increment major, reset minor and patch to 0
2. Else if any commit triggers a minor bump → increment minor, reset patch to 0
3. Else if any commit triggers a patch bump → increment patch
4. If no bump-triggering commits exist (only docs, chore, etc.) → inform user and ask whether to proceed with a patch bump or skip

If an explicit version was provided in Phase 0, validate it:
- Must be valid semver
- Must be greater than current version
- Use it instead of the calculated version

### 2.3 Major Bump Confirmation

If the calculated version is a major bump, STOP and present to the user:

```
Breaking changes detected:
  - <commit hash short> <commit message>
  - <commit hash short> <commit message>

This will bump from X.Y.Z to (X+1).0.0. Proceed? [y/n]
```

Wait for user confirmation. If declined, suggest a minor bump instead.

---

## Phase 3: PREPARE — Create Release Artifacts

### 3.1 Create Release Branch

```bash
git checkout -b release/vX.Y.Z
```

If the branch already exists, inform the user and ask whether to continue on the existing branch or start fresh.

### 3.2 Bump Version

Update version in all relevant files:

1. `package.json` — update `version` field
2. Workspace `package.json` files (if monorepo) — update `version` field
3. `plugin.json` — update `version` field (if exists)
4. `marketplace.json` — update `version` field (if exists)
5. Any other files containing a version string matching the old version (search and confirm with user)

### 3.3 Generate Changelog

Parse commits and generate/update `CHANGELOG.md` following Keep a Changelog format. Use the template from `references/main.md`.

Structure:
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Breaking Changes
- <description> (<hash-short>)

### Added
- <description> (<hash-short>)

### Fixed
- <description> (<hash-short>)

### Changed
- <description> (<hash-short>)

### Documentation
- <description> (<hash-short>)

### Other
- <description> (<hash-short>)
```

Rules:
- Prepend the new version section to the existing CHANGELOG.md (below the header)
- If CHANGELOG.md does not exist, create it with a standard header
- Strip conventional commit prefixes from descriptions (e.g., `feat: add login` becomes `Add login`)
- Capitalize the first word of each description
- Include short commit hash in parentheses, linked to the commit on GitHub if remote is available
- Remove empty sections (e.g., if no breaking changes, omit that section)

### 3.4 Generate Release Notes Excerpt

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Reuse CHANGELOG bullets verbatim — no narrative preamble, no "Thanks for using …" closer, no marketing framing. Preserve verbatim: version numbers, commit hashes, issue/PR numbers, `BREAKING CHANGE:` markers. **LITE intensity** required for breaking-change descriptions (users need the migration reasoning, not fragments). Migration instructions: full sentences + commands preserved exactly.

Write a standalone release notes file for the GitHub release body:
```bash
# Write to session temp dir
cat > ${SESSION_TMP_DIR}/release-notes.md << 'NOTES'
<release notes content — same as changelog section but without the version header>
NOTES
```

### 3.5 Commit Release Prep

```bash
git add package.json CHANGELOG.md
# Add any other modified version files
git commit -m "chore(release): prepare vX.Y.Z"
```

### 3.6 Report Preparation Status

```
Release vX.Y.Z prepared.
  Branch: release/vX.Y.Z
  Version files updated: N
  Changelog: CHANGELOG.md updated
  Commits included: N

Next step: run 'release verify' to validate quality gates.
```

---

## Phase 4: VERIFY — Quality Gates

### 4.1 Detect Available Commands

```bash
# Read package.json scripts
node -p "Object.keys(require('./package.json').scripts || {}).join('\n')" 2>/dev/null
```

Determine which commands are available: type-check, lint, test, build.

### 4.2 Type Check

```bash
npm run type-check 2>&1 || npx tsc --noEmit 2>&1
```

Must exit 0. Record pass/fail.

### 4.3 Lint

```bash
npm run lint 2>&1
```

Must exit with 0 errors (warnings are acceptable). Record pass/fail.

### 4.4 Tests

```bash
npm test 2>&1
```

Must exit 0. Record total/passed/failed counts. Record pass/fail.

### 4.5 Build

```bash
npm run build 2>&1
```

Must exit 0. Record pass/fail.

### 4.6 Completeness Gate (Optional)

If the completeness-gate skill is available in this plugin suite, invoke it:
- Run completeness-gate against the full codebase
- Score must be 70 or higher (C grade minimum)
- If completeness-gate is not available, mark as SKIPPED

### 4.7 Version Consistency Check

Verify that all version files contain the same version string:
```bash
# Check all files that should contain the version
grep -r "X.Y.Z" package.json plugin.json marketplace.json 2>/dev/null
```

### 4.8 Gate Summary

Print the verification results:

```
Release Verification: PASS/FAIL
  Type-check:     PASS/FAIL/SKIPPED
  Lint:           PASS/FAIL/SKIPPED
  Tests:          PASS/FAIL/SKIPPED (N/N passed)
  Build:          PASS/FAIL/SKIPPED
  Completeness:   PASS/FAIL/SKIPPED (score: N/100)
  Version sync:   PASS/FAIL
```

If ANY required gate fails, STOP. Do not proceed to publish. Inform the user which gates failed and suggest fixes.

---

## Phase 5: PUBLISH — Tag and Release

### 5.1 Pre-Publish Validation

Verify that:
1. Current branch is `release/vX.Y.Z`
2. All quality gates have passed (Phase 4 completed successfully)
3. Working directory is clean (`git status --porcelain` is empty)

If any validation fails, inform the user and stop.

### 5.2 Confirm with User

```
Ready to publish vX.Y.Z. This will:
  1. Create git tag vX.Y.Z
  2. Push release branch and tag to remote
  3. Create GitHub release with changelog

Proceed? [y/n]
```

Wait for explicit confirmation.

### 5.3 Create Tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### 5.4 Push to Remote

```bash
git push origin release/vX.Y.Z
git push origin vX.Y.Z
```

### 5.5 Create GitHub Release

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file ${SESSION_TMP_DIR}/release-notes.md \
  --target release/vX.Y.Z
```

If `gh` is not available, instruct the user to create the release manually and provide the release notes content.

### 5.6 Merge Back to Main

```bash
git checkout main
git merge release/vX.Y.Z --no-edit
git push origin main
```

If merge conflicts occur, stop and inform the user. Do not force-resolve conflicts.

### 5.7 Cleanup Release Branch

```bash
git branch -d release/vX.Y.Z
git push origin --delete release/vX.Y.Z
```

---

## Phase 6: ROLLBACK — Revert Failed Release

### 6.1 Assess Rollback Scope

Determine what was completed before failure:
- Tag created locally? → Delete local tag
- Tag pushed to remote? → Delete remote tag (with user confirmation)
- GitHub release created? → Delete GitHub release (with user confirmation)
- Release branch merged to main? → Revert the merge commit
- Version files updated? → Revert the version bump commit

### 6.2 Delete Tag

```bash
# Local tag
git tag -d vX.Y.Z

# Remote tag (ONLY with user confirmation)
echo "Delete remote tag vX.Y.Z? This cannot be undone. [y/n]"
git push origin :refs/tags/vX.Y.Z
```

### 6.3 Delete GitHub Release

```bash
gh release delete vX.Y.Z --yes 2>/dev/null || echo "No GitHub release to delete"
```

### 6.4 Revert Commits

```bash
# Revert the release prep commit
git revert HEAD --no-edit
```

If the release was merged to main, revert the merge:
```bash
git checkout main
git revert -m 1 HEAD --no-edit
git push origin main
```

### 6.5 Delete Release Branch

```bash
git branch -d release/vX.Y.Z 2>/dev/null
git push origin --delete release/vX.Y.Z 2>/dev/null
```

### 6.6 Rollback Report

```
Rollback complete for vX.Y.Z:
  Local tag:      DELETED/NOT_FOUND
  Remote tag:     DELETED/NOT_FOUND/SKIPPED
  GitHub release: DELETED/NOT_FOUND
  Merge reverted: YES/NO/NOT_NEEDED
  Release branch: DELETED/NOT_FOUND
```

---

## Phase 7: REPORT — Final Status

### 7.1 Print Final Summary

Print a mode-appropriate summary:
- **prepare**: version, branch name, commit count, changelog status, next step (`release verify`)
- **verify**: gate results (N/N passed), next step (`release publish` if PASS)
- **publish**: version, tag, GitHub release URL, changelog summary (N features, N fixes, N other)
- **rollback**: confirmation that artifacts were removed and repo is restored

### 7.2 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Append `session_end` to the operations log

---

## Error Recovery

- **Git tag already exists**: Suggest incrementing the patch version (e.g., v1.2.1 if v1.2.0 exists). Never overwrite existing tags.
- **Push fails (no remote)**: Save tag locally, instruct user to push manually when remote is available.
- **GitHub release fails**: Tag is still valid on remote. Instruct user to create the release manually via `gh release create` or the GitHub UI. Provide the release notes content.
- **Quality gates fail during publish**: Abort publish immediately. Keep the release branch intact for fixes. Instruct user to fix issues and re-run `release verify`.
- **Rollback fails**: Provide manual rollback steps from `references/main.md`. List each artifact that needs manual cleanup.
- **No conventional commits found**: Warn user that version calculation cannot proceed automatically. Ask for an explicit version.
- **Monorepo version sync fails**: List which packages have mismatched versions. Ask user to resolve manually before retrying.
- **Merge conflict on merge-back**: Stop and inform user. Provide the branch names and suggest manual resolution.
- **Working directory not clean**: Warn user about uncommitted changes. Suggest committing or stashing before proceeding.
