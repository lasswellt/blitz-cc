# Deterministic Test Recipe — patterns for async / timing / mock-heavy specs

Reference protocol. Documents patterns that reduce test flakiness when generating or fixing tests for code involving async operations, timers, randomness, shared state, or external services. Consulted by `agents/test-writer.md` and `skills/test-gen/SKILL.md` when the target code has signals of this class. **Not auto-enforced** — the agent decides when to apply.

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

## Related

- [agent-prompt-boilerplate.md](agent-prompt-boilerplate.md) — Self-Falsification rule (artifact-construction discipline; complementary to verification-first principle here)
- [knowledge-protocol.md](knowledge-protocol.md) — capture "this async pattern stalled before" lessons here for future test-writer dispatches
- [terse-output.md](terse-output.md) — output style for test code itself (preserve verbatim per the boundary list)

---

## Status

**Author-time reference.** No agent is auto-required to consult this. The expected pattern: when `agents/test-writer.md` or `skills/test-gen/SKILL.md` detects the signals listed above in the target code, the agent reads this file and applies the patterns that fit. If the agent skips this consultation and the test ends up flaky, the issue surfaces via the normal sprint-review path — at which point an entry can be added to `.cc-sessions/KNOWLEDGE.md` flagging the missed-signal pattern for future runs.

Behavioral enforcement (mandatory consultation, classifier-driven routing, etc.) is deferred per the v1.13 evaluation — Option A in `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` summary.
