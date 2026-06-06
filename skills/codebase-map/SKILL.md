---
name: codebase-map
description: "Builds CODEBASE-MAP.md for brownfield onboarding: Technology (stack/deps/build), Architecture (modules/layers/data flow), Quality (test coverage, lint debt), and Concerns (security/perf risks). Use when the user says 'map the codebase', 'analyze this project', 'I just inherited this repo', or when no CODEBASE-MAP.md exists. For deep coupling/dependency-graph structural analysis use the architect agent; for quality/tech-debt findings use /blitz:audit."
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "(no arguments — analyzes the current project)"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [agent-orchestration.md](/_shared/agent-orchestration.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Codebase Mapper

Produce a comprehensive, prescriptive analysis of an existing codebase by spawning 4 parallel dimension agents (Technology, Architecture, Quality, Concerns) and synthesizing their findings into a single `CODEBASE-MAP.md`. Output helps developers understand the project before planning sprints, refactoring, or onboarding new team members. Execute every phase in order. Do NOT skip phases. ultrathink during synthesis — the value of this map is cross-dimensional reasoning (e.g., "high test coverage on the wrong layer," "architecture A but stack B implies tension X") that single-dimension analysis misses.

**This skill is read-only. It does NOT modify any code.**

---

## Phase 0: CONTEXT — Register and Inventory

### 0.0 Register Session

Follow [session-lifecycle.md](/_shared/session-lifecycle.md) §Session Registration and [terse-output.md](/_shared/terse-output.md). Generate `SESSION_ID`, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, log `skill_start`.

### 0.1 Build File Inventory

The orchestrator builds a shared inventory that all dimension agents consume. Keep this bash work in the orchestrator so we don't pay 4× the token cost of re-running the same greps.

```bash
mkdir -p "${SESSION_TMP_DIR}"

# Source file count by type
find . \( -name '*.ts' -o -name '*.tsx' -o -name '*.vue' -o -name '*.js' -o -name '*.jsx' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
  > "${SESSION_TMP_DIR}/source-files.txt"

# Directory structure (top 3 levels)
find . -maxdepth 3 -type d -not -path '*/node_modules/*' -not -path '*/.git/*' | sort \
  > "${SESSION_TMP_DIR}/dir-tree.txt"

# Package configuration
for f in package.json pnpm-workspace.yaml lerna.json nx.json turbo.json tsconfig.json; do
  [ -f "$f" ] && cat "$f" > "${SESSION_TMP_DIR}/config-${f//\//-}.json" 2>/dev/null
done
```

---

## Phase 1: SPAWN DIMENSION AGENTS — Parallel Analysis

Spawn 4 agents in **a single assistant message** so they execute concurrently. Each agent writes its findings to a dedicated file; the orchestrator merges in Phase 3.

### 1.1 Agent Roster

| Agent | Dimension | Output File | File Cap |
|---|---|---|---|
| `map-technology` | Stack, frameworks, dependencies, runtime | `${SESSION_TMP_DIR}/map-technology.md` | 12 |
| `map-architecture` | Module boundaries, data flow, integration | `${SESSION_TMP_DIR}/map-architecture.md` | 15 |
| `map-quality` | TypeScript strictness, test coverage, TODOs, complexity | `${SESSION_TMP_DIR}/map-quality.md` | 10 |
| `map-concerns` | Fragile areas, security, dependency risks, docs gaps | `${SESSION_TMP_DIR}/map-concerns.md` | 10 |

### 1.2 Spawn Parameters

For each agent, call the `Agent` tool with:

- `subagent_type: general-purpose` (agents must Write findings files — never `Explore`)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from Opus orchestrator)
- `description: codebase-map <dimension> analysis`
- `prompt`: the dimension-agent prompt template (see `references/main.md` section "Dimension Agent Prompt Template")
- `run_in_background: false` (orchestrator waits on all 4 synchronously)

**Weight class**: Medium (per [agent-orchestration.md](/_shared/agent-orchestration.md)). The prompt MUST declare: file cap from the roster, max 25 tool calls, max 250-line output, 5-min wall-clock, stub-then-append write pattern.

### 1.3 Inputs Each Agent Receives

1. Its dimension name (Technology / Architecture / Quality / Concerns).
2. Absolute path to the shared inventory dir: `${SESSION_TMP_DIR}/`.
3. Its output file path (from the roster).
4. The dimension-specific checklist (see `references/main.md`).
5. The stack profile from Phase 0.

---

## Phase 2: COLLECT AND VALIDATE — Gather All Findings

**Before reading any file, validate output presence**:

```bash
MISSING_COUNT=0
EXPECTED_FILES=(
  "${SESSION_TMP_DIR}/map-technology.md"
  "${SESSION_TMP_DIR}/map-architecture.md"
  "${SESSION_TMP_DIR}/map-quality.md"
  "${SESSION_TMP_DIR}/map-concerns.md"
)
for f in "${EXPECTED_FILES[@]}"; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # Log to .cc-sessions/activity-feed.jsonl
  fi
done
```

**Gate**: If `MISSING_COUNT >= 2`, ABORT and report to user — a 2-dimension codebase map would be misleading. If `MISSING_COUNT == 1`, retry that dimension once with a narrower file cap. If still failed, emit a placeholder section in the final map flagging the missing dimension.

**Check for `PARTIAL: true` markers** in successful files — treat PARTIAL sections as known-incomplete and surface `MISSING` items in the final report.

---

## Phase 3: SYNTHESIZE — Generate CODEBASE-MAP.md

Read all 4 dimension files. Assemble into a single `CODEBASE-MAP.md` at the project root:

```markdown
# Codebase Map — <project-name>

Generated: <ISO-8601>
Analyzed by: blitz codebase-map (v<plugin-version>)

## Technology
<contents of map-technology.md>

## Architecture
<contents of map-architecture.md>

## Quality
<contents of map-quality.md>

## Concerns
<contents of map-concerns.md>

## Recommendations
<orchestrator-synthesized cross-dimensional recommendations>
```

The `Recommendations` section is the orchestrator's cross-cutting synthesis — e.g., a quality concern that compounds with an architectural gap. This is the one place the orchestrator adds value beyond concatenation.

---

## Phase 4: REPORT — Summary

Print a summary to the user:

```
[codebase-map] Complete ✓
  Dimensions analyzed: N/4
  Files analyzed: N (from shared inventory)
  Quality score: N/100 (from map-quality.md)
  Concerns flagged: N (from map-concerns.md)
  Output: CODEBASE-MAP.md
```

Log `skill_complete` to the activity feed. Clean up `${SESSION_TMP_DIR}/map-*.md` files (keep the inventory for future runs).

---

## Error Recovery

- **No source files found**: Inform user the directory looks empty; skip to Phase 3 with a minimal map noting the empty repo.
- **2+ dimensions failed**: Abort per Phase 2 gate. Do not ship a half-map silently.
- **1 dimension failed (after retry)**: Emit a placeholder section with explicit "⚠ not analyzed — dimension agent failed" text. Never silently omit.
