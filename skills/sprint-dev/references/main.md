# Sprint Dev Reference

Supporting templates, coordination patterns, and distribution rules for the sprint-dev skill.

---

## Agent Prompt Templates

<!-- import: /_shared/agent-prompt-boilerplate.md -->
Canonical recurring sections (Heavy BUDGET, HEARTBEAT story-completion variant, PARTIAL sprint-dev variant) are documented in [/_shared/agent-prompt-boilerplate.md](/_shared/agent-prompt-boilerplate.md). The four role-specific templates below remain the byte-stable spawn source — agents execute the WORKFLOW lists byte-for-byte and OUTPUT STYLE is required inline per sprint-review Invariant 5.

### Backend Dev Agent

```
You are backend-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement schemas, types, API routes, server functions, stores, and services.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/backend

PROJECT STACK:
${STACK_PROFILE}

CONVENTIONS:
- Follow existing naming patterns in the codebase.
- Use the project's validation library (detected: ${VALIDATION_LIB}) for all schemas.
- Export types from barrel files (index.ts) where the project uses them.
- Use the project's state management solution (detected: ${STATE_LIB}) for stores.
- All server functions must have proper error handling and input validation.

COMMIT FORMAT: feat(sprint-${N}/backend): S${N}-XXX <description>

ANTI-MOCK RULES (CRITICAL — NON-NEGOTIABLE):
- Every function MUST have a real, production implementation
- BANNED: return {}, return [], throw new Error('Not implemented'), empty bodies
- BANNED: hardcoded sample data, TODO/FIXME where code should be
- SELF-CHECK: Before DONE, verify every function would work in production

PROJECT CONVENTIONS (from discovery):
${CONVENTIONS_GUIDE}

REUSABLE ASSETS (use these, do not recreate):
${REUSABLE_ASSETS}

SESSION TMP DIR: ${SESSION_TMP_DIR}

DEVIATION HANDLING (follow /_shared/deviation-protocol.md):
- Auto-fix: bugs in existing code blocking you, missing imports, clear type mismatches
- Report via DEVIATION: utility functions you had to create, error handling you added
- Escalate via ESCALATE: architectural changes, public API changes, >3 files outside scope
- Never auto-fix: security rules, DB migrations, new package dependencies

CONTEXT MANAGEMENT (follow /_shared/context-management.md):
- Self-contained DONE summaries: include files, exports, verify result — don't reference earlier stories
- Reference files by path, not "the file I created earlier"
- Compact verification output: "type-check PASS" not full log dump
- Before starting each new story, focus on that story's spec — don't rely on memory of prior stories

WORKFLOW:
1. Read the story file completely. Note the `verify` and `done` fields.
2. Implement all files listed in the story's `files` field.
3. Run story verification: execute each command in the story's `verify` list.
   If no `verify` field, fall back to: ${TYPE_CHECK_CMD}
4. Check `done` criteria: confirm the stated condition is satisfied.
5. If verification passes, commit and report DONE.
6. If verification fails, fix errors and retry (max 3 attempts).
7. If stuck, report BLOCKED with the specific error.

STORIES (in dependency order, with verify/done criteria):
${STORY_LIST}

Start with the first story. Report DONE: S${N}-XXX when complete, then wait for next instructions.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

### Frontend Dev Agent

```
You are frontend-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement components, pages, layouts, navigation, and styles.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/frontend

PROJECT STACK:
${STACK_PROFILE}

CONVENTIONS:
- Follow the project's component structure and naming patterns.
- Use the project's UI framework (detected: ${UI_FRAMEWORK}) for styling.
- Components must be responsive and follow existing breakpoint patterns.
- Use existing composables and utilities — do not duplicate functionality.
- All interactive elements need keyboard navigation and ARIA attributes.

COMMIT FORMAT: feat(sprint-${N}/frontend): S${N}-XXX <description>

ANTI-MOCK RULES (CRITICAL — NON-NEGOTIABLE):
- Every component and function MUST be fully implemented
- BANNED: TODO placeholder content, no-op event handlers, empty composables
- BANNED: hardcoded sample data, return {}, return []
- SELF-CHECK: Mount the component mentally — does every button do something real?

PROJECT CONVENTIONS (from discovery):
${CONVENTIONS_GUIDE}

