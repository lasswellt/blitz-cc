---
id: E-041
title: "Session management v2 — hook-owned records, messaging, inbox, dashboard"
status: implemented
implemented_in: "2.5.0"
priority: P0
phase: 1
domain: session
depends_on: [E-040]
cc_floor: "2.1.271"
estimated_stories: 9
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-041 Session management v2

**Why.** Registration today is prose the model executes (`session-lifecycle.md` §Session Registration). A skill that skips the preamble is invisible to every peer and to the conflict matrix. The platform now hands hooks a native `session_id`, `transcript_path`, `scratchpad_dir`, and a messaging socket; `claude agents --json` exposes `state` / `status` / `waitingFor`; sessions can message each other and ask for a one-shot idle notice. herdr and Lantern both converge on the same shape: deterministic state capture, an attention queue, a heartbeat that escalates, and a single view.

**Model.** One record per native session at `.cc-sessions/sessions/<session_id>.json`, **written by hooks**, **enriched by skills** (`skill`, `working_on`, `args`), **overlaid at read time** with agent-view JSON. Skills never mint IDs.

```
{ "session_id": "...", "harness": "claude", "cwd": "...", "dirs": [],
  "started": "...", "last_activity": "...", "status": "active|completed|suspended|cleared|failed",
  "state": "working|idle", "skill": null, "working_on": null, "args": null,
  "locks_held": [], "transcript_path": "...", "scratchpad_dir": "...",
  "permission_mode": "...", "effort": "...", "agent_type": null, "source": "startup|resume|clear|compact|fork" }
```

## Stories

### S1 Hook-owned session records
- **Files:** `hooks/scripts/session-start.sh`; new `hooks/scripts/session-end.sh`, `hooks/scripts/heartbeat.sh` (wired `PostToolBatch`, async; absorbs `post-tool-batch.sh`), `hooks/scripts/stop-turn.sh`; `hooks/scripts/_lib/common.sh`.
- **Change:** `session-start.sh` reads stdin, writes the record via `blitz_atomic_write`, logs `session_start` with `session=<session_id>` (retires the model-written entry, C13); on `source=resume` reopens the existing record. `heartbeat.sh` bumps `last_activity`, sets `state: working`. `stop-turn.sh` sets `state: idle`, drains `.cc-sessions/mailbox/<sid>.jsonl` into the session's own inbox socket (`CLAUDE_CODE_MESSAGING_SOCKET` + `CLAUDE_CODE_MESSAGING_TOKEN`; no-op when absent). `last_assistant_message` is never stored. `pre-compact-snapshot.sh` switches to stdin `session_id` (C9).
- **Helpers in `common.sh`:** `blitz_session_record_path`, `blitz_session_update <sid> <jq-filter>` (atomic), `blitz_agent_view` (`claude agents --json --all` → map by `sessionId` → `{state,status,waitingFor,name,pid,kind}`), `blitz_session_stale` (`last_activity` > 30 min AND overlay `state` ∉ {working, blocked}, OR `started` > 4 h with no overlay), `blitz_inbox_post <text>`, `blitz_mailbox_send <sid> <text>`. Fix `blitz_live_worktree_paths` to filter `state ∈ {working, blocked}` (C2).
- **Acceptance:** `bats hooks/tests/session-helpers.bats` with a fake `claude` shim on PATH returning canned agent-view JSON; record transitions verified end to end.

### S2 Protocol rewrite
- **Files:** `skills/_shared/session-lifecycle.md` §Session Registration, §5a, §5b-i, §Conflict Matrix, §Session Cleanup; `skills/_shared/terse-output.md` §Activity Feed; `CLAUDE.md`; `hooks/scripts/blitz-prompt-expansion.sh`.
- **Change:** Step 1 becomes `SESSION_ID="${CLAUDE_SESSION_ID}"`; step 3 becomes a PATCH of `skill` / `working_on` / `args`; tmp dir = `scratchpad_dir` (fallback `.cc-sessions/sessions/<sid>/tmp/`). §5b-i uses `blitz_agent_view` and keys conflicts on `state` / `waitingFor`. Feed `session` field = native ID; new hook-emitted events `session_start`, `session_end`, `idle`, `needs_input`, `permission_denied`, `cache_bust`, `mailbox` documented as such. Mailbox line schema `{ts, from, to, kind: note|unblock|halt, text}`. CLAUDE.md drops the model-written session_start; prompt-expansion injects `skill/working_on` of other active sessions.
- **Acceptance:** `markdown-link-validate.sh` green; `skill-frontmatter-validate.sh --all` green; no skill still generates `<skill>-<hex>` IDs (`grep -rn "8-char-random-hex" skills/` empty).

### S3 Conflict matrix gains a messaging column
- **Files:** `skills/_shared/session-lifecycle.md` §Conflict Matrix; `skills/_shared/security.md` (new TB-5).
- **Change:** BLOCK → `ListAgents`, locate the peer by `sessionId`, `SendMessage(to, notify_when_idle: true)` with a one-line reason, print `LOOP_DEFER`, exit. WARN → `SendMessage` one-line notice ("blitz: sprint-dev wave 2 editing src/stores/*"). When the peer's `crossSessionInbound` is `hold` / `refuse`, degrade to WARN-only and say so. TB-5 recommends `crossSessionInbound: hold` for unattended `-p` workers and documents that an inbound message can never approve, change config, or run commands.
- **Acceptance:** two sessions in one container: a second `sprint-dev` on the same sprint prints `LOOP_DEFER` and the first receives the notice; verified manually and recorded in the epic's PR.

