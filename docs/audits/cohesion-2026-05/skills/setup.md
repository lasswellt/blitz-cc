---
unit: skills/setup
kind: skill
verdict: needs-tightening
removable_lines: 28
created: 2026-05-28
---

# Audit: skills/setup

## A. Identity & Boundaries

**One-sentence purpose:** Scan global + project CLAUDE.md files against a static conflict catalog, validate tool permissions, and check package-manager assumptions, producing a severity-graded report.

**Description vs body:** Match is good. Description says "detects conflicts … validates tool permissions and stack assumptions" — body phases 2–4 implement exactly that. No scope creep.

**Overlaps:**

| Other unit | Relation | True dup or legitimate layer? |
|---|---|---|
| `blitz:health` | health.md also checks project readiness (stack, deps, CI config) | Legitimate layering — `health` checks project health; `setup` checks blitz↔CLAUDE.md rule conflicts. Different subject domain. |
| `blitz:conform` | conform checks code against style rules | No overlap — conform is post-implementation linting, not config-conflict detection. |
| `hooks/scripts/skill-frontmatter-validate.sh` | both validate settings | No overlap — hook validates SKILL.md schema; setup validates user CLAUDE.md rules at runtime. |

No true duplications found.

---

## B. Cohesion

**_shared protocol citations:**

| Protocol | Cited | Followed or restated? |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0.0, §Additional Resources) | Followed by reference — no inline restatement. |
| `verbose-progress.md` | Yes (Phase 0.0) | Followed by reference. |
| `terse-output.md` | Yes (§Additional Resources + canonical OUTPUT STYLE line) | **Invariant 5 satisfied.** OUTPUT STYLE snippet present verbatim at line 22. |
| `state-handoff.md` | Not cited | Verified: setup produces no pipeline artifact (report-only); omission is correct. |
| `story-frontmatter.md` | Not cited | Correct — setup is not sprint-family. |
| `spawn-protocol.md` | Not cited | Correct — setup spawns no agents. |
| `token-budget.md` | Not cited | Acceptable for `effort: low` single-agent skill. |

**Cross-refs liveness:**

- `references/main.md` — exists and readable. Live. ✓
- `/_shared/session-protocol.md` — standard shared path, assumed live. ✓
- `/_shared/terse-output.md` — standard shared path, assumed live. ✓
- `docs/_research/2026-04-16_plugin-agent-strategy.md` — not verified (not read). Uncertainty: may be stale or deleted.
- `${CLAUDE_PLUGIN_ROOT}/skills/setup/conflict-catalog.json` — verified path (`skills/setup/assets/conflict-catalog.json` exists on disk). **Path mismatch**: SKILL.md Phase 2 says `${CLAUDE_PLUGIN_ROOT}/skills/setup/conflict-catalog.json` but the error-recovery block says `assets/conflict-catalog.json`; `references/main.md` says both `skills/setup/conflict-catalog.json` (schema) and `assets/conflict-catalog.json` (extending instructions). Actual file on disk: `skills/setup/assets/conflict-catalog.json`. All three path forms are inconsistent. **Bug.**

**Pipeline chain:** setup has no downstream consumer (report-only, no artifact). No pipeline chain to trace.

---

## C. Conciseness

**Line count:** 199 lines — under 500-line cap. ✓

**Anti-laziness nudges to delete:**

Line 30: `**This skill is read-only by default.** \`--fix\` mode is reserved for future versions and not implemented in MVP.`
— Restates what Phase 0.1 already says in the flag table. Defensive "don't do the wrong thing" note for old model behavior. Removable.

Line 53 (flag table row): `| \`--fix\` | **Not implemented in MVP** — print "coming in v1.4" and fall back to \`--check\` |`
— "coming in v1.4" is stale version ref (current version far past v1.4). Either implement or remove the flag from `argument-hint` entirely. Stale + misleading.

Lines 190 (Phase 6 item 3 + surrounding): `Future \`--fix\` mode will exit non-zero on unresolved HIGH conflicts.`
— Forward-looking prose describing unimplemented behavior; no informational value today.

Lines 196–199 (Error Recovery `--fix` reference): Error message says "reinstall the blitz plugin" — the catalog path referenced there is wrong (see §B above), compounding the confusion.

