# Release Management — Reference Material

Templates, patterns, procedures for release skill.

---

## Conventional Commit Regex Patterns

Parse commit messages:

### Type Extraction

```regex
^(?<type>feat|fix|refactor|perf|docs|style|test|chore|ci|build)(?<scope>\([^)]+\))?(?<breaking>!)?:\s*(?<description>.+)$
```

Groups:
- `type`: commit type (feat, fix, etc.)
- `scope`: optional scope in parentheses (e.g., `(auth)`)
- `breaking`: optional `!` for breaking change
- `description`: commit description

### Breaking Change Detection

Check two locations:
1. **Header**: `!` after type/scope (e.g., `feat!: remove login endpoint`)
2. **Body**: line starting with `BREAKING CHANGE:` or `BREAKING-CHANGE:`

```regex
# Header detection
^[a-z]+(\([^)]+\))?!:

# Body detection
^BREAKING[ -]CHANGE:\s*(.+)$
```

### Scope Extraction

```regex
\((?<scope>[^)]+)\)
```

### Full Parsing Example

```
Input:  "feat(auth)!: replace session tokens with JWT"
Output: { type: "feat", scope: "auth", breaking: true, description: "replace session tokens with JWT" }

Input:  "fix: handle null user in profile page"
Output: { type: "fix", scope: null, breaking: false, description: "handle null user in profile page" }
```

---

## CHANGELOG.md Template (Keep a Changelog)

### Full File Template

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Breaking Changes
- Description of breaking change ([hash](url))

### Added
- Description of new feature ([hash](url))

### Fixed
- Description of bug fix ([hash](url))

### Changed
- Description of change ([hash](url))

### Documentation
- Description of docs change ([hash](url))

### Other
- Description of other change ([hash](url))

## [Previous.Version] - YYYY-MM-DD
...
```

### Section Ordering Rules

Sections MUST appear in this order (omit empty sections):
1. Breaking Changes
2. Added
3. Fixed
4. Changed
5. Documentation
6. Other

### Commit-to-Section Mapping

| Commit Type | Changelog Section |
|-------------|-------------------|
| `feat` | Added |
| `fix` | Fixed |
| `refactor` | Changed |
| `perf` | Changed |
| `docs` | Documentation |
| `chore` | Other |
| `ci` | Other |
| `build` | Other |
| `style` | _(excluded)_ |
| `test` | _(excluded)_ |

### Description Formatting Rules

1. Strip conventional commit prefix: `feat(auth): add login` becomes `Add login`
2. Capitalize first letter
3. Remove trailing period
4. Keep descriptions concise (under 80 characters)
5. Include short commit hash (first 7 chars) linked to commit URL

### Commit Hash Links

If GitHub remote detected:
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')
```

Link format: `([hash](REMOTE_URL/commit/FULL_HASH))`

No remote: plain hash `(hash)`.

---

## GitHub Release Body Template

```markdown
## What's Changed

### Breaking Changes
- Description (hash)

### New Features
- Description (hash)

### Bug Fixes
- Description (hash)

### Other Changes
- Description (hash)

**Full Changelog**: REMOTE_URL/compare/vPREVIOUS...vCURRENT
```

### Release Title Convention

Format: `vX.Y.Z`

Pre-releases: `vX.Y.Z-beta.N` or `vX.Y.Z-rc.N`

---

## Version Bump Decision Matrix

| Commits Include | Bump | Example |
|-----------------|------|---------|
| Breaking change (any type) | Major | 1.2.3 -> 2.0.0 |
| `feat` (no breaking) | Minor | 1.2.3 -> 1.3.0 |
| `fix` only (no feat, no breaking) | Patch | 1.2.3 -> 1.2.4 |
| Only `docs`, `chore`, `style`, `test`, `ci` | None (ask user) | 1.2.3 -> 1.2.3 |

### Pre-1.0.0 Special Rules

Current version below 1.0.0:
- Breaking changes bump minor (0.1.0 -> 0.2.0) instead of major
- Features bump patch (0.1.0 -> 0.1.1) instead of minor
- Follows semver convention for pre-stable software

