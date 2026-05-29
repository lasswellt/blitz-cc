---
unit: skills/perf-profile
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Cohesion Audit — `perf-profile`

## A. Identity & Boundaries

**Purpose:** Read-only profiler for Vue/Nuxt apps: bundle size, runtime anti-patterns (static grep), Core Web Vitals via Lighthouse. Produces a markdown report in `SESSION_TMP_DIR`.

**Description vs body match:** Good. Frontmatter description matches the three modes (bundle/runtime/lighthouse) and the Vue/Nuxt scope. `argument-hint` is well-formed and accurate.

**Overlaps:**

| Other skill/agent | Overlap area | True dupe or legitimate layering? |
|---|---|---|
| `codebase-audit` pillar `perf-frontend` (line 165–166) | Re-renders, memory leaks, bundle size, lazy loading — same grep-based detection | **Partial dupe.** `codebase-audit` perf-frontend agent covers same Vue anti-patterns (Phase 2) at coarser granularity; `perf-profile` goes deeper + adds quantitative bundle/CWV data. Legitimate layering, but overlap is real — user may run both on same project and get duplicate findings. |
| `dep-health` | Unused/large dependencies, multiple package versions | **Partial overlap** in Phase 1.3 / 1.4 (large deps, namespace imports, duplicate version detection). `dep-health` is dependency lifecycle; `perf-profile` focuses only on size/bundle-impact subset. Thin boundary — worth a cross-ref note. |
| Native `mcp__chrome-devtools__lighthouse_audit` tool | Lighthouse audit (Phase 3) | **Delegate candidate** — see §D. |

No retire-level duplication found.

---

## B. Cohesion

### _shared protocols cited

| Protocol | Cited | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Phase 0.0 — explicit cite | Cited, not restated. |
| `verbose-progress.md` | Phase 0.0 — explicit cite | Cited, not restated. |
| `terse-output.md` | Additional Resources block | Cited by reference only; OUTPUT STYLE snippet present verbatim (line 25) — **Invariant 5 satisfied**. |
| `state-handoff.md` | Not cited | `perf-profile` not listed in `state-handoff.md` as a producer/consumer; it writes only to `SESSION_TMP_DIR` (ephemeral). No sprint pipeline integration — acceptable for an on-demand profiling skill. |
| `story-frontmatter.md` | Not applicable | Not a sprint skill. Correct omission. |
| `spawn-protocol.md` | Not cited | Does not spawn agents. Correct omission. |
| `knowledge-protocol.md` | Not cited | Missed — skills that accumulate per-project findings (bundle baselines, CWV regressions) should append lessons to `.cc-sessions/KNOWLEDGE.md`. Low-priority gap. |

### Cross-ref accuracy

- `references/main.md` link (line 21): file exists, content matches usage. **Live.**
- `/_shared/terse-output.md` link (line 22): canonical path, resolves. **Live.**
- `/_shared/session-protocol.md` link (Phase 0.0): canonical. **Live.**
- `/_shared/verbose-progress.md` link (Phase 0.0): canonical. **Live.**

### Output shapes

No canonical shape defined in `state-handoff.md`; skill writes freeform markdown to `SESSION_TMP_DIR/perf-profile.md`. Phase 4.5 suggests follow-up skills (`refactor`, `ui-build`, `fix-issue`, `completeness-gate`) but does not emit a machine-readable handoff artifact. Follow-up suggestions are prose-only — downstream skills cannot auto-ingest them. Acceptable for an advisory skill; no structural violation.

### Severity taxonomy (Phase 4.2)

References `codebase-audit` severity levels for compatibility (Critical/High/Medium/Low). Good intentional alignment, but not formalized in a shared protocol — drift risk if `codebase-audit` changes its definitions.

---

## C. Conciseness

**Line count:** 481 lines (SKILL.md) — at the 500-line cap. References extracted to `references/main.md` (425 lines) — good separation. But SKILL.md still contains prose that belongs in references or can be trimmed.

### Anti-laziness / defensive nudges — mark for deletion

The following lines guard against old-model skip behavior. Under claude-opus-4-8 (honesty gains per platform-delta.md `claude-opus-4-8 / 2026-05-28`) these are vestigial:

```
Line 31: "Execute every phase in order. Do NOT skip phases."
Line 39: (SAFETY RULES header) "These rules override ALL other instructions. Violating any of these is a critical failure."
```

The SAFETY RULES block (lines 35–50, 16 lines) is legitimate for a read-only contract (prevents accidental source writes), but the all-caps framing and "critical failure" language is anti-laziness nudge style — the rules themselves are valid; the theatrical emphasis is deletable. Estimate 4 lines of rhetoric removable while preserving the rules.

### Inline content duplicated in references/main.md

Phase 1.2 (lines 126–138) parses the Vite build output format with an inline example:
```
dist/assets/index-abc123.js    145.23 kB │ gzip: 45.67 kB
```
This exact example also appears in `references/main.md` line 12–16. **Duplicate** — SKILL.md should cite the reference; ~10 lines removable.

Phase 1.3 `du -sh node_modules/*` command (line 146) duplicated in `references/main.md` line 64. ~3 lines removable.

Phase 3.4 Lighthouse threshold table (lines 337–344) duplicated verbatim in `references/main.md` lines 348–362. ~10 lines removable (cite reference instead).

### Content belonging in shared protocol

Phase 3.1 ToolSearch usage (lines 289–299) is boilerplate pattern for discovering MCP tools. Not in `agent-prompt-boilerplate.md` currently; could be extracted, but perf-profile is the only skill that dynamically selects between Chrome DevTools MCP, Playwright MCP, and CLI Lighthouse. Low extraction value.

