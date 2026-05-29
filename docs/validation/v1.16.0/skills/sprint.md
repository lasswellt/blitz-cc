---
unit: sprint
validator: claude-sonnet-4-6
date: 2026-05-28
verdict: cohesive
highest_leverage_fix: "None required — all checks PASS or N/A; body is 109 lines (well under 450 target)."
---

# v1.16.0 Validation — `sprint` Skill

File validated: `skills/sprint/SKILL.md` (119 lines total, 109 body lines).
No `skills/sprint/references/main.md` exists — correct, not required for this skill.

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Command run: `hooks/scripts/skill-frontmatter-validate.sh skills/sprint/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Own read confirms all required fields present:
- `name: sprint` (line 2)
- `description`: 317 chars, third-person, ≤1024 ✓ (line 3)
- `model: opus` (line 7)
- `effort: low` (line 8)
- `compatibility: ">=2.1.71"` (line 9)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent` (line 5)
- `disable-model-invocation: false` (line 6)

All six required fields present and valid. Validator concurs.

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet extracted from `skills/_shared/terse-output.md` between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->` markers. Byte-for-byte comparison with line 12 of `skills/sprint/SKILL.md`:

```
MATCH — identical strings confirmed by shell comparison ($skill_line = $canonical)
```

No drift detected.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Command run: `hooks/scripts/markdown-link-validate.sh skills/sprint/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

Manual spot-check of `/_shared/` links cited in the file:
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` ✓
- `/_shared/carry-forward-registry.md` → `skills/_shared/carry-forward-registry.md` ✓
- `/_shared/checkpoint-protocol.md` → `skills/_shared/checkpoint-protocol.md` ✓
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` ✓
- `skills/next/SKILL.md` referenced inline (not as a link) — not a broken link concern

All links resolve.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

Per unit notes: N/A unless own read finds an O1–O5 owner relationship. `sprint` is a pure orchestrator, not an owner. It delegates cleanly to sub-skills via "Invoke the **sprint-plan** skill" (line 83) and "Invoke the **sprint-dev** skill" (line 100) without restating any owned logic. The `--loop` delegation is correctly documented as a backwards-compat alias to `/blitz:next --loop` with a citation to `skills/next/SKILL.md §Loop Mode` (lines 32, 53).

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `roadmap → sprint-plan → sprint-dev → sprint-review`

`sprint` (orchestrator) sits atop this chain. Per `skills/_shared/state-handoff.md`:

1. **Upstream producer → sprint pre-flight**: `roadmap` produces `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json`. Sprint's Pre-Flight Validation (lines 63–64) checks for exactly these artifacts. Match confirmed.

2. **sprint → sprint-plan**: Sprint invokes sprint-plan (line 83); sprint-plan produces `sprints/sprint-${N}/manifest.json` + `sprints/sprint-${N}/stories/S${N}-*.md` per state-handoff §sprint-plan. Sprint-dev's Phase 0.0 hard-fails if `manifest.json` or story files are absent (confirmed in sprint-dev/SKILL.md lines 64–69: `Producer: /blitz:sprint-plan.`).

3. **sprint → sprint-dev → sprint-review**: Sprint invokes sprint-dev (line 100), which produces `STATE.md`, story status transitions, and carry-forward entries — all consumed by sprint-review per state-handoff §sprint-dev and §sprint-review.

4. **Uningested research guard** (lines 64–72): Sprint's Pre-Flight step 1b auto-invokes `/blitz:roadmap extend` before the cycle if uningested `docs/_research/*.md` exist, consistent with state-handoff §research → §roadmap → §sprint-plan ordering.

Pipeline composition is correct end-to-end.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

Per unit notes: DW wiring check applies only to `codebase-audit` and `research`. `sprint` is neither. No `BLITZ_DISPATCH` gate, no `Workflow` block, and no DW logic found in the file.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`sprint` is not read-only-by-construction. `allowed-tools` includes `Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent` (line 5). Write/Edit capabilities are appropriate for an orchestrator that logs to activity feed, manages session state, and potentially auto-applies gap-closure stories. No hardening needed.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Total file: 119 lines. Frontmatter: lines 1–10 (10 lines). Body: lines 11–119 = **109 lines**.

109 ≤ 450 target ✓  
109 ≤ 500 hard cap ✓

Well within budget.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not include `TeamCreate` or `SendMessage` (line 5). Sprint uses `Agent` (canonical pattern) for any sub-agent dispatch. No TeamCreate/SendMessage drift.

---

## Skill Verdict

**cohesive**

All runnable checks (V1, V2, V3, V5, V8) PASS. V4, V6, V7, V9 are N/A per unit notes and own read. No issues found.

## Highest-Leverage Fix

None required. Body is 109 lines (well under the 450 target), OUTPUT STYLE matches verbatim, all links resolve, frontmatter validator passes, and the pipeline I/O composition is correct end-to-end. The skill is clean.
