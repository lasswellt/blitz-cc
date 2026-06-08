---
name: migrate
description: "Handles framework, library, and tooling migrations with incremental safety. Researches breaking changes, plans atomic migration steps, and verifies after each step (type-check + tests). Use when the user says 'migrate to', 'upgrade to Vue 3', 'Pinia from Vuex', 'Nuxt 2→3', 'replace X with Y', 'breaking change upgrade'. Refuses to proceed if any verification step fails."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
model: opus
effort: high
compatibility: ">=2.1.71"
argument-hint: "<target: e.g. 'vue 3.5', 'vitest', 'eslint 9', 'pinia 3'>"
disable-model-invocation: true
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For codemod registry, risk assessment matrix, and rollback procedures, see [references/main.md](references/main.md)
- For package install policy (always resolve to registry latest unless the user pinned a specific version), see [/_shared/security.md](/_shared/security.md). Migration target version is user-specified — that's the case-2 exception; secondary deps installed during the migration follow the latest-resolution rule.
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** breaking-change step explanations. Full sentences + reasoning chain required in these sections. Resume terse on next section.

# Migration Specialist

Handle framework upgrades, library migrations, and tooling transitions with incremental safety. Research breaking changes, plan atomic steps, verify after each. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER upgrade more than one major version at a time.** If the user asks to go from Vue 2 to Vue 3.5, upgrade to Vue 3.0 first, verify, then to 3.5.

2. **NEVER modify tests to make them pass.** If tests fail after a migration step, the migration step introduced a regression. Fix the source code, not the test.

3. **ALWAYS create a rollback branch before starting.** This is your safety net. No exceptions.

4. **ALWAYS verify (type-check + tests + build) after EACH step.** No batching verification across multiple steps.

5. **ABORT after 3 consecutive verification failures.** Something is fundamentally wrong. Stop and report to the user.

6. **NEVER remove deprecation warnings by deleting the code.** Fix the underlying usage to use the new API.

7. **NEVER combine multiple breaking changes into one step.** Each breaking change gets its own atomic step with its own verification.

8. **NEVER leave placeholder code behind.** Migrated code must remain fully implemented. See [Definition of Done](/_shared/sprint-contracts.md). No `TODO`, `FIXME`, `STUB`, or empty function bodies in the output.

---

## Phase 0: PARSE — Understand Migration Target

1. Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9). Print verbose progress at every phase transition.
2. Extract migration target from `$ARGUMENTS`. Ambiguous target → ask for clarification. Full examples: [references/main.md](references/main.md#target-interpretation-examples).
3. Read `package.json` (all workspace files) for current target version, related peer packages, and lock file format:
   ```bash
   cat package.json | grep -E '"(name|version)"' | head -5
   cat package.json | grep -A1 '"<target-package>"' || echo "Package not found in package.json"
   ```
4. Create rollback branch:
   ```bash
   ROLLBACK_BRANCH="migrate/pre-<target>-$(date +%Y%m%d)"
   git checkout -b "${ROLLBACK_BRANCH}"
   git checkout -  # Return to original branch
   echo "Rollback branch created: ${ROLLBACK_BRANCH}"
   ```
   If branch exists, append timestamp: `migrate/pre-<target>-$(date +%Y%m%d-%H%M%S)`

---

## Phase 1: RESEARCH — Gather Migration Intelligence

If WebSearch is available, search for the official migration guide, breaking changes, codemods, and known gotchas:
```
"<package> <old-version> to <new-version> migration guide"
"<package> <new-version> breaking changes"
"<package> <new-version> codemod"
```
Write results to `${SESSION_TMP_DIR}/migration-research.md`. If WebSearch unavailable, fall back to the package changelog:
```bash
cat node_modules/<package>/CHANGELOG.md 2>/dev/null | head -200
npm info <package> --json 2>/dev/null | head -50
```

For each breaking change, document: Change, Grep pattern, Impact (files affected), Migration path (manual or codemod), Risk level.
```bash
grep -r "<pattern>" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" --include="*.jsx" -l . | grep -v node_modules | wc -l
```

Consult codemod registry in `references/main.md`. Check availability:
```bash
npm info <codemod-package> version 2>/dev/null || echo "Not found"
```
Common codemods: Vue → `npx vue-codemod`; ESLint → `npx @eslint/migrate-config`; Nuxt → `npx nuxi upgrade`; Jest→Vitest → `npx jest-to-vitest`.

---

## Phase 2: IMPACT — Assess Scope

Count affected files per breaking change:
```bash
for pattern in "<pattern1>" "<pattern2>" "<pattern3>"; do
  count=$(grep -r "$pattern" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" -l . | grep -v node_modules | wc -l)
  echo "Pattern: $pattern — Files: $count"
done
```

Classify risk using the matrix from `references/main.md`:

| Risk Level | Criteria |
|-----------|----------|
| **Low** | Patch/minor upgrade, <10 files affected, no breaking changes |
| **Medium** | Minor upgrade with deprecations, 10-50 files, codemods available |
| **High** | Major upgrade, >50 files, manual migration required |
| **Critical** | Multiple major upgrades, deep architectural changes, no codemods |

Present assessment and prompt to proceed:
```
Migration Assessment: <target>
  Current version: <X.Y.Z>
  Target version:  <A.B.C>
  Risk level:      <Low | Medium | High | Critical>
  Files affected:  <N>
  Breaking changes: <N>
  Codemods available: <N>/<total>
  Estimated steps: <N>

  Proceed? (The rollback branch has been created.)
```

---

## Phase 3: PLAN — Build Migration Steps

Create atomic steps ordered by dependency and risk:

| Priority | Step Type | Risk | Example |
|----------|-----------|------|---------|
| 1 | Update config files | Lowest | `tsconfig.json`, `vite.config.ts`, `.eslintrc` |
| 2 | Update package versions | Low | `npm install <package>@<version>` |
| 3 | Run codemods | Low | `npx <codemod> .` |
| 4 | Fix type-level changes | Medium | Updated type signatures, removed types |
| 5 | Fix API changes | Medium | Renamed methods, changed parameters |
| 6 | Fix behavioral changes | High | Changed defaults, removed features |
| 7 | Update tests for new APIs | Medium | Test imports, test utilities |
| 8 | Clean up deprecations | Low | Remove compatibility shims |

Determine verification commands for this project:
```bash
cat package.json | grep -E '"(test|type-check|typecheck|tsc|lint|build)"'
```

Present the plan:
```
Migration Plan: <current> → <target>
===================================
Steps: <N>
Rollback: <rollback-branch>

Step 1: <description>
  Files: <count>
  Risk: Low
  Codemod: <yes/no>
...
```

---

## Phase 4: EXECUTE — Incremental Migration

### 4.1 Execute Loop

For each step: make the change (edit files, run codemods, update configs — least change principle), then verify:
```bash
<TYPE_CHECK_CMD> 2>&1 | tail -30
<TEST_CMD> 2>&1 | tail -50
<BUILD_CMD> 2>&1 | tail -30
```

**If verification passes:** commit and proceed:
```bash
git add <changed-files>
git commit -m "migrate(<target>): step <N> — <description>"
```

**If verification fails:** analyze, fix, re-verify (max 3 attempts). If still failing after 3 attempts, revert and note as blocked:
```bash
git checkout -- <changed-files>
```

Display progress after each step:
```
Migration Progress: <current> → <target>
  [x] Step 1: Update package version — PASS
  [x] Step 2: Update config files — PASS
  [x] Step 3: Run codemod — PASS
  [ ] Step 4: Fix breaking API changes — IN PROGRESS (attempt 2/3)
  [ ] Step 5: Update test imports — PENDING
  [ ] Step 6: Clean up deprecations — PENDING
```

### 4.2 Output Artifacts (canonical, per [/_shared/session-lifecycle.md](/_shared/session-lifecycle.md) §migrate)

Write durable artifacts under `docs/migrations/<from>-<to>/` (slug e.g. `vue2-vue3`):
- `plan.md` — incremental step plan + per-step verification commands.
- `STATE.md` — checkpoint (steps completed/failed); enables `--resume`.
- `report.md` — applied-change summary + type-check/test gate result per step.

After each step (pass or fail), update `STATE.md`:
```json
{ "target":"<from>-<to>", "started":"<ISO-8601>", "rollback_branch":"<branch>",
  "current_step":4, "total_steps":8,
  "steps":[{ "number":1, "description":"...", "status":"pass", "commit":"abc1234" }],
  "remaining":["..."], "last_updated":"<ISO-8601>" }
```

### 4.3 Resume Contract (`--resume`)

At Phase 0, if `docs/migrations/<from>-<to>/STATE.md` exists:
- **without `--resume`** — refuse to clobber: print `BLOCK: migration STATE.md exists; pass --resume to continue, or move STATE.md aside to restart.` and exit 1.
- **with `--resume`** — read STATE.md, verify each completed commit still exists in git history, skip `done` steps, retry the first non-`done` step. Rerun after full completion is a no-op (`migration already complete`, exit 0).

### 4.4 Consecutive Failure Check

Track consecutive failures across steps. If 3 steps in a row fail verification:

```
MIGRATION ABORTED: 3 consecutive verification failures
=====================================================
Step <N>:   <error summary>
Step <N+1>: <error summary>
Step <N+2>: <error summary>

Completed steps: <N> (committed)
Failed steps: 3
Remaining steps: <N>

Recommendation: Review the migration approach or seek help.
Rollback: git checkout <rollback-branch>
```

---

## Phase 5: VERIFY — Full Suite

Run full verification and compare against pre-migration baseline:
```bash
<TYPE_CHECK_CMD> 2>&1
<LINT_CMD> 2>&1
<TEST_CMD> 2>&1
<BUILD_CMD> 2>&1
```

Check for remaining deprecations:
```bash
npm run build 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in build"
npx tsc --noEmit 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in type-check"
npm test 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in tests"
```

Confirm target package is at expected version:
```bash
cat package.json | grep -A1 '"<target-package>"'
npm ls <target-package> 2>/dev/null | head -5
```

---

## Phase 6: REPORT

Print migration summary:
```
Migration Complete: <target>
==============================
Version: <old> → <new>
Steps completed: <N>/<total>
Steps skipped: <N> (list reasons)
Files modified: <N>

Verification:
  Type-check: PASS / FAIL (N errors)
  Lint:       PASS / FAIL (N errors)
  Tests:      PASS / FAIL (N passed, N failed, N skipped)
  Build:      PASS / FAIL
  Deprecation warnings: <N> remaining

Commits created: <N>
Rollback: git checkout <rollback-branch>
```

Follow-up suggestions:

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Tests fail after migration | `fix-issue` | Debug and fix the specific test failures |
| Deprecation warnings remain | `migrate` (re-run) | Address remaining deprecations |
| Large refactoring needed | `refactor` | Clean up migration artifacts |
| Test coverage dropped | `test-gen` | Generate tests for new API usage |

Session cleanup: update `.cc-sessions/${SESSION_ID}.json` status to `completed` or `failed`, release held locks, append `session_end` to the operation log.

---

## Error Recovery

- **No internet**: Use `node_modules` changelog; warn guidance may be incomplete.
- **Codemod fails**: Fall back to manual migration; note unautomated patterns.
- **Rollback branch exists**: Append timestamp (e.g., `migrate/pre-vue3-20260318-143022`).
- **Package install fails**: Check peer conflicts; `--legacy-peer-deps` or `--force` only as last resort.
- **Dirty git state**: Warn user; suggest stash or commit first; do not proceed without confirmation.
- **Lock file conflicts**: Delete lock file and regenerate (`npm install` / `pnpm install`).
- **Monorepo**: Migrate workspaces one at a time, starting with shared packages.
- **Version not found**: List available versions; ask user to pick.
