---
unit: skills/sprint-plan
kind: skill
verdict: needs-tightening
removable_lines: 60
created: 2026-05-28
---

# Audit: sprint-plan

## A. Identity & Boundaries

**One-sentence purpose:** Selects unblocked epics from the roadmap, spawns parallel research agents, generates story files with canonical frontmatter, and publishes GitHub issues for the next sprint.

**Description ↔ body match:** Yes. Description mentions `--gaps`, topological sort, research agents, `story-frontmatter.md`, and GitHub issues — all present in body. Accurate.

**Overlaps with other skills/agents:**

| Skill/Agent | Overlap | Type |
|---|---|---|
| `blitz:roadmap` | Epic selection, dependency graph reads | Legitimate layering — roadmap writes the graph; sprint-plan reads it |
| `blitz:research` | Spawns parallel research agents | Legitimate layering — sprint-plan's research is sprint-scoped; `blitz:research` produces `docs/_research/` for the roadmap phase |
| `blitz:sprint-dev` | Consumes story files; reads manifest.json | Pipeline handoff — no functional duplication |
| `blitz:sprint-review` | Reads coverage matrix, carry-forward registry | Pipeline handoff — no functional duplication |
| `blitz:conform` | Called inline at Phase 4 validation failures | Legitimate delegation — not reimplemented |
| `blitz:completeness-gate` | AC coverage check (Phase 4.1) partially mirrors completeness-gate's role | Borderline: completeness-gate runs post-implementation; sprint-plan's Phase 4.1 is pre-implementation AC mapping — different timing, different purpose. No true duplication. |

No retire/merge candidates found.

---

## B. Cohesion

### Cited protocols

| Protocol | Cited | Followed vs. Restated |
|---|---|---|
| `session-protocol.md` | Yes (Phase 0, Phase 4.5 lock) | Delegates — uses §Session Registration + §File-Based Locking by reference |
| `verbose-progress.md` | Yes (Phase 0 step 0) | Delegates |
| `state-handoff.md` | Yes (Phase 0.0, header) | Delegates — Phase 0.0 hard-fail block is inline bash, but it's ~12 lines that couldn't be imported anyway |
| `story-frontmatter.md` | Yes (Phase 3.2, references/main.md) | Properly delegates; references/main.md explicitly tombstones its prior inline duplication |
| `carry-forward-registry.md` | Yes (Phase 0 step 8, Phase 4.1) | Delegates for reader algorithm |
| `spawn-protocol.md` | Yes (Phase 2.1, 2.4) | Delegates — references §8 validator by name; does NOT restate thresholds inline (good) |
| `terse-output.md` | Yes | OUTPUT STYLE snippet present verbatim (line 25 of SKILL.md) — **Invariant 5 satisfied** |
| `checkpoint-protocol.md` | Yes (Phase 0 step 7) | Delegates |
| `context-management.md` | Yes (header) | Delegates |
| `token-budget.md` | Not cited | Model routing not cross-referenced; `model: opus` frontmatter exists but no mention of fast-mode availability for this latency-sensitive skill |
| `knowledge-protocol.md` | Not cited | Omission; low impact for planning skill |
| `shortcut-taxonomy.md` | Not cited | Phase 3.1.1 SPIDR guard is inline, not a cross-reference to shortcut-taxonomy.md — drift risk |
| `agent-routing.md` | Not cited | Not required for slash-only skill but should be noted |

### Cross-refs live/accurate

- `/_shared/story-frontmatter.md` — verified exists
- `/_shared/state-handoff.md` — verified exists
- `/_shared/carry-forward-registry.md` — verified exists
- `/_shared/spawn-protocol.md` — verified exists
- `references/main.md` — verified exists
- `docs/_research/2026-04-08_sprint-carryforward-registry.md` — referenced twice inline; not verified (file may exist; not read in this audit)

### State-handoff.md conformance

Sprint-plan's emitted artifacts per `state-handoff.md`:

| Artifact | Phase | Correct |
|---|---|---|
| `sprints/sprint-${N}/manifest.json` | 1.4 | Yes |
| `sprints/sprint-${N}/stories/S${N}-*.md` | 3.2 | Yes |
| `sprint-registry.json` entry | 4.5 | Yes |
| `.cc-sessions/carry-forward.jsonl` auto_waived lines | 4.1 | Yes |
| GitHub issues | 4.4 | Yes |

Consumed inputs per state-handoff.md:

| Artifact | Phase | Correct |
|---|---|---|
| `docs/roadmap/roadmap-registry.json` | 0.0 gate | Yes |
| `docs/roadmap/epic-registry.json` | 0.0 gate | Yes |
| `.cc-sessions/carry-forward.jsonl` | 0 step 8 | Yes |
| `sprints/sprint-${N}-planning-inputs.json` | 0 step 8 | Yes |

No invented shapes. Full conformance.

