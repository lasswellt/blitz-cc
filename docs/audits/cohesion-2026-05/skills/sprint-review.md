---
unit: skills/sprint-review
kind: skill
verdict: needs-tightening
removable_lines: 80
created: 2026-05-28
---

# Audit: skills/sprint-review

Sources read: `skills/sprint-review/SKILL.md` (449 lines), `skills/sprint-review/references/main.md` (848 lines), `docs/audits/cohesion-2026-05/platform-delta.md`.

---

## A. Identity & Boundaries

**One-sentence purpose:** Runs automated quality gates (type-check, lint, tests, build), 4 parallel reviewer agents, 8 registry invariants (carry-forward, ratchet, critic, branch hygiene), and emits PASS/CONDITIONAL/FAIL + review report for a completed sprint.

**Description vs body match:** Verified. Frontmatter description accurately summarises the Phase 0–4 pipeline. No mismatch.

**Overlapping skills/agents:**

| Skill/Agent | Overlap type | True dup or legitimate layer? |
|---|---|---|
| `skills/review/SKILL.md` | Thin alias that routes to sprint-review | Legitimate — documented alias per `quality-matrix.md` row 27 |
| `skills/completeness-gate/SKILL.md` | Phase 1.5.1 Anti-Mock Scan in sprint-review mirrors completeness-gate's placeholder scan | **True partial dup** — SKILL.md Phase 1.5.1 re-implements the same grep patterns completeness-gate already owns; quality-matrix.md row 34 explicitly says "ship" chains them separately, but sprint-review also runs it inline |
| `skills/integration-check/SKILL.md` | Phase 1.6 integration check — sprint-review invokes `/blitz:integration-check all` as a sub-call | Legitimate layering (delegation, not reimplementation) |
| `agents/critic.md` | Invariant 7 spawns `blitz:critic` | Legitimate — critic is a spawned subagent, not re-implemented inline |
| `agents/reviewer.md` | Phase 2 spawns 4 reviewer agents of type `general-purpose` (not the reviewer agent) | Legitimate — spawn-protocol `general-purpose` distinct from named `reviewer.md` agent; no dup |

---

## B. Cohesion

### _shared protocol citations

| Protocol | Cited? | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | ✅ Phase 0 step 0, Phase 4.3 lock | Delegated — no inline restatement |
| `verbose-progress.md` | ✅ Phase 0 step 0 | Delegated |
| `terse-output.md` | ✅ SKILL.md line 26 + references/main.md line 848 | Both locations contain canonical OUTPUT STYLE snippet — Invariant 5 satisfied |
| `story-frontmatter.md` | ✅ Additional Resources | Delegated |
| `state-handoff.md` | ✅ Phase 0.0 | Followed — Phase 0.0 bash block in references/main.md matches contract |
| `carry-forward-registry.md` | ✅ Phase 3.6 | Reader Algorithm delegated — no inline restatement of algorithm |
| `spawn-protocol.md` | ✅ Phase 2.6 | Agent Output Contract delegated to §8 reference; weight class Medium stated inline but consistent with protocol |
| `ratchet-protocol.md` | ✅ Invariant 6 | Delegated + concrete compute script in references/main.md §Invariant 6 — additive, not contradictory |
| `shortcut-taxonomy.md` | ✅ Invariant 7 | Delegated to critic |
| `worktree-lifecycle.md` | ✅ Invariant 8 | Delegated + concrete bash block in references/main.md §Invariant 8 |
| `checkpoint-protocol.md` | ✅ Phase 0 step 1b | Delegated |
| `deviation-protocol.md` | ✅ Additional Resources | Cited but no inline body — correct |
| `context-management.md` | ✅ Additional Resources | Cited — no inline restatement |
| `knowledge-protocol.md` | ✅ references/main.md §Reviewer Output Schema | Delegated |

**Drift risk:** Low. Protocols are cited and delegated, not restated. One drift point: Phase 2.2.1 states `subagent_type: general-purpose` inline — this is consistent with spawn-protocol.md but duplicates the weight-class cap table (15 reads, 25 tool calls, 300-line output, 5-min) in prose rather than referencing spawn-protocol §Medium weight class. Not critical but DRY target.

