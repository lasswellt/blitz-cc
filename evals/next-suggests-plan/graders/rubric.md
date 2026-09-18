---
type: llm
weight: 2
---

PASS if the final reply recommends running `/blitz:sprint-plan` as the next action (the primary "Command:" or recommendation line), on the reasoning that a roadmap with an unstarted epic exists and no sprint has been planned yet. It must NOT dispatch or claim to have run sprint-plan itself (suggest mode is read-only).
FAIL if it recommends `/blitz:implement`, `/blitz:sprint-review`, `/blitz:ship`, `/blitz:roadmap full`, or says there is nothing to do; or if it reports that it started planning a sprint.