### Pipeline chain trace (sprint-plan → sprint-dev)

sprint-plan Phase 3.2 writes `sprints/sprint-${N}/stories/S${N}-XXX-<slug>.md` with `status: planned`, `assigned_agent`, `files[]`, `verify[]`, `depends_on[]`. sprint-dev Phase 0.0 requires `sprints/sprint-${N}/manifest.json` + story files validated against `story-frontmatter.md`. References/main.md §Story File Format notes `status: planned` at creation and `github_issue: null` until Phase 4.5 — matches sprint-dev's Phase 0 validation. **Chain is intact.**

---

## C. Conciseness

**Line counts:** SKILL.md = 450 lines (cap 500 — within limit). references/main.md = 339 lines (separate file, no cap per se).

**Combined** = 789 lines. The references file is a companion document, not a SKILL.md extension, so it does not count against the 500-line cap. However the total load on context is high.

### Anti-laziness / defensive prose candidates for deletion

1. **SKILL.md line 33:** `"Execute every phase in order. Do NOT skip phases."` — relic of pre-4.8 instruction-following weakness. With 4.8 honesty gains, skip-guard is low-value. ~1 line.

2. **SKILL.md lines 346–354 (auto-waiver procedure note):** `"All four writes are required — manifest carry_forward alone reintroduces the CAP-133 silent-drop."` The procedure is already specified in Phase 4.1 and references/main.md. This trailing repetition guards against the model skipping step 4. ~4 lines.

3. **SKILL.md lines 103–104 (carry-forward step 8 rationale block):** `"Why this matters: carry-forward state lives in the registry…"` — 3 lines of explanatory prose that compensates for a model that might ignore the registry read. Belongs in a shared protocol note, not inline. ~4 lines.

4. **Phase 2.2 (lines 182–189):** Restates agent prompt content structure already specified in Phase 2.1 and agent templates in references/main.md. Borderline — light duplication. ~8 lines.

5. **SKILL.md lines 291–293 (Phase 3.2 Output Style sub-block):** Verbatim repeat of the canonical OUTPUT STYLE snippet already present at line 25 for story bodies. The story body section says `terse-technical per /_shared/terse-output.md` + drops full snippet again. ~12 lines.

6. **references/main.md lines 2–8 (companion intro + pointer to carry-forward-registry.md):** Pure prose header that re-explains the companion relationship. Already self-evident from file structure. ~8 lines.

7. **SKILL.md Phase 2.1 `subagent_type: general-purpose` note** (line 157): `"(agents must Write findings files; Explore is read-only and silently fails the write)"` — legitimate guard against a real footgun. **Keep.**

8. **references/main.md §Balance Check (lines 52–56):** `"No single agent has more than 50% of total story points."` Heuristic not enforced anywhere downstream; pure advisory. ~5 lines removable or movable to a shared load-balancing note.

**Estimated removable lines: ~60** (across SKILL.md + references/main.md combined).

### Content that belongs in shared protocol

- SPIDR bulk-story guard (SKILL.md Phase 3.1.1, ~30 lines) — semantically belongs in `shortcut-taxonomy.md` (anti-shortcut detector 20 if one were added). Currently inline with no cross-reference. Drift risk: if shortcut-taxonomy.md adds a similar pattern, this becomes a duplicate. **Mark for future extraction.**

---

## D. Modernization

### Native primitive overlap

Per `platform-delta.md`:

1. **Native orchestration workflows (v2.1.154+)** — Phase 2.1 spawns 3-4 `Agent` tool calls in a single message for parallelism. Native workflows provide the same fan-out with cached intermediate results. **Verdict: keep as-is today.** Reason: native workflows are intra-session only (platform-delta.md 2026-05-28, "resume limited to same session"). Sprint-plan's research agent outputs are written to `${SESSION_TMP_DIR}/` files and copied into `${SPRINT_DIR}/research/` — this cross-session persistence is exactly the gap that native workflows don't close. Delegating would lose the file-persistence contract that sprint-review and subsequent sessions rely on. *[platform-delta.md v2.1.154+, 2026-05-28]*

2. **`/goal` completion-condition loop (v2.1.139)** — Phase 4.1 retries AC coverage up to 3 times. `/goal` could replace the retry loop with a declarative condition check. **Verdict: keep as-is.** The retry includes story-generation logic, not just condition polling. `/goal` is for exit conditions, not remediation loops. *[platform-delta.md v2.1.139, 2026-05-11]*

3. **`disallowed-tools` frontmatter (v2.1.152)** — SKILL.md does not use `disallowed-tools`. The SPIDR check and bulk-story guards are prose-only; no tool restrictions prevent a model from, e.g., bulk-writing story files. **Verdict: low impact here** — sprint-plan doesn't have a specific tool to lock down. Not a gap. *[platform-delta.md v2.1.152]*

