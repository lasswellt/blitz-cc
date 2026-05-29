---
unit: agents/frontend-dev.md
kind: agent
verdict: PASS_WITH_WARNINGS
removable_lines: 0
created: 2026-05-28
---

# Audit: agents/frontend-dev.md

## A. Role Clarity & Overlap

**Role**: Builder. Receives story assignments from sprint-dev orchestrator; writes Vue 3 / Pinia / TypeScript source only.

**vs. backend-dev**: No overlap — backend-dev targets Cloud Functions / Firestore / Zod; frontend-dev targets component/store/composable layer. Boundary is clean by convention; neither file enforces it.

**vs. /code-review**: No structural overlap. frontend-dev writes; `/code-review` reviews diffs. Native `/code-review --fix` (platform-delta.md v2.1.152) is a post-write pass, not a substitute.

**vs. test-writer**: Phase 0 mentions component tests are *required* but the agent does not write them — delegates to test-writer per spawn-protocol. Ambiguity: Quality Gates §7 says "every new component must have at least one test". If test-writer runs in a separate wave, this creates a completion-state race: frontend-dev can report DONE before test-writer acts. This is a documentation gap, not a code gap.

**vs. critic**: frontend-dev is not a critic. No overlap.

**Conclusion**: Role scope is clean. One ambiguity (who owns the component test) should be resolved by explicit cross-agent note.

---

## B. Contract Compliance

### JSON Reply Contract (token-budget.md §3, spawn-protocol.md §7)

**Finding: VIOLATION.** The agent has no instruction to return the canonical JSON reply schema. No `Return ONLY this JSON...` instruction exists anywhere in the file. Agent is spawned by sprint-dev via `Agent()` calls; orchestrator parses return with `jq`. Prose reply will break the run.

### Agent Output Contract (spawn-protocol.md §2)

**Finding: PARTIAL.** HEARTBEAT / PARTIAL protocol is not present. frontend-dev is a Heavy-class agent (50 turns, writes files). Per spawn-protocol.md §3, Heavy agents MUST emit periodic HEARTBEAT lines and PARTIAL output blocks. The file has no such instructions.

### Prompt Boilerplate (agent-prompt-boilerplate.md)

**Finding: N/A for content, but OUTPUT STYLE present.** OUTPUT STYLE terse-technical snippet present verbatim at line 20–21. Satisfies sprint-review Invariant 5.

BUDGET block absent. Phase 0 "Think" block is present and sound, but no explicit `Max tool calls / Max file reads / Wall-clock` budget declared. token-budget.md mandates this for Medium/Heavy spawns.

### Prose-Reply Leakage

No explicit anti-prose guard. Combined with missing JSON reply instruction, this is the highest-severity contract gap.

---

## C. Tooling

### allowed-tools (frontmatter `tools:`)

Declared: `Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch`

Matches spawn-protocol.md §1 blitz agent table for `blitz:frontend-dev`: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch. **Correct.**

### disallowed-tools

platform-delta.md (v2.1.152): `disallowed-tools` SKILL.md frontmatter field now available for per-agent tool lockdown. frontend-dev does not use it. Candidate tools to lock out: `Agent` (subagents-cannot-spawn-subagents constraint). Currently not listed in `tools:` so implicitly unavailable — but declaring it in `disallowed-tools` would make the constraint explicit and machine-enforced rather than convention-only.

### Read-only by construction

Not applicable — agent legitimately writes files. No false read-only claim.

---

## D. Model/Effort Under 4.8

`model: sonnet` — correct per token-budget.md routing matrix ("Standard workers: frontend-dev → sonnet (4.6)").

Current model ID `sonnet` maps to `claude-sonnet-4-6` per platform-delta.md (2026-05-28). Alias still valid; no change required.

4.8 is Opus model. frontend-dev is Sonnet. 4.8 honesty gains do not directly apply to this agent. No model change warranted.

Effort field: **absent from frontmatter.** Plugin agents do not use `effort:` (that's a SKILL.md field). Not a defect.

---

## E. Critics Only

Not applicable — frontend-dev is a builder, not a critic.

---

## F. Orchestrator Only

Not applicable — frontend-dev is a leaf implementation agent.

---

## Top Edits (leverage-ranked)

1. **Add canonical JSON reply instruction** — highest impact; missing instruction breaks sprint-dev `jq` parse on every frontend-dev return. Insert the §3 snippet from token-budget.md near end of file.
2. **Add HEARTBEAT/PARTIAL protocol** — Heavy-class agent (maxTurns: 50); orchestrator cannot detect stuck agents without it.
3. **Declare BUDGET block** — Medium/Heavy spawn requirement per agent-prompt-boilerplate.md; add explicit `Max tool calls / file reads / wall-clock` limits.
4. **Add `disallowed-tools: [Agent]`** — make subagent spawn prohibition machine-enforced (platform-delta.md v2.1.152).
5. **Clarify component test ownership** — Quality Gates §7 says frontend-dev must produce a test, but test-writer is the canonical test agent. Pick one and note it; remove the other.

---

## Uncertainty

- Did not read `skills/sprint-dev/references/main.md` — cannot verify whether the orchestrator-side Agent() spawn prompt for frontend-dev already injects the JSON reply contract. If it does, B.JSON is a documentation gap only, not a runtime gap.
- Did not read `/_shared/definition-of-done.md` or `/_shared/deviation-protocol.md` — referenced in agent body; content unverified.
- platform-delta.md entries cited below are verified (primary-source column confirmed readable).
