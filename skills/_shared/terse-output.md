# Terse Output Protocol

Blitz's output-compression directive for skills and spawned agents. Inspired by the caveman-mode pattern (MIT, github.com/JuliusBrussee/caveman) and internalized here so blitz has no runtime dependency on external plugins.

**Purpose:** reduce model output tokens 20–40% without sacrificing technical accuracy. Applies to orchestrator-to-user prose, agent-to-orchestrator reports, findings summaries, decision rationale. Does NOT apply to structured artifacts, code, or exact-match payloads.

**Absorbs** (2026-06-06 `_shared` consolidation): `verbose-progress.md` (console verbosity + activity-feed logging) — appended below under its original headings; output shaping and progress logging are one concern.

## Canonical Snippet

Every SKILL.md and every `agents/*.md` must contain this exact one-line directive verbatim. `skill-frontmatter-validate.sh` and `agent-frontmatter-validate.sh` hash-compare each file's OUTPUT STYLE line against this canonical source. Drift between the canonical and a deployed copy fails the validator.

<!-- canonical-output-style-start -->
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
<!-- canonical-output-style-end -->

Agents may extend the canonical snippet with a trailing addendum (e.g., `agents/critic.md` appends "No apologies. No 'I'll now check…' prose. Only findings or LGTM."). Extensions are out of scope for the hash check — only the canonical line above is enforced byte-identical. Future stricter enforcement could compare a hash of the extended block bounded by `<!-- output-style-extend: <agent> -->` / `<!-- end-extend -->` markers.

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
| `lite` | Drop fillers and pleasantries; keep full sentences | Default for user-facing orchestrator output |
| `full` | Fragments allowed; articles dropped; telegraphic | Agent-to-orchestrator reports; verification summaries |
| `ultra` | Maximum compression; symbol shorthand allowed | Internal checkpoint markers; bulk status lines |

Skills SHOULD declare an intended level in their SKILL.md frontmatter (`output_style: lite|full|ultra`). Default when unspecified: `lite`.

---

## Intensity override precedence (model-followed convention)

This is an **advisory convention the orchestrator follows when interpolating** the active intensity into a spawn prompt — NOT a deterministic resolver read by any hook or script. When the orchestrator assembles the OUTPUT STYLE snippet for an Agent() spawn or skill invocation, it SHOULD consult these sources in order and use the first one present:

1. **Environment variable:** `BLITZ_OUTPUT_INTENSITY=lite|full|ultra` — session-scoped override, typically set for one `/loop` run.
2. **Developer profile:** `.cc-sessions/developer-profile.json` top-level `output_intensity` field — per-user/per-repo preference that survives sessions.
3. **Skill frontmatter:** `output_intensity: lite|full|ultra` in the SKILL.md frontmatter — per-skill declaration.
4. **Output-style field:** the legacy `output_style:` frontmatter field (treated as an alias of `output_intensity`).
5. **Default:** `lite`.

The chosen intensity is what gets substituted into the canonical `agent-orchestration.md` §7 OUTPUT STYLE snippet when agents spawn. See `agent-orchestration.md` for the interpolation point. Because resolution is model-followed rather than coded, treat the ordering as a strong recommendation, not a guaranteed runtime contract.

---

## Preservation boundary (non-negotiable)

Never compress:

1. Fenced code blocks (` ``` ... ``` `) and inline code (`` `...` ``)
2. YAML frontmatter and JSON bodies
3. File paths and URLs
4. Grep patterns, regex strings, exact-match phrases inside tables
5. Commit messages and PR descriptions (rendered verbatim elsewhere)
6. Scope blocks, registry entries, DoD checklists — every field must parse
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
| **Risks and trade-offs** | Research doc §Risks, Open Questions, ADR §Consequences | Same reason as root cause — the qualifier matters. |
| **Destructive-op confirmations** | `rm -rf`, `git push --force`, `drop table`, `kubectl delete`, package uninstall | Irreversibility demands a full sentence + reasoning chain. The user's "yes" is binding. |
| **First-time onboarding** | README quickstart sections, bootstrap output to a fresh user, error-message remediation | New users need full sentences; terse output fails the "reader picks up cold" test. |
| **Migration notices** | Breaking-change descriptions in CHANGELOG, deprecation warnings, upgrade-required prompts | Users skim; full prose ensures the action is unmissable. |

