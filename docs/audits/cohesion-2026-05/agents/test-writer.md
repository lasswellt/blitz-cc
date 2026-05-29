---
unit: agents/test-writer.md
kind: agent
verdict: MODERNIZE
removable_lines: 0
created: 2026-05-28
---

# Cohesion Audit — agents/test-writer.md

## A. Role Clarity & Overlap

**Role**: Test generation specialist (unit / integration / E2E). Pure builder — no critic, no orchestrator concern.

**Overlap with `/blitz:test-gen` skill**: `skills/test-gen/` likely wraps this agent for user-facing invocation. Overlap is intentional (skill → agent delegation pattern). No conflict.

**Overlap with `/code-review`**: None. `test-writer` generates tests; `/code-review` reviews diffs. Non-overlapping scopes.

**Overlap with `blitz:reviewer`**: None. Reviewer inspects existing code quality; test-writer produces test files.

**Builder/critic/orchestrator classification**: Pure builder. Correct classification. No routing or adversarial role assumed.

## B. Contract Compliance

### Subagent JSON Reply Contract (token-budget.md §3, ≤50-word summary)

**VIOLATION**: `agents/test-writer.md` contains no instruction to return canonical JSON on completion. The agent is designed to be spawned by orchestrators (sprint-dev, blitz:next) and interact as a subagent. token-budget.md §3 mandates every Agent() prompt instruct the subagent to return ONLY the canonical JSON schema. No JSON return contract is present anywhere in the file.

This is prose-reply leakage by omission — the agent will return unstructured prose to the orchestrator, bloating context.

### Agent Output Contract (spawn-protocol.md)

spawn-protocol.md §1 lists `blitz:test-writer` as having tools `Read, Write, Edit, Bash, Glob, Grep` — matches the `tools:` frontmatter line exactly. Contract honored on tool surface.

### Prompt Boilerplate (agent-prompt-boilerplate.md)

agent-prompt-boilerplate.md defines BUDGET blocks for Medium/Heavy spawns. test-writer has no BUDGET declaration. For sprint-dev wave spawns (typically Medium-class), the budget block is missing. Omission is consistent across other agents too — whether this is enforced is unclear without reading sprint-dev spawn prompts. Flagged as gap; not verified against sprint-dev references/main.md.

### OUTPUT STYLE snippet

Present verbatim at line 23. Sprint-review Invariant 5 satisfied.

## C. Tooling

**Declared tools**: `Read, Write, Edit, Bash, Glob, Grep`

**Correctness**: Appropriate for test generation. `Write`/`Edit` needed for test files. `Bash` needed for running test suite (`npx vitest run`). `Glob`/`Grep` needed for stack detection.

**`disallowed-tools` field** (platform-delta.md v2.1.152): Not used. Opportunity: `disallowed-tools: [Agent, WebFetch, WebSearch]` would enforce read-by-construction for non-test browsing. Currently "read-only where appropriate" is asserted via prose instructions, not enforced declaratively. Declarative enforcement IS available via `disallowed-tools` since v2.1.152.

**`permissionMode`**: Line 14 correctly notes `permissionMode` is silently ignored for plugin agents. Comment is accurate.

## D. Model/Effort Under 4.8

**Current model**: `sonnet` (claude-sonnet-4-6 per platform-delta.md model IDs as of 2026-05-28).

**token-budget.md routing matrix**: Classifies test-gen as "Mechanical workers" → `haiku`. The agent's inline comment (line 16-18) argues Haiku is too coarse for edge-case reasoning. This is a deliberate override of the routing matrix default.

**Assessment under 4.8 honesty gains**: platform-delta.md (verified, 2026-05-28) states Opus 4.8 is ~4x less likely to let own code flaws pass unremarked. This applies to Opus specifically; Sonnet 4.6 gains are not separately quantified in platform-delta.md. The Sonnet override over Haiku remains defensible: test-writer does structural pattern inference (stack detection), spec-fix complexity classification, and oracle derivation — not purely mechanical. Downgrade to Haiku not recommended without evidence 4.5 Haiku handles HARD_SPEC classification reliably.

**Model ID**: frontmatter says `model: sonnet`. Per platform-delta.md (2026-05-28), current Sonnet model ID is `claude-sonnet-4-6`. Alias `sonnet` should resolve correctly if the harness maps it, but explicit ID is safer per platform-delta.md guidance.

## E. Critics Only

Not applicable — test-writer is a builder, not a critic.

## F. Orchestrator Only

Not applicable.

## Top Edits (leverage-ranked)

1. **Add JSON reply contract** — append token-budget.md §3 canonical JSON return instruction to agent body. Highest impact: prevents prose-reply bloat in every orchestrator spawn.
2. **Add `disallowed-tools: [Agent, WebFetch, WebSearch]`** — declarative enforcement of non-browsing constraint (platform-delta.md v2.1.152).
3. **Explicit model ID** — change `model: sonnet` → `model: claude-sonnet-4-6` per platform-delta.md current IDs (2026-05-28).
4. **BUDGET block** — add Medium-class budget declaration for sprint-dev spawns per agent-prompt-boilerplate.md.
