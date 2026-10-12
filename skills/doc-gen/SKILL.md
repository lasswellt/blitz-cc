---
name: doc-gen
description: "Generates API docs, component docs and Mermaid architecture diagrams from source code into docs/generated/. Modes: api, components, architecture, full (parallel agents). Use for 'generate docs', 'API documentation', 'component docs', 'architecture diagram', or when source is ahead of docs/."
allowed-tools: Read, Glob, Grep, ToolSearch, Agent, Edit(docs/generated/**), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh)
model: inherit
compatibility: ">=2.1.296"
argument-hint: "<api|components|architecture|full>"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For documentation templates, Vue SFC parsing patterns, and Mermaid diagram examples, see [references/main.md](references/main.md)
- For subagent spawning (type selection, weight classes, the fan-out gate), see [agents.md](/_shared/agents.md) and [agents.reference.md](/_shared/agents.reference.md) §3–§4
- For output style (terse-technical, preservation rules), see [/_shared/output.md](/_shared/output.md)

---

# Documentation Generator

Analyze source code and produce comprehensive, accurate documentation. In `full` mode, spawn 3 parallel agents (api, components, architecture) for concurrent documentation generation. Changelog generation belongs to `/blitz:ship`. Execute every phase in order. Do NOT skip phases.

All generated documentation must satisfy the Definition of Done ([quality.reference.md](/_shared/quality.reference.md) §Definition of Done). No placeholder sections, no TODO stubs.

---

## Phase 0: PARSE (Determine Mode)

### 0.0 Register Session

Follow [sessions.md](/_shared/sessions.md) §2 (skill preamble, steps 1-7) and [output.md](/_shared/output.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode

Extract mode from `$ARGUMENTS`. If not specified, ask the user.

| Mode | Description | Output File |
|------|-------------|-------------|
| `api` | Generate API documentation for exported functions/classes | `docs/generated/api.md` |
| `components` | Generate Vue component documentation (props, emits, slots) | `docs/generated/components.md` |
| `architecture` | Generate architecture overview with Mermaid diagrams | `docs/generated/architecture.md` |
| `full` | Run all modes (spawns parallel agents) | All of the above + `docs/generated/index.md` |

---

## Phase 1: DISCOVER (File Inventory)

### 1.1 Scan Source Files

Glob for relevant files based on mode:

| Mode | Glob Patterns |
|------|--------------|
| api | `src/**/*.ts` (excluding `*.test.*`, `*.spec.*`, `*.d.ts`) |
| components | `src/**/*.vue`, `components/**/*.vue` |
| architecture | `package.json`, `*config*`, directory structure |
| full | All of the above |

```bash
# Example for api mode
find src/ -name '*.ts' -not -name '*.test.*' -not -name '*.spec.*' -not -name '*.d.ts' | grep -v node_modules | head -100
```

### 1.2 Assess JSDoc Coverage

For `api` mode, scan for existing JSDoc comments versus exported functions:

```bash
# Count exported functions
grep -r "^export " src/ --include="*.ts" | grep -v node_modules | wc -l

# Count JSDoc blocks
grep -r "/\*\*" src/ --include="*.ts" | grep -v node_modules | wc -l
```

Report coverage percentage = (JSDoc blocks / exported functions) * 100.

### 1.3 Check Staleness

Check if `docs/generated/` exists and when it was last updated:

```bash
if [ -d "docs/generated" ]; then
  LAST_GEN=$(stat -c %Y docs/generated/*.md 2>/dev/null | sort -n | tail -1)
  NOW=$(date +%s)
  AGE_DAYS=$(( (NOW - LAST_GEN) / 86400 ))
  echo "Last generated: ${AGE_DAYS} days ago"

  # Check for commits since last generation
  LAST_GEN_DATE=$(date -d @${LAST_GEN} +%Y-%m-%d 2>/dev/null)
  COMMITS_SINCE=$(git log --since="${LAST_GEN_DATE}" --oneline 2>/dev/null | wc -l)
  echo "Commits since last generation: ${COMMITS_SINCE}"
else
  echo "No generated docs found"
fi
```

If docs are older than 7 days or there have been commits since last generation, flag as stale/outdated.

---

## Phase 2: ANALYZE (Mode-Specific Extraction)

### 2.1 API Mode

For each TypeScript file with exports, extract:

1. **Function signatures**: name, parameters (with types), return type, async flag
2. **JSDoc comments**: description, `@param` tags, `@returns`, `@throws`, `@example`, `@deprecated`
3. **Zod schemas**: Parse `z.object({...})` definitions to infer documented types
4. **Type/interface definitions**: Extract `type` and `interface` declarations that are exported
5. **Constants**: Exported `const` values, especially enums and configuration objects
6. **Re-exports**: Track barrel file re-exports to map the public API surface

For each export, record:
- Module path (relative to src/)
- Export name
- Kind (function, class, type, interface, const, enum)
- Signature or shape
- Documentation (from JSDoc or inferred)

### 2.2 Components Mode

For each `.vue` file, extract:

1. **Props**: Parse `defineProps<Props>()` or `defineProps({...})`
   - Prop name, type, default value, required flag
   - JSDoc or inline comments describing each prop
2. **Emits**: Parse `defineEmits<{...}>()` or `defineEmits([...])`
   - Event name, payload type
3. **Slots**: Parse `defineSlots()` or find `<slot>` tags in template
   - Slot name, scoped slot props (if any)
4. **Component description**: Top-level comment block or `@description` in script setup
5. **Composable usage**: Track which composables are called (for cross-references)
6. **Expose**: Parse `defineExpose({...})` for public component API

### 2.3 Architecture Mode

1. **Directory structure**: Map the top-level directory tree (2-3 levels deep)
2. **Import graph**: For each module, parse imports to build a dependency graph
   - Which modules depend on which
   - Identify circular dependencies
3. **Layer identification**: Classify modules into layers:
   - Pages (routes/views)
   - Components (UI building blocks)
   - Composables (shared reactive logic)
   - Stores (state management)
   - Services/API (data access)
   - Utils (pure utilities)
   - Types (shared type definitions)
4. **Key flows**: Identify 3-5 important data flows through the layers
5. **Mermaid diagrams**: Generate flowcharts and dependency graphs

---

## Phase 3: GENERATE (Write Documentation)

### 3.1 Create Output Directory

```bash
mkdir -p docs/generated
```

### 3.2 Full Mode (Parallel Agents)

If mode is `full`, spawn the three agents below in one message for parallel documentation generation (subagents, never an agent team; [agents.md](/_shared/agents.md) §1.5).

Spawn 3 agents using `Agent(subagent_type: "general-purpose", model: "sonnet", effort: "medium", run_in_background: true, description: "doc-gen <agent-name>", prompt: <agent-prompt>)` in a **single assistant message** so they run concurrently. Substitute `<agent-name>` with the concrete name from the table below (`doc-api`, `doc-components`, `doc-architecture`).

> **Subagent type**: doc agents must Write their output files. Never use `Explore` or rely on SDK heuristics. See [agents.md](/_shared/agents.md).

| Agent | Mode | Output File | Description |
|-------|------|-------------|-------------|
| `doc-api` | api | `docs/generated/api.md` | API reference documentation |
| `doc-components` | components | `docs/generated/components.md` | Component documentation |
| `doc-architecture` | architecture | `docs/generated/architecture.md` | Architecture overview |

**Weight class**: Medium ([agents.reference.md](/_shared/agents.reference.md) §3.3). Each agent prompt MUST declare:
- Max 15 file reads (of source files to document)
- Max 25 tool calls
- Max 250-line reply (the document itself is written to disk incrementally and is not the reply)
- 5-minute wall-clock budget

Each agent receives:
1. The file inventory from Phase 1 (relevant subset for its mode).
2. The stack profile from Phase 0.
3. The appropriate template from `references/main.md`.
4. Its output file path.
5. **Incremental-write instructions**: Stub the output file at start with `# IN PROGRESS`, then append each section as you complete it. If you time out or hit a budget ceiling, at least a partial document with completed sections is on disk rather than nothing.
6. **File-level partial marker** (add verbatim to prompt; the reply itself uses the status enum of [agents.reference.md](/_shared/agents.reference.md) §4.1, `BLOCKED` with `circuit-breaker` on budget exhaustion):
   ```
   PARTIAL: If you have fewer than 3 tool calls remaining, STOP and append to your output file:
     ---
     PARTIAL: true
     COMPLETED: [list of sections written]
     MISSING: [list of sections skipped]
     CONFIDENCE: low|medium|high
     ---
   ```

### 3.3 Single Mode (Direct Generation)

For single-mode runs, generate documentation directly using the templates from `references/main.md`.

Write to `docs/generated/<mode>.md`.

### 3.4 Gate after completion (Full Mode Only)

Wait on the three background agents' completion notifications (never poll output files in a loop; [agents.md](/_shared/agents.md) §1.5), then check the output files once:

```bash
MISSING_COUNT=0
PARTIAL_COUNT=0
for f in docs/generated/api.md docs/generated/components.md docs/generated/architecture.md; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
  elif grep -q '^PARTIAL: true' "$f"; then
    echo "PARTIAL: $f" >&2
    PARTIAL_COUNT=$((PARTIAL_COUNT+1))
  else
    echo "DONE: $f"
  fi
done
```

An agent with no completion notification 5 min + 30 s after its spawn is MISSING.

**Handling outcomes**:
- **Missing files**: retry the failed agent(s) once with a narrowed scope (single section only). If still failed, leave the file absent and list it under "Not generated" in the Phase 4 index (never write a placeholder document).
- **PARTIAL files**: keep the partial content. In Phase 4 TOC, mark the partial documents with a `(PARTIAL)` suffix so the reader knows coverage is incomplete. Read the `MISSING:` list from the PARTIAL block and log to the activity feed.
- **All DONE**: proceed normally.

Do NOT silently produce a "complete" index that includes missing or partial docs without flagging them.

---

## Phase 4: ASSEMBLE (Cross-Link and Index)

### 4.1 Generate Table of Contents

Create `docs/generated/index.md`:

```markdown
# Generated Documentation

> Auto-generated from source code. Do not edit manually.

**Generated**: YYYY-MM-DD
**Stack**: <detected stack>

## Contents

- [API Reference](api.md): Exported functions, types, and schemas
- [Components](components.md): Vue component props, events, and slots
- [Architecture](architecture.md): System overview and dependency diagrams
```

Only link documents that were successfully generated.

### 4.2 Cross-References

Scan generated documents and add links between related items:
- Component doc references the store it uses (link to API doc section)
- API doc references components that consume it
- Architecture doc links to relevant API and component sections

Use standard markdown links: `[StoreName](api.md#storename)`.

### 4.3 Add Generation Metadata

Append a footer to each generated file:

```markdown
---
<!-- Generated by doc-gen on YYYY-MM-DD. Do not edit manually. -->
```

---

## Phase 5: REPORT (Present to User)

### 5.1 Output Summary

```
Documentation Generated
========================
Mode: <mode>
Stack: <detected stack>

  API docs:      N functions documented (M% JSDoc coverage)
  Components:    N components documented
  Architecture:  N diagrams generated

Output: docs/generated/
Index:  docs/generated/index.md
```

Adjust the summary to show only the modes that were run.

### 5.2 Follow-Up Suggestions

| Condition | Suggestion |
|-----------|------------|
| JSDoc coverage < 50% | "Consider adding JSDoc comments to improve API documentation quality" |
| Components have no descriptions | "Add top-level comments to Vue SFCs for better component docs" |
| Circular dependencies found | "Run `refactor` to untangle circular imports" |

### 5.3 Session Cleanup

Final phase per [sessions.md](/_shared/sessions.md) §2: `blitz_session_update "$SESSION_ID" '.working_on="done: <summary>"'`, log `skill_end` with `{status, summary}`, and remove `${SESSION_TMP_DIR}` unless an artifact there is still needed. Never set `status` or `state`; the hook closes the record.

---

## Safety Rules

- **Non-destructive.** This skill only reads source files and writes to `docs/generated/`. It never modifies application code.
- **Overwrite protection.** Before writing to `docs/generated/`, check for files that do NOT have the `<!-- Generated by doc-gen -->` footer. If found, these may be manually edited files; warn the user before overwriting and suggest backing them up.
- **No credential exposure.** Do not include environment variable values, API keys, secrets, or `.env` file contents in generated documentation.
- **Git-safe.** Generated docs may be committed but are clearly marked as auto-generated. Users should add `docs/generated/` to `.gitignore` if they do not want them tracked.
- **File size limits.** If a generated document exceeds 2000 lines, split it into multiple files and link from the index.

---

## Error Recovery

- **Source file parse failure**: Skip the file, note it in the output summary. Do not abort the entire mode.
- **Full mode agent failure**: Collect partial results from successful agents. Note which modes failed in the index.
- **docs/generated/ has manual edits**: Warn the user before overwriting. List the files that lack the auto-generated footer and suggest backing them up.
- **No exports found in API mode**: Report "No public API surface detected. Check that functions are exported."
- **No .vue files found in components mode**: Report "No Vue components found. Check the glob patterns."
- **Import graph too large**: Limit architecture diagrams to the top 30 most-connected modules. Note the truncation.
- **Mermaid diagram too complex**: Simplify by grouping related modules into subgraphs. Limit nodes to 50 per diagram.