### S4 Inbox and heartbeat triage (Lantern pattern)
- **Files:** new `.cc-sessions/inbox.jsonl` (schema below); `hooks/scripts/notification-log.sh`, `permission-denied.sh`, `startup-validate.sh` (quarantine → inbox), `worktree-create.sh` (collision → inbox); `skills/next/SKILL.md`; `skills/_shared/session-lifecycle.md` §Scheduling.
- **Schema:** `{ts, id, source: hook|skill|cron, kind: needs_input|permission|blocked|stale_lock|quarantine|hook_failure|escalation, session, text, status: pending|converted|dismissed, age_h}`.
- **Change:** `/blitz:next` (and each `--loop` tick) triages the inbox first: blocked > 24 h → escalation line, stale lock → release per matrix, quarantine → surface; prints `HEARTBEAT_OK` when the inbox is empty and no session is `waitingFor`. Items > 7 d old fold into one "needs triage" escalation.
- **Acceptance:** `bats hooks/tests/inbox.bats`; `/blitz:next` on an empty inbox prints `HEARTBEAT_OK`.

### S5 `/blitz:sessions` skill
- **Files:** new `skills/sessions/SKILL.md` + `references/main.md`; new `scripts/sessions-dashboard.sh`; `skills/_shared/skill-cross-references.md`; counts.
- **Frontmatter:** read-only; `model: inherit`; `allowed-tools: Read, Bash, Glob, Grep, ListAgents`; `compatibility: ">=2.1.271"`; `argument-hint: "[list|attention|dashboard|prune] [--html]"`.
- **Modes:** `list` (table: sid, skill, state/status overlay, waitingFor, age, cwd, PR); `attention` (queue = overlay `waitingFor` ≠ null OR `state=blocked` OR last feed event ∈ {needs_input, permission_denied} newer than last `idle` OR inbox pending; oldest first); `dashboard` (markdown: sessions, attention, locks, timeline from last 200 feed lines, best-effort token estimate from `context-char-count` / transcript size; `--html` → `emit_html`); `prune` (closed > 7 d; never a live overlay).
- **Why a new skill, not `health`:** health = structural assertions about the plugin; sessions = runtime state of this checkout. `/blitz:health` §2.x delegates.
- **Acceptance:** `skill-frontmatter-validate.sh skills/sessions/SKILL.md`; dashboard renders with zero sessions; `--html` output passes the `sanitize_html` boundary test.

### S6 Move `emit_html` into a script library
- **Files:** new `hooks/scripts/_lib/html.sh`; `skills/_shared/html-template-helper.md`.
- **Change:** the bash bodies of `sanitize_html` / `emit_html` move to `html.sh`; the protocol doc references it (keeps "never inline a second copy" true now that a script consumer exists). Add `sessions` to the Adopters table.
- **Acceptance:** audit / codebase-map / quality-metrics / research `--html` paths unchanged in bats.

### S7 sprint-dev monitoring and peer coordination
- **Files:** `skills/sprint-dev/SKILL.md` §3.2 (line 322), §3.2.2 (new); `agents/orchestrator.md` §Watch background tasks.
- **Change:** `Monitor(..., timeout: 1800)` re-armed at each wave boundary; on deadline expiry fall back to `TaskList` polling (C1). At each wave boundary `ListAgents`; if a `sprint-review` session for the same sprint is `waiting`, `SendMessage` "wave N merged"; honor inbound `halt` mailbox lines by finishing the current story and writing STATE.md.
- **Acceptance:** no `persistent:` left in `skills/`; sprint-dev bats fixture for wave-boundary message emission.

### S8 `/blitz:health` handoff
- **Files:** `skills/health/SKILL.md` §2.1, §2.5.
- **Change:** use `blitz_session_stale` + overlay; report daemon status, live count by `state`, attention count; link to `/blitz:sessions` for detail. `compatibility` → `>=2.1.271`.

### S9 `/blitz:conform` migration
- **Files:** `skills/conform/SKILL.md`.
- **Change:** migrate `.cc-sessions/<skill>-<hex>.json` → `sessions/<native id>.json` where a native ID is recoverable from the feed, else mark `legacy: true`; rewrite feed `session` values when a mapping exists.

## Verification
- Full validator sweep + `bats hooks/tests/`.
- Manual two-session scenario (S3) and a `claude --bg "/blitz:audit"` scenario showing the background session in `/blitz:sessions list` with `state` from the overlay.

## Risks
- Same-container constraint: sessions on host vs container cannot message; the overlay and records still work.
- Agent-view JSON is a research preview; keep the jq mapping in one helper so a schema change is a one-line fix.
- Inbox growth: mirror the feed's truncation rule (keep last 200, drop > 7 d dismissed).