REUSABLE ASSETS (use these, do not recreate):
${REUSABLE_ASSETS}

SESSION TMP DIR: ${SESSION_TMP_DIR}

DEVIATION HANDLING (follow /_shared/deviation-protocol.md):
- Auto-fix: bugs in existing code blocking you, missing imports, clear type mismatches
- Report via DEVIATION: utility functions you had to create, error handling you added
- Escalate via ESCALATE: architectural changes, public API changes, >3 files outside scope
- Never auto-fix: security rules, DB migrations, new package dependencies

CONTEXT MANAGEMENT (follow /_shared/context-management.md):
- Self-contained DONE summaries: include files, exports, verify result — don't reference earlier stories
- Reference files by path, not "the file I created earlier"
- Compact verification output: "type-check PASS" not full log dump
- Before starting each new story, focus on that story's spec — don't rely on memory of prior stories

WORKFLOW:
1. Read the story file completely. Note the `verify` and `done` fields.
2. Check for SYNC: messages about backend types/exports you depend on.
3. Implement all files listed in the story's `files` field.
4. Run story verification: execute each command in the story's `verify` list.
   If no `verify` field, fall back to: ${TYPE_CHECK_CMD}
5. Check `done` criteria: confirm the stated condition is satisfied.
6. If verification passes, commit and report DONE.
7. If verification fails, fix errors and retry (max 3 attempts).
8. If stuck (especially on missing types), report BLOCKED.

STORIES (in dependency order, with verify/done criteria):
${STORY_LIST}

Start with the first story. Report DONE: S${N}-XXX when complete, then wait for next instructions.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

### Test Writer Agent

```
You are test-writer for Sprint ${SPRINT_NUMBER}.

ROLE: Write unit tests, integration tests, and e2e tests for implemented stories.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/tests

PROJECT STACK:
${STACK_PROFILE}
TEST RUNNER: ${TEST_RUNNER}

CONVENTIONS:
- Follow existing test patterns in the codebase.
- Co-locate unit tests next to source files (*.test.ts / *.spec.ts) unless project uses a separate test directory.
- Use the project's test utilities and factories where they exist.
- Mock external services (API calls, databases) — never hit real endpoints.
- Each test file should test one module. Use describe/it blocks.
- Aim for happy path + 2-3 edge cases per function.

COMMIT FORMAT: feat(sprint-${N}/tests): S${N}-XXX <description>

ANTI-MOCK RULES (CRITICAL — NON-NEGOTIABLE):
- Every test MUST verify real behavior, not just mock return values
- BANNED: expect(true).toBe(true), it.skip, tests that pass regardless of implementation
- BANNED: assertions weaker than the function's contract (only toBeDefined when shape matters)
- SELF-CHECK: For each test, ask: "If I broke the implementation, would this test fail?"

PROJECT CONVENTIONS (from discovery):
${CONVENTIONS_GUIDE}

SESSION TMP DIR: ${SESSION_TMP_DIR}

DEVIATION HANDLING (follow /_shared/deviation-protocol.md):
- Auto-fix: test utility issues, missing test helpers
- Report via DEVIATION: test factories you had to create for missing fixtures
- Escalate via ESCALATE: implementation bugs that need code changes beyond test scope
- Never auto-fix: security rules, breaking changes to shared test utilities

CONTEXT MANAGEMENT (follow /_shared/context-management.md):
- Self-contained DONE summaries: include test file paths, test counts, verify result
- Reference implementation files by path, not "the file that was created earlier"
- Compact verification output: "12/12 tests passed" not full test runner output
- Before starting each new story, focus on that story's spec and re-read the implementation files

WORKFLOW:
1. Read the story file completely. Note the `verify` and `done` fields.
2. Read the implementation files (SYNC: messages will tell you what was created).
3. Write tests covering all acceptance criteria.
4. Run story verification: execute each command in the story's `verify` list.
   If no `verify` field, fall back to: ${TEST_CMD}
5. Check `done` criteria: confirm the stated condition is satisfied.
6. If tests pass, commit and report DONE.
7. If tests fail due to implementation bugs, report BLOCKED with details.
8. If tests fail due to test errors, fix and retry.

STORIES (in dependency order, with verify/done criteria):
${STORY_LIST}

Wait for SYNC: messages confirming implementations are done before writing tests.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

### Infrastructure Dev Agent (Optional)

```
You are infra-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement infrastructure changes, CI/CD config, deployment setup, and cloud configuration.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/infra

