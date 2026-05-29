---
unit: skills/sprint-dev
kind: orchestrator
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `sprint-dev`

Sources read: `skills/sprint-dev/SKILL.md` (457 lines), `skills/sprint-dev/references/main.md` (787 lines), `docs/audits/cohesion-2026-05/platform-delta.md`.

---

## A. Identity & Boundaries

**Purpose (one sentence):** Implements a planned sprint by spawning role-typed agents in isolated worktrees, distributing dependency-ordered story waves, and merging+verifying the result.

**Description vs body:** Description matches body. Frontmatter description is accurate and ≤1024 chars.

**Overlaps with other skills/agents:**

| Other unit | Nature | True dup or layering? |
|---|---|---|
| `blitz:implement` | Also spawns agents to write code | **Layering** — `implement` is single-story freeform; `sprint-dev` is multi-story wave-orchestrated sprint execution |
| `blitz:integration-check` | Verifies export-to-import tracing, route coverage | **Layering** — sprint-dev calls `integration-check` in Phase 3.5.0; no duplication |
| `blitz:completeness-gate` | Scores implementation completeness | **Layering** — called in Phase 4.2.5; not duplicated |
| `blitz:sprint-review` | Reviews completed sprint output | **Layering** — downstream consumer; no overlap in behavior |
| `blitz:sprint-plan` | Produces the manifest/stories sprint-dev consumes | **Layering** — upstream producer |
| `agents/backend-dev`, `agents/frontend-dev`, `agents/test-writer` | Implement stories inside worktrees | **Layering** — sprint-dev is the orchestrator; agents are workers |
| `blitz:next --loop` | Autonomous reconciliation loop that calls sprint-dev | **Layering** — caller, not duplicate |

No true duplication found.

---

## B. Cohesion

### _shared protocol citations and compliance

| Protocol | Cited? | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0, 1.6, 4.7) | Followed — Phase 1.6 registry-lock steps replicate the CHECK→ACQUIRE→VERIFY→OPERATE→RELEASE sequence verbatim. **Drift risk**: lock steps repeated at Phase 1.6 and Phase 4.7; both should reference protocol rather than restate. |
| `verbose-progress.md` | Yes (Phase 0) | Followed |
| `terse-output.md` | Yes (line 26 + every agent template) | **Invariant 5 compliant** — verbatim snippet present in SKILL.md body AND in all four agent templates in references/main.md |
| `story-frontmatter.md` | Yes (Phase 0.0, 1.3) | Followed |
| `state-handoff.md` | Yes (Phase 0.0, 4.7) | Followed |
| `spawn-protocol.md` | Yes (Phase 2.3, 3.5.1) | Followed — weight class annotated Heavy/Medium correctly |
| `carry-forward-registry.md` | Yes (Phase 3.2 §1a) | Followed |
| `checkpoint-protocol.md` | Yes (Phase 0 §1, Phase 3.2 §1b, 4.10) | Followed |
| `deviation-protocol.md` | Yes (Phase 3.3) | Followed |
| `context-management.md` | Yes (Phase 3.2 §5) | Followed |
| `knowledge-protocol.md` | Yes (Phase 0.5 + references/main.md §KNOWLEDGE.md Slice) | Followed |
| `worktree-lifecycle.md` | Yes (Phase 4.4) | Followed |
| `package-install-policy.md` | Yes (Phase 2.3 + references/main.md item 13) | Followed |
| `agent-prompt-boilerplate.md` | Cited in references/main.md via `<!-- import: -->` marker | Followed — per CLAUDE.md standard |
| `ratchet-protocol.md` | Not cited | Not followed inline either — sprint-dev produces the `stale_worktree_branch_count` metric input (Phase 4.4) and `type_errors` baseline (Phase 0) but does not reference the ratchet contract. Gap: if Phase 4.4 cleanup fails silently, ratchet counter increments and blocks next sprint-review. **Low severity** — sprint-review enforces ratchet; sprint-dev only needs to produce clean state. |
| `shortcut-taxonomy.md` | Not cited | Not followed. **Acceptable**: anti-shortcut enforcement is in agent templates (ANTI-MOCK RULES) and hooks; skill-level cite not required. |
| `token-budget.md` | Not cited | Missing. SKILL.md uses `model: opus`, `effort: high` — correct for orchestrator role per MEMORY.md feedback. But `token-budget.md` model-routing table and fast-mode surfacing (platform-delta.md `fast-mode-2026-02-01`) are not referenced. |

