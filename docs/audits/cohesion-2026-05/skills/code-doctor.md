---
unit: skills/code-doctor
kind: skill
verdict: needs-tightening
removable_lines: 18
created: 2026-05-28
---

# Cohesion Audit — `code-doctor`

## A. Identity & Boundaries

**One-sentence purpose:** Framework-API correctness audit (Firestore, VueFire, Vue 3, Pinia) — detects anti-patterns, misuse, dead exports, duplication; optionally applies low-risk auto-fixes.

**Description vs body match:** Verified accurate. Frontmatter description matches phases, rule sets, and `--scan`/`--fix`/`--fix-all` modes in body.

**Overlap inventory:**

| Skill/Agent | Overlapping surface | True duplication? |
|---|---|---|
| `code-sweep` | `dead-export` detection (rule D1) + duplication (rule DUP1) | Legitimate layering — `code-sweep` is convention-discovered/continuous-ratchet; `code-doctor` owns framework-canonical rules. `quality-matrix.md` §35 documents distinction. Scope boundary stated verbatim in `references/main.md` line 3. |
| `codebase-audit` | Dead code + anti-pattern detection at broad pillar level | Legitimate layering — `codebase-audit` is universal/pillar-level; `code-doctor` is framework-specific + `paths:` auto-load gated. `quality-matrix.md` §35 confirmed. |
| `refactor` | `--fix`/`--fix-all` applies edits; SKILL.md line 279 suggests `/blitz:refactor` for extraction candidates | Legitimate handoff, not duplication. `code-doctor --fix` is confined to `auto_fix: true` rules; refactor handles structural rewrites. |
| `agents/critic.md` | Phase 2 LLM-judge for critical findings false-positive triage | Critic is adversarial sprint-level; Phase 2 judge is a local micro-confirmation step. Different scope. Not duplicate. |

No true duplications found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited? | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.1 + §Additional Resources) | Followed — cites `§Session Registration`, no restatement. |
| `verbose-progress.md` | Yes (Phase 0.1 + §Additional Resources) | Followed — cites format, no restatement. |
| `terse-output.md` | Yes (§Additional Resources) | Followed via reference. |
| `state-handoff.md` | Not cited | N/A — this skill is a standalone audit tool, not a sprint-pipeline producer/consumer. No `STATE.md` artifacts produced. Correct to omit. |
| `story-frontmatter.md` | Not cited | N/A — not a sprint-story consumer/producer. |
| `ratchet-protocol.md` | Not cited — **drift risk** | Skill implements its OWN ratchet ledger (`.cc-sessions/code-doctor-ledger.jsonl`) inline in `references/main.md §F`. `ratchet-protocol.md` defines the canonical 8-metric monotonic ratchet (verified in `skills/_shared/ratchet-protocol.md`). Code-doctor's ratchet is scoped differently (per-rule-category, per-scope) which may justify a separate ledger — but the in-body implementation is a parallel, non-canonical ratchet. This is a **drift risk** if ratchet-protocol.md evolves schema. |
| `spawn-protocol.md` | Not cited | Phase 2 spawns Agent() for LLM judge but does not cite spawn-protocol.md. Low severity — the agent call is simple (single short-lived agent, no timeout tiers, no HEARTBEAT). |
| `shortcut-taxonomy.md` | Not cited | No anti-shortcut guards. Acceptable — skill has no code-generation surface. |

### Cross-ref accuracy

- `references/main.md` — live path, verified readable.
- `/_shared/terse-output.md`, `/_shared/session-protocol.md`, `/_shared/verbose-progress.md` — cross-refs use `/_shared/` prefix. Verified these files exist at `skills/_shared/`.
- `_shared/project-context.md §Canonical block` — cited via import comment line 17. Verified `skills/_shared/project-context.md` exists.

All cross-refs: **live and accurate** (verified).

### Invariant 5 — OUTPUT STYLE snippet

Present verbatim at line 28. **Pass.**

### Pipeline chain trace

`code-doctor` is not a sprint-pipeline node (no `STATE.md` produce/consume). It can be invoked standalone or from `blitz:next`. Output is `docs/_audits/YYYY-MM-DD_code-doctor.md` + console table. No downstream skill is declared as consumer.

`quality-matrix.md` line 24 confirms: "none" for upstream, "manual" for downstream. Consistent.

---

## C. Conciseness

**Body line count:** 279 lines (SKILL.md) + 280 lines (references/main.md, on-demand). SKILL.md is well under 500-line cap.

**Prose warranting deletion (anti-laziness guards):**

None found that are clearly model-behavior compensations. The Safety Rules block (lines 44–50) is operational policy, not sycophancy-guard prose. Retained as correctness constraints.

**DRY candidates:**

