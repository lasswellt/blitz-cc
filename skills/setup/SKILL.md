---
name: setup
description: "Detects conflicts between CLAUDE.md rules and blitz skill behaviors. Reads global + project CLAUDE.md, matches against a known-conflict catalog, and reports severity-graded findings with remediation. Validates tool permissions and stack assumptions. Use on new project install, after adding CLAUDE.md rules, or when blitz skills behave unexpectedly."
allowed-tools: Read, Bash, Glob, Grep
disallowed-tools: Edit, Write, NotebookEdit
model: sonnet
effort: low
compatibility: ">=2.1.71"
argument-hint: "[--fix | --check] [--scope global|project|all] -- detects conflicts between CLAUDE.md files and blitz behaviors; --check audits read-only, --fix applies safe migrations; --scope chooses global config (~/.claude) / current project / both"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For conflict catalog schema and detailed pattern list, see [references/main.md](references/main.md)
- For session protocol, see [session-protocol.md](/_shared/session-protocol.md)
- For the research driving this skill, see `docs/_research/2026-04-16_plugin-agent-strategy.md`
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Setup / Doctor Skill

Scan the user's `~/.claude/CLAUDE.md` and project `./CLAUDE.md` for rules that conflict with blitz skill behaviors (auto-commit, auto-push, test execution, commit format, branch naming, package manager assumptions, model preferences), validate tool permissions, and produce a severity-graded report with remediation suggestions.

**This skill is read-only by default.** `--fix` mode is reserved for future versions and not implemented in MVP.

---

## SAFETY RULES

1. **Read-only analysis**. Do not modify the user's CLAUDE.md files.
2. **No secrets in output**. CLAUDE.md may contain API keys or personal info — never quote full CLAUDE.md content in output; only quote the specific rule snippet that matched a conflict pattern.
3. **Best-effort detection**. Pattern matching is advisory; always tell the user the report is heuristic and they should review findings before acting.

---

## Phase 0: INIT

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration and [verbose-progress.md](/_shared/verbose-progress.md). Generate `SESSION_ID`, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, log `skill_start`.

### 0.1 Parse Arguments

| Flag | Behavior |
|---|---|
| `--check` (default) | Report-only scan |
| `--fix` | **Not implemented in MVP** — print "coming in v1.4" and fall back to `--check` |
| `--scope global` | Scan `~/.claude/CLAUDE.md` only |
| `--scope project` | Scan `./CLAUDE.md` only |
| `--scope all` (default) | Scan both scopes |

---

## Phase 1: DISCOVER — Locate CLAUDE.md Files

Probe for CLAUDE.md at each supported scope:

```bash
SCOPES=()
[ -f "$HOME/.claude/CLAUDE.md" ] && SCOPES+=("global:$HOME/.claude/CLAUDE.md")
[ -f "./.claude/CLAUDE.md" ] && SCOPES+=("project-local:./.claude/CLAUDE.md")
[ -f "./CLAUDE.md" ] && SCOPES+=("project:./CLAUDE.md")
```

If no CLAUDE.md files exist at any scope, exit early with "No CLAUDE.md files found. blitz is ready with defaults."

Filter `SCOPES` based on the `--scope` argument.

---

## Phase 2: PARSE — Extract Rules

For each CLAUDE.md file in `SCOPES`, load its content.

**Stage 1 — Regex scan** (zero LLM cost, deterministic):

Load the conflict catalog from `${CLAUDE_PLUGIN_ROOT}/skills/setup/conflict-catalog.json`. For each pattern in the catalog, grep the CLAUDE.md content for matches. Record hits with:
- `scope` (global / project-local / project)
- `pattern_id` (from catalog)
- `line_number` (in the CLAUDE.md)
- `matched_snippet` (one line; sanitized — no surrounding context that may contain secrets)

**Stage 2 — (deferred to future version)**: LLM semantic pass on files >200 lines. Not in MVP.

---

## Phase 3: VALIDATE — Tool Permissions

