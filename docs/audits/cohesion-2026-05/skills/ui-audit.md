---
unit: skills/ui-audit
kind: skill
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# ui-audit — Cohesion + Modernization Audit

## A. Identity & Boundaries

**One-sentence purpose:** Cross-page semantic consistency + data-quality + UI/UX heuristic auditor that extracts a labeled value registry, asserts declared invariants, and detects placeholder/flapping/role-leak issues — read-only on the target app.

**Description vs body match:** Good. Description ("Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts a labeled value registry, asserts cross-page invariants...") is accurate and concise. 183 chars — well within 1024. Body covers all modes claimed.

**Overlapping skills:**

| Skill | Overlap kind | Verdict |
|---|---|---|
| `browse` | Both use Playwright MCP to crawl pages; `browse` also captures console errors, screenshots, and visual analysis | **Legitimate layering** — `browse` is navigation + error capture; `ui-audit` is semantic value extraction + invariants. `ui-audit` Phase 1 explicitly reads browse-produced artifacts (`docs/crawls/crawl-visited.json`, `hierarchy.json`) and warns on concurrent run. They compose, not duplicate. |
| `ui-build` | Shares Vercel heuristic vocabulary (Cat 9, Cat 16) | **Legitimate** — `ui-build` produces; `ui-audit` validates. |

No true duplication found.

---

## B. Cohesion

### _shared protocols cited and followed

| Protocol | Cited? | Followed / Inline-drift? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0, §0.3 conflict matrix) | Followed — Phase 0.0 delegates to it verbatim. |
| `verbose-progress.md` | Yes (Phase 0.0) | Followed — activity-feed events are well-specified throughout. |
| `terse-output.md` | Yes (Additional Resources + OUTPUT STYLE block) | OUTPUT STYLE block present and verbatim. **Invariant 5 satisfied.** |
| `spawn-protocol.md` | Yes (Phase 5.2 comment) | Partially followed — Phase 5.2 spawn snippet cites `model: "sonnet"` as load-bearing (feedback_skill_model_1m_inheritance.md). No drift. |
| `token-budget.md` | Not cited | **Gap** — skill spawns agents in Phase 5.2 but does not reference `token-budget.md` for worker routing. The spawn cap (10 focus probes, 10 clicks, >30 page threshold) is declared inline rather than in a shared budget policy. Low risk: all caps are mode-specific and well-commented. |
| `agent-routing.md` | Not cited | Not required for slash-only skill. Acceptable. |

### Cross-refs live + accurate

- `references/main.md` — file exists, complete. ✓
- `references/checks.md` — file exists, complete. ✓
- `references/patterns.md` — file exists but header states "SKELETON — populated in E-009 (CAP-012)". Two categories implemented (Cat 9, Cat 16); remaining categories marked TODO. References within SKILL.md point to `references/patterns.md` correctly — consumers see the right file, though it's incomplete by design.
- `/_shared/session-protocol.md` — path valid. ✓
- `/_shared/verbose-progress.md` — path valid. ✓
- `/_shared/terse-output.md` — path valid. ✓
- `.ui-audit.json.example` — referenced in Phase 0.2 error messages; file existence not verifiable from this audit but error messages point to repo root. No other audit flags this as broken.

### Produces / consumes per state-handoff.md

Verified: `docs/crawls/page-data-registry.jsonl` (JSONL append-only), `docs/crawls/ui-audit-report.md`, `docs/crawls/latest-tick.json` (extends `ui_audit_matrix` block set by `browse`). Consumes `docs/crawls/crawl-visited.json` + `docs/crawls/hierarchy.json` from `browse`. No invented shapes that conflict with `state-handoff.md` — shapes are well-documented in `references/main.md §Schemas`.

### Invariant 5 (OUTPUT STYLE)

Present verbatim in SKILL.md lines 30–30. Agent spawn snippet in `references/main.md §5.2` also contains OUTPUT STYLE block. ✓

### Pipeline chain trace (full mode → sprint-review)

`blitz:ui-audit full` → writes `docs/crawls/ui-audit-report.md` + `docs/crawls/page-data-registry.jsonl`. Neither is declared as an input in `state-handoff.md` for any downstream sprint skill. `blitz:sprint-review` does not consume ui-audit outputs. The skill is a standalone QA tool, not a pipeline step — this is correct by design and consistent with its read-only scope.

---

## C. Conciseness

**SKILL.md body:** 175 lines — well under 500-line cap. ✓

**references/main.md:** 1,566 lines. This is a reference/implementation document, not a SKILL.md body, so the 500-line cap does not apply. Correctly separated.

**Defensive prose / anti-laziness nudges (candidates for deletion given 4.8 honesty gains):**