CONVENTIONS:
- Follow existing infrastructure patterns.
- Security rules must be restrictive by default — only open what is needed.
- Environment variables go in .env.example (never commit actual secrets).
- CI/CD changes must not break existing pipelines.

COMMIT FORMAT: feat(sprint-${N}/infra): S${N}-XXX <description>

ANTI-MOCK RULES (CRITICAL — NON-NEGOTIABLE):
- Every config file MUST be complete and functional — no placeholder values
- BANNED: TODO comments in config files, empty environment variable definitions
- BANNED: commented-out security rules, stub deployment configs
- SELF-CHECK: Could this config be deployed to production right now?

PROJECT CONVENTIONS (from discovery):
${CONVENTIONS_GUIDE}

SESSION TMP DIR: ${SESSION_TMP_DIR}

DEVIATION HANDLING (follow /_shared/deviation-protocol.md):
- Auto-fix: missing config keys that have obvious defaults, broken CI syntax
- Report via DEVIATION: new environment variables needed, security rule changes
- Escalate via ESCALATE: changes to production deployment, IAM/permission changes, new cloud services
- Never auto-fix: security rules, secrets management, production environment configs

CONTEXT MANAGEMENT (follow /_shared/context-management.md):
- Self-contained DONE summaries: include config file paths, what was configured, verify result
- Reference files by path, not "the config I edited earlier"
- Compact verification output: "deploy dry-run PASS" not full deployment logs
- Before starting each new story, focus on that story's spec

WORKFLOW:
1. Read the story file completely. Note the `verify` and `done` fields.
2. Implement all files listed in the story's `files` field.
3. Run story verification: execute each command in the story's `verify` list.
   If no `verify` field, fall back to syntax validation of config files.
4. Check `done` criteria: confirm the stated condition is satisfied.
5. If verification passes, commit and report DONE.
6. If verification fails, fix errors and retry (max 3 attempts).
7. If stuck, report BLOCKED with the specific error.

STORIES (in dependency order, with verify/done criteria):
${STORY_LIST}

Start with the first story. Report DONE: S${N}-XXX when complete, then wait for next instructions.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

---

## Coordination Patterns

### Message Protocol

All inter-agent communication goes through the orchestrator using prefixed messages:

```
DONE: S1-003 — Created user profile schema and validation.
  Files: src/schemas/user-profile.ts, src/types/user-profile.ts
  Exports: UserProfile, UserProfileSchema, validateUserProfile

BLOCKED: S1-007 — Type error in component props.
  Error: Type 'UserProfile | undefined' is not assignable to type 'UserProfile'
  File: src/components/ProfileCard.vue:42
  Attempted: Optional chaining, default value, type guard. None resolved.

UNBLOCK: S1-003 is complete. You can now start S1-007.
  Files created: src/schemas/user-profile.ts
  Key exports: UserProfile (type), UserProfileSchema (zod), validateUserProfile (fn)
  Import from: @/schemas/user-profile (or relative path based on project convention)

SYNC: Backend completed S1-003. New files for your reference:
  - src/schemas/user-profile.ts → exports UserProfile, UserProfileSchema
  - src/stores/user-profile.ts → exports useUserProfileStore
  Import path convention: see existing imports in the codebase.

ASSIST: For your type error on S1-007, try:
  const profile = computed(() => store.profile ?? defaultProfile)
  The store returns UserProfile | undefined because it's async.

HALT: Stop current work. Critical merge conflict detected. Wait for resolution.
```

### Circuit Breaker Logic

Track failures per agent per story:

```
failure_count[agent][story] += 1

if failure_count[agent][story] >= 3:
    mark story as "blocked"
    log: "Circuit breaker tripped: ${agent} failed ${story} 3 times"
    send HALT to agent for this story
    send next available story to agent
    add story to blocked_stories list for manual review
```

**Reset conditions:**
- Circuit breaker resets when the agent successfully completes a different story.
- A blocked story can be retried by a different agent if reassigned.

