---
description: "A one-sentence, one-file change goes through build's inline path: the edit is made on the main thread, the fixture test is run, and no docs/plans/ directory or dev agent is created. Needs --scaffold and Bash."
tags: [build, needs-scaffold, needs-bash]
max_turns: 25
allowed_tools: [Read, Glob, Grep, Edit, Write, Skill, Bash]
---

/blitz:build "make greet() trim surrounding whitespace from name before greeting"
