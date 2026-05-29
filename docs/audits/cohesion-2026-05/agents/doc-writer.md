---
unit: agents/doc-writer.md
kind: agent
verdict: NEEDS_WORK
removable_lines: 0
created: 2026-05-28
---

# Cohesion Audit — `agents/doc-writer.md`

## A. Role Clarity & Overlap

**Role**: documentation specialist — read source, write to `docs/` or `docs/generated/`. Spawned by other skills as a subagent.

**Overlap with `skills/doc-gen/SKILL.md`**:
- `doc-gen` is a full orchestrator skill: phase-gated, spawns parallel agents, handles full/api/components/architecture/changelog modes, writes `docs/generated/`, manages session lifecycle.
- `doc-writer` is a leaf agent: templates for API docs, component docs, ADRs, READMEs, migration guides; no orchestration, no spawning.
- The two overlap in surface area (API docs, Vue component docs), but differ in activation: `doc-gen` is user-invoked; `doc-writer` is a spawned worker.
- `doc-gen` Phase 3.2 spawns `general-purpose` agents (not `blitz:doc-writer`) for its parallel mode — the agent is not actually wired as a consumer of `doc-gen`. This is an **unresolved coupling gap**: `doc-writer` exists in the agent roster but `doc-gen` bypasses it.
- Overlap with `/code-review`: none. `doc-writer` is write-only to `docs/`; no source analysis or quality judgement.

**Verdict on role overlap**: `doc-writer` should be the canonical worker `doc-gen` spawns. Currently it is not. Either wire `doc-gen` to spawn `blitz:doc-writer` or accept that both independently implement the same Vue SFC parsing / JSDoc extraction logic, increasing drift risk.

---

## B. Contract Compliance

### B1. Subagent JSON Reply Contract (`token-budget.md` §3)

**FAIL.** `doc-writer` contains zero instructions to return the canonical JSON reply:
```json
{"status":…,"summary":…,"files_changed":…,"issues":…,"next_blocked_by":…,"metrics":…}
```
No `Return ONLY this JSON` instruction. No `≤50-word summary` constraint. When spawned as a subagent the agent will emit prose — bloating orchestrator context per `token-budget.md` §3 "Prose replies are forbidden."

### B2. Agent Output Contract (`spawn-protocol.md` §2)

**FAIL.** No `Write-as-you-go` / incremental-write instruction. No HEARTBEAT markers. No PARTIAL degradation block. Given the agent writes documentation files (potentially large), it is Heavy-class work with no Heavy-class safeguards.

### B3. Prompt Boilerplate (`agent-prompt-boilerplate.md`)

**FAIL.** No weight-class budget block. No generic agent preamble. No `{{OUTPUT_PATH}}` existence check instruction. The boilerplate fragments that `agent-prompt-boilerplate.md` defines for `general-purpose` agents are absent entirely from `doc-writer`.

### B4. Prose-Reply Leakage

**CONFIRMED.** Quality Gates section ("Before considering your work complete, verify…") and Documentation Quality Rules are instruction prose to the agent itself, not to any spawning orchestrator. When the agent responds, those sections produce evaluative prose that would leak into the orchestrator's context unless the JSON reply contract overrides it. The JSON contract is absent (see B1), so leakage is certain.

---

## C. Tooling

**`tools:` frontmatter**: `Read, Write, Edit, Bash, Glob, Grep`

- Correct: Write/Edit needed to produce `docs/` output.
- `Bash` listed — reasonable for reading `package.json`, detecting stack, running `find`.
- `WebSearch` / `ToolSearch` absent — consistent with a documentation-only agent that does not need web access. **VERIFIED correct** per spawn-protocol decision matrix: `blitz:doc-writer` row lists `Read, Write, Edit, Bash, Glob, Grep` with no WebSearch — matches.

