# v1.16.0 Agent Validation — architect

**Unit:** agents/architect.md
**Date:** 2026-05-28
**Validator:** automated rubric A1–A6

---

## A1 — Frontmatter + Reply Contract

### Frontmatter validation

`bash hooks/scripts/agent-frontmatter-validate.sh agents/architect.md` → `[agent-frontmatter-validate.sh] OK: 1 agent .md files conform`

Fields present and valid:
- `name: architect` (line 2)
- `description:` multi-line with example (lines 3–11)
- `tools: Read, Glob, Grep, Bash` (line 12)
- `maxTurns: 15` (line 14)
- `model: sonnet` (line 18)
- `background: true` (line 19)
- `memory: project` (line 20)

Forbidden fields (`hooks:`, `mcpServers:`, `permissionMode:`) absent — confirmed by grep returning empty on frontmatter block.

Body line count: 139 (well under 500-line cap).

OUTPUT STYLE snippet: present verbatim at line 24.

### JSON reply contract

The ≤50-word JSON reply contract (`{status, summary≤50w, files_changed, issues, next_blocked_by}`) is **not embedded in the agent body**. Per `skills/_shared/token-budget.md` §3, the contract belongs in every `Agent()` spawn prompt, not the agent body itself — so this is correct by the "embedding in spawn prompts" convention. However, unlike `agents/critic.md` (which embeds the contract at line 203 as belt-and-suspenders self-reference), architect omits it entirely from its body.

No explicit "Agent Output Contract honored/declared" language appears in the body. The agent does not return JSON; it returns structured Markdown findings. When spawned, callers must inject the reply-contract snippet per spawn-protocol §9.

**Verdict: PASS with note** — frontmatter clean; reply-contract absent from body is consistent with the spawn-prompt convention but differs from critic's belt-and-suspenders pattern. No formal violation.

---

## A2 — Read-Only Enforcement

### What the file says

Line 29: `You are strictly **READ-ONLY** — never modify files.`
Line 155–156: `**READ-ONLY**: Never create, modify, or delete any files.`

### What the tools allow

`tools: Read, Glob, Grep, Bash` (line 12)

The `Bash` tool permits arbitrary shell commands including file writes (`echo ... > file`, `tee`, `cat > file`, `mkdir`, etc.). There is no `disallowed-tools` entry. Read-only enforcement is **prose-only** — no tool-level gate prevents writing.

### Contradiction in Collaboration Hints (line 148)

`agents/architect.md:148`: `Write findings to ${SESSION_TMP_DIR}/architect-findings.md if a session temp dir is provided`

This directly contradicts:
- Line 29/155: the read-only constraint
- `skills/_shared/spawn-protocol.md:54`: "If a spawn site expects architect to write findings files, the orchestrator must write them from the agent's text return"
- `skills/_shared/spawn-protocol.md:76`: "blitz:architect is strictly read-only — use general-purpose if analysis must produce a file"

The Collaboration Hints section invites the agent to use Bash to write a findings file, which is both internally contradictory and at odds with the authoritative cross-reference in spawn-protocol.

### Comparison to peer read-only agents

| Agent | Has Bash? | Has Write/Edit? | Prose read-only claim |
|---|---|---|---|
| architect | YES | No | YES |
| critic | YES | No | YES |
| research-critic | YES | No | implicit |
| design-critic | YES | No | implicit |
| reviewer | YES | **YES (Write)** | No — reviewer writes |

All read-only agents share the same Bash exposure. None use `disallowed-tools` to enforce the constraint structurally.

**Verdict: FAIL** — read-only is prose-asserted only; Bash enables writes. Line 148 actively invites a write, contradicting spawn-protocol.md:54 and the agent's own constraint block (line 155). This is the highest-leverage fix.

---

## A3 — Orchestrator Injection Guard

**N/A** — architect is not the orchestrator agent.

---

## A4 — Orchestrator Routing Completeness

**N/A** — architect is not the orchestrator agent.

---

## A5 — Critic Detector Re-justification

**N/A** — architect is not the critic agent.

---

## A6 — DW Agent-Prompt Parity

**N/A** — architect is not critic/research-critic/design-critic. It is spawned by `codebase-audit` and `sprint-review` but is not itself a DW-gated critic role.

---

## Agent Verdict

**needs-hardening**

The agent passes frontmatter validation and correctly scopes its tools to analysis primitives. However, read-only enforcement is prose-only (Bash remains a write-capable escape hatch), and Collaboration Hints line 148 actively contradicts both the in-body constraint and `spawn-protocol.md:54`. The JSON reply contract is absent from the body, which is technically acceptable per the spawn-prompt convention but creates ambiguity for callers.

## Highest-Leverage Fix

Remove line 148 (`Write findings to ${SESSION_TMP_DIR}/architect-findings.md…`) from the Collaboration Hints section — it directly contradicts spawn-protocol.md:54 and the agent's own read-only constraint. Add a clarifying note that orchestrators must extract findings from the agent's text return. Optionally add `disallowed-tools: Write, Edit` if the Claude Code plugin API supports it, to structurally enforce the read-only guarantee.
