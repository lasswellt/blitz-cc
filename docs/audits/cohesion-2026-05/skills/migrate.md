---
unit: skills/migrate
kind: skill
verdict: needs-tightening
removable_lines: 45
created: 2026-05-28
---

# Cohesion Audit — `migrate`

## A. Identity & Boundaries

**Purpose:** Incremental framework/library/tooling migration with rollback safety, atomic steps, and per-step verification.

**Description vs body match:** Accurate. Description covers the trigger patterns, the core behavior (research → plan → atomic execute → verify), and the abort-on-failure contract.

**Overlaps:**

| Skill / Agent | Nature |
|---|---|
| `refactor` | Legitimate layering. `refactor` = restructure without behavior change; `migrate` = adopt new external API. Safety rules and atomic-step-with-verify pattern are near-identical (`refactor` §§SAFETY RULES 1-3 mirror `migrate` §§1-7). True duplication in structure, not purpose. |
| `research` | Legitimate layering. Phase 1 spawns inline WebSearch queries; `research` does deeper multi-source fan-out. `migrate` Phase 1.1 notes it is "if WebSearch available" — degenerate fallback path. No true duplication. |
| `fix-issue` | Legitimate layering. Referenced in Phase 6.2 follow-up table when tests fail after migration. Not the same scope. |
| `dep-health` | Minor overlap — both inspect `package.json` and lock files. `dep-health` audits; `migrate` acts. No true duplication. |

No retirable duplication found. `refactor` and `migrate` share structural DNA but have distinct trigger sets and distinct safety semantics (one never changes public APIs; the other must change them by design).

---

## B. Cohesion

### _shared Protocol Citations

| Protocol | Cited | Followed vs Restated |
|---|---|---|
| `session-protocol.md` | Yes — Phase 0.0 | Delegates: "Follow §Session Registration (steps 1-9)" — no inline restatement. |
| `verbose-progress.md` | Yes — Phase 0.0 | Delegates. |
| `terse-output.md` | Yes — OUTPUT STYLE line (line 22) | Verbatim canonical snippet present. Invariant 5 satisfied. |
| `package-install-policy.md` | Yes — Additional Resources block | Delegates. |
| `definition-of-done.md` | Yes — Safety Rule 8 | Delegates. |
| `state-handoff.md` | **Not cited** | `migrate` produces no named state artifact consumed by another sprint-family skill. It operates outside the sprint pipeline. Omission is correct here — no handoff needed. |
| `story-frontmatter.md` | **Not cited** | Same reasoning — standalone skill. Correct omission. |
| `spawn-protocol.md` | **Not cited** | Skill calls `Agent` in `allowed-tools`. Phase 1.1 says "Spawn Research Agent" but instructs direct WebSearch use — no Agent() call in body. The Agent tool entry in `allowed-tools` is stale/unused. See §E. |
| `shortcut-taxonomy.md` | Not cited | Not required for non-autonomous skills; acceptable. |

### OUTPUT STYLE Invariant 5

Line 22 matches canonical snippet byte-for-byte. **PASS.**

### Cross-refs

All `[references/main.md]` links resolve (file present). `[/_shared/session-protocol.md]`, `[/_shared/verbose-progress.md]`, `[/_shared/package-install-policy.md]`, `[/_shared/definition-of-done.md]` all resolve. `[/_shared/terse-output.md]` resolves via implicit import.

### Pipeline chain

`migrate` is invoked standalone, not by sprint-family pipeline. Output is git commits + `${SESSION_TMP_DIR}/migrate-progress.json`. No downstream skill reads that JSON — it is resumption state for the same skill only. No pipeline chain to trace; correct for the skill's scope.

---

## C. Conciseness

**Body line count: 470** — under 500-line cap. Within limit.

**Removable prose — anti-laziness guards:**

| Location | Quoted text | Failure mode guarded | Action |
|---|---|---|---|
| Phase 0 intro | `"Execute every phase in order. Do NOT skip phases."` (line 30) | Old-model phase-skipping. 4.8 honesty/diligence makes this redundant. | Delete (~1 line) |
| Phase 4.1 intro | `"#### 4.1.1 Make the Change\n\nExecute the step — edit files, run codemods, update configs. Follow the principle of least change."` | Scaffolding filler; no decision content. | Delete (~4 lines) |
| Phase 4.1.3 header | `"**If verification passes:**"` ... commit block + `"Proceed to next step."` trailing line | The trailing `"Proceed to next step."` is obvious from the structure. | Remove trailing sentence (~1 line) |
| Safety Rules preamble | `"These rules override ALL other instructions. Violating any of these is a critical failure."` | Emphasis for old-model compliance. With 4.8 honesty, the rules stand on their own. | Delete 2-line preamble (~2 lines) |
| Phase 3.3 Plan template | 20-line display block with literal `<description>`, `<count>` placeholders | Pattern was necessary when models didn't know what format to output. Now inferrable. | Collapse to 5-line example (~15 lines) |
| Phase 4.2.2 resume section | `"3. If resuming, verify each completed commit still exists in git history."` — obvious with no unique content | Defensive nudge with no new information. | Delete (~1 line) |
| Error Recovery block | `"**No internet for research**: Proceed with package changelog from node_modules only. Warn that migration guidance may be incomplete."` | Already handled by Phase 1.4 fallback. Duplication. | Delete (~2 lines) |