**`disallowed-tools`**: not declared. Per `platform-delta.md` (v2.1.152), `disallowed-tools` SKILL.md frontmatter field now available. For `doc-writer`, the "never modify source files" constraint (line 172) is **asserted in prose only** — not enforced. Using `disallowed-tools` to remove `Edit` on paths outside `docs/` is not directly possible (no path-scoped disallow), but removing `Edit` entirely and relying solely on `Write` would be over-restrictive (updating existing docs requires Edit). Enforcement of the "docs/ only" constraint remains **asserted, not enforced declaratively**. This is a known limitation of the platform — no per-path tool restriction exists. Flag as accepted gap, not a fixable deficiency.

**`maxTurns: 30`**: reasonable for a single documentation task; no objection.

**`background: true`**: correct — doc-writer is designed for background spawning.

---

## D. Model/Effort Under 4.8 Honesty

**`model: haiku`** — declared in frontmatter, consistent with `token-budget.md` routing matrix ("Mechanical workers: test-gen, lint-fix, file ops, doc-gen, formatting → haiku"). **VERIFIED consistent.**

Note: `spawn-protocol.md` Blitz Plugin Agents table (line 49) lists `blitz:doc-writer` default model as `sonnet` — **MISMATCH**. The agent's own frontmatter says `haiku`; spawn-protocol's table says `sonnet`. One of the two is stale. If `doc-writer` was downgraded to `haiku` (correct per token-budget routing), `spawn-protocol.md` table needs updating.

**4.8 honesty impact on doc-gen tasks**: documentation is pattern-following work. 4.8's honesty gains (verified: ~4× less likely to let own flaws pass per `platform-delta.md` `claude-opus-4-8 / 2026-05-28`) are meaningful for reasoning tasks, not format-following template work. Haiku assignment remains correct. No model change warranted.

---

## E. Critics Only

Not applicable — `doc-writer` is not a critic.

---

## F. Orchestrator Only

Not applicable — `doc-writer` is not an orchestrator.

---

## Summary of Findings

| # | Severity | Finding |
|---|----------|---------|
| 1 | BLOCKER | No JSON reply contract. Agent returns prose; orchestrator context bloated. |
| 2 | BLOCKER | No write-as-you-go / HEARTBEAT / PARTIAL. Heavy-class output with zero Heavy-class safeguards. |
| 3 | MAJOR | `doc-gen` skill spawns `general-purpose` agents instead of `blitz:doc-writer`. Coupling gap → drift between two parallel implementations. |
| 4 | MAJOR | `spawn-protocol.md` Blitz Plugin Agents table lists `doc-writer` model as `sonnet`; frontmatter declares `haiku`. One stale. |
| 5 | MINOR | `docs/`-only write constraint asserted in prose, not enforced. Accepted platform gap (no path-scoped `disallowed-tools`). |
| 6 | MINOR | No weight-class budget block in body. Spawning orchestrators have no declared caps to reference. |

---

## Top Edits (leverage-ranked)

1. **Add JSON reply contract** — append canonical `Return ONLY this JSON …` block (from `token-budget.md` §3) near end of agent body. Fixes BLOCKER #1.
2. **Add HEARTBEAT + PARTIAL blocks** — insert verbatim snippets from `spawn-protocol.md` §3 for Medium/Heavy class. Fixes BLOCKER #2.
3. **Wire `doc-gen` to spawn `blitz:doc-writer`** — in `skills/doc-gen/SKILL.md` Phase 3.2, replace `general-purpose` spawns with `blitz:doc-writer` (which already has Write + the right tool set). Closes coupling gap #3. (Edit target: `skills/doc-gen/SKILL.md` lines 198–199.)
4. **Fix model mismatch in spawn-protocol** — update `spawn-protocol.md` Blitz Plugin Agents table row for `blitz:doc-writer`: `sonnet` → `haiku`. Fixes #4.
5. **Add weight-class budget block** — insert Medium-class budget declaration (per `agent-prompt-boilerplate.md`) into `doc-writer` body. Fixes #6.
