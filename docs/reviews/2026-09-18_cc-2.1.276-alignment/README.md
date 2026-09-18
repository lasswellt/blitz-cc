---
title: "blitz-cc alignment review — Claude Code 2.1.276 (September 2026)"
date: 2026-09-18
status: accepted
plugin_version_reviewed: 2.4.4
cc_version_reviewed_against: 2.1.276
epics: [E-040, E-041, E-042, E-043, E-044, E-045, E-046, E-047]
---

# blitz-cc alignment review — Claude Code 2.1.276

**Scope.** Qualitative review of the plugin (37 skills, 11 agents, 38 hook scripts, 13 shared protocols) against Claude Code as of 2026-09-18 and against current agentic-engineering practice. Last release 2.4.4 shipped 2026-06-07 against ~2.1.157; roughly 120 platform releases are unreviewed.

**Inputs.** Anthropic docs (best-practices, hooks, sub-agents, skills, memory, sessions, agent view, cross-session messaging, workflows, scheduled tasks, channels, `/goal`, plugins reference, changelog 2.1.158–2.1.276), three Anthropic blog posts (session value, test impact analysis, Projects redesign), herdr (GitHub README + session-manager plugin), and the Lantern agent-dashboard article. Full list with fetch dates: [sources.md](sources.md).

**Output.** Eight epic-ready plans under [epics/](epics/), numbered E-040..E-047 (continuing from E-039). **All eight were implemented in release 2.5.0 (2026-09-18)**; each epic file carries `status: implemented`. Two items still need a live-account check (see CHANGELOG 2.5.0).

---

## 1. Scorecard

| Area | Grade | Headline finding |
|---|---|---|
| Version floors | C | Four floors (2.1.71 / 117 / 152 / 157) scattered across `plugin.json`, `README.md:98`, `agent-orchestration.md:1059`, installer. No single source. Platform is at 2.1.276. |
| Hook surface | B- | 16 of 33 events wired. `Stop` deliberately unwired (`hooks/scripts/README.md:104`) but is now the platform's heartbeat / mailbox / verification-gate primitive. No use of `if`, `statusMessage`, `once`, `async`, `asyncRewake`, exec-form `args`, or `prompt`/`agent` hook types. |
| Session management | C+ | Registration is model-executed prose (unenforced). Native `session_id`, `transcript_path`, `scratchpad_dir`, `CLAUDE_CODE_MESSAGING_SOCKET` unused. Agent-view overlay filters the wrong field (C2). No cross-session messaging, no attention queue, no dashboard. |
| Verification | B | Seven deterministic blockers and an 8-invariant gate are strong. No `/goal`, no Stop-hook gate, no `/verify` recipe. sprint-dev's `Monitor(..., persistent: true)` is removed API (C1). |
| Test selection | D | `npm test -- --changed` plus a filename-sibling matcher. No journal, no selector, no calibration. |
| Memory / context | B- | `memory: project` on 7 agents is right. KNOWLEDGE.md and auto memory unreconciled. All 37 skills pin `model: opus` + `effort`, forcing a model/effort switch (prompt-cache bust) on every invocation from a non-opus session (C6). CLAUDE.md carries a hook-shaped procedure (C13). |
| Plugin quality | B | Validators + bats + CI are solid. No `evals/` for `claude plugin eval`, no `/skill-doctor` budget check, Workflow scripts embedded in skill prose rather than `workflows/`. |
| Hygiene | C | README headings say 10 agents / 12 protocols against a banner of 11 / 13; `ci.yml` says 10; `[Unreleased]` holds four review rounds; research cited from shipped protocols is gitignored; two epic numbering schemes. |

---

## 2. Contradiction register

Items marked ✓ were re-verified against the working tree during this review. Others come from the design pass and should be re-checked at implementation time.

