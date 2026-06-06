# v1.16.0 Validation — agents/backend-dev.md

**Date:** 2026-05-28  
**Validator:** freeform agent (claude-sonnet-4-6)  
**Unit:** backend-dev  
**File:** agents/backend-dev.md (214 lines)

---

## A1 — Frontmatter + Reply Contract

### Frontmatter lint

```
$ bash hooks/scripts/agent-frontmatter-validate.sh agents/backend-dev.md
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```

Script validates: name, description (≤1024 chars, 482 chars actual), model (sonnet ✓ per agent-orchestration.md matrix for standard workers), tools (Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch), maxTurns (50), forbidden fields absent, body lines (194 ≤ 500), OUTPUT STYLE snippet present.

### Silently-stripped fields

- `permissionMode`: appears only in a YAML comment (`# Note: permissionMode is not supported...`) on line 14 — NOT a YAML key. Script check 7 (grep for `^permissionMode:`) correctly passes. No silent-stripping risk.
- `hooks`, `mcpServers`: absent from frontmatter. No risk.

### ≤50-word JSON reply contract (agent-orchestration.md §3)

**FAIL — missing from both the agent file and its authoritative spawn prompt.**

agent-orchestration.md §3 (line 73): "Every Agent() prompt MUST instruct the subagent to return ONLY the canonical JSON shown below."

The sprint-dev spawn prompt (`skills/sprint-dev/references/main.md` lines 14–80) uses `DONE: S${N}-XXX` as the reply signal — not the canonical JSON schema (`status`/`summary`/`files_changed`/`issues`/`metrics`). The agent file itself also contains no declaration of this contract.

This is a systemic gap shared by `frontend-dev` and `test-writer` (grep across all writer agents confirms zero occurrences of "Return ONLY" or "files_changed" in those files). The sprint-dev orchestrator parses `DONE:` prefix messages, not JSON — a deliberate but undocumented deviation from the agent-orchestration.md mandate.

**Verdict:** A1 FAIL on reply-contract sub-check. Frontmatter itself is clean.

---

## A2 — Read-Only Enforcement

**N/A** — backend-dev is a writer agent, not in the read-only set (orchestrator/critic/research-critic/design-critic/architect/reviewer). Its `tools:` list correctly includes Write and Edit as required for implementation work.

---

## A3 — Orchestrator Injection Guard

**N/A** — backend-dev is not the orchestrator.

---

## A4 — Orchestrator Routing Completeness

**N/A** — backend-dev is not the orchestrator.

---

## A5 — Critic Detector Re-Justification

**N/A** — backend-dev is not the critic agent.

---

## A6 — DW Agent-Prompt Parity

**N/A** — backend-dev is not in the critic/research-critic/design-critic set spawned at codebase-audit/research gate points.

---

## Agent Verdict

**needs-tightening**

The agent frontmatter passes all script checks cleanly. The sole gap is that neither the agent file nor its sprint-dev spawn prompt (`skills/sprint-dev/references/main.md`) contains the canonical JSON reply contract mandated by agent-orchestration.md §3. Instead, the sprint-dev protocol uses the `DONE: S${N}-XXX` prefix convention, which the orchestrator parses but which is undocumented as an intentional deviation from the canonical contract. This is a systemic issue shared with `frontend-dev` and `test-writer` — not a backend-dev-specific failing.

## Highest-Leverage Fix

Add a documented exception block in `skills/_shared/agent-orchestration.md` §3 (or a companion `dev-agent-reply-protocol.md`) that formally recognizes the sprint-dev `DONE:`/`BLOCKED:`/`DEVIATION:` prefix protocol as the approved deviation for Heavy implementation agents — explicitly noting why prose-prefixed replies are acceptable there (real-time story-by-story streaming) while JSON is mandatory for analysis/audit agents (single-shot return to orchestrator). This resolves the apparent contract violation across all three writer agents at once without changing any spawn prompt.