Check that blitz skills' required tools are permitted in the user's settings:

```bash
USER_SETTINGS="$HOME/.claude/settings.json"
PROJECT_SETTINGS="./.claude/settings.json"

REQUIRED_TOOLS=(Agent SendMessage TeamCreate TaskCreate TaskUpdate Write Edit Bash)

for settings_file in "$USER_SETTINGS" "$PROJECT_SETTINGS"; do
  [ -f "$settings_file" ] || continue
  # Parse permissions.allow and permissions.deny with jq
  ALLOW=$(jq -r '.permissions.allow // [] | join(",")' "$settings_file" 2>/dev/null)
  DENY=$(jq -r '.permissions.deny // [] | join(",")' "$settings_file" 2>/dev/null)
  # Check for missing required tools in allow (if allow is non-empty, treat as allowlist mode)
  # Record findings
done
```

Record findings for any required tool that is explicitly denied or absent from a non-empty allowlist.

---

## Phase 4: STACK CHECK — Command Assumptions

Detect package manager and verify blitz's default command assumptions match:

```bash
# Detect package manager from lockfile
if [ -f pnpm-lock.yaml ]; then PM=pnpm
elif [ -f bun.lockb ]; then PM=bun
elif [ -f yarn.lock ]; then PM=yarn
elif [ -f package-lock.json ]; then PM=npm
else PM=unknown; fi
```

If `$PM != npm`, record a MEDIUM-severity finding: "blitz verify commands default to `npm run *`; detected package manager is `$PM`. Some skills may fail silently on tool invocation."

Read `package.json` `scripts` and verify:
- `type-check` or `typecheck` script exists → if absent, record LOW finding
- `test` script exists → LOW if absent
- `build` script exists → LOW if absent
- `lint` script exists → LOW if absent

---

## Phase 5: REPORT — Present Findings

Aggregate findings from Phases 2–4. Group by severity: HIGH / MEDIUM / LOW.

Print:

```
[setup] CLAUDE.md Conflict Report
══════════════════════════════════════════════════════════════════════
Scopes scanned: <list of CLAUDE.md paths>
Tool permissions checked: <list of settings.json paths>
Package manager detected: <pnpm|npm|yarn|bun|unknown>

HIGH (N)
──────
  [pattern-id]  <rule text, trimmed>
    Scope:     <scope>:<line>
    Conflicts: <comma-separated skill names>
    Fix:       <remediation from catalog>

MEDIUM (N)
──────
  ... (same format)

LOW (N)
──────
  ... (same format)

SUMMARY
───────
Total: <N> conflicts  (<H> HIGH, <M> MEDIUM, <L> LOW)
<N> tool-permission gaps
<N> stack-assumption mismatches

Advice:
<If HIGH count > 0>: Address HIGH conflicts before invoking sprint-dev
  or code-sweep --loop. These skills auto-commit/auto-push and will
  violate your stated rules.
<If MEDIUM count > 0>: Review MEDIUM conflicts — they cause surprise
  behavior but rarely break workflows.
<If no conflicts>: No conflicts detected. blitz defaults match your
  CLAUDE.md rules. Ready to go.
```

---

## Phase 6: COMPLETE

1. Log `task_complete` to `.cc-sessions/activity-feed.jsonl`.
2. If no conflicts: print "No conflicts detected. blitz is ready."
3. Exit with status 0 on any finding severity (report-only mode). Future `--fix` mode will exit non-zero on unresolved HIGH conflicts.

---

## Error Recovery

- **No CLAUDE.md found at any scope**: Exit 0 with "No CLAUDE.md files found. blitz is ready with defaults."
- **Conflict catalog missing or malformed**: Exit 1 with "ERROR: assets/conflict-catalog.json is invalid; reinstall the blitz plugin." Link to GitHub issues.
- **settings.json unparseable**: Record a LOW finding noting the file is malformed; continue with other checks.
- **jq not installed**: Fall back to basic grep-based permission checks; note in the report that detection was incomplete.
