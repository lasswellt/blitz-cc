---
unit: skills/code-sweep
kind: skill
verdict: needs-tightening
removable_lines: 28
created: 2026-05-28
---

# Audit: code-sweep

## A. Identity & Boundaries

**Purpose (one sentence):** Iterative static-analysis sweep with ratchet semantics across 30 checks / 7 categories, `/loop`-compatible, never regresses metrics.

**Description vs body match:** Verified. Description ("30 checks across 7 categories with a ratchet") matches body exactly. Arg-hint is complete.

**Overlaps:**

| Skill/Agent | Nature | Classification |
|-------------|--------|----------------|
| `code-doctor` | Both grep source files; code-doctor checks framework-canonical rules, code-sweep discovers conventions dynamically. `quality-matrix.md` documents the distinction. | Legitimate layering — different trigger + semantics |
| `completeness-gate` | Both grep TODOs / placeholder patterns. completeness-gate = binary gate; code-sweep = monotonic metric. `quality-matrix.md` §Apparent overlaps documents. | Legitimate layering |
| `codebase-audit` | Both perform quality passes over source. codebase-audit = broad one-shot health portrait; code-sweep = narrow continuous ratchet. | Legitimate layering |
| native `/simplify` (v2.1.154, `platform-delta.md` 2026-05-28) | `/simplify` applies reuse/simplification/efficiency/altitude cleanup with auto-apply. Overlaps code-sweep categories Reduction + Optimization for JS/TS. | Partial overlap — see §D |
| `refactor` | refactor is human-directed structural transformation; sweep is automated metric improvement. No meaningful overlap. | No overlap |

---

## B. Cohesion

**Shared protocols cited:**

| Protocol | Cited in SKILL.md | Followed or restated inline |
|----------|------------------|----------------------------|
| `session-protocol.md` | Phase 0.0 (§Session Registration) | Followed by reference — no inline restatement |
| `verbose-progress.md` | Phase 0.0 | Followed by reference |
| `terse-output.md` | Additional Resources + OUTPUT STYLE line | Correct — canonical snippet verbatim at line 22; **Invariant 5 satisfied** |
| `spawn-protocol.md` | Not cited explicitly; Phase 2.2 manually specifies `subagent_type`, `model`, `description`, `prompt` | **Drift risk** — Phase 2.2 reinvents spawn parameters inline instead of citing `spawn-protocol.md §Agent Output Contract` |
| `ratchet-protocol.md` | Not cited by name; ratchet logic implemented inline in Phase 3 + Phase 5 | **Drift risk** — ratchet schema in references/main.md may diverge from `_shared/ratchet-protocol.md` |
| `agent-prompt-boilerplate.md` | `references/main.md` line 8: `<!-- import: /_shared/agent-prompt-boilerplate.md -->` | Correctly annotated |
| `token-budget.md` | Not cited | Model `opus` + worker `sonnet` matches routing matrix — compliant but uncited |
| `state-handoff.md` | Not cited | code-sweep produces `docs/sweeps/*.json` and `sweep-ledger.jsonl`; these are not sprint-pipeline artifacts, no state-handoff obligation |
| `story-frontmatter.md` | Not applicable | Not a sprint-pipeline producer/consumer |
| `carry-forward-registry.md` | Not cited | Ratchet state is self-contained in `docs/sweeps/ratchet.json`; not a carry-forward producer |

**Cross-refs live?** Verified:
- `/_shared/session-protocol.md` — exists
- `/_shared/verbose-progress.md` — exists
- `/_shared/terse-output.md` — exists
- `references/main.md` — exists
- All appear correct.

**Pipeline trace (scan-only → next consumer):**

`code-sweep --scan-only` writes `docs/sweeps/YYYY-MM-DD.json` + `latest.json`. No downstream blitz skill consumes these files. They are human-facing artifacts; no state-handoff contract required. Pipeline chain terminates here — no broken handoff.

---

## C. Conciseness

**Body line count:** 247 lines (SKILL.md). Under 500-line cap. ✓

**references/main.md:** 921 lines — exceeds 500-line cap by 421 lines, but `main.md` is explicitly a reference file (not a SKILL.md body), so cap doesn't apply. Confirmed by `skill-frontmatter-validate.sh` scope (validates SKILL.md only).

**Anti-laziness / defensive prose (candidates for deletion):**

1. **Phase 2.2 lines 155–168** — "IMPORTANT: emit all Agent tool calls in the same assistant message to run them concurrently. Do not chain them sequentially." This is an anti-laziness nudge guarding against sequential agent spawning. With 4.8 honesty, model reliably follows concurrency instructions without the defensive "IMPORTANT" wrapper. The underlying requirement (parallel spawn) belongs in `spawn-protocol.md §3 Parallel Dispatch` — inline restatement is drift risk.

2. **Phase 4 lines 195–202** — Verify-revert-commit recipe is partially re-specified rather than delegated to `session-protocol.md` conflict matrix. Three sentences could collapse to a cite. ~5 lines.

3. **`--loop` description (lines 63–70)** — "When `--loop`: auto-approve all, auto-commit+push, exit after one fix cycle. Tick type: first run → DISCOVERY; `run % 10 == 0` → RE-DISCOVERY; fixable findings → FIX; else → SCAN." This is loop-dispatch logic the model must faithfully implement. Not anti-laziness per se — required behavior. Keep.

4. **Phase 2.2 "Inputs each agent receives" block (lines 161–167)** — Redundant with the Tier Agent Prompt Template in references/main.md. Exists as a concise checklist. Low redundancy; borderline. ~5 lines removable if references/main.md expands its "Notes for orchestrator" section.

