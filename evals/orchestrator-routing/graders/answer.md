---
type: llm
weight: 1
---

PASS if the final reply is a session-status answer: it reports which Claude Code sessions are running / blocked / waiting for input (or states there are none, e.g. "HEARTBEAT_OK" or "no active sessions"), framed as session or attention-queue status.
FAIL if the reply talks about system processes (ps, top, CPU), asks the user what they mean, or answers a different question.