**How to apply.** When a skill's output crosses an exemption category, that section drops to LITE intensity for the duration of the section. Resume the active intensity at the next non-exempt section. Mark the boundary explicitly if the section is more than ~3 lines:

```markdown
<!-- exempt: safety -->
This operation is destructive. It will delete the production database
backup. There is no automated rollback. Type the database name to confirm.
<!-- /exempt -->
```

**Audit.** sprint-review Phase 3.6 grep-checks for `<!-- exempt: ` markers in agent prompt templates and skill outputs; missing markers around safety/destructive content is a WARN, present-but-misused markers are a BLOCKER.

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

1. **Spawn protocol** — every Agent() prompt template should append: *"Output style: terse-technical per `/_shared/terse-output.md`. Preserve code, paths, commands, structured fields verbatim. No preamble, no trailing summary."* See `agent-orchestration.md`.

2. **SKILL.md Additional Resources** — skills that produce user-facing output should list this file alongside `session-lifecycle.md`.

3. **`/blitz:compress`** — the file-compression skill applies these same rules to rewrite markdown files at author time. This doc is the reference spec for that skill.

---

## Credit

The directive structure, intensity tiers, and preservation-rule framing are adapted from caveman-mode (JuliusBrussee/caveman, MIT). The integration surface (spawn-protocol injection, SKILL.md references, file-rewriter skill) is blitz-specific.


---

<!-- ===== Absorbed from verbose-progress.md — 2026-06-06 _shared consolidation ===== -->
<!-- Inbound links of the form verbose-progress.md#anchor were mechanically rewritten to
     terse-output.md#anchor. Every heading below is preserved verbatim as an anchor target. -->

# Verbose Progress Protocol

All skills MUST emit verbose progress output so the user always knows what is happening. This protocol defines the standard format for progress reporting and cross-instance activity logging.

---

## Console Output (User-Facing)

Every skill MUST print status lines at each phase transition, substep, and decision point. Use these exact formats:

### Phase Entry

```
[<skill-name>] Phase <N>: <PHASE_TITLE>
```

Example:
```
[sprint-plan] Phase 0: CONTEXT — Loading project state
[sprint-plan] Phase 1: INITIALIZE — Selecting epics and creating sprint
```

### Substep Progress

```
[<skill-name>]   ├─ <action-in-progress>...
[<skill-name>]   ├─ <action-completed> ✓ (<detail>)
[<skill-name>]   └─ <final-substep> ✓
```

Examples:
```
[sprint-plan]   ├─ Searching for registry files...
[sprint-plan]   ├─ Found roadmap-registry.json ✓ (12 epics, 4 in-progress)
[sprint-plan]   ├─ Loading research index...
[sprint-plan]   ├─ Research index loaded ✓ (8 documents, 3 epics covered)
[sprint-plan]   ├─ Building codebase inventory...
[sprint-plan]   ├─ Inventory complete ✓ (42 source files, 3 packages)
[sprint-plan]   └─ Phase 0 complete ✓
```

### Decision Points

When a skill makes a non-trivial decision, explain WHY:

```
[<skill-name>]   ├─ DECISION: <what was decided>
[<skill-name>]   │  Reason: <why this was chosen>
```

Examples:
```
[sprint-plan]   ├─ DECISION: Selected epics EP-003, EP-004, EP-007
[sprint-plan]   │  Reason: EP-001, EP-002 are done. EP-005 blocked by EP-003. EP-006 blocked by EP-004.
[sprint-dev]    ├─ DECISION: Spawning 3 agents (no infra stories)
[sprint-dev]    │  Reason: 5 backend stories, 4 frontend stories, 3 test stories, 0 infra stories
```

### Agent Spawning

```
[<skill-name>]   ├─ SPAWNING: <agent-name> — <role description>
[<skill-name>]   │  Working on: <list of assigned items>
[<skill-name>]   │  Worktree: <path> (if applicable)
```

### Agent Progress (Orchestrator Relaying)

```
[<skill-name>]   ├─ [<agent-name>] <status message>
```

Examples:
```
[sprint-dev]   ├─ [backend-dev] Implementing S1-003: Create registration Cloud Function
[sprint-dev]   ├─ [backend-dev] S1-003 type-check PASS ✓
[sprint-dev]   ├─ [backend-dev] S1-003 committed ✓
[sprint-dev]   ├─ [frontend-dev] Implementing S1-007: User registration form
[sprint-dev]   ├─ UNBLOCK: S1-008 now ready (depends on S1-003 ✓)
```