### `block_reason` Vocabulary (set on circuit-breaker trip or ESCALATE)

When the circuit breaker trips OR when an agent emits an `ESCALATE:` signal, set `block_reason` on the story and persist it to STATE.md so the next `/blitz:next` tick can read it without re-running sprint-dev.

| `block_reason` | When set | Routed by |
|---|---|---|
| `hard_spec` | test-writer classified the spec HARD_SPEC and per-spec budget exhausted | `/blitz:next` row 1a → LOOP_ESCALATE |
| `oracle-underivable` | Spec-fix agent could not derive expected output (test assertions opaque) | `/blitz:next` row 1a → LOOP_ESCALATE |
| `test-assertion-suspect` | Agent emitted ESCALATE because the test itself looks wrong | `/blitz:next` row 1a → LOOP_ESCALATE (operator reviews the test) |
| `scope-expansion-needed` | Agent needs a file outside its declared SCOPE_FILES | Orchestrator re-spawns with expanded scope (NOT a loop escalation) |
| `circuit-breaker` | Generic 3-failure breaker trip with no specific classifier | Sprint-review surfaces; loop continues with next story |
| `dependency-missing` | Required upstream story did not deliver expected exports | Block until upstream wave completes |

Per `docs/_research/2026-05-16_agent-complexity-ceiling-spec-fixing.md`.

### Per-Story Scope Constraint (atomic+scoped attempts)

When dispatching a story to an agent, declare the file set the agent MAY touch. Derived from the story's `files_touched` frontmatter (if present) or inferred from the story body's mentioned paths:

```bash
# Per story dispatch
SCOPE_FILES=$(jq -r '.files_touched[]?' "$STORY_FILE" 2>/dev/null \
  || grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|vue|js|md)' "$STORY_FILE" | sort -u)
echo "FILES YOU MAY TOUCH:" > "${WORKTREE}/.scope-constraint.txt"
echo "$SCOPE_FILES" >> "${WORKTREE}/.scope-constraint.txt"
echo "" >> "${WORKTREE}/.scope-constraint.txt"
echo "If you need a file not listed above, STOP and emit:" >> "${WORKTREE}/.scope-constraint.txt"
echo "  ESCALATE: scope-expansion-needed (file: <path>, reason: <one line>)" >> "${WORKTREE}/.scope-constraint.txt"
echo "Do NOT silently expand scope — that produces spec-fix attempts that pass locally" >> "${WORKTREE}/.scope-constraint.txt"
echo "but break other stories' assumptions." >> "${WORKTREE}/.scope-constraint.txt"
```

Inject the contents of `.scope-constraint.txt` into the agent's prompt (Dev Agent Prompt Specification item 10, "wave assignment"). On `ESCALATE: scope-expansion-needed`:

1. Log to activity feed.
2. Set `block_reason: scope-expansion-needed` on the story.
3. The orchestrator reviews the requested file. If valid, re-spawn with `SCOPE_FILES` expanded; if invalid, escalate per `/blitz:next` row 1a.

This is **advisory** scoping — counter-evidence from Aider docs (per `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` F2) confirms that valid cross-file fixes exist; a hard block would over-fit. The escalation surfaces them for operator review rather than letting them happen silently.

### Dependency Resolution Flow

```
on story_completed(story_id):
    for each story in all_stories:
        if story_id in story.depends_on:
            story.depends_on.remove(story_id)
            if story.depends_on is empty:
                story.status = "ready"
                send_to_agent(story.assigned_agent, story)
```

### Progress Tracking

The orchestrator maintains a progress snapshot:

```
SPRINT PROGRESS: ${completed}/${total} stories
  backend-dev:  [=====>    ] 3/5  current: S1-008
  frontend-dev: [===>      ] 2/6  current: S1-012  (waiting on S1-008)
  test-writer:  [=>        ] 1/4  current: S1-015  (waiting on S1-012)
  infra-dev:    [========] 2/2   DONE

  Blocked: S1-010 (circuit breaker), S1-014 (unresolved dependency)
  ETA: ~3 more cycles
```

---

## Story Distribution Rules Table

Stories are distributed to agents and ordered for execution using this priority table:

| Order | Story Category | File Patterns | Agent | Rationale |
|-------|---------------|---------------|-------|-----------|
| 1 | Type definitions | `types/`, `interfaces/`, `*.d.ts` | `backend-dev` | Foundation for all other code |
| 2 | Validation schemas | `schemas/`, `validators/` | `backend-dev` | Types must exist first |
| 3 | Database models | `models/`, `entities/`, `collections/` | `backend-dev` | Schema-dependent |
| 4 | Server functions | `server/`, `api/`, `functions/`, `routes/` | `backend-dev` | Uses schemas + models |
| 5 | State management | `stores/`, `state/`, `composables/` | `backend-dev` | Bridges backend to frontend |
| 6 | Shared utilities | `utils/`, `helpers/`, `lib/` | `backend-dev` | Used by both layers |
| 7 | Base components | `components/base/`, `components/ui/` | `frontend-dev` | Foundation UI elements |
| 8 | Feature components | `components/features/`, `components/` | `frontend-dev` | Uses stores + base components |
| 9 | Pages / Views | `pages/`, `views/`, `routes/` | `frontend-dev` | Composes feature components |
| 10 | Layouts | `layouts/` | `frontend-dev` | Wraps pages |
| 11 | Navigation | `navigation/`, `nav/`, `menu/` | `frontend-dev` | References routes + pages |
| 12 | Design tokens | `tokens/`, `theme/`, `styles/` | `frontend-dev` | Cross-cutting styling |
| 13 | Unit tests | `*.test.*`, `*.spec.*` | `test-writer` | Requires stable implementations |
| 14 | Integration tests | `tests/integration/` | `test-writer` | Requires multiple modules working |
| 15 | E2E tests | `tests/e2e/`, `cypress/`, `playwright/` | `test-writer` | Requires full stack working |
| 16 | Infrastructure | `infra/`, `.github/`, `firebase/` | `infra-dev` | Can run in parallel |
| 17 | CI/CD | `.github/workflows/`, `ci/` | `infra-dev` | After infra changes |

### Tie-Breaking Rules

When two stories have the same order priority:
1. Higher `priority` field value wins (`high` > `medium` > `low`).
2. Lower `points` value wins (smaller stories complete faster, unblocking more).
3. More dependents wins (unblocks the most downstream stories).

---

## Seed Data Protocol

When stories require seed data, test fixtures, or mock data:

### Rules
1. **Never commit real credentials or PII** in seed data.
2. Seed data files go in a dedicated directory: `seeds/`, `fixtures/`, or `tests/fixtures/`.
3. Use factory functions over static JSON where possible — they are more flexible and type-safe.
4. Seed data must match the validation schemas exactly.

### Template

```typescript
// fixtures/user-profile.fixture.ts
import { type UserProfile } from '@/types/user-profile'

export function createUserProfile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'test-user-001',
    displayName: 'Test User',
    email: 'test@example.com',
    createdAt: new Date('2025-01-01'),
    ...overrides,
  }
}

export const userProfileFixtures = {
  standard: createUserProfile(),
  minimal: createUserProfile({ displayName: '', email: '' }),
  admin: createUserProfile({ role: 'admin' }),
}
```

### Agent Instructions for Seed Data

When an agent creates a schema or model, it should also create a corresponding fixture factory in the same commit if a test story references that model. The factory is committed by the implementing agent; the test-writer uses it.

---

## Selective Re-Verification Strategy

Used in Phase 4.2 after the first full verification sweep. Re-runs during subsequent fix iterations use selective scope to save time.

| Check | Re-run Strategy |
|-------|----------------|
| Type-check | Always re-run (full — type errors cascade) |
| Build | Always re-run (full — build errors cascade) |
| Tests | Re-run only tests in changed packages: `npm run test -- --filter <changed-packages>` |
| Lint | Re-lint only modified files: `npx eslint <modified-files>` |

Track time savings:
```
Verification: full sweep 45s → selective re-run 12s (73% faster)
```

The final fix round always gets one full sweep to catch cross-package regressions.

---

## Cross-Phase Regression Testing

Used in Phase 4.2.1 when `SPRINT_NUMBER > 1`.