**Estimated removable lines: ~45** (across prose deletions and template compression).

**Content that belongs in shared protocol:** None — codemod registry and risk matrix correctly live in `references/main.md`, not a shared protocol.

---

## D. Modernization

### Native primitive recheck (platform-delta.md v2026-05-28)

| Primitive | Applies? | Keep/Delegate/Retire |
|---|---|---|
| Native orchestration (v2.1.154+) — parallel subagents via JS script | Phase 1.1 spawns a research agent inline via WebSearch, not a true `Agent()` call. No multi-agent fan-out in practice. | **Keep** — the skill uses direct WebSearch, not Agent(). No native orchestration overlap. |
| `/code-review --fix` (v2.1.152) | Phase 5 post-migration verification. Skill does its own type-check+test+build loop; `--fix` applies to diff review, not migration verification. | **Keep** — different purpose. |
| `disallowed-tools` frontmatter (v2.1.152) | Phase 4 could benefit from locking out `TaskCreate` (if present) to prevent accidental sprint injection during migration. | **Delegate** — add `disallowed-tools: [TaskCreate]` as declarative guard. Low-value change but correct modernization. |
| `claude-opus-4-8` model ID (2026-05-28) | Frontmatter has `model: opus` (alias). | **Keep alias** — `opus` resolves to current; explicit pin to `claude-opus-4-8` optional but not required. |
| `effort: high` | Correct for a multi-phase, multi-step autonomous migration that may spawn research. | **Keep** — sane. |
| `claude agents` TUI (v2.1.139) | Phase 4.2 progress tracking uses `migrate-progress.json`; native TUI provides visibility without file writes. | Note-only: could reduce need for progress file in future. No change required today. |

**`model: opus` + `effort: high` judgment:** Appropriate. Migration is a high-stakes, long-horizon task that benefits from Opus-level reasoning and planning depth. Not a candidate for Sonnet downgrade.

**`disable-model-invocation: true`:** Present and correct — skill is slash-invoked.

---

## E. Correctness

1. **`Agent` in `allowed-tools` but unused in body.** Phase 1.1 reads "Spawn Research Agent (if WebSearch available)" and then shows direct WebSearch queries — no `Agent()` call. Body never constructs an Agent prompt. `Agent` in `allowed-tools` grants unnecessary capability. Remove `Agent` from `allowed-tools`.

2. **`${SESSION_TMP_DIR}` is used in Phase 1.1, 4.2.1, 4.2.2 but never defined.** No Phase 0 step initializes this variable. Other skills that use `SESSION_TMP_DIR` derive it from `session-protocol.md` §Session Registration. The link is implicit via the Phase 0.0 delegation; acceptable but fragile — the body should note where the variable is set.

3. **Phase 4.2.2 checks `${SESSION_TMP_DIR}/migrate-progress.json` "At Phase 0"** — the instruction is placed in Phase 4, not Phase 0. Structural misplacement. Should appear in Phase 0.1 or 0.2.

4. **`compatibility: ">=2.1.71"`** — current platform is v2.1.154+. Compatibility floor is stale but harmless; no incorrect behavior. Low-priority cleanup.

5. **references/main.md Version Compatibility tables** — `Node.js 18.x` listed as "End of Life: April 2025". As of 2026-05-28 this is past. The table will mislead; update to remove 18.x or mark EOL.

6. **No `spawn-protocol.md` citation** — `Agent` is in `allowed-tools`. If the tool is removed (see point 1), this becomes moot.

7. **`$ARGUMENTS` (line 64)** — platform-canonical variable; no issue.

---

## F. Verdict

**`needs-tightening`**

Skill is coherent, well-scoped, and correctly layered against overlapping skills. No true duplication. Three concrete fixes deliver the most leverage:

### Top Edits

1. **Remove `Agent` from `allowed-tools`** — body never calls `Agent()`. Granting the capability without use is an accidental permission expansion. If Phase 1 research ever grows to a true subagent fan-out, add back with `spawn-protocol.md` citation.

2. **Move Phase 4.2.2 resume block to Phase 0** — structural misplacement causes a model to miss the resume check at the correct time. Move the check to after Phase 0.3 (rollback branch creation).

3. **Delete ~45 lines of anti-laziness scaffolding** — primarily the Safety Rules preamble (`"These rules override ALL other instructions..."`), the Phase 3.3 verbose plan template (compress to 5-line example), and the `"Execute every phase in order. Do NOT skip phases."` opener. All guarded against pre-4.8 model behavior; 4.8 honesty + diligence makes them noise.
