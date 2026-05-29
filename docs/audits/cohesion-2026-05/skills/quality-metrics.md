---
unit: quality-metrics
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `quality-metrics`

## A. Identity & Boundaries

**One-sentence purpose**: Collect, persist, and visualize code-quality scores (TypeScript errors, lint debt, test pass-rate, build status, completeness) as time-series snapshots in `docs/metrics/`.

**Description ↔ body match**: Accurate. Description mentions four modes (collect, dashboard, trend, compare); body implements all four across Phases 0–5. No drift.

**Overlaps with other skills/agents**:

| Skill | Overlap zone | Classification |
|---|---|---|
| `sprint-review` Phase 1 | Runs `tsc --noEmit`, `eslint`, tests, build — same tools, same exit-code semantics | **Legitimate layering**: sprint-review is a gate (PASS/FAIL per-sprint), quality-metrics is an observability snapshot (score time-series). Different output shape, different consumer. No code duplication in SKILL.md. |
| `dep-health` | Both read `package.json` dependencies | **Legitimate layering**: dep-health produces CVE/outdated/license audit; quality-metrics counts `dependencies` + `devDependencies` keys for codebase-size signal. Depth differs. |
| `completeness-gate` | quality-metrics imports completeness score via `collect-completeness` agent | **Legitimate composition**: completeness-gate owns the score; quality-metrics reads it as one dimension. Not duplication. |
| `ratchet-protocol.md` (shared) | Both track monotonic metric trends over time | **Partial overlap — not yet a problem**: ratchet uses `stale_worktree_branch_count` + 8 blitz-internal metrics; quality-metrics tracks code-quality scores. Different metric sets, different storage paths. If ratchet expands to cover lint/type-error scores this overlap becomes real duplication. |

`quality-matrix.md` does not list `quality-metrics` in the 7-skill matrix. It appears only as a downstream of `/blitz:ship`. Not a correctness issue but signals the matrix is incomplete (minor gap).

---

## B. Cohesion

### _shared protocols cited vs followed

| Protocol | Cited | Followed or restated inline |
|---|---|---|
| `session-protocol.md` | ✓ (Phase 0.0 defers to §Session Registration steps 1-9) | Followed — no inline restatement |
| `verbose-progress.md` | ✓ (Phase 0.0) | Followed |
| `spawn-protocol.md` | ✓ (cross-ref block + Phase 1.2) | Followed — weight class + parameters stated, not duplicated |
| `terse-output.md` | ✓ (cross-ref block) | Followed |
| `state-handoff.md` | Not cited | See below |
| `story-frontmatter.md` | Not cited (not a sprint-phase skill) | N/A — quality-metrics is post-sprint; it consumes `completeness-gate` output, not story files. Acceptable gap. |
| `agent-prompt-boilerplate.md` | ✓ (references/main.md §Collector Agent Prompt Template cites it inline) | Followed — `<!-- import: -->` marker present, canonical sections referenced |