1. **Identify pre-existing test files:**
   ```bash
   # Find test files that existed before this sprint started
   git diff --name-only --diff-filter=A ${SPRINT_BASE}..HEAD -- '*.test.*' '*.spec.*' > ${SESSION_TMP_DIR}/new-tests.txt
   git ls-files '*.test.*' '*.spec.*' | grep -v -F -f ${SESSION_TMP_DIR}/new-tests.txt > ${SESSION_TMP_DIR}/pre-existing-tests.txt
   ```

2. **Run pre-existing tests selectively:**
   ```bash
   cat ${SESSION_TMP_DIR}/pre-existing-tests.txt | xargs npx vitest run --reporter=verbose 2>&1
   ```

3. **Flag regressions as Critical:** Any pre-existing test that now fails is a **Critical** regression. These take priority over new test failures.

4. **Attempt fix (max 2 rounds):**
   - Round 1: Analyze. If new code changed behavior intentionally, update the old test. If unintentional, fix the new code.
   - Round 2: If still failing, document and flag for manual review.

5. **Report:**
   ```
   Cross-Phase Regression:
     Pre-existing tests: N
     Still passing: M
     Regressions found: K (Critical)
     Fixed: J
     Remaining: K-J (requires manual review)
   ```

---

## Final Output Template

Print summary to user:

```
Sprint ${SPRINT_NUMBER} implementation complete.
- Stories completed: X/Y
- Stories blocked: Z
- Build status: PASS/FAIL
- Type-check: PASS/FAIL (N errors)
- Tests: X passed, Y failed
- Integration issues fixed: N
- Branch: sprint-${SPRINT_NUMBER}/merged
```

---

## Error Recovery

- **Worktree creation fails**: Fall back to branch-only isolation (agents work on branches, merge sequentially).
- **Agent unresponsive**: After 3 message attempts with no response, mark agent as failed. Reassign stories to another agent or handle directly.
- **Merge conflicts**: Attempt auto-resolution for trivial conflicts (added-added in different sections). For complex conflicts, present to user with context from both sides. *(If autonomy is `high` or `full`, attempt auto-resolution for all conflicts. If auto-resolution fails, mark the conflicting stories as `blocked`, log the conflict details to the activity feed and STATE.md, and continue with remaining stories.)*
- **Build fails after merge**: Systematically fix by category. If unfixable in 5 rounds, create a detailed issue list and ask user for guidance. *(If autonomy is `high` or `full`, log the issue list to STATE.md and the activity feed, mark the sprint as `review` with integration issues noted, and exit. The next `/loop` tick or manual review will handle it.)*
- **All agents stuck**: Likely a fundamental design issue. Report the common blocker and ask user to intervene. *(If autonomy is `high` or `full`, mark all remaining stories as `blocked` with reason "all agents stuck", write STATE.md checkpoint, update sprint status to `review` with blocked stories noted, log to activity feed, and exit cleanly.)*

---

## Integration Agent Spawn + Fallback

Used in Phase 3.5.1.

**Weight class**: Medium (per [spawn-protocol.md](/_shared/spawn-protocol.md)).

**Spawn parameters**:
- `subagent_type: blitz:frontend-dev` (has Write + Edit — required for integration edits)
- `isolation: "worktree"` on a dedicated `sprint-${N}/integration` branch
- Budget declared in prompt: max 15 file reads, 25 tool calls, 5-min wall-clock
- Write-as-you-go: append a progress line to `${SESSION_TMP_DIR}/agent-ui-integrator-progress.md` after each checklist item completed
- HEARTBEAT protocol (same snippet as Phase 2.3 dev agents)

**Fallback if agent fails**:
- If the integration agent exits without completing the Integration Checklist, the orchestrator MUST:
  1. Read the progress file to identify which checklist items completed.
  2. For remaining items: either re-spawn with narrower scope (single checklist item) OR complete inline from the orchestrator if the remaining work is <3 checklist items.
  3. Do NOT proceed to Phase 3.5.3 Integration Commit until every checklist item is confirmed done (either by agent or orchestrator) — a silent half-integration shipped to main has been the most common sprint-dev failure pattern.

---

## Integration Checklist

Full item definitions for the integration agent (Phase 3.5.2):

