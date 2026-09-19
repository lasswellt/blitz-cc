---
name: todo
description: "Use when the user says 'todo: X', 'remember to X', 'add a todo', 'what's on my todo list', or when Claude surfaces a follow-up that should not become a stale TODO comment. Tracks ideas, follow-ups, and tech debt in docs/plans/BACKLOG.md (markdown checklist). Modes: add, list, check, resolve."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
compatibility: ">=2.1.271"
argument-hint: "<add <text> [#tag] | list [#tag] | check | resolve <n|substring>>"
---

# Todo — the backlog

Track development ideas, follow-up items, and technical debt discovered during work so they are not lost or left as stale TODO comments in code. Lightweight: no session preamble, no verbose progress. Freeform activity-feed logging from `CLAUDE.md` still applies.

## Storage

`docs/plans/BACKLOG.md` — tracked in git, one checklist line per item ([loop.md](/_shared/loop.md) §Files). `/blitz:plan` reads the open lines when it brainstorms a plan; a line that became a plan task is checked off with the plan slug.

```markdown
# Backlog

- [ ] 2026-09-19 Add rate limiting to API endpoints #backend
- [ ] 2026-09-19 Loading skeleton on dashboard (src/pages/Dashboard.vue:88) #frontend
- [x] 2026-09-12 Fix login redirect #backend → plan auth-redirect
```

Line shape: `- [ ] <ISO date> <text> #tag` — one `#tag` from `#backend #frontend #testing #infra #docs #general`, optional `(file:line)` context inside the text, and a trailing ` → <resolution>` once checked. Create the file with the `# Backlog` heading when it is absent. Never rewrite lines you are not resolving; append new items at the end.

## Mode routing

First argument: `add`, `list` (default), `check`, `resolve`.

### add `<text> [#tag]`

1. Take the text verbatim; infer the tag from keywords when none is given (API/server/store → `#backend`; component/page/UI/style → `#frontend`; test/coverage/mock → `#testing`; deploy/CI/config → `#infra`; README/changelog → `#docs`; else `#general`). Append `(file:line)` when the item came from a specific location.
2. Duplicate guard: if an open line shares >60 % of its words, print `similar: <line>` and still add unless the user declines.
3. Append `- [ ] $(date -u +%F) <text> #tag` and confirm: `Added #<n>: <text> #tag` (`n` = 1-based position among open lines).

### list `[#tag]`

Print open lines grouped by tag, numbered by position among open lines (that number is what `resolve` accepts), then a one-line count of checked items:

```
Open (3):
  #backend   1. 2026-09-19 Add rate limiting to API endpoints
  #frontend  2. 2026-09-19 Loading skeleton on dashboard (src/pages/Dashboard.vue:88)
  #testing   3. 2026-09-18 Integration tests for auth flow
Done: 5 (git log docs/plans/BACKLOG.md for history)
```

### check

Cross-reference code comments with the backlog:

```bash
grep -rnE "\b(TODO|FIXME|HACK|XXX)\b" --include='*.ts' --include='*.tsx' --include='*.vue' --include='*.js' --include='*.py' . \
  | grep -vE "node_modules|\.cc-sessions|docs/plans/BACKLOG\.md"
```

Match each hit against open lines by keyword overlap or a matching `(file:line)`. Report `Code TODOs: N — tracked M, untracked K`, list the untracked ones as `path:line — comment`, and list open backlog lines with no code counterpart (ideas / follow-ups). Offer to `add` the untracked ones (one line each, `(file:line)` context filled in); never edit the source comments.

### resolve `<n|substring>`

1. Resolve the target: `n` is the position from `list`; a substring must match exactly one open line (else print the matches and stop).
2. Edit that line only: `- [ ]` → `- [x]`, append ` → <resolution>` (a plan slug, PR number, commit, or `done`).
3. Confirm: `Resolved: <text>`.

## Rules

- The file is the source of truth; no ids, no JSON, no sidecar state. Position numbers are recomputed on every `list`.
- Checked lines stay in the file; prune them by hand or in `/blitz:learn` when a plan is archived. Git history is the audit trail.
- Never turn a backlog line into a plan task here — that is `/blitz:plan`'s job; `todo` only records and resolves.