### Warnings and Errors

```
[<skill-name>]   ⚠ WARNING: <message>
[<skill-name>]   ✖ ERROR: <message>
```

### Session Registration

```
[<skill-name>] Session registered: <SESSION_ID>
[<skill-name>]   ├─ Checking for conflicts...
[<skill-name>]   ├─ No conflicts found ✓  (or: Found active session <X>, proceeding with caution)
```

### Phase Completion

```
[<skill-name>] Phase <N> complete ✓ (<summary>)
```

### Skill Completion

```
[<skill-name>] Complete ✓ — <one-line summary>
  Duration: <elapsed>
  Activity logged to .cc-sessions/activity-feed.jsonl
```

---

## Activity Feed (Cross-Instance)

All skills MUST write to the activity feed so other Claude Code instances can see what's happening. This is the mechanism for multi-instance awareness.

### File Location

```
.cc-sessions/activity-feed.jsonl
```

### Entry Format

One JSON object per line, append-only:

```json
{"ts":"<ISO-8601>","session":"<SESSION_ID>","skill":"<skill-name>","event":"<event-type>","message":"<human-readable message>","detail":{}}
```

`session` is the **native Claude Code session id** (`${CLAUDE_SESSION_ID}` in a skill body, stdin `session_id` in a hook) — the same id that names `.cc-sessions/sessions/<id>.json`. Legacy `<skill>-<8hex>` and `cli-<8hex>` values are migrated by `/blitz:conform --fix`; `cli-<8hex>` still appears only when a hook receives no `session_id` (fallback `blitz_session_id`).

### Required Events

Every skill MUST log these events to the activity feed:

| Event Type | When | Detail Fields |
|---|---|---|
| `skill_start` | Skill begins execution | `{ "args": "<parsed arguments>", "phase": 0 }` |
| `phase_start` | Each phase begins | `{ "phase": <N>, "title": "<phase title>" }` |
| `decision` | Non-trivial decision made | `{ "choice": "<what>", "reason": "<why>" }` |
| `agent_spawn` | Agent spawned | `{ "agent": "<name>", "role": "<role>", "items": ["<assigned items>"] }` |
| `agent_progress` | Agent completes a unit of work | `{ "agent": "<name>", "item": "<story/task>", "status": "done|blocked|error" }` |
| `registry_update` | Any registry file modified | `{ "file": "<path>", "change": "<summary>" }` |
| `phase_complete` | Each phase completes | `{ "phase": <N>, "summary": "<result>" }` |
| `skill_complete` | Skill finishes | `{ "status": "success|partial|failed", "summary": "<result>" }` |
| `warning` | Non-fatal issue encountered | `{ "message": "<detail>" }` |
| `error` | Fatal or significant error | `{ "message": "<detail>", "recoverable": true|false }` |

### Hook-emitted events (skills must NOT re-emit these)

Hooks write the following deterministically via `blitz_log_event` (`skill: "hook"`, `session` = stdin `session_id`). A skill that logs its own `session_start`, `session_end` or `idle` creates a duplicate the dashboard counts twice — skills log `skill_start` / `skill_complete` instead.