| # | Location | Repo says | Platform is | Epic |
|---|---|---|---|---|
| C1 ✓ | `skills/sprint-dev/SKILL.md:322` | `Monitor(..., persistent: true)` | `persistent` removed in 2.1.271; every watch has a deadline (max 30 min, 10 in `-p`). Loop must re-arm per wave or fall back to `TaskList` polling. | E-041 |
| C2 ✓ | `skills/_shared/session-lifecycle.md:105`, `skills/health/SKILL.md:117`, `hooks/scripts/_lib/common.sh:118` | Filters `.status != "completed"/"failed"/"stopped"` | `claude agents --json` schema: `state` ∈ working/blocked/done/failed/stopped, `status` ∈ busy/waiting/idle, `waitingFor` ∈ permission prompt/input needed/sandbox request/dialog open. Current filter excludes nothing. | E-041 |
| C3 | `skills/next/SKILL.md:47-61`, `session-lifecycle.md:941-958` | ScheduleWakeup keeps the loop alive through idle; `/loop` fixed-interval, 3-day expiry | Self-paced loops are not restored on resume; CronCreate tasks expire after 7 days with jitter; `.claude/loop.md` sets the default prompt; Routines have a 1-hour minimum; `/loop` should run in its own session. | E-042 |
| C4 | `agent-orchestration.md:1279` | "cache TTL not settable from agent markdown" | `experimental.cacheTtl: 1h` on agent frontmatter since 2.1.248; `subagentPromptCacheTtl` setting for workflows. | E-044 |
| C5 | `agent-orchestration.md:1398` | Hard-coded `~/.claude/projects/-home-tom-development-blitz/memory/MEMORY.md` | Auto memory lives under `autoMemoryDirectory` (default `~/.claude/projects/<project>/memory/`), typed topic files, 200-line / 25 KB index cap. | E-044 |
| C6 ✓ | All 37 `skills/*/SKILL.md`; mandated by `hooks/scripts/skill-frontmatter-validate.sh:150-156` | `model: opus` + `effort:` required | Session-cost guidance: set model and effort once; switching mid-conversation busts the prompt cache. `model: inherit` supported. | E-044 |
| C7 | `hooks/scripts/agent-frontmatter-validate.sh:138` | `memory` ∈ project \| none | `memory` ∈ user \| project \| local; also `isolation`, `omitClaudeMd` (2.1.271), `skills`, `experimental.cacheTtl`, `model: inherit` unvalidated. | E-044 |
| C8 | `hooks/scripts/README.md:3,134,136` | "36 scripts"; "other events pass minimal context" | 38 scripts; every event carries `session_id, prompt_id, transcript_path, cwd, scratchpad_dir, permission_mode, effort, agent_id, agent_type`. | E-040 |
| C9 | `hooks/scripts/pre-compact-snapshot.sh` | Reads `$CLAUDE_SESSION_ID` from env | Other hooks read stdin `session_id`. Three session-ID schemes coexist (native, `cli-<hex>`, `<skill>-<hex>`). | E-041 |
| C10 | `skills/setup/SKILL.md:102`, `agent-orchestration.md:1407` | Requires `TeamCreate`; cites `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `SendMessage`/`ListAgents` are the messaging surface (2.1.224+). Agent teams remain experimental and off by default. Verify live before retiring. | E-046 |
| C11 | `agent-orchestration.md:1077`, `sprint-contracts.md:880` | `PushNotification` tool | Not in the documented tool surface this review read. Verify live. | E-046 |
| C12 ✓ | `README.md:304,308,434`, `.github/workflows/ci.yml:27` | Agent Catalog (10), Builder agents (6), Shared Protocols (12); CI "(10)" | 11 / 7 / 13. `check-count-sync.sh` does not assert these headings. | E-047 |
| C13 ✓ | `CLAUDE.md:3-44` | Model writes `session_start` and reads the feed every session | `hooks/scripts/session-start.sh` already reads the feed; the write should be hook-owned (deterministic). | E-041 |
| C14 ✓ | `agent-orchestration.md:1059` | Floor 2.1.157 for `--agent` dispatch | Not reflected in `plugin.json` or `README.md:98`. | E-040 |

---

## 3. What the external sources contribute

| Source | Concept | Where it lands |
|---|---|---|
| Best practices (code.claude.com) | Verification ladder: prompt-level check → `/goal` evaluator → Stop-hook gate → adversarial subagent. `/verify` recipe recorded to `.claude/skills/verify/SKILL.md`. Explore / plan / code. CLAUDE.md pruning via `/doctor`. `/batch` fan-out. Writer/Reviewer sessions. | E-042, E-044 |
| Session value blog | Set model + effort once per session. `/compact` before a break, `/rewind` for discarding recent turns, `/rename` before `/clear`. Quiet flags in CLAUDE.md. Outputs > 30 k chars auto-file. `/loop` in its own session. Subagents on haiku/sonnet for noisy jobs. | E-044, E-042 |
| Test impact analysis blog | Stateless listener + append-only journal + selector. Design for 25× load in two quarters. Instrument so an agent can observe queue-in == queue-out. No singleton bottleneck. | E-043 |
| Projects redesigned | Threads = independent cloud sessions on their own branches; coordinator directs; shared project memory; configurable check-in cadence. sprint-dev waves map onto threads; orchestrator is the coordinator. | E-046 |
| herdr | Sidebar state working / blocked / idle / needs-input. "Wait until another agent is genuinely blocked" (= `notify_when_idle`). Session index across harnesses. Mailbox delivered at turn end via Stop hook. Address form `<harness>:<session id>`. | E-041 |
| Lantern (stack-junkie) | Tasks / Inbox / Log triad. Hourly heartbeat with escalation (blocked > 24 h → inbox item; `HEARTBEAT_OK` when quiet). "Make dashboard updates non-optional" → in Claude Code terms, hooks not prose. JSON files until concurrency forces SQLite. Design for the agent first. | E-041 |

blitz already has the Log (`activity-feed.jsonl`) and a Tasks analogue (`todos.jsonl`, sprint stories). The missing piece is the **Inbox**: a durable attention queue that hooks write and the next heartbeat triages.

---

## 4. Session management: target model

```
                       ┌──────────────── hooks (deterministic) ────────────────┐
 SessionStart ──► .cc-sessions/sessions/<session_id>.json  ◄── Stop (idle, drain mailbox)
 PostToolBatch ─► last_activity / state:working             ◄── SessionEnd (close, release locks)
 Notification ──► inbox.jsonl  (needs_input, permission)     ◄── PermissionDenied
                       └────────────────────────────────────────────────────────┘
                                          │ read-time overlay
                                          ▼
                 claude agents --json --all  (state / status / waitingFor / pid)
                                          │
                                          ▼
          /blitz:sessions  list | attention | dashboard (--html via emit_html) | prune
                                          │
             conflict matrix ──► SendMessage (WARN notice / BLOCK notify_when_idle + LOOP_DEFER)
