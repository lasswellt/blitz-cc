# Test conventions (inlined into the dev spawn prompt)

`build` pastes this file below the `ROLE: test` line of a `dev` spawn when a task's `files[]` is test files only. The full test-authoring contract (stack detection, AAA pattern, factories, component and rules-test patterns, spec-fix oracle, per-spec turn cap, coverage awareness) is `agents/test-writer.md`; read it before editing. Deterministic-test recipes and the mocking policy: `skills/test-gen/references/deterministic-tests.md`.

## What a test-role dev does differently

| Generic `dev` rule | `ROLE: test` |
|---|---|
| Never edit test files | Edits **only** test files (`*.test.*`, `*.spec.*`, `__tests__/**`, fixtures/factories the task lists). Source files are in the never-edit list; a source change the tests need is `BLOCKED` with `scope-expansion-needed`. |
| Make `verify[]` pass by implementing behavior | Make `verify[]` pass by writing or repairing tests that exercise the existing implementation. |
| JSDoc on exports | Test names follow "should [expected behavior] when [condition]"; factories over inline literals. |

## Never weaken assertions

- Never delete, skip (`it.skip`, `xit`, `describe.skip`, `.only`), or loosen an assertion to reach green (registry `det-01`, `det-02`, reject).
- Never replace a specific matcher with `toBeDefined()` / `toBeTruthy()` when the shape matters.
- Never assert only on mock calls (`toHaveBeenCalled`) when a result is observable.
- If a failing test's expected output cannot be derived from the assertions and the spec, stop: `ESCALATE: oracle-underivable`. `build` maps it to `blocked_reason: oracle-underivable` on the task.
- If the test itself looks wrong, stop: `ESCALATE: test-assertion-suspect`. Never rewrite the assertion to match the implementation.

## Mocking

Mock the network, clocks, randomness, and third-party SaaS at the wire; never the module under test, its `src/` collaborators, Firestore rules (use the emulator), or the store a test exercises. A `vi.mock` of a path under `src/` raises the `mocks_in_src` ratchet (`det-03`). Full policy: `skills/test-gen/references/deterministic-tests.md` §Mocking policy.

## Reply

Same status enum and JSON block as `agents/dev.md`. `verify[]` tails paste the runner's summary line (`Tests  12 passed (12)`), not the full log. Budget: 10 tool calls per failing spec; on exhaustion reply `BLOCKED` with `escalate: "ESCALATE: spec-investigation-budget-exhausted"` and the last three hypotheses in `summary`.
