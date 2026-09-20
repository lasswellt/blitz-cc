---
description: check --scope repo on a Python + Rust repo with NO package.json must resolve this project's own checkers from the toolchain table and report their diagnostics. Guards against the loop regressing to Node-only. Needs --scaffold and Bash.
tags: [check, polyglot, needs-scaffold, needs-bash]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

/blitz:check --scope repo
