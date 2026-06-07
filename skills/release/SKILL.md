---
name: release
description: "Manages semantic versioning, changelogs, GitHub releases. Modes: prepare (version + draft CHANGELOG), verify (gates), publish (tag + push + npm publish), rollback (revert + delete tag). Use for the versioning/tag/publish/rollback step in isolation: 'publish release', 'tag and ship', 'rollback release', 'prepare changelog'. For the full pre-release chain use /blitz:ship instead."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<prepare|verify|publish|rollback> [version]"
disable-model-invocation: true
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
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

8. **NEVER leave placeholder code behind.** All release artifacts must be fully formed. See [Definition of Done](/_shared/sprint-contracts.md).

---

## Phase 0: PARSE — Determine Mode

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition and decision point.

Extract from `$ARGUMENTS`:

| Mode | Description |
|------|-------------|
| `prepare` (default) | Calculate version, generate changelog, create release branch |
| `verify` | Run all quality gates on current state |
| `publish` | Tag, push, create GitHub release (requires prior prepare + verify) |
| `rollback` | Revert a failed release |

Optional explicit version override: `prepare 2.0.0`. If mode is `publish`, verify that a release branch exists and verification has passed before proceeding.

---

## Phase 1: CONTEXT — Gather Release State

1. **Current version** — `node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0"`. Also check: `lerna.json`, `plugin.json`, `marketplace.json`, `version.txt`.
2. **Latest tag** — `git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"`
3. **Registry state** — check `private` field in `package.json`; if `private: true`, tag and GitHub release only (no npm publish).
4. **Commit history since last tag:**
```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  git log ${LAST_TAG}..HEAD --pretty=format:"%H|%s|%an|%ai"
else
  git log --pretty=format:"%H|%s|%an|%ai"
fi
```
5. **Unreleased check** — if no commits since last tag, inform user and stop.

---

## Phase 2: CALCULATE — Determine Version Bump

**Canonical changelog owner (O1/O5).** `skills/release` is the SINGLE source of the commit-type → changelog-section map and Keep a Changelog emit logic. `doc-gen` (`changelog` mode) and `ship` (Phase 2) MUST delegate here — they do not restate this map.

Categorize commits since last tag (from `references/main.md`):

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

Apply semver rules:
1. Any major-bump commit → increment major, reset minor+patch to 0
2. Any minor-bump commit → increment minor, reset patch to 0
3. Any patch-bump commit → increment patch
4. No bump commits (only docs/chore/etc.) → inform user, ask whether to patch-bump or skip

If explicit version provided: validate semver, validate > current, use it.

**Major bump confirmation** — STOP and present:
```
Breaking changes detected:
  - <commit hash short> <commit message>

This will bump from X.Y.Z to (X+1).0.0. Proceed? [y/n]
```
Wait for confirmation. If declined, suggest minor bump.

---

## Phase 3: PREPARE — Create Release Artifacts

1. **Create release branch** — `git checkout -b release/vX.Y.Z`. If branch exists, ask to continue or start fresh.
2. **Bump version** — update `package.json`, workspace `package.json` files (monorepo), `plugin.json`, `marketplace.json`, and any other files containing the old version string (confirm with user).
3. **Generate changelog** — parse commits, update `CHANGELOG.md` (Keep a Changelog format; template in `references/main.md`). Structure:
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
Rules: prepend new section below header; create `CHANGELOG.md` if absent; strip commit prefixes; capitalize first word; link short hash to GitHub if remote available; omit empty sections.

4. **Generate release notes** — terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Reuse CHANGELOG bullets verbatim. **LITE intensity** for breaking-change descriptions (migration reasoning needed). Migration instructions: full sentences + commands preserved exactly.
```bash
cat > ${SESSION_TMP_DIR}/release-notes.md << 'NOTES'
<release notes — same as changelog section without version header>
NOTES
```
5. **Commit release prep:**
```bash
git add package.json CHANGELOG.md
# Add any other modified version files
git commit -m "chore(release): prepare vX.Y.Z"
```
6. **Report** — version, branch, version files updated count, changelog status, commit count. Next step: `release verify`.

---

## Phase 4: VERIFY — Quality Gates

Detect available scripts: `node -p "Object.keys(require('./package.json').scripts || {}).join('\n')" 2>/dev/null`