**DRY candidates:** None identified — no protocol content is being restated inline.

**Estimated removable lines:** ~28 (lines 30, 53, stale `--fix` forward refs, incorrect catalog path in error message, defensive re-explanations of `--fix`).

**Phantom tool list (Phase 3):** `REQUIRED_TOOLS=(Agent SendMessage TeamCreate TaskCreate TaskUpdate Write Edit Bash)` — this list is for checking user settings, but setup's own `allowed-tools` frontmatter only lists `Read, Bash, Glob, Grep`. The check list includes `Agent`, `SendMessage`, `TeamCreate`, `TaskCreate`, `TaskUpdate` — none of which setup itself uses. The list is valid as "tools blitz skills need" but is undocumented as such; a reader will assume it's setup's own tool list. Needs a clarifying comment.

---

## D. Modernization

**Native primitives (platform-delta.md v2026-05-28):**

| Native change | Relevance | Verdict |
|---|---|---|
| `disallowed-tools` SKILL.md frontmatter (v2.1.152) | Phase 3 checks tool deny lists; setup itself has no risky tools to block | No action needed — setup already has a minimal `allowed-tools` list. No native overlap. |
| `SessionStart` hooks `additionalContext` / `reloadSkills` (v2.1.152) | Setup is a manual slash-skill, not a hook — no overlap | No action. |
| Model IDs current as of 2026-05-28: `claude-sonnet-4-6` | `model: sonnet` frontmatter is an alias — **should be explicit `claude-sonnet-4-6`** per platform-delta.md | Update frontmatter `model:` value. Low urgency but recommended for determinism. |
| `effort.level` in hooks (v2.1.141) | Not relevant — setup doesn't branch on effort | No action. |

**Prose guard → `disallowed-tools`:** No applicable conversion — setup has no tool-misuse risk to guard.

**Model/effort sanity:** `model: sonnet`, `effort: low` — appropriate for a read-only scan. No agent spawning. Sane.

**`--fix` flag:** Advertised in `argument-hint` but unimplemented. Either delete from frontmatter hint or implement. Stale feature stub creates user confusion and is the main source of removable lines.

---

## E. Correctness

**Stale refs:**
- `"coming in v1.4"` — stale version string (SKILL.md line 53). Current repo at v1.15.0+. **Bug.**
- `assets/conflict-catalog.json` path inconsistency across three locations (SKILL.md Phase 2, SKILL.md Error Recovery, references/main.md). Actual disk path: `skills/setup/assets/conflict-catalog.json`. Runtime would fail with `${CLAUDE_PLUGIN_ROOT}/skills/setup/conflict-catalog.json` (missing `assets/` segment) if `$CLAUDE_PLUGIN_ROOT` = repo root. **Bug.**
- `docs/_research/2026-04-16_plugin-agent-strategy.md` — not verified present. Possible dead link.

**Wrong tool names in REQUIRED_TOOLS check:** `TaskUpdate` — not a Claude Code tool (standard tools are `TaskCreate`, `TaskStop`). Low impact (it's a passive check list), but inaccurate.

**`--fix` in `argument-hint`:** Misleads users into thinking `--fix` does something. It explicitly falls back to `--check`.

**Subagent constraint:** Setup does not spawn agents. `subagents-cannot-spawn-subagents` not relevant.

**Dynamic Workflows:** Setup is slash-only and uses no agents. Native workflow orchestration (platform-delta.md v2.1.154+) has zero impact on this skill.

---

## F. Verdict

`needs-tightening`

**Top 3 edits:**

1. **Fix catalog path everywhere.** Standardize to `${CLAUDE_PLUGIN_ROOT}/skills/setup/assets/conflict-catalog.json` in Phase 2 bash block, Phase 6 error-recovery message, and references/main.md. One path, three fixes.

2. **Remove or implement `--fix`.** It's been "coming in v1.4" since before v1.15.0. Delete `--fix` from `argument-hint` frontmatter, Phase 0.1 flag table, Phase 6 forward-ref prose, and SAFETY RULES line 30. Eliminates ~28 removable lines and removes stale version ref.

3. **Update `model:` to explicit `claude-sonnet-4-6`** per platform-delta.md v2026-05-28 model ID table (determinism; alias may resolve differently across versions).
