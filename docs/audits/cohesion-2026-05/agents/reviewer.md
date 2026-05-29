---
unit: agents/reviewer.md
kind: agent
verdict: REFINE
removable_lines: 22
created: 2026-05-28
---

# Cohesion + Modernization Audit — `agents/reviewer.md`

## A. Role Clarity & Overlap

**Role**: code quality + security reviewer. Writes incremental findings to a temp file. Findings-only — never modifies source files. Scoped to 15 files/session.

**Overlap assessment**:

| Potential overlap | Verdict | Rationale |
|---|---|---|
| `/code-review` (platform skill, v2.1.152) | **Keep distinct** | `/code-review` reviews a diff in the working tree (`--fix`, `--comment`). `blitz:reviewer` reviews arbitrary files/scopes spanning multiple sessions, writes structured findings to `${SESSION_TMP_DIR}/review-findings.md`, and is spawnable by orchestrators mid-sprint. Diff scope vs full-file scope; the `--fix`/`--comment` integration path doesn't exist in the agent. Overlap is real but the call sites differ. |
| `/simplify` (platform skill, v2.1.154) | **Keep distinct** | `/simplify` = cleanup-only (reuse, simplification, altitude); reviewer = correctness + security + pattern. Non-overlapping. |
| `agents/critic.md` | **Keep distinct** | critic = shortcut/anti-pattern taxonomy on sprint artifacts; reviewer = OWASP/TypeScript/architecture on source files. Input type, detection mechanism, and call sites differ. |
| `/blitz:sprint-review` Phase 3.6 critic loop | **Keep distinct** | sprint-review runs `agents/critic.md`, not `blitz:reviewer`. reviewer is invoked on-demand for user-requested code reviews or orchestrator-spawned quality passes mid-sprint. |

No retire/delegate recommendation.

## B. Contract Compliance

### Subagent JSON Reply Contract (`token-budget.md` §3)

**Verdict: NON-COMPLIANT — prose leakage.**

The agent body instructs the agent to write findings to `${SESSION_TMP_DIR}/review-findings.md` and produce a markdown `## Summary` section. There is no instruction to return the canonical JSON reply schema. When spawned via `Agent()`, the agent will return prose findings in its reply text, not JSON. This bloats orchestrator context by 430–1,930 tokens per return (per `token-budget.md` §3).

**Fix required**: add JSON reply contract at end of body:

```
## Reply Contract (when spawned via Agent())

Return ONLY this JSON, nothing else. No markdown fence, no preamble, no postamble:
{"status":"complete|partial|failed","summary":"<≤50 words>","files_changed":["${SESSION_TMP_DIR}/review-findings.md"],"issues":[{"severity":"blocker|major|minor","where":"path:line","what":"≤30 words"}],"next_blocked_by":[]}
```

Rich findings stay in `review-findings.md`; JSON summary references it via `files_changed`.

### Agent Output Contract (`spawn-protocol.md` §1 table)

`spawn-protocol.md` §1 table lists `blitz:reviewer` with `Write` for findings only, `sonnet` model. Verified consistent with `agents/reviewer.md` frontmatter (`tools: Read, Write, Bash, Glob, Grep`, `model: sonnet`). **COMPLIANT**.

### Prompt Boilerplate (`agent-prompt-boilerplate.md`)

Agent body does not include the Generic Agent Preamble (`You are a general-purpose agent with Write access. Your task is INCOMPLETE if {{OUTPUT_PATH}} does not exist when you finish.`). This preamble targets orchestrator-spawned agents whose deliverable is a file. The reviewer's `Write-As-You-Go Protocol` (§§1–3) partially substitutes, but does not include the `INCOMPLETE` exit-guard or the output-path completion check. Missing the orchestrator-side existence-check means interrupted reviews may return `status: complete` with no findings file written.

**Verdict: PARTIAL — missing INCOMPLETE guard.**

### OUTPUT STYLE snippet

