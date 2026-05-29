---
unit: skills/doc-gen
kind: skill
verdict: needs-tightening
removable_lines: 90
created: 2026-05-28
---

# doc-gen — Cohesion + Modernization Audit

## A. Identity & Boundaries

**Purpose (one sentence):** Generates API docs, Vue component tables, Mermaid architecture diagrams, and Keep-a-Changelog entries from source code + conventional commits, in five modes (api, components, architecture, changelog, full).

**Description vs body match:** Description is accurate; lists all five modes and trigger phrases. Body delivers exactly what the description promises. No scope creep detected.

**Overlap analysis:**

| Overlap | Skill / Agent | Kind |
|---------|--------------|------|
| Changelog generation from conventional commits | `skills/release` (Phase 3.1) and `skills/ship` (Phase 2) | **True duplication** — all three parse `git log` with identical `feat/fix/refactor/BREAKING CHANGE` mapping and produce Keep-a-Changelog output. `release` writes `CHANGELOG.md` (project artifact); `doc-gen` writes `docs/generated/changelog.md` (documentation artifact). Same data, different destination — thin distinction |
| Architecture diagrams (Mermaid) | `skills/codebase-map` (agent `map-architecture`) | Legitimate layering — `codebase-map` uses architecture as one lens in a multi-dimension codebase snapshot; `doc-gen architecture` is a standalone, repeatable generation target for ongoing maintenance. |
| Import graph / dependency analysis | `skills/codebase-map`, `skills/code-doctor` | Legitimate layering — those skills consume the result for diagnostic purposes; `doc-gen` writes it as documentation for readers. |

**True duplication requiring resolution:** changelog generation is implemented identically across doc-gen / release / ship. No consumer differentiates the three outputs by format; they all follow Keep a Changelog. Recommend extracting a `_shared/changelog-generation.md` protocol or designating `release` as canonical and having `doc-gen changelog` call it.

---

## B. Cohesion

### Cited `_shared` protocols

| Protocol | Cited? | Followed or restated inline? |
|----------|--------|------------------------------|
| `session-protocol.md` | Yes (§0.0, Phase 5.3) | Followed via reference |
| `verbose-progress.md` | Yes (§0.0) | Followed via reference |
| `spawn-protocol.md` | Yes (§3.2) | Followed via reference |
| `terse-output.md` | Yes (cross-ref + OUTPUT STYLE block) | Followed |
| `definition-of-done.md` | Yes (body §intro) | Followed via reference |
| `state-handoff.md` | Not cited | No explicit produce/consume contract declared |
| `story-frontmatter.md` | Not cited | Correct — doc-gen doesn't participate in sprint stories |
| `token-budget.md` | Not cited | Subagent model routing in §3.2 is hardcoded `"sonnet"` without referencing `token-budget.md` routing matrix |

### Cross-refs

All referenced paths (`/_shared/session-protocol.md`, `/_shared/spawn-protocol.md`, `/_shared/verbose-progress.md`, `/_shared/terse-output.md`, `/_shared/definition-of-done.md`) use the canonical `/_shared/` prefix. Path format is correct; no dead links detected (verified by convention, not traversal — `_shared/` files confirmed present in prior audits of this repo).

`references/main.md` is an inline embed (`!cat skills/doc-gen/references/main.md`) — 539 lines of templates and regex patterns. This file is an outlier: no other audited skill uses a `references/` directory of this size. Content is genuinely skill-specific (Vue SFC parsing patterns, Mermaid diagram CSS color palette, Keep a Changelog template). Not a DRY violation.

### Invariant 5 (OUTPUT STYLE)

Present verbatim at line 23 of SKILL.md. Invariant 5 satisfied.

### Pipeline trace (changelog mode)

```
user: /blitz:doc-gen changelog
  → Phase 0: parse mode
  → Phase 1: git log → commit list
  → Phase 2.4: group by conventional prefix
  → Phase 3.3: write docs/generated/changelog.md  ← output shape
  → Phase 4.1: update index.md
  → Phase 5.1: report summary
```

Next skill that might consume `docs/generated/changelog.md`: none declared. `release` reads `CHANGELOG.md` (project root), not `docs/generated/changelog.md`. **Pipeline gap**: the two changelog artifacts are not reconciled — a reader will see two different changelogs in the repo.

---

## C. Conciseness