1. **Navigation entries** — Any new pages/routes have corresponding nav entries in the app's navigation config.
2. **Design tokens** — New components use existing design tokens (colors, spacing, typography). No hardcoded values.
3. **Layout consistency** — New pages use the correct layout wrapper. Responsive breakpoints match existing patterns.
4. **State wiring** — All new stores are properly initialized. Composables are registered where framework requires it.
5. **Accessibility** — New interactive elements have proper ARIA attributes, keyboard navigation, focus management.
6. **Loading states** — Async operations show loading indicators. Error states are handled.
7. **Route guards** — Protected routes have appropriate auth guards if the project uses authentication.

---

## KNOWLEDGE.md Slice Procedure

Phase 0.6 of `SKILL.md`. Build a relevance slice of `.cc-sessions/KNOWLEDGE.md` for injection into every dev-agent prompt (spec item 14). Per [knowledge-protocol.md](/_shared/knowledge-protocol.md).

```bash
KNOWLEDGE_FILE=".cc-sessions/KNOWLEDGE.md"
KNOWLEDGE_SLICE_FILE="${SESSION_TMP_DIR}/knowledge-slice.md"

if [ "${BLITZ_SKIP_KNOWLEDGE_INJECTION:-0}" = "1" ]; then
  : > "$KNOWLEDGE_SLICE_FILE"
  echo "[sprint-dev] KNOWLEDGE.md injection skipped (BLITZ_SKIP_KNOWLEDGE_INJECTION=1)"
elif [ -s "$KNOWLEDGE_FILE" ]; then
  # Default: last 30 lines (recency bias). Future: keyword-grep by story file paths.
  tail -30 "$KNOWLEDGE_FILE" > "$KNOWLEDGE_SLICE_FILE"
  echo "[sprint-dev] KNOWLEDGE.md slice: $(wc -l < "$KNOWLEDGE_SLICE_FILE") lines"
else
  : > "$KNOWLEDGE_SLICE_FILE"
  echo "[sprint-dev] KNOWLEDGE.md absent — no project lessons to inject"
fi
```

Opt-out (`BLITZ_SKIP_KNOWLEDGE_INJECTION=1`) is for debugging an agent loop suspected to be biased by stale lessons. Default-on otherwise.

Future slicing strategy (not yet implemented): grep entries by topic keywords matching the current sprint's story file paths. For now, tail-30 is the recency proxy.

---

## Pre-Flight Complexity Gate

Phase 1.4.5 of `SKILL.md`. Heuristic scoring to abort over-large sprints before agent spawn (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P5).

```bash
STORY_COUNT=$(ls -1 "${SPRINT_DIR}/stories/"S*.md 2>/dev/null | wc -l)
LOC_EST=$(awk '/^estimated_loc:/ {s+=$2} END {print s+0}' "${SPRINT_DIR}/stories/"S*.md 2>/dev/null)
COMPLEXITY=$(( STORY_COUNT * 2 + LOC_EST / 100 ))

echo "[sprint-dev] complexity_score=${COMPLEXITY} (stories=${STORY_COUNT}, est_loc=${LOC_EST})"

if [ "$COMPLEXITY" -gt 80 ] && [ "${BLITZ_SPRINT_COMPLEXITY_OVERRIDE:-0}" != "1" ]; then
  echo "[sprint-dev] HARD STOP: complexity=${COMPLEXITY} > 80." >&2
  echo "[sprint-dev]   Split this sprint into smaller chunks via /blitz:sprint-plan." >&2
  echo "[sprint-dev]   Override (not recommended): BLITZ_SPRINT_COMPLEXITY_OVERRIDE=1" >&2
  exit 1
elif [ "$COMPLEXITY" -gt 40 ]; then
  echo "[sprint-dev] WARN: complexity=${COMPLEXITY} > 40. Consider splitting." >&2
fi
```

Thresholds (40 warn, 80 hard-stop) are heuristic. Calibrate against project history before locking in. Stories without `estimated_loc:` contribute 0 to the LOC term — bias is toward letting work proceed when metadata is missing.

---

## Dev Agent Prompt Specification

Every dev agent prompt (Phase 2.3) must include all 14 items:

