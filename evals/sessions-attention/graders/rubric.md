---
type: llm
weight: 2
---

PASS if the final reply presents an attention queue containing the session `build-a1b2c3d4` with its pending inbox item (a permission_denied about `npm publish`, needing an operator decision), and reports at least one attention item (e.g. "1 attention item").
FAIL if the reply prints `HEARTBEAT_OK` or "no sessions need attention", omits the pending inbox item, or lists some other session instead.
