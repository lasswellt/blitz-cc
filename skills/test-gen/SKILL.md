---
name: test-gen
description: "Generates tests for target files matching the project's existing test conventions (Vitest/Jest, AAA/BDD style, factory patterns). Analyzes untested functions, edge cases, and error paths. Runs each generated test to verify it passes. Use when the user says 'add tests', 'generate tests for', 'test coverage', 'write tests', 'cover this file with tests'. Especially valuable after sprint-dev completes if test coverage gaps remain."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<file-path>"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For Vitest/Jest patterns, Vue component testing, and Firestore rules testing, see [references/main.md](references/main.md)
- For deterministic test patterns on async/timing/mock-heavy targets (fake-timer footguns, seeded randomness, MSW vs `vi.mock`), see [/_shared/deterministic-test-recipe.md](/_shared/deterministic-test-recipe.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Test Generation Skill

Generate tests for a target file by analyzing its exports, parameters, side effects, and error conditions. Follow project conventions, run tests to verify, and report coverage. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE TARGET — Identify What to Test

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Arguments

Extract the target file path from `$ARGUMENTS`. If not provided, ask the user.

Validate the file exists:
```bash
[ -f "<target-file>" ] && echo "FOUND" || echo "NOT FOUND"
```

### 0.2 Classify Target

Determine the target type:

| Type | Detection | Test Strategy |
|------|-----------|---------------|
| **Utility / Helper** | `utils/`, `helpers/`, `lib/`, pure functions | Unit tests with input/output pairs |
| **Store / State** | `stores/`, `state/`, Pinia/Vuex store | State mutation tests, action tests |
| **Composable** | `composables/`, `use*.ts` | Reactive behavior tests, lifecycle tests |
| **Component** | `*.vue`, `components/` | Mount tests, prop/emit tests, slot tests |
| **API Route / Handler** | `server/`, `api/`, `routes/`, `functions/` | Request/response tests, error handling |
| **Schema / Validator** | `schemas/`, `validators/`, Zod/Yup | Valid/invalid input tests, edge cases |
| **Middleware** | `middleware/`, `guards/` | Pass-through and rejection tests |
| **Configuration** | `config/`, `*.config.*` | Validation tests for config shape |

---

## Phase 1: DISCOVER — Analyze Target and Project Conventions

### 1.1 Analyze Target File

Read the target file and extract:
- **Exports**: Every exported function, class, type, constant, or default export
- **Parameters**: For each function, its parameter types and optional/required status
- **Return types**: What each function returns (including Promise types for async)
- **Side effects**: API calls, file writes, store mutations, event emissions
- **Error conditions**: try/catch blocks, thrown errors, error return paths
- **Dependencies**: What the file imports (these may need mocking)
- **Branching logic**: if/else, switch, ternary (each branch needs a test)

### 1.2 Find Existing Test Patterns (Broad Discovery)

Search for ALL test files in the project:
```bash
find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | head -40
```

Read from **3 categories** (minimum 6 files total):

**Category A — Same type as target** (2-3 files):
Tests for similar files in the same directory pattern as the target. These show how code like yours is typically tested.

**Category B — Well-established tests** (2 files):
The largest/most comprehensive test files in the project. These reveal the team's full testing vocabulary (custom matchers, setup patterns, assertion depth).

**Category C — Test utilities/factories** (all found):
```bash
find . -path "*/test*" -name "*.ts" -o -path "*/test*" -name "*.js" | grep -E "(helper|util|setup|factory|fixture|mock)" | grep -v node_modules | head -10
```
Helper files, factories, mock setups. These are shared infrastructure you MUST use.

From these files, extract:
- **Test runner**: Vitest (`import { describe, it, expect } from 'vitest'`) or Jest (globals or imports)
- **File naming**: `*.test.ts` vs `*.spec.ts` vs `__tests__/*.ts`
- **File location**: Co-located (next to source) vs centralized (`tests/` directory)
- **Import style**: Named imports, default imports, barrel imports
- **Mocking strategy**: `vi.mock()` vs `jest.mock()`, manual mocks, fixture factories
- **Assertion depth**: Shallow (`toBeDefined`) vs deep (`toEqual` with full shape)
- **Setup/teardown**: `beforeEach`, `afterEach`, `beforeAll`, factory functions
- **Factory patterns**: How test data is constructed (factory functions, fixtures, inline)
- **Custom matchers**: Any project-specific matchers or assertion helpers
- **Describe/it style**: Nested describes, BDD style ("should..."), or flat

### 1.3 Detect Test Runner

```bash
# Check package.json for test runner
if grep -q '"vitest"' package.json 2>/dev/null; then
  echo "RUNNER: vitest"
elif grep -q '"jest"' package.json 2>/dev/null; then
  echo "RUNNER: jest"
else
  echo "RUNNER: unknown"
fi
```

### 1.4 Check for Existing Tests

Does the target file already have tests?
```bash
TARGET_NAME=$(basename "<target-file>" | sed 's/\.[^.]*$//')
find . -name "${TARGET_NAME}.test.*" -o -name "${TARGET_NAME}.spec.*" | grep -v node_modules
```

If tests exist:
- Read them to understand what is already covered.
- Generate tests ONLY for uncovered exports, branches, and edge cases.
- Do NOT duplicate existing tests.

### 1.5 Check for Test Utilities

Search for existing test helpers:
```bash
find . -path "*/test*" -name "*.ts" -o -path "*/test*" -name "*.js" | grep -E "(helper|util|setup|factory|fixture|mock)" | grep -v node_modules | head -10
```

If factories or fixtures exist, use them instead of creating inline test data.

---

## Phase 2: PLAN — Design Test Cases

### 2.1 Generate Test Cases

For each exported function/component/composable, generate test cases following the AAA pattern (Arrange, Act, Assert):

#### For Functions:
| Category | Test Cases |
|----------|-----------|
| **Happy path** | Call with valid, typical inputs. Verify expected output. |
| **Edge cases** | Empty arrays, zero values, empty strings, boundary values |
| **Null/undefined** | Null input, undefined optional params, missing fields |
| **Error paths** | Invalid input, network failures, permission denied |
| **Type boundaries** | Max integers, very long strings, deeply nested objects |
| **Async behavior** | Resolved promises, rejected promises, timeout scenarios |

#### For Components:
| Category | Test Cases |
|----------|-----------|
| **Render** | Mounts without error with required props |
| **Props** | Each prop produces expected rendering |
| **Events** | User interactions emit correct events with payloads |
| **Slots** | Named slots render provided content |
| **States** | Loading, empty, error, populated states render correctly |
| **Reactivity** | Prop changes trigger re-renders |

#### For Stores:
| Category | Test Cases |
|----------|-----------|
| **Initial state** | Store initializes with correct defaults |
| **Actions** | Each action produces expected state changes |
| **Getters** | Computed values derive correctly from state |
| **Error handling** | Failed actions set error state |
| **Reset** | Store resets to initial state |

### 2.2 Prioritize Test Cases

Order by value:
1. Happy path (ensures basic functionality works)
2. Error paths (ensures failures are handled)
3. Edge cases (ensures robustness)
4. Boundary conditions (ensures correctness at limits)

### 2.3 Determine Mocking Strategy

For each external dependency:
- **API calls**: Mock the HTTP client or fetch
- **Stores**: Mock the store or provide a real store with test data
- **Router**: Mock `useRouter` / `useRoute`
- **External services**: Mock the service client
- **File system**: Mock fs operations
- **Time**: Mock `Date.now()`, timers if time-dependent logic exists

---

## Phase 3: IMPLEMENT — Write Tests

### 3.1 Determine Test File Path

Follow the project's convention discovered in Phase 1:
```
# Co-located (most common)
src/utils/format.ts      -> src/utils/format.test.ts

# Centralized
src/utils/format.ts      -> tests/unit/utils/format.test.ts

# Match existing pattern (*.spec.* vs *.test.*)
```

### 3.2 Write Test File

Generate the test file following project conventions. Use the AAA pattern for every test:

```typescript
// ARRANGE — Set up test data and mocks
// ACT — Call the function or trigger the behavior
// ASSERT — Verify the result
```

**Test file structure:**
1. Imports (test runner, target module, mocks, utilities)
2. Mock setup (top-level mocks)
3. Describe block per exported function/component
4. Nested describe for categories (happy path, error cases, edge cases)
5. Individual `it` blocks following BDD naming ("should return X when Y")

### 3.3 Implementation Rules

- **One assertion focus per test.** A test can have multiple `expect` calls, but they should all verify the same behavior.
- **No test interdependence.** Tests must pass in any order. Use `beforeEach` to reset state.
- **Descriptive names.** Test names should read as documentation: `it('should return empty array when input is null')`.
- **Real types, mock data.** Use the project's TypeScript types for test data. Satisfy the type system.
- **No network calls.** All external calls must be mocked.
- **Clean up.** If a test creates side effects, clean them in `afterEach`.
- **Follow existing patterns.** If the project uses factory functions, use them. If it uses inline objects, do the same.

### 3.4 Test Integrity Gate

Every generated test must verify real behavior. See [Definition of Done](/_shared/definition-of-done.md).

**BANNED in generated tests:**
- `expect(true).toBe(true)` or equivalent no-op assertions
- Tests that only assert `.toBeDefined()` when the shape matters
- Tests that pass regardless of implementation changes
- `it.skip` or `describe.skip` — no skipped tests in delivered work

---

## UI Framework Variants

### When Testing Vue Components (Vue Test Utils)

```typescript
import { mount, shallowMount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'

// Mount with required plugins
const wrapper = mount(Component, {
  props: { /* ... */ },
  global: {
    plugins: [createTestingPinia()],
    stubs: { /* stub child components */ },
  },
})
```

### When Testing with Tailwind CSS

- Do NOT test Tailwind class presence (classes are implementation details).
- Test rendered content, visibility, and behavior instead.
- Use `wrapper.text()`, `wrapper.find()`, `wrapper.emitted()`.

### When Testing Quasar Components

```typescript
import { installQuasarPlugin } from '@quasar/quasar-app-extension-testing-unit-vitest'

installQuasarPlugin()

// Quasar components are available globally after plugin install
const wrapper = mount(Component, {
  props: { /* ... */ },
})

// Test Quasar-specific features
expect(wrapper.findComponent({ name: 'QBtn' }).exists()).toBe(true)
```

### When Testing Vuetify Components

```typescript
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'

const vuetify = createVuetify({ components })

const wrapper = mount(Component, {
  props: { /* ... */ },
  global: {
    plugins: [vuetify],
  },
})
```

### When Testing Firestore Rules

See references/main.md for the Firestore rules testing pattern using `@firebase/rules-unit-testing`.

---

## Phase 4: VERIFY — Run and Validate Tests

### 4.1 Run Generated Tests

```bash
# Run only the new test file for fast feedback
<TEST_CMD> <test-file-path> 2>&1
```

### 4.2 Handle Failures

For each failing test:

| Failure Type | Action |
|---|---|
| **Import error** | Fix import path or missing mock |
| **Type error** | Fix test data to match TypeScript types |
| **Mock not working** | Adjust mock setup (wrong module path, missing return value) |
| **Assertion wrong** | Re-read the source code; the assertion may be incorrect |
| **Source bug found** | The test is correct and found a real bug. Keep the test, note the bug. |
| **Timeout** | Add proper async handling (`await`, `vi.useFakeTimers()`) |

Fix and re-run until all tests pass. Maximum 5 fix iterations.

### 4.3 Run Full Test Suite

After the new tests pass individually, run the full suite:
```bash
<TEST_CMD> 2>&1 | tail -50
```

Verify no existing tests broke.

### 4.4 Coverage Report (if available)

```bash
# Vitest
npx vitest run --coverage <test-file-path> 2>&1 | tail -30

# Jest
npx jest --coverage <test-file-path> 2>&1 | tail -30
```

If a coverage tool is configured, report:
- **Statements**: X%
- **Branches**: X%
- **Functions**: X%
- **Lines**: X%

If no coverage tool is configured, estimate coverage based on the test cases generated vs exports analyzed.

---

## Phase 5: REPORT — Summarize Results

### 5.1 Output Summary

```
Tests Generated: <target-file>
==============================
Test file: <test-file-path>
Test runner: <Vitest | Jest>
Tests written: <count>
Tests passing: <count>
Tests failing: <count>

Coverage:
  Exports tested: <N>/<total>
  Branches covered: <estimated>
  Error paths tested: <N>

Test Breakdown:
  Happy path:     <N> tests
  Error handling:  <N> tests
  Edge cases:      <N> tests
  Boundary:        <N> tests
```

### 5.2 Note Untested Areas

List anything that was NOT tested and why:
- Private functions (not exported, tested indirectly)
- Complex integration scenarios (would require full environment)
- Visual rendering (requires browser testing, not unit tests)

### 5.3 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Target is a Vue component | `browse` | Visual regression test in the browser |
| Low branch coverage | `test-gen` on related files | Increase overall coverage |
| Source bugs discovered by tests | `fix-issue` | Fix the bugs the tests revealed |
| Component has complex UI interactions | `browse` | E2E interaction testing |

---

## Error Recovery

Specific recovery procedures for common test generation failures:

| # | Scenario | Detection | Recovery |
|---|----------|-----------|----------|
| 1 | **No test runner detected** | No vitest/jest in package.json, no test config files | Ask user which runner to use. If uncertain, suggest Vitest. Generate config file if needed. |
| 2 | **Target has no exports** | No `export` keywords found | Check for default export or side-effect modules. For side-effect modules, test observable effects. If truly nothing to test, inform user. |
| 3 | **Mock setup fails** | `vi.mock()` or `jest.mock()` throws | Verify module path is correct (relative vs alias). Check if the module uses default vs named exports. Try manual mock in `__mocks__/` directory. |
| 4 | **Vue mount crashes** | `mount()` or `shallowMount()` throws during test | Check for missing global plugins (Pinia, Router, Quasar, Vuetify). Add required plugins to `global.plugins`. Try `shallowMount` instead of `mount`. |
| 5 | **Async test hangs** | Test times out without resolving | Add explicit `vi.useFakeTimers()` for timer-dependent code. Ensure all promises are awaited. Add `vi.runAllTimers()` after triggering async operations. Set explicit timeout: `it('...', async () => {...}, 10000)`. |
| 6 | **Import resolution fails** | Module not found errors | Check for path aliases (`@/`, `~/`, `#imports`). Verify tsconfig paths are configured for the test runner. Add `resolve.alias` to vitest/jest config if needed. |
| 7 | **Type errors in test file** | TypeScript compilation errors | Ensure test data satisfies the full interface (not partial). Use `as` casting only as last resort. Check if `@types/*` packages are installed for test utilities. |
| 8 | **Snapshot mismatch** | Snapshot tests fail on first run | Do not use snapshot tests in generated code — prefer explicit assertions. If project uses snapshots extensively, generate with `--updateSnapshot` flag on first run only. |
| 9 | **Environment mismatch** | `document`, `window`, or DOM APIs unavailable | Check vitest/jest environment config. Set `environment: 'jsdom'` or `environment: 'happy-dom'` in test config or per-file with `@vitest-environment jsdom` comment. |
| 10 | **Max retry exceeded** | 5 fix iterations completed, tests still failing | Stop attempting fixes. Present the remaining failures to the user with: (a) which tests pass, (b) which tests fail and why, (c) suggested manual fixes. Do not delete failing tests — they may reveal real bugs. |
