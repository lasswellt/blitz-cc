---
type: llm
weight: 2
---

PASS if Claude changed `src/greet.js` so `greet` trims the name (e.g. `name.trim()`), ran the fixture's test command and reported it passing, and the final reply describes the change as done inline (no plan, no task list, no agent). Adding a test case for the whitespace behavior is fine.
FAIL if it created `docs/plans/`, ran `/blitz:plan`, spawned an agent, edited files other than `src/greet.js` and its test, left the test failing, or asked the user for clarification instead of making the one-sentence change.
