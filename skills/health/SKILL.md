---
name: health
description: "Validates plugin structural integrity: hooks executable + valid hooks.json, no stale sessions or orphan locks, activity-feed under threshold, every SKILL.md passes the canonical frontmatter lint. Use when the user reports a hook misfiring, a session collision warning, an unfamiliar lock file, or simply asks 'is the plugin healthy?'. Run after any /blitz:setup or hook config change."
argument-hint: "(no arguments — runs all checks)"
allowed-tools: Read, Bash, Glob, Grep
disallowed-tools: Edit, Write, NotebookEdit
model: sonnet
effort: low
compatibility: ">=2.1.152"
---


<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Plugin Health Check

Verify the structural integrity and operational health of the blitz plugin. Reports issues that could affect skill execution, session management, or hook automation.

**No session protocol required.** This skill is lightweight and read-only.

**Boundary vs conform/setup.** `health` = *read-only* assertion of structural **and runtime** state (hooks, sessions, locks, activity-feed, background agents) — it never mutates. `/blitz:conform --scope plugin` runs the same structural checks **plus `--fix`** schema migration but defers runtime probes here. `/blitz:setup` is the orthogonal CLAUDE.md-rule conflict + permission audit. The frontmatter + hook-wiring checks below intentionally overlap conform's plugin scope (both call the same validators); the distinction is assert-only vs repair.

---

## Phase 0: STRUCTURAL CHECKS

Run the plugin structure validator:
```bash
./scripts/validate-plugin-structure.sh 2>&1
```

Report the result. If validation fails, list each failure with its location.

---

## Phase 1: HOOK CHECKS

### 1.1 Hook Scripts Exist and Are Executable

For each hook in `hooks/hooks.json`, verify:
- The referenced script file exists
- The script is executable (`-x` permission)
- The script has a valid shebang line

```bash
# List all hook scripts from hooks.json and check each
for script in $(grep -oP '"command":\s*"[^"]*scripts/([^"]+)"' hooks/hooks.json | grep -oP '[^/]+\.sh$'); do
  ls -la hooks/scripts/${script} 2>/dev/null || echo "MISSING: ${script}"
done
```

### 1.2 hooks.json Is Valid

```bash
python3 -c "import json; json.load(open('hooks/hooks.json')); print('hooks.json: valid')" 2>&1
```

---

## Phase 2: SESSION CHECKS

### 2.1 Stale Sessions

Check `.cc-sessions/*.json` for sessions that are still marked `active` but appear stale:

```bash
find .cc-sessions -maxdepth 1 -name "*.json" -exec grep -l '"status": "active"' {} \; 2>/dev/null
```

For each active session:
- Check if the PID is still running
- Check if the session is older than 4 hours

Report stale sessions and suggest cleanup.

### 2.2 Stale Locks

Check for `.lock` files that may be orphaned:

```bash
find . -name "*.lock" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null
```

For each lock file, check if the owning session is still active. Report orphaned locks.

### 2.3 Activity Feed Size

```bash
wc -l .cc-sessions/activity-feed.jsonl 2>/dev/null || echo "No activity feed"
```

If over 500 lines, suggest truncation. If over 1000 lines, flag as a warning.

### 2.4 Session Reports Directory

```bash
ls .cc-sessions/reports/ 2>/dev/null | wc -l
```

Report the number of session reports available.

### 2.5 Background Agents (native agent view)

Surface the native agent-view supervisor state so background-session interop (worktree isolation, conflict overlay) is observable. Best-effort — skip silently if `claude` CLI absent.

```bash
# Supervisor / daemon state (CC >=2.1.139)
claude daemon status 2>/dev/null || echo "agent-view daemon: not running or unavailable"
# Live background sessions, if any
claude agents --json 2>/dev/null | jq -r 'if type=="array" then length else 0 end' 2>/dev/null || echo 0
# Warn if agent view is disabled while blitz interop expects it
if [ "${CLAUDE_CODE_DISABLE_AGENT_VIEW:-}" = "1" ] || grep -q '"disableAgentView"[[:space:]]*:[[:space:]]*true' .claude/settings.json 2>/dev/null; then
  echo "WARN: agent view disabled — /blitz:worktree-prune live-session guard + conflict overlay degrade to .cc-sessions/*.json only"
fi
```

Report: daemon reachable (y/n), live background-session count, and the disable warning if present. Cross-ref: [/_shared/worktree-lifecycle.md](/_shared/worktree-lifecycle.md) §Interop.

---

## Phase 3: REGISTRY CHECKS

### 3.1 Skill Frontmatter Conformance

Walk every `skills/*/SKILL.md` (Anthropic-canonical layout — no central registry) and validate via the lint hook:

```bash
hooks/scripts/skill-frontmatter-validate.sh --all
```

The validator reports per-file violations: missing required frontmatter fields, description over 1024 chars, body over 500 lines, missing canonical OUTPUT STYLE snippet. Report the exit code (0 = all conform; 1 = violations listed) plus the count of skills found:

```bash
ls skills/*/SKILL.md | wc -l
```

If any skill directory lacks a SKILL.md, flag it (the directory is incomplete or stale).

### 3.2 Agent Files Exist

Verify all agent files referenced by skills exist in `agents/`:

```bash
ls agents/*.md 2>/dev/null
```

### 3.3 Shared Protocols Exist

Verify all shared protocol files exist:

```bash
ls skills/_shared/*.md 2>/dev/null
```

Check that the expected protocols are present: session-protocol.md, verbose-progress.md, definition-of-done.md, checkpoint-protocol.md, deviation-protocol.md, context-management.md, session-report-template.md.

---

## Phase 4: STACK DETECTION CHECK

```bash
./scripts/detect-stack.sh 2>&1
```

Verify the stack detection script runs successfully and produces output.

---

## Phase 5: REPORT

Print a health summary:

```
Plugin Health Check
===================
Structural validation: PASS/FAIL (N/M checks)
Hook scripts:          PASS/FAIL (N/M executable)
hooks.json:            PASS/FAIL
Sessions:              N active, N stale, N completed
Stale locks:           N found
Activity feed:         N lines (OK/WARN)
Session reports:       N available
Skill frontmatter:     PASS/FAIL (N skills, M frontmatter violations)
Agent files:           PASS/FAIL (N/M found)
Shared protocols:      PASS/FAIL (N/M found)
Stack detection:       PASS/FAIL

Overall: HEALTHY / NEEDS ATTENTION / UNHEALTHY
```

If any checks fail, list recommended actions:

```
Recommended Actions:
  1. [STALE SESSION] Clean up session <X> — PID not running, 6h old
  2. [ORPHANED LOCK] Delete sprint-registry.json.lock — owning session completed
  3. [FRONTMATTER] skills/foo/SKILL.md: missing required field 'effort' — see /_shared/terse-output.md and lint hook
```