Run each available gate:
1. **Type-check** — `npm run type-check 2>&1 || npx tsc --noEmit 2>&1` — must exit 0
2. **Lint** — `npm run lint 2>&1` — must exit with 0 errors (warnings OK)
3. **Tests** — `npm test 2>&1` — must exit 0; record total/passed/failed
4. **Build** — `npm run build 2>&1` — must exit 0
5. **Completeness** — invoke `/blitz:review --only completeness` if available; score ≥70 required; else SKIPPED
6. **Version sync** — `grep -r "X.Y.Z" package.json plugin.json marketplace.json 2>/dev/null` — all version files must match

Print results:
```
Release Verification: PASS/FAIL
  Type-check:     PASS/FAIL/SKIPPED
  Lint:           PASS/FAIL/SKIPPED
  Tests:          PASS/FAIL/SKIPPED (N/N passed)
  Build:          PASS/FAIL/SKIPPED
  Completeness:   PASS/FAIL/SKIPPED (score: N/100)
  Version sync:   PASS/FAIL
```

If ANY required gate fails, STOP. Do not proceed to publish. Report which gates failed.

---

## Phase 5: PUBLISH — Tag and Release

1. **Pre-publish validation** — branch is `release/vX.Y.Z`, Phase 4 passed, `git status --porcelain` is empty. Stop if any fails.
2. **Confirm with user:**
```
Ready to publish vX.Y.Z. This will:
  1. Create git tag vX.Y.Z
  2. Push release branch and tag to remote
  3. Create GitHub release with changelog

Proceed? [y/n]
```
3. **Create tag** — `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
4. **Push to remote:**
```bash
git push origin release/vX.Y.Z
git push origin vX.Y.Z
```
5. **Create GitHub release:**
```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file ${SESSION_TMP_DIR}/release-notes.md \
  --target release/vX.Y.Z
```
If `gh` unavailable, instruct user to create manually and provide release notes content.

6. **Merge back to main:**
```bash
git checkout main
git merge release/vX.Y.Z --no-edit
git push origin main
```
If merge conflicts occur, stop and inform user. Do not force-resolve.

7. **Cleanup release branch:**
```bash
git branch -d release/vX.Y.Z
git push origin --delete release/vX.Y.Z
```

---

## Phase 6: ROLLBACK — Revert Failed Release

Assess rollback scope (what completed before failure: local tag, remote tag, GitHub release, merge, version commit), then revert each artifact in reverse order. Remote-tag and GitHub-release deletion require explicit user confirmation (SAFETY RULE 7). Emit a rollback report listing each artifact's disposition.

Full rollback recipe (6.1 scope assessment, 6.2 delete tag, 6.3 delete GitHub release, 6.4 revert commits, 6.5 delete release branch, 6.6 rollback report): [references/main.md](references/main.md#phase-6-rollback-recipe).

---

## Phase 7: REPORT — Final Status

Print mode-appropriate summary:
- **prepare**: version, branch, commit count, changelog status, next step (`release verify`)
- **verify**: gate results (N/N passed), next step (`release publish` if PASS)
- **publish**: version, tag, GitHub release URL, changelog summary (N features, N fixes, N other)
- **rollback**: confirmation artifacts removed and repo restored

Session cleanup: set `status: completed` in `.cc-sessions/${SESSION_ID}.json`, release locks, append `session_end` to operations log.

---

## Error Recovery

- **Git tag already exists**: suggest incrementing patch (e.g., v1.2.1 if v1.2.0 exists). Never overwrite.
- **Push fails (no remote)**: save tag locally, instruct user to push manually.
- **GitHub release fails**: tag valid on remote; instruct user to create release via `gh release create` or GitHub UI; provide notes content.
- **Quality gates fail during publish**: abort immediately; keep release branch intact; instruct to fix and re-run `release verify`.
- **Rollback fails**: provide manual steps from `references/main.md`; list artifacts needing manual cleanup.
- **No conventional commits found**: warn, ask for explicit version.
- **Monorepo version sync fails**: list mismatched packages; ask user to resolve manually before retrying.
- **Merge conflict on merge-back**: stop, inform user, suggest manual resolution.
- **Working directory not clean**: warn about uncommitted changes; suggest commit or stash before proceeding.