Line 23 contains the canonical OUTPUT STYLE snippet verbatim plus the permitted extension (`Auto-pause for security/irreversible/root-cause sections.`). **COMPLIANT** per `terse-output.md` "Extensions are out of scope for the hash check."

## C. Tooling

**`allowed-tools` field**: Not present in frontmatter. The `tools:` field (`Read, Write, Bash, Glob, Grep`) is the plugin-agent equivalent, and matches the `spawn-protocol.md` §1 table row for `blitz:reviewer`. **Consistent.**

**`disallowed-tools` (platform-delta v2.1.152)**: The agent is findings-only (`Constraints` section asserts "Never create, modify, or delete source files. Only write to the review findings file"). This constraint is prose-only, not enforced declaratively. With `disallowed-tools` now available (platform-delta.md, v2.1.152), `Edit` could be added to `disallowed-tools` to enforce the source-modification prohibition. `Write` must remain (for the findings file) so wholesale tool-lockdown isn't possible, but removing `Edit` would prevent accidental inline edits that bypass the Write gate.

**Verdict: "read-only by construction" claim is asserted, not enforced.** `Edit` is not in `tools:` already — so in practice the agent cannot call Edit. However `Bash` remains, and the agent could use `bash -c 'echo ... >> src/file.ts'` to write source. The prohibition is behavioral, not structural. Acceptable risk for a reviewer agent, but should be noted.

**`maxTurns: 20`**: Reasonable for ≤15 file review scope. No issue.

**`background: true`**: Correct — reviewer runs as a background agent. Consistent with spawn-protocol.

## D. Model / Effort Under 4.8

`model: sonnet` — matches `token-budget.md` §1 row "Plan-check / critic: sonnet — adversarial review needs reasoning, not depth" and row "Standard workers: reviewer: sonnet".

**Under Opus 4.8 honesty gains** (platform-delta.md: "~4x less likely than Opus 4.7 to let own code flaws pass unremarked"): this improvement applies to Opus. The reviewer uses Sonnet 4.6. Sonnet does not carry the same honesty-gain claims. No model-upgrade case from this delta; reviewer scope (pattern/security checklist) is not primarily an honesty problem. Sonnet remains correct choice per cost matrix.

No separate/cross-model argument applies here (reviewer is not a critic agent in the critic/research-critic/design-critic sense — Section E is N/A).

## E. CRITICS ONLY

N/A — `reviewer` is not a critic-role agent.

## F. ORCHESTRATOR ONLY

N/A — `reviewer` is not an orchestrator agent.

## G. Verdict & Top Edits

**Verdict: REFINE**

Issues are behavioral-contract gaps, not structural redundancy. Role is justified. Model is correct.

### Leverage-Ranked Top Edits

1. **Add JSON reply contract** (token-budget.md §3 compliance) — prevents prose leakage when spawned via `Agent()`. Estimated savings: 400–1,900 tokens/spawn × N reviews per sprint. Write findings to file; reference via `files_changed`.
2. **Add INCOMPLETE guard** (agent-prompt-boilerplate.md Generic Agent Preamble pattern) — prevents false `status: complete` returns on interrupted reviews. Tie to `${SESSION_TMP_DIR}/review-findings.md` existence check.
3. **Add `disallowed-tools: [Edit]`** (platform-delta.md v2.1.152) — declaratively enforce the source-non-modification constraint rather than relying on prose `Constraints` section.
4. **Deduplicate §9 "Feature Completeness"** (lines 119–127) and **§9 "Completeness Review"** (lines 144–153) — two sections labeled §9 with overlapping content. One §9 is mis-numbered. Merge into single `### 9. Completeness` section. Saves ~22 lines.
5. **Remove `memory: project`** if reviewer is only ever spawned by orchestrators (not invoked standalone). Project memory adds load cost with no benefit for a single-session review pass. Conditional: verify standalone usage before cutting.
