---
unit: agents/backend-dev.md
kind: agent
verdict: MODERNIZE
removable_lines: 0
created: 2026-05-28
---

# Audit — agents/backend-dev.md

## A. Role Clarity & Overlap

**Role**: builder/implementer. Clear. Not critic, not orchestrator.

**Scope overlap with `/code-review`**: none. `/code-review` (platform-delta.md v2.1.152) is a diff-level critic skill; `backend-dev` is a story-level writer. No delegation conflict.

**Scope overlap with `frontend-dev`**: none — disjoint layer boundary (server vs client). Both agents carry `WebSearch, ToolSearch` in their tool lists; that's a shared capability, not an overlap.

**Stack specificity concern**: description says "Cloud Functions v2 / Zod / Firestore". Body has stack-detection logic (§ "Stack Detection") that makes the agent generic. Description over-promises specificity. Low severity; confusing to sponsors but not a correctness bug.

## B. Contract Compliance

### Subagent JSON Reply Contract (token-budget.md §3)

**Finding: NON-COMPLIANT — prose-reply leakage.**

`backend-dev.md` contains no instruction to return canonical JSON. The "Self-Validation Protocol" and "Quality Gates" sections direct the agent to run checks, then report "DONE to the orchestrator" — but no JSON schema is defined, no ≤50-word summary field, no `files_changed[]` contract, no `issues[]` array. Any spawning skill that parses the return with `jq` will see `BAD_REPLY`.

Required fix: add the canonical reply block (token-budget.md §3 schema + the verbatim "Return ONLY this JSON…" directive) as a terminal section.

### Agent Output Contract (spawn-protocol.md §6)

The agent is a builder; its deliverable is edited source files, not a text return to the orchestrator. The contract still requires the JSON wrapper with `files_changed[]` listing what was written. Absent.

### Prompt Boilerplate (agent-prompt-boilerplate.md)

The `<!-- import: -->` pattern for BUDGET and WRITE-AS-YOU-GO blocks is not present. This is optional for agents (boilerplate cites orchestrator skills as primary consumers), so not a hard violation — but HEARTBEAT/PARTIAL snippets would benefit a `maxTurns: 50` agent.

### OUTPUT STYLE Snippet

**COMPLIANT.** Line 23 contains the verbatim canonical snippet:

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

## C. Tooling

**Declared tools (frontmatter line 13):**
```
tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch
```

**Correctness**: all tools are appropriate for a backend implementer. `WebSearch` justified for package version resolution (package-install-policy.md). `ToolSearch` justified for lazy MCP schema fetch per token-budget.md §5.

**`disallowed-tools` field (platform-delta.md v2.1.152)**: not used. No tools obviously need blocking. `Agent` tool is absent from `tools:` already, which prevents nested spawning — correct for a leaf worker. This is adequate; no `disallowed-tools` entry is needed.

**"Read-only by construction" enforcement**: N/A — this agent is explicitly a writer. No false read-only claim made.

## D. Model/Effort under Opus 4.8

**Model: `sonnet`** — matches token-budget.md §1 "Standard workers: backend-dev → sonnet (4.6)". Correct.

**Current model ID `claude-sonnet-4-6`** (platform-delta.md, row "Model IDs current as of 2026-05-28"). Frontmatter uses alias `sonnet`, not the versioned ID. Acceptable if the harness resolves the alias; but token-budget.md says "set `model:` explicitly" and uses `sonnet (4.6)` in prose. Low risk, but explicit ID recommended for determinism.

**Opus 4.8 honesty gains** (platform-delta.md row "Opus 4.8 honesty: ~4x less likely…"): this agent is not a critic. Honesty gains do not change the builder's role or model choice. No action required.

**`effort:` field**: not present in frontmatter. Agents don't require `effort:` (that's a SKILL.md field). Confirmed non-issue.

## E. Critics Only

N/A — `backend-dev` is a builder, not a critic.

## F. Orchestrator Only

N/A — `backend-dev` is a leaf worker.

## Findings Summary

| # | Section | Severity | Finding |
|---|---------|----------|---------|
| 1 | B | BLOCKER | No canonical JSON reply contract; prose-reply leakage guaranteed when spawner parses with `jq` |
| 2 | A | MINOR | Frontmatter `description` overstates Firebase-specificity; body correctly uses stack detection |
| 3 | D | MINOR | `model: sonnet` should be `model: claude-sonnet-4-6` per platform-delta.md 2026-05-28 for determinism |
| 4 | B | MINOR | No HEARTBEAT/PARTIAL budget block; `maxTurns: 50` agents can run long without progress signals |

## Top Edits (leverage-ranked)

1. **Add canonical JSON reply section** (terminal section, ~15 lines) — fixes BLOCKER #1; unblocks `jq`-parsing spawners.
2. **Pin `model: claude-sonnet-4-6`** (1-line frontmatter change) — addresses platform-delta.md model-ID row; prevents silent alias-resolution drift.
3. **Narrow `description:` to drop Firebase/Zod/Firestore specificity** (~2 lines) — aligns description with the stack-detection behavior in the body.
4. **Add HEARTBEAT snippet** (Medium/Heavy class budget block, ~8 lines) — improves orchestrator visibility on long runs.
