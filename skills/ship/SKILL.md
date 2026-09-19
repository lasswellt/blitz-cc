---
name: ship
description: "Releases finished work: checks the plan's gate, computes semver from commits, writes CHANGELOG, tags, publishes, archives the plan, runs learn. Slash-only. Use for 'ship it', 'cut a release', 'publish', 'release vX.Y.Z', 'tag this'. Refuses when any task is open or the check report is not PASS."
argument-hint: "[--plan <slug>] [<version>] [--dry-run] [--no-publish]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
model: opus
effort: medium
disable-model-invocation: true
compatibility: ">=2.1.271"
---
> **Session:** slash-only skill; it pins `model: opus`, `effort: medium` because a release is rare and the cache reset is acceptable. Current effort: `${CLAUDE_EFFORT}`.

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- Artifacts, `next` rows, archive path, `check-report.md` freshness: [/_shared/loop.md](/_shared/loop.md)
- PASS / CONDITIONAL / FAIL verdict criteria: [/_shared/quality.md](/_shared/quality.md) §PASS / CONDITIONAL / FAIL
- Rollback recipe, merge-back, publish per stack, changelog template: [references/main.md](references/main.md)

---

# Ship

`ship` is the last step of the loop (`research → plan → build → check → ship`). It turns a plan whose every task is `done` and whose last check is `PASS` into a tagged, published release, then archives the plan and runs `learn`. Execute every phase in order; never skip one.

**Slash-only.** `disable-model-invocation: true` means the Skill tool and scheduled fires cannot invoke this skill. `next --loop` never dispatches `ship`: row 4 marks the plan `done`, runs `learn`, archives, and prints `Ready: /blitz:ship --plan <slug>`. A human types the command. `spec.md` `ship: auto` only removes the confirmation prompt in Phase 4; it never makes the loop ship.

**No Stop gate.** `ship` never arms `gate.json`; `rm -f .cc-sessions/sessions/${CLAUDE_SESSION_ID}/gate.json` at start in case a previous skill left one.

**Feed.** Append `skill_start` at Phase 0 and `skill_end` (with the version and tag in `detail`) after Phase 6 to `.cc-sessions/activity-feed.jsonl` ([sessions.reference.md](/_shared/sessions.reference.md)§99).

---

## Safety rules (non-negotiable)

These override every other instruction in this file.

1. **Never push, tag on the remote, publish a package, or create a GitHub release without explicit confirmation** (`Proceed? [y/n]`), unless `spec.md` carries `ship: auto` or the user wrote `--yes`. `--dry-run` never reaches a push.
2. **Never skip the gate.** Open, blocked, or `in_progress` tasks, or a check report that is not `PASS`, stop the skill at Phase 1. Do not "ship anyway".
3. **Never force-push tags.** An existing tag means: suggest the next patch version, never overwrite.
4. **Never modify a published release.** Fix forward with a patch release; rollback (Phase R) is for a release that failed mid-flight.
5. **Major bumps always require confirmation**, even under `ship: auto` or `--yes`.
6. **Never auto-resolve merge conflicts** during merge-back. Stop and report.
7. **Never delete a remote tag or a GitHub release without confirmation.**
8. **Never write `tasks.json` directly.** `scripts/tasks.sh` is its only writer; `ship` only reads it.
9. **Never leave placeholder artifacts.** CHANGELOG entries, release notes, and version bumps are complete or the phase fails.

---

## Phase 0: PARSE

Extract from `$ARGUMENTS`:

| Argument | Meaning | Default |
|---|---|---|
| `--plan <slug>` | the plan to ship (`docs/plans/<slug>/`) | the single `spec.md` with `status: active`; more than one active plan → stop and ask which |
| `<version>` | explicit semver (`2.1.0`, `v2.1.0`) | computed from conventional commits (Phase 2) |
| `--dry-run` | run every phase up to Phase 4, print what would happen, write nothing outside `${SESSION_TMP_DIR}` | off |
| `--no-publish` | tag and release, skip the package registry step | off |
| `--yes` | skip the Phase 4 confirmation (same effect as `spec.md` `ship: auto`) | off |

```bash
SLUG="<slug>"; PLAN_DIR="docs/plans/${SLUG}"
[ -f "${PLAN_DIR}/spec.md" ] || { echo "ship: no plan at ${PLAN_DIR}"; exit 1; }
SHIP_MODE=$(awk '/^ship:/{print $2; exit}' "${PLAN_DIR}/spec.md")   # auto | manual
```

Print `[ship] plan=<slug> version=<explicit|computed> dry-run=<y/n> publish=<y/n>`.

---

## Phase 1: PRE-FLIGHT

Every check below must pass; print the table and stop on the first failure.

