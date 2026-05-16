---
name: doc-gen
description: "Generates API docs, component docs, architecture diagrams (Mermaid), and CHANGELOG entries from source code and conventional commits. Modes: api, components, architecture, changelog, full. Use when the user says 'generate docs', 'doc-gen', 'API documentation', 'component docs', 'architecture diagram', 'auto-changelog', or when source code is ahead of docs/."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, TeamCreate, SendMessage
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<mode> -- api (TypeDoc/JSDoc → docs/api/) | components (Vue prop+event tables) | architecture (Mermaid graphs) | changelog (commits since last tag) | full (all of the above)"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For documentation templates, Vue SFC parsing patterns, and Mermaid diagram examples, see:
!cat skills/doc-gen/references/main.md
<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Documentation Generator

Analyze source code and produce comprehensive, accurate documentation. In `full` mode, spawn 4 parallel agents (api, components, architecture, changelog) for concurrent documentation generation. Execute every phase in order. Do NOT skip phases.

All generated documentation must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder sections, no TODO stubs.

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode

Extract mode from `$ARGUMENTS`. If not specified, ask the user.

| Mode | Description | Output File |
|------|-------------|-------------|
| `api` | Generate API documentation for exported functions/classes | `docs/generated/api.md` |
| `components` | Generate Vue component documentation (props, emits, slots) | `docs/generated/components.md` |
| `architecture` | Generate architecture overview with Mermaid diagrams | `docs/generated/architecture.md` |
| `changelog` | Generate changelog from conventional commits | `docs/generated/changelog.md` |
| `full` | Run all modes (spawns parallel agents) | All of the above + `docs/generated/index.md` |

---

## Phase 1: DISCOVER — File Inventory

### 1.1 Scan Source Files

Glob for relevant files based on mode:

| Mode | Glob Patterns |
|------|--------------|
| api | `src/**/*.ts` (excluding `*.test.*`, `*.spec.*`, `*.d.ts`) |
| components | `src/**/*.vue`, `components/**/*.vue` |
| architecture | `package.json`, `*config*`, directory structure |
| changelog | Git log (no file glob needed) |
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

## Phase 2: ANALYZE — Mode-Specific Extraction

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

### 2.4 Changelog Mode

Parse git log with conventional commit format:

```bash
# Get commits since last tag or last 3 months
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "${LAST_TAG}" ]; then
  git log "${LAST_TAG}..HEAD" --pretty=format:"%H|%s|%an|%ai" 2>&1
else
  git log --since="3 months ago" --pretty=format:"%H|%s|%an|%ai" 2>&1
fi
```

Group commits by type:
- **Added** (`feat:`): New features
- **Fixed** (`fix:`): Bug fixes
- **Changed** (`refactor:`, `perf:`): Code changes
- **Breaking Changes** (`BREAKING CHANGE:` or `!:` suffix): Breaking changes
- **Other** (`docs:`, `chore:`, `ci:`, `test:`, `style:`): Miscellaneous

---

## Phase 3: GENERATE — Write Documentation

### 3.1 Create Output Directory

```bash
mkdir -p docs/generated
```

### 3.2 Full Mode — Parallel Agents

If mode is `full`, create a team and spawn agents for parallel documentation generation.

Use `TeamCreate` to create a team named `doc-gen-<TIMESTAMP>`.

Spawn 4 agents using `SendMessage`, each with `model: "sonnet"`, `mode: "auto"`, `run_in_background: true`, **`subagent_type: general-purpose`**:

> **Subagent type**: doc agents must Write their output files. Never use `Explore` or rely on SDK heuristics. See [spawn-protocol.md](/_shared/spawn-protocol.md).

| Agent | Mode | Output File | Description |
|-------|------|-------------|-------------|
| `doc-api` | api | `docs/generated/api.md` | API reference documentation |
| `doc-components` | components | `docs/generated/components.md` | Component documentation |
| `doc-architecture` | architecture | `docs/generated/architecture.md` | Architecture overview |
| `doc-changelog` | changelog | `docs/generated/changelog.md` | Changelog |

**Weight class**: Medium (per [spawn-protocol.md](/_shared/spawn-protocol.md)). Each agent prompt MUST declare:
- Max 20 file reads (of source files to document)
- Max 25 tool calls
- Max 400-line output (doc-api, doc-components, doc-architecture) / 100-line (doc-changelog)
- 5-minute wall-clock budget

