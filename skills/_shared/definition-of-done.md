# Definition of Done

Universal checklist every code-producing skill and agent must verify before marking work complete.

---

## Functional Completeness

- [ ] Every function is fully implemented with real logic
- [ ] Every acceptance criterion from the story/task is addressed
- [ ] Feature works end-to-end (not just one layer)
- [ ] All code paths produce meaningful results

---

## Anti-Mock Rules (CRITICAL — NON-NEGOTIABLE)

The following patterns are **BANNED** in production code. Any of these in delivered code means the work is NOT done.

| # | Banned Pattern | Why |
|---|---------------|-----|
| 1 | `return {}` / `return []` / `return null` as placeholder returns | Produces silent wrong behavior in production |
| 2 | `throw new Error('Not implemented')` / `throw new Error('TODO')` | Crash in production |
| 3 | Empty function bodies that should have logic | Feature silently does nothing |
| 4 | Hardcoded sample data posing as real data | App shows fake data to users |
| 5 | `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code should be | Incomplete delivery |
| 6 | Empty catch blocks that silently swallow errors | Hides failures, makes debugging impossible |
| 7 | Functions that only log and return without performing their stated purpose | Feature silently does nothing |
| 8 | Event handlers that are no-ops (`() => {}`) | User interactions do nothing |
| 9 | Store actions that return hardcoded data instead of calling real APIs | App displays stale/fake data |

### Self-Check

Before marking work as done, ask yourself for **every function you wrote**:

> "If this ran in production right now, would it actually work?"

If the answer is no, the work is not done.

---

## Scope Discipline (Karpathy Principle 2)

- [ ] No abstraction added unless the story explicitly required it
- [ ] No "future-proofing" not in the story (configurability, plugin hooks, generics)
- [ ] No error handling for scenarios the story does not mention
- [ ] No files modified outside the story's surgical scope (every changed line traces to an acceptance_check)
- [ ] If implementation exceeds ~150% of estimated story size, add a carry-forward note explaining why before marking complete

---

## Code Quality

- [ ] Type-check passes with zero new errors
- [ ] Lint passes with zero new errors
- [ ] No `any` types — use `unknown` with type guards if truly unknown
- [ ] No `console.log` left behind — use proper logger if needed
- [ ] No hardcoded secrets, API keys, or URLs — use environment variables
- [ ] No commented-out code blocks left in

---

## Security (Backend)

- [ ] Every callable function has an auth check
- [ ] Every endpoint validates authorization (not just authentication)
- [ ] No user input reaches the database without validation
- [ ] No PII in logs beyond user ID
- [ ] Error messages do not leak internal details (stack traces, DB schemas, etc.)

---

## Testing

- [ ] New public functions have at least one test
- [ ] Error paths are tested (not just happy path)
- [ ] Tests exercise real code — not just mock return values
- [ ] No `it.skip`, `xit`, or `describe.skip` left in test files

---

## Build

- [ ] Project builds successfully
- [ ] No new build warnings introduced


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
