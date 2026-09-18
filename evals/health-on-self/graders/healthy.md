---
type: llm
weight: 2
---

PASS if the final reply is a plugin health summary whose overall verdict is HEALTHY (a line such as "Overall: HEALTHY"), with the structural validation, hook scripts, hooks.json, skill frontmatter, agent files and shared-protocol rows reported as PASS. Session / lock / activity-feed rows reported as "0 found" or "none" are expected in a fresh workspace and are not failures.
FAIL if the overall verdict is NEEDS ATTENTION or UNHEALTHY, if any structural row is FAIL, or if the reply is not a health report at all (e.g. it asks what to check, or reports it could not find the plugin).