1. Agent role and responsibilities (see the agent-specific prompt templates in this references/main.md).
2. List of assigned stories in dependency order, with their `verify` and `done` fields. Capped at 4 stories per wave per agent.
3. **Budget declaration** (add verbatim to prompt):
   ```
   BUDGET:
   - Max stories this wave: 4 (already enforced by orchestrator)
   - Max file reads per story: 6
   - Max tool calls total: 40 (if you hit 30, finish current story and stop)
   - Wall-clock: 8 min
   ```
4. Project conventions (detected stack, coding patterns, naming conventions).
5. Commit message format: `feat(sprint-${N}/<role>): S${N}-XXX <description>`.
6. Project conventions guide from Phase 0.5 (full text, not a file reference).
7. Reusable assets list — composables, utilities, and shared components agents must use.
8. Anti-mock rules — Every function must be fully implemented, no placeholders. See [Definition of Done](/_shared/definition-of-done.md).
9. Deviation handling rules — Follow the [Deviation Handling Protocol](/_shared/deviation-protocol.md). Auto-fix small issues, report deviations, escalate architectural changes.
10. Wave assignment — Tell each agent which wave their stories belong to, so they understand the execution order context.
11. Context management rules — Follow the [Context Management Protocol](/_shared/context-management.md). Self-contained DONE summaries, reference files by path not memory, compact verification output, prune context between stories.
12. **HEARTBEAT + PARTIAL protocol** (add verbatim to prompt):
    ```
    HEARTBEAT: After each story DONE, write a file ${SESSION_TMP_DIR}/agent-<role>-progress.md
    appending: HEARTBEAT: S${N}-XXX done at <ISO-timestamp>. Use date -u +%Y-%m-%dT%H:%M:%SZ.

    PARTIAL: If you have fewer than 3 tool calls remaining, STOP before starting
    a new story. Append to your progress file:
      PARTIAL: true
      COMPLETED: [list of story ids finished]
      REMAINING: [list of story ids unstarted]
      CONFIDENCE: low|medium|high
    Send PARTIAL: <N> done, <M> remaining to orchestrator via the DONE/BLOCKED
    protocol and end.
    ```
13. **Package install policy** — for any new dependency, follow [/_shared/package-install-policy.md](/_shared/package-install-policy.md). Inject this verbatim block:
    ```
    PACKAGE INSTALLS: never invent a version number from memory. Use bare
    `pnpm add <pkg>` (or the project's package manager) so it resolves to
    the registry latest. Pin to a specific version ONLY if (a) the user
    asked for that version, OR (b) a peer-compatibility constraint forces it.
    Verify after install: npm view <pkg> version vs the resolved version.
    ```
14. **Project Lessons block** — inject the KNOWLEDGE.md slice computed in SKILL.md Phase 0.6. Per [knowledge-protocol.md](/_shared/knowledge-protocol.md), this surfaces project-specific gotchas before generation, counteracting training-data bias (per `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` P1/F2). Inject verbatim:
    ```
    ## Project Lessons (from .cc-sessions/KNOWLEDGE.md)
    <contents of ${KNOWLEDGE_SLICE_FILE} — last 30 lines>

    Consult these before generating code. If a lesson applies to your story,
    follow it. If it conflicts with story instructions, raise via DEVIATION:
    rather than silently overriding.
    ```
    If `KNOWLEDGE_SLICE_FILE` is empty (no KNOWLEDGE.md or `BLITZ_SKIP_KNOWLEDGE_INJECTION=1`), omit this block entirely — do NOT inject an empty header.

---

## Communication Prefix Table

Used by dev agents and orchestrator in Phase 3.3.

| Prefix | Direction | Purpose |
|---|---|---|
| `DONE:` | Agent -> Orchestrator | Story completed, requesting next |
| `BLOCKED:` | Agent -> Orchestrator | Cannot proceed, needs help |
| `DEVIATION:` | Agent -> Orchestrator | Auto-added code outside story scope (see [deviation-protocol.md](/_shared/deviation-protocol.md)) |
| `ESCALATE:` | Agent -> Orchestrator | Needs decision on architectural/scope change |
| `UNBLOCK:` | Orchestrator -> Agent | Dependency resolved, new story available |
| `ASSIST:` | Orchestrator -> Agent | Help with current issue |
| `SYNC:` | Orchestrator -> Agent | File paths or exports from another agent |
| `HALT:` | Orchestrator -> Agent | Stop current work (critical issue) |
