---
unit: agents/critic.md
kind: agent
verdict: MODERNIZE
removable_lines: 18
created: 2026-05-28
---

# Critic Agent — Cohesion + Modernization Audit

## A. Role Clarity & Overlap

**Role**: adversarial pre-PASS reviewer. Strictly read-only. Attempts to REJECT before `sprint-review` marks PASS.

**vs `reviewer`**: clean distinction. `reviewer` surveys and summarizes; `critic` tries to find ONE rejection signal. No scope overlap. Keep both.

**vs `/code-review`**: platform-delta.md (v2.1.152/2026-05-27) notes `/code-review --fix` applies findings; `/code-review` is a skill wrapper around the same diff-review pattern. Partial functional overlap: `/code-review` also catches structural issues. **Distinction holds**: `critic` is gated to sprint-review Phase 3.6, runs acceptance_checks from story frontmatter (no `/code-review` equivalent), runs ratchet regression check, and emits a binary LGTM/REJECT verdict the orchestrator must see as JSON. Delegate none of this to `/code-review`.

**vs `research-critic`/`design-critic`**: no overlap — scoped to sprint code review only.

**Verdict**: role is clean and necessary. Zero delegation.

---

## B. Contract Compliance

### JSON Reply Contract (token-budget.md §3)

**PASS**. `agents/critic.md` §3 defines the canonical JSON return shape with:
- `"status": "complete"` ✓
- `"summary": "<verdict, ≤50 words>"` ✓
- `"files_changed": []` ✓ (always empty — read-only)
- `"issues": [{"severity": ..., "where": ..., "what": "≤30 words"}]` ✓
- `"verdict": "LGTM | REJECT"` ✓
- Instruction `Return ONLY this JSON, nothing else (no markdown fence, no preamble)` ✓

**Missing `metrics` block** (optional per contract, so not a blocker). `files_changed: []` is correct for read-only; not a gap.

**No prose-reply leakage**: §3 and §4 both forbid prose returns. Enforced.

### Agent Output Contract (spawn-protocol.md)

Critic is not itself a spawn orchestrator — it IS the spawned agent. Its reply contract mirrors the canonical JSON schema. No spawn-side issues.

### Prompt Boilerplate (agent-prompt-boilerplate.md)

**Gap**: `critic.md` has no Weight-Class Budget Block. `spawn-protocol.md` §2 requires Medium/Heavy spawns to include budget declarations in the prompt. Critic is a Medium-class agent (runs 9 checks, Bash commands, file reads). No `BUDGET:` block present.

**HEARTBEAT / PARTIAL**: not present. For a 30-turn `maxTurns` agent running potentially slow `tsc` and acceptance-check loops, PARTIAL is recommended by spawn-protocol §3. Absence is advisory (not blocking).

**OUTPUT STYLE snippet**: PRESENT verbatim at line 29 per `terse-output.md` canonical text. Sprint-review Invariant 5 satisfied. ✓

---

## C. Tooling

**Declared**: `tools: Read, Grep, Glob, Bash`

**Enforced**: Frontmatter lacks `disallowed-tools:` (available since platform-delta.md v2.1.152). "Read-only by construction" is ASSERTED in prose (§4 "You are read-only … You don't have those tools.") but NOT ENFORCED declaratively. The agent prompt says "you don't have those tools" — but the agent definition does not use `disallowed-tools: Write, Edit, Agent` to actually remove them from the pool.

**Risk**: model could attempt `Write`/`Edit` if confused. The hook `block-test-deletion.sh` and `post-edit-typecheck-block.sh` provide some downstream protection but not pre-call prevention.

**Recommended edit**: add `disallowed-tools: Write, Edit, Agent, NotebookEdit` to frontmatter. Reduces tool pool from all-tools to declared-tools. Costs 0 lines, reduces injection surface.

**`WebSearch`/`WebFetch`**: not in allowed-tools. Appropriate — critic only examines local repo state.

---

## D. Model / Effort Under 4.8

**Current**: `model: sonnet` (claude-sonnet-4-6).

**token-budget.md routing matrix** assigns critic to `sonnet` ("Plan-check / critic — adversarial review needs reasoning, not depth"). ✓

