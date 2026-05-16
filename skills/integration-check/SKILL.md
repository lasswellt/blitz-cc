---
name: integration-check
description: "Validates cross-module wiring on the current code: export-to-import tracing (are new exports actually consumed?), route coverage (do new pages have navigation entries?), auth guard coverage, store-to-component wiring. Read-only analysis. Use when the user says 'integration check', 'check wiring', 'audit imports', 'unused exports', 'orphan routes', or invoked by /blitz:sprint-dev Phase 3.5.0 after implementation."
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "[scope: all | routes | exports | auth | stores]"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Integration Checker

Validate cross-module wiring by spawning parallel check agents grouped into 3 logical domains. Each domain agent runs its checks and writes findings JSON; the orchestrator merges and reports.

**This skill is read-only. It does NOT modify any code.**

All findings follow the [Definition of Done](/_shared/definition-of-done.md) standards.

---

## Phase 0: CONTEXT

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate `SESSION_ID`, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, log `skill_start`.

### 0.1 Parse Scope

| Argument | Agents Spawned |
|---|---|
| `all` (default) | 3 agents (wiring, auth, ui) |
| `routes` | wiring agent only (skip auth + ui) |
| `exports` | wiring agent only |
| `auth` | auth agent only |
| `stores` | wiring agent only |

### 0.2 Build Shared File Inventory

```bash
mkdir -p "${SESSION_TMP_DIR}"
find . \( -name '*.ts' -o -name '*.vue' -o -name '*.js' -o -name '*.tsx' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
  | sort > "${SESSION_TMP_DIR}/source-files.txt"
```

---

## Phase 1: SPAWN CHECK AGENTS — Parallel Analysis

Spawn the active agents in **a single assistant message** so they run concurrently.

### 1.1 Agent Grouping

The 7 original check categories are grouped into 3 parallel agents by concern domain:

| Agent | Checks Covered | Output File |
|---|---|---|
| `check-wiring` | Export-to-import, store-to-component, API-to-store, state-to-render | `${SESSION_TMP_DIR}/check-wiring.json` |
| `check-auth` | Auth guard coverage, protected endpoints | `${SESSION_TMP_DIR}/check-auth.json` |
| `check-ui` | Route coverage, form-to-handler wiring | `${SESSION_TMP_DIR}/check-ui.json` |

Grouping rationale: wiring-related checks share a common grep+trace pattern (inventory → exports → importers). Auth is a distinct concern with a different data flow. UI-facing checks (routes + forms) share template-parsing logic.

### 1.2 Spawn Parameters

For each active agent, call the `Agent` tool with:

- `subagent_type: general-purpose` (agents must Write findings JSON — never `Explore`)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from Opus orchestrator)
- `description: integration-check <domain>`
- `prompt`: the check-agent prompt template (see `references/main.md` section "Check Agent Prompt Template")
- `run_in_background: false`

**Weight class**: Medium (per [spawn-protocol.md](/_shared/spawn-protocol.md)). Each agent prompt declares: max 12 file reads, max 20 tool calls, 5-min wall-clock, stub-then-append JSON output.

### 1.3 Inputs Each Agent Receives

1. Agent domain (wiring / auth / ui).
2. Path to shared inventory: `${SESSION_TMP_DIR}/source-files.txt`.
3. Output file path (from roster).
4. Domain-specific check definitions (see `references/main.md`).
5. Output JSON schema.

---

## Phase 2: COLLECT AND VALIDATE

**Before reading any file, validate output presence**:

```bash
MISSING_COUNT=0
EXPECTED_FILES=()
# Build EXPECTED_FILES based on which agents were spawned for the scope.
# Example for scope=all:
EXPECTED_FILES+=("${SESSION_TMP_DIR}/check-wiring.json")
EXPECTED_FILES+=("${SESSION_TMP_DIR}/check-auth.json")
EXPECTED_FILES+=("${SESSION_TMP_DIR}/check-ui.json")

for f in "${EXPECTED_FILES[@]}"; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
  fi
done
```

**Gate**: If all expected agents failed, ABORT. If 1 agent failed, retry once with narrower scope. If still failed, emit a placeholder finding in the final report noting the missing domain.

---

## Phase 3: MERGE FINDINGS

Read all domain JSON files, concatenate findings arrays, deduplicate by `id` (format: `<check_id>-<file>-<line>-<hash>`).

---

## Phase 4: REPORT

Print a structured findings report:

```
Integration Check Report
========================
Scope: <scope>
Agents: <N>/<M> succeeded
Files analyzed: N

Export-to-Import Tracing:
  ✓ N exports have consumers
  ⚠ M orphaned exports (no importers):
    - <file>:<line> → <export-name>

Route Coverage:
  ✓ N routes reachable via navigation
  ⚠ M unreachable routes

Auth Guard Coverage:
  ✓ N endpoints protected
  ⚠ M unprotected sensitive endpoints

Store Wiring:
  ✓ N stores have consumers
  ⚠ M orphaned stores

API Wiring:
  ✓ N API functions called by stores
  ⚠ M orphaned API functions

Form Wiring:
  ✓ N forms connected to handlers
  ⚠ M disconnected forms

State-to-Render:
  ✓ N state vars rendered
  ⚠ M orphaned state vars

Overall: N findings (H high, M medium, L low)
```

Severity classification (used by agents and report):
- **High**: Unprotected auth endpoints, orphaned API functions suggesting missing features, disconnected forms
- **Medium**: Unreachable routes, orphaned stores, orphaned state
- **Low**: Orphaned exports (may be intentionally public API)

Log `skill_complete` to activity feed. Clean up `${SESSION_TMP_DIR}/check-*.json`.

---

## Error Recovery

- **All agents failed**: Abort with clear error message pointing user to `.cc-sessions/activity-feed.jsonl` for diagnostics.
- **1 agent failed after retry**: Emit placeholder section in report marking that domain as "⚠ not checked — agent failed".
- **No source files**: Exit early with "No source files found in scope".