| Event | Hook (event) | `detail` |
|---|---|---|
| `session_start` | `session-start.sh` (SessionStart) — writes/reopens the record | `{"source":"startup\|resume\|clear\|compact\|fork","cwd":"<path>"}` |
| `session_end` | `session-end.sh` (SessionEnd) | `{"reason":"clear\|resume\|logout\|prompt_input_exit\|other","status":"completed\|suspended\|cleared\|logged_out","locks_released":<n>,"record":true\|false}` |
| `idle` | `stop-turn.sh` (Stop) — record `state: idle` + `last_activity`. **Record-only transition, no feed line** (one per turn would swamp the feed); readers take idleness from the record / overlay, not the feed |
| `post_tool_batch` (heartbeat) | `heartbeat.sh` (PostToolBatch) — record `state: working`, `last_activity` bump | `{}` |
| `mailbox` | `stop-turn.sh` (Stop) — mailbox lines delivered to this session's inbox socket | `{"count":<n>}` |
| `needs_input` | `notification-log.sh` (Notification: permission / idle prompt / elicitation) — also writes an inbox line | `{"notification_type":"<type>","kind":"needs_input\|permission"}` |
| `notification` | `notification-log.sh` (any other Notification) | `{"notification_type":"<type>","kind":""}` |
| `permission_denied` | `permission-denied.sh` (PermissionDenied) — also writes an inbox `permission` line; never retries | `{"tool_name":"<tool>"}` |
| `permission_request` | `permission-request.sh` (PermissionRequest) | `{"tool_name":"<tool>"}` |
| `cache_bust` | `model-switch-warn.sh` (PreModelSwitch) | `{"from":"<model>","to":"<model>"}` |
| `config_change` | `config-change.sh` (ConfigChange) — re-runs `startup-validate.sh --strict` | `{"source":"user_settings\|project_settings\|local_settings\|policy_settings\|skills","validate":"pass\|fail\|skipped"}` |
| `cwd_changed` | `cwd-changed.sh` (CwdChanged) — record `cwd` | `{"cwd":"<path>"}` |
| `directory_added` | `cwd-changed.sh` (DirectoryAdded) — record `dirs[]` | `{"path":"<path>","method":"<method>"}` |
| `warning` (stale cleanup) | `session-start.sh` (SessionStart, `blitz_session_stale`) — record → `status: failed`, `failed_reason: stale_session_cleanup` | `{"session":"<sid>","locks_released":<n>,"record":"<path>","reason":"stale_session_cleanup"}` |
| `handoff_written` | `pre-compact-snapshot.sh` (PreCompact) | `{"phase":"<phase>","sprint":"sprint-N"\|null}` |
| `file_change` | `post-edit-activity-log.sh` (PostToolUse Write/Edit, `skill: "freeform"`) | `{"files":["<path>"]}` |
| `subagent_start` / `subagent_stop` / `teammate_idle` / `task_validated` / `post_tool_failure` / `stop_failure` / `worktree_create` / `worktree_remove` / `worktree_collision_blocked` / `branch_cleanup` / `verification` / `override` | the like-named hook scripts (see `hooks/scripts/README.md`) | per script header |

Skills keep the semantic layer (`skill_start`, `phase_*`, `decision`, `agent_*`, `registry_update`, `warning`, `error`, `skill_complete`). A skill MAY still log `warning` for its own conditions; the stale-cleanup `warning` shape above is hook-only.

### Inbox and mailbox line schemas

Two more JSONL files share the feed's discipline (append-only, ≤200/500-char text, injection-scanned, untrusted on read — [security.md](security.md) TB-2/TB-5):

```json
// .cc-sessions/inbox.jsonl — attention queue, one line per item needing a human or /blitz:next
{"ts":"<ISO-8601>","id":"inb-<8hex>","source":"hook|skill|cron","kind":"needs_input|permission|blocked|stale_lock|quarantine|hook_failure|escalation","session":"<session_id>","text":"<≤200 chars>","status":"pending|converted|dismissed"}

// .cc-sessions/mailbox/<target_session_id>.jsonl — hook/script → session; drained by the target's Stop hook
{"ts":"<ISO-8601>","from":"<session_id>|unknown","to":"<target_session_id>","kind":"note|unblock|halt","text":"<≤500 chars>"}
```

Hooks write inbox lines with `blitz_inbox_append <kind> <text> [session]` and mailbox lines with `blitz_mailbox_send <target> <kind> <text>` (both in `hooks/scripts/_lib/common.sh`). A skill triaging the inbox rewrites `status` in place (atomic write, one session at a time) and logs a feed `decision` per item. Which one to use when: [session-lifecycle.md](session-lifecycle.md) §Mailbox protocol.

### Message length (soft rule)

The `message` field SHOULD be ≤200 characters. The JSONL envelope (all keys except `message`) is a preservation boundary — parsers depend on its shape — but the `message` string is compression-eligible prose.

If the message would exceed 200 chars, move detail into the `detail` object. Keep the `message` a one-line human-readable summary.

**Sprint-review grep audit** (non-BLOCKER warning):

```bash
# Flag any message field over 300 chars
grep -E '"message":".{300,}"' .cc-sessions/activity-feed.jsonl
```

300 chars is the hard audit threshold (soft target is 200). A hit prints a warning but does not fail the sprint. Persistent offenders (same pattern across multiple sprints) may warrant an update to the emitting skill.

