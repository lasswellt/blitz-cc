# Output Protocol

Blitz's output-compression directive for skills and spawned agents, plus the console progress format every skill prints. Inspired by the caveman-mode pattern (MIT, github.com/JuliusBrussee/caveman) and internalized here so blitz has no runtime dependency on external plugins.

**Purpose:** reduce model output tokens 20–40% without sacrificing technical accuracy. Applies to main-thread-to-user prose, agent-to-main-thread reports, findings summaries, decision rationale. Does NOT apply to structured artifacts, code, or exact-match payloads.


> **Reference:** [output.reference.md](output.reference.md) carries the rest of this protocol: The canonical exemptions list, worked examples, console output formats per phase, activity-feed integration, and credits. Load it when you need one of those; this file is the contract every consumer obeys.

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