**Body line count:** 375 (SKILL.md) + 539 (references/main.md) = 914 combined. SKILL.md alone is within the 500-line cap. `references/main.md` is not subject to the cap (it's a reference file, not a SKILL.md). No violation.

**Anti-laziness / defensive prose to delete (Opus 4.8 honesty gains):**

| Lines | Quoted prose | Failure mode it guarded | Verdict |
|-------|-------------|------------------------|---------|
| 29 | `"Execute every phase in order. Do NOT skip phases."` | Old models skipped phases when context got long | Delete — Opus 4.8 honesty + sequential phase numbering is sufficient |
| 199 | `"Never use Explore or rely on SDK heuristics."` | Old models hallucinated tool names | Delete — spawn-protocol.md already specifies `general-purpose` |
| 221 | `"(replaces the previously banned 'write the full document' rule)"` | Rule evolution annotation — not executable instruction | Delete parenthetical — creates confusion about what the current rule is |
| 269 | `"Do NOT silently produce a 'complete' index that includes missing or partial docs without flagging them."` | Old models glossed over failures | Delete — PARTIAL handling in §3.4 already specifies exact behavior |
| 357 | `"This skill only reads source files and writes to docs/generated/. It never modifies application code."` | Trust-building prose for cautious users | Keep — safety rules section is load-bearing for overwrite-protection logic that follows |

Estimated removable lines from SKILL.md: ~8 pure anti-laziness nudges. An additional ~80 lines in `references/main.md` could be trimmed from the Mermaid diagram pattern section (3 of 4 examples are redundant with the architecture template diagram above them). Total removable: ~88 → rounded to 90.

**Content belonging in a shared protocol:** The commit-type-to-section mapping table (references/main.md lines 323-342) duplicates identical tables in `skills/release/SKILL.md` and `skills/ship/SKILL.md`. Belongs in `_shared/changelog-generation.md`.

---

## D. Modernization

### Native primitive overlap

**Claim 1 — Parallel agents (full mode):**  
`full` mode spawns 4 concurrent `Agent()` calls. Native Workflows (platform-delta.md v2.1.154+) support JS-script fan-out across dozens of parallel subagents with intermediate results in script variables. The current 4-agent fan-out is a correct and minimal use — not an overengineered reimplementation. Verdict: **keep**. Tradeoff: native Workflows would reduce context-window pressure from agent coordination, but 4 agents is below any real limit. No action required today.

**Claim 2 — Model routing (`"sonnet"` hardcoded in Phase 3.2):**  
Hardcoded `model: "sonnet"` in agent spawns doesn't account for the `token-budget.md` routing matrix. Model IDs in platform-delta.md (2026-05-28) are `claude-sonnet-4-6` (alias `sonnet`). The alias works, but routing logic is not parameterized. Low risk; no immediate breakage. Verdict: **flag for token-budget.md alignment**.

**Claim 3 — `disallowed-tools` frontmatter:**  
Safety Rules §Non-destructive states the skill never modifies application code. This could be enforced declaratively via `disallowed-tools` (platform-delta.md v2.1.152) rather than relying on prose. Candidate: disallow `Bash` edit commands against `src/` (though this isn't granular enough in current tool model). Verdict: **low ROI** — the non-destructive constraint is path-based (writes only to `docs/generated/`), not tool-based. `disallowed-tools` can't express path restrictions. Skip.

**Claim 4 — Model/effort frontmatter:**  
`model: opus`, `effort: medium`. Per platform-delta.md (fast-mode-2026-02-01 beta), `claude-opus-4-8` fast mode is available at $10/$50 per MTok (vs $30/$150 for older Opus). For a doc-generation task (read source files, emit markdown), fast mode is appropriate. Verdict: **consider `model: opus-fast`** if token-budget.md exposes the alias; currently no evidence it does. Defer to token-budget.md audit.

---

## E. Correctness

**Stale references:** None detected. No hardcoded version numbers or deprecated flags.

**Dead env vars / flags:** `$ARGUMENTS` used without definition — standard Blitz convention, no issue.

**`stat -c %Y` (Phase 1.3):** GNU `stat` syntax; fails on macOS (uses `stat -f %m`). Risk is low for a WSL-based project but not portable. Not a blocking error — just a cross-platform caveat.

**Multi-agent / subagents-cannot-spawn-subagents:**  
`doc-gen` is slash-invoked. It spawns `Agent()` workers in Phase 3.2. This is the correct architecture per `agent-routing.md` — subagents spawned by a slash skill are not subagents spawning subagents. Dynamic Workflows (platform-delta.md v2.1.154+) do not change this calculus for doc-gen: the skill is correctly slash-only, and spawning workers from a slash context is permitted. No change needed.

**Polling approach (Phase 3.4):** Uses `bash` file-existence polling loop with a 5-minute timeout declared in prose but not enforced in the script. Monitor tool (if available) would be more reliable. Minor — not blocking.

---

## F. Verdict

**`needs-tightening`**

True duplication of changelog generation across doc-gen / release / ship is the highest-leverage issue. Everything else is minor.

### Top 3 edits

1. **Extract `_shared/changelog-generation.md`** containing the commit-type-to-section mapping table and Keep-a-Changelog template. Have doc-gen, release, and ship all cite it. Removes ~30 lines from this skill and eliminates the divergence risk.

2. **Delete anti-laziness nudges** at lines 29, 199, 221, 269 (approximately 4–6 lines). Prose is not executed; Opus 4.8 self-corrects. Reduces noise.

3. **Declare state-handoff contract** in Phase 0 or a dedicated header: what `doc-gen` produces (`docs/generated/{api,components,architecture,changelog,index}.md`) and what it consumes (source files via Glob/Grep, git log). Aligns with `state-handoff.md` and makes the pipeline gap with `release` visible to maintainers.
