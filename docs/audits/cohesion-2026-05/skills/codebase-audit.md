---
unit: codebase-audit
kind: skill
verdict: needs-tightening
removable_lines: 35
created: 2026-05-28
---

# Audit: `skills/codebase-audit`

Source read: `skills/codebase-audit/SKILL.md` (474 lines) + `skills/codebase-audit/references/main.md` (487 lines). Platform delta read: `docs/audits/cohesion-2026-05/platform-delta.md` (2026-05-28).

---

## A. Identity & Boundaries

**One-sentence purpose:** Run a 5-pillar (Architecture, Performance, Security, Maintainability, Robustness) full-repo quality audit via 10 parallel agents, emitting findings + roadmap-ingestible epic index.

**Description vs body match:** Matches. Description accurately names the 5 pillars, 10 agents, and downstream consumers (`/blitz:roadmap`, `/blitz:sprint-plan`).

**Overlapping skills (verified via `_shared/quality-matrix.md` + cross-reference search):**

| Skill | Overlap type | Verdict |
|---|---|---|
| `code-doctor` | Both audit code quality | Legitimate layering — code-doctor is framework-specific (Vue/Firestore/Pinia) rule pack; codebase-audit is universal 5-pillar. Documented in quality-matrix.md row "codebase-audit + code-doctor". |
| `code-sweep` | Both find quality issues | Legitimate layering — code-sweep is a ratchet/continuous loop; codebase-audit is a quarterly one-shot. quality-matrix.md confirms no code duplication. |
| `sprint-review` | Both review code | Legitimate layering — sprint-review gates a single sprint (8 invariants); codebase-audit is pre-release/quarterly breadth scan. |
| `perf-profile` | Both address performance pillar | Partial overlap — perf-profile is runtime profiling (flame graphs, traces); codebase-audit/perf agents do static analysis. No true duplication; different evidence types. |
| `security-review` | Both cover security | Partial overlap — security-review is a standalone skill (not in quality-matrix.md's 7). codebase-audit's sec-rules + sec-code agents cover same domain. **Risk**: if `security-review` exists independently, two skills cover the same security scope. Needs cross-check. _Inferred from skill listing; security-review SKILL.md not read for this audit._ |

---

## B. Cohesion

### _shared protocols cited and followed

| Protocol | Cited | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | §0.0 (explicit ref) | Delegates — "Follow §Session Registration (steps 1-9)". Clean. |
| `verbose-progress.md` | §0.0 (explicit ref) | Delegates — "Print verbose progress at every phase transition". Clean. |
| `spawn-protocol.md` | §Additional Resources + §1.1 | Followed — `subagent_type: general-purpose`, `model: sonnet` explicit, `run_in_background: true`. Minor restatement in §1.3 step 8 (write-as-you-go rule) is agent-facing, not orchestrator-facing; acceptable. |
| `workflow-dispatch.md` | §1.0 (explicit ref) | Delegates capability gate correctly. |
| `carry-forward-registry.md` | §3.3a (explicit ref) | Follows — `scope:` YAML frontmatter contract specified with sample. |
| `terse-output.md` | Lines 22-23 (verbatim snippet) | **Invariant 5 PASS** — OUTPUT STYLE snippet present verbatim. |
| `token-budget.md` | Implicit via `model: sonnet` in agents | Not cited by name. Agents explicitly pin `model: sonnet` to prevent `[1m]` inheritance — this is the right behavior per memory note, but `token-budget.md` reference in Additional Resources section is absent. Low risk (behavior is correct). |
| `state-handoff.md` | Not cited | Produces `docs/audits/audit-YYYYMMDD.md`, `…-epics.md`, `…-index.json`. These are the canonical carry-forward shapes. No conflict found. |
| `story-frontmatter.md` | Not cited | Does not produce story files; not a producer in that schema. No issue. |
| `agent-prompt-boilerplate.md` | `references/main.md` line 9 (import comment) | Cited but not fully delegated — `references/main.md` says "see shared fragment" but keeps a full inline agent prompt template for "Invariant 5 byte-stable spawn source". Rationale is explicit and valid. |

### Cross-references

All `/_shared/` links in SKILL.md appear valid. `docs/_research/2026-05-16_audit-agent-fp-prevention.md` referenced in §2.1.5 and `references/main.md` rule 2/3 — not verified to exist (inferred from path pattern).

### Pipeline chain (end-to-end trace)

`/blitz:codebase-audit` → emits `docs/audits/audit-YYYYMMDD-index.json` with `proposed_epics[]` → `/blitz:roadmap extend` ingests via `scope:` YAML frontmatter in `…-epics.md` → sets `ingested_at` in index → `/blitz:next` Phase 0.9b reads `status` field to detect deferred work.

Chain is internally consistent. `carry-forward-registry.md` §Writers contract is met (id, unit, target, description, acceptance fields all specified in §3.3a).

**One gap:** `references/main.md` Epic Index JSON schema (lines 439-486) includes `overall_health_score` + `pillar_scores` at top level, but SKILL.md §3.5 schema (lines 408-441) omits these fields. The two schemas are out of sync. Consumers reading the index file may miss health scores if they follow only the SKILL.md schema.

---

## C. Conciseness

Body: 474 lines (cap: 500). Under cap but dense.

### Anti-laziness / defensive prose (candidates for deletion under 4.8 honesty gains)

| Line(s) | Quote | Failure mode guarded | Deletable? |
|---|---|---|---|
| 31 | `"Execute every phase in order. Do NOT skip phases."` | Model skipping phases to appear done faster. With 4.8 honesty + opus orchestrator, this is redundant. | Yes — ~1 line |
| 31 | `"ultrathink across pillar synthesis"` | Model producing shallow single-pillar output. `ultrathink` is a prompt-engineering nudge, not a protocol. With 4.8 + `/effort high`, redundant. | Yes — partial phrase |
| 149 | `"Each agent prompt must also include: max 250-line output per pillar, 5-minute wall-clock budget, mandatory write-as-you-go (step 8 of prompt construction below)."` | Agent ignoring constraints. These are restated in §1.3 (step 8) and in `references/main.md` rule 1. Triple-stated. | Trim to single ref (~1 line saved) |
| 176-185 | §1.3 "Agent Prompt Construction" numbered list (items 1-8) | Model constructing incomplete prompts. The template in `references/main.md` already encodes all these items. §1.3 is a restatement of the template structure. | Condense to "Use template from references/main.md; all 8 items pre-encoded." — saves ~12 lines |
| 189-196 | §1.4 polling loop + "Timeout: If any agent has not produced output after 5 minutes, mark it as failed and proceed." | Model waiting indefinitely or not handling failures. Already covered by §2.2 failure handling. | Merge into §2.2, save ~6 lines |

**Estimated removable lines: ~35** (12 from §1.3 collapse + 6 from §1.4 merge + 8 from `references/main.md` redundant schema sync + partial anti-laziness phrases + schema discrepancy fix).

### Content belonging in shared protocol

`references/main.md` rule 2 (falsify-before-recording with 4 sub-patterns) and rule 3 (confidence scoring 0-100) are audit-domain-specific enough to stay in references rather than being pushed to `_shared/`. No DRY violation.

---

## D. Modernization

### Native primitives (platform-delta.md citations)

**Native Workflows (platform-delta.md v2.1.154+, 2026-05-28):** Codebase-audit already has a Workflow dispatch path (§1.0, §1.1-W). The `USE_WORKFLOW=maybe` auto-detection is correct. The 10-agent flat pool maps well to native `parallel()` — no DAG required. **Verdict: keep workflow path; already modernized.** No loss of determinism since both paths produce identical output files.

**`disallowed-tools` frontmatter (platform-delta.md v2.1.152):** Audit agents should be read-only (no Write except to their findings file). Currently enforced via prompt instruction only. Could add `disallowed-tools: [Edit]` to the orchestrator SKILL.md to prevent accidental edits of non-findings files. Pillar agents need Write for findings but not Edit. The platform delta enables this per-skill lockdown. **Verdict: candidate improvement** — orchestrator-level `disallowed-tools` not applicable (orchestrator writes audit report), but agent prompts could specify `disallowed-tools` for tighter control. Currently not expressible per-agent in frontmatter (only per-skill). Low priority.

**Opus 4.8 fast mode (platform-delta.md fast-mode-2026-02-01 beta, $10/$50 per MTok):** Orchestrator uses `model: opus`. With Opus 4.8 fast mode at 2.5x throughput and 3x cheaper than 4.6/4.7 fast mode, the orchestrator phase (synthesis, dedup, epic generation) is a strong candidate for fast mode. **Verdict: update `token-budget.md` routing; no SKILL.md change needed here** (routing is token-budget's concern).

**Model IDs (platform-delta.md 2026-05-28):** Current model IDs: `claude-opus-4-8`, `claude-sonnet-4-6`. SKILL.md uses shorthand `model: opus` and `model: sonnet` (in agent spawning). These are alias-style — acceptable if the platform resolves them. If not, SKILL.md should pin `model: claude-opus-4-8`. **Verdict: inferred that shorthand works; verify against platform docs.** _Unverified._

**`/effort ultracode` + workflow trigger (platform-delta.md v2.1.154+):** `effort: high` frontmatter. `ultracode` (`xhigh`) would auto-trigger workflow orchestration — codebase-audit already has its own workflow dispatch gate (`BLITZ_DISPATCH`). No conflict, but the note in platform-delta.md about `token-budget.md` needing to account for `ultracode` multi-workflow sessions applies here. No SKILL.md change needed.

**Agent cap 16 concurrent (platform-delta.md 2026-05-28):** 10 agents in one `parallel()` is within the 16 cap. Safe.

---

## E. Correctness

- **`compatibility: ">=2.1.71"`** — Workflow path requires v2.1.154+; `disallowed-tools` requires v2.1.152. The compatibility floor is stale for these features. However, both are opt-in (Workflow is auto-fallback; `disallowed-tools` not yet used). **Low risk but should be bumped to `>=2.1.154`** to signal minimum for full feature set.

- **`SESSION_TMP_DIR` variable** — Used in Phase 0.1 without definition source. Presumably set by session-protocol.md or the platform environment. Not verified. _Inferred._

- **Schema discrepancy** — `references/main.md` Epic Index schema includes `overall_health_score` + `pillar_scores` keys that §3.5 (SKILL.md) omits. Downstream consumers (`/blitz:roadmap`, `/blitz:next`) expecting those keys from the SKILL.md spec will silently miss them. **Correctness bug.**

- **`docs/_research/2026-05-16_audit-agent-fp-prevention.md`** — Referenced in §2.1.5 and `references/main.md` rules 2-3. Path follows research naming convention; existence not verified. If missing, references are dead. _Unverified._

- **Subagents-cannot-spawn-subagents constraint** — Skill is slash-invoked (not spawnable as subagent). Dynamic Workflows (platform-delta.md v2.1.154+) enable JS-script fan-out without the subagent-spawning-subagent restriction. However, codebase-audit already uses the Workflow path as opt-in. No change needed; slash-only remains correct for cross-session resume (STATE.md) which native workflow doesn't support (intra-session only per platform-delta.md).

- **`Confidence` field in agent findings** — §2.1 says "each finding has: … **Confidence: 0-100**" but does not enforce this in the output format header (§2.1, first bullet). `references/main.md` rule 3 adds it to agent instructions. If an agent omits it, §2.1.5 notes "trigger detector #20" but that detector is only advisory. Gap between advisory and enforced.

---

## F. Verdict

**`needs-tightening`**

- Body is under 500-line cap but has ~35 removable lines of redundant phase instructions (§1.3/§1.4) and anti-laziness nudges obsolete under 4.8 honesty.
- One correctness bug: SKILL.md §3.5 schema omits `overall_health_score`/`pillar_scores` present in `references/main.md` Epic Index schema.
- `compatibility` floor stale (`>=2.1.71` vs features requiring `>=2.1.154`).
- No retire/delegate justified: the 5-pillar orchestration is a value-added opinionated layer; native Workflows don't replace the pillar structure, checklist, or epic-generation pipeline.

### Top 3 highest-leverage edits

1. **Fix schema discrepancy** — add `overall_health_score` and `pillar_scores` to SKILL.md §3.5 JSON schema (or add a cross-ref noting they're defined in `references/main.md`). Prevents silent data loss for downstream consumers.

2. **Collapse §1.3 + §1.4** — replace 18-line prompt-construction list + polling section with: "Construct each prompt from the template in `references/main.md` (all 8 required items pre-encoded). Poll for completion; timeout 5 min per agent — mark failed, continue." Saves ~18 lines.

3. **Bump `compatibility` to `>=2.1.154`** — reflects actual minimum for Workflow path; documents true feature floor.
