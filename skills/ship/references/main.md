# Ship — reference

Overflow for [SKILL.md](../SKILL.md): the changelog template, publish steps per stack, merge-back, and the rollback recipe. `SKILL.md` owns the phase order and the safety rules; nothing here relaxes them.

---

## Changelog template

Keep a Changelog, newest section first, directly under the file header:

```markdown
# Changelog

All notable changes to this project are documented here. Format: Keep a Changelog; versioning: semver.

## [X.Y.Z] - YYYY-MM-DD

### Breaking Changes
- <What changed and the migration, in full sentences> ([abc1234](https://github.com/<owner>/<repo>/commit/abc1234))

### Added
- <Subject, prefix stripped, first letter capitalized> ([abc1234](…))

### Fixed
- …

### Changed
- …

### Documentation
- …

### Other
- …
```

Rules:

- Strip the conventional prefix and scope from the subject (`feat(api): add x` → `Add x`); keep the scope when it disambiguates (`api: add x`).
- Omit empty sections. Never emit a section with a placeholder bullet.
- Hash links use the GitHub remote when `git remote get-url origin` resolves to github.com; otherwise the bare short hash.
- Squash-merged PRs: use the PR title as the subject and `(#123)` as the link when the commit carries a PR number.
- Breaking-change bullets are the only place full sentences are required; exact migration commands are preserved verbatim.
- `release-notes.md` = the same section without the `## [X.Y.Z]` header, plus a trailing `Plan: docs/plans/archive/<date>-<slug>/spec.md` line.

---

## Publish per stack

Skipped entirely under `--no-publish`. Detect from the stack line `detect-stack.sh` printed and from the files below; publish only one target unless the project is clearly a multi-target monorepo (then ask).

| Signal | Command | Skip when |
|---|---|---|
| `package.json` without `"private": true` | `npm publish --access public` (add `--provenance` when `CI` and `GITHUB_ACTIONS` are set); workspaces: `npm publish -ws` after `npm version` was already applied per package | `"private": true`, no `name`, or `npm whoami` fails |
| `.claude-plugin/plugin.json` + `marketplace.json` | nothing to push to a registry: the tag is the release; verify both files carry the new version (`scripts/check-version-sync.sh` when present) | never |
| `pyproject.toml` | `python -m build && python -m twine upload dist/*` | no `[project]` table |
| `Cargo.toml` | `cargo publish` | `publish = false` |
| `Dockerfile` + registry in CI | leave to CI; print the image tag the workflow will produce | always locally |

A registry publish is the one step that cannot be undone. Run it after the tag and the GitHub release exist so a publish failure leaves a coherent state (tag + release, no package): the user re-runs the single command by hand. Never `npm unpublish`; use `npm deprecate <name>@X.Y.Z "<reason>"` for a bad version.

---

## Merge-back

Only when the release branch is not the integration branch (`main`/`master`, or `develop` in git-flow projects).

```bash
TARGET=main
git checkout "$TARGET" && git pull --ff-only origin "$TARGET"
git merge --no-ff --no-edit "$BRANCH" -m "chore(release): merge vX.Y.Z into ${TARGET}"
git push origin "$TARGET"
git checkout "$BRANCH"
```

- Pre-check with `git merge-tree $(git merge-base "$TARGET" "$BRANCH") "$TARGET" "$BRANCH" | grep -c '^<<<<<<<'`; a non-zero count means conflicts: stop before the merge and print the conflicting paths. Never resolve them inside `ship`.
- A branch-protection rejection on push is not a failure: open a PR (`gh pr create --base "$TARGET" --head "$BRANCH" --title "chore(release): vX.Y.Z" --body-file "${SESSION_TMP_DIR}/release-notes.md"`) and report the URL.
- Delete a `release/*` branch only after the merge landed and only with confirmation: `git branch -d release/vX.Y.Z && git push origin --delete release/vX.Y.Z`. A plan branch is left for the user.

---

## Rollback recipe

Entered from a Phase 5 failure or `--rollback vX.Y.Z`. First assess, then undo in reverse order, then report.

### R.1 Assess

| Artifact | Exists when |
|---|---|
| Prep commit | `git log -1 --format=%s` is `chore(release): prepare vX.Y.Z` |
| Local tag | `git tag -l vX.Y.Z` prints the tag |
| Remote tag | `git ls-remote --tags origin refs/tags/vX.Y.Z` prints a line |
| GitHub release | `gh release view vX.Y.Z` exits 0 |
| Package version | `npm view <name>@X.Y.Z version` (or the stack equivalent) exits 0 |
| Merge commit | `git log <target> --merges --grep "vX.Y.Z" -1` prints a commit |
| Archived plan | `docs/plans/archive/*-<slug>/` exists |

### R.2 Undo (reverse order)

```bash
# GitHub release — confirmation required
gh release delete vX.Y.Z --yes

# Remote tag — confirmation required, cannot be undone
git push origin :refs/tags/vX.Y.Z

# Local tag
git tag -d vX.Y.Z

# Merge into the integration branch (only if it happened)
git checkout <target> && git revert -m 1 --no-edit <merge-sha> && git push origin <target>

# Prep commit on the release branch
git checkout "$BRANCH" && git revert --no-edit HEAD
```

- A published package version is never removed here: `npm deprecate` and a follow-up patch release are the path.
- The archived plan is moved back (`git mv docs/plans/archive/<date>-<slug> docs/plans/<slug>`) and `spec.md` returns to `status: active` only when `ship` itself did the archive in this run; an archive done earlier by `next --loop` row 4 stays.
- `docs/solutions/<slug>.md` written by `learn` stays: what was learned remains true.
- Every step prints its own line; a step that finds nothing prints `NOT_FOUND` and continues.

### R.3 Report

```
Rollback vX.Y.Z (<slug>):
  GitHub release: DELETED | NOT_FOUND | SKIPPED
  Remote tag:     DELETED | NOT_FOUND | SKIPPED
  Local tag:      DELETED | NOT_FOUND
  Merge:          REVERTED | NOT_NEEDED
  Prep commit:    REVERTED | NOT_FOUND
  Package:        <name>@X.Y.Z still published — run: npm deprecate … | NOT_PUBLISHED
  Plan:           docs/plans/<slug>/ (status: active) | left archived
Next: fix the cause, then /blitz:ship --plan <slug> <next-version>
```
