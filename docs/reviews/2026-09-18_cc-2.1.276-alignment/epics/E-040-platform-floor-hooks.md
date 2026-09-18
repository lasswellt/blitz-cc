---
id: E-040
title: "Platform floor + hook-surface modernization"
status: implemented
implemented_in: "2.5.0"
priority: P0
phase: 1
domain: platform
depends_on: []
cc_floor: "2.1.271"
estimated_stories: 6
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-040 Platform floor + hook-surface modernization

**Why.** The plugin advertises four different Claude Code floors and wires 16 of 33 hook events. The unwired `Stop` and `SessionEnd` events are exactly the primitives E-041 and E-042 need. New hook fields (`if`, `statusMessage`, `once`, `async`, exec-form `args`) reduce cost and false triggers on existing guards.

**Decision.** One plugin-wide effective floor **≥ 2.1.271**. Per-skill `compatibility:` stays honest per feature (skills that adopt messaging, the agent-view overlay, or the Stop gate declare `>=2.1.271`; the rest may remain `>=2.1.71`). The 2.1.117 / 2.1.152 / 2.1.157 sub-floors are removed from prose.

**Stop-hook stance.** The old rationale ("would only be a logging stub", `hooks/scripts/README.md:104`) no longer holds. Stop is the only event that can deterministically mark idle, deliver a mailbox at turn end, and run a verification gate. Default behavior stays non-blocking; blocking only via `stop-gate.sh` when a gate file exists. Never wire a `prompt`-type Stop hook (it would collide with a user `/goal`).

## Stories

### S1 Single source of truth for the floor
- **Files:** new `.claude-plugin/compat.json`; `scripts/check-version-sync.sh`; `.claude-plugin/plugin.json`; `README.md:98`; `CLAUDE.md`; `.claude-plugin/settings.json`; `skills/_shared/agent-orchestration.md:1059`; `installer/install.sh`, `installer/src/index.js`, `installer/src/verify.js`, `installer/README.md`.
- **Change:** `compat.json` = `{"cc_min":"2.1.271","features":{"cross_session_messaging":"2.1.224","agent_view_json":"2.1.141","monitor_deadline":"2.1.271","omit_claude_md":"2.1.271","plugin_eval":"2.1.269","goal_checkins":"2.1.234"}}`. `check-version-sync.sh` gains a section that greps every `2\.1\.[0-9]{2,3}` in the listed files and fails on any value outside `compat.json`.
- **Acceptance:** `scripts/check-version-sync.sh` exits 0; `grep -rn "2\.1\.1[15][27]" README.md CLAUDE.md .claude-plugin installer` returns nothing.

### S2 Wire tier-1 events
- **Files:** `hooks/hooks.json`; new scripts in `hooks/scripts/`: `session-end.sh`, `stop-turn.sh`, `stop-gate.sh` (body in E-042), `notification-log.sh`, `permission-denied.sh`, `model-switch-warn.sh`, `cwd-changed.sh`, `config-change.sh`.
- **Change:** `SessionEnd` → close session record, release owned locks (reason mapping: prompt_input_exit/other → completed, resume → suspended, clear → cleared, logout → logged_out). `Stop` → `stop-turn.sh` (non-blocking, idle + heartbeat + mailbox drain) then `stop-gate.sh`. `Notification` → append `needs_input` / `permission` to `.cc-sessions/inbox.jsonl`. `PermissionDenied` → log only, never emit `retry` (containment posture). `PreModelSwitch` → log `cache_bust` + one-line advisory. `CwdChanged` / `DirectoryAdded` → update `cwd` / `dirs[]` on the record. `ConfigChange` → re-run `startup-validate.sh --strict --quiet` (TB-2). All new entries use exec form (`command` + `args`), `timeout`, `statusMessage`.
- **Acceptance:** `hooks/hooks.json` valid; `bats hooks/tests/` green with new suites `session-end.bats`, `stop-turn.bats`, `notification-log.bats`, `permission-denied.bats`; each new script exits 0 on empty stdin.

### S3 Adopt hook fields on existing guards
- **Files:** `hooks/hooks.json`.
- **Change:** `if: "Bash(git *)"` on `block-no-verify.sh`, `block-destructive-git.sh`, `pre-commit-validate.sh`, `reference-compression-validate.sh`, `markdown-link-validate.sh`. `timeout: 90` + `statusMessage` on `post-edit-typecheck-block.sh`; `timeout: 60` on `post-edit-test.sh`. `once: true` on a new SessionStart entry for `startup-validate.sh`. `async: true` + `asyncRewake: true` reserved for the E-043 batched test runner.
- **Acceptance:** guards still block in bats; a non-git Bash call no longer invokes the git guards (measure via `BLITZ_HOOK_TRACE=1` log count).

### S4 Validator understands the new surface
- **Files:** `scripts/validate-plugin-structure.sh:138-164`.
- **Change:** parse `args` arrays; skip `type != command` entries; validate `if` strings are permission-rule shaped (`Tool(pattern)`); assert every wired script exists and is executable.
- **Acceptance:** validator passes on the new `hooks.json`; a deliberately malformed `if` fails it.

### S5 Hook documentation refresh
- **Files:** `hooks/scripts/README.md`; `CLAUDE.md` hooks paragraph; `.claude-plugin/plugin.json` description; `scripts/check-count-sync.sh`.
- **Change:** fix C8 (count line, stdin-contract section listing common fields, blocker list), replace the Stop section with the new rationale, add one row per new script grouped by event. Counts regenerate via `check-count-sync.sh --write`.
- **Acceptance:** `check-count-sync.sh` exits 0.

### S6 Tier-2 events (optional, only if they do real work)
- `TaskCreated` (dashboard timeline), `InstructionsLoaded` (record which CLAUDE.md/rules loaded; feeds `/doctor` trims), `Setup` (seed KNOWLEDGE.md + verify recipe under `--init`). Skip `Elicitation*`, `FileChanged`, `PostModelSwitch`, `MessageDisplay`.

## Verification
- `scripts/validate-plugin-structure.sh && scripts/check-version-sync.sh && scripts/check-count-sync.sh && bats hooks/tests/`
- Manual: start a session on 2.1.276, run one Bash and one Edit, exit; confirm `.cc-sessions/sessions/<id>.json` transitions active → idle → completed (E-041 S1 provides the record writer).

## Risks
- Older consumers on < 2.1.271 lose messaging and Stop heartbeat silently; installer must print the floor.
- `if` filters use the permission-rule grammar; a typo silently disables a guard. Validator S4 is the mitigation.
