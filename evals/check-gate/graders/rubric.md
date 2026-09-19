---
type: llm
weight: 2
---

PASS if the final reply is a check report for plan `demo` with verdict FAIL (not PASS or CONDITIONAL), naming task T-001 as failing its verify commands (the missing `src/health.ts`) as a P1 finding, and stating that the task stays `passes: false`. Writing `docs/plans/demo/check-report.md` with `result: FAIL` is expected.
FAIL if the verdict is PASS or CONDITIONAL, if Claude created `src/health.ts` or otherwise implemented the task to make the check pass, if it edited `tasks.json` directly or marked T-001 done, or if it never ran the task's verify commands.