**DRY violations:** Tier Agent Prompt Template lives in `references/main.md` and is also partially summarized in SKILL.md Phase 2.2. Acceptable split (SKILL.md = what to do, references = full template), but the "Inputs each agent receives" enumeration at lines 161–167 duplicates the template's `{{…}}` placeholder list — ~6 lines removable.

**Content that belongs in `_shared`:** The circuit-breaker logic (SAFETY RULE 7 + Phase 4 "increment circuit breaker") is inline. Pattern is general enough for `session-protocol.md`; however it's scoped to fix-mode code-sweep only, so moving it would add noise to a shared protocol. Leave in place.

**Estimated removable lines:** 28 (IMPORTANT concurrency nudge ~4 lines, verify-revert cite compression ~5 lines, "Inputs each agent receives" dedup ~6 lines, Phase 2.2 spawn-param restatement ~8 lines that should cite `spawn-protocol.md`, miscellaneous hedging ~5 lines in Error Recovery).

---

## D. Modernization

**Native `/simplify` overlap** (`platform-delta.md` v2.1.154 / 2026-05-28):
Native `/simplify` reinstated in v2.1.154 covers Reduction + Optimization categories with auto-apply. Verdict: **keep code-sweep, do not delegate Reduction/Optimization to `/simplify`**.
Tradeoff argument: `/simplify` is stateless (no ratchet, no ledger, no per-run snapshot). code-sweep's value proposition is the monotonic metric — ensuring the codebase only gets cleaner over time, with a grade/score dashboard. Delegating to `/simplify` loses: (a) ratchet enforcement, (b) category-level budgets, (c) incremental file queue, (d) per-finding ledger with age tracking. The opinionation is real and irreplaceable by a stateless native.

**Native workflows** (`platform-delta.md` v2.1.154+ / 2026-05-28):
The parallel-tier-agent pattern (Phase 2.2) could be expressed as a native JS workflow script. However, code-sweep's tier agents are already lightweight Agent tool calls — the spawn is already parallel within one assistant message. No structural change required. The 16-agent concurrency cap (`platform-delta.md` 2026-05-28) is not a risk — code-sweep spawns max 3 tier agents.

**`disallowed-tools` frontmatter** (`platform-delta.md` v2.1.152):
SAFETY RULE 1 ("–scan-only is READ-ONLY — never modify source files") could be partially enforced declaratively via `disallowed-tools: Write, Edit` when invoked in scan-only mode. However, mode is runtime-determined (from args), and `disallowed-tools` is static frontmatter — cannot be conditional on flag. No actionable change.

**Model/effort frontmatter:**
`model: opus`, `effort: high`. Under 4.8 honesty + fast mode (`platform-delta.md` fast-mode-2026-02-01 / 2026-05-28): Opus 4.8 fast mode at $10/$50 per MTok is viable for the orchestrator role (planning + diffing). Tier worker agents already use `model: sonnet` (verified in Phase 2.2 and references/main.md). Opus orchestrator is justified by the discovery + ratchet logic requiring strong reasoning. Fast mode could reduce latency on `--loop` ticks where the 2-minute budget is tight. Recommend adding a note in Phase 0 or the frontmatter comment to surface fast-mode option for loop use. Not a blocking issue.

**`/goal` native loop** (`platform-delta.md` v2.1.139 / 2026-05-11):
code-sweep `--loop` is richer than `/goal` (ratchet, categories, commit/push). No delegation opportunity.

---

## E. Correctness

**Model ID:** `model: opus` — interpreted as current `claude-opus-4-8` per platform routing. Not pinned to a versioned model ID. Acceptable given SKILL.md convention.

**`missing-subagent-type` check (line 124, Tier 2):** Check verifies subagent calls include `subagent_type`. This is a blitz-specific lint rule, not a universal pattern. Correct for this codebase.

**`subagents-cannot-spawn-subagents` constraint:** code-sweep is slash-invoked (not spawned by another skill). Its tier agents are `general-purpose` workers that run grep + write — they do not spawn further agents. Constraint is respected. Dynamic Workflows (`platform-delta.md` v2.1.154+) do not change the calculus here — no subagent spawning of subagents occurs.

**Dead flags:** None found. All `--flag` options in the arg-hint correspond to Phase 0.1 table entries. No stale env vars or wrong tool names detected.

**Broken paths:** `references/main.md` cited as "same directory as this file" — correct, confirmed at `skills/code-sweep/references/main.md`. All `/_shared/*.md` refs resolve.

**State file paths:** `docs/sweeps/*.json`, `.code-sweep.json`, `.code-sweep-standards.json` — consistent across Phase 1, Phase 5, and references/main.md.

---

## F. Verdict

**Verdict: `needs-tightening`**

**Top 3 highest-leverage edits:**

1. **Cite `spawn-protocol.md` in Phase 2.2** — replace the inline spawn-parameter enumeration and "IMPORTANT: emit all Agent tool calls in the same assistant message" nudge with a reference to `spawn-protocol.md §3 Parallel Dispatch` + `§Agent Output Contract`. Removes ~12 lines, eliminates drift risk between inline restatement and canonical spec.

2. **Cite `ratchet-protocol.md`** — Phase 3 step 5 ("Ratchet check") and Phase 5 step 5 ("Ratchet update") should reference `_shared/ratchet-protocol.md` explicitly. Currently the ratchet schema lives in `references/main.md` without linking back to the shared protocol. Risk: ratchet-protocol.md evolves, references/main.md schema drifts.

3. **Drop "Inputs each agent receives" enumeration (Phase 2.2 lines 161–167)** — fully duplicated by the `{{…}}` placeholder list in `references/main.md` Tier Agent Prompt Template. Saves ~6 lines with no information loss; the caller can read the template to know what to fill in.
