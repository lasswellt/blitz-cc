---
type: llm
weight: 2
---

PASS if the final reply is a plugin health report whose overall verdict is HEALTHY (a line such as "Overall: HEALTHY"), with the plugin-structure checks (validate-plugin-structure, hook scripts, hooks.json, skill frontmatter, agent files, shared protocols) reported as PASS. Session-state rows reported as "0 found" or "none" and project-setup rows reported as INFO or "not a project" are expected in an empty workspace and are not failures.
FAIL if the overall verdict is DEGRADED or UNHEALTHY, if any plugin-structure row is FAIL, or if the reply is not a doctor report at all (e.g. it asks what to check, or reports it could not find the plugin).