---

## Rollback Procedure (Manual)

When automated rollback fails, follow manual steps:

### Step 1: Identify Release Artifacts

```bash
# Check if tag exists locally
git tag -l "vX.Y.Z"

# Check if tag exists on remote
git ls-remote --tags origin "refs/tags/vX.Y.Z"

# Check if GitHub release exists
gh release view vX.Y.Z 2>/dev/null && echo "EXISTS" || echo "NOT FOUND"

# Check if release branch exists
git branch -a | grep "release/vX.Y.Z"

# Check if merge to main occurred
git log main --oneline -5
```

### Step 2: Remove GitHub Release

```bash
gh release delete vX.Y.Z --yes
```

### Step 3: Remove Remote Tag

```bash
git push origin :refs/tags/vX.Y.Z
```

### Step 4: Remove Local Tag

```bash
git tag -d vX.Y.Z
```

### Step 5: Revert Merge to Main (if applicable)

```bash
git checkout main
git log --oneline -5  # Find the merge commit hash
git revert -m 1 <merge-commit-hash> --no-edit
git push origin main
```

### Step 6: Remove Release Branch

```bash
git branch -D release/vX.Y.Z
git push origin --delete release/vX.Y.Z
```

### Step 7: Verify Cleanup

```bash
echo "=== Verification ==="
git tag -l "vX.Y.Z"                           # Should be empty
git ls-remote --tags origin "refs/tags/vX.Y.Z" # Should be empty
gh release view vX.Y.Z 2>&1                    # Should say "not found"
git branch -a | grep "release/vX.Y.Z"          # Should be empty
echo "=== Done ==="
```

---

## Monorepo Coordination

### Version Sync Strategy

Monorepos using workspaces:

1. **Detect workspace packages**:
   ```bash
   # pnpm
   pnpm list --recursive --depth -1 --json 2>/dev/null

   # npm workspaces
   npm query .workspace 2>/dev/null

   # Check pnpm-workspace.yaml or package.json workspaces field
   ```

2. **Version sync approaches**:
   - **Lockstep**: all packages share same version. Bump all together.
   - **Independent**: each package has own version. Bump only changed packages.
   - Detection: if `lerna.json` exists with `"version": "independent"`, use independent mode. Otherwise lockstep.

### Publish Order for Monorepos

Publish in dependency order (leaves first):

1. Build dependency graph from workspace `package.json` files
2. Topological sort (packages with no internal deps first)
3. Publish in order, waiting for each to complete before publishing dependents

```
Example order:
  1. @scope/utils         (no internal deps)
  2. @scope/types         (no internal deps)
  3. @scope/core          (depends on utils, types)
  4. @scope/ui            (depends on core)
  5. @scope/app           (depends on ui, core)
```

### Cross-Reference Updates

Bumping versions in monorepo:
1. Update package's own `version` field
2. Update internal `dependencies` or `devDependencies` referencing sibling packages
3. Run `pnpm install` or `npm install` to update lockfiles

---

## Quality Gate Thresholds

| Gate | Pass Condition | Notes |
|------|---------------|-------|
| Type-check | Exit code 0 | No new type errors |
| Lint | Exit code 0, 0 errors | Warnings are acceptable |
| Tests | Exit code 0, all pass | No test failures |
| Build | Exit code 0 | Clean production build |
| Completeness | Score >= 70 (C grade) | Optional — skip if not available |
| Version sync | All files match | All version files contain new version |

### Skip Conditions

Gate marked SKIPPED (not FAIL) only if:
- Corresponding npm script does not exist in `package.json`
- Tool not installed (e.g., `tsc` not found)
- Gate explicitly optional (completeness gate)

SKIPPED gates do not block release.

---

## Semver Validation

### Valid Semver Format

```regex
^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
```

### Version Comparison

New version must be greater than current:
- Compare major first, then minor, then patch
- Pre-release versions lower than release counterpart (1.0.0-beta.1 < 1.0.0)

### Tag Format

Tags use `v` prefix: `v1.2.3`, `v2.0.0-beta.1`

## Phase 6 Rollback Recipe

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