### Cross-ref accuracy

- `references/main.md` does NOT contain a `## Reviewer Prompt Templates` section. SKILL.md Phase 2.2.1 (`Prompt from references/main.md "Reviewer Prompt Templates"`) is a **dead cross-reference** — the section does not exist in the file. **Correctness defect.**
- All other cross-refs (`state-handoff.md`, `carry-forward-registry.md`, `spawn-protocol.md §8`, `ratchet-protocol.md`, `worktree-lifecycle.md`) verified present.

### Produces/consumes per state-handoff.md

Verified against `skills/_shared/state-handoff.md` §sprint-review rows 74–82:

| Artifact | Expected | Present in skill? |
|---|---|---|
| `sprints/sprint-${N}/review-report.md` | Produce Phase 4.1 | ✅ |
| `sprints/sprint-${N}-planning-inputs.json` | Produce Invariant 4 | ✅ references/main.md §3.6.5 |
| Story status final transitions | Produce Phase 3 | ✅ |
| `.cc-sessions/carry-forward.jsonl` events | Produce Phase 3.6 | ✅ |
| `sprint-registry.json` status update | Produce Phase 4.3 | ✅ |
| `sprint-registry.json`, manifest, stories | Consume Phase 0.0 | ✅ |

Shape conformance: registry JSON shape in Phase 4.3 includes `quality_gates`, `findings`, `stories_*` keys — matches state-handoff expected shape. No invented shapes.

### OUTPUT STYLE (Invariant 5)

Present verbatim in SKILL.md line 26 (intensity: `terse-technical`). Present in references/main.md line 848 (identical text). Invariant 5 satisfied.

### Pipeline chain trace (sprint-dev → sprint-review → ship)

sprint-dev produces: stories with `status: done`, `sprint-registry.json` with `status: in-progress|review`, commits, branches.
sprint-review Phase 0.0 consumes: `sprint-registry.json` ✅, `manifest.json` ✅, `stories/S*.md` ✅.
sprint-review produces: `review-report.md`, registry status `→ reviewed`, `review_status: PASS|CONDITIONAL|FAIL`.
ship (downstream) reads: `sprint-registry.json` `review_status` + `review-report.md`.
Chain intact — no shape mismatch found.

---

## C. Conciseness

**SKILL.md body:** 449 lines (under 500-line cap ✅). No padding or prose that exists purely to compensate for old-model behavior found in the SKILL.md body.

**references/main.md:** 848 lines. Contains reviewer checklists (§386–443), auto-fix strategy tables (§179–225), and the full Invariant 6/7/8 bash blocks. All are additive reference material, not anti-laziness nudges. However:

**Anti-laziness prose to flag for deletion:**

1. `references/main.md` §Finding Format lines 347-368 restates the terse-output finding shape rules in exhaustive prose ("Drop from findings: 'I noticed', 'It seems like'…"). These are already covered by `terse-output.md`. Estimated **~25 removable lines** — the specific reviewer-drop rules are not in terse-output.md so partial legitimacy; the `keep` list (line numbers, concrete fix) is the only additive content.

