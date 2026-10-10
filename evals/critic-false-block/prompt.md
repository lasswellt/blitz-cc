---
description: "Known-good fixture: a correct, tested, in-scope implementation. check --scope plan must end PASS with critic LGTM; a REJECT or FAIL is a false block. Run with --runs 5+ and read the pass rate. Needs --scaffold and Bash."
tags: [check, critic, needs-scaffold, needs-bash]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Agent]
---

/blitz:check --scope plan demo
