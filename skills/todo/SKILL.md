---
name: todo
description: "Tracks development ideas, follow-up items, and technical debt discovered mid-task. Modes: add, list, check, resolve. Stores in .cc-sessions/todos.jsonl with file:line context. Use when the user says 'todo: X', 'remember to X', 'add a todo', 'what's on my todo list', 'todos for this sprint', or when Claude itself surfaces a follow-up that shouldn't become a stale TODO comment in code."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
effort: low
compatibility: ">=2.1.71"
argument-hint: "<add <description> | list | check | resolve <id>>"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Todo Management

Track development ideas, follow-up items, and technical debt discovered during work. Prevents items from being lost or becoming stale TODO comments in code.

**No session protocol required.** This skill is lightweight.

**Verbose progress exemption:** This skill intentionally skips verbose output. Freeform activity-feed logging from CLAUDE.md still applies.

---

## Mode Routing

Parse the first argument:

| Argument | Mode | Description |
|---|---|---|
| `add <description>` | ADD | Create a new tracked todo |
| `list` | LIST | Show all open todos grouped by area |
| `check` | CHECK | Scan code for TODO/FIXME comments and cross-reference with tracked todos |
| `resolve <id>` | RESOLVE | Mark a todo as resolved |

If no argument, default to `list`.

---

## Mode: ADD

1. **Parse description.** Extract the todo description from the arguments.
2. **Infer area.** Based on keywords in the description, assign an area:
   - `backend` — API, server, functions, database, store
   - `frontend` — component, page, UI, style, layout
   - `testing` — test, coverage, assertion, mock
   - `infra` — deploy, CI, config, environment
   - `docs` — documentation, README, changelog
   - `general` — anything else
3. **Generate ID.** Read `.cc-sessions/todos.jsonl` to find the highest existing ID number. New ID = `TODO-<next-number>`.
4. **Check for duplicates.** Scan existing open todos for similar descriptions (>60% word overlap). If found, warn but still create.
5. **Append entry:**
   ```bash
   echo '{"id":"TODO-NNN","created":"<ISO-8601>","session":"<current-session-or-cli>","description":"<text>","area":"<area>","status":"open","resolved_by":null}' >> .cc-sessions/todos.jsonl
   ```
6. **Confirm:** Print `Added: TODO-NNN — <description> [<area>]`

---

## Mode: LIST

1. **Read all todos** from `.cc-sessions/todos.jsonl`.
2. **Group by status** (open first, then resolved).
3. **Within open, group by area.**
4. **Print:**

```
Open Todos (N):
  backend:
    TODO-003 — Add rate limiting to API endpoints (2026-03-15)
    TODO-007 — Migrate user schema to v2 (2026-03-17)
  frontend:
    TODO-005 — Add loading skeleton to dashboard (2026-03-16)
  testing:
    TODO-008 — Integration tests for auth flow (2026-03-18)

Resolved (N):
  TODO-001 — Fix login redirect (resolved by fix-issue session)
  TODO-002 — Update deps (resolved by dep-health session)
```

---

## Mode: CHECK

1. **Scan codebase** for TODO/FIXME/HACK/XXX comments:
   ```bash
   grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.vue" --include="*.js" . | grep -v node_modules | grep -v .cc-sessions
   ```
2. **Read tracked todos** from `.cc-sessions/todos.jsonl`.
3. **Cross-reference:** For each code comment, check if it matches a tracked todo (keyword overlap).
4. **Report:**

```
Code TODOs found: N
  Tracked (matched to a todo): M
  Untracked (no matching todo): K

Untracked TODOs in code:
  src/api/users.ts:42 — TODO: add pagination
  src/components/Dashboard.vue:88 — FIXME: handle empty state

Tracked todos not in code (ideas/follow-ups):
  TODO-003 — Add rate limiting to API endpoints
  TODO-008 — Integration tests for auth flow
```

5. **Offer to track** untracked code TODOs: "Would you like me to add these N untracked TODOs to the tracker?"

---

## Mode: RESOLVE

1. **Parse the ID** from arguments (e.g., `TODO-003`).
2. **Read `.cc-sessions/todos.jsonl`** and find the matching entry.
3. **If not found**, print error and list similar IDs.
4. **Update the entry:** Read all lines, modify the matching line to set `"status":"resolved"` and `"resolved_by":"<context>"`, write back.
5. **Confirm:** Print `Resolved: TODO-003 — <description>`

---

## Storage

```
.cc-sessions/todos.jsonl
```

One JSON object per line, append-only for adds. Resolves require a rewrite of the matching line.

Todos are preserved indefinitely. They can be pruned by manually editing the file or by running `check` and resolving completed items.
