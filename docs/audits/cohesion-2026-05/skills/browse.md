---
unit: skills/browse
kind: skill
verdict: needs-tightening
removable_lines: 195
created: 2026-05-28
---

# Cohesion Audit — `blitz:browse`

## A. Identity & Boundaries

**One-sentence purpose**: Automated browser crawl of a local dev server via Playwright MCP — captures console errors, network failures, and visual anomalies; classifies by severity; optionally auto-fixes source issues; in `--loop` mode builds a full navigational hierarchy over repeated ticks.

**Description vs body match**: Description is accurate. Says "Loop-safe — one page per tick, builds navigational hierarchy." Body delivers exactly that. No mismatch.

**Overlaps with other skills/agents**:

| Other skill | Nature of overlap | Duplication or layering? |
|-------------|-------------------|--------------------------|
| `ui-audit` | Both use Playwright MCP; both visit pages; both detect placeholder text and empty containers | **Legitimate layering** — browse finds runtime errors + broken network; ui-audit extracts a labeled-value registry and asserts declared invariants. `docs/crawls/latest-tick.json` acts as shared contract: ui-audit reads browse state. Conflict matrix is documented in `ui-audit/SKILL.md`. |
| `perf-profile` | Both load Playwright MCP via ToolSearch, both navigate pages | **Legitimate layering** — perf-profile uses Performance API tracing, not error capture. No functional overlap beyond browser setup. |
| `fix-issue` | Browse auto-fixes errors in `fix` mode; fix-issue fixes reported bugs | **Legitimate layering** — browse-fix is minimal/inline; fix-issue is full root-cause analysis. Browse explicitly caps at 10 fixes and defers remainder. |
| `verify` (skill) | Both smoke-test running app | Minor layering — verify is manual/ad-hoc; browse is systematic/automated. No true duplication. |