### Reading the Activity Feed

At session start (during the session protocol preamble), skills MUST:

1. Read the last 20 lines of `.cc-sessions/activity-feed.jsonl` (if it exists).
2. Print a summary of recent activity:

```
[<skill-name>] Recent activity (last 30 minutes):
  ├─ [8c1d…f0a2] sprint-dev: Implementing sprint 3 — 8/12 stories done (15m ago, working)
  ├─ [3b77…91ce] research: Completed auth-strategy research (28m ago, idle)
  └─ No conflicts detected ✓
```

3. If any active session is working on conflicting resources, warn before proceeding.

### Writing to the Activity Feed

Use append mode. Example bash implementation:

```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","session":"'"${SESSION_ID}"'","skill":"<skill-name>","event":"skill_start","message":"Starting <skill-name>","detail":{"args":"<args>","phase":0}}' >> .cc-sessions/activity-feed.jsonl
```

Or use the Write tool with append semantics (read existing content, add new line, write back) if bash append is not available.

### Feed Maintenance

The activity feed is append-only and grows over time. To prevent unbounded growth:
- Skills MAY truncate entries older than 7 days when the file exceeds 500 lines.
- Truncation should preserve the most recent 200 entries.
- Only one session should truncate at a time (use a brief lock if needed).

The same rule applies to `.cc-sessions/inbox.jsonl`: keep the most recent 200 `pending|converted` lines, drop `dismissed` lines older than 7 days (`/blitz:next` Phase 0.5 and `/blitz:sessions prune` do this; same single-truncator rule). Mailbox files are truncated by their own `Stop` hook on delivery and need no sweep; `/blitz:sessions prune` removes mailboxes whose target record is closed > 7 d.

---

## Sprint Selection Verbosity (Special Case)

Sprint-family skills (sprint, sprint-plan, sprint-dev, sprint-review, implement, review, ship) require structured decision-tree output at key moments. Use the formats below — adapt the data, keep the shape.

| Trigger | Format | Required content |
|---|---|---|
| Epic selection (sprint-plan) | Tree (`├─ EP-XXX "title" — STATUS → action`) | Every candidate epic + status + reason + selection verdict |
| Story distribution (sprint-dev) | Tree grouped by agent role | Every story + priority + points + dependencies per agent |
| Wave progress (sprint-dev) | `Wave N: <progress-bar> N/M stories <state>` per wave | All waves + completion fraction + critical-path note |
| Sprint dashboard (sprint-dev, every 3 completions or wave boundary) | Box-drawing dashboard with stories %/points %/per-agent rows | Stories, points, per-agent progress, ready/blocked/in-progress lists |

Canonical examples (copy + adapt):

```
[sprint-plan] Epic Selection:
  ├─ EP-003 "Dashboard" — UNBLOCKED (deps: EP-001 ✓, EP-002 ✓) → SELECTED
  ├─ EP-005 "Admin Panel" — BLOCKED (deps: EP-003 pending) → skip
  └─ EP-007 "API Keys" — UNBLOCKED (no deps) → SELECTED
  Selected: 3 epics; estimated stories: 12-18

[sprint-dev] Wave Progress:
  Wave 0: ████████████████████ COMPLETE (3/3)
  Wave 1: ██████████░░░░░░░░░░ 2/4 in progress
  Critical path: on track (Wave 1 ETA: ~2 more stories)

[sprint-dev] Progress Dashboard:
  Stories 6/12 (50%) · Points 19/41 (46%) · Wave 2 of 4
  backend 3/5 · frontend 1/4 · test 2/3
  Ready: S3-010, S3-011 · Blocked: S3-012 (waits S3-008) · In-progress: S3-004
```

Box-drawing dashboards (`┌─┐│└─┘`) are acceptable when terminal width permits but not required — the inline form above conveys the same information.

---

## Integration with Existing Session Protocol

This protocol extends (not replaces) the session-lifecycle.md. Specifically:

1. **Session registration** now includes activity feed write (skill_start event).
2. **Session cleanup** now includes activity feed write (skill_complete event).
3. **Lock operations** already logged in operations.log — activity feed logs higher-level events only.
4. **Conflict detection** now also reads the activity feed for recent context.

All skills that reference session-lifecycle.md should also follow this verbose-progress protocol.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