```

Skills no longer mint IDs. They **claim** the hook-created record (`skill`, `working_on`, `args`) and keep writing semantic feed events. Everything a peer needs to know about a session exists whether or not the skill preamble ran.

---

## 5. Migration notes for plugin consumers (apply at 2.5.0)

- **Floor moves to ≥ 2.1.271.** Older CLIs keep the slash skills but lose messaging, Stop-hook heartbeat, and the sessions dashboard.
- **Session IDs change.** `.cc-sessions/<skill>-<hex>.json` becomes `.cc-sessions/sessions/<native session_id>.json`. `/blitz:conform` migrates; the feed's `session` field switches to the native ID.
- **Skills stop pinning `model: opus`.** Run `claude --model opus --effort high` (or set once in the session) for the sprint family. The 2.4.4 `[1m]` credits fix is preserved because `inherit` never switches alias.
- **CLAUDE.md shrinks.** The activity-feed procedure moves into hooks; hook-author and skill-author rules move to `.claude/rules/*.md` with `paths:`.
- **Stop hook is non-blocking by default.** A gate only blocks when a sprint or loop has written `gate.json`; it never fights a user `/goal`.

---

## 6. Epic index

| Epic | Title | Priority | Depends on | CC floor |
|---|---|---|---|---|
| [E-040](epics/E-040-platform-floor-hooks.md) | Platform floor + hook-surface modernization | P0 | — | 2.1.271 |
| [E-041](epics/E-041-session-management-v2.md) | Session management v2 (records, messaging, inbox, dashboard) | P0 | E-040 | 2.1.271 |
| [E-042](epics/E-042-verification-modernization.md) | Verification modernization (`/goal`, Stop gate, `/verify`) | P1 | E-040 | 2.1.271 |
| [E-043](epics/E-043-test-impact-analysis.md) | Test impact analysis v0 (listener / selector) | P1 | — | 2.1.71 |
| [E-044](epics/E-044-memory-context-economics.md) | Memory + context economics | P1 | — | 2.1.271 |
| [E-045](epics/E-045-plugin-evals-workflows.md) | Plugin evals + `workflows/` distribution | P2 | E-040 | 2.1.269 |
| [E-046](epics/E-046-cloud-threads-routines-channels.md) | Cloud threads, routines, channels posture | P2 | E-041 | 2.1.271 |
| [E-047](epics/E-047-hygiene-drift.md) | Hygiene drift | P0 | — | — |

**Recommended order:** E-047 → E-040 → E-044 (validators + bulk `model: inherit` before adding skill #38) → E-041 → E-042 → E-043 → E-045 → E-046 → release 2.5.0.

**Cross-epic risks**

1. `model: inherit` on skills reverses a 2.4.4 decision. Confirm on a live `opus[1m]` session that no `sonnet[1m]` credits error reappears before merging E-044.
2. A blocking Stop hook and a user-set `/goal` both fire after every turn. The gate must be a no-op unless `gate.json` exists, and must stay under the platform's 8-consecutive-block cap.
3. `PushNotification` and `TeamCreate` references need a live check (`/list-agents`, tool listing) before deletion.
4. `claude plugin eval` suite format and `/skill-doctor` invocation from a skill are unverified; confirm with `--help` before authoring E-045.

---

## 7. Method

Three read-only exploration passes over the repo (session management + hooks; skills + agents + concept sweep; docs + changelog + epic history), eleven documentation fetches, one design pass producing the file-level plan that the epics carry. Two sources were unreachable through the environment proxy: stack-junkie.com (supplied by the user as pasted text) and dotzlaw.com (skipped). herdr.dev was read via its GitHub README and the session-manager plugin README.
