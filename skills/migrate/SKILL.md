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
- For package install policy (always resolve to registry latest unless the user pinned a specific version), see [/_shared/package-install-policy.md](/_shared/package-install-policy.md). Migration target version is user-specified — that's the case-2 exception; secondary deps installed during the migration follow the latest-resolution rule.
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

8. **NEVER leave placeholder code behind.** Migrated code must remain fully implemented. See [Definition of Done](/_shared/definition-of-done.md). No `TODO`, `FIXME`, `STUB`, or empty function bodies in the output.

---

## Phase 0: PARSE — Understand Migration Target

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Target

Extract the migration target from `$ARGUMENTS`. Examples:

| Input | Interpretation |
|-------|---------------|
| `vue 3.5` | Upgrade Vue from current version to 3.5 |
| `vitest` | Migrate test runner from Jest/Mocha to Vitest |
| `eslint 9` | Upgrade ESLint to v9 (flat config migration) |
| `pinia 3` | Upgrade Pinia to v3 |
| `typescript 5.5` | Upgrade TypeScript to 5.5 |
| `esm` | Migrate from CommonJS to ES Modules |
| `vite` | Migrate from Webpack to Vite |

If the target is ambiguous, ask the user for clarification.

### 0.2 Detect Current Versions

Read `package.json` (and any workspace `package.json` files) to find:
- Current version of the target package
- Related packages that may need coordinated upgrades (e.g., `@vue/compiler-sfc` when upgrading Vue)
- Peer dependency relationships
- Lock file format (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`)

```bash
cat package.json | grep -E '"(name|version)"' | head -5
cat package.json | grep -A1 '"<target-package>"' || echo "Package not found in package.json"
```

### 0.3 Create Rollback Branch

```bash
ROLLBACK_BRANCH="migrate/pre-<target>-$(date +%Y%m%d)"
git checkout -b "${ROLLBACK_BRANCH}"
git checkout -  # Return to original branch
echo "Rollback branch created: ${ROLLBACK_BRANCH}"
```

If the branch already exists, append a timestamp:
```bash
ROLLBACK_BRANCH="migrate/pre-<target>-$(date +%Y%m%d-%H%M%S)"
```

---

## Phase 1: RESEARCH — Gather Migration Intelligence

### 1.1 Spawn Research Agent (if WebSearch available)

Use WebSearch to research the migration target. Search for:
- Official migration guide / upgrade guide
- Breaking changes list / changelog
- Available codemods (automated transforms)
- Known issues and workarounds
- Community migration experiences and gotchas

Recommended search queries:
```
"<package> <old-version> to <new-version> migration guide"
"<package> <new-version> breaking changes"
"<package> <new-version> codemod"
```

Write research results to `${SESSION_TMP_DIR}/migration-research.md`.

### 1.2 Analyze Breaking Changes

For each breaking change found, document:

| Field | Description |
|-------|-------------|
| **Change** | What API/behavior changed |
| **Pattern** | Grep pattern to find affected code |
| **Impact** | Number of files affected in this project |
| **Migration path** | Manual fix or codemod available |
| **Risk** | High / Medium / Low |

```bash
# For each breaking change pattern, count affected files
grep -r "<pattern>" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" --include="*.jsx" -l . | grep -v node_modules | wc -l
```

### 1.3 Check Codemod Availability

Consult the codemod registry in `references/main.md` and check for available codemods:

```bash
# Check if common codemod packages exist
npm info <codemod-package> version 2>/dev/null || echo "Not found"
```

Common codemod commands:
- Vue: `npx @vue/compat` migration build, `npx vue-codemod`
- ESLint: `npx @eslint/migrate-config`
- TypeScript: built-in migration via strict flags
- Nuxt: `npx nuxi upgrade`
- Jest to Vitest: `npx jest-to-vitest`

### 1.4 Read Package Changelog

If web research is unavailable, fall back to the package changelog:
```bash
# Check for CHANGELOG in node_modules
cat node_modules/<package>/CHANGELOG.md 2>/dev/null | head -200
# Or fetch from npm
npm info <package> --json 2>/dev/null | head -50
```

---

## Phase 2: IMPACT — Assess Scope

### 2.1 Count Affected Files

For each breaking change, grep the codebase for affected patterns:

```bash
# Count files per breaking change
for pattern in "<pattern1>" "<pattern2>" "<pattern3>"; do
  count=$(grep -r "$pattern" --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" -l . | grep -v node_modules | wc -l)
  echo "Pattern: $pattern — Files: $count"
done
```

### 2.2 Risk Assessment

Classify the overall migration using the risk matrix from `references/main.md`:

| Risk Level | Criteria |
|-----------|----------|
| **Low** | Patch/minor upgrade, <10 files affected, no breaking changes |
| **Medium** | Minor upgrade with deprecations, 10-50 files, codemods available |
| **High** | Major upgrade, >50 files, manual migration required |
| **Critical** | Multiple major upgrades, deep architectural changes, no codemods |

### 2.3 Effort Estimate

Calculate estimated effort:
```
Total steps = config changes + codemod runs + (manual fixes per breaking change)
Estimated time = steps × average time per step
```

Present the assessment to the user:
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

### 3.1 Order Steps

Create atomic, verifiable steps ordered by dependency and risk:

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

### 3.2 Define Verification Gates

After each step, run the full verification suite:
```bash
# Type check
npx tsc --noEmit 2>&1 | tail -30

# Tests
npm test 2>&1 | tail -50

# Build
npm run build 2>&1 | tail -30
```

Determine the project's actual commands:
```bash
cat package.json | grep -E '"(test|type-check|typecheck|tsc|lint|build)"'
```

### 3.3 Present Plan

Show the step-by-step plan to the user:
```
Migration Plan: <current> → <target>
===================================
Steps: <N>
Rollback: <rollback-branch>

Step 1: <description>
  Files: <count>
  Risk: Low
  Codemod: <yes/no>

Step 2: <description>
  Files: <count>
  Risk: Medium
  Codemod: <no — manual>

...
```

---

## Phase 4: EXECUTE — Incremental Migration

### 4.1 Execute Steps

For each step in the plan:

#### 4.1.1 Make the Change

Execute the step — edit files, run codemods, update configs. Follow the principle of least change.

#### 4.1.2 Verify

Run the verification suite:
```bash
<TYPE_CHECK_CMD> 2>&1 | tail -30
<TEST_CMD> 2>&1 | tail -50
<BUILD_CMD> 2>&1 | tail -30
```

#### 4.1.3 Handle Result

**If verification passes:**
```bash
git add <changed-files>
git commit -m "migrate(<target>): step <N> — <description>"
```
Proceed to next step.

**If verification fails:**
1. Analyze the error output.
2. Attempt to fix (max 3 attempts per step).
3. After each fix attempt, re-run verification.
4. If fixed: commit and proceed.
5. If not fixed after 3 attempts: revert the step, note as blocked, try next step.
   ```bash
   git checkout -- <changed-files>
   ```

### 4.2 Track Progress

Maintain a progress checklist and display after each step:
```
Migration Progress: <current> → <target>
  [x] Step 1: Update package version — PASS
  [x] Step 2: Update config files — PASS
  [x] Step 3: Run codemod — PASS
  [ ] Step 4: Fix breaking API changes — IN PROGRESS (attempt 2/3)
  [ ] Step 5: Update test imports — PENDING
  [ ] Step 6: Clean up deprecations — PENDING
```

### 4.2.1 Output Artifacts (canonical, per [/_shared/state-handoff.md](/_shared/state-handoff.md) §migrate)

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

### 4.2.2 Resume Contract (`--resume`)

At Phase 0, if `docs/migrations/<from>-<to>/STATE.md` exists:
- **without `--resume`** — refuse to clobber: print `BLOCK: migration STATE.md exists; pass --resume to continue, or move STATE.md aside to restart.` and exit 1.
- **with `--resume`** — read STATE.md, verify each completed commit still exists in git history, skip `done` steps, retry the first non-`done` step. Rerun after full completion is a no-op (`migration already complete`, exit 0).

### 4.3 Consecutive Failure Check

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

### 5.1 Complete Verification

After all steps complete (or all possible steps are done), run the full verification:

```bash
<TYPE_CHECK_CMD> 2>&1
<LINT_CMD> 2>&1
<TEST_CMD> 2>&1
<BUILD_CMD> 2>&1
```

Compare results against the pre-migration baseline (captured in Phase 0).

### 5.2 Check for Remaining Deprecations

```bash
npm run build 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in build"
npx tsc --noEmit 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in type-check"
npm test 2>&1 | grep -i "deprecat" || echo "No deprecation warnings in tests"
```

### 5.3 Verify Package Versions

Confirm the target package is at the expected version:
```bash
cat package.json | grep -A1 '"<target-package>"'
npm ls <target-package> 2>/dev/null | head -5
```

---

## Phase 6: REPORT

### 6.1 Migration Summary

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

### 6.2 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Tests fail after migration | `fix-issue` | Debug and fix the specific test failures |
| Deprecation warnings remain | `migrate` (re-run) | Address remaining deprecations |
| Large refactoring needed | `refactor` | Clean up migration artifacts |
| Test coverage dropped | `test-gen` | Generate tests for new API usage |

### 6.3 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed` or `failed`.
2. Release any held locks.
3. Append `session_end` to the operation log.

---

## Error Recovery

- **No internet for research**: Proceed with package changelog from `node_modules` only. Warn that migration guidance may be incomplete.
- **Codemod fails**: Fall back to manual migration for affected patterns. Note which patterns were not auto-migrated.
- **Rollback branch already exists**: Append timestamp to make unique (e.g., `migrate/pre-vue3-20260318-143022`).
- **Package install fails**: Check for peer dependency conflicts. Try `--legacy-peer-deps` or `--force` only as last resort. Report conflicts to user.
- **Git state is dirty before starting**: Warn user and suggest stashing or committing changes first. Do not proceed with dirty state unless user confirms.
- **Lock file conflicts**: Delete lock file and regenerate with `npm install` / `pnpm install`.
- **Monorepo complications**: Identify affected workspaces and migrate them one at a time, starting with shared packages.
- **Version not found**: If target version does not exist, list available versions and ask user to pick one.