**`state-handoff.md`**: `session-protocol.md` conflict matrix row shows `quality-metrics` produces `${SESSION_TMP_DIR}/quality-metrics.json` (verified). `state-handoff.md` not cited in SKILL.md — low risk since this skill is a leaf node (not piped into another skill's Phase 0 input), but citation should be added for completeness.

### Invariant 5 — OUTPUT STYLE snippet

Present verbatim at line 23 of SKILL.md ✓. Also present in `references/main.md` collector agent prompt template ✓.

### Cross-refs live + accurate

- `/_shared/session-protocol.md` — exists ✓
- `/_shared/verbose-progress.md` — exists ✓  
- `/_shared/spawn-protocol.md` — exists ✓
- `/_shared/terse-output.md` — exists ✓
- `/_shared/agent-prompt-boilerplate.md` — exists ✓ (cited in references/main.md)
- `skills/quality-metrics/references/main.md` — loaded via `!cat` directive ✓

### Pipeline chain trace: `/blitz:ship` → `quality-metrics collect` → `/blitz:release`

`ship/SKILL.md` line 122–124 calls `quality-metrics collect`; expects it to succeed (no output consumed by release). `quality-metrics` writes `docs/metrics/YYYY-MM-DD.json`; `ship` does not read this file — it's observability-only. Chain is: emit snapshot, continue. No contract mismatch. ✓

---

## C. Conciseness

**Body line count**: SKILL.md = 400 lines (cap = 500 ✓). `references/main.md` = 397 lines (no cap on references; appropriate home for templates/schemas).

### Anti-laziness nudges / defensive restatements (mark for deletion)

1. **Line 29**: `"Do NOT skip phases."` — defensive anti-shortcut guard. With Opus 4.8 honesty gains (platform-delta.md, `claude-opus-4-8 / 2026-05-28`), this guard is redundant. **Remove** (~1 line).

2. **Phase 1 header prose** (lines 54–55): `"Wall-clock drops from 2-3 min sequential to ~45 sec parallel."` — motivational explanation for parallel spawn. Not a contract; reads as anti-laziness justification. Move intent to a comment or remove. (~2 lines).

3. **Phase 2.3** (lines 173–176): `"Re-read the written file and validate it parses as valid JSON"` with explicit bash. This is procedural scaffolding that exists to prevent silent write failures — legitimate under older models. Under Opus 4.8 this is borderline. **Keep** for now — it's a correctness check with measurable side-effects, not pure motivation.

4. **Error Recovery section** (lines 391–400): 7 named error scenarios with explicit handling. Useful reference content. Not defensive prose — **keep**.

**Content belonging in shared protocol (DRY)**:

- Score formula table in `references/main.md` (§Score Calculation Details) duplicates the per-collector formulas already specified in §Collector Agent Prompt Template and in SKILL.md Phase 1.1 table. Three sources of truth for the same formulas. Consolidate to `references/main.md` §Score Calculation Details as the single source; drop inline formula column from SKILL.md Phase 1.1 and the per-collector fills in §Collector Agent Prompt Template. **~20 lines removable**.

- Dashboard template in `references/main.md` (§Dashboard Markdown Template) duplicates the dashboard structure described in SKILL.md Phase 3.3 (lines 205–260). SKILL.md Phase 3.3 describes structure in prose; references/main.md has the byte-stable template. SKILL.md Phase 3.3 should reference `references/main.md` and omit the duplicate markdown block (~50 lines). Already partly mitigated because Phase 3.3 says "with the following structure" — but the full block is still inline.

**Estimated removable lines (SKILL.md only)**: ~55 (3 defensive lines + 52 from Phase 3.3 dashboard block that duplicates references/main.md template).

---

## D. Modernization

### Native primitive overlap

**`disallowed-tools` frontmatter** (`platform-delta.md` v2.1.152): Safety Rules section (lines 383–389) states "Read-only on source code" and "Non-destructive metrics." These are prose guards. The `disallowed-tools` field could enforce `Edit` and `Delete` lockdown declaratively at frontmatter level, removing the need for prose reminders. **Verdict: delegate** — add `disallowed-tools: [Edit, MultiEdit, Write]` to frontmatter for collector agents (or to the orchestrator's own SKILL.md if Edit is not in `allowed-tools`). Current `allowed-tools: Read, Write, Bash, Glob, Grep, Agent` correctly excludes Edit — the prose guard is already satisfied by allowed-tools. Low priority.

**`/goal` loop** (`platform-delta.md` v2.1.139 / 2026-05-11): Not applicable — quality-metrics is not a loop skill.

**Native workflows** (`platform-delta.md` v2.1.154+): Phase 1 spawns 5 parallel collector agents via `Agent` tool with `run_in_background: false`. Native JS workflow orchestration could replace this fan-out pattern. **Verdict: keep** — Blitz collector agents carry fallback policies, score formulas, and JSON schema contracts that native fan-out doesn't encode. The determinism of `score: null` on tool-absent is business logic that belongs in the prompt. Native workflow fan-out is a transport improvement, not a replacement.

**Model/effort frontmatter**: `model: opus`, `effort: medium`. With Opus 4.8 fast mode ($10/$50 per MTok, `platform-delta.md` `fast-mode-2026-02-01 beta header / 2026-05-28`), orchestrator-side computation (Phases 0, 2, 3, 4, 5) is lightweight JSON manipulation — Sonnet would suffice. Collector agents already specify `model: sonnet` explicitly (Phase 1.2). Recommendation: drop orchestrator to `model: sonnet`, `effort: low`. The orchestrator does no reasoning — it parses mode, spawns agents, merges JSON, writes files. **Top edit.**

**Model IDs** (`platform-delta.md` 2026-05-28): `model: opus` in frontmatter is an alias. No hard breakage but `claude-opus-4-8` is the canonical current ID. Update if model field accepts full IDs (verified alias support in CC ≥2.1.71 per `compatibility` field — alias is fine, low priority).

---

## E. Correctness

**Stale version refs**: `compatibility: ">=2.1.71"` — no newer capability used (Workflow fan-out is optional; skill works without it). No breakage.

**`${SESSION_TMP_DIR}`**: Referenced throughout but never declared/initialized in SKILL.md. `session-protocol.md` defines it — correct by reference. But Phase 1.2 and 1.4 assume it exists before any session-protocol setup completes. Phase 0.0 defers to session-protocol §Session Registration steps 1-9 which creates it. Ordering is correct but implicit — a comment noting "SESSION_TMP_DIR set by session-protocol §3" would prevent confusion.

**`collect-completeness` agent command** (references/main.md): `ls -t docs/metrics/*.json 2>/dev/null | head -1 | xargs jq -r '.scores.completeness // "null"'` — this reads from `docs/metrics/` (quality-metrics own output) rather than from a completeness-gate snapshot. If no prior quality-metrics run exists, `jq` returns null (correct). If a prior run existed but had null completeness, returns "null" string — the `// "null"` coercion produces a string, not JSON null. Minor type bug: downstream JSON merging will see `"null"` (string) vs `null`. Low severity but correctness gap.

**Snapshot immutability rule** (line 386): "append a counter suffix (`YYYY-MM-DD-2.json`)" — `references/main.md` §Snapshot Filename Conventions says same-session overwrites are allowed. These two rules are consistent. ✓

**`subagents-cannot-spawn-subagents`**: Phase 1.2 spawns agents from the orchestrator (slash-invoked skill = top-level). Not a violation. Dynamic Workflows (`platform-delta.md` v2.1.154+) do not change this — skill is already correct.

**Dead flags/env vars**: None found.

**`quality-matrix.md` gap**: Matrix lists 7 quality skills but omits `quality-metrics`. Not a correctness bug in this SKILL.md, but the matrix (`skills/_shared/quality-matrix.md` line 17–28) should include it. Out of scope for this file's edits.

---

## F. Verdict

**`needs-tightening`**

No true duplication with another skill. Architecture is sound. Two actionable issues:

### Top edits (highest leverage)

1. **Drop orchestrator model to `sonnet` + `effort: low`**: Orchestrator does JSON merge + file writes only; workers already specify `model: sonnet`. Opus overhead is wasted cost. Change `model: opus` → `model: sonnet`, `effort: medium` → `effort: low` in SKILL.md frontmatter.

2. **Collapse Phase 3.3 inline dashboard block to reference**: Replace the ~50-line markdown template in SKILL.md Phase 3.3 with `See references/main.md §Dashboard Markdown Template`. Template already lives in references; inline copy is drift risk. (~50 lines removed from SKILL.md).

3. **Fix `collect-completeness` string/null type bug**: Change `jq -r '.scores.completeness // "null"'` → `jq '.scores.completeness'` (drop `-r`, let jq output native `null`). One-line fix in references/main.md §Collector Agent Prompt Template per-collector parameter fills.
