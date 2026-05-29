---
unit: skills/integration-check
kind: skill
verdict: needs-tightening
removable_lines: 18
created: 2026-05-28
---

# Cohesion Audit — integration-check

## A. Identity & Boundaries

**One-sentence purpose**: Read-only cross-module wiring validator: traces exports→imports, routes, auth guards, store/form/state wiring via 3 parallel domain agents.

**Description vs body match**: Accurate. Description lists the 5 check domains (export-import, route coverage, auth guard, store-to-component) and the sprint-dev 3.5.0 trigger. Body implements exactly those domains via 3 grouped agents (check-wiring, check-auth, check-ui). No gap.

**Overlapping skills/agents**:

| Skill | Overlap Area | Verdict |
|---|---|---|
| `completeness-gate` | Both analyze source files for gaps | Legitimate layering — completeness-gate scores story acceptance criteria; integration-check traces live wiring topology |
| `codebase-audit` | Both run parallel domain agents over the codebase | Legitimate layering — codebase-audit covers 10 quality pillars (security, deps, perf, etc.); integration-check is wiring-only |
| `code-sweep` | Both grep source for patterns | Legitimate layering — code-sweep hunts dead/duplicate code; integration-check traces consumer relationships |
| `sprint-review Phase 1.6` | sprint-review invokes integration-check conditionally | Correct delegation — sprint-review calls `/blitz:integration-check all`, not a duplicate |

No true duplicates found.

---

## B. Cohesion

**Protocols cited vs followed**:

| Protocol | Cited | Followed |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0) | Verified — SESSION_ID, tmp dir, `skill_start` log |
| `verbose-progress.md` | Yes (Phase 0.0) | Verified — `skill_complete` + cleanup in Phase 4 |
| `spawn-protocol.md` | Yes (§1.2, §1.3) | Verified — `subagent_type: general-purpose`, `model: sonnet`, Medium weight class, 12/20 limits |
| `agent-prompt-boilerplate.md` | Yes (`<!-- import: -->` in references/main.md) | Verified — BUDGET, WRITE-AS-YOU-GO, HEARTBEAT, CONFIRMATION blocks present verbatim in references/main.md template |
| `terse-output.md` | Yes (§Additional Resources + inline) | Verified — OUTPUT STYLE snippet present verbatim in SKILL.md line 21 and in agent prompt template |
| `definition-of-done.md` | Referenced (line 31) | Cannot verify — file not read; cited as standards source |
| `state-handoff.md` | Not cited | Not cited but consistent: `quality-matrix.md` shows integration-check produces `findings list (read-only)`, no consume of structured upstream artifact — correct for a gate skill |

**Cross-refs live and accurate** (verified):
- `references/main.md` exists and is the spawn source — correct
- `spawn-protocol.md`, `session-protocol.md`, `verbose-progress.md`, `terse-output.md` all exist in `_shared/`
- `definition-of-done.md` exists in `_shared/` — link valid

**Invariant 5 (OUTPUT STYLE verbatim)**: PASS — snippet present at SKILL.md line 21 and in agent prompt template inside references/main.md.

**Pipeline chain trace** (sprint-dev → integration-check → sprint-review):
- sprint-dev Phase 3.5.0 calls `/blitz:integration-check` — verified in sprint-dev SKILL.md line 340
- integration-check emits structured console report + cleans up JSON — no file artifact consumed by sprint-review
- sprint-review Phase 1.6 re-invokes `/blitz:integration-check all` independently — no dependency on prior run artifacts
- Chain is clean: integration-check is stateless/read-only; each invoker gets a fresh run. No handoff artifact gap.

**state-handoff.md compliance**: No entries for integration-check in state-handoff.md (checked via grep — no output). `quality-matrix.md` documents it correctly as producing a findings list with no structured file output. Consistent with Phase 4 cleanup removing the tmp JSON files. **Gap**: integration-check does not persist findings for downstream consumers; if sprint-review runs it again, work is duplicated. Acceptable given read-only/cheap nature.

---

## C. Conciseness

**Body line count**: 187 lines (SKILL.md) + 177 lines (references/main.md) = 364 total. Under 500-line cap. PASS.

**Anti-laziness prose to mark for deletion** (compensates for old-model behavior):

- SKILL.md line 29: `"This skill is read-only. It does NOT modify any code."` — redundant with `allowed-tools` list and Phase 0 context. 4.8 honesty means the model reads tool constraints; this guard existed for models that ignored tool lists. **Removable** (1 line).

- SKILL.md lines 64-65: `"Spawn the active agents in a single assistant message so they run concurrently."` — spawn-protocol.md §parallel-spawn already mandates this; restating here is drift risk if the shared protocol changes. **Removable or replace with `<!-- see spawn-protocol.md §parallel-spawn -->`** (1 line).

- references/main.md lines 10-11 (import comment paragraph): explains that the inline template is kept "byte-stable" and that agent-prompt-boilerplate.md is only an "author-time dedup target". This is metadata about the dedup convention, not runtime content. Belongs in a comment, not prose. Currently 3 lines of prose before the template. **Shrink to 1-line comment** (−2 lines).