- Phase 2 Agent() call (lines 156–169) repeats the "spawn a single Agent with tight prompt" pattern without citing `spawn-protocol.md`. Low priority — prompt is 6 lines, extracting to shared protocol adds overhead.
- `references/main.md §F` ratchet ledger is a partial reimplementation of `ratchet-protocol.md`. The section is 18 lines that could delegate to the canonical protocol with a "see ratchet-protocol.md, ledger key = `code-doctor-ledger.jsonl`" sentence. **Estimated removable: 18 lines.**

**Removable line estimate: 18** (ratchet ledger §F in references/main.md if delegated to canonical ratchet-protocol.md).

---

## D. Modernization

### Native primitive overlap

| Claim | Platform-delta citation | Verdict |
|---|---|---|
| Phase 2 LLM judge uses manual `Agent()` spawn; native Dynamic Workflows (v2.1.154+, platform-delta.md verified 2026-05-28) fan-out parallel agents via JS orchestration | platform-delta.md v2.1.154+ row: "JS script fans work across dozens–hundreds of parallel subagents" | **Keep skill-level.** Phase 2 judge is a single sequential agent call — no fan-out benefit from workflows. Tradeoff: native workflows provide 16-agent concurrency cap + 1k total cap; overkill for one confirming agent. No change warranted. |
| `disallowed-tools` frontmatter (platform-delta.md v2.1.152) could reinforce `--scan` mode safety by removing Write/Edit | platform-delta.md v2.1.152 row: "`disallowed-tools` SKILL.md frontmatter field: removes named tools from Claude's pool for skill duration" | **Modernization opportunity.** In `--scan` mode (default), Write and Edit are in `allowed-tools` but must not be used. A `disallowed-tools: Write, Edit` field active by default would make this declarative + enforced, not just prose-asserted. Tradeoff: skill currently needs Write/Edit for `--fix` mode — would require mode-conditional frontmatter (not currently supported by platform). Result: prose guard remains necessary; a comment noting the limitation is sufficient. |
| `/simplify` reinstated (v2.1.154, platform-delta.md 2026-05-28) for cleanup-only review | platform-delta.md v2.1.154 row: "`/simplify` reinstated" | No overlap. `code-doctor` is framework-rule-based; `/simplify` is LLM-judgment cleanup. Distinct mechanisms. |

### Model/effort sanity

`model: opus` + `effort: low` — per MEMORY.md: "orchestrator SKILL.md frontmatter should set `effort: low` alongside `model: opus`". Correct per project convention.

Phase 2 hardcodes `model: sonnet` for judge agents. Correct — judge is narrow confirmation, not reasoning-heavy. No change needed.

Model ID `opus` in frontmatter is a short alias. `token-budget.md` routing matrix should resolve to `claude-opus-4-8` per platform-delta.md 2026-05-28 model ID row. No SKILL.md action required unless platform requires explicit model IDs.

---

## E. Correctness

- `compatibility: ">=2.1.71"` — no newer feature requires bumping; `disallowed-tools` (v2.1.152) is not used so no constraint. **Correct.**
- `--no-confirm` flag documented in `argument-hint` and Phase 0.2 — consistent.
- `// code-doctor-ignore: <ruleId>` suppression: documented in both SKILL.md line 123 and `references/main.md §B`. Consistent.
- `docs/_audits/` write path: consistent between Phase 3.2 and `references/main.md §D`.
- `.cc-sessions/code-doctor-ledger.jsonl` ledger path: consistent between Phase 3.4 and `references/main.md §F`.
- Phase 2 subagent: `subagent_type: general-purpose, model: sonnet` — valid per spawn-protocol. Not broken.
- **subagents-cannot-spawn-subagents:** Skill is slash-invoked; it spawns one Agent in Phase 2. No subagent spawning subagents. Dynamic Workflows (v2.1.154+) do not change this — skill is not authored as a workflow. No action.
- No stale env vars or dead flags found.

---

## F. Verdict

**`needs-tightening`**

**Top 3 highest-leverage edits:**

1. **Ratchet delegation** — Replace `references/main.md §F` (18-line custom ledger spec) with a pointer to `ratchet-protocol.md` and a single config line: `ledger_key: "code-doctor-ledger.jsonl"`. Removes drift risk from parallel ratchet implementations.

2. **`disallowed-tools` annotation** — Add a comment in frontmatter noting that `disallowed-tools: Write, Edit` is the intended lockdown for `--scan` mode but cannot be set conditionally until platform supports mode-conditional frontmatter. Prevents silent assumption that model behavior alone enforces read-only.

3. **Spawn-protocol citation** — Add `[/_shared/spawn-protocol.md](/_shared/spawn-protocol.md)` to §Additional Resources alongside the other protocol links. Phase 2 Agent() call is currently uncited; citation makes the dependency explicit for future changes.