### 1.1 Every task is `done`

```bash
NOT_DONE=$("${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" list "$SLUG" --json \
  | jq -r '[.[] | select(.status != "done")] | map("\(.id) \(.status)\(if .blocked_reason then " (" + .blocked_reason + ")" else "" end)") | join(", ")')
[ -z "$NOT_DONE" ] || { echo "BLOCK: tasks not done: ${NOT_DONE}. Run /blitz:build ${SLUG} or /blitz:next."; exit 1; }
```

`tasks.sh` only writes `status: done` after `verify[]` passed, so this line is also the structural "done" check ([loop.md](/_shared/loop.md) §Structural rules).

### 1.2 Fresh PASS check report

The report must say `result: PASS` and be newer than the last task change.

```bash
UPDATED=$(jq -r '.updated' "${PLAN_DIR}/tasks.json")
REPORT="${PLAN_DIR}/check-report.md"
FRESH=0
if [ -f "$REPORT" ] && grep -qE '^result: PASS' "$REPORT"; then
  REPORT_TS=$(awk -F': *' '/^(date|ts|generated):/{print $2; exit}' "$REPORT")
  [ -n "$REPORT_TS" ] && [ "$REPORT_TS" \> "$UPDATED" ] && FRESH=1
fi
```

If `FRESH=0`, invoke `/blitz:check --scope plan <slug>` **once** through the Skill tool (no `--fix`; ship does not edit code), then re-read the report. Refuse on anything but `PASS`:

| Report | Action |
|---|---|
| `PASS`, newer than `updated` | proceed |
| `CONDITIONAL` | stop: print the open P2/advisory findings; the user runs `/blitz:check --scope plan <slug> --fix` or rules on them in `progress.md`, then re-runs ship |
| `FAIL` or missing after the check call | stop: `BLOCK: check-report.md <verdict>; ship refuses` |

Verdict criteria: [quality.md](/_shared/quality.md) §PASS / CONDITIONAL / FAIL.

### 1.3 Repository state

```bash
git status --porcelain            # must be empty
BRANCH=$(git branch --show-current)
git fetch --tags --quiet
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
```

