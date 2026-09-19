# Output Protocol

Blitz's output-compression directive for skills and spawned agents, plus the console progress format every skill prints. Inspired by the caveman-mode pattern (MIT, github.com/JuliusBrussee/caveman) and internalized here so blitz has no runtime dependency on external plugins.

**Purpose:** reduce model output tokens 20–40% without sacrificing technical accuracy. Applies to main-thread-to-user prose, agent-to-main-thread reports, findings summaries, decision rationale. Does NOT apply to structured artifacts, code, or exact-match payloads.

## Enforcement

Output style is enforced by `output-styles/terse-technical.md` (`force-for-plugin: true`), which the platform applies while blitz is enabled. Skills and agents do not repeat a snippet in their bodies; there are no hash markers and no validator comparison. Spawn prompts include the single line `Output: terse-technical per output.md; fragments OK; preserve code, paths, commands, JSON verbatim.` Agents may append a short addendum to that line (e.g., `critic`: "No apologies. No 'I'll now check…' prose. Only findings or LGTM.").

---

## Core rule

Speak technical-first, filler-free. Format preferred: `[subject] [verb] [reason]. [next action].`

**Drop:**
- Articles (a / an / the) where the meaning is unambiguous without them
- Fillers: *just, really, basically, actually, simply, quite, very*
- Pleasantries and preambles: *sure, certainly, I'd be happy to, let me*
- Hedging: *it seems, perhaps, maybe, arguably, somewhat*
- Trailing summaries of work already evident in the diff or tool output

**Keep:**
- Exact technical vocabulary and proper nouns
- Code (verbatim)
- File paths, URLs, commands, CLI flags
- Version numbers, dates, error codes
- Numbers, identifiers, grep patterns
- Headings and list structure

---

## Intensity levels

| Level | Description | When to use |
|---|---|---|
| `lite` | Drop fillers and pleasantries; keep full sentences | Default for user-facing main-thread output |
| `full` | Fragments allowed; articles dropped; telegraphic | Agent-to-main-thread reports; verification summaries |
| `ultra` | Maximum compression; symbol shorthand allowed | Internal checkpoint markers; bulk status lines |

Skills SHOULD declare an intended level in their SKILL.md frontmatter (`output_intensity: lite|full|ultra`). Default when unspecified: `lite`.

---

## Intensity override precedence (model-followed convention)

This is an **advisory convention the main thread follows when interpolating** the active intensity into a spawn prompt — NOT a deterministic resolver read by any hook or script. When assembling the `Output:` line for an Agent() spawn or skill invocation, consult these sources in order and use the first one present:

1. **Environment variable:** `BLITZ_OUTPUT_INTENSITY=lite|full|ultra` — session-scoped override, typically set for one `/loop` or `next --loop` run.
2. **Skill frontmatter:** `output_intensity: lite|full|ultra` in the SKILL.md frontmatter — per-skill declaration.
3. **Output-style field:** the legacy `output_style:` frontmatter field (treated as an alias of `output_intensity`).
4. **Default:** `lite`.

The chosen intensity is what gets substituted into the spawn `Output:` line when agents spawn (see [agents.md](/_shared/agents.md)). Because resolution is model-followed rather than coded, treat the ordering as a strong recommendation, not a guaranteed runtime contract.

---

## Preservation boundary (non-negotiable)

Never compress:

1. Fenced code blocks (` ``` ... ``` `) and inline code (`` `...` ``)
2. YAML frontmatter and JSON bodies
3. File paths and URLs
4. Grep patterns, regex strings, exact-match phrases inside tables
5. Commit messages and PR descriptions (rendered verbatim elsewhere)
6. `tasks.json` entries, `verify[]` commands, DoD checklists — every field must parse
7. Commands the user might copy-paste
8. Error messages and stack traces quoted for diagnosis

If compression would alter any of the above, write the original form. Correctness dominates brevity.

---

## Auto-pause conditions

Temporarily drop terse mode and write normally when:

- Reporting a security warning or credential risk
- Confirming an irreversible action (delete, force-push, drop-table)
- The user appears confused by prior terse output (explicit ask for clarification)
- Explaining a non-obvious root cause where compressed prose would lose the reasoning chain

Resume terse mode on the next response.

---

## Canonical Exemptions List

Authoritative — overrides any per-skill exemption declarations. Skills MUST NOT redefine the exemption set in their SKILL.md frontmatter; if a skill thinks it needs a new exemption category, propose it here first.

Sections in any agent or skill output that ALWAYS use full-prose (LITE intensity) regardless of the active intensity level:

| Section type | Examples | Why exempt |
|---|---|---|
| **Safety rules** | "Never run X against prod", "Never bypass Y", security warnings, credential-handling guidance | Compressed safety language has caused real incidents (e.g., a "use --no-verify only when needed" terse line that dropped the only-when-needed condition). |
| **Root cause analyses** | Bug post-mortems, "why did this break", architectural decision records | The reasoning chain is the value; compression loses it. |
| **Risks and trade-offs** | Research doc §Risks, Open Questions, `plan.md` §Risks, ADR §Consequences | Same reason as root cause — the qualifier matters. |
| **Destructive-op confirmations** | `rm -rf`, `git push --force`, `drop table`, `kubectl delete`, package uninstall | Irreversibility demands a full sentence + reasoning chain. The user's "yes" is binding. |
| **First-time onboarding** | README quickstart sections, `onboard` output to a fresh user, error-message remediation | New users need full sentences; terse output fails the "reader picks up cold" test. |
| **Migration notices** | Breaking-change descriptions in CHANGELOG, deprecation warnings, upgrade-required prompts | Users skim; full prose ensures the action is unmissable. |

