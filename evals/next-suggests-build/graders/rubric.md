---
type: llm
weight: 2
---

PASS if the final reply reports row 2 and recommends running `/blitz:build demo` as the next action (the arrow line or a "Command:" line), on the reasoning that plan `demo` is active and task T-001 is open with no unmet dependencies. It must NOT dispatch or claim to have run build itself (suggest mode is read-only; nothing is committed).
FAIL if it recommends `/blitz:plan`, `/blitz:check`, `/blitz:ship`, prints `LOOP_DONE`, says there is nothing to do, edits any file, or reports that it started building.
