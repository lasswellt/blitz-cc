---
description: /blitz:health run against the plugin repo itself reports an overall HEALTHY verdict. Needs --allow-tools Bash (the skill runs validate-plugin-structure.sh and the frontmatter lint from ${CLAUDE_PLUGIN_ROOT}).
tags: [health, needs-bash]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Bash]
append_system_prompt: "The working directory is an empty eval workspace. The blitz plugin under test is loaded from its checkout; when the health skill runs a cwd-relative path such as ./scripts/validate-plugin-structure.sh or hooks/scripts/skill-frontmatter-validate.sh, resolve it against the plugin root (the directory holding .claude-plugin/plugin.json, i.e. ${CLAUDE_PLUGIN_ROOT}) and run it from there."
---

/blitz:health