Each agent receives:
1. The file inventory from Phase 1 (relevant subset for its mode).
2. The stack profile from Phase 0.
3. The appropriate template from `references/main.md`.
4. Its output file path.
5. **Incremental-write instructions** (replaces the previously banned "write the full document" rule): Stub the output file at start with `# IN PROGRESS`, then append each section as you complete it. If you time out or hit a budget ceiling, at least a partial document with completed sections is on disk rather than nothing.
6. **HEARTBEAT + PARTIAL protocol** (add verbatim to prompt):
   ```
   HEARTBEAT: At the start of each section, append to your output file:
     HEARTBEAT: <section-name> at <ISO-timestamp>

   PARTIAL: If you have fewer than 3 tool calls remaining, STOP and append:
     ---
     PARTIAL: true
     COMPLETED: [list of sections written]
     MISSING: [list of sections skipped]
     CONFIDENCE: low|medium|high
     ---
   ```

### 3.3 Single Mode — Direct Generation

For single-mode runs, generate documentation directly using the templates from `references/main.md`.

Write to `docs/generated/<mode>.md`.

### 3.4 Wait for Agents (Full Mode Only)

Poll for agent completion by checking output files:

```bash
MISSING_COUNT=0
PARTIAL_COUNT=0
for f in docs/generated/api.md docs/generated/components.md docs/generated/architecture.md docs/generated/changelog.md; do
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

Timeout after 5 minutes per agent.

**Handling outcomes**:
- **Missing files**: retry the failed agent(s) once with a narrowed scope (single section only). If still failed, write a placeholder `# TBD — agent failed` to the missing file so Phase 4 assembly doesn't crash.
- **PARTIAL files**: keep the partial content. In Phase 4 TOC, mark the partial documents with a `(PARTIAL)` suffix so the reader knows coverage is incomplete. Read the `MISSING:` list from the PARTIAL block and log to the activity feed.
- **All DONE**: proceed normally.

Do NOT silently produce a "complete" index that includes missing or partial docs without flagging them.

---

## Phase 4: ASSEMBLE — Cross-Link and Index

### 4.1 Generate Table of Contents

Create `docs/generated/index.md`:

```markdown
# Generated Documentation

> Auto-generated from source code. Do not edit manually.

**Generated**: YYYY-MM-DD
**Stack**: <detected stack>

## Contents

- [API Reference](api.md) — Exported functions, types, and schemas
- [Components](components.md) — Vue component props, events, and slots
- [Architecture](architecture.md) — System overview and dependency diagrams
- [Changelog](changelog.md) — Recent changes grouped by type
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

## Phase 5: REPORT — Present to User

### 5.1 Output Summary

```
Documentation Generated
========================
Mode: <mode>
Stack: <detected stack>

  API docs:      N functions documented (M% JSDoc coverage)
  Components:    N components documented
  Architecture:  N diagrams generated
  Changelog:     N entries since last release

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
| Changelog has no conventional commits | "Adopt conventional commits for automatic changelog generation" |

### 5.3 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`.
2. Append `session_end` to the operation log.
3. Optionally remove session temp directory if no artifacts need preservation.

---

## Safety Rules

- **Non-destructive.** This skill only reads source files and writes to `docs/generated/`. It never modifies application code.
- **Overwrite protection.** Before writing to `docs/generated/`, check for files that do NOT have the `<!-- Generated by doc-gen -->` footer. If found, these may be manually edited files — warn the user before overwriting and suggest backing them up.
- **No credential exposure.** Do not include environment variable values, API keys, secrets, or `.env` file contents in generated documentation.
- **Git-safe.** Generated docs may be committed but are clearly marked as auto-generated. Users should add `docs/generated/` to `.gitignore` if they do not want them tracked.
- **File size limits.** If a generated document exceeds 2000 lines, split it into multiple files and link from the index.

---

## Error Recovery

- **Source file parse failure**: Skip the file, note it in the output summary. Do not abort the entire mode.
- **Git log fails (no commits)**: Skip changelog generation. Report "No commit history available."
- **Full mode agent failure**: Collect partial results from successful agents. Note which modes failed in the index.
- **docs/generated/ has manual edits**: Warn the user before overwriting. List the files that lack the auto-generated footer and suggest backing them up.
- **No exports found in API mode**: Report "No public API surface detected. Check that functions are exported."
- **No .vue files found in components mode**: Report "No Vue components found. Check the glob patterns."
- **No conventional commits for changelog**: Generate a plain commit list grouped by date instead of by type.
- **Import graph too large**: Limit architecture diagrams to the top 30 most-connected modules. Note the truncation.
- **Mermaid diagram too complex**: Simplify by grouping related modules into subgraphs. Limit nodes to 50 per diagram.
