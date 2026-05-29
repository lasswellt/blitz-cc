# Agent Validation: frontend-dev — v1.16.0 Cohesion+DW

**Unit:** `agents/frontend-dev.md`
**Role:** Standard writer agent (Vue 3 / Pinia implementation)
**Validated:** 2026-05-28
**Validator model:** claude-sonnet-4-6

---

## A1 — Frontmatter + Reply Contract

**Verdict: PASS**

`hooks/scripts/agent-frontmatter-validate.sh agents/frontend-dev.md` output:
```
[agent-frontmatter-validate.sh] OK: 1 agent .md files conform
```

Field evidence (re-derived from frontmatter):
- `name: frontend-dev` — lowercase+hyphens, ≤64 chars, no reserved words. (`agents/frontend-dev.md:2`)
- `description:` — 419 chars (well under 1024 cap). (`agents/frontend-dev.md:3–11`, verified via Python YAML parse)
- `model: sonnet` — matches token-budget.md §1 "Standard workers: backend-dev, frontend-dev" → `claude-sonnet-4-6`. (`agents/frontend-dev.md:16`)
- `tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch` — non-empty. (`agents/frontend-dev.md:12`)
- `maxTurns: 50` — positive integer. (`agents/frontend-dev.md:14`)
- Forbidden fields (`hooks`, `mcpServers`, `permissionMode`) — ABSENT as active fields. Line 13 carries only a prose comment explaining the restriction; no YAML key is set. (`agents/frontend-dev.md:13`)

**Silently-stripped fields:** None present as YAML keys. The comment at line 13 is correct documentation. No silent-strip risk.

**JSON reply contract (token-budget.md §3):** The reply contract belongs in the SPAWNING skill's `Agent()` prompt, not in the agent definition. `sprint-dev/references/main.md` carries the HEARTBEAT/PARTIAL/BUDGET blocks (confirmed at line 9: `<!-- import: /_shared/agent-prompt-boilerplate.md -->`). The agent-prompt-boilerplate.md explicitly states that the reply contract snippet is injected by orchestrators, not the agent file itself. `frontend-dev.md` is the receiver, not the injector — no gap.

**Agent Output Contract (spawn-protocol.md §8):** Same reasoning — the classify_output validator and standard gate thresholds live in the orchestrator (sprint-dev). The subagent definition does not need to redeclare them.

**OUTPUT STYLE snippet:** Present verbatim at `agents/frontend-dev.md:21`.

**Body length:** 266 lines (cap: 500). (`awk '/^---$/{c++; next} c>=2{print}' agents/frontend-dev.md | wc -l` → 266)

---

## A2 — Read-Only Enforcement

**Verdict: N/A**

`frontend-dev` is a writer agent, not in the read-only set (orchestrator / critic / research-critic / design-critic / architect / reviewer). Write and Edit are expected and correct per its role. `tools` line confirms: `Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch`. (`agents/frontend-dev.md:12`)

---

## A3 — Orchestrator Injection Guard

**Verdict: N/A**

`frontend-dev` is not the orchestrator agent. Applies only to `agents/orchestrator.md`.

---

## A4 — Orchestrator Routing Completeness

**Verdict: N/A**

`frontend-dev` is not the orchestrator agent. Applies only to `agents/orchestrator.md`.

---

## A5 — Critic Detector Re-Justification

**Verdict: N/A**

`frontend-dev` is not the critic agent. Applies only to `agents/critic.md`.

---

## A6 — DW Agent-Prompt Parity

**Verdict: N/A**

`frontend-dev` is not a critic/research-critic/design-critic agent. Applies only to agents spawned at codebase-audit/research gate points dispatched via Workflow.

---

## Agent Verdict

**cohesive**

All applicable checks pass. The frontmatter is valid per the lint script; forbidden fields are absent as YAML keys (only correctly documented in a comment); model is `sonnet` matching the token-budget standard-worker routing rule; OUTPUT STYLE snippet is verbatim; body is 266 lines under the 500-line cap. The JSON reply contract is correctly the spawning orchestrator's responsibility (sprint-dev/references/main.md), not the agent definition's.

---

## Highest-Leverage Fix

None required. One advisory improvement: add a brief note in the agent body (or frontmatter comment) explicitly stating that the canonical JSON reply contract (`status/summary/files_changed/issues/next_blocked_by`) is injected by the spawning orchestrator — this would make A1 self-documenting for future reviewers without touching the reply-contract ownership model.