| Check | Stop when |
|---|---|
| Clean tree | any line from `git status --porcelain` (ask to commit or stash) |
| Release branch | `BRANCH` is not the branch the project releases from (`main`/`master` for trunk-based projects, `release/*` or the plan branch otherwise; ask once when unclear, remember the answer in `progress.md` as a `Ruling:`) |
| Up to date | `git rev-list --count HEAD..@{u}` is non-zero |
| Toolchain | `gh auth status` fails and `--no-publish` was not given (GitHub release is skipped with a warning, not a failure) |
| Dependencies | a lockfile exists but `node_modules` (or the stack's equivalent) does not |

### 1.4 Gate summary

```
Ship pre-flight (<slug>):
  Tasks:        N/N done
  Check report: PASS (<ts>)
  Tree:         clean on <branch>, <n> commits since <last-tag|start>
  Publish:      npm|none (--no-publish)
```

---

## Phase 2: VERSION

### 2.1 Semver from conventional commits

Collect `git --no-pager log ${LAST_TAG:+${LAST_TAG}..}HEAD --format='%h%x09%s%x09%b'` and classify:

| Commit | Bump | CHANGELOG section |
|---|---|---|
| `feat:` / `feat(scope):` | minor | Added |
| `fix:` / `fix(scope):` | patch | Fixed |
| `BREAKING CHANGE:` in body, or `!` after the type | major | Breaking Changes |
| `refactor:`, `perf:` | none | Changed |
| `docs:` | none | Documentation |
| `chore:`, `ci:`, `build:` | none | Other |
| `style:`, `test:` | none | excluded |

Rules: any major → `X+1.0.0`; else any minor → `X.Y+1.0`; else any patch → `X.Y.Z+1`; no bumping commit → ask whether to patch-bump or stop. An explicit `<version>` must be valid semver and greater than the current version. A tag `v<version>` that already exists stops the skill with the next patch suggested (safety rule 3).

**Major bump confirmation** (always, safety rule 5):

```
Breaking changes detected:
  - <hash> <subject>
This bumps <current> → <next>. Proceed? [y/n]
```

### 2.2 Version files

Bump every file that carries the current version string: `package.json` (and workspace packages), `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `pyproject.toml`, `Cargo.toml`, or whatever `detect-stack.sh` reports. List the files before editing; the user confirms any file outside that list.

---

## Phase 3: CHANGELOG AND NOTES

Prepend a Keep a Changelog section to `CHANGELOG.md` (create it when absent; template in [references/main.md](references/main.md#changelog-template)):

```markdown
## [X.Y.Z] - YYYY-MM-DD
### Breaking Changes / Added / Fixed / Changed / Documentation / Other
- <Subject with the type prefix stripped, first letter capitalized> (<hash>)
```

Omit empty sections; link hashes when a GitHub remote exists; breaking-change bullets keep full sentences and exact migration commands. Write the same section without the version header to `${SESSION_TMP_DIR}/release-notes.md`; append one line `Plan: docs/plans/archive/<date>-<slug>/spec.md` so the release links back to the archived plan.

Commit: `git commit -am "chore(release): prepare vX.Y.Z"` with the `Task: <slug>/release` trailer.

`--dry-run` stops here: print the version, the changelog section, and the list of files it would have changed, then `git checkout -- .` to restore them. Nothing else runs.

---

## Phase 4: CONFIRM

```
Ship vX.Y.Z (<slug>):
  1. tag vX.Y.Z and push <branch> + tag
  2. GitHub release from release-notes.md
  3. npm publish            (skipped: --no-publish)
  4. merge back into <target> (skipped: already on <target>)
  5. archive docs/plans/<slug> → docs/plans/archive/<date>-<slug>
  6. /blitz:learn <slug>
Proceed? [y/n]
```

Wait for `y` unless `ship: auto` or `--yes`. A `n` keeps the prep commit on the branch and prints how to resume (`/blitz:ship --plan <slug> <version>`), nothing is pushed.

---

## Phase 5: RELEASE

Run in order; on any failure jump to Phase R with the list of what completed.

1. **Tag** — `git tag -a vX.Y.Z -m "Release vX.Y.Z"`.
2. **Push** — `git push origin "$BRANCH" && git push origin vX.Y.Z`.
3. **GitHub release** — `gh release create vX.Y.Z --title "vX.Y.Z" --notes-file "${SESSION_TMP_DIR}/release-notes.md" --target "$BRANCH"`. Without `gh`, print the notes and the manual step; not a failure.
4. **Publish** — skipped under `--no-publish` or when the package is `"private": true` / has no registry. Otherwise per stack ([references/main.md](references/main.md#publish-per-stack)): `npm publish` (with `--provenance` when running in CI), `pip`/`cargo`/marketplace equivalents. A publish that fails after the tag exists is reported, not rolled back: the tag and release stand, the user re-runs the publish command.
5. **Merge back** — only when `BRANCH` is not the integration branch: `git checkout <target> && git merge --no-ff --no-edit "$BRANCH" && git push origin <target>`, then return to `BRANCH`. Conflicts stop the skill (safety rule 6); details in [references/main.md](references/main.md#merge-back).

---

## Phase 6: ARCHIVE AND LEARN

1. Set `status: done` in `docs/plans/<slug>/spec.md` (frontmatter only) and append to `progress.md`:
   `## <ISO-8601> ship vX.Y.Z tag=vX.Y.Z release=<url>`.
2. Move the plan: `mkdir -p docs/plans/archive && git mv docs/plans/<slug> docs/plans/archive/$(date -u +%Y-%m-%d)-<slug>`. If `next --loop` row 4 already archived it, skip the move and use the archived path.
3. Commit `chore(plans): archive <slug> after vX.Y.Z` with the `Task: <slug>/release` trailer; push.
4. Invoke `/blitz:learn <slug>` through the Skill tool. `learn` resolves the archived path itself, is idempotent, and prints one line when nothing non-obvious was learned. If it writes `docs/solutions/<slug>.md`, commit it as `docs(solutions): <slug>` and push. A `learn` failure is reported and does not undo the release.

---

## Phase 7: REPORT

```
Shipped vX.Y.Z (<slug>)
  Tag:       vX.Y.Z
  Release:   <url|manual>
  Publish:   npm <name>@X.Y.Z | skipped
  Merged:    <branch> → <target> | n/a
  Archived:  docs/plans/archive/<date>-<slug>/
  Learned:   docs/solutions/<slug>.md | nothing new
  Changes:   N breaking · N added · N fixed · N changed
```

Then `PushNotification(title: "Shipped vX.Y.Z", message: "<N added> · <N fixed> · <url>")` when Remote Control is configured (no-op otherwise), and the `skill_end` feed line.

---

## Phase R: ROLLBACK

Entered only from a Phase 5 failure or on `/blitz:ship --plan <slug> --rollback vX.Y.Z`. Assess which artifacts exist (local tag, remote tag, GitHub release, package version, merge commit, prep commit), then remove them in reverse order; remote tag and release deletion each need a `[y/n]` (safety rule 7); a published package version is never unpublished by this skill (deprecate instead). The plan stays where it is; `spec.md` returns to `status: active` only if it was already flipped. Full recipe and the report shape: [references/main.md](references/main.md#rollback-recipe).