### Cross-refs live and accurate

- `references/main.md` sections cited in SKILL.md body (e.g., §"Resume Divergence Gate", §"Dev Agent Prompt Specification"): **verified** — all sections present in references/main.md.
- `/_shared/*` links: all cited protocols exist.
- `docs/_research/2026-05-16_*` paths in references/main.md: not verified (outside scope of this audit — marked **inferred**).
- `compatibility: ">=2.1.71"` — current platform is v2.1.154+; constraint is permissive, not stale (correct — lower bound, not pinned version).

### Produces/consumes per state-handoff.md

- **Consumes**: `sprint-registry.json` (status `planned`), `sprints/sprint-N/manifest.json`, `sprints/sprint-N/stories/S*.md` — verified in Phase 0.0.
- **Produces**: sprint branch `sprint-N/merged`, updated `sprint-registry.json` (status `review`), story frontmatter status updates, `STATE.md` — consistent with state-handoff.md contract.
- No invented shapes found.

### Pipeline chain trace (sprint-plan → sprint-dev → sprint-review)

1. **sprint-plan** produces `sprint-registry.json` (status `planned`) + story files.
2. **sprint-dev** Phase 0.0 gate reads exactly those artifacts.
3. **sprint-dev** Phase 4.7 writes `status: review`.
4. **sprint-review** (verified in prior audits) reads `status: review` + story `status` fields.

Chain is intact. No shape mismatch found.

---

## C. Conciseness

**SKILL.md body**: 457 lines — **under 500-line cap** (compliant).

**references/main.md**: 787 lines — not capped (reference files are not subject to SKILL.md 500-line cap per CLAUDE.md).

### Prose compensating for old-model behavior (deletion candidates)

| Location | Quote | Failure mode guarded | Mark |
|---|---|---|---|
| Phase 3.5 header | `"This phase is **mandatory** and must not be skipped, even if no explicit UI stories exist."` | Model skipping integration pass on sprints with no UI stories | **Delete** — 4.8 honesty gains make this redundant; the phase structure itself enforces it |
| Phase 2.3 | `"**Note:** The \`isolation: "worktree"\` parameter replaces manual \`git worktree add\` commands."` | Old model attempting manual worktree setup when platform primitive exists | **Delete** — note compensates for pre-2.1.71 behavior; current `compatibility: ">=2.1.71"` means agents always have native `isolation: worktree` |
| references/main.md §KNOWLEDGE.md Slice Procedure | `"Future slicing strategy (not yet implemented): grep entries by topic keywords matching the current sprint's story file paths. For now, tail-30 is the recency proxy."` | None (aspirational roadmap note) | **Delete from skill** — belongs in a TODO tracker, not a running skill definition |
| Phase 3.2 §1a | `"Apply the inference-fallback (parent-epic link with \`delta: 1\`) when the story omits \`registry_entries\`."` — duplicated from carry-forward-registry.md | Model omitting carry-forward on incomplete stories | **Delegate** — `carry-forward-registry.md` §Writers already specifies this; inline restatement is drift risk |
| Phase 1.6 lock steps (5 sub-steps) | Full CHECK→ACQUIRE→VERIFY→OPERATE→RELEASE block | Model skipping lock acquisition | **Delegate** — same block repeated at Phase 4.7; both should be `"Follow /_shared/session-protocol.md §File-Based Locking Protocol"` (1 line each) — saves ~10 lines each = ~20 lines total |
| Phase 4.8.5 | `"Never silently drop blocked stories."` | Model not creating carry-forward for blocked stories | **Borderline** — keep as imperative invariant; very cheap (1 line) |