2. SKILL.md Phase 3.6 §Invariant 5 (lines 318–350) contains the full audit bash block + explanation. The bash block is legitimate (it's the executable procedure). But lines 318–330 prose-explain what the snippet is, already stated in spawn-protocol.md §7. Estimated **~12 removable lines** (prose intro above the bash block).

3. references/main.md §Quality Gate Checklist (lines 142–176) — 34 lines of per-gate pass/fail tables. These describe what `npm run type-check` / `npm run lint` already report; not reference material that changes behavior. **~34 removable lines** if the build tool already gives structured output.

4. SKILL.md Phase 0 step 3 (`find . -maxdepth 3 -name 'package.json'...`) is a one-liner that belongs in references/main.md §Phase 0.0 Input Gate or Changed Package Detection. Minor — not counted.

**Content that belongs in a shared protocol:** The reviewer spawn weight-class spec (15 reads, 25 tool calls, 300-line output, 5-min budget) in SKILL.md Phase 2.2.1 duplicates spawn-protocol.md's Medium weight class. **~5 removable lines** — replace with `Weight class: Medium per spawn-protocol.md §Medium`.

**Total estimated removable lines (SKILL.md + references/main.md):** ~80 lines (conservative). Mostly in references/main.md.

---

## D. Modernization

### Native primitive overlap

**`/code-review --fix` (platform-delta.md v2.1.152, 2026-05-27):**
platform-delta.md row 33 states: "Replaces manual apply step in Blitz `sprint-review` Phase 3.6 critic loop."
Assessment: Phase 3 auto-fix loop (Phase 3.1–3.5) is more opinionated than `/code-review --fix` — it runs type-check, lint, tests in a retry loop with category-ordered fix sequencing and carry-forward escalation on failure. Native `/code-review --fix` applies findings from a diff review but does not implement the retry/revert loop or carry-forward integration. **Verdict: keep** Phase 3 auto-fix loop. Tradeoff: native `/code-review --fix` loses the retry-with-revert logic and carry-forward escalation on exhausted attempts. The opinionated sprint-aware behavior is legitimate non-native value.

**`/code-review` reviewer agents (platform-delta.md v2.1.152):**
sprint-review Phase 2 spawns 4 parallel reviewer agents rather than delegating to native `/code-review`. Native `/code-review` is a diff review without sprint-aware context injection (ACs, prior gate results, sequential cross-finding mode). **Verdict: keep** parallel agent spawn. Tradeoff: native review loses sprint AC injection and Phase 3.6 critic integration. Opinionation is legitimate.

**`disallowed-tools` (platform-delta.md v2.1.152):**
SKILL.md has no `disallowed-tools` frontmatter. Phase 3.4 states "never auto-fix security findings." This prose guard could be reinforced via `disallowed-tools` if there were a relevant tool to lock, but security findings are prevented by Phase 3.1 scope table, not tool invocation. No mechanical lock available — prose guard is correct approach here. **No change needed.**

**Model ID (platform-delta.md 2026-05-28):**
`model: opus` in frontmatter — not pinned to a specific version. Current model is `claude-opus-4-8`. Opus 4.8 honesty improvements (platform-delta.md row: "~4x less likely than Opus 4.7 to let own code flaws pass unremarked") benefit this skill directly (Phase 3 auto-fix assessment + Invariant 5 snippet audits). Fast mode (`speed: "fast"`, $10/$50 per MTok) could reduce latency on the orchestrator's Phase 0–2 passes. **Recommend** updating `model: claude-opus-4-8` and noting fast mode eligibility for Phase 0/1 passes in token-budget.md.

**Effort: high** — appropriate given 8-phase pipeline + parallel agent spawning. No change.

**Native workflows (platform-delta.md v2.1.154):**
Phase 2 parallel reviewer spawn is a manual multi-`Agent()` pattern. Native workflows could fan out the 4 reviewers as first-class subagents. However, workflow state is intra-session only (platform-delta.md row: "resume limited to same session") and Blitz needs cross-session carry-forward. **Verdict: keep** manual Agent() spawn. No determinism or opinionation is lost; native workflow adoption is blocked by cross-session gap.

**`/goal` loop (platform-delta.md v2.1.139):**
Phase 4.6 retry rules for auto-fix loop could use native `/goal` condition-check. Low priority; current retry loop is sufficient. **Verdict: keep** — explicit retry loop is more auditable.

---

## E. Correctness

**Dead cross-reference (HIGH):** SKILL.md Phase 2.2.1 — `Prompt from references/main.md "Reviewer Prompt Templates"` — this section does **not exist** in references/main.md. The file has `## Reviewer Spawn Strategy`, `## Reviewer-Specific Checklists`, but no `## Reviewer Prompt Templates` section with actual reviewer prompt text. Consequence: reviewer agents in Phase 2 have no concrete prompt template. The spawn instructions exist (subagent_type, model, weight class) but the actual prompt text is absent. This is a **correctness gap** — reviewer agents would be spawned with ad-hoc prompts.

**Reviewer Prompt Template absence:** references/main.md contains the checklist and finding format but not the actual prompt strings sent to `security-reviewer`, `backend-reviewer`, `frontend-reviewer`, `pattern-reviewer`. The SKILL.md references this section as if it exists.

**Phase 3.6 invariant count mismatch:** SKILL.md Phase 4.2 PASS criteria states "All Phase 3.6 invariants 1–7 pass" but Phase 3.6 enumerates Invariants 1–8 (including branch hygiene). SKILL.md Phase 4.2 FAIL criteria mentions "invariant failure escalates" and "critic REJECT" and "type_errors > 0" but Invariant 8 not listed in the 4.2 status table. **Minor inconsistency** — Invariant 8 is in Phase 3.6 step 5 and references/main.md §Invariant 8, but PASS criteria in 4.2 says "1-7" not "1-8".

**`stale_worktree_branch_count` metric:** Invariant 6 mentions the 8th metric was "added 2026-05-17" requiring `code-sweep --baseline stale_worktree_branch_count` on existing projects. No automation to prompt this — operators must know to run it manually. Minor documentation gap, not a skill defect.

**Model alias `opus`:** Not pinned to `claude-opus-4-8`. Stale if `opus` alias changes. Low risk but inconsistent with platform-delta.md row recommending specific model IDs.

**`SESSION_TMP_DIR` undefined:** Used throughout (Phase 1.5, 2.1, 2.2, 2.6) but never initialized in SKILL.md. Assumed to come from session-protocol.md `§Session Registration`. Not a defect if session-protocol initializes it, but undocumented dependency. **Inferred** — did not verify session-protocol.md defines `SESSION_TMP_DIR`.

**No `disallowed-tools` field:** Current frontmatter has `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, Agent`. WebSearch is included — reasonable for security CVE lookups in reviewer context. No tools that should be locked. Correct as-is.

**`blitz:critic` agent type:** Phase 3.6 Invariant 7 spawns `subagent_type: "blitz:critic"`. platform-delta.md v2.1.154 confirms native workflows, but `blitz:critic` is a named skill invocation pattern. Verify spawn-protocol.md supports `blitz:*` subagent_type — **inferred** it does based on other skills using same pattern. Not verified directly.

**Subagents-cannot-spawn-subagents constraint:** sprint-review is slash-only (not invoked from orchestrator mid-chain). Phase 2 spawns `general-purpose` agents — these are leaf agents. Phase 3.6 Invariant 7 spawns `blitz:critic`. If critic itself spawns agents, the constraint applies. `agents/critic.md` is described as read-only adversarial — assumed no sub-spawn. **Inferred** — did not read agents/critic.md.

---

## F. Verdict

**`needs-tightening`**

Skill is coherent and well-structured. No retire, split, or merge warranted. Three concrete issues require fixing:

### Top Edits (highest leverage)

1. **Add `## Reviewer Prompt Templates` section to `references/main.md`** — populate the actual prompt text for `security-reviewer`, `backend-reviewer`, `frontend-reviewer`, `pattern-reviewer` (Phase 2.2.1 references this section; it doesn't exist). Without it, reviewer agent prompts are ad-hoc at runtime. Critical correctness gap.

2. **Fix Phase 4.2 PASS criteria: "1–7" → "1–8"** — Invariant 8 (branch hygiene) blocks PASS per Phase 3.6 step 5 and 4.6 inline recovery, but the 4.2 PASS criteria table omits it. One-line fix in SKILL.md line 379.

3. **Pin `model: claude-opus-4-8`** — replace `model: opus` per platform-delta.md 2026-05-28 model IDs row. Opus 4.8 honesty improvements directly benefit auto-fix correctness assessment and Invariant 5 auditing. Also note fast mode eligibility in token-budget.md for Phases 0–1.