1. `references/main.md` § Phase 1 § 1.2, line 92:
   ```
   If any of 6 tools missing, print `[ui-audit] Playwright MCP tools unavailable...` and exit 1.
   ```
   The "6 tools" count is load-bearing. Keep.

2. `references/main.md` § Phase INTERACTIVE § I.4, last sentence:
   > "If `ok === false` (element gone between enumeration + probe — shadow-DOM timing, route transition) → `focus_probe_element_gone` INFO."
   This documents a legitimate edge case. Keep.

3. `references/main.md` § Phase 5 § 5.2, comment block:
   ```
   `model: "sonnet"` is LOAD-BEARING — omitting re-introduces `[1m]` context crash (see feedback_skill_model_1m_inheritance.md). See spawn-protocol.md §7 for OUTPUT STYLE snippet.
   ```
   This is a knowledge-protocol note compensating for a platform-era footgun (pre-4.8 model inheritance bug). Under Opus 4.8 honesty improvements (platform-delta.md / 2026-05-28), this risk is reduced but the explicit `model:` in Agent() calls is still best practice. **Mark for trimming** — keep `model: "sonnet"` in spawn snippet but reduce the comment to a single inline note. ~4 lines removable.

4. `references/main.md` § Phase 3 § 3.1 + § 3.2 + § 3F.1: The `select` filter exclude list (`label != "quality_flag" and ...`) is repeated verbatim 4 times across the file. Guard-rail comment in `§ 3.1` says "Canonical exclude set (sync with § 4.2 + Shared-templates reducer)". This is a DRY violation — ~30 redundant lines. Should be extracted to a named shell variable or function, or collapsed to a single "Shared templates" reference. The `Shared-templates` section at bottom of `main.md` already has the canonical reducer but it's not cited back. **~30 lines removable via dedup.**

5. `SKILL.md` Phase 0.1, argument table rows for `--yes` and `--ci` both end with:
   > "Equivalent except for audit trail: `--ci` writes one `ci_run` activity-feed event at start."
   This note appears in both SKILL.md (inline under R10) and `references/main.md §7.2`. ~5 lines redundant across the two files; single canonical location (main.md §7.2) is sufficient. **~5 lines removable from SKILL.md.**

6. `references/checks.md` header:
   > "**SKELETON — populated in E-009 (CAP-011) — DO NOT treat as shipping checklist.**"
   All 6 quality flags are now implemented (Phase 2 + Phase 4). Header is stale. **Delete skeleton banner — ~4 lines.**

7. `references/patterns.md` header:
   > "**SKELETON — populated in E-009 (CAP-012) — DO NOT treat as shipping checklist.**"
   Two categories implemented; remaining are TODO. Banner partially accurate but the "DO NOT treat as shipping checklist" clause is overly defensive for a delivered feature. **Trim to a targeted TODO note — ~4 lines.**

**Content belonging in shared protocols:** The ReDoS guard pattern (`/\([^)]*[+*][^)]*\)[+*]/`) in Phase 2 §2.4 is inline. If other skills accept user-supplied regex, this belongs in a shared security helper. Currently only ui-audit uses user regexes — acceptable inline for now.

**Estimated removable lines (SKILL.md + references combined):** ~55 lines (30 reducer dedup + 5 --ci note + 4 checks.md banner + 4 patterns.md banner + 4 spawn comment trim + smaller cleanups).

---

## D. Modernization

### Native primitive overlap (platform-delta.md citations)

| Claim | platform-delta.md version | Keep/Delegate/Retire | Tradeoff |
|---|---|---|---|
| Phase 5.2 parallel agent spawn for >30-page runs | v2.1.154+ / 2026-05-28 (Native orchestration via JS workflows) | **Keep** — native workflows require `workflow` in prompt or `/effort ultracode`; ui-audit spawns agents conditionally based on page count with specific prompt-injection defenses (delimiters, content validation). Delegating loses the ReDoS guard, prompt-injection framing, and the `model: "sonnet"` routing. | Determinism of page-count threshold + security framing is lost if delegated. |
| `--loop` + `ScheduleWakeup` pattern | v2.1.139 / `/goal` completion-condition loop | **Keep** — `/goal` is single-condition exit; ui-audit `--loop` manages a `(role × page)` cursor across sessions with 2-pass drift detection. `/goal` cannot resume cross-session (platform-delta.md: "resume limited to same session"). Cross-session resume is the whole point. | Native `/goal` covers simpler cases but gap persists for multi-session audit matrix. |
| Safety Rule 1 destructive-label classifier inline in SKILL.md | v2.1.152 `disallowed-tools` frontmatter field | **Partial delegate** — `disallowed-tools` removes a tool from Claude's pool but cannot gate behavior based on page content (e.g., "don't click buttons labeled Delete"). The classifier is content-aware, not tool-aware. `disallowed-tools` could be used to remove `browser_fill` from the pool to reinforce Rule 2 (never fill forms). Add `disallowed-tools: [browser_fill]` to frontmatter as a declarative backstop. **Low risk of loss.** | |