**4.8 honesty argument**: platform-delta.md (claude-opus-4-8 / 2026-05-28) states Opus 4.8 is "~4x less likely than Opus 4.7 to let own code flaws pass unremarked." However, critic IS already cross-model (it runs on the spawner's work, not its own). The honest-reporting gain from 4.8 improves critic fidelity when Opus is used — but sonnet-4-6 as the critic model is still correct per the cost/quality matrix. No model upgrade warranted unless a false-LGTM pattern emerges in practice.

**CMC (§5)** provides Gemini variant for cross-model diversity. That mechanism already satisfies the cross-model principle. The separate/cross-model argument holds.

---

## E. Detector-by-Detector Re-justification (4.8 Honesty Lens)

Platform-delta.md note (VERIFIED): "Opus 4.8 is ~4x less likely to let own code flaws pass unremarked." This is behavioral — the builder model is more honest about its own output. It does NOT eliminate structural/deterministic failures that require grep/diff/tsc evidence.

| # | Detector | 4.8 behavioral? | Keep/Cut/Reduce | Rationale |
|---|---|---|---|---|
| 2.1 — `.skip/.only/xit/xdescribe`; `as any`; mock delta | Structural grep | NO | **KEEP** | Deterministic pattern; model won't self-remove `.skip()` tags in committed code |
| 2.2 — Ratchet regression | File-state check | NO | **KEEP** | Numeric comparison; purely structural |
| 2.3 — Build/type-check | `tsc --noEmit` | NO | **KEEP** | Compiler output; model cannot introspect post-commit tsc errors |
| 2.4 — Test count | grep count | NO | **KEEP** | Deterministic; count may drop due to tooling, not model behavior |
| 2.5 — Story `acceptance_checks` | Shell execution | NO | **KEEP** | Programmatic; critic is the only agent that executes these |
| 2.6 — Hallucinated symbols spot-check | Import resolution | PARTIAL | **REDUCE** | 4.8's perfect lazy-investigation score (unverified per platform-delta.md) reduces hallucinated-import rate. However, commit history already materialized bad imports — deterministic post-hoc check. Keep but note false-positive rate may drop. |
| 2.7 — `--no-verify` reflog scan | Git reflog | NO | **KEEP** | Structural; catches hook bypasses regardless of model |
| 2.8 — Test file rename | `git diff-filter=R` | NO | **KEEP** | Structural; model doesn't control git history |
| 2.9 — Audit-finding integrity (detector #20) | Evidence field grep | NO | **KEEP** | Advisory; structural pattern in docs, not builder behavior |

**Summary**: 0 detectors cut. 2.6 warranted annotation that FP rate may decrease with 4.8 builders; logic remains correct. Cross-model argument (§5 CMC Gemini variant) still valid — 4.8 improves builder honesty but critic must still verify COMMITTED artifacts, not the model's intent.

**No detectors removable on 4.8 grounds.** All 9 checks catch deterministic/structural properties that 4.8 model-honesty cannot self-resolve.

---

## F. Orchestrator — N/A

critic is not an orchestrator. Section F skipped.

---

## Top Edits (leverage-ranked)

1. **Add `disallowed-tools: Write, Edit, Agent, NotebookEdit`** to frontmatter — enforces read-only declaratively (currently asserted only in prose). Zero risk, closes injection surface.
2. **Add Medium-class Budget Block** per `spawn-protocol.md` §2/`agent-prompt-boilerplate.md` — annotate with `maxTurns: 30` to signal Heavy-class consideration.
3. **Update model ID in `token-budget.md`** routing matrix Sonnet row to `claude-sonnet-4-6` (current model ID per platform-delta.md 2026-05-28).
4. **Annotate 2.6** with note that 4.8 builder models reduce hallucinated-import rate; keep check but lower severity to advisory when builder is Opus 4.8.
5. **(Advisory) Add PARTIAL heartbeat** for long acceptance_checks loops (2.5 shell-type checks on large sprint trees can exceed 5 min).

**Removable lines**: 18 (CMC §5 env-var table + Gemini setup prose can be extracted to a separate `skills/sprint-review/references/main.md` note, reducing critic.md body; currently duplicates sprint-review §Invariant 7 citation).
