# Deterministic tests — patterns for async / timing / mock-heavy specs

Author-time guidance for `/blitz:test-gen` and `agents/test-writer.md`. Read it when the target code shows any signal in the table below; apply the patterns that fit. Not hook-enforced: a flaky spec surfaces later through `check` (`tasks.sh verify` reruns the task's `verify[]`), and the lesson goes to `docs/solutions/` via `learn`.
Moved from `quality-engine.md` §Deterministic Test Recipe (v3.0.0); the policy half of testing (DoD, anti-mock rows, ratchet `mocks_in_src`) lives in [quality.md](/_shared/quality.md).
Scope: Vitest and Jest recipes, seeded randomness, MSW, property-based tests, and the mocking policy at the end.

**Sourced from**:
- [Claude Code best practices — Anthropic](https://code.claude.com/docs/en/best-practices) — verification-first principle
- [trunk.io — How to avoid flaky tests in vitest](https://trunk.io/blog/how-to-avoid-and-detect-flaky-tests-in-vitest)
- [fast-check.dev — Beyond flaky tests: controlled randomness](https://fast-check.dev/blog/2025/03/28/beyond-flaky-tests-bringing-controlled-randomness-to-vitest/)
- [Vitest fake timers docs](https://vitest.dev/api/vi.html#vi-usefaketimers)
- `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` F3 (failure modes and footgun warnings)

---

## When to consult this recipe

Signals in the target code that flag a deterministic-test recipe is warranted:

| Signal | Threshold | Why it matters |
|---|---|---|
| `setTimeout` / `setInterval` / `requestAnimationFrame` | any | Timing is non-deterministic without fake timers |
| `Math.random` / `crypto.randomUUID` / `Date.now` / `performance.now` | any in production code | Stochastic outputs vary between runs |
| `fetch` / `axios` / API client | any | Network latency is non-deterministic |
| `await` chains with ≥3 promises | structural | Promise scheduling order can vary |
| Singletons / module-scope state | any | Test ordering can leak state |
| `vi.mock` / `jest.mock` chains | ≥5 in one file | Mock isolation hazards compound |

When any of these are present, prefer the recipe sections below over a default test setup.

To pick **which** specs to run while iterating on a fix, use `scripts/test-selector.sh <changed files>` (sibling + import graph + journal recent-fail / co-change; `--full` on config or lockfile changes) rather than hand-listing files — the selected set is what the heartbeat and the Stop gate run, so a spec that stays green here stays green there.

---

## Vitest recipe

### Fake timers — async-safe

```ts
import { vi } from 'vitest'

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

it('resolves after delay', async () => {
  const promise = something()
  // CRITICAL: async variant — sync advanceTimersByTime deadlocks on
  // promise + timer chains
  await vi.advanceTimersByTimeAsync(1000)
  await expect(promise).resolves.toBe('done')
})
```

**Footgun**: `vi.advanceTimersByTime(N)` (no `Async`) deadlocks when the test code has `await` between the timer and the assertion. Use `advanceTimersByTimeAsync` when ANY async is in the chain. Symptom: test hangs until Vitest timeout.

### Seeded randomness

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    sequence: { seed: 12345 },        // deterministic file/test order
    env: { TEST_SEED: '12345' },      // pass to seeded RNG in test helpers
  },
})

// In test file
import { fc, test } from '@fast-check/vitest'

test.prop([fc.integer()])('handles any integer', (n) => {
  expect(process(n)).not.toThrow()
})
// Every failure includes the seed for reproduction
```

### `isolate: false` (faster but risky)

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    isolate: false,   // skip per-test isolation; faster, but...
  },
})
```

**Footgun**: shared module state leaks between tests. Use only when state is proven shared-immutable (e.g., pure-function modules). For tests with mocks or singletons, leave `isolate: true` (default).

### MSW (Mock Service Worker)

Prefer MSW handlers over `vi.mock()` for HTTP calls:

```ts
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

const server = setupServer(
  http.get('/api/users/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, name: 'Test User' })
  ),
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

Why prefer over `vi.mock('axios')`: MSW handles the wire format, so test code uses the real HTTP client. Mocking the client hides serialization bugs.

---

## Jest recipe

### Fake timers — `modern` and await

```ts
beforeEach(() => {
  jest.useFakeTimers()     // 'modern' is default in Jest 27+
})

afterEach(() => {
  jest.useRealTimers()
})

it('resolves after delay', async () => {
  const promise = something()
  jest.advanceTimersByTime(1000)   // sync — fine here
  await Promise.resolve()           // flush microtasks
  await expect(promise).resolves.toBe('done')
})
```

**Footgun**: unlike Vitest, Jest has no `advanceTimersByTimeAsync` variant. Manually flush microtasks via `await Promise.resolve()` or `await new Promise(setImmediate)` after the sync advance.

### Serial run

```bash
npx jest --runInBand            # single process, no worker non-determinism
npx jest --seed=12345           # deterministic test order (Jest 30+)
```

`--runInBand` is the most reliable lever when a flaky test reproduces only under parallel workers. Pays a wall-clock cost.

---

## Property-based testing (cross-runner)

`@fast-check/vitest` or `fast-check` with Jest:

```ts
import { fc } from 'fast-check'

it('reverse is involutive', () => {
  fc.assert(
    fc.property(fc.array(fc.string()), (xs) => {
      expect(reverse(reverse(xs))).toEqual(xs)
    }),
    { seed: 42, numRuns: 100 },
  )
})
```

Every failure is reproducible from `seed`. Shipped pattern from `fast-check.dev`.

---

## What this recipe does NOT cover

- **Multi-process orchestration** (Worker, child_process, browser-Node IPC) — fake timers don't span processes. Use real timers + generous `vi.setConfig({ testTimeout: N })`.
- **File-system race conditions** — tests that race on `fs.writeFile` / `fs.readFile`. Use `mock-fs` or scoped temp directories.
- **`Date.now` shifts mid-test** — `vi.setSystemTime(new Date('2026-01-01'))` works, but advances don't update unless you call it again.
- **Snapshot fragility for time-stamped output** — wrap in `expect(output.replace(/\d{4}-\d{2}-\d{2}/, 'DATE')).toMatchSnapshot()`.
- **`Promise.all` ordering** — fake timers don't guarantee scheduling order between promises; treat as a documented test-design limitation.

---

## Counter-evidence and caveats (must read before adopting)

Per `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` F3 + F6:

1. **Fake timers deadlock on async chains** (Vitest sync variant) — fix is the `Async` variant; tutorials often skip this.
2. **Determinism via low temperature is not absolute** — empirical study (arxiv 2509.19185, 39 frameworks, 439 apps) found non-determinism persists even with fixed low temperature and Top-P. This recipe addresses runtime determinism; LLM-generation determinism is a separate concern.
3. **`isolate: false` leaks shared state** — only use when state is proven immutable.
4. **Property-based testing surfaces real bugs but inflates test runtime** — set `numRuns` modestly (50–200) unless investigating a specific class of inputs.
5. **MSW requires setup-file plumbing** — for one-off tests, a single `vi.mock` may be cheaper. Adopt MSW project-wide or skip.
6. **Spec-as-test trap** — 1-in-10 spurious passes where the output is right but the test assertion is wrong (per Monte Carlo Data, AI Agent Evaluation). Deterministic runners don't help here; the assertion has to be right.

---

## Mocking policy

Evidence: over 1.2M commits, agent-authored commits add mocks in 36% of cases vs 26% for human commits; tests that mock the unit under test pass while the product fails (see also SpecBench: visible tests saturate, held-out tests do not).

| Mock it | Never mock it |
|---|---|
| Network (`fetch`, `axios`, HTTP clients) — prefer MSW at the wire | The module under test, or its direct collaborators inside `src/` |
| Clocks (`Date.now`, `performance.now`, timers) — fake timers | Firestore security rules — run them in the emulator |
| Randomness (`Math.random`, `crypto.randomUUID`) — seeded RNG | Vue component internals (`setup`, computed, emitted events) — mount and assert |
| Third-party SaaS (payments, email, LLM APIs) — recorded handlers | Pinia stores when the store is what the test exercises |

Rules:

1. A `vi.mock` / `jest.mock` of a path under `src/` is a smell; every added mock in `src/` raises the `mocks_in_src` ratchet metric (registry `det-03`, P2 reject) and `check` flags the delta.
2. Prefer emulator-backed integration tests over mocks for Firebase code: `firebase emulators:exec --only firestore,functions "npx vitest run <file> --reporter=dot"` and `@firebase/rules-unit-testing` for rules assertions (`assertSucceeds` / `assertFails`).
3. A test whose only assertions are on mock calls (`toHaveBeenCalledWith`) does not count toward "new public functions have at least one test" (DoD §Testing).
4. When the oracle cannot be derived without mocking the unit itself, stop and reply `ESCALATE: oracle-underivable`; `build` records it as `blocked_reason`.

## Related

- [quality.md](/_shared/quality.md) — Definition of Done, anti-mock rows, ratchet metrics
- [agents.md](/_shared/agents.md) — test-writer reply enum and self-falsification rule
- [output.md](/_shared/output.md) — output style for test code (preserve verbatim per the boundary list)