**Estimated removable lines in SKILL.md**: ~35 (mandatory-note 1 line, worktree note 3 lines, two lock-step blocks → 2 references ~20 lines total, carry-forward restatement ~5 lines, misc inline duplications ~6 lines).

**Estimated removable lines in references/main.md**: ~20 (future-slicing TODO note ~5 lines, other aspiration prose ~15 lines).

**Total removable**: ~55 lines.

### Content belonging in a shared protocol (DRY)

- The per-wave caps formula (`≤4 stories AND ≤6 affected files`) and the sprint-276 root-cause note in Phase 2.3 are spawn-budget policy. Belongs in `spawn-protocol.md` §Heavy weight class, not duplicated inline.
- The ANTI-MOCK RULES block in all four agent templates (references/main.md) is partially covered by `definition-of-done.md` (cited in references/main.md item 8). Either collapse to a cite or keep for byte-stable spawn sources — current approach is defensible since agent templates must be byte-stable.

---

## D. Modernization

### Native primitive overlap (all citations from platform-delta.md)

**`isolation: "worktree"` — KEEP (already native)**
SKILL.md Phase 2.3 already uses `isolation: "worktree"` (platform-delta.md v2.1.154+). Manual `git worktree add` is NOT used. **Status: up-to-date.**

**Native workflow orchestration — DELEGATE (partial)**
Platform-delta.md v2.1.154+: JS script fans work across ≤16 concurrent agents; intermediate results in script variables, not context window. Sprint-dev's wave-dispatch loop (Phase 3.2) replicates this in-process: it tracks `agent_tracker` in context, sends `UNBLOCK:` messages, rebuilds from STATE.md on resume.

- **Keep** the cross-session resume logic (`STATE.md` + `carry-forward-registry.md`) — native workflows are intra-session only (platform-delta.md 2026-05-28); gap persists.
- **Keep** the `block_reason` vocabulary + circuit breaker — platform has no equivalent per-story failure taxonomy.
- **Delegate** wave dispatch to native workflows if/when Blitz adopts them — the 16-agent concurrency cap (platform-delta.md 2026-05-28) aligns with sprint-dev's typical 4-agent wave.
- **Tradeoff**: delegating loses the `block_reason` → `/blitz:next` LOOP_ESCALATE routing chain and the `BLITZ_RESUME_ON_DIVERGENCE` contract. Not safe to delegate until native workflows surface per-agent failure metadata.

**`disallowed-tools` frontmatter — DELEGATE**
Platform-delta.md v2.1.152: `disallowed-tools` per-skill removes tools from the pool. Sprint-dev SKILL.md currently has no `disallowed-tools`. Prose guards (`ANTI-MOCK RULES: BANNED: return {}`) could be reinforced with `disallowed-tools` but ANTI-MOCK is semantic (about content), not tool-level — `disallowed-tools` cannot block writing empty functions. **No mechanical delegation possible; keep prose guards.**

**`claude agents` TUI (research preview) — INFORMATIONAL**
Platform-delta.md 2026-05-28: native `claude agents` panel partially closes the multi-worktree visibility gap. Sprint-dev's `Monitor(tail -f progress.md)` remains the primary mechanism; `claude agents` complements but doesn't replace it. No action required today.

**Opus 4.8 fast mode — UPDATE RECOMMENDED**
Platform-delta.md `fast-mode-2026-02-01`: `claude-opus-4-8` fast mode at $10/$50 per MTok, 2.5× faster. Sprint-dev orchestrator is latency-critical (wave dispatch). `token-budget.md` should be updated; sprint-dev's `model: opus` frontmatter should reference `claude-opus-4-8` + optionally `speed: "fast"` for wave-dispatch calls. **Current `model: opus` is an alias — verify it resolves to `claude-opus-4-8`** (platform-delta.md model IDs 2026-05-28 list `claude-opus-4-8` as current).

**`compatibility: ">=2.1.71"` — UPDATE**
Minimum for `isolation: "worktree"` is v2.1.71 (inferred from feature availability; not in platform-delta.md — **inferred**). `disallowed-tools` requires v2.1.152. If `disallowed-tools` is added to frontmatter, bump to `>=2.1.152`.

