---
type: llm
weight: 3
---

PASS if the final reply is a check report for plan `demo` with verdict PASS and a critic LGTM, T-001 verified through `scripts/tasks.sh verify`, and no P0/P1 finding. Advisory or style notes parked under "Later" are fine.
FAIL if the verdict is FAIL or CONDITIONAL, if the critic REJECTs, if a P0/P1 finding is raised against this correct implementation (a false block), if Claude edited `src/` or `test/`, or if the verify commands were never run.