### `disallowed-tools` opportunity

SKILL.md frontmatter currently sets `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch`. Adding `disallowed-tools: [mcp__plugin_playwright_playwright__browser_fill]` (Playwright `browser_fill`) would make Safety Rule 2 declarative. This is a concrete modernization edit with no tradeoff loss.

### Model/effort frontmatter

```yaml
model: opus
effort: low
```

`model: opus` + `effort: low` is the orchestrator-pairing pattern from feedback. Correct per CLAUDE.md memory note ("orchestrator SKILL.md frontmatter should set `effort: low` alongside `model: opus`"). Opus 4.8 fast mode (`speed: "fast"` API param) is available (platform-delta.md / `fast-mode-2026-02-01` / 2026-05-28) but is Claude API only — not applicable to CLI skill invocations. No change needed.

Model ID `opus` is an alias. Current canonical ID per platform-delta.md (2026-05-28): `claude-opus-4-8`. SKILL.md uses `model: opus` shorthand — acceptable if the platform resolves it, but explicit `claude-opus-4-8` in `token-budget.md` routing matrix is needed (out-of-scope for this skill's own frontmatter).

---

## E. Correctness

**Version refs:** `compatibility: ">=2.1.71"` — no evidence this is stale. Playwright MCP tools used match current tool names (`browser_navigate`, `browser_evaluate`, `browser_snapshot`, `browser_wait_for`, `browser_console_messages`, `browser_network_requests`, `browser_click`). All match `mcp__plugin_playwright_playwright__*` namespace in current deferred tool list. ✓

**Dead flags/env vars:** `CLAUDE_CODE_AUTONOMY` used in Phase 0.1 + §7.2 ETA gate. Listed in hooks context. Valid. `BLITZ_OUTPUT_INTENSITY` in `references/main.md §3I.2` — not validated here; assumed consistent with verbose-progress.md contract.

**Broken paths:** None found. `docs/crawls/` paths consistent across SKILL.md + main.md. `.cc-sessions/activity-feed.jsonl` write in §3I.2 is correct.

**Stale sprint references:** `references/checks.md` and `references/patterns.md` have sprint-6/E-009/CAP-011/CAP-012 skeleton banners. Checks.md content is now implemented (all 6 flags have detection procedures); banner is stale. **Correctness issue: banner tells consumers "DO NOT treat as shipping checklist" for code that is shipped.**

**Subagents-cannot-spawn-subagents:** SKILL.md is slash-only (invokable). Phase 5.2 spawns sub-agents for >30-page heuristics runs. This is valid — ui-audit itself is invoked as a slash-command, not as a sub-agent, so it can spawn sub-agents. Dynamic Workflows (platform-delta.md v2.1.154+) do not change this calculus — the constraint is about sub-agents spawning further sub-agents, not about slash-commands. ✓

**`references/main.md §3I.1` jq — known bug callout:** Comment says "`$src` variable-binding is load-bearing — don't re-introduce sprint-6 filter-arg bug." This is a correctness guard, not anti-laziness prose. Keep.

**Phase ROLE §R.3 scripted login:** `browser_evaluate` is used to set `.value` on input elements and call `.click()` on submit — this bypasses `browser_fill` + `browser_click` tools. Under `disallowed-tools: [browser_fill]`, the `browser_evaluate` path for login would still work. No regression from adding that `disallowed-tools` entry.

---

## F. Verdict

**`needs-tightening`**

Skill is coherent, well-bounded, and correctly layered vs `browse`. No retire/merge candidate. Specific improvements:

### top_edits

1. **Add `disallowed-tools: [mcp__plugin_playwright_playwright__browser_fill]` to SKILL.md frontmatter** — declarative enforcement of Safety Rule 2 (never fill forms) using v2.1.152 `disallowed-tools` field (platform-delta.md). Low risk, zero tradeoff.

2. **Remove stale skeleton banners from `references/checks.md` (line 1–5) and `references/patterns.md` (line 1–6)** — all 6 quality flags are implemented; Phase 4 procedures are complete. Banner actively misleads consumers. Trim to a targeted `<!-- TODO(E-009/CAP-012): remaining heuristic categories -->` note in patterns.md only.

3. **Deduplicate the 4× repeated `select` exclude list in `references/main.md`** — extract to a named shell variable or a `## Shared templates — exclude filter` section and replace inline repetitions with a reference. Saves ~30 lines and eliminates sync-drift risk when a new label type is added.
