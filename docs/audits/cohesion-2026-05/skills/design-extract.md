---
unit: skills/design-extract
kind: skill
verdict: needs-tightening
removable_lines: 22
created: 2026-05-28
---

# Audit: design-extract

## A. Identity & Boundaries

**Purpose**: Extract design tokens, typography, palette, and motion vocabulary from a brownfield project; emit `DESIGN.md` as shared aesthetic source-of-truth consumed by `ui-build` and `design-critic`.

**Description vs body**: Match is accurate. Description names DESIGN.md spec, bootstrapping use case, and handoff consumers. Body delivers exactly that in 6 phases (SESSION → SOURCE DETECTION → TOKEN EXTRACTION → AESTHETIC INFERENCE → EMIT → VERIFICATION).

**Overlaps**:

| Skill/Agent | Overlap | Classification |
|---|---|---|
| `ui-build` Phase 3.0.2 | Also writes/updates `DESIGN.md` on greenfield runs | **Legitimate layering** — `ui-build` writes design decisions; `design-extract` reverse-engineers them from existing code. Distinct directionality. |
| `frontend-design` | References same `/_shared/frontend-design-heuristics.md` tone taxonomy | **Legitimate layering** — `frontend-design` creates new designs; `design-extract` classifies existing ones using same vocabulary. |
| `design-critic` | Both consume `DESIGN.md` and `frontend-design-heuristics.md` §2 tones | **Legitimate layering** — `design-critic` evaluates; `design-extract` emits. No duplication. |

No true duplication identified.

---

## B. Cohesion

### _shared protocols cited

| Protocol | Cited | Followed / Inline-restatement |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0) | Cite-only — Phase 0 says "Follow [...]. Register session." No inline restatement. ✓ |
| `verbose-progress.md` | No | Activity-feed bash block in Phase 5 is an **inline restatement** of the protocol. Drift risk. |
| `terse-output.md` | Yes (OUTPUT STYLE block, line 14) | Verbatim snippet present. Invariant 5 satisfied. ✓ |
| `frontend-design-heuristics.md` | Yes (Phase 3, Phase 4 template) | Used correctly as reference, not restated inline. ✓ |
| `token-budget.md` | Cited in §Additional Resources | Not referenced in any phase body. Unclear how it governs this skill. |
| `definition-of-done.md` | Cited in §Additional Resources | Skill has its own DoD checklist (Phase 6 bottom). This is a **partial inline restatement** of the shared protocol. |
| `state-handoff.md` | Not cited | `DESIGN.md` is a pipeline artifact but not declared in state-handoff schema. Cross-skill consumption (ui-build, design-critic) is informal. |
| `story-frontmatter.md` | Not applicable | Skill does not produce/consume sprint stories. ✓ |

**Cross-refs**: All `/_shared/` paths are relative — correctly formatted for skill context. External URL (Google Labs spec) is live as of audit date (unverified via fetch in this session — **inferred**).

**OUTPUT STYLE**: Verbatim canonical block present at line 14. Invariant 5 ✓.

**Pipeline chain (end-to-end)**:
1. `design-extract` runs, emits `DESIGN.md` with five sections.
2. `ui-build` Phase 3.0.2 reads `DESIGN.md` instead of re-discovering tokens (confirmed in `ui-build/SKILL.md:128`).
3. `design-critic` receives `DESIGN.md` as part of spawn prompt context (confirmed `ui-build/SKILL.md:326`).

Chain is coherent. `ui-build` explicitly names this skill as the prerequisite for brownfield runs (`ui-build/SKILL.md:130`). ✓

---

## C. Conciseness

**Body line count**: 189 lines. Well under 500-line cap. ✓

**Inline restatements / anti-laziness prose**:

- Lines 166–171: Activity-feed bash snippet is a full inline restatement of the write-to-feed pattern defined in `verbose-progress.md`. Phase 5 "Activity-feed log:" section (~6 lines) can be replaced with: `Log \`task_complete\` event per \`verbose-progress.md\`.`
- Lines 183–189: DoD checklist duplicates `/_shared/definition-of-done.md` pattern. The shared protocol exists for this. (~7 lines removable, or reduce to a cite).
- Lines 43–49 (Phase 1 bash block): Discovery bash is specific enough to this skill to justify inline — not DRY violation.
- Lines 96–103 (Phase 3): Density heuristic `grep -c '<.*v-'` is Vue-specific hardcode. Acceptable given skill targets Vue/Tailwind stack (Quasar/Vuetify mentioned). **Not removable** but worth noting Vue coupling.

**Estimated removable lines**: ~22 (activity-feed bash block ×6, DoD duplication ×7, token-budget.md cite that does nothing ×2, misc defensive phrasing ×7).

---

## D. Modernization

### Native primitive overlap (citing platform-delta.md)

| Claim | platform-delta.md version | Verdict | Tradeoff |
|---|---|---|---|
| `disallowed-tools` frontmatter could lock this read-only skill harder | v2.1.152 | **Delegate (partial)** — add `disallowed-tools: [Write, Edit]` for source-file read phase; re-enable Write/Edit only in Phase 4. Currently allowed-tools lists all six tools, enabling write at any phase. | Loss: none. Gain: enforces "no source files modified" DoD invariant declaratively. |
| Skill uses `Bash` for token extraction rather than platform Read/Grep | Not a native-primitive regression | **Keep** — bash pipeline (`node -e`, `grep`, `find`) produces structured output not achievable with Read/Grep alone. |

**Model/effort**: `model: sonnet`, `effort: low`. Appropriate for a read-heavy extraction task. `sonnet-4-6` (current model ID per platform-delta.md v2026-05-28) is the right tier. No Opus required. ✓

**No multi-agent spawning** — no subagent constraint applies.

---

## E. Correctness

- **Compatibility floor** `>=2.1.117` cited with rationale in comment at lines 10–12. Rationale ("holistic-machine orchestrator for DESIGN.md handoff") is accurate — `ui-build` consumes the artifact. ✓
- **Bash commands**: `node -e "const config = require('./tailwind.config.js')"` will fail for `.ts`/`.cjs` Tailwind configs. Phase 1 discovery lists `tailwind.config.ts` and `.cjs` but Phase 2.1 only attempts `.js`. **Stale/incorrect** — will silently emit `"(no parsable Tailwind config)"` for TS projects, the most common modern config format.
- **CSS variable grep** (line 80): `$(find src -name '*.css' 2>/dev/null)` — unquoted subshell will break on paths with spaces. Low severity but incorrect.
- **Density heuristic** (line 101): `grep -c '<.*v-' src/pages/*.vue` — glob fails if `src/pages/` doesn't exist (non-standard layout). Should use `find`.
- No dead env vars, no broken `/_shared/` paths detected. **Verified by read**.

---

## F. Verdict

**`needs-tightening`**

### Top edits (highest leverage)

1. **Fix Tailwind TS config extraction** (Phase 2.1): Replace `require('./tailwind.config.js')` with a `tsx`/`ts-node`-aware loader or use `grep`-based fallback for `.ts` configs. Current bash silently no-ops for the majority of modern projects.

2. **Add `disallowed-tools` guard for source-file read phases** (platform-delta.md v2.1.152): Add `disallowed-tools: [Write, Edit]` as default + document Phase 4 override. Enforces DoD "no source files modified" declaratively rather than as prose.

3. **Replace inline activity-feed bash + DoD checklist with protocol cites** (Conciseness): Phase 5 bash block → `Log \`task_complete\` per \`verbose-progress.md\`.`; Phase 6 DoD → `Follow \`/_shared/definition-of-done.md\`.` Removes ~13 lines of restatement drift.