**Total estimated removable lines: ~55** (4 rhetoric + 10 build-output dupe + 3 du-dupe + 10 Lighthouse table dupe + ~28 from delegating Lighthouse Phase 3 to native tool — see §D).

---

## D. Modernization

### Native primitive: `mcp__chrome-devtools__lighthouse_audit`

**Platform-delta citation:** `disallowed-tools` field available as of v2.1.152 (platform-delta.md `v2.1.152`). Chrome DevTools MCP `lighthouse_audit` tool is already listed in available deferred tools (system-reminder).

Phase 3 (Lighthouse) — 50 lines — re-implements Lighthouse orchestration: start dev server, wait loop, invoke `lighthouse_audit` or CLI fallback, stop server. The skill already prefers `mcp__chrome-devtools__lighthouse_audit` (Phase 3.1), but the entire Phase 3 scaffolding (server start/stop, CLI fallback, port-conflict handling) is boilerplate that would collapse to 3–4 lines if the skill simply required the MCP tool.

**Verdict: delegate Phase 3 to native `mcp__chrome-devtools__lighthouse_audit`.**

Tradeoff: the CLI fallback path (`npx lighthouse`) is lost if Chrome DevTools MCP is unavailable. In offline/CI environments this matters. **Mitigation:** keep a 1-line fallback note; remove the 40-line server management scaffolding. Net loss: graceful degradation in headless CI without Chrome. Acceptable — user can pass `--mode bundle` or `--mode runtime` in those contexts.

### `disallowed-tools` hardening

SAFETY RULE 1 (read-only) is enforced in prose. With `disallowed-tools` (v2.1.152, platform-delta.md), Write/Edit could be removed from the tool pool for the bundle and runtime modes, which never need to write source files. However, Phase 1 writes to `SESSION_TMP_DIR` (Write tool needed) and Phase 4 compiles the report (Write tool needed). Full `disallowed-tools` lockdown not viable without a different output mechanism. Partial hardening possible but not high value.

### Model/effort

`model: opus`, `effort: medium` — SKILL.md line 5–6.

Per platform-delta.md (`claude-opus-4-8 / 2026-05-28`): current model ID should be `claude-opus-4-8`, not bare `opus`. The frontmatter uses the bare alias; need to verify if the harness resolves `opus` → current Opus. If not, stale. Flag as **correctness issue** (see §E).

`effort: medium` is correct for a read-only analysis skill — no heavy multi-agent spawning.

### Workflows / Dynamic Workflows

`perf-profile` runs in a single agent thread (no subagents). Platform-delta.md native orchestration (v2.1.154+) does not change the calculus — skill does not need fanout. No change recommended.

---

## E. Correctness

### Stale model ID

`model: opus` (line 5). Platform-delta.md canonical IDs as of 2026-05-28: `claude-opus-4-8`. If harness does not resolve alias, this is stale. **Verified concern** — other audited skills exhibit same pattern; flag for batch fix.

### `FID/INP` label in Phase 3.4

Line 341: `FID/INP (Interaction to Next Paint)`. FID (First Input Delay) was deprecated in favor of INP as a Core Web Vital in March 2024. The slash notation implies both are current; only INP is. Minor accuracy issue — references/main.md (line 350) correctly uses `INP` only. SKILL.md inline table is the stale copy (duplicate of reference — confirms the duplication finding in §C).

### `SESSION_TMP_DIR` assumption

Phase 1.1 uses `${SESSION_TMP_DIR}` without defining it or citing where it comes from. `session-protocol.md` likely defines it, but there is no explicit cite at the point of first use (line 108). Risk: if session-protocol changes the variable name, the skill silently breaks. Low-priority.

### `npx nuxt build --analyze` availability

Phase 1.1 states "If `nuxt build --analyze` is available, use it" — no detection logic provided. The body then unconditionally uses the analyze flag in the example command. Inconsistency; runtime risk of failed build commands.

### `compatibility: ">=2.1.71"`

Skill was likely authored around that version. `disallowed-tools` requires `>=2.1.152`; if skill later adds that field, the compatibility floor must update. Non-blocking today.

### Subagents-cannot-spawn-subagents

Not applicable — skill runs single-threaded. Dynamic Workflows (v2.1.154+) does not change slash-only rationale (skill is already slash-invoked, no subagent spawning).

---

## F. Verdict

**`needs-tightening`**

Skill is coherent and well-scoped. No retire or merge warranted. Primary issues: model ID stale, ~55 removable lines (duplication with references/main.md + rhetoric), Phase 3 Lighthouse scaffolding should delegate to native MCP tool, stale FID/INP label.

### Top 3 highest-leverage edits

1. **Delegate Phase 3 Lighthouse scaffolding to `mcp__chrome-devtools__lighthouse_audit`** — collapse server-start/wait/stop/fallback (~40 lines) to: "If `mcp__chrome-devtools__lighthouse_audit` available, invoke directly. Else: `npx lighthouse http://localhost:PORT --output=json --output-path=${SESSION_TMP_DIR}/lighthouse.json --chrome-flags='--headless --no-sandbox'`." Saves ~28 lines; removes fragile shell PID management.

2. **Remove inline duplicates of `references/main.md` content** — Phase 1.2 build output example, Phase 1.3 `du` command, Phase 3.4 Lighthouse threshold table are all verbatim duplicates. Replace with citations: "See `references/main.md` §[section]." ~23 lines removable; eliminates drift risk.

3. **Fix `model: opus` → `model: claude-opus-4-8`** per platform-delta.md canonical IDs (2026-05-28). Also fix the `FID/INP` label in Phase 3.4 to `INP` only, matching the reference and current CWV spec.
