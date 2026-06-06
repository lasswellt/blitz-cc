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
- For deterministic test patterns on async/timing/mock-heavy targets (fake-timer footguns, seeded randomness, MSW vs `vi.mock`), see [/_shared/quality-engine.md](/_shared/quality-engine.md)
- For Spec Fix Mode (HARD_SPEC classifier, verification-first oracle template, per-spec turn cap) when fixing failing specs, see [`agents/test-writer.md`](/agents/test-writer.md) §Spec Fix Mode
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Test Generation Skill

Generate tests for a target file by analyzing its exports, parameters, side effects, and error conditions. Follow project conventions, run tests to verify, and report coverage. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE TARGET — Identify What to Test

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration (steps 1-9) and [terse-output.md](/_shared/terse-output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

Extract target file path from `$ARGUMENTS`. If not provided, ask the user. Validate:
```bash
[ -f "<target-file>" ] && echo "FOUND" || echo "NOT FOUND"
```

Classify target type:

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

Read target file and extract: exports (functions, classes, types, constants, default), parameter types and optional/required status, return types (including Promise types), side effects (API calls, store mutations, event emissions), error conditions (try/catch, thrown errors), dependencies (imports that may need mocking), branching logic (each branch needs a test).

### 1.2 Find Existing Test Patterns (Broad Discovery)

```bash
find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | head -40
```

Read from **3 categories** (minimum 6 files total):

**Category A — Same type as target** (2-3 files): Tests for similar files in the same directory pattern. Show how code like yours is typically tested.

**Category B — Well-established tests** (2 files): Largest/most comprehensive test files. Reveal full testing vocabulary (custom matchers, setup patterns, assertion depth).

**Category C — Test utilities/factories** (all found):
```bash
find . -path "*/test*" -name "*.ts" -o -path "*/test*" -name "*.js" | grep -E "(helper|util|setup|factory|fixture|mock)" | grep -v node_modules | head -10
```

Extract: test runner, file naming (`*.test.ts` vs `*.spec.ts`), file location (co-located vs centralized), import style, mocking strategy, assertion depth, setup/teardown patterns, factory patterns, custom matchers, describe/it style.

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

```bash
TARGET_NAME=$(basename "<target-file>" | sed 's/\.[^.]*$//')
find . -name "${TARGET_NAME}.test.*" -o -name "${TARGET_NAME}.spec.*" | grep -v node_modules
```

If tests exist: read them, generate tests ONLY for uncovered exports/branches/edge cases, do NOT duplicate.

### 1.5 Check for Test Utilities

```bash
find . -path "*/test*" -name "*.ts" -o -path "*/test*" -name "*.js" | grep -E "(helper|util|setup|factory|fixture|mock)" | grep -v node_modules | head -10
```

If factories or fixtures exist, use them instead of inline test data.

---

## Phase 2: PLAN — Design Test Cases

### 2.1 Generate Test Cases

For each exported function/component/composable, generate test cases following the AAA pattern (Arrange, Act, Assert):

**Functions:**
| Category | Test Cases |
|----------|-----------|
| **Happy path** | Call with valid, typical inputs. Verify expected output. |
| **Edge cases** | Empty arrays, zero values, empty strings, boundary values |
| **Null/undefined** | Null input, undefined optional params, missing fields |
| **Error paths** | Invalid input, network failures, permission denied |
| **Type boundaries** | Max integers, very long strings, deeply nested objects |
| **Async behavior** | Resolved promises, rejected promises, timeout scenarios |

**Components:**
| Category | Test Cases |
|----------|-----------|
| **Render** | Mounts without error with required props |
| **Props** | Each prop produces expected rendering |
| **Events** | User interactions emit correct events with payloads |
| **Slots** | Named slots render provided content |
| **States** | Loading, empty, error, populated states render correctly |
| **Reactivity** | Prop changes trigger re-renders |

**Stores:**
| Category | Test Cases |
|----------|-----------|
| **Initial state** | Store initializes with correct defaults |
| **Actions** | Each action produces expected state changes |
| **Getters** | Computed values derive correctly from state |
| **Error handling** | Failed actions set error state |
| **Reset** | Store resets to initial state |

### 2.2 Prioritize and Mock

Order: happy path → error paths → edge cases → boundary conditions.

Mock strategy per dependency type: API calls → mock HTTP client/fetch; stores → mock or provide with test data; router → mock `useRouter`/`useRoute`; external services → mock client; file system → mock fs; time-dependent → mock `Date.now()`, timers.

---

## Phase 3: IMPLEMENT — Write Tests

### 3.1 Determine Test File Path

Follow project convention from Phase 1:
```
# Co-located (most common)
src/utils/format.ts      -> src/utils/format.test.ts

# Centralized
src/utils/format.ts      -> tests/unit/utils/format.test.ts

# Match existing pattern (*.spec.* vs *.test.*)
```

### 3.2 Write Test File

Use the AAA pattern for every test:
```typescript
// ARRANGE — Set up test data and mocks
// ACT — Call the function or trigger the behavior
// ASSERT — Verify the result
```

Structure: imports → mock setup → describe block per export → nested describes per category → `it` blocks with BDD naming ("should return X when Y").

### 3.3 Implementation Rules

- One assertion focus per test (multiple `expect` calls OK if verifying the same behavior).
- No test interdependence — use `beforeEach` to reset state.
- Descriptive names: `it('should return empty array when input is null')`.
- Real types, mock data — satisfy the type system.
- No network calls — all external calls must be mocked.
- Clean up side effects in `afterEach`.
- Follow existing patterns (factories if project uses them, inline if not).

### 3.4 Test Integrity Gate

Every generated test must verify real behavior. See [Definition of Done](/_shared/sprint-contracts.md).

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

| Failure Type | Action |
|---|---|
| **Import error** | Fix import path or missing mock |
| **Type error** | Fix test data to match TypeScript types |
| **Mock not working** | Adjust mock setup (wrong module path, missing return value) |
| **Assertion wrong** | Re-read source code; assertion may be incorrect |
| **Source bug found** | Keep the test, note the bug |
| **Timeout** | Add proper async handling (`await`, `vi.useFakeTimers()`) |

Fix and re-run until all tests pass. Maximum 5 fix iterations.

### 4.3 Run Full Test Suite

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

Report Statements/Branches/Functions/Lines % if coverage tool configured; otherwise estimate from test cases vs exports analyzed.

---

## Phase 5: REPORT — Summarize Results

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

Note untested areas and why (private functions, complex integration scenarios, visual rendering).

Follow-up suggestions:

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Target is a Vue component | `browse` | Visual regression test in the browser |
| Low branch coverage | `test-gen` on related files | Increase overall coverage |
| Source bugs discovered by tests | `fix-issue` | Fix the bugs the tests revealed |
| Component has complex UI interactions | `browse` | E2E interaction testing |

---

## Error Recovery

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