**How to apply.** When a skill's output crosses an exemption category, that section drops to LITE intensity for the duration of the section. Resume the active intensity at the next non-exempt section. Mark the boundary explicitly if the section is more than ~3 lines:

```markdown
<!-- exempt: safety -->
This operation is destructive. It will delete the production database
backup. There is no automated rollback. Type the database name to confirm.
<!-- /exempt -->
```

**Audit.** `check` grep-checks for `<!-- exempt: ` markers in agent prompt templates and skill outputs; missing markers around safety/destructive content is a WARN, present-but-misused markers are a BLOCKER.

---

## Examples

| Verbose (before) | Terse (after) |
|---|---|
| "I'd be happy to take a look at that bug. Let me search the codebase and find where the issue might be." | "Investigating bug. Searching codebase." |
| "It seems like the problem is basically that the cache isn't being invalidated when the user updates their profile." | "Cache not invalidated on profile update." |
| "I've completed the refactor. Here's a summary of what I changed: I updated three files to use the new API, removed the deprecated helper, and added tests." | "Refactor done. Three files migrated to new API, deprecated helper removed, tests added." |
| "Sure! In order to fix this, we should probably just add a null check." | "Add null check." |

---

## Integration points in blitz

1. **Spawn prompts** — every Agent() prompt template carries the single `Output:` line from §Enforcement. See [agents.md](/_shared/agents.md).
2. **SKILL.md Additional Resources** — skills that produce user-facing output should list this file alongside [sessions.md](/_shared/sessions.md).
3. **Output style** — `output-styles/terse-technical.md` is the platform-level enforcement; this file is the reference spec it summarizes.

## Credit

The directive structure, intensity tiers, and preservation-rule framing are adapted from caveman-mode (JuliusBrussee/caveman, MIT). The integration surface (spawn-prompt line, SKILL.md references, forced output style) is blitz-specific.

---

# Verbose Progress Protocol

All skills MUST emit verbose progress output so the user always knows what is happening. This protocol defines the standard format for progress reporting; the cross-instance activity feed that accompanies it is specified in [sessions.md](/_shared/sessions.md).

---

## Console Output (User-Facing)

Every skill MUST print status lines at each phase transition, substep, and decision point. Use these exact formats:

### Phase Entry

```
[<skill-name>] Phase <N>: <PHASE_TITLE>
```

Example:
```
[plan] Phase 0: CONTEXT — Loading project state
[plan] Phase 1: TASKS — Writing spec, plan, and tasks.json
```

### Substep Progress

```
[<skill-name>]   ├─ <action-in-progress>...
[<skill-name>]   ├─ <action-completed> ✓ (<detail>)
[<skill-name>]   └─ <final-substep> ✓
```

Examples:
```
[plan]   ├─ Reading docs/plans/BACKLOG.md...
[plan]   ├─ Backlog loaded ✓ (6 notes, 2 tagged for this slug)
[plan]   ├─ Solutions loaded ✓ (5 documents, cap reached)
[plan]   └─ Phase 0 complete ✓
```

### Decision Points

When a skill makes a non-trivial decision, explain WHY:

```
[<skill-name>]   ├─ DECISION: <what was decided>
[<skill-name>]   │  Reason: <why this was chosen>
```

Examples:
```
[plan]    ├─ DECISION: Classified as architectural — writing spec.md
[plan]    │  Reason: touches auth flow and two packages; one-sentence diff not possible
[build]   ├─ DECISION: Task path, sequential (no --parallel)
[build]   │  Reason: 4 open tasks, only 2 have disjoint files
```

### Agent Spawning

```
[<skill-name>]   ├─ SPAWNING: <agent-name> — <role description>
[<skill-name>]   │  Working on: <list of assigned items>
[<skill-name>]   │  Worktree: <path> (if applicable)
```

### Agent Progress (Main Thread Relaying)

```
[<skill-name>]   ├─ [<agent-name>] <status message>
```

Examples:
```
[build]   ├─ [dev] Implementing T-003: Create registration Cloud Function
[build]   ├─ [dev] T-003 committed ✓ (Task: auth/T-003)
[build]   ├─ UNBLOCK: T-008 now ready (deps: T-003 ✓)
```

### Warnings and Errors

```
[<skill-name>]   ⚠ WARNING: <message>
[<skill-name>]   ✖ ERROR: <message>
```
### Session Registration, Phase and Skill Completion

```
[<skill-name>] Session registered: <SESSION_ID>
[<skill-name>]   ├─ No conflicts found ✓  (or: Found active session <X>, proceeding with caution)
[<skill-name>] Phase <N> complete ✓ (<summary>)
```

```
[<skill-name>] Complete ✓ — <one-line summary>
  Duration: <elapsed>
  Activity logged to .cc-sessions/activity-feed.jsonl
```

## Activity Feed (Cross-Instance)

Skills append loop/skill-level events (`skill_start`, `decision`, `verification`, `skill_end`) to `.cc-sessions/activity-feed.jsonl` so other Claude Code instances can see what is happening. The line schema, `session` id rule, and required event set live in [sessions.md](/_shared/sessions.md); do not restate them here. Per-edit logging is OpenTelemetry's job, not the feed's.

## Integration with Session Protocol

This protocol extends (not replaces) [sessions.md](/_shared/sessions.md): session registration writes `skill_start`, session cleanup writes `skill_end`, and conflict detection also reads the feed for recent context. All skills that reference sessions.md should also follow this verbose-progress protocol.

## Related protocols

- [sessions.md](/_shared/sessions.md) — session registration, conflict matrix, activity feed / inbox / mailbox line schemas.
- [agents.md](/_shared/agents.md) — spawn prompt contract that carries the `Output:` line.
- `output-styles/terse-technical.md` — the forced output style that enforces this protocol.