4. **Opus 4.8 fast mode ($10/$50 per MTok, platform-delta.md fast-mode-2026-02-01 beta, 2026-05-28)** — `model: opus` with no `speed: fast` annotation. Sprint-plan is latency-sensitive (user waits for research + story generation). **Verdict: add `speed: fast` note to frontmatter or `token-budget.md` routing section.** The 2.5x throughput improvement and 3x lower cost vs 4.6/4.7 fast mode directly benefit this skill. *[platform-delta.md fast-mode-2026-02-01 beta, 2026-05-28]* — **top_edit candidate.**

5. **Model ID currency** — `model: opus` (alias). Current canonical ID is `claude-opus-4-8` per platform-delta.md (2026-05-28). Alias may still resolve but explicit ID is safer. *[platform-delta.md 2026-05-28]* — **minor.**

### `effort: high`

Correct for an orchestrator that spawns agents and produces multi-file output. No change needed.

### `model: sonnet` for subagents (line 159)

Correct per MEMORY.md feedback `[Skill model must survive [1m] context inheritance]`. **Keep explicit `model: sonnet`.**

---

## E. Correctness

1. **Phase 2.3 missing** — Phase numbering jumps 2.1 → 2.2 → 2.4 (no 2.3). Not a logic bug — 2.3 may have been deleted. Cosmetic fix only.

2. **`$CLAUDE_PLUGIN_ROOT` in Phase 0 project context block (line 13)** — `!` shell expansion in SKILL.md markdown. Correct pattern for the detect-stack.sh hook. Verified against other skills in repo — consistent. No bug.

3. **`SESSION_TMP_DIR` undefined in body** — SKILL.md references `${SESSION_TMP_DIR}` in Phase 2.1 and 2.2 without defining it. Definition presumably lives in `session-protocol.md` §Session Registration or `verbose-progress.md`. **Unverified** (those files not read in this audit). If undefined, agent prompt interpolation silently uses the literal string. Low probability given the skill has been running in production, but worth confirming.

4. **`subagents-cannot-spawn-subagents` constraint** — SKILL.md is slash-invoked; it spawns agents itself. Dynamic Workflows (v2.1.154+) allow script-mediated fan-out but the constraint is about *agents spawning agents*, not orchestrators. Sprint-plan is a slash-invoked skill (orchestrator tier) — constraint does not apply here. **No change needed.**

5. **`references/main.md` §Error Recovery** — partially overlaps SKILL.md §Error Recovery (lines 445–451). The SKILL.md section says "Full detail in references/main.md §Error Recovery" but then restates 5 inline rules. The inline rules differ from references/main.md (which has 4 rules, overlapping but not identical). **Drift vector** — if references/main.md updates, SKILL.md inline summary won't track. ~6 lines removable from SKILL.md if references/main.md is considered authoritative.

6. **`sprint-${N}-planning-inputs.json` path in Phase 0 step 8** — the file is referenced as `sprints/sprint-${SPRINT_NUMBER}-planning-inputs.json` in SKILL.md but state-handoff.md §sprint-plan row lists it identically. Consistent. No bug.

7. **GitHub issue creation Phase 4.4 vs Phase 4.5 numbering** — SKILL.md calls issue creation Phase 4.4 and registry update Phase 4.5, but `references/main.md` §Story File Format says `github_issue: null` until "Phase 4.5 (post-issue-creation)". Off-by-one mislabel in references/main.md. **Minor drift** — no functional impact.

---

## F. Verdict

**`needs-tightening`**

No retire, merge, or delegate-to-native warranted. Core logic is correct, pipeline contracts are clean, and Invariant 5 is satisfied. Primary issues:

1. ~60 removable lines of defensive prose + output-style duplication
2. SPIDR guard not cross-referenced to `shortcut-taxonomy.md` (drift risk)
3. Opus fast-mode not surfaced despite cost+latency benefit
4. Error Recovery duplication between SKILL.md inline and references/main.md

---

## Top Edits

1. **Add `speed: fast` to frontmatter or reference in `token-budget.md` routing note.** Sprint-plan is the highest-latency user-facing planning skill; Opus 4.8 fast mode at $10/$50/MTok is directly applicable. Cite: *platform-delta.md fast-mode-2026-02-01 beta, 2026-05-28*.

2. **Delete the duplicate OUTPUT STYLE block in Phase 3.2 (SKILL.md ~lines 292–295) and replace with `per line 25`.** The canonical snippet at line 25 already satisfies Invariant 5; the second occurrence in the story-body section is redundant. ~12 lines removed.

3. **Cross-reference SPIDR bulk-story guard (Phase 3.1.1) to `shortcut-taxonomy.md`** with a comment: `<!-- also tracked as detector #20 in shortcut-taxonomy.md — keep in sync -->`. Prevents silent divergence if taxonomy adds a matching entry.
