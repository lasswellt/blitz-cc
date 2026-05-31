# Hook Trust Boundary (TB-1)

> Companion to [threat-model.md](threat-model.md). Defines how Blitz hooks must treat project-local files, and records the audited invariant that no hook executes project-controlled content before the platform trust prompt.

## The rule

Blitz hooks fire on Claude Code lifecycle events (`SessionStart`, `PreToolUse`, `PostToolUse`, …). Some run **before** the user has accepted "Do you trust this folder?". The article's pre-trust-config-execution incident (AP-1) was a cloned repo whose `.claude/settings.json` defined a hook that ran attacker code at startup, before that prompt.

**Therefore:**
1. **Treat project-local files as untrusted inbound data**, not trusted local config — `.cc-sessions/*.json`, `activity-feed.jsonl`, profiles, CLAUDE.md, carry-forward registry. This is [threat-model.md](threat-model.md) §3 TB-1.
2. **A hook MUST NOT `eval`, `source`, or otherwise execute** any project-controlled file's contents. Hooks may *parse* (jq) and *echo*, never execute.
3. **Echoed free-text fields MUST be capped + injection-scanned** before reaching context. `session-start.sh` caps every echoed field at 200 chars (parity with `orchestrator.md:146`) and replaces injection-marker hits with `[quarantined: …]`.
4. **Execution-bearing parsing defers to the platform trust prompt.** Blitz relies on the Claude Code platform for the trust gate itself — it does not reimplement it (threat-model.md §6). Blitz's duty is to not parse-execute project config before it.

## Audited invariant (keep true)

> **No Blitz hook executes project-controlled content pre-trust.**

Verified 2026-05-31 across all `hooks/scripts/*.sh`:
- The `block-*.sh` + `pre-edit-guard.sh` hooks read `tool_input` (the agent's *own* proposed action from the harness), not committed project files.
- `session-start.sh` parses `.cc-sessions/` JSON with `jq` and echoes sanitized text — no `eval`/`source` of project content.
- `startup-validate.sh` reads + scans; it does not execute entries.

**Regression guard (audit `sec-containment` / pre-commit):**
```bash
# Command-position eval/source/. only (excludes comments + the word "source" in jq/prose).
# The only legitimate hit is `. "$(dirname "$0")/_lib/common.sh"` — first-party, filtered out.
grep -REn '^[[:space:]]*(eval|source|\.)[[:space:]]+' hooks/scripts/*.sh \
  | grep -v '_lib/common.sh' || echo "clean: no pre-trust execution of project content"
```

## Related
- [threat-model.md](threat-model.md) §3 TB-1, §6 (scope: trust-prompt delegated to platform).
- `hooks/scripts/session-start.sh` — the SessionStart enforcement point.
- `hooks/scripts/startup-validate.sh` — persistent-state validation (TB-2).