- references/main.md: Framework-Specific Wiring Patterns section (lines ~130-177) — 48 lines of framework docs (Nuxt 3, Vue 3, Pinia, Firebase). This is reference material for the human author, not injected into agent prompts (the `{{CHECK_DEFS}}` variable substitutes domain-specific patterns, not this section). If agents don't receive it, it's dead weight in references/main.md. **Verify injection or remove** (potential −48 lines if not injected; counted as 14 removable lines conservatively since CHECK_DEFS may be manually constructed from it).

**DRY violations**:
- Severity classification table appears in both SKILL.md (lines 174-178) and references/main.md (Severity Classification section). One copy is sufficient; SKILL.md copy should be removed (the agents receive it via references/main.md). **Removable** (5 lines from SKILL.md).

**Estimated removable lines**: ~18 (1 read-only guard + 1 concurrent spawn reminder + 2 import comment prose + 5 severity table dupe + 9 from framework patterns clarification).

---

## D. Modernization

**Native primitive overlap** (per platform-delta.md):

| Claim | platform-delta.md cite | Verdict |
|---|---|---|
| 3-agent parallel spawn replicates native workflow fan-out | v2.1.154+ / 2026-05-28 — "JS script fans work across dozens–hundreds of parallel subagents; intermediate results stay in script variables" | **Keep** with caveat: native workflows would work but the blitz implementation adds opinionated domain grouping (wiring/auth/ui), structured JSON schema, severity classification, and framework-specific grep patterns that native fan-out does not provide. Delegating loses the Vue/Nuxt/Firebase contract specificity. |
| `model: opus` orchestrator + `model: sonnet` agents | fast-mode-2026-02-01 / 2026-05-28 — `claude-opus-4-8` fast mode at $10/$50 MTok | **Update model IDs**: frontmatter `model: opus` should reference `claude-opus-4-8`; agent spawn `model: sonnet` should reference `claude-sonnet-4-6` per platform-delta.md verified model IDs (2026-05-28). |
| `disallowed-tools` not used | v2.1.152 — `disallowed-tools` SKILL.md frontmatter field available | **Opportunity**: skill is read-only by design; add `disallowed-tools: [Write, Edit]` to frontmatter to enforce declaratively instead of prose guard on line 29. This makes the "read-only" constraint a platform primitive. |

**`disallowed-tools` note**: agents need Write for their JSON output files, so `disallowed-tools` applies to the orchestrator only — enforce read-only on the orchestrator, not the spawned agents (correct as-is for agents).

**Model/effort sanity under 4.8**:
- `model: opus` + `effort: medium` — orchestrator is lightweight (spawns 3 agents, merges JSON). With 4.8 honesty gains, opus for orchestration is more expensive than needed; **consider `model: sonnet` + `effort: medium`** since the orchestrator's work is JSON merge + report formatting, not reasoning-heavy analysis.
- Agent `model: sonnet` — appropriate.

---

## E. Correctness

**Stale version refs**: `compatibility: ">=2.1.71"` — no known issue with this floor; workflows (v2.1.154+) not required by this skill. Floor is accurate.

**Model IDs**: `model: opus` in frontmatter does not reference `claude-opus-4-8`. Not pinned to specific model ID — may resolve correctly via alias but ambiguous. Same for agent spawn `model: sonnet` vs `claude-sonnet-4-6`.

**Subagents-cannot-spawn-subagents constraint**: SKILL.md is slash-only (confirmed in `agent-routing.md` line 25 listing integration-check as super-orchestrator). This remains correct — integration-check spawns 3 parallel agents, which cannot themselves spawn agents. Dynamic Workflows (v2.1.154+) do not change this constraint for the Claude Code skill execution model; the `Agent` tool invocation in skills is not the same as JS workflow scripts. **Keep slash-only**.

**Dead paths/flags**: None found. `SESSION_TMP_DIR`, `EXPECTED_FILES`, output paths all consistent. Cleanup instruction in Phase 4 (`rm check-*.json`) matches the file names defined in Phase 1.

**`definition-of-done.md` reference** (line 31): file exists in `_shared/`; link is live. Content relevance unverified (did not read definition-of-done.md).

---

## F. Verdict

**`needs-tightening`**

### Top 3 Highest-Leverage Edits

1. **Add `disallowed-tools: [Write, Edit]` to orchestrator frontmatter** — replaces the prose guard on line 29; makes read-only constraint a platform primitive per platform-delta.md v2.1.152. Remove line 29 prose after.

2. **Pin model IDs to `claude-opus-4-8` / `claude-sonnet-4-6`** (or consider downgrading orchestrator to `claude-sonnet-4-6` since orchestrator work is JSON merge, not deep analysis) — per platform-delta.md verified model IDs 2026-05-28.

3. **Remove duplicate severity table from SKILL.md lines 174-178** — already present in references/main.md; single source in references is the correct location since that's what agents receive.