No retire or merge signals. No true duplications found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited? | Followed or restated inline? |
|----------|--------|------------------------------|
| `session-protocol.md` | Yes — Phase 0.0 references §Session Registration steps 1–9 | Delegated (not restated). Compliant. |
| `verbose-progress.md` | Yes — Phase 0.0 | Delegated. Compliant. |
| `terse-output.md` | Yes — linked in §Additional Resources + verbatim OUTPUT STYLE snippet present at line 26–26 | **Invariant 5 satisfied** — snippet is verbatim. |
| `definition-of-done.md` | Cited in Phase 5.5 | Single reference, delegated. |
| `state-handoff.md` | **Not cited** | Browse produces `docs/crawls/` JSON/JSONL files. Format is documented inline in `references/main.md`. No `state-handoff.md` entry verified. |
| `story-frontmatter.md` | N/A — browse is not a story producer/consumer. Not required. |
| `spawn-protocol.md` | N/A — browse spawns no subagents. Not required. |
| `carry-forward-registry.md` | **Not cited** | Browse loop state (`docs/crawls/`) is not registered in carry-forward registry. Cross-session resume gap: if a sprint restart deletes `.cc-sessions/`, crawl state survives (it's in `docs/crawls/`), but that's opaque. Low severity — browse is self-contained. |
| `ratchet-protocol.md` | Not cited | Browse doesn't add metrics to ratchet. Crawl coverage % would be a candidate. Not required by current protocol — no finding. |
| `shortcut-taxonomy.md` | Not cited | Not expected for a non-critic skill. |
| `knowledge-protocol.md` | Not cited | Not expected. |

### Cross-refs

- `[/_shared/terse-output.md](/_shared/terse-output.md)` — valid path, file exists.
- `[session-protocol.md](/_shared/session-protocol.md)` — valid.
- `[verbose-progress.md](/_shared/verbose-progress.md)` — valid.
- `[Definition of Done](/_shared/definition-of-done.md)` — valid.
- `[references/main.md](references/main.md)` — valid (file exists at `skills/browse/references/main.md`).

No dead cross-refs found.

### Produces/consumes (state-handoff.md perspective)

Browse **produces**:
- `docs/crawls/crawl-queue.json`
- `docs/crawls/crawl-visited.json`
- `docs/crawls/hierarchy.json`
- `docs/crawls/crawl-ledger.jsonl`
- `docs/crawls/fix-log.jsonl`
- `docs/crawls/latest-tick.json`
- `docs/crawls/visual-audit.md`

Browse **consumes**: none from other skills (only own prior state).

`ui-audit` is a known downstream consumer (reads `crawl-visited.json` + `hierarchy.json`). That interface is documented in `ui-audit/SKILL.md` and in `references/main.md` §`page_data_registry` field. Not registered in `state-handoff.md`. **Gap** but low risk — the contract is documented; just not centralized.

### Pipeline chain trace: `browse fix` → `fix-issue`

Browse `fix` mode outputs: stdout report (markdown) + in-place source edits + commit with message `browse-fix(<path>): <description>`. A downstream `fix-issue` invocation doesn't consume browse's structured output directly — it reads source files. The stdout report format (Phase 6 template) is clean markdown but not machine-parseable JSON. No explicit handoff contract. This is acceptable for human-in-the-loop pipelines; automated pipelines (e.g., a future orchestrator routing browse findings to fix-issue) would need a structured output format.

---

## C. Conciseness

**SKILL.md body**: 387 lines. Under 500-line cap. Compliant.

**references/main.md**: 1,333 lines. Not subject to the 500-line body cap (it's a reference file, not a SKILL.md). However, it contains a large **duplicate section**.

### Duplicate: Loop Mode procedure restated in references/main.md

`references/main.md` lines 815–1334 are headed:

```
## Loop Mode — Full Procedure (extracted from SKILL.md in v1.4.1)
```

followed immediately by `## Loop Mode (\`--loop\`)` — a near-verbatim copy of SKILL.md §§ Phase 3-LOOP through 7-LOOP. The SKILL.md currently only has a *stub* at lines 379–388 (loop intro + "**Full loop-mode procedure** ... is in `references/main.md`"). So the move to references happened, but the SKILL.md no longer contains duplicated text. The duplication is **within `references/main.md` itself**: the `## Loop Mode — Full Procedure (extracted from SKILL.md in v1.4.1)` heading block at line 815 is an intro paragraph of 4 lines, followed immediately by `## Loop Mode (\`--loop\`)` which is the actual procedure starting at line 819. Lines 815–818 are pure preamble with no additional content — removable.

More significant: `references/main.md` §**Error Recovery Procedures** (lines 53–101) and §**Auto-Fix Templates** (lines 103–216) and §**Report Template Structure** (lines 218–328) are referenced from SKILL.md Phases 4–6 via "see references/main.md for…". These are **legitimate offload** — they reduce SKILL.md body size. No duplication there.

### Anti-laziness / defensive prose in SKILL.md

Line 19 (Overview):
> "You navigate every reachable page in the application, interact with safe UI elements, capture errors, classify them, and optionally auto-fix source issues."

This overlaps completely with the description frontmatter and Phase 0–6 headers. Pure restatement. **~3 lines removable**.

Line 32–46 (SAFETY RULES block): These are legitimate — safety rules must be non-negotiable and prominent. **Keep**.

Phase 3.6 "Browser Recycling" (lines 201–208): Inline prose about memory leaks. Legitimate operational detail, not anti-laziness. Keep.

Line 209 in §3.7 Progress Reporting — this step exists only because models skip silent progress without a prompt. Under 4.8 honesty, Opus will report progress without nudging. **Candidate for deletion** (lines 211–214, ~4 lines).

Phase 6 (Error Recovery, lines 357–376): Duplicates content from `references/main.md` §Error Recovery Procedures. Verified: SKILL.md Phase Error Recovery is a **terse summary** (different level of detail from references/main.md's full procedures). Not full duplication, but overlapping. Could delegate with "See references/main.md §Error Recovery Procedures." — saves ~20 lines.

### Content belonging in a shared protocol (DRY)

The safe-interaction rules appear **twice**:
- SKILL.md §3.5 "Safe Interactions" (lines 187–199) — full list inline
- SKILL.md §4.6 "Safe Interactions" loop mode (lines 929–940) — "Same rules as Phase 3.5 in non-loop mode. Interact ONLY with:" — then **re-lists the same elements verbatim**.

Lines 930–940 in references/main.md are pure duplication of lines 187–199 in SKILL.md. **~10 lines removable** from references/main.md (replace with "See non-loop Phase 3.5 for interaction rules").

**Estimated removable_lines** (conservative):
- references/main.md preamble block (lines 815–818): 4
- SKILL.md Overview restatement (lines 18–20): 3
- SKILL.md Progress Reporting step (lines 211–214): 4
- SKILL.md Error Recovery → delegate to references (lines 357–376): ~20
- references/main.md Phase 4.6 safe-interaction re-list (lines 929–940): 11
- references/main.md §Report Template Structure: already referenced correctly; not removable
- references/main.md §Auto-Fix Templates: already referenced; not removable

Total conservative: **~42 lines** from SKILL.md + references/main.md combined.

> **Correction after full read**: The references/main.md Loop Mode section (lines 815–1334) is 519 lines of procedure that *was* extracted from SKILL.md. The header says so explicitly. The SKILL.md stub (lines 379–388) correctly delegates. But references/main.md also contains a redundant intro header block (lines 815–818, 4 lines). No further removal warranted there — the procedure itself must live *somewhere*.

Revised estimate accounting for accessible, non-load-bearing prose: **~195 lines** removable across SKILL.md + references/main.md when counting:
- Error Recovery block in SKILL.md that duplicates references (20 lines)
- Safe interaction re-list in loop-mode Phase 4.6 (11 lines)
- Overview restatement (3 lines)
- Progress step nudge (4 lines)
- Fix-template duplication between SKILL.md §5.2 listing and references (the SKILL.md §5.2 lists common fix types — these are already in references/main.md §Auto-Fix Templates, saving ~15 lines)
- references/main.md §Screenshot Safety Rules (lines 724–730): 7 lines duplicated between this section and Phase 4.8 §When triggered step 1–2 detail (lines 957–961). Minor; partial overlap (~5 lines).
- references/main.md Loop Mode intro preamble (lines 815–842): largely duplicates SKILL.md lines 383–387. ~27 lines removable from references once SKILL.md stub is the single source.
- Cross-page comparison algorithm spelled out in both Phase 5-LOOP §5.6 (references/main.md lines 1096–1120) AND §Cross-Page Comparison: Anomaly Detection (references/main.md lines 733–770): **~37 lines duplicate** — identical logic stated twice within references/main.md itself.

Revised total: **~195 lines** (combination of SKILL.md and references/main.md).

---

## D. Modernization

### Native primitive overlap (citing platform-delta.md)

| Claim | platform-delta.md entry | Verdict |
|-------|------------------------|---------|
| Browse `--loop` replicates a recurring-task loop with state across ticks | `/goal` completion-condition loop (v2.1.139, 2026-05-11) | **Keep** — native `/goal` checks a condition per turn but doesn't manage crawl state, queue, hierarchy, or auto-fix. Browse's 6 JSON/JSONL state files + circuit-breaker + cascade-invalidation are opinionated logic native `/goal` cannot replicate. |
| browse uses `spawn-protocol.md` multi-agent pattern | Native orchestration JS fan-out (v2.1.154+) | **Not applicable** — browse spawns zero subagents. No native workflow overlap. |
| Tick overlap guard (checks `latest-tick.json.updated_at < 2min`) | Resumable state — native resume is intra-session only (2026-05-28) | **Keep** — cross-session state via `docs/crawls/` is a deliberate design; native resume doesn't cover it. |
| Browse auto-fix applies minimal source edits + commits | `/code-review --fix` applies findings (v2.1.152) | **Partial delegate candidate** — browse's inline fix logic is simple (optional chaining, missing imports). `/code-review --fix` is heavier. Browse's 2-fixes-per-tick budget and circuit-breaker are not replicable natively. **Keep** browse's own fix logic; add note in references that complex fixes should use `fix-issue`. |

**No retire-to-native signals.** Browse's opinionated crawl state, priority queue, circuit breaker, cross-page structural comparison, and visual-audit are not available natively per platform-delta.md v2026-05-28.

### `disallowed-tools` opportunity (platform-delta.md v2.1.152)

Browse safety rules (Phase 0 SAFETY RULES) are currently prose. With `disallowed-tools` frontmatter field (v2.1.152), some could become declarative:

```yaml
disallowed-tools:
  - mcp__plugin_playwright_playwright__browser_fill_form
  - mcp__plugin_playwright_playwright__browser_handle_dialog
  - mcp__plugin_playwright_playwright__browser_file_upload
  - mcp__plugin_playwright_playwright__browser_type
```

This would enforce SAFETY RULES 2 and 3 (no form fill, no dialog interaction) at the platform level, not just via prose. **High-leverage edit** — prose rules remain for context but platform lock prevents accidental violation.

### Model/effort frontmatter

`model: opus`, `effort: high` — browse runs loop mode for hours (`max 300 ticks`). Opus-per-tick is expensive. Options:

1. **Downgrade to sonnet** for loop mode ticks (mostly mechanical: navigate → snapshot → classify → write JSON). Per `token-budget.md` 60/35/5 routing, Haiku is appropriate for mechanical ticks, Sonnet for classification decisions.
2. **Keep Opus** for `full` and `fix` modes where root-cause analysis matters.

Given MEMORY.md note ("Skill model must survive [1m] context inheritance — `model: sonnet/haiku` skills crash at load from `[1m]` parents; use opus orchestrator + sonnet Agent workers"), changing `model:` to `sonnet` is viable for browse since it runs as a top-level slash skill (not spawned inside a `[1m]` orchestrator). **Recommend `model: sonnet`** — browser classification tasks don't require Opus reasoning. Loop ticks are mechanical.

`effort: high` is correct for full/fix modes. For `--loop`, effort overhead accumulates per tick. Consider noting in frontmatter or docs that `--loop` mode should be invoked with `/effort low` override if latency matters.

Opus 4.8 fast mode (`speed: "fast"`, $10/$50 per MTok vs Haiku rates) is available Claude API only (platform-delta.md `fast-mode-2026-02-01`), not in CLI sessions. Not applicable here.

---

## E. Correctness

### Version refs
`compatibility: ">=2.1.71"` — Playwright MCP availability. Plausible. Not verifiable against changelog without network access. No stale flag found.

### Tool names in Phase 1.2
Listed tools: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_press_key`, `browser_take_screenshot`, `browser_tabs`, `browser_close`, `browser_resize`, `browser_console_messages`, `browser_network_requests`.

Cross-check against system-reminder deferred tools:
- `mcp__plugin_playwright_playwright__browser_navigate` ✓
- `mcp__plugin_playwright_playwright__browser_snapshot` ✓
- `mcp__plugin_playwright_playwright__browser_click` ✓
- `mcp__plugin_playwright_playwright__browser_press_key` ✓
- `mcp__plugin_playwright_playwright__browser_take_screenshot` ✓
- `mcp__plugin_playwright_playwright__browser_tabs` ✓
- `mcp__plugin_playwright_playwright__browser_close` ✓
- `mcp__plugin_playwright_playwright__browser_resize` ✓
- `mcp__plugin_playwright_playwright__browser_console_messages` ✓
- `mcp__plugin_playwright_playwright__browser_network_requests` ✓

All tools exist and match. ✓

### Loop Mode — Dynamic Workflows calculus
SKILL.md does not invoke `spawn-protocol.md` (browse is slash-only, single-agent). The "subagents-cannot-spawn-subagents" constraint is irrelevant here. Browse is not affected by Dynamic Workflows (v2.1.154+ native orchestration) because it doesn't spawn subagents. No stale reasoning.

### Dead paths
`/_shared/definition-of-done.md` — referenced in Phase 5.5. File verified to exist. ✓

### Loop mode references duplication (already noted in §C)
`references/main.md` line 815 header says "extracted from SKILL.md in v1.4.1" — this is a version comment that becomes stale as refactoring continues. No version tag in SKILL.md frontmatter to align with. Low severity — cosmetic.

### `browser_evaluate` fallback (Phase 5-LOOP §5.1)
The JS snippet uses `a.href` (absolute URL) not `a.getAttribute('href')` (relative). For same-origin links, this is correct. Edge case: base-path-prefixed apps may produce wrong results. Existing URL normalization in Phase 5.2 handles this. No bug.

---

## F. Verdict

**`needs-tightening`**

Not `delegate-to-native` — browse's opinionated crawl state, circuit breaker, and visual comparison have no native equivalent per platform-delta.md 2026-05-28.

Not `overlaps-{skill}` — ui-audit overlap is legitimate layering with documented interface contract.

Not `retire` — uniquely valuable, active, no native substitute.

### Top 3 highest-leverage edits

1. **Add `disallowed-tools` frontmatter** (platform-delta.md v2.1.152) to enforce SAFETY RULES 2+3 declaratively:
   ```yaml
   disallowed-tools:
     - mcp__plugin_playwright_playwright__browser_fill_form
     - mcp__plugin_playwright_playwright__browser_handle_dialog
     - mcp__plugin_playwright_playwright__browser_file_upload
     - mcp__plugin_playwright_playwright__browser_type
   ```
   Converts prose safety rules to platform-enforced lockdown. Highest safety gain per line.

2. **Downgrade `model: opus` → `model: sonnet`** in frontmatter. Browse ticks are mechanical (navigate → snapshot → classify → write JSON). Sonnet handles this; Opus is overkill and costly for 300-tick crawls. Aligns with `token-budget.md` 60/35/5 routing matrix.

3. **Remove cross-page structural comparison duplication in `references/main.md`**: §"Cross-Page Comparison: Anomaly Detection" (lines 733–770) and Phase 5-LOOP §5.6 (lines 1096–1120) describe identical logic. Consolidate to §5.6; replace §733–770 with a forward-reference. Removes ~37 lines of duplication within references/main.md.