### Model/effort sanity

- `model: opus` + `effort: high`: correct per MEMORY.md feedback ("opus orchestrator + sonnet Agent workers") and CLAUDE.md ("Skill orchestrator pairs opus with effort: low" feedback conflicts with `effort: high`).
- **Conflict detected**: MEMORY.md feedback entry `feedback_skill_effort_low.md` says "orchestrator SKILL.md frontmatter should set `effort: low` alongside `model: opus`". Sprint-dev uses `effort: high`. This is a legitimate divergence — sprint-dev launches full multi-wave implementations; `effort: low` is appropriate for lightweight routing orchestrators (e.g., `blitz:next`), not for complex multi-phase work. **Keep `effort: high`** with a note that the feedback applies to routing-only orchestrators.

---

## E. Correctness

**Stale version refs:**
- `compatibility: ">=2.1.71"` — permissive lower bound; not stale (acceptable).
- `model: opus` — not pinned to an explicit model ID. Resolves to current Opus per platform default. Should pin to `claude-opus-4-8` per platform-delta.md 2026-05-28 model IDs.

**Dead flags:**
- `BLITZ_SKIP_KNOWLEDGE_INJECTION`, `BLITZ_SPRINT_COMPLEXITY_OVERRIDE`, `BLITZ_RESUME_ON_DIVERGENCE`, `BLITZ_SKIP_BRANCH_CLEANUP` — all present in references/main.md scripts; none appear dead.

**Broken paths:** None found. All `/_shared/` refs verified present (inferred from other audits; not individually re-read in this session — **inferred**).

**Wrong tool names:** `TaskCreate`, `TaskUpdate`, `TaskList` in `allowed-tools` — match current platform tool names (verified as of v2.1.154).

**`subagents-cannot-spawn-subagents` constraint:**
SKILL.md correctly remains slash-invoked (`/blitz:sprint-dev`). Phase 2.3 spawns dev agents from the orchestrator (top-level skill), not from a subagent. Dynamic Workflows (platform-delta.md v2.1.154+) does not change this constraint for the current architecture — the constraint applies within a workflow run. Sprint-dev's worktree-per-agent pattern predates native workflows; if sprint-dev is eventually ported to a native workflow script, the spawning model changes but the slash-only entry point remains correct for cross-session resume. **No change needed.**

**Phase numbering inconsistency:** Phase 4.2.1 appears after Phase 4.2.5 in the document (lines 379 vs 372). Section order is 4.2 → 4.2.5 → 4.2.1. Execution order presumably is 4.2 → 4.2.1 → 4.2.5 but document reversal creates ambiguity. **Minor correctness issue.**

---

## F. Verdict

`needs-tightening`

Skill is **coherent and correct**. No true duplication with other skills. Pipeline chain intact. Invariant 5 (OUTPUT STYLE) present in SKILL.md and all four agent templates. Primary issues:

1. ~55 removable lines (anti-laziness prose, duplicated lock steps, aspirational TODO notes).
2. `model: opus` should pin to `claude-opus-4-8`; `token-budget.md` fast-mode surfacing missing.
3. Per-wave caps belong in `spawn-protocol.md` §Heavy, not inline.
4. Phase 4.2.1/4.2.5 ordering inversion.

---

## Top Edits (highest leverage)

1. **Collapse both lock-step blocks** (Phase 1.6 and Phase 4.7) to single-line references: `"Follow /_shared/session-protocol.md §File-Based Locking Protocol."` Saves ~20 lines; eliminates drift between SKILL.md and the protocol.

2. **Pin model ID and surface fast mode**: Change `model: opus` → `model: claude-opus-4-8`; add note to reference `token-budget.md` §fast-mode for wave-dispatch latency. Per platform-delta.md `fast-mode-2026-02-01`.

3. **Fix Phase 4.2.1/4.2.5 ordering**: Move §4.2.1 Cross-Phase Regression Testing to immediately after §4.2, before §4.2.5 Completeness Gate — execution logic flows 4.2 → 4.2.1 → 4.2.5 → 4.3.
